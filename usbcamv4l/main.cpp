#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#include <drm/drm_fourcc.h>
#include <turbojpeg.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/error.h>
#include <libavutil/hwcontext.h>
#include <libavutil/pixdesc.h>
}

#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <poll.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

#include <algorithm>
#include <chrono>
#include <cctype>
#include <cstdint>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <csignal>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <numeric>
#include <optional>
#include <sstream>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace fs = std::filesystem;

#ifndef GL_UNPACK_ROW_LENGTH_EXT
#define GL_UNPACK_ROW_LENGTH_EXT 0x0CF2
#endif

static constexpr int MAX_CAMERAS = 4;
static constexpr int DEFAULT_WINDOW_W = 320;
static constexpr int DEFAULT_WINDOW_H = 240;
static constexpr int DEFAULT_FRAME_W = 640;
static constexpr int DEFAULT_FRAME_H = 480;

enum class CapturePreference {
  Auto,     // Try NV12 then YUYV (existing behavior).
  MJPEG,    // Prefer MJPEG, then fall back to NV12/YUYV.
};

static bool g_activeRendererIsNvidia = false;
static bool g_activeRendererIsIntel = false;
static bool g_activeRendererIsAmd = false;

static volatile std::sig_atomic_t g_stopRequested = 0;

static void handle_stop_signal(int) {
  g_stopRequested = 1;
}

struct Rect { int x{0}; int y{0}; int w{DEFAULT_WINDOW_W}; int h{DEFAULT_WINDOW_H}; };

struct CamInfo {
  std::string devPath;
  std::string card;
  std::string busInfo;
  std::string stableId;
};

struct CameraScanResult {
  std::vector<CamInfo> cams;
  int videoNodes{0};
  int permissionDenied{0};
};

struct V4L2NodeInfo {
  CamInfo cam;
  uint32_t capabilities{0};
  uint32_t deviceCaps{0};
  uint32_t effectiveCaps{0};
  bool hasCapture{false};
};

struct CameraCandidate {
  CamInfo cam;
  int nodeNumber{-1}; // parsed from /dev/videoN
  int sysfsIndex{-1}; // /sys/class/video4linux/videoN/index
  bool isUsb{false};
  bool preferred{false};
};

struct Resolution {
  int w{DEFAULT_FRAME_W};
  int h{DEFAULT_FRAME_H};
};

static std::string trim(const std::string& s) {
  size_t a = s.find_first_not_of(" \t\r\n");
  size_t b = s.find_last_not_of(" \t\r\n");
  if (a == std::string::npos) return "";
  return s.substr(a, b - a + 1);
}

static std::string to_lower_copy(std::string s) {
  std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return s;
}

static bool env_is_truthy(const char* name) {
  const char* v = std::getenv(name);
  if (!v || !*v) return false;
  const std::string lower = to_lower_copy(trim(v));
  return !(lower == "0" || lower == "false" || lower == "no" || lower == "off");
}

static bool has_amd_drm_device() {
  std::error_code ec;
  const fs::path drmRoot("/sys/class/drm");
  if (!fs::exists(drmRoot, ec) || ec) return false;

  for (const auto& entry : fs::directory_iterator(drmRoot, ec)) {
    if (ec) break;
    const std::string name = entry.path().filename().string();
    if (name.rfind("card", 0) != 0) continue;
    if (name.find('-') != std::string::npos) continue;
    if (name.size() <= 4) continue;
    bool digitsOnly = true;
    for (size_t i = 4; i < name.size(); ++i) {
      if (!std::isdigit(static_cast<unsigned char>(name[i]))) {
        digitsOnly = false;
        break;
      }
    }
    if (!digitsOnly) continue;

    const fs::path vendorPath = entry.path() / "device" / "vendor";
    std::ifstream in(vendorPath);
    if (!in.is_open()) continue;
    std::string vendor;
    if (!std::getline(in, vendor)) continue;
    vendor = to_lower_copy(trim(vendor));
    if (vendor == "0x1002") return true; // AMD PCI vendor ID
  }
  return false;
}

static void maybe_enable_amd_zink_workaround() {
  if (env_is_truthy("USBCAMV4L_DISABLE_ZINK_WORKAROUND")) return;

  const bool forceZink = env_is_truthy("USBCAMV4L_FORCE_ZINK");
  if (!forceZink && !has_amd_drm_device()) return;

  if (std::getenv("MESA_LOADER_DRIVER_OVERRIDE") || std::getenv("GALLIUM_DRIVER")) {
    std::cerr << "Mesa driver override detected in environment; skipping internal Zink override.\n";
    return;
  }

  (void)setenv("MESA_LOADER_DRIVER_OVERRIDE", "zink", 0);
  (void)setenv("GALLIUM_DRIVER", "zink", 0);
  (void)setenv("LIBGL_KOPPER_DRI2", "1", 0);
  std::cerr << "Applying AMD Mesa workaround: requesting Zink OpenGL backend.\n";
}

static bool gl_extension_supported(const char* extList, const char* ext) {
  if (!extList || !ext || !*ext) return false;
  const std::string all(extList);
  const std::string needle(ext);
  size_t pos = 0;
  while (true) {
    pos = all.find(needle, pos);
    if (pos == std::string::npos) return false;
    const bool startOk = (pos == 0) || std::isspace(static_cast<unsigned char>(all[pos - 1]));
    const size_t endPos = pos + needle.size();
    const bool endOk = (endPos == all.size()) || std::isspace(static_cast<unsigned char>(all[endPos]));
    if (startOk && endOk) return true;
    pos = endPos;
  }
}

static std::string fourcc_to_string(uint32_t f) {
  std::string out(4, ' ');
  out[0] = static_cast<char>(f & 0xFF);
  out[1] = static_cast<char>((f >> 8) & 0xFF);
  out[2] = static_cast<char>((f >> 16) & 0xFF);
  out[3] = static_cast<char>((f >> 24) & 0xFF);
  return out;
}

static std::string av_error_to_string(int err) {
  char buf[AV_ERROR_MAX_STRING_SIZE] = {};
  if (av_strerror(err, buf, sizeof(buf)) == 0) return std::string(buf);
  return "unknown ffmpeg error";
}

static bool ffmpeg_planar_yuv_info(AVPixelFormat fmt, int width, int height,
                                   bool& isNV12, bool& hasChroma, int& chromaW, int& chromaH) {
  isNV12 = false;
  hasChroma = true;
  chromaW = 0;
  chromaH = 0;
  switch (fmt) {
    case AV_PIX_FMT_NV12:
      isNV12 = true;
      chromaW = (width + 1) / 2;
      chromaH = (height + 1) / 2;
      return true;
    case AV_PIX_FMT_YUV420P:
    case AV_PIX_FMT_YUVJ420P:
      chromaW = (width + 1) / 2;
      chromaH = (height + 1) / 2;
      return true;
    case AV_PIX_FMT_YUV422P:
    case AV_PIX_FMT_YUVJ422P:
      chromaW = (width + 1) / 2;
      chromaH = height;
      return true;
    case AV_PIX_FMT_YUV444P:
    case AV_PIX_FMT_YUVJ444P:
      chromaW = width;
      chromaH = height;
      return true;
    case AV_PIX_FMT_GRAY8:
      hasChroma = false;
      chromaW = 0;
      chromaH = 0;
      return true;
    default:
      return false;
  }
}

static bool is_mjpeg_fourcc(uint32_t fmt) {
  return fmt == V4L2_PIX_FMT_MJPEG || fmt == V4L2_PIX_FMT_JPEG;
}

static std::vector<std::string> enumerate_drm_render_nodes() {
  std::vector<std::pair<int, std::string>> numbered;
  std::error_code ec;
  const fs::path drmRoot("/dev/dri");
  if (!fs::exists(drmRoot, ec) || ec) return {};

  for (const auto& entry : fs::directory_iterator(drmRoot, ec)) {
    if (ec) break;
    const std::string name = entry.path().filename().string();
    const std::string prefix = "renderD";
    if (name.rfind(prefix, 0) != 0) continue;
    const std::string tail = name.substr(prefix.size());
    if (tail.empty()) continue;
    bool digitsOnly = true;
    for (char c : tail) {
      if (!std::isdigit(static_cast<unsigned char>(c))) {
        digitsOnly = false;
        break;
      }
    }
    if (!digitsOnly) continue;
    int n = -1;
    try {
      n = std::stoi(tail);
    } catch (...) {
      continue;
    }
    numbered.push_back({n, entry.path().string()});
  }

  std::sort(numbered.begin(), numbered.end(),
            [](const auto& a, const auto& b) { return a.first < b.first; });
  std::vector<std::string> out;
  out.reserve(numbered.size());
  for (const auto& item : numbered) out.push_back(item.second);
  return out;
}

static bool pixfmt_matches_request(uint32_t requested, uint32_t actual) {
  if (requested == V4L2_PIX_FMT_MJPEG) return is_mjpeg_fourcc(actual);
  return requested == actual;
}

static bool try_set_capture_format(int fd, int reqW, int reqH,
                                   uint32_t requestedPixFmt,
                                   v4l2_format& outFmt) {
  std::memset(&outFmt, 0, sizeof(outFmt));
  outFmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  outFmt.fmt.pix.width = reqW;
  outFmt.fmt.pix.height = reqH;
  outFmt.fmt.pix.pixelformat = requestedPixFmt;
  outFmt.fmt.pix.field = V4L2_FIELD_NONE;
  if (ioctl(fd, VIDIOC_S_FMT, &outFmt) != 0) return false;
  return pixfmt_matches_request(requestedPixFmt, outFmt.fmt.pix.pixelformat);
}

static std::string sanitize_stable_id(std::string id) {
  id = trim(id);
  for (char& c : id) {
    if (c == ',' || c == '\n' || c == '\r') c = '_';
  }
  return id;
}

static int parse_video_node_number(const std::string& devPath) {
  const std::string prefix = "/dev/video";
  if (devPath.rfind(prefix, 0) != 0) return -1;
  const std::string tail = devPath.substr(prefix.size());
  if (tail.empty()) return -1;
  for (char c : tail) if (c < '0' || c > '9') return -1;
  try {
    return std::stoi(tail);
  } catch (...) {
    return -1;
  }
}

static int read_int_file(const fs::path& p) {
  std::ifstream in(p);
  if (!in.is_open()) return -1;
  std::string s;
  if (!std::getline(in, s)) return -1;
  s = trim(s);
  if (s.empty()) return -1;
  try {
    return std::stoi(s);
  } catch (...) {
    return -1;
  }
}

static std::string physical_device_key(const std::string& devPath, const std::string& busInfo) {
  const std::string trimmedBus = trim(busInfo);
  if (!trimmedBus.empty()) return sanitize_stable_id(trimmedBus);

  std::error_code ec;
  const auto videoName = fs::path(devPath).filename();
  const fs::path sysDevice = fs::canonical(fs::path("/sys/class/video4linux") / videoName / "device", ec);
  if (!ec && !sysDevice.empty()) return sanitize_stable_id(sysDevice.string());

  return sanitize_stable_id(devPath);
}

static bool is_usb_key(const std::string& busInfo, const std::string& physicalKey) {
  const std::string bus = trim(busInfo);
  if (bus.rfind("usb-", 0) == 0) return true;
  return physicalKey.find("/usb") != std::string::npos;
}

static int sort_int_or_max(int value) {
  return (value >= 0) ? value : std::numeric_limits<int>::max();
}

static bool stepwise_contains(const v4l2_frmsize_stepwise& sw, uint32_t w, uint32_t h) {
  if (w < sw.min_width || w > sw.max_width || h < sw.min_height || h > sw.max_height) return false;
  if (sw.step_width > 0 && ((w - sw.min_width) % sw.step_width) != 0) return false;
  if (sw.step_height > 0 && ((h - sw.min_height) % sw.step_height) != 0) return false;
  return true;
}

static void add_resolution_unique(std::vector<Resolution>& out,
                                  std::unordered_set<uint64_t>& seen,
                                  int w, int h) {
  if (w <= 0 || h <= 0) return;
  const uint64_t key =
      (static_cast<uint64_t>(static_cast<uint32_t>(w)) << 32) |
      static_cast<uint32_t>(h);
  if (!seen.insert(key).second) return;
  out.push_back(Resolution{w, h});
}

static std::vector<Resolution> enumerate_supported_resolutions(const std::string& devPath,
                                                               int* failErrno = nullptr) {
  if (failErrno) *failErrno = 0;

  int fd = ::open(devPath.c_str(), O_RDONLY | O_NONBLOCK);
  if (fd < 0) {
    if (failErrno) *failErrno = errno;
    return {};
  }

  std::vector<Resolution> out;
  std::unordered_set<uint64_t> seen;

  auto add_stepwise_resolutions = [&](const v4l2_frmsize_stepwise& sw) {
    add_resolution_unique(out, seen, static_cast<int>(sw.min_width), static_cast<int>(sw.min_height));
    add_resolution_unique(out, seen, static_cast<int>(sw.max_width), static_cast<int>(sw.max_height));

    static constexpr Resolution common[] = {
        {320, 240}, {640, 480}, {800, 600}, {1024, 576},
        {1024, 768}, {1280, 720}, {1280, 800}, {1280, 960},
        {1600, 900}, {1920, 1080},
    };
    for (const auto& r : common) {
      if (stepwise_contains(sw, static_cast<uint32_t>(r.w), static_cast<uint32_t>(r.h))) {
        add_resolution_unique(out, seen, r.w, r.h);
      }
    }
  };

  auto enum_for_type = [&](uint32_t bufType) {
    for (uint32_t fmtIdx = 0;; ++fmtIdx) {
      v4l2_fmtdesc fmt{};
      fmt.type = bufType;
      fmt.index = fmtIdx;
      if (ioctl(fd, VIDIOC_ENUM_FMT, &fmt) != 0) break;

      for (uint32_t sizeIdx = 0;; ++sizeIdx) {
        v4l2_frmsizeenum fsize{};
        fsize.index = sizeIdx;
        fsize.pixel_format = fmt.pixelformat;
        if (ioctl(fd, VIDIOC_ENUM_FRAMESIZES, &fsize) != 0) break;

        if (fsize.type == V4L2_FRMSIZE_TYPE_DISCRETE) {
          add_resolution_unique(out, seen,
                                static_cast<int>(fsize.discrete.width),
                                static_cast<int>(fsize.discrete.height));
        } else if (fsize.type == V4L2_FRMSIZE_TYPE_STEPWISE ||
                   fsize.type == V4L2_FRMSIZE_TYPE_CONTINUOUS) {
          add_stepwise_resolutions(fsize.stepwise);
        }
      }
    }
  };

  enum_for_type(V4L2_BUF_TYPE_VIDEO_CAPTURE);
  enum_for_type(V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE);
  ::close(fd);

  if (out.empty()) {
    add_resolution_unique(out, seen, DEFAULT_FRAME_W, DEFAULT_FRAME_H);
  }

  std::sort(out.begin(), out.end(),
            [](const Resolution& a, const Resolution& b) {
              if (a.h != b.h) return a.h < b.h;
              return a.w < b.w;
            });
  return out;
}

static Resolution choose_resolution_interactively(const CamInfo& cam,
                                                  const std::vector<Resolution>& availableInput,
                                                  const Resolution& defaultRes) {
  std::vector<Resolution> available = availableInput;
  if (available.empty()) available.push_back(defaultRes);

  std::sort(available.begin(), available.end(),
            [](const Resolution& a, const Resolution& b) {
              if (a.h != b.h) return a.h < b.h;
              return a.w < b.w;
            });

  size_t defaultIdx = 0;
  for (size_t i = 0; i < available.size(); ++i) {
    if (available[i].w == defaultRes.w && available[i].h == defaultRes.h) {
      defaultIdx = i;
      break;
    }
  }

  std::cout << "\nCamera: " << cam.card << " [" << cam.devPath << "]\n";
  std::cout << "Available resolutions:\n";
  for (size_t i = 0; i < available.size(); ++i) {
    std::cout << "  " << (i + 1) << ") " << available[i].w << "x" << available[i].h;
    if (i == defaultIdx) std::cout << " (default)";
    std::cout << "\n";
  }
  std::cout << "Choose [1-" << available.size() << "] (ENTER for "
            << (defaultIdx + 1) << "): " << std::flush;

  while (true) {
    std::string line;
    if (!std::getline(std::cin, line)) {
      std::cout << "\n";
      return available[defaultIdx];
    }
    line = trim(line);
    if (line.empty()) return available[defaultIdx];

    try {
      const int choice = std::stoi(line);
      if (choice >= 1 && choice <= static_cast<int>(available.size())) {
        return available[static_cast<size_t>(choice - 1)];
      }
    } catch (...) {
    }
    std::cout << "Invalid selection. Choose [1-" << available.size() << "]: " << std::flush;
  }
}

static std::optional<Resolution> best_resolution_for_height(const std::vector<Resolution>& available,
                                                            int targetHeight) {
  std::optional<Resolution> best;
  for (const auto& r : available) {
    if (r.h != targetHeight) continue;
    if (!best.has_value()) {
      best = r;
      continue;
    }

    const int lhs = std::abs(r.w - DEFAULT_FRAME_W);
    const int rhs = std::abs(best->w - DEFAULT_FRAME_W);
    if (lhs < rhs || (lhs == rhs && r.w < best->w)) {
      best = r;
    }
  }
  return best;
}

static int choose_common_height_interactively(
    const std::vector<int>& heights,
    const std::vector<CamInfo>& orderedCams,
    const std::unordered_map<std::string, std::vector<Resolution>>& availableByStableId,
    int defaultHeight) {
  size_t defaultIdx = 0;
  for (size_t i = 0; i < heights.size(); ++i) {
    if (heights[i] == defaultHeight) {
      defaultIdx = i;
      break;
    }
  }

  std::cout << "\nCommon pixel heights across selected cameras:\n";
  for (size_t i = 0; i < heights.size(); ++i) {
    const int h = heights[i];
    std::cout << "  " << (i + 1) << ") height " << h << "px";
    for (const auto& cam : orderedCams) {
      auto it = availableByStableId.find(cam.stableId);
      if (it == availableByStableId.end()) continue;
      auto best = best_resolution_for_height(it->second, h);
      if (!best.has_value()) continue;
      std::cout << " | " << cam.devPath << ": " << best->w << "x" << best->h;
    }
    std::cout << "\n";
  }

  std::cout << "Choose [1-" << heights.size() << "] (ENTER for "
            << (defaultIdx + 1) << "): " << std::flush;

  while (true) {
    std::string line;
    if (!std::getline(std::cin, line)) {
      std::cout << "\n";
      return heights[defaultIdx];
    }
    line = trim(line);
    if (line.empty()) return heights[defaultIdx];

    try {
      const int choice = std::stoi(line);
      if (choice >= 1 && choice <= static_cast<int>(heights.size())) {
        return heights[static_cast<size_t>(choice - 1)];
      }
    } catch (...) {
    }
    std::cout << "Invalid selection. Choose [1-" << heights.size() << "]: " << std::flush;
  }
}

static std::string config_dir() {
  const char* xdg = std::getenv("XDG_CONFIG_HOME");
  const char* home = std::getenv("HOME");
  std::string baseDir;
  if (xdg && std::strlen(xdg) > 0) baseDir = xdg;
  else if (home && std::strlen(home) > 0) baseDir = std::string(home) + "/.config";
  else baseDir = ".";
  std::string dir = baseDir + "/viewMultiCameras";
  std::error_code ec;
  fs::create_directories(dir, ec);
  return dir;
}

static std::string positions_file() {
  return config_dir() + "/camera_positions.csv";
}

static std::string resolutions_file() {
  return config_dir() + "/camera_resolutions.csv";
}

static std::string recordings_dir() {
  const char* home = std::getenv("HOME");
  std::string baseDir;
  if (home && std::strlen(home) > 0) {
    baseDir = std::string(home) + "/Desktop";
  } else {
    baseDir = ".";
  }
  const std::string dir = baseDir + "/USB-Recordings";
  std::error_code ec;
  fs::create_directories(dir, ec);
  return dir;
}

static std::string control_socket_file() {
  const char* env = std::getenv("USBCAMV4L_CONTROL_SOCKET");
  if (env && std::strlen(env) > 0) return std::string(env);
  return "/tmp/usbcamv4l-control.sock";
}

static int create_control_socket(const std::string& socketPath) {
  if (socketPath.empty()) return -1;
  if (socketPath.size() >= sizeof(sockaddr_un{}.sun_path)) {
    std::cerr << "Control socket path too long: " << socketPath << "\n";
    return -1;
  }

  const int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
  if (fd < 0) {
    std::cerr << "Failed to create control socket: " << strerror(errno) << "\n";
    return -1;
  }

  if (fcntl(fd, F_SETFL, O_NONBLOCK) != 0) {
    std::cerr << "Failed to set control socket nonblocking mode: " << strerror(errno) << "\n";
    close(fd);
    return -1;
  }

  unlink(socketPath.c_str());
  sockaddr_un addr{};
  addr.sun_family = AF_UNIX;
  std::strncpy(addr.sun_path, socketPath.c_str(), sizeof(addr.sun_path) - 1);
  if (bind(fd, reinterpret_cast<const sockaddr*>(&addr), sizeof(addr)) != 0) {
    std::cerr << "Failed to bind control socket " << socketPath
              << ": " << strerror(errno) << "\n";
    close(fd);
    return -1;
  }
  return fd;
}

static std::string sanitize_filename_component(std::string s) {
  s = sanitize_stable_id(s);
  for (char& c : s) {
    const bool ok = std::isalnum(static_cast<unsigned char>(c)) || c == '-' || c == '_' || c == '.';
    if (!ok) c = '_';
  }
  if (s.empty()) s = "camera";
  return s;
}

static std::string compact_local_timestamp() {
  const auto now = std::chrono::system_clock::now();
  const std::time_t t = std::chrono::system_clock::to_time_t(now);
  std::tm tm{};
#if defined(_POSIX_VERSION)
  localtime_r(&t, &tm);
#else
  tm = *std::localtime(&t);
#endif
  char buf[32] = {};
  if (std::strftime(buf, sizeof(buf), "%Y%m%d_%H%M%S", &tm) == 0) {
    return "time";
  }
  return std::string(buf);
}

struct RawVideoRecorder {
  enum class Profile {
    Fast,
    Quality,
  };
  enum class Backend {
    SoftwareX264,
    VaapiH264,
  };

  bool enabled{false};
  Profile profile{Profile::Fast};
  bool started{false};
  pid_t pid{-1};
  int writeFd{-1};
  int width{0};
  int height{0};
  int segment{0};
  bool softwareFallbackUsed{false};
  Backend backend{Backend::SoftwareX264};
  std::string vaapiDevice;
  std::string baseName;
  std::string outputPath;

  bool write_all(const uint8_t* data, size_t bytes) {
    if (!started || writeFd < 0 || !data) return false;
    size_t off = 0;
    while (off < bytes) {
      const ssize_t n = ::write(writeFd, data + off, bytes - off);
      if (n > 0) {
        off += static_cast<size_t>(n);
        continue;
      }
      if (n < 0 && errno == EINTR) continue;
      return false;
    }
    return true;
  }

  void stop() {
    if (writeFd >= 0) {
      ::close(writeFd);
      writeFd = -1;
    }
    if (pid > 0) {
      int status = 0;
      (void)waitpid(pid, &status, 0);
      pid = -1;
    }
    started = false;
    width = 0;
    height = 0;
    backend = Backend::SoftwareX264;
    vaapiDevice.clear();
  }

  bool start_process(int w, int h, bool forceSoftware = false) {
    if (!enabled || w <= 0 || h <= 0) return false;
    stop();
    width = w;
    height = h;
    if (!forceSoftware) softwareFallbackUsed = false;

    const std::string ts = compact_local_timestamp();
    const std::string safeBase = sanitize_filename_component(baseName);
    const std::string part = (segment > 0) ? ("_part" + std::to_string(segment)) : "";
    outputPath = recordings_dir() + "/" + safeBase + "_" + ts +
                 "_" + std::to_string(width) + "x" + std::to_string(height) +
                 part + ".mp4";
    const std::string sizeArg = std::to_string(width) + "x" + std::to_string(height);

    bool useVaapiFastPath =
        !forceSoftware &&
        profile == Profile::Fast &&
        !env_is_truthy("USBCAMV4L_REC_SOFTWARE_ONLY");
    vaapiDevice.clear();
    if (useVaapiFastPath) {
      const char* forced = std::getenv("USBCAMV4L_VAAPI_DEVICE");
      if (forced && *forced) {
        vaapiDevice = forced;
      } else {
        const auto renderNodes = enumerate_drm_render_nodes();
        if (!renderNodes.empty()) vaapiDevice = renderNodes.front();
      }
      if (vaapiDevice.empty()) useVaapiFastPath = false;
    }
    backend = useVaapiFastPath ? Backend::VaapiH264 : Backend::SoftwareX264;

    int pipeFds[2] = {-1, -1};
    if (pipe(pipeFds) != 0) {
      std::cerr << "Failed to create recording pipe for " << safeBase
                << ": " << strerror(errno) << "\n";
      return false;
    }

    const pid_t child = fork();
    if (child < 0) {
      std::cerr << "Failed to start recorder process for " << safeBase
                << ": " << strerror(errno) << "\n";
      ::close(pipeFds[0]);
      ::close(pipeFds[1]);
      return false;
    }

    if (child == 0) {
      ::close(pipeFds[1]);
      if (dup2(pipeFds[0], STDIN_FILENO) < 0) _exit(127);
      ::close(pipeFds[0]);

      if (useVaapiFastPath) {
        const char* mesaOverride = std::getenv("MESA_LOADER_DRIVER_OVERRIDE");
        if (mesaOverride && to_lower_copy(trim(mesaOverride)) == "zink") {
          (void)unsetenv("MESA_LOADER_DRIVER_OVERRIDE");
          (void)unsetenv("GALLIUM_DRIVER");
          (void)unsetenv("LIBGL_KOPPER_DRI2");
        }
        const char* argvVaapi[] = {
            "ffmpeg",
            "-hide_banner",
            "-loglevel", "error",
            "-y",
            "-vaapi_device", vaapiDevice.c_str(),
            "-f", "rawvideo",
            "-pix_fmt", "rgba",
            "-video_size", sizeArg.c_str(),
            "-framerate", "30",
            "-i", "-",
            "-vf", "vflip,format=nv12,hwupload",
            "-an",
            "-c:v", "h264_vaapi",
            "-qp", "28",
            outputPath.c_str(),
            nullptr};
        execvp("ffmpeg", const_cast<char* const*>(argvVaapi));
      } else if (profile == Profile::Quality) {
        const char* argvQuality[] = {
            "ffmpeg",
            "-hide_banner",
            "-loglevel", "error",
            "-y",
            "-f", "rawvideo",
            "-pix_fmt", "rgba",
            "-video_size", sizeArg.c_str(),
            "-framerate", "30",
            "-i", "-",
            "-vf", "vflip,format=yuv420p",
            "-an",
            "-c:v", "libx264",
            "-preset", "medium",
            "-crf", "20",
            outputPath.c_str(),
            nullptr};
        execvp("ffmpeg", const_cast<char* const*>(argvQuality));
      } else {
        const char* argvFast[] = {
            "ffmpeg",
            "-hide_banner",
            "-loglevel", "error",
            "-y",
            "-f", "rawvideo",
            "-pix_fmt", "rgba",
            "-video_size", sizeArg.c_str(),
            "-framerate", "30",
            "-i", "-",
            "-vf", "vflip,format=yuv420p",
            "-an",
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-tune", "zerolatency",
            "-crf", "30",
            outputPath.c_str(),
            nullptr};
        execvp("ffmpeg", const_cast<char* const*>(argvFast));
      }
      _exit(127);
    }

    ::close(pipeFds[0]);
    writeFd = pipeFds[1];
    pid = child;
    started = true;
    const char* backendLabel = (backend == Backend::VaapiH264)
                                   ? "h264_vaapi"
                                   : (profile == Profile::Quality ? "libx264 medium" : "libx264 ultrafast");
    std::cerr << "Recording started: " << outputPath << "\n";
    std::cerr << "Recording encoder: " << backendLabel << "\n";
    return true;
  }

  bool ensure_started(const std::string& name, int w, int h) {
    if (!enabled) return false;
    if (baseName.empty()) baseName = name;
    if (!started) return start_process(w, h);
    if (w == width && h == height) return true;

    ++segment;
    std::cerr << "Recording resolution changed for " << baseName
              << " to " << w << "x" << h << "; starting new file segment.\n";
    return start_process(w, h);
  }

  bool write_frame(const uint8_t* rgba, size_t bytes) {
    if (!started || writeFd < 0) return false;
    if (write_all(rgba, bytes)) return true;

    if (profile == Profile::Fast &&
        backend == Backend::VaapiH264 &&
        !softwareFallbackUsed) {
      const int w = width;
      const int h = height;
      softwareFallbackUsed = true;
      ++segment;
      std::cerr << "VAAPI recorder write failed for " << baseName
                << "; retrying with software x264.\n";
      if (start_process(w, h, true) && write_all(rgba, bytes)) {
        return true;
      }
    }

    std::cerr << "Recording pipeline write failed for " << baseName
              << "; stopping recorder.\n";
    stop();
    return false;
  }
};

static std::optional<V4L2NodeInfo> query_v4l2(const std::string& devPath, int* failErrno = nullptr) {
  if (failErrno) *failErrno = 0;
  int fd = ::open(devPath.c_str(), O_RDONLY | O_NONBLOCK);
  if (fd < 0) {
    if (failErrno) *failErrno = errno;
    return std::nullopt;
  }

  v4l2_capability cap{};
  if (ioctl(fd, VIDIOC_QUERYCAP, &cap) != 0) {
    if (failErrno) *failErrno = errno;
    ::close(fd);
    return std::nullopt;
  }
  ::close(fd);

  V4L2NodeInfo out;
  out.cam.devPath = devPath;
  out.cam.card = reinterpret_cast<const char*>(cap.card);
  out.cam.busInfo = reinterpret_cast<const char*>(cap.bus_info);

  out.capabilities = cap.capabilities;
  out.deviceCaps = cap.device_caps;
  out.effectiveCaps =
      (cap.capabilities & V4L2_CAP_DEVICE_CAPS) ? cap.device_caps : cap.capabilities;
  out.hasCapture =
      (out.effectiveCaps & V4L2_CAP_VIDEO_CAPTURE) ||
      (out.effectiveCaps & V4L2_CAP_VIDEO_CAPTURE_MPLANE);
  return out;
}

static int probe_capture_stream_rank(const std::string& devPath, CapturePreference capturePref) {
  int fd = ::open(devPath.c_str(), O_RDWR | O_NONBLOCK);
  if (fd < 0) return -1;

  auto close_fd = [&]() {
    if (fd >= 0) {
      ::close(fd);
      fd = -1;
    }
  };

  v4l2_capability cap{};
  if (ioctl(fd, VIDIOC_QUERYCAP, &cap) != 0) {
    close_fd();
    return -1;
  }
  const uint32_t effectiveCaps =
      (cap.capabilities & V4L2_CAP_DEVICE_CAPS) ? cap.device_caps : cap.capabilities;
  const bool hasCapture =
      (effectiveCaps & V4L2_CAP_VIDEO_CAPTURE) ||
      (effectiveCaps & V4L2_CAP_VIDEO_CAPTURE_MPLANE);
  if (!hasCapture) {
    close_fd();
    return -1;
  }

  v4l2_format fmt{};
  if (capturePref == CapturePreference::MJPEG &&
      try_set_capture_format(fd, DEFAULT_FRAME_W, DEFAULT_FRAME_H, V4L2_PIX_FMT_MJPEG, fmt)) {
    close_fd();
    return 3;
  }

  if (try_set_capture_format(fd, DEFAULT_FRAME_W, DEFAULT_FRAME_H, V4L2_PIX_FMT_NV12, fmt)) {
    close_fd();
    return 2;
  }

  const bool ok = (try_set_capture_format(fd, DEFAULT_FRAME_W, DEFAULT_FRAME_H, V4L2_PIX_FMT_YUYV, fmt) &&
                   (fmt.fmt.pix.width % 2) == 0);
  close_fd();
  return ok ? 1 : -1;
}

static CameraScanResult enumerate_cameras(CapturePreference capturePref) {
  CameraScanResult scan;
  std::vector<std::string> videoNodes;
  std::error_code ec;
  fs::directory_iterator it("/dev", ec);
  fs::directory_iterator end;
  for (; !ec && it != end; it.increment(ec)) {
    const auto& ent = *it;
    const auto name = ent.path().filename().string();
    if (name.rfind("video", 0) != 0) continue;
    videoNodes.push_back(ent.path().string());
  }

  std::sort(videoNodes.begin(), videoNodes.end(),
            [](const std::string& a, const std::string& b) {
              const int an = parse_video_node_number(a);
              const int bn = parse_video_node_number(b);
              if (an >= 0 && bn >= 0 && an != bn) return an < bn;
              return a < b;
            });

  scan.videoNodes = static_cast<int>(videoNodes.size());

  std::unordered_map<std::string, std::vector<CameraCandidate>> groups;
  for (const auto& devPath : videoNodes) {
    const auto videoName = fs::path(devPath).filename();

    int failErr = 0;
    auto qi = query_v4l2(devPath, &failErr);
    if (!qi) {
      if (failErr == EACCES || failErr == EPERM) ++scan.permissionDenied;
      continue;
    }
    if (!qi->hasCapture) continue;

    CameraCandidate c;
    c.cam = qi->cam;
    c.nodeNumber = parse_video_node_number(devPath);
    c.sysfsIndex = read_int_file(fs::path("/sys/class/video4linux") / videoName / "index");
    c.cam.stableId = physical_device_key(devPath, c.cam.busInfo);
    c.isUsb = is_usb_key(c.cam.busInfo, c.cam.stableId);

    groups[c.cam.stableId].push_back(c);
  }

  std::vector<CameraCandidate> selected;
  selected.reserve(groups.size() * 2);
  for (auto& kv : groups) {
    auto& cands = kv.second;
    std::sort(cands.begin(), cands.end(),
              [](const CameraCandidate& a, const CameraCandidate& b) {
                if (sort_int_or_max(a.sysfsIndex) != sort_int_or_max(b.sysfsIndex)) {
                  return sort_int_or_max(a.sysfsIndex) < sort_int_or_max(b.sysfsIndex);
                }
                if (sort_int_or_max(a.nodeNumber) != sort_int_or_max(b.nodeNumber)) {
                  return sort_int_or_max(a.nodeNumber) < sort_int_or_max(b.nodeNumber);
                }
                return a.cam.devPath < b.cam.devPath;
              });

    int preferredIdx = -1;
    int bestRank = -1;
    for (size_t i = 0; i < cands.size(); ++i) {
      const int rank = probe_capture_stream_rank(cands[i].cam.devPath, capturePref);
      if (rank > bestRank) {
        bestRank = rank;
        preferredIdx = static_cast<int>(i);
      }
    }
    if (preferredIdx >= 0) cands[static_cast<size_t>(preferredIdx)].preferred = true;
    if (preferredIdx >= 0) selected.push_back(cands[preferredIdx]);
    for (size_t i = 0; i < cands.size(); ++i) {
      if (static_cast<int>(i) == preferredIdx) continue;
      selected.push_back(cands[i]);
    }
  }

  std::sort(selected.begin(), selected.end(),
            [](const CameraCandidate& a, const CameraCandidate& b) {
              if (a.isUsb != b.isUsb) return a.isUsb > b.isUsb;
              if (a.cam.stableId != b.cam.stableId) return a.cam.stableId < b.cam.stableId;
              if (a.preferred != b.preferred) return a.preferred > b.preferred;
              if (sort_int_or_max(a.nodeNumber) != sort_int_or_max(b.nodeNumber)) {
                return sort_int_or_max(a.nodeNumber) < sort_int_or_max(b.nodeNumber);
              }
              return a.cam.devPath < b.cam.devPath;
            });

  for (const auto& c : selected) {
    if (c.preferred) {
      std::cerr << "Selected camera node " << c.cam.devPath
                << " (group=" << c.cam.stableId << ")\n";
    }
    scan.cams.push_back(c.cam);
  }
  return scan;
}

static std::string fps_string_from_fraction(uint32_t numerator, uint32_t denominator) {
  if (numerator == 0 || denominator == 0) return "n/a";
  const double fps = static_cast<double>(denominator) / static_cast<double>(numerator);
  char buf[32];
  std::snprintf(buf, sizeof(buf), "%.2f", fps);
  return std::string(buf);
}

static std::string frame_interval_summary(int fd, uint32_t pixFmt, uint32_t width, uint32_t height) {
  v4l2_frmivalenum fi{};
  fi.pixel_format = pixFmt;
  fi.width = width;
  fi.height = height;
  fi.index = 0;
  if (ioctl(fd, VIDIOC_ENUM_FRAMEINTERVALS, &fi) != 0) return "fps: unknown";

  if (fi.type == V4L2_FRMIVAL_TYPE_DISCRETE) {
    std::vector<double> fpsValues;
    for (uint32_t idx = 0;; ++idx) {
      v4l2_frmivalenum cur{};
      cur.pixel_format = pixFmt;
      cur.width = width;
      cur.height = height;
      cur.index = idx;
      if (ioctl(fd, VIDIOC_ENUM_FRAMEINTERVALS, &cur) != 0) break;
      if (cur.type != V4L2_FRMIVAL_TYPE_DISCRETE ||
          cur.discrete.numerator == 0 || cur.discrete.denominator == 0) {
        continue;
      }
      fpsValues.push_back(static_cast<double>(cur.discrete.denominator) /
                          static_cast<double>(cur.discrete.numerator));
      if (fpsValues.size() >= 8) break;
    }
    if (fpsValues.empty()) return "fps: unknown";
    std::sort(fpsValues.begin(), fpsValues.end());
    fpsValues.erase(std::unique(fpsValues.begin(), fpsValues.end()), fpsValues.end());
    std::string out = "fps:";
    for (double fps : fpsValues) {
      char buf[24];
      std::snprintf(buf, sizeof(buf), " %.2f", fps);
      out += buf;
    }
    return out;
  }

  if (fi.type == V4L2_FRMIVAL_TYPE_STEPWISE || fi.type == V4L2_FRMIVAL_TYPE_CONTINUOUS) {
    const std::string minFps = fps_string_from_fraction(fi.stepwise.max.numerator, fi.stepwise.max.denominator);
    const std::string maxFps = fps_string_from_fraction(fi.stepwise.min.numerator, fi.stepwise.min.denominator);
    return "fps: " + minFps + "-" + maxFps;
  }
  return "fps: unknown";
}

static void list_camera_formats_and_modes(const CamInfo& cam) {
  std::cout << "Camera: " << cam.card << " [" << cam.devPath << "]\n";
  std::cout << "  stable-id: " << cam.stableId << "\n";
  if (!trim(cam.busInfo).empty()) std::cout << "  bus-info: " << cam.busInfo << "\n";

  int fd = ::open(cam.devPath.c_str(), O_RDONLY | O_NONBLOCK);
  if (fd < 0) {
    std::cout << "  open failed: " << strerror(errno) << "\n\n";
    return;
  }

  auto enum_type = [&](uint32_t type, const char* typeLabel) {
    bool printedType = false;
    for (uint32_t fmtIdx = 0;; ++fmtIdx) {
      v4l2_fmtdesc fmt{};
      fmt.type = type;
      fmt.index = fmtIdx;
      if (ioctl(fd, VIDIOC_ENUM_FMT, &fmt) != 0) break;
      if (!printedType) {
        std::cout << "  " << typeLabel << ":\n";
        printedType = true;
      }
      std::cout << "    format " << fourcc_to_string(fmt.pixelformat)
                << " (" << reinterpret_cast<const char*>(fmt.description) << ")\n";

      int listedSizes = 0;
      int totalSizes = 0;
      bool truncated = false;
      for (uint32_t sizeIdx = 0;; ++sizeIdx) {
        v4l2_frmsizeenum fsize{};
        fsize.index = sizeIdx;
        fsize.pixel_format = fmt.pixelformat;
        if (ioctl(fd, VIDIOC_ENUM_FRAMESIZES, &fsize) != 0) break;
        ++totalSizes;
        if (listedSizes >= 16) {
          truncated = true;
          continue;
        }
        if (fsize.type == V4L2_FRMSIZE_TYPE_DISCRETE) {
          const uint32_t w = fsize.discrete.width;
          const uint32_t h = fsize.discrete.height;
          std::cout << "      " << w << "x" << h
                    << " (" << frame_interval_summary(fd, fmt.pixelformat, w, h) << ")\n";
        } else if (fsize.type == V4L2_FRMSIZE_TYPE_STEPWISE ||
                   fsize.type == V4L2_FRMSIZE_TYPE_CONTINUOUS) {
          std::cout << "      "
                    << fsize.stepwise.min_width << "x" << fsize.stepwise.min_height
                    << " .. "
                    << fsize.stepwise.max_width << "x" << fsize.stepwise.max_height
                    << " (step "
                    << std::max(1u, fsize.stepwise.step_width) << "x"
                    << std::max(1u, fsize.stepwise.step_height) << ")\n";
        }
        ++listedSizes;
      }
      if (truncated) {
        std::cout << "      ... +" << (totalSizes - listedSizes) << " more sizes\n";
      }
    }
  };

  enum_type(V4L2_BUF_TYPE_VIDEO_CAPTURE, "VIDEO_CAPTURE");
  enum_type(V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE, "VIDEO_CAPTURE_MPLANE");
  ::close(fd);
  std::cout << "\n";
}

static int list_cameras_mode(CapturePreference capturePref) {
  auto scan = enumerate_cameras(capturePref);
  if (scan.cams.empty()) {
    if (scan.videoNodes == 0) {
      std::cerr << "No /dev/video* devices found.\n";
    } else if (scan.permissionDenied == scan.videoNodes) {
      std::cerr << "Permission denied opening all /dev/video* devices.\n";
      std::cerr << "Add this user to the 'video' group and re-login.\n";
    } else {
      std::cerr << "No capture-capable V4L2 cameras found.\n";
    }
    return 1;
  }

  std::unordered_set<std::string> seen;
  for (const auto& cam : scan.cams) {
    if (!seen.insert(cam.devPath).second) continue;
    list_camera_formats_and_modes(cam);
  }
  return 0;
}

struct CaptureBenchScore {
  uint32_t requestedPixFmt{0};
  uint32_t actualPixFmt{0};
  int width{0};
  int height{0};
  int frames{0};
  double fps{0.0};
  bool ok{false};
};

static CaptureBenchScore benchmark_capture_format(const std::string& devPath,
                                                  int reqW, int reqH,
                                                  uint32_t requestedPixFmt,
                                                  int durationMs) {
  CaptureBenchScore out;
  out.requestedPixFmt = requestedPixFmt;
  if (durationMs <= 0) return out;

  int fd = ::open(devPath.c_str(), O_RDWR | O_NONBLOCK);
  if (fd < 0) return out;

  std::vector<v4l2_buffer> queuedBuffers;
  std::vector<void*> mappedPtrs;
  std::vector<size_t> mappedLens;

  auto cleanup = [&]() {
    if (fd >= 0) {
      v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
      (void)ioctl(fd, VIDIOC_STREAMOFF, &type);
    }
    for (size_t i = 0; i < mappedPtrs.size(); ++i) {
      if (mappedPtrs[i] && mappedPtrs[i] != MAP_FAILED) {
        munmap(mappedPtrs[i], mappedLens[i]);
      }
    }
    if (fd >= 0) {
      ::close(fd);
      fd = -1;
    }
  };

  v4l2_format fmt{};
  if (!try_set_capture_format(fd, reqW, reqH, requestedPixFmt, fmt)) {
    cleanup();
    return out;
  }
  out.actualPixFmt = fmt.fmt.pix.pixelformat;
  out.width = static_cast<int>(fmt.fmt.pix.width);
  out.height = static_cast<int>(fmt.fmt.pix.height);

  v4l2_requestbuffers req{};
  req.count = 3;
  req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  req.memory = V4L2_MEMORY_MMAP;
  if (ioctl(fd, VIDIOC_REQBUFS, &req) != 0 || req.count < 2) {
    cleanup();
    return out;
  }

  mappedPtrs.resize(req.count, nullptr);
  mappedLens.resize(req.count, 0);
  queuedBuffers.resize(req.count);

  for (uint32_t i = 0; i < req.count; ++i) {
    v4l2_buffer b{};
    b.type = req.type;
    b.memory = req.memory;
    b.index = i;
    if (ioctl(fd, VIDIOC_QUERYBUF, &b) != 0) {
      cleanup();
      return out;
    }
    mappedLens[i] = b.length;
    mappedPtrs[i] = mmap(nullptr, b.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, b.m.offset);
    if (mappedPtrs[i] == MAP_FAILED) {
      mappedPtrs[i] = nullptr;
      cleanup();
      return out;
    }
    queuedBuffers[i] = b;
    if (ioctl(fd, VIDIOC_QBUF, &b) != 0) {
      cleanup();
      return out;
    }
  }

  v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  if (ioctl(fd, VIDIOC_STREAMON, &type) != 0) {
    cleanup();
    return out;
  }

  pollfd pfd{};
  pfd.fd = fd;
  pfd.events = POLLIN;

  const auto start = std::chrono::steady_clock::now();
  while (true) {
    const auto now = std::chrono::steady_clock::now();
    const auto elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(now - start).count();
    if (elapsedMs >= durationMs) break;

    const int timeoutMs = std::min<int>(40, durationMs - static_cast<int>(elapsedMs));
    const int prc = poll(&pfd, 1, std::max(1, timeoutMs));
    if (prc < 0) {
      if (errno == EINTR) continue;
      break;
    }
    if (prc == 0 || (pfd.revents & POLLIN) == 0) continue;

    v4l2_buffer dq{};
    dq.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    dq.memory = V4L2_MEMORY_MMAP;
    if (ioctl(fd, VIDIOC_DQBUF, &dq) != 0) {
      if (errno == EAGAIN || errno == EINTR) continue;
      break;
    }
    ++out.frames;
    if (ioctl(fd, VIDIOC_QBUF, &dq) != 0) break;
  }

  const double elapsedSec =
      std::chrono::duration_cast<std::chrono::duration<double>>(std::chrono::steady_clock::now() - start).count();
  if (elapsedSec > 0.0) out.fps = static_cast<double>(out.frames) / elapsedSec;
  out.ok = out.frames > 0;
  cleanup();
  return out;
}

static int capture_pref_bonus(uint32_t requestedPixFmt, CapturePreference capturePref) {
  if (capturePref == CapturePreference::MJPEG) {
    if (requestedPixFmt == V4L2_PIX_FMT_MJPEG) return 3;
    if (requestedPixFmt == V4L2_PIX_FMT_NV12) return 2;
    if (requestedPixFmt == V4L2_PIX_FMT_YUYV) return 1;
    return 0;
  }
  if (requestedPixFmt == V4L2_PIX_FMT_NV12) return 3;
  if (requestedPixFmt == V4L2_PIX_FMT_YUYV) return 2;
  if (requestedPixFmt == V4L2_PIX_FMT_MJPEG) return 1;
  return 0;
}

static std::optional<CaptureBenchScore> auto_benchmark_best_format(const std::string& devPath,
                                                                   int reqW, int reqH,
                                                                   CapturePreference capturePref,
                                                                   int totalDurationMs = 1200) {
  std::vector<uint32_t> candidates;
  if (capturePref == CapturePreference::MJPEG) candidates.push_back(V4L2_PIX_FMT_MJPEG);
  candidates.push_back(V4L2_PIX_FMT_NV12);
  candidates.push_back(V4L2_PIX_FMT_YUYV);

  const int eachMs = std::max(250, totalDurationMs / std::max(1, static_cast<int>(candidates.size())));
  std::optional<CaptureBenchScore> best;
  double bestScore = -1e9;

  for (uint32_t fmt : candidates) {
    CaptureBenchScore s = benchmark_capture_format(devPath, reqW, reqH, fmt, eachMs);
    if (!s.ok) continue;

    const double weighted = s.fps + 0.1 * static_cast<double>(capture_pref_bonus(fmt, capturePref));
    if (!best.has_value() || weighted > bestScore) {
      best = s;
      bestScore = weighted;
    }
  }
  return best;
}

static std::unordered_map<std::string, Rect> load_positions_csv(const std::string& file) {
  std::unordered_map<std::string, Rect> out;
  std::ifstream in(file);
  if (!in.is_open()) return out;

  std::string line;
  bool first = true;
  while (std::getline(in, line)) {
    line = trim(line);
    if (line.empty()) continue;
    if (first) { first = false; if (line.find("camera_id") != std::string::npos) continue; }

    std::stringstream ss(line);
    std::string camera_id, sx, sy, sw, sh;
    if (!std::getline(ss, camera_id, ',')) continue;
    if (!std::getline(ss, sx, ',')) continue;
    if (!std::getline(ss, sy, ',')) continue;
    if (!std::getline(ss, sw, ',')) continue;
    if (!std::getline(ss, sh, ',')) continue;

    Rect r;
    try {
      r.x = std::stoi(trim(sx));
      r.y = std::stoi(trim(sy));
      r.w = std::stoi(trim(sw));
      r.h = std::stoi(trim(sh));
    } catch (...) { continue; }
    out[trim(camera_id)] = r;
  }
  return out;
}

static bool save_positions_csv(const std::string& file,
                               const std::unordered_map<std::string, Rect>& pos) {
  std::ofstream out(file, std::ios::trunc);
  if (!out.is_open()) return false;
  out << "camera_id,x,y,w,h\n";
  for (const auto& kv : pos) {
    out << kv.first << "," << kv.second.x << "," << kv.second.y << ","
        << kv.second.w << "," << kv.second.h << "\n";
  }
  return true;
}

static std::unordered_map<std::string, Resolution> load_resolutions_csv(const std::string& file) {
  std::unordered_map<std::string, Resolution> out;
  std::ifstream in(file);
  if (!in.is_open()) return out;

  std::string line;
  bool first = true;
  while (std::getline(in, line)) {
    line = trim(line);
    if (line.empty()) continue;
    if (first) {
      first = false;
      if (line.find("camera_id") != std::string::npos) continue;
    }

    std::stringstream ss(line);
    std::string camera_id, sw, sh;
    if (!std::getline(ss, camera_id, ',')) continue;
    if (!std::getline(ss, sw, ',')) continue;
    if (!std::getline(ss, sh, ',')) continue;

    Resolution r;
    try {
      r.w = std::stoi(trim(sw));
      r.h = std::stoi(trim(sh));
    } catch (...) {
      continue;
    }
    if (r.w <= 0 || r.h <= 0) continue;
    out[trim(camera_id)] = r;
  }
  return out;
}

static bool save_resolutions_csv(const std::string& file,
                                 const std::unordered_map<std::string, Resolution>& res) {
  std::ofstream out(file, std::ios::trunc);
  if (!out.is_open()) return false;
  out << "camera_id,w,h\n";
  for (const auto& kv : res) {
    out << kv.first << "," << kv.second.w << "," << kv.second.h << "\n";
  }
  return true;
}

static Rect constrain_rect_to_aspect(Rect r, int aspectW, int aspectH) {
  if (aspectW <= 0 || aspectH <= 0 || r.w <= 0 || r.h <= 0) return r;

  const int64_t wFromH = std::max<int64_t>(1, (static_cast<int64_t>(r.h) * aspectW + aspectH / 2) / aspectH);
  const int64_t hFromW = std::max<int64_t>(1, (static_cast<int64_t>(r.w) * aspectH + aspectW / 2) / aspectW);

  const int deltaW = std::abs(static_cast<int>(wFromH) - r.w);
  const int deltaH = std::abs(static_cast<int>(hFromW) - r.h);
  if (deltaH <= deltaW) {
    r.h = static_cast<int>(hFromW);
  } else {
    r.w = static_cast<int>(wFromH);
  }
  r.w = std::max(1, r.w);
  r.h = std::max(1, r.h);
  return r;
}

static void x11_apply_window_hints(Display* dpy, Window w, const Rect& r, int aspectW = 0, int aspectH = 0) {
  XSizeHints hints{};
  hints.flags = USPosition | USSize | PPosition | PSize;
  hints.x = r.x;
  hints.y = r.y;
  hints.width = std::max(1, r.w);
  hints.height = std::max(1, r.h);

  if (aspectW > 0 && aspectH > 0) {
    int aw = aspectW;
    int ah = aspectH;
    const int g = std::gcd(std::abs(aw), std::abs(ah));
    if (g > 1) {
      aw /= g;
      ah /= g;
    }
    hints.flags |= PAspect;
    hints.min_aspect.x = aw;
    hints.min_aspect.y = ah;
    hints.max_aspect.x = aw;
    hints.max_aspect.y = ah;
  }
  XSetWMNormalHints(dpy, w, &hints);
}

static bool x11_get_window_root_xy(Display* dpy, Window w, int& rx, int& ry) {
  Window child;
  int wx, wy;
  if (!XTranslateCoordinates(dpy, w, DefaultRootWindow(dpy), 0, 0, &wx, &wy, &child)) return false;
  rx = wx;
  ry = wy;
  return true;
}

static void x11_apply_window_geometry(Display* dpy, Window w, const Rect& r) {
  x11_apply_window_hints(dpy, w, r);
  XMoveResizeWindow(dpy, w,
                    r.x, r.y,
                    static_cast<unsigned>(std::max(1, r.w)),
                    static_cast<unsigned>(std::max(1, r.h)));
}

static bool clamp_rect_to_screen(Rect& r, int screenW, int screenH) {
  if (screenW <= 0 || screenH <= 0) return false;

  const Rect before = r;
  r.w = std::max(1, std::min(r.w, screenW));
  r.h = std::max(1, std::min(r.h, screenH));
  r.x = std::max(0, std::min(r.x, screenW - r.w));
  r.y = std::max(0, std::min(r.y, screenH - r.h));

  return r.x != before.x || r.y != before.y || r.w != before.w || r.h != before.h;
}

// ---- GL helpers ----
static const char* kVS = R"(
attribute vec2 aPos;
attribute vec2 aUV;
varying vec2 vUV;
void main() {
  vUV = aUV;
  gl_Position = vec4(aPos, 0.0, 1.0);
}
)";

static const char* kFS_NV12 = R"(
precision mediump float;
varying vec2 vUV;
uniform sampler2D texY;
uniform sampler2D texUV;
void main() {
  float y = texture2D(texY, vUV).r;
  vec2 uv = texture2D(texUV, vUV).ra; // expects LUMINANCE_ALPHA-like mapping
  float u = uv.x - 0.5;
  float v = uv.y - 0.5;

  float r = y + 1.402 * v;
  float g = y - 0.344136 * u - 0.714136 * v;
  float b = y + 1.772 * u;
  gl_FragColor = vec4(r, g, b, 1.0);
}
)";

static const char* kFS_YUYV = R"(
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
varying vec2 vUV;
uniform sampler2D texYUYV;
uniform float frameWidth;
void main() {
  highp float srcX = floor(clamp(vUV.x, 0.0, 0.999999) * frameWidth);
  highp vec2 packedUV = vec2(clamp(vUV.x, 0.0, 1.0), clamp(vUV.y, 0.0, 1.0));
  vec4 yuyv = texture2D(texYUYV, packedUV);

  float y = (mod(srcX, 2.0) < 0.5) ? yuyv.r : yuyv.b;
  float u = yuyv.g - 0.5;
  float v = yuyv.a - 0.5;

  float r = y + 1.402 * v;
  float g = y - 0.344136 * u - 0.714136 * v;
  float b = y + 1.772 * u;
  gl_FragColor = vec4(r, g, b, 1.0);
}
)";

static const char* kFS_YUV_PLANAR = R"(
precision mediump float;
varying vec2 vUV;
uniform sampler2D texPlanarY;
uniform sampler2D texPlanarU;
uniform sampler2D texPlanarV;
void main() {
  float y = texture2D(texPlanarY, vUV).r;
  float u = texture2D(texPlanarU, vUV).r - 0.5;
  float v = texture2D(texPlanarV, vUV).r - 0.5;

  float r = y + 1.402 * v;
  float g = y - 0.344136 * u - 0.714136 * v;
  float b = y + 1.772 * u;
  gl_FragColor = vec4(r, g, b, 1.0);
}
)";

static const char* kFS_RGBA = R"(
precision mediump float;
varying vec2 vUV;
uniform sampler2D texRGBA;
void main() {
  gl_FragColor = texture2D(texRGBA, vUV);
}
)";

// Compact, light sans bitmap for low-visual-footprint telemetry.
static constexpr int kOverlayScale = 1;
static constexpr int kOverlayGlyphW = 5;
static constexpr int kOverlayGlyphH = 7;
static constexpr int kOverlayAdvance = (kOverlayGlyphW + 1) * kOverlayScale;
static constexpr int kOverlayMargin = 2;
static constexpr uint8_t kOverlayTextR = 240;
static constexpr uint8_t kOverlayTextG = 240;
static constexpr uint8_t kOverlayTextB = 240;
static constexpr uint8_t kOverlayTextA = 150;  // Intentionally translucent.
static constexpr uint8_t kOverlayShadowA = 52;

static void glyph_5x7(char c, uint8_t rows[7]) {
  std::memset(rows, 0, 7);
  switch (c) {
    case '0': { const uint8_t g[7] = {0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E}; std::memcpy(rows, g, 7); break; }
    case '1': { const uint8_t g[7] = {0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E}; std::memcpy(rows, g, 7); break; }
    case '2': { const uint8_t g[7] = {0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F}; std::memcpy(rows, g, 7); break; }
    case '3': { const uint8_t g[7] = {0x1E, 0x01, 0x01, 0x0E, 0x01, 0x01, 0x1E}; std::memcpy(rows, g, 7); break; }
    case '4': { const uint8_t g[7] = {0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02}; std::memcpy(rows, g, 7); break; }
    case '5': { const uint8_t g[7] = {0x1F, 0x10, 0x10, 0x1E, 0x01, 0x01, 0x1E}; std::memcpy(rows, g, 7); break; }
    case '6': { const uint8_t g[7] = {0x0E, 0x10, 0x10, 0x1E, 0x11, 0x11, 0x0E}; std::memcpy(rows, g, 7); break; }
    case '7': { const uint8_t g[7] = {0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08}; std::memcpy(rows, g, 7); break; }
    case '8': { const uint8_t g[7] = {0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E}; std::memcpy(rows, g, 7); break; }
    case '9': { const uint8_t g[7] = {0x0E, 0x11, 0x11, 0x0F, 0x01, 0x01, 0x0E}; std::memcpy(rows, g, 7); break; }
    case 'F': { const uint8_t g[7] = {0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10}; std::memcpy(rows, g, 7); break; }
    case 'P': { const uint8_t g[7] = {0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10}; std::memcpy(rows, g, 7); break; }
    case 'S': { const uint8_t g[7] = {0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E}; std::memcpy(rows, g, 7); break; }
    case 'X':
    case 'x': { const uint8_t g[7] = {0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11}; std::memcpy(rows, g, 7); break; }
    case '.': { const uint8_t g[7] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x06}; std::memcpy(rows, g, 7); break; }
    case ' ': { break; }
    default:  { const uint8_t g[7] = {0x1E, 0x01, 0x02, 0x04, 0x08, 0x00, 0x08}; std::memcpy(rows, g, 7); break; }
  }
}

static inline void overlay_put_pixel(std::vector<uint8_t>& rgba, int w, int h, int x, int y,
                                     uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
  if (x < 0 || y < 0 || x >= w || y >= h) return;
  const size_t idx = (static_cast<size_t>(y) * static_cast<size_t>(w) + static_cast<size_t>(x)) * 4u;
  rgba[idx + 0] = r;
  rgba[idx + 1] = g;
  rgba[idx + 2] = b;
  rgba[idx + 3] = a;
}

static void render_overlay_text_rgba(std::vector<uint8_t>& rgba, int w, int h, const std::string& text) {
  if (w <= 0 || h <= 0) return;
  rgba.assign(static_cast<size_t>(w) * static_cast<size_t>(h) * 4u, 0);

  const int baseX = kOverlayMargin;
  const int baseY = kOverlayMargin;

  int penX = baseX;
  for (char ch : text) {
    uint8_t glyph[7];
    glyph_5x7(ch, glyph);
    for (int gy = 0; gy < kOverlayGlyphH; ++gy) {
      const uint8_t bits = glyph[gy];
      for (int gx = 0; gx < kOverlayGlyphW; ++gx) {
        if ((bits & (1u << (kOverlayGlyphW - 1 - gx))) == 0) continue;
        for (int sy = 0; sy < kOverlayScale; ++sy) {
          for (int sx = 0; sx < kOverlayScale; ++sx) {
            // Soft shadow to keep text legible without a heavy background block.
            overlay_put_pixel(rgba, w, h,
                              penX + gx * kOverlayScale + sx + 1,
                              baseY + gy * kOverlayScale + sy + 1,
                              0, 0, 0, kOverlayShadowA);
            overlay_put_pixel(rgba, w, h,
                              penX + gx * kOverlayScale + sx,
                              baseY + gy * kOverlayScale + sy,
                              kOverlayTextR, kOverlayTextG, kOverlayTextB, kOverlayTextA);
          }
        }
      }
    }
    penX += kOverlayAdvance;
    if (penX + kOverlayAdvance >= w) break;
  }
}

static void overlay_dimensions_for_text(const std::string& text, int& outW, int& outH) {
  const int chars = std::max(1, static_cast<int>(text.size()));
  outW = kOverlayMargin + chars * kOverlayAdvance + kOverlayMargin;
  outH = kOverlayMargin + kOverlayGlyphH * kOverlayScale + kOverlayMargin;
  outW = std::clamp(outW, 56, 360);
  outH = std::clamp(outH, 12, 28);
}

static void make_overlay_quad(int viewportW, int viewportH,
                              int px, int py, int w, int h,
                              GLfloat out[16]) {
  const float invW = 1.0f / std::max(1, viewportW);
  const float invH = 1.0f / std::max(1, viewportH);
  const float x0 = -1.0f + 2.0f * static_cast<float>(px) * invW;
  const float x1 = -1.0f + 2.0f * static_cast<float>(px + w) * invW;
  const float y0 = -1.0f + 2.0f * static_cast<float>(py) * invH;
  const float y1 = -1.0f + 2.0f * static_cast<float>(py + h) * invH;
  const GLfloat quad[] = {
      x0, y0, 0.0f, 1.0f,
      x1, y0, 1.0f, 1.0f,
      x0, y1, 0.0f, 0.0f,
      x1, y1, 1.0f, 0.0f,
  };
  std::memcpy(out, quad, sizeof(quad));
}

static bool mjpeg_chroma_dimensions(int subsamp, int width, int height,
                                    bool& hasChroma, int& chromaW, int& chromaH) {
  hasChroma = true;
  chromaW = 0;
  chromaH = 0;
  switch (subsamp) {
    case TJSAMP_444:
      chromaW = width;
      chromaH = height;
      return true;
    case TJSAMP_422:
      chromaW = (width + 1) / 2;
      chromaH = height;
      return true;
    case TJSAMP_420:
      chromaW = (width + 1) / 2;
      chromaH = (height + 1) / 2;
      return true;
    case TJSAMP_GRAY:
      hasChroma = false;
      chromaW = 0;
      chromaH = 0;
      return true;
    case TJSAMP_440:
      chromaW = width;
      chromaH = (height + 1) / 2;
      return true;
    case TJSAMP_411:
      chromaW = (width + 3) / 4;
      chromaH = height;
      return true;
    default:
      return false;
  }
}

static GLuint compile_shader(GLenum type, const char* src) {
  GLuint s = glCreateShader(type);
  glShaderSource(s, 1, &src, nullptr);
  glCompileShader(s);
  GLint ok = 0;
  glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    char log[2048];
    glGetShaderInfoLog(s, sizeof(log), nullptr, log);
    std::cerr << "Shader compile error: " << log << "\n";
  }
  return s;
}

static GLuint make_program(const char* fsSrc) {
  GLuint vs = compile_shader(GL_VERTEX_SHADER, kVS);
  GLuint fs = compile_shader(GL_FRAGMENT_SHADER, fsSrc);
  GLuint p = glCreateProgram();
  glAttachShader(p, vs);
  glAttachShader(p, fs);
  glBindAttribLocation(p, 0, "aPos");
  glBindAttribLocation(p, 1, "aUV");
  glLinkProgram(p);
  GLint ok = 0;
  glGetProgramiv(p, GL_LINK_STATUS, &ok);
  if (!ok) {
    char log[2048];
    glGetProgramInfoLog(p, sizeof(log), nullptr, log);
    std::cerr << "Program link error: " << log << "\n";
  }
  glDeleteShader(vs);
  glDeleteShader(fs);
  return p;
}

static void init_plane_texture(GLuint& tex, GLenum format, int width, int height, GLint filter) {
  if (tex != 0) return;
  glGenTextures(1, &tex);
  glBindTexture(GL_TEXTURE_2D, tex);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, GL_UNSIGNED_BYTE, nullptr);
}

static void ensure_plane_texture(GLuint& tex, int& allocW, int& allocH,
                                 GLenum format, int width, int height, GLint filter) {
  if (tex != 0 && (allocW != width || allocH != height)) {
    glDeleteTextures(1, &tex);
    tex = 0;
  }
  init_plane_texture(tex, format, width, height, filter);
  allocW = width;
  allocH = height;
}

static void init_neutral_luma_texture(GLuint& tex) {
  if (tex != 0) return;
  const uint8_t neutral = 128;
  glGenTextures(1, &tex);
  glBindTexture(GL_TEXTURE_2D, tex);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, 1, 1, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, &neutral);
}

static bool upload_plane_texture(GLuint tex, GLenum format,
                                 int width, int height, int bytesPerPixel,
                                 const uint8_t* src, int srcStrideBytes,
                                 bool canUseUnpackRowLength,
                                 std::vector<uint8_t>& scratch) {
  if (!src || width <= 0 || height <= 0 || bytesPerPixel <= 0) return false;
  const int tightStride = width * bytesPerPixel;
  if (srcStrideBytes <= 0) srcStrideBytes = tightStride;
  if (srcStrideBytes < tightStride) return false;

  const uint8_t* uploadPtr = src;
  bool usedRowLength = false;

  if (srcStrideBytes != tightStride) {
    if (canUseUnpackRowLength && (srcStrideBytes % bytesPerPixel) == 0) {
      glPixelStorei(GL_UNPACK_ROW_LENGTH_EXT, srcStrideBytes / bytesPerPixel);
      usedRowLength = true;
    } else {
      const size_t tightStrideSize = static_cast<size_t>(tightStride);
      scratch.resize(tightStrideSize * static_cast<size_t>(height));
      for (int y = 0; y < height; ++y) {
        std::memcpy(scratch.data() + static_cast<size_t>(y) * tightStrideSize,
                    src + static_cast<size_t>(y) * static_cast<size_t>(srcStrideBytes),
                    tightStrideSize);
      }
      uploadPtr = scratch.data();
    }
  }

  glBindTexture(GL_TEXTURE_2D, tex);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, format, GL_UNSIGNED_BYTE, uploadPtr);
  if (usedRowLength) glPixelStorei(GL_UNPACK_ROW_LENGTH_EXT, 0);
  return true;
}

static inline uint8_t clamp_u8(int v) {
  if (v < 0) return 0;
  if (v > 255) return 255;
  return static_cast<uint8_t>(v);
}

// Conservative fallback path for drivers that struggle with the YUYV shader path.
static bool convert_yuyv_to_rgba(const uint8_t* src,
                                 int width, int height,
                                 int srcStrideBytes,
                                 std::vector<uint8_t>& outRgba) {
  if (!src || width <= 0 || height <= 0) return false;
  const int minStride = width * 2;
  if (srcStrideBytes <= 0) srcStrideBytes = minStride;
  if (srcStrideBytes < minStride) return false;
  if ((width % 2) != 0) return false;

  outRgba.resize(static_cast<size_t>(width) * static_cast<size_t>(height) * 4u);
  for (int y = 0; y < height; ++y) {
    const uint8_t* row = src + static_cast<size_t>(y) * static_cast<size_t>(srcStrideBytes);
    uint8_t* dst = outRgba.data() + static_cast<size_t>(y) * static_cast<size_t>(width) * 4u;

    for (int x = 0; x < width; x += 2) {
      const int y0 = row[0];
      const int u = row[1] - 128;
      const int y1 = row[2];
      const int v = row[3] - 128;

      const int rAdd = (91881 * v) >> 16;
      const int gSub = ((22554 * u) + (46802 * v)) >> 16;
      const int bAdd = (116130 * u) >> 16;

      dst[0] = clamp_u8(y0 + rAdd);
      dst[1] = clamp_u8(y0 - gSub);
      dst[2] = clamp_u8(y0 + bAdd);
      dst[3] = 255;

      dst[4] = clamp_u8(y1 + rAdd);
      dst[5] = clamp_u8(y1 - gSub);
      dst[6] = clamp_u8(y1 + bAdd);
      dst[7] = 255;

      row += 4;
      dst += 8;
    }
  }
  return true;
}

static void draw_quad(const GLfloat* quad) {
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), quad + 0);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), quad + 2);
  glEnableVertexAttribArray(1);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

static bool probe_renderer_context(EGLDisplay edpy, EGLConfig cfg, EGLContext ctx) {
  EGLint pbAttrs[] = {EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE};
  EGLSurface probe = eglCreatePbufferSurface(edpy, cfg, pbAttrs);
  if (probe == EGL_NO_SURFACE) {
    std::cerr << "Failed to create EGL probe surface for renderer query.\n";
    return false;
  }
  if (!eglMakeCurrent(edpy, probe, probe, ctx)) {
    std::cerr << "eglMakeCurrent failed during renderer query.\n";
    eglDestroySurface(edpy, probe);
    return false;
  }

  const char* eglVendor = eglQueryString(edpy, EGL_VENDOR);
  const char* glVendor = reinterpret_cast<const char*>(glGetString(GL_VENDOR));
  const char* glRenderer = reinterpret_cast<const char*>(glGetString(GL_RENDERER));
  std::cerr << "EGL vendor: " << (eglVendor ? eglVendor : "(null)") << "\n";
  std::cerr << "GL vendor: " << (glVendor ? glVendor : "(null)") << "\n";
  std::cerr << "GL renderer: " << (glRenderer ? glRenderer : "(null)") << "\n";
  g_activeRendererIsNvidia = false;
  g_activeRendererIsIntel = false;
  g_activeRendererIsAmd = false;
  auto classify_renderer = [&](const std::string& text) {
    const std::string lower = to_lower_copy(text);
    if (lower.find("nvidia") != std::string::npos) g_activeRendererIsNvidia = true;
    if (lower.find("intel") != std::string::npos) g_activeRendererIsIntel = true;
    if (lower.find("amd") != std::string::npos ||
        lower.find("radeon") != std::string::npos ||
        lower.find("ati") != std::string::npos) {
      g_activeRendererIsAmd = true;
    }
  };
  if (glVendor) classify_renderer(glVendor);
  if (glRenderer) classify_renderer(glRenderer);
  if (!glVendor || !glRenderer) {
    std::cerr << "Failed to query active GL renderer.\n";
  } else if (g_activeRendererIsAmd) {
    std::cerr << "Detected AMD renderer; enabling VAAPI MJPEG hardware decode probing.\n";
  }
  eglMakeCurrent(edpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  eglDestroySurface(edpy, probe);
  return glVendor && glRenderer;
}

struct MjpegHwDecoder {
  bool enabled{false};
  std::string backendName;
  AVCodecContext* codecCtx{nullptr};
  AVPacket* packet{nullptr};
  AVFrame* frame{nullptr};
  AVFrame* transferFrame{nullptr};
  AVFrame* outputFrame{nullptr};
  AVBufferRef* hwDeviceCtx{nullptr};
  AVPixelFormat expectedHwPixFmt{AV_PIX_FMT_NONE};
  bool enforceHwPixFmt{false};
  bool warnedDecode{false};
  bool warnedFormat{false};

  static enum AVPixelFormat pick_hw_format(AVCodecContext* ctx, const enum AVPixelFormat* pixFmts) {
    if (!ctx || !pixFmts) return AV_PIX_FMT_NONE;
    auto* self = reinterpret_cast<MjpegHwDecoder*>(ctx->opaque);
    if (!self || !self->enforceHwPixFmt || self->expectedHwPixFmt == AV_PIX_FMT_NONE) {
      return pixFmts[0];
    }
    for (const enum AVPixelFormat* p = pixFmts; *p != AV_PIX_FMT_NONE; ++p) {
      if (*p == self->expectedHwPixFmt) return *p;
    }
    return AV_PIX_FMT_NONE;
  }

  void reset() {
    enabled = false;
    backendName.clear();
    warnedDecode = false;
    warnedFormat = false;
    enforceHwPixFmt = false;
    expectedHwPixFmt = AV_PIX_FMT_NONE;
    if (packet) {
      av_packet_free(&packet);
      packet = nullptr;
    }
    if (frame) {
      av_frame_free(&frame);
      frame = nullptr;
    }
    if (transferFrame) {
      av_frame_free(&transferFrame);
      transferFrame = nullptr;
    }
    if (outputFrame) {
      av_frame_free(&outputFrame);
      outputFrame = nullptr;
    }
    if (codecCtx) {
      avcodec_free_context(&codecCtx);
      codecCtx = nullptr;
    }
    if (hwDeviceCtx) {
      av_buffer_unref(&hwDeviceCtx);
      hwDeviceCtx = nullptr;
    }
  }

  bool init(const std::string& devPath, bool allowCudaCuvid, bool allowVaapi,
            bool allowQsv, bool preferVaapi) {
    reset();

    struct Candidate {
      const char* label;
      const char* decoderName;
      AVHWDeviceType hwType;
      AVPixelFormat hwPixFmt;
      bool requireHwFormat;
    };
    std::vector<Candidate> candidates;
    if (allowCudaCuvid) {
      candidates.push_back({"CUDA/CUVID", "mjpeg_cuvid", AV_HWDEVICE_TYPE_CUDA, AV_PIX_FMT_CUDA, false});
    }
    auto add_qsv = [&]() {
      if (allowQsv) {
        candidates.push_back({"Intel QSV", "mjpeg_qsv", AV_HWDEVICE_TYPE_QSV, AV_PIX_FMT_QSV, false});
      }
    };
    auto add_vaapi = [&]() {
      if (allowVaapi) {
        candidates.push_back({"VAAPI", "mjpeg", AV_HWDEVICE_TYPE_VAAPI, AV_PIX_FMT_VAAPI, true});
      }
    };
    if (preferVaapi) {
      add_vaapi();
      add_qsv();
    } else {
      add_qsv();
      add_vaapi();
    }

    static bool cudaUnavailable = false;
    static bool qsvUnavailable = false;
    static bool vaapiUnavailable = false;

    for (const auto& candidate : candidates) {
      if (candidate.hwType == AV_HWDEVICE_TYPE_CUDA && cudaUnavailable) continue;
      if (candidate.hwType == AV_HWDEVICE_TYPE_QSV && qsvUnavailable) continue;
      if (candidate.hwType == AV_HWDEVICE_TYPE_VAAPI && vaapiUnavailable) continue;

      const AVCodec* codec = avcodec_find_decoder_by_name(candidate.decoderName);
      if (!codec) continue;

      AVCodecContext* tryCtx = avcodec_alloc_context3(codec);
      if (!tryCtx) continue;

      AVBufferRef* tryDevice = nullptr;
      if (candidate.hwType != AV_HWDEVICE_TYPE_NONE) {
        int devRc = AVERROR(ENODEV);
        std::string selectedHwDevice;
        std::vector<std::string> deviceCandidates;
        if (candidate.hwType == AV_HWDEVICE_TYPE_VAAPI) {
          const char* forcedVaapi = std::getenv("USBCAMV4L_VAAPI_DEVICE");
          if (forcedVaapi && *forcedVaapi) {
            deviceCandidates.emplace_back(forcedVaapi);
          }
          for (const auto& node : enumerate_drm_render_nodes()) {
            if (std::find(deviceCandidates.begin(), deviceCandidates.end(), node) == deviceCandidates.end()) {
              deviceCandidates.push_back(node);
            }
          }
          // Fallback to libavutil default device selection if explicit nodes failed.
          deviceCandidates.emplace_back();
        } else {
          deviceCandidates.emplace_back();
        }

        bool temporarilyDisabledZinkForVaapi = false;
        std::string savedMesaOverride;
        std::string savedGalliumDriver;
        std::string savedKopperDri2;
        const bool hadMesaOverride = std::getenv("MESA_LOADER_DRIVER_OVERRIDE") != nullptr;
        const bool hadGalliumDriver = std::getenv("GALLIUM_DRIVER") != nullptr;
        const bool hadKopperDri2 = std::getenv("LIBGL_KOPPER_DRI2") != nullptr;
        if (candidate.hwType == AV_HWDEVICE_TYPE_VAAPI &&
            !env_is_truthy("USBCAMV4L_KEEP_ZINK_FOR_VAAPI")) {
          const char* mesaOverride = std::getenv("MESA_LOADER_DRIVER_OVERRIDE");
          if (mesaOverride && to_lower_copy(trim(mesaOverride)) == "zink") {
            if (mesaOverride) savedMesaOverride = mesaOverride;
            if (const char* g = std::getenv("GALLIUM_DRIVER")) savedGalliumDriver = g;
            if (const char* k = std::getenv("LIBGL_KOPPER_DRI2")) savedKopperDri2 = k;
            (void)unsetenv("MESA_LOADER_DRIVER_OVERRIDE");
            (void)unsetenv("GALLIUM_DRIVER");
            (void)unsetenv("LIBGL_KOPPER_DRI2");
            temporarilyDisabledZinkForVaapi = true;
            std::cerr << "Temporarily disabling Zink override for VAAPI device probing.\n";
          }
        }

        for (const auto& dev : deviceCandidates) {
          const char* devArg = dev.empty() ? nullptr : dev.c_str();
          devRc = av_hwdevice_ctx_create(&tryDevice, candidate.hwType, devArg, nullptr, 0);
          if (devRc >= 0) {
            selectedHwDevice = dev;
            break;
          }
          if (candidate.hwType == AV_HWDEVICE_TYPE_VAAPI && !dev.empty()) {
            std::cerr << "VAAPI device probe failed for " << dev
                      << ": " << av_error_to_string(devRc) << "\n";
          }
        }

        if (temporarilyDisabledZinkForVaapi) {
          if (hadMesaOverride) (void)setenv("MESA_LOADER_DRIVER_OVERRIDE", savedMesaOverride.c_str(), 1);
          else (void)unsetenv("MESA_LOADER_DRIVER_OVERRIDE");
          if (hadGalliumDriver) (void)setenv("GALLIUM_DRIVER", savedGalliumDriver.c_str(), 1);
          else (void)unsetenv("GALLIUM_DRIVER");
          if (hadKopperDri2) (void)setenv("LIBGL_KOPPER_DRI2", savedKopperDri2.c_str(), 1);
          else (void)unsetenv("LIBGL_KOPPER_DRI2");
        }

        if (devRc < 0) {
          if (candidate.hwType == AV_HWDEVICE_TYPE_CUDA) cudaUnavailable = true;
          if (candidate.hwType == AV_HWDEVICE_TYPE_QSV) qsvUnavailable = true;
          if (candidate.hwType == AV_HWDEVICE_TYPE_VAAPI) vaapiUnavailable = true;
          avcodec_free_context(&tryCtx);
          continue;
        }
        if (candidate.hwType == AV_HWDEVICE_TYPE_VAAPI) {
          if (!selectedHwDevice.empty()) {
            std::cerr << "Using VAAPI device " << selectedHwDevice << " for " << devPath << ".\n";
          } else {
            std::cerr << "Using default VAAPI device selection for " << devPath << ".\n";
          }
        }
        tryCtx->hw_device_ctx = av_buffer_ref(tryDevice);
        if (!tryCtx->hw_device_ctx) {
          av_buffer_unref(&tryDevice);
          avcodec_free_context(&tryCtx);
          continue;
        }
      }

      expectedHwPixFmt = candidate.hwPixFmt;
      enforceHwPixFmt = candidate.requireHwFormat;
      if (candidate.requireHwFormat) {
        tryCtx->opaque = this;
        tryCtx->get_format = &MjpegHwDecoder::pick_hw_format;
      }

      tryCtx->thread_count = 1;
      tryCtx->flags |= AV_CODEC_FLAG_LOW_DELAY;
      tryCtx->flags2 |= AV_CODEC_FLAG2_FAST;
      tryCtx->pkt_timebase = AVRational{1, 1000000};
      const int openRc = avcodec_open2(tryCtx, codec, nullptr);
      if (openRc != 0) {
        if (tryDevice) av_buffer_unref(&tryDevice);
        avcodec_free_context(&tryCtx);
        continue;
      }

      packet = av_packet_alloc();
      frame = av_frame_alloc();
      transferFrame = av_frame_alloc();
      outputFrame = av_frame_alloc();
      if (!packet || !frame || !transferFrame || !outputFrame) {
        if (tryDevice) av_buffer_unref(&tryDevice);
        avcodec_free_context(&tryCtx);
        reset();
        continue;
      }

      codecCtx = tryCtx;
      hwDeviceCtx = tryDevice;
      enabled = true;
      backendName = candidate.label;
      warnedDecode = false;
      warnedFormat = false;
      std::cerr << "Enabled MJPEG hardware decode for " << devPath
                << " via " << backendName << ".\n";
      return true;
    }

    reset();
    return false;
  }

  bool decode_frame(const uint8_t* bitstream, size_t bytesUsed, AVFrame*& outFrame) {
    outFrame = nullptr;
    if (!enabled || !codecCtx || !packet || !frame || !transferFrame || !outputFrame ||
        !bitstream || bytesUsed == 0) {
      return false;
    }
    if (bytesUsed > static_cast<size_t>(std::numeric_limits<int>::max())) return false;

    av_packet_unref(packet);
    packet->data = const_cast<uint8_t*>(bitstream);
    packet->size = static_cast<int>(bytesUsed);

    int rc = avcodec_send_packet(codecCtx, packet);
    if (rc == AVERROR(EAGAIN)) {
      while (true) {
        av_frame_unref(frame);
        const int drainRc = avcodec_receive_frame(codecCtx, frame);
        if (drainRc == AVERROR(EAGAIN) || drainRc == AVERROR_EOF) break;
        if (drainRc < 0) break;
      }
      rc = avcodec_send_packet(codecCtx, packet);
    }
    if (rc < 0) {
      if (!warnedDecode) {
        std::cerr << "MJPEG hardware decode send_packet failed (" << backendName
                  << "): " << av_error_to_string(rc) << "\n";
        warnedDecode = true;
      }
      return false;
    }

    av_frame_unref(outputFrame);
    bool haveOutput = false;
    while (true) {
      av_frame_unref(frame);
      av_frame_unref(transferFrame);

      rc = avcodec_receive_frame(codecCtx, frame);
      if (rc == AVERROR(EAGAIN) || rc == AVERROR_EOF) break;
      if (rc < 0) {
        if (!warnedDecode) {
          std::cerr << "MJPEG hardware decode receive_frame failed (" << backendName
                    << "): " << av_error_to_string(rc) << "\n";
          warnedDecode = true;
        }
        return false;
      }

      AVFrame* candidate = frame;
      const AVPixFmtDescriptor* pixDesc =
          av_pix_fmt_desc_get(static_cast<AVPixelFormat>(frame->format));
      if (pixDesc && (pixDesc->flags & AV_PIX_FMT_FLAG_HWACCEL)) {
        rc = av_hwframe_transfer_data(transferFrame, frame, 0);
        if (rc < 0) {
          std::cerr << "MJPEG hardware frame transfer failed (" << backendName
                    << "): " << av_error_to_string(rc)
                    << ". Disabling this backend.\n";
          reset();
          return false;
        }
        candidate = transferFrame;
      }

      bool isNV12 = false;
      bool hasChroma = false;
      int chromaW = 0;
      int chromaH = 0;
      const AVPixelFormat pixFmt = static_cast<AVPixelFormat>(candidate->format);
      const bool isPackedYuyv = (pixFmt == AV_PIX_FMT_YUYV422);
      if (!isPackedYuyv &&
          !ffmpeg_planar_yuv_info(pixFmt, candidate->width, candidate->height,
                                  isNV12, hasChroma, chromaW, chromaH)) {
        if (!warnedFormat) {
          std::cerr << "MJPEG hardware decode output format is "
                    << av_get_pix_fmt_name(pixFmt)
                    << " (unsupported). Disabling this backend.\n";
          warnedFormat = true;
        }
        reset();
        return false;
      }
      if (candidate->width <= 0 || candidate->height <= 0 || !candidate->data[0]) {
        continue;
      }
      if (candidate->linesize[0] <= 0) {
        continue;
      }
      if (isPackedYuyv) {
        if (candidate->linesize[0] < candidate->width * 2) continue;
      } else {
        if (hasChroma) {
          if (!candidate->data[1]) continue;
          if (!isNV12 && !candidate->data[2]) continue;
        }
        if (hasChroma && candidate->linesize[1] <= 0) {
          continue;
        }
        if (hasChroma && !isNV12 && candidate->linesize[2] <= 0) {
          continue;
        }
      }

      av_frame_unref(outputFrame);
      if (av_frame_ref(outputFrame, candidate) != 0) {
        continue;
      }
      haveOutput = true;
    }

    if (haveOutput) {
      warnedDecode = false;
      outFrame = outputFrame;
      return true;
    }
    return false;
  }
};

// ---- V4L2 + DMABUF ----
struct V4L2DmabufCam {
  CamInfo cam;
  int requestedW{DEFAULT_FRAME_W};
  int requestedH{DEFAULT_FRAME_H};
  bool lowLatency{true};
  uint32_t preferredPixFmt{0}; // Optional startup benchmark hint.
  int requestedBufferCount{3}; // Adaptive queue depth [2..4].
  bool allowCudaHwMjpeg{false};
  bool allowFullHwMjpeg{false};
  bool allowVaapiHwMjpeg{false};
  bool allowQsvHwMjpeg{false};
  bool preferVaapiHwMjpeg{false};
  bool preferCpuYuyv{false};
  bool yuyvCpuConvert{false};
  bool record{false};
  int fd{-1};
  int width{0}, height{0};
  int strideY{0}, strideUV{0};
  bool nv12{false};
  bool yuyv{false};
  bool mjpeg{false};
  GLuint uploadYTex{0};
  int uploadYTexW{0};
  int uploadYTexH{0};
  GLuint uploadUVTex{0};
  int uploadUVTexW{0};
  int uploadUVTexH{0};
  GLuint yuyvTex{0};
  int yuyvTexW{0};
  int yuyvTexH{0};
  GLuint mjpegYTex{0};
  int mjpegYTexW{0};
  int mjpegYTexH{0};
  GLuint mjpegUTex{0};
  int mjpegUTexW{0};
  int mjpegUTexH{0};
  GLuint mjpegVTex{0};
  int mjpegVTexW{0};
  int mjpegVTexH{0};
  GLuint neutralChromaTex{0};
  GLuint overlayTex{0};
  int overlayTexW{0};
  int overlayTexH{0};
  std::vector<uint8_t> scratchY;
  std::vector<uint8_t> scratchUV;
  std::vector<uint8_t> scratchYuyv;
  std::vector<uint8_t> yuyvRgba;
  std::vector<uint8_t> scratchMjpegY;
  std::vector<uint8_t> scratchMjpegU;
  std::vector<uint8_t> scratchMjpegV;
  std::vector<uint8_t> overlayRgba;
  std::vector<uint8_t> recordRgba;
  std::string overlayText;
  double fpsValue{0.0};
  int fpsFrameCount{0};
  std::chrono::steady_clock::time_point fpsWindowStart{};
  bool fpsStarted{false};
  bool frameClockStarted{false};
  std::chrono::steady_clock::time_point lastFrameTs{};
  std::chrono::steady_clock::time_point lastReconnectAttempt{};
  int consecutiveDqErrors{0};
  double frameIntervalEwmaMs{0.0};
  int stutterEvents{0};
  bool reconnectPending{false};

  MjpegHwDecoder mjpegHw;

  tjhandle tjDecoder{nullptr};
  int mjpegSubsamp{-1};
  bool mjpegHasChroma{false};
  int mjpegPlaneW[3]{0, 0, 0};
  int mjpegPlaneH[3]{0, 0, 0};
  int mjpegPlaneStride[3]{0, 0, 0};
  std::vector<uint8_t> mjpegPlaneY;
  std::vector<uint8_t> mjpegPlaneU;
  std::vector<uint8_t> mjpegPlaneV;

  bool warnedMjpegHeader{false};
  bool warnedMjpegDecode{false};
  bool warnedMjpegSizeMismatch{false};
  bool warnedMjpegUnsupportedSubsamp{false};
  bool warnedMjpegHwSizeMismatch{false};

  RawVideoRecorder recorder;

  struct Buf {
    void* ptr{nullptr};
    size_t len{0};
    int dmabuf{-1};
    EGLImageKHR yImg{EGL_NO_IMAGE_KHR};
    EGLImageKHR uvImg{EGL_NO_IMAGE_KHR};
    GLuint yTex{0};
    GLuint uvTex{0};
  };
  std::vector<Buf> bufs;

  bool reconfigure_mjpeg_planes(int subsamp, int frameW, int frameH) {
    bool hasChroma = false;
    int chromaW = 0;
    int chromaH = 0;
    if (!mjpeg_chroma_dimensions(subsamp, frameW, frameH, hasChroma, chromaW, chromaH)) {
      return false;
    }

    const bool sameLayout =
        (mjpegSubsamp == subsamp) &&
        (mjpegHasChroma == hasChroma) &&
        (mjpegPlaneW[0] == frameW) &&
        (mjpegPlaneH[0] == frameH) &&
        (!hasChroma || ((mjpegPlaneW[1] == chromaW) && (mjpegPlaneH[1] == chromaH)));
    if (sameLayout) return true;

    mjpegSubsamp = subsamp;
    mjpegHasChroma = hasChroma;

    mjpegPlaneW[0] = frameW;
    mjpegPlaneH[0] = frameH;
    mjpegPlaneStride[0] = frameW;
    mjpegPlaneY.resize(static_cast<size_t>(mjpegPlaneStride[0]) * static_cast<size_t>(mjpegPlaneH[0]));

    if (mjpegHasChroma) {
      mjpegPlaneW[1] = chromaW;
      mjpegPlaneH[1] = chromaH;
      mjpegPlaneStride[1] = chromaW;
      mjpegPlaneW[2] = chromaW;
      mjpegPlaneH[2] = chromaH;
      mjpegPlaneStride[2] = chromaW;
      mjpegPlaneU.resize(static_cast<size_t>(mjpegPlaneStride[1]) * static_cast<size_t>(mjpegPlaneH[1]));
      mjpegPlaneV.resize(static_cast<size_t>(mjpegPlaneStride[2]) * static_cast<size_t>(mjpegPlaneH[2]));
    } else {
      mjpegPlaneW[1] = 0;
      mjpegPlaneH[1] = 0;
      mjpegPlaneStride[1] = 0;
      mjpegPlaneW[2] = 0;
      mjpegPlaneH[2] = 0;
      mjpegPlaneStride[2] = 0;
      mjpegPlaneU.clear();
      mjpegPlaneV.clear();
    }

    if (mjpegYTex) glDeleteTextures(1, &mjpegYTex);
    if (mjpegUTex) glDeleteTextures(1, &mjpegUTex);
    if (mjpegVTex) glDeleteTextures(1, &mjpegVTex);
    mjpegYTex = 0;
    mjpegYTexW = 0;
    mjpegYTexH = 0;
    mjpegUTex = 0;
    mjpegUTexW = 0;
    mjpegUTexH = 0;
    mjpegVTex = 0;
    mjpegVTexW = 0;
    mjpegVTexH = 0;
    scratchMjpegY.clear();
    scratchMjpegU.clear();
    scratchMjpegV.clear();
    return true;
  }

  bool open_and_configure(CapturePreference capturePref) {
    fd = ::open(cam.devPath.c_str(), O_RDWR | O_NONBLOCK);
    if (fd < 0) { std::cerr << "open failed: " << cam.devPath << "\n"; return false; }

    nv12 = false;
    yuyv = false;
    mjpeg = false;
    yuyvCpuConvert = false;
    warnedMjpegHeader = false;
    warnedMjpegDecode = false;
    warnedMjpegSizeMismatch = false;
    warnedMjpegUnsupportedSubsamp = false;
    warnedMjpegHwSizeMismatch = false;
    overlayText.clear();
    overlayRgba.clear();
    fpsValue = 0.0;
    fpsFrameCount = 0;
    fpsStarted = false;
    frameClockStarted = false;
    consecutiveDqErrors = 0;
    frameIntervalEwmaMs = 0.0;
    stutterEvents = 0;
    reconnectPending = false;
    lastReconnectAttempt = std::chrono::steady_clock::time_point{};
    mjpegHw.reset();

    auto fail = [&]() -> bool {
      for (auto& b : bufs) {
        if (b.ptr && b.ptr != MAP_FAILED) munmap(b.ptr, b.len);
        if (b.dmabuf >= 0) close(b.dmabuf);
        b = Buf{};
      }
      bufs.clear();
      recorder.stop();
      mjpegHw.reset();
      if (tjDecoder) {
        tjDestroy(tjDecoder);
        tjDecoder = nullptr;
      }
      mjpegPlaneY.clear();
      mjpegPlaneU.clear();
      mjpegPlaneV.clear();
      yuyvRgba.clear();
      recordRgba.clear();
      mjpegSubsamp = -1;
      mjpegHasChroma = false;
      mjpegPlaneW[0] = mjpegPlaneW[1] = mjpegPlaneW[2] = 0;
      mjpegPlaneH[0] = mjpegPlaneH[1] = mjpegPlaneH[2] = 0;
      mjpegPlaneStride[0] = mjpegPlaneStride[1] = mjpegPlaneStride[2] = 0;
      if (fd >= 0) {
        close(fd);
        fd = -1;
      }
      return false;
    };

    v4l2_format fmt{};
    bool configured = false;
    std::vector<uint32_t> formatOrder;
    auto push_format = [&](uint32_t f) {
      if (f == 0) return;
      if (std::find(formatOrder.begin(), formatOrder.end(), f) == formatOrder.end()) {
        formatOrder.push_back(f);
      }
    };
    push_format(preferredPixFmt);
    if (capturePref == CapturePreference::MJPEG) push_format(V4L2_PIX_FMT_MJPEG);
    push_format(V4L2_PIX_FMT_NV12);
    push_format(V4L2_PIX_FMT_YUYV);

    uint32_t requestedFmt = 0;
    for (uint32_t f : formatOrder) {
      if (!try_set_capture_format(fd, requestedW, requestedH, f, fmt)) continue;
      configured = true;
      requestedFmt = f;
      break;
    }
    if (configured) {
      const uint32_t actualFmt = fmt.fmt.pix.pixelformat;
      mjpeg = is_mjpeg_fourcc(actualFmt);
      nv12 = (actualFmt == V4L2_PIX_FMT_NV12);
      yuyv = (actualFmt == V4L2_PIX_FMT_YUYV);
      (void)requestedFmt;
    }
    if (!configured) {
      if (capturePref == CapturePreference::MJPEG) {
        std::cerr << "VIDIOC_S_FMT failed for MJPEG, NV12, and YUYV: " << cam.devPath
                  << " (requested " << requestedW << "x" << requestedH << ")\n";
      } else {
        std::cerr << "VIDIOC_S_FMT failed for NV12 and YUYV: " << cam.devPath
                  << " (requested " << requestedW << "x" << requestedH << ")\n";
      }
      return fail();
    }

    width = (int)fmt.fmt.pix.width;
    height = (int)fmt.fmt.pix.height;
    if (yuyv && (width % 2) != 0) {
      std::cerr << "Unsupported odd-width YUYV frame from " << cam.devPath
                << ": " << width << "x" << height << "\n";
      return fail();
    }
    strideY = (int)fmt.fmt.pix.bytesperline;
    if (strideY <= 0) {
      if (nv12) strideY = width;
      else if (yuyv) strideY = width * 2;
      else strideY = 0;
    }
    strideUV = nv12 ? strideY : 0;

    if (mjpeg) {
      tjDecoder = tjInitDecompress();
      if (!tjDecoder) {
        std::cerr << "tjInitDecompress failed for " << cam.devPath
                  << ": " << tjGetErrorStr() << "\n";
        return fail();
      }
      if (!mjpegHw.init(cam.devPath, allowCudaHwMjpeg, allowVaapiHwMjpeg,
                        allowQsvHwMjpeg, preferVaapiHwMjpeg)) {
        std::cerr << "MJPEG hardware decode unavailable for " << cam.devPath
                  << "; using turbojpeg CPU decode fallback.\n";
      }
      std::cerr << "MJPEG enabled for " << cam.devPath
                << "; hardware decode is preferred, with turbojpeg fallback."
                << " Color conversion/scaling remain on GPU.\n";
    } else if (capturePref == CapturePreference::MJPEG) {
      std::cerr << "Warning: " << cam.devPath
                << " did not accept MJPEG; using " << fourcc_to_string(fmt.fmt.pix.pixelformat)
                << " instead.\n";
    }

    yuyvCpuConvert = yuyv && preferCpuYuyv;
    if (yuyv) {
      if (yuyvCpuConvert) {
        std::cerr << "Warning: " << cam.devPath
                  << " is YUYV; using CPU YUYV unpack + GPU RGBA render fallback.\n";
      } else {
        std::cerr << "Warning: " << cam.devPath
                  << " is YUYV; using GPU shader conversion path.\n";
      }
    }

    std::cerr << "Configured " << cam.devPath << ": "
              << width << "x" << height << " " << fourcc_to_string(fmt.fmt.pix.pixelformat)
              << " (stride=" << strideY << ")\n";

    v4l2_requestbuffers req{};
    req.count = static_cast<uint32_t>(std::clamp(requestedBufferCount, 2, 4));
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;
    if (ioctl(fd, VIDIOC_REQBUFS, &req) != 0 || req.count < 2) {
      std::cerr << "VIDIOC_REQBUFS failed: " << cam.devPath << "\n";
      return fail();
    }

    bufs.resize(req.count);

    for (unsigned i = 0; i < req.count; ++i) {
      v4l2_buffer b{};
      b.type = req.type;
      b.memory = req.memory;
      b.index = i;
      if (ioctl(fd, VIDIOC_QUERYBUF, &b) != 0) {
        std::cerr << "VIDIOC_QUERYBUF failed\n";
        return fail();
      }

      bufs[i].len = b.length;
      bufs[i].ptr = mmap(nullptr, b.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, b.m.offset);
      if (bufs[i].ptr == MAP_FAILED) {
        std::cerr << "mmap failed\n";
        bufs[i].ptr = nullptr;
        return fail();
      }

      if (nv12) {
        v4l2_exportbuffer eb{};
        eb.type = req.type;
        eb.index = i;
        eb.flags = O_CLOEXEC;
        if (ioctl(fd, VIDIOC_EXPBUF, &eb) != 0) {
          std::cerr << "VIDIOC_EXPBUF failed: " << strerror(errno) << "\n";
          bufs[i].dmabuf = -1;
        } else {
          bufs[i].dmabuf = eb.fd;
        }
      } else {
        bufs[i].dmabuf = -1;
      }

      if (ioctl(fd, VIDIOC_QBUF, &b) != 0) {
        std::cerr << "VIDIOC_QBUF failed\n";
        return fail();
      }
    }

    v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    if (ioctl(fd, VIDIOC_STREAMON, &type) != 0) {
      std::cerr << "VIDIOC_STREAMON failed\n";
      return fail();
    }
    lastFrameTs = std::chrono::steady_clock::now();
    frameClockStarted = false;
    consecutiveDqErrors = 0;
    reconnectPending = false;
    return true;
  }

  void shutdown(PFNEGLDESTROYIMAGEKHRPROC eglDestroyImageKHR, EGLDisplay edpy) {
    if (fd >= 0) {
      v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
      ioctl(fd, VIDIOC_STREAMOFF, &type);
    }
    for (auto& b : bufs) {
      if (b.yTex) glDeleteTextures(1, &b.yTex);
      if (b.uvTex) glDeleteTextures(1, &b.uvTex);
      if (b.yImg != EGL_NO_IMAGE_KHR && eglDestroyImageKHR) eglDestroyImageKHR(edpy, b.yImg);
      if (b.uvImg != EGL_NO_IMAGE_KHR && eglDestroyImageKHR) eglDestroyImageKHR(edpy, b.uvImg);
      if (b.ptr && b.ptr != MAP_FAILED) munmap(b.ptr, b.len);
      if (b.dmabuf >= 0) close(b.dmabuf);
      b = Buf{};
    }
    bufs.clear();
    recorder.stop();
    if (uploadYTex) glDeleteTextures(1, &uploadYTex);
    if (uploadUVTex) glDeleteTextures(1, &uploadUVTex);
    if (yuyvTex) glDeleteTextures(1, &yuyvTex);
    if (mjpegYTex) glDeleteTextures(1, &mjpegYTex);
    if (mjpegUTex) glDeleteTextures(1, &mjpegUTex);
    if (mjpegVTex) glDeleteTextures(1, &mjpegVTex);
    if (neutralChromaTex) glDeleteTextures(1, &neutralChromaTex);
    if (overlayTex) glDeleteTextures(1, &overlayTex);
    uploadYTex = 0;
    uploadYTexW = 0;
    uploadYTexH = 0;
    uploadUVTex = 0;
    uploadUVTexW = 0;
    uploadUVTexH = 0;
    yuyvTex = 0;
    yuyvTexW = 0;
    yuyvTexH = 0;
    mjpegYTex = 0;
    mjpegYTexW = 0;
    mjpegYTexH = 0;
    mjpegUTex = 0;
    mjpegUTexW = 0;
    mjpegUTexH = 0;
    mjpegVTex = 0;
    mjpegVTexW = 0;
    mjpegVTexH = 0;
    neutralChromaTex = 0;
    overlayTex = 0;
    overlayTexW = 0;
    overlayTexH = 0;
    scratchY.clear();
    scratchUV.clear();
    scratchYuyv.clear();
    yuyvRgba.clear();
    scratchMjpegY.clear();
    scratchMjpegU.clear();
    scratchMjpegV.clear();
    overlayRgba.clear();
    recordRgba.clear();
    overlayText.clear();
    fpsValue = 0.0;
    fpsFrameCount = 0;
    fpsStarted = false;
    frameClockStarted = false;
    consecutiveDqErrors = 0;
    frameIntervalEwmaMs = 0.0;
    stutterEvents = 0;
    reconnectPending = false;
    lastReconnectAttempt = std::chrono::steady_clock::time_point{};
    mjpegHw.reset();
    mjpegPlaneY.clear();
    mjpegPlaneU.clear();
    mjpegPlaneV.clear();
    mjpegSubsamp = -1;
    mjpegHasChroma = false;
    mjpegPlaneW[0] = mjpegPlaneW[1] = mjpegPlaneW[2] = 0;
    mjpegPlaneH[0] = mjpegPlaneH[1] = mjpegPlaneH[2] = 0;
    mjpegPlaneStride[0] = mjpegPlaneStride[1] = mjpegPlaneStride[2] = 0;
    if (tjDecoder) {
      tjDestroy(tjDecoder);
      tjDecoder = nullptr;
    }
    if (fd >= 0) { close(fd); fd = -1; }
  }
};

struct XWin {
  Window win{0};
  EGLSurface surf{EGL_NO_SURFACE};
  Rect geom{};
  Rect pendingGeom{};
  bool resizePending{false};
  std::chrono::steady_clock::time_point lastResizeEvent{};
};

static void print_usbcamv4l_help(const char* argv0) {
  std::cout
      << "usbcamv4l - multi USB camera viewer (V4L2 + EGL/GLES)\n\n"
      << "Usage:\n"
      << "  " << argv0 << " [OPTIONS]\n\n"
      << "Options (alphabetical):\n"
      << "  -b, --bench-ms N\n"
      << "      Startup benchmark budget per camera in milliseconds (300-4000).\n"
      << "  -f, --fps\n"
      << "      Enable live resolution+FPS overlay.\n"
      << "  -h, --help\n"
      << "      Show this help and exit.\n"
      << "  -l, --list-cameras\n"
      << "      List formats, resolutions, and FPS modes, then exit.\n"
      << "  -m, --mjpeg\n"
      << "      Prefer MJPEG capture (fallback: NV12 then YUYV).\n"
      << "  -M, --mjpeg-hw\n"
      << "      Enable full hardware MJPEG decode backend probing.\n"
      << "  -B, --no-bench\n"
      << "      Disable startup capture-path benchmark selection.\n"
      << "  -C, --no-control\n"
      << "      Disable runtime control socket.\n"
      << "  -r, --rec\n"
      << "      Enable recording for all cameras.\n"
      << "  -F, --rec-fast\n"
      << "      Recording profile: fast throughput (default recording profile).\n"
      << "  -Q, --rec-quality\n"
      << "      Recording profile: higher quality, lower throughput.\n"
      << "  -s, --res\n"
      << "      Choose one common capture height for all cameras.\n"
      << "  -e, --res-each\n"
      << "      Choose capture resolution separately for each camera.\n"
      << "  -R, --reset\n"
      << "      Reset saved window position and resolution state.\n"
      << "  -S, --strict-sync\n"
      << "      Force strict GPU sync (glFinish every frame).\n\n"
      << "Compatibility aliases:\n"
      << "  Legacy long flags with single dash are accepted (example: -mjpeg).\n"
      << "  Common misspellings are normalized (example: --mpjeg -> --mjpeg).\n";
}

int main(int argc, char** argv) {
  std::signal(SIGINT, handle_stop_signal);
  std::signal(SIGTERM, handle_stop_signal);
  std::signal(SIGHUP, handle_stop_signal);

  bool resetWindowPositions = false;
  bool chooseEachResolution = false;
  bool chooseAllResolution = false;
  bool preferMjpeg = false;
  bool allowFullMjpegHw = false;
  bool strictGpuSync = false;
  bool showFpsOverlay = false;
  bool listCamerasOnly = false;
  bool autoBenchmarkStartup = true;
  int benchmarkDurationMs = 1200;
  bool enableControlSocket = true;
  bool enableRecording = false;
  RawVideoRecorder::Profile recordProfile = RawVideoRecorder::Profile::Fast;
  auto normalize_option_alias = [](std::string arg) -> std::string {
    auto lower = to_lower_copy(arg);
    if (lower == "--help" || lower == "-help" || lower == "--hlep" || lower == "--halp") return "-h";
    if (lower == "--reset" || lower == "-reset" || lower == "--rest") return "-R";
    if (lower == "--res" || lower == "-res" ||
        lower == "--choose-all-res" || lower == "-choose-all-res" ||
        lower == "--choose-all-resolution" || lower == "-choose-all-resolution") return "-s";
    if (lower == "--res-each" || lower == "-res-each" ||
        lower == "--choose-each-res" || lower == "-choose-each-res" ||
        lower == "--choose-each-resolution" || lower == "-choose-each-resolution" ||
        lower == "--choose-res" || lower == "-choose-res" ||
        lower == "--choose-resolution" || lower == "-choose-resolution" ||
        lower == "--res-ech" || lower == "--res-eash") return "-e";
    if (lower == "--mjpeg" || lower == "-mjpeg" ||
        lower == "--mpjeg" || lower == "-mpjeg" ||
        lower == "--mjpg" || lower == "-mjpg") return "-m";
    if (lower == "--mjpeg-hw" || lower == "-mjpeg-hw" ||
        lower == "--mpjeg-hw" || lower == "-mpjeg-hw" ||
        lower == "--mjpg-hw" || lower == "-mjpg-hw") return "-M";
    if (lower == "--strict-sync" || lower == "-strict-sync" ||
        lower == "--strictsync" || lower == "-strictsync" ||
        lower == "--stric-sync" || lower == "-stric-sync") return "-S";
    if (lower == "--fps" || lower == "-fps" ||
        lower == "--fpps" || lower == "-fpps" ||
        lower == "--fpss" || lower == "-fpss") return "-f";
    if (lower == "--list-cameras" || lower == "-list-cameras" ||
        lower == "--list-camera" || lower == "-list-camera" ||
        lower == "--listcams" || lower == "-listcams" ||
        lower == "--list-camreas" || lower == "-list-camreas") return "-l";
    if (lower == "--no-bench" || lower == "-no-bench" ||
        lower == "--no-benchmark" || lower == "-no-benchmark" ||
        lower == "--nobench" || lower == "-nobench") return "-B";
    if (lower == "--no-control" || lower == "-no-control" ||
        lower == "--nocontrol" || lower == "-nocontrol") return "-C";
    if (lower == "--rec" || lower == "-rec") return "-r";
    if (lower == "--rec-fast" || lower == "-rec-fast" ||
        lower == "--recf-fast" || lower == "-recf-fast") return "-F";
    if (lower == "--rec-quality" || lower == "-rec-quality" ||
        lower == "--rec-qaulity" || lower == "-rec-qaulity") return "-Q";
    return arg;
  };

  std::vector<std::string> normalizedArgs;
  normalizedArgs.reserve(static_cast<size_t>(argc) * 2u);
  normalizedArgs.push_back(argv[0]);
  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    const std::string lower = to_lower_copy(arg);
    if (arg == "--") {
      normalizedArgs.push_back(arg);
      for (int j = i + 1; j < argc; ++j) normalizedArgs.push_back(argv[j]);
      break;
    }
    if (lower.rfind("--bench-ms=", 0) == 0 || lower.rfind("-bench-ms=", 0) == 0 ||
        lower.rfind("--benchms=", 0) == 0 || lower.rfind("-benchms=", 0) == 0 ||
        lower.rfind("--bech-ms=", 0) == 0 || lower.rfind("-bech-ms=", 0) == 0) {
      normalizedArgs.push_back("-b");
      normalizedArgs.push_back(arg.substr(arg.find('=') + 1));
      continue;
    }
    if (lower == "--bench-ms" || lower == "-bench-ms" ||
        lower == "--benchms" || lower == "-benchms" ||
        lower == "--bech-ms" || lower == "-bech-ms") {
      normalizedArgs.push_back("-b");
      if (i + 1 < argc) normalizedArgs.push_back(argv[++i]);
      continue;
    }
    normalizedArgs.push_back(normalize_option_alias(arg));
  }

  std::vector<char*> argvMutable;
  argvMutable.reserve(normalizedArgs.size() + 1u);
  for (auto& s : normalizedArgs) argvMutable.push_back(s.data());
  argvMutable.push_back(nullptr);

  opterr = 0;
  optind = 1;
  int opt = 0;
  while ((opt = getopt(static_cast<int>(normalizedArgs.size()), argvMutable.data(),
                       "b:fhlmMBCrFQseRS")) != -1) {
    switch (opt) {
      case 'b':
        try {
          benchmarkDurationMs = std::clamp(std::stoi(optarg), 300, 4000);
        } catch (...) {
          std::cerr << "Invalid value for --bench-ms: " << (optarg ? optarg : "(null)") << "\n";
          return 1;
        }
        break;
      case 'f':
        showFpsOverlay = true;
        break;
      case 'h':
        print_usbcamv4l_help(argv[0]);
        return 0;
      case 'l':
        listCamerasOnly = true;
        break;
      case 'm':
        preferMjpeg = true;
        break;
      case 'M':
        preferMjpeg = true;
        allowFullMjpegHw = true;
        break;
      case 'B':
        autoBenchmarkStartup = false;
        break;
      case 'C':
        enableControlSocket = false;
        break;
      case 'r':
        enableRecording = true;
        break;
      case 'F':
        enableRecording = true;
        recordProfile = RawVideoRecorder::Profile::Fast;
        break;
      case 'Q':
        enableRecording = true;
        recordProfile = RawVideoRecorder::Profile::Quality;
        break;
      case 's':
        chooseAllResolution = true;
        break;
      case 'e':
        chooseEachResolution = true;
        break;
      case 'R':
        resetWindowPositions = true;
        break;
      case 'S':
        strictGpuSync = true;
        break;
      case '?':
      default:
        if (optopt == 'b') {
          std::cerr << "Missing value for -b/--bench-ms\n";
        } else {
          std::string badOpt;
          if (optind - 1 >= 0 && optind - 1 < static_cast<int>(normalizedArgs.size())) {
            badOpt = normalizedArgs[static_cast<size_t>(optind - 1)];
          }
          if (badOpt == normalizedArgs.front() &&
              optind >= 0 && optind < static_cast<int>(normalizedArgs.size())) {
            badOpt = normalizedArgs[static_cast<size_t>(optind)];
          }
          if (!badOpt.empty()) {
            std::cerr << "Unknown option: " << badOpt << "\n";
          } else {
            std::cerr << "Unknown option.\n";
          }
        }
        std::cerr << "Use --help for usage.\n";
        return 1;
    }
  }

  if (optind < static_cast<int>(normalizedArgs.size())) {
    for (int i = optind; i < static_cast<int>(normalizedArgs.size()); ++i) {
      std::cerr << "Unexpected positional argument: " << normalizedArgs[static_cast<size_t>(i)] << "\n";
    }
    std::cerr << "Use --help for usage.\n";
    return 1;
  }

  if (chooseEachResolution && chooseAllResolution) {
    std::cerr << "Choose only one resolution mode: -res-each or -res\n";
    return 1;
  }

  const CapturePreference capturePref =
      preferMjpeg ? CapturePreference::MJPEG : CapturePreference::Auto;
  std::cerr << "Capture format preference: "
            << (preferMjpeg ? "MJPEG -> NV12 -> YUYV" : "NV12 -> YUYV")
            << "\n";
  std::cerr << "MJPEG decode mode: "
            << (allowFullMjpegHw ? "full hardware decode allowed"
                                 : "low-latency (prefer VAAPI on AMD, prefer QSV on Intel, then turbojpeg)")
            << "\n";
  std::cerr << "GPU sync mode: "
            << (strictGpuSync ? "strict (glFinish, fixed)"
                              : "adaptive (glFlush default, glFinish on stutter)")
            << "\n";
  std::cerr << "Overlay mode: "
            << (showFpsOverlay ? "enabled (-fps)" : "disabled (default)")
            << "\n";
  std::cerr << "Recording mode: "
            << (enableRecording ? ("enabled -> " + recordings_dir()) : "disabled")
            << "\n";
  std::cerr << "Startup benchmark: "
            << (autoBenchmarkStartup ? ("enabled (" + std::to_string(benchmarkDurationMs) + "ms/camera)")
                                     : "disabled")
            << "\n";
  std::cerr << "Control socket: "
            << (enableControlSocket ? control_socket_file() : "disabled")
            << "\n";
  if (enableRecording) {
    std::cerr << "Recording profile: "
              << (recordProfile == RawVideoRecorder::Profile::Fast ? "fast" : "quality")
              << "\n";
  }

  maybe_enable_amd_zink_workaround();

  if (listCamerasOnly) {
    return list_cameras_mode(capturePref);
  }

  const std::string positionsCsv = positions_file();
  const std::string resolutionsCsv = resolutions_file();

  std::unordered_map<std::string, Rect> saved;
  std::unordered_map<std::string, Resolution> savedResolutions;
  if (resetWindowPositions) {
    std::error_code ecPos;
    const bool removedPos = fs::remove(positionsCsv, ecPos);
    if (ecPos) {
      std::cerr << "Warning: failed to remove " << positionsCsv
                << ": " << ecPos.message() << "\n";
    } else {
      std::cerr << (removedPos ? "Removed saved positions: " : "No saved positions file: ")
                << positionsCsv << "\n";
    }

    std::error_code ecRes;
    const bool removedRes = fs::remove(resolutionsCsv, ecRes);
    if (ecRes) {
      std::cerr << "Warning: failed to remove " << resolutionsCsv
                << ": " << ecRes.message() << "\n";
    } else {
      std::cerr << (removedRes ? "Removed saved resolutions: " : "No saved resolutions file: ")
                << resolutionsCsv << "\n";
    }
  } else {
    saved = load_positions_csv(positionsCsv);
    std::cerr << "Loaded " << saved.size()
              << " saved window position entries from " << positionsCsv << "\n";
    savedResolutions = load_resolutions_csv(resolutionsCsv);
    std::cerr << "Loaded " << savedResolutions.size()
              << " saved resolution entries from " << resolutionsCsv << "\n";
  }

  auto scan = enumerate_cameras(capturePref);
  auto cams = scan.cams;
  if (cams.empty()) {
    if (scan.videoNodes == 0) {
      std::cerr << "No /dev/video* devices found.\n";
    } else if (scan.permissionDenied == scan.videoNodes) {
      std::cerr << "Permission denied opening all /dev/video* devices.\n";
      std::cerr << "Add this user to the 'video' group and re-login.\n";
    } else {
      std::cerr << "No capture-capable V4L2 cameras found.\n";
    }
    return 1;
  }

  std::unordered_map<std::string, std::vector<CamInfo>> candidatePoolByStableId;
  for (const auto& cam : cams) {
    candidatePoolByStableId[cam.stableId].push_back(cam);
  }

  std::unordered_set<std::string> discoveredStableIds;
  for (const auto& cam : cams) discoveredStableIds.insert(cam.stableId);
  const int targetWindowCount =
      std::min<int>(MAX_CAMERAS, static_cast<int>(discoveredStableIds.size()));

  std::vector<CamInfo> orderedUniqueCams;
  orderedUniqueCams.reserve(static_cast<size_t>(targetWindowCount));
  {
    std::unordered_set<std::string> seen;
    for (const auto& cam : cams) {
      if (seen.insert(cam.stableId).second) {
        orderedUniqueCams.push_back(cam);
        if (static_cast<int>(orderedUniqueCams.size()) >= targetWindowCount) break;
      }
    }
  }

  std::unordered_map<std::string, Resolution> chosenResolutionByStableId;
  if (chooseAllResolution) {
    std::unordered_map<std::string, std::vector<Resolution>> availableByStableId;
    availableByStableId.reserve(orderedUniqueCams.size());

    for (const auto& cam : orderedUniqueCams) {
      int enumErr = 0;
      auto available = enumerate_supported_resolutions(cam.devPath, &enumErr);
      if (available.empty()) {
        std::cerr << "Failed to enumerate resolutions for " << cam.devPath
                  << ", using default fallback resolution.\n";
        available.push_back(Resolution{DEFAULT_FRAME_W, DEFAULT_FRAME_H});
      }
      availableByStableId.emplace(cam.stableId, std::move(available));
    }

    std::unordered_map<int, int> heightCount;
    for (const auto& cam : orderedUniqueCams) {
      auto it = availableByStableId.find(cam.stableId);
      if (it == availableByStableId.end()) continue;
      std::unordered_set<int> uniqueHeightsForCam;
      for (const auto& r : it->second) uniqueHeightsForCam.insert(r.h);
      for (int h : uniqueHeightsForCam) ++heightCount[h];
    }

    std::vector<int> commonHeights;
    for (const auto& kv : heightCount) {
      if (kv.second == static_cast<int>(orderedUniqueCams.size())) commonHeights.push_back(kv.first);
    }
    std::sort(commonHeights.begin(), commonHeights.end());

    if (commonHeights.empty()) {
      std::cerr << "No common pixel height exists across all selected cameras.\n";
      std::cerr << "Use -res-each to set per-camera resolutions instead.\n";
      return 1;
    }

    const int chosenHeight = choose_common_height_interactively(
        commonHeights, orderedUniqueCams, availableByStableId, DEFAULT_FRAME_H);
    for (const auto& cam : orderedUniqueCams) {
      auto it = availableByStableId.find(cam.stableId);
      if (it == availableByStableId.end()) continue;

      auto selected = best_resolution_for_height(it->second, chosenHeight);
      if (!selected.has_value()) selected = Resolution{DEFAULT_FRAME_W, DEFAULT_FRAME_H};
      chosenResolutionByStableId[cam.stableId] = *selected;
      std::cerr << "Chosen all-camera resolution for " << cam.devPath
                << ": " << selected->w << "x" << selected->h << "\n";
    }
  }

  Display* dpy = XOpenDisplay(nullptr);
  if (!dpy) {
    std::cerr << "XOpenDisplay failed. This implementation requires X11.\n";
    return 1;
  }
  Atom WM_DELETE_WINDOW = XInternAtom(dpy, "WM_DELETE_WINDOW", False);

  EGLDisplay edpy = eglGetDisplay((EGLNativeDisplayType)dpy);
  if (edpy == EGL_NO_DISPLAY) {
    std::cerr << "eglGetDisplay failed\n";
    XCloseDisplay(dpy);
    return 1;
  }
  if (!eglInitialize(edpy, nullptr, nullptr)) {
    std::cerr << "eglInitialize failed\n";
    XCloseDisplay(dpy);
    return 1;
  }
  eglBindAPI(EGL_OPENGL_ES_API);

  EGLint cfgAttrs[] = {
    EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
    EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
    EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
    EGL_NONE
  };
  EGLConfig cfg;
  EGLint ncfg = 0;
  if (!eglChooseConfig(edpy, cfgAttrs, &cfg, 1, &ncfg) || ncfg < 1) {
    std::cerr << "eglChooseConfig failed\n";
    eglTerminate(edpy);
    XCloseDisplay(dpy);
    return 1;
  }
  EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
  EGLContext ctx = eglCreateContext(edpy, cfg, EGL_NO_CONTEXT, ctxAttrs);
  if (ctx == EGL_NO_CONTEXT) {
    std::cerr << "eglCreateContext failed\n";
    eglTerminate(edpy);
    XCloseDisplay(dpy);
    return 1;
  }
  if (!probe_renderer_context(edpy, cfg, ctx)) {
    eglDestroyContext(edpy, ctx);
    eglTerminate(edpy);
    XCloseDisplay(dpy);
    return 1;
  }

  auto eglCreateImageKHR =
      (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
  auto eglDestroyImageKHR =
      (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
  auto glEGLImageTargetTexture2DOES =
      (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");
  const bool haveEglImageImport =
      eglCreateImageKHR && eglDestroyImageKHR && glEGLImageTargetTexture2DOES;
  if (!haveEglImageImport) {
    std::cerr << "EGLImage DMABUF import extensions unavailable; using GPU upload fallback.\n";
  }

  std::vector<XWin> wins;
  std::vector<V4L2DmabufCam> vcams;
  wins.reserve(static_cast<size_t>(targetWindowCount));
  vcams.reserve(static_cast<size_t>(targetWindowCount));

  int screen = DefaultScreen(dpy);
  const int screenW = DisplayWidth(dpy, screen);
  const int screenH = DisplayHeight(dpy, screen);
  Window root = RootWindow(dpy, screen);

  std::unordered_set<std::string> openedStableIds;
  for (const auto& c : cams) {
    if (static_cast<int>(wins.size()) >= targetWindowCount) break;
    if (openedStableIds.find(c.stableId) != openedStableIds.end()) continue;

    Resolution desired;
    const char* desiredSource = "default";
    auto desiredIt = chosenResolutionByStableId.find(c.stableId);
    if (desiredIt != chosenResolutionByStableId.end()) {
      desired = desiredIt->second;
      desiredSource = "preselected";
    } else {
      if (chooseEachResolution) {
        const auto available = enumerate_supported_resolutions(c.devPath);
        desired = choose_resolution_interactively(c, available, desired);
        desiredSource = "interactive";
      } else {
        auto savedResIt = savedResolutions.find(c.stableId);
        if (savedResIt != savedResolutions.end()) {
          desired = savedResIt->second;
          desiredSource = "saved";
        }
      }
      chosenResolutionByStableId[c.stableId] = desired;
    }

    Rect r{};
    auto it = saved.find(c.stableId);
    const bool haveSavedPos = (it != saved.end());
    if (haveSavedPos) r = it->second;
    const Rect requestedRect = r;
    const bool wasClamped = clamp_rect_to_screen(r, screenW, screenH);
    if (wasClamped) {
      std::cerr << "Adjusted startup window to fit screen: " << c.devPath
                << " requested=(" << requestedRect.x << "," << requestedRect.y
                << " " << requestedRect.w << "x" << requestedRect.h << ")"
                << " clamped=(" << r.x << "," << r.y << " " << r.w << "x" << r.h << ")"
                << " screen=(" << screenW << "x" << screenH << ")\n";
    }
    std::cerr << "Startup restore: " << c.devPath
              << " (group=" << c.stableId << ")"
              << " pos=(" << r.x << "," << r.y << ")"
              << (haveSavedPos ? " [saved-pos]" : " [default-pos]")
              << " window=" << r.w << "x" << r.h
              << (haveSavedPos ? " [saved-size]" : " [default-size]")
              << " capture-request=" << desired.w << "x" << desired.h
              << " [" << desiredSource << "]\n";

    Window w = XCreateSimpleWindow(dpy, root, r.x, r.y, (unsigned)r.w, (unsigned)r.h,
                                   0, BlackPixel(dpy, screen), BlackPixel(dpy, screen));
    XStoreName(dpy, w, (c.card + " [" + c.devPath + "]").c_str());
    x11_apply_window_geometry(dpy, w, r);
    XSelectInput(dpy, w, StructureNotifyMask | ExposureMask);
    XSetWMProtocols(dpy, w, &WM_DELETE_WINDOW, 1);
    XMapWindow(dpy, w);
    x11_apply_window_geometry(dpy, w, r);
    XSync(dpy, False);

    {
      int ax = 0, ay = 0;
      XWindowAttributes awa{};
      if (x11_get_window_root_xy(dpy, w, ax, ay) && XGetWindowAttributes(dpy, w, &awa)) {
        std::cerr << "Applied geometry: " << c.devPath
                  << " requested=(" << r.x << "," << r.y << " " << r.w << "x" << r.h << ")"
                  << " actual=(" << ax << "," << ay << " " << awa.width << "x" << awa.height << ")\n";
      }
    }

    EGLSurface surf = eglCreateWindowSurface(edpy, cfg, (EGLNativeWindowType)w, nullptr);
    if (surf == EGL_NO_SURFACE) {
      std::cerr << "eglCreateWindowSurface failed\n";
      XDestroyWindow(dpy, w);
      continue;
    }

    if (!eglMakeCurrent(edpy, surf, surf, ctx)) {
      std::cerr << "eglMakeCurrent failed\n";
      eglDestroySurface(edpy, surf);
      XDestroyWindow(dpy, w);
      continue;
    }

    V4L2DmabufCam cam;
    cam.cam = c;
    cam.requestedW = desired.w;
    cam.requestedH = desired.h;
    cam.lowLatency = true;
    cam.requestedBufferCount = 2;
    cam.allowCudaHwMjpeg = allowFullMjpegHw && g_activeRendererIsNvidia;
    cam.allowFullHwMjpeg = allowFullMjpegHw;
    cam.allowVaapiHwMjpeg = allowFullMjpegHw || g_activeRendererIsIntel || g_activeRendererIsAmd;
    cam.allowQsvHwMjpeg = g_activeRendererIsIntel;
    cam.preferVaapiHwMjpeg = g_activeRendererIsAmd;
    cam.preferCpuYuyv = g_activeRendererIsAmd;
    cam.record = enableRecording;
    cam.recorder.enabled = enableRecording;
    cam.recorder.profile = recordProfile;
    if (autoBenchmarkStartup) {
      auto bench = auto_benchmark_best_format(c.devPath, desired.w, desired.h, capturePref, benchmarkDurationMs);
      if (bench.has_value()) {
        cam.preferredPixFmt = bench->requestedPixFmt;
        std::cerr << "Startup benchmark (" << c.devPath << "): selected "
                  << fourcc_to_string(bench->requestedPixFmt)
                  << " -> delivered " << fourcc_to_string(bench->actualPixFmt)
                  << " @ " << bench->width << "x" << bench->height
                  << " (" << bench->fps << " fps over " << bench->frames << " frames)\n";
      }
    }
    if (!cam.open_and_configure(capturePref)) {
      std::cerr << "Failed camera candidate " << c.devPath
                << " (group=" << c.stableId << "), trying next candidate.\n";
      eglDestroySurface(edpy, surf);
      XDestroyWindow(dpy, w);
      continue;
    }
    if (chooseEachResolution || chooseAllResolution) {
      Rect displayRect = r;
      displayRect.w = cam.width;
      displayRect.h = cam.height;

      const Rect beforeDisplayClamp = displayRect;
      const bool clampedDisplay = clamp_rect_to_screen(displayRect, screenW, screenH);
      if (clampedDisplay) {
        std::cerr << "Adjusted capture-sized window to fit screen: " << c.devPath
                  << " requested=(" << beforeDisplayClamp.x << "," << beforeDisplayClamp.y
                  << " " << beforeDisplayClamp.w << "x" << beforeDisplayClamp.h << ")"
                  << " clamped=(" << displayRect.x << "," << displayRect.y
                  << " " << displayRect.w << "x" << displayRect.h << ")"
                  << " screen=(" << screenW << "x" << screenH << ")\n";
      }

      x11_apply_window_geometry(dpy, w, displayRect);
      XSync(dpy, False);

      r = displayRect;

      std::cerr << "Display window size synced to capture: " << c.devPath
                << " window=" << r.w << "x" << r.h
                << " capture=" << cam.width << "x" << cam.height << "\n";
    }

    if (cam.nv12 && haveEglImageImport) {
      for (auto& b : cam.bufs) {
        if (b.dmabuf < 0) continue;

        EGLint yAttrs[] = {
          EGL_WIDTH, cam.width,
          EGL_HEIGHT, cam.height,
          EGL_LINUX_DRM_FOURCC_EXT, DRM_FORMAT_R8,
          EGL_DMA_BUF_PLANE0_FD_EXT, b.dmabuf,
          EGL_DMA_BUF_PLANE0_OFFSET_EXT, 0,
          EGL_DMA_BUF_PLANE0_PITCH_EXT, cam.strideY,
          EGL_NONE
        };
        b.yImg = eglCreateImageKHR(edpy, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, nullptr, yAttrs);

        const int uvW = cam.width / 2;
        const int uvH = cam.height / 2;
        const int uvOff = cam.strideY * cam.height;

        EGLint uvAttrs[] = {
          EGL_WIDTH, uvW,
          EGL_HEIGHT, uvH,
          EGL_LINUX_DRM_FOURCC_EXT, DRM_FORMAT_GR88,
          EGL_DMA_BUF_PLANE0_FD_EXT, b.dmabuf,
          EGL_DMA_BUF_PLANE0_OFFSET_EXT, uvOff,
          EGL_DMA_BUF_PLANE0_PITCH_EXT, cam.strideUV,
          EGL_NONE
        };
        b.uvImg = eglCreateImageKHR(edpy, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, nullptr, uvAttrs);

        if (b.yImg == EGL_NO_IMAGE_KHR || b.uvImg == EGL_NO_IMAGE_KHR) {
          std::cerr << "EGLImage import failed; falling back to GPU NV12 upload path.\n";
          if (b.yImg != EGL_NO_IMAGE_KHR) {
            eglDestroyImageKHR(edpy, b.yImg);
            b.yImg = EGL_NO_IMAGE_KHR;
          }
          if (b.uvImg != EGL_NO_IMAGE_KHR) {
            eglDestroyImageKHR(edpy, b.uvImg);
            b.uvImg = EGL_NO_IMAGE_KHR;
          }
          continue;
        }

        glGenTextures(1, &b.yTex);
        glBindTexture(GL_TEXTURE_2D, b.yTex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, (GLeglImageOES)b.yImg);

        glGenTextures(1, &b.uvTex);
        glBindTexture(GL_TEXTURE_2D, b.uvTex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, (GLeglImageOES)b.uvImg);
      }
    } else if (cam.nv12) {
      std::cerr << "DMABUF EGL import disabled for " << cam.cam.devPath
                << "; using GPU NV12 upload path.\n";
    }

    wins.push_back({w, surf, r});
    vcams.push_back(std::move(cam));
    openedStableIds.insert(c.stableId);

    savedResolutions[c.stableId] = Resolution{vcams.back().width, vcams.back().height};
    (void)save_resolutions_csv(resolutionsCsv, savedResolutions);
    std::cerr << "Started camera window: " << c.devPath
              << " @ " << vcams.back().width << "x" << vcams.back().height << "\n";
  }

  if (wins.empty()) {
    std::cerr << "No camera windows could be created.\n";
    eglDestroyContext(edpy, ctx);
    eglTerminate(edpy);
    XCloseDisplay(dpy);
    return 1;
  }

  if (!eglMakeCurrent(edpy, wins[0].surf, wins[0].surf, ctx)) {
    std::cerr << "eglMakeCurrent failed\n";
    for (auto& cam : vcams) cam.shutdown(eglDestroyImageKHR, edpy);
    for (auto& w : wins) {
      if (w.surf != EGL_NO_SURFACE) eglDestroySurface(edpy, w.surf);
      if (w.win) XDestroyWindow(dpy, w.win);
    }
    eglDestroyContext(edpy, ctx);
    eglTerminate(edpy);
    XCloseDisplay(dpy);
    return 1;
  }
  const bool needYuyvShader = std::any_of(vcams.begin(), vcams.end(),
                                          [](const V4L2DmabufCam& c) {
                                            return c.yuyv && !c.yuyvCpuConvert;
                                          });
  const bool needNV12Shader = std::any_of(vcams.begin(), vcams.end(),
                                          [](const V4L2DmabufCam& c) {
                                            return c.nv12 || c.mjpeg;
                                          });
  const bool needYUVPlanarShader = std::any_of(vcams.begin(), vcams.end(),
                                               [](const V4L2DmabufCam& c) {
                                                 return c.mjpeg;
                                               });
  const bool needOverlayShader = showFpsOverlay || enableControlSocket;

  GLuint progNV12 = needNV12Shader ? make_program(kFS_NV12) : 0;
  GLuint progYUYV = needYuyvShader ? make_program(kFS_YUYV) : 0;
  GLuint progYUVPlanar = needYUVPlanarShader ? make_program(kFS_YUV_PLANAR) : 0;
  GLuint progRGBA = needOverlayShader ? make_program(kFS_RGBA) : 0;

  GLint locY = progNV12 ? glGetUniformLocation(progNV12, "texY") : -1;
  GLint locUV = progNV12 ? glGetUniformLocation(progNV12, "texUV") : -1;
  GLint locYuyv = progYUYV ? glGetUniformLocation(progYUYV, "texYUYV") : -1;
  GLint locYuyvWidth = progYUYV ? glGetUniformLocation(progYUYV, "frameWidth") : -1;
  GLint locPlanarY = progYUVPlanar ? glGetUniformLocation(progYUVPlanar, "texPlanarY") : -1;
  GLint locPlanarU = progYUVPlanar ? glGetUniformLocation(progYUVPlanar, "texPlanarU") : -1;
  GLint locPlanarV = progYUVPlanar ? glGetUniformLocation(progYUVPlanar, "texPlanarV") : -1;
  GLint locRGBA = progRGBA ? glGetUniformLocation(progRGBA, "texRGBA") : -1;

  if (progNV12) {
    glUseProgram(progNV12);
    glUniform1i(locY, 0);
    glUniform1i(locUV, 1);
  } else if (needNV12Shader) {
    std::cerr << "NV12 shader program unavailable; NV12 streams may fail to render.\n";
  }
  if (progYUYV) {
    glUseProgram(progYUYV);
    glUniform1i(locYuyv, 0);
  } else if (needYuyvShader) {
    std::cerr << "YUYV shader program unavailable; YUYV streams may fail to render.\n";
  }
  if (progYUVPlanar) {
    glUseProgram(progYUVPlanar);
    glUniform1i(locPlanarY, 0);
    glUniform1i(locPlanarU, 1);
    glUniform1i(locPlanarV, 2);
  } else if (needYUVPlanarShader) {
    std::cerr << "Planar YUV shader program unavailable; MJPEG streams may fail to render.\n";
  }
  if (progRGBA) {
    glUseProgram(progRGBA);
    glUniform1i(locRGBA, 0);
  }

  const char* glExt = reinterpret_cast<const char*>(glGetString(GL_EXTENSIONS));
  const bool canUseUnpackRowLength = gl_extension_supported(glExt, "GL_EXT_unpack_subimage");
  if (!canUseUnpackRowLength) {
    std::cerr << "GL_EXT_unpack_subimage not found; strided uploads will use CPU row repack.\n";
  }

  const GLfloat quad[] = {
    -1.f, -1.f, 0.f, 1.f,
     1.f, -1.f, 1.f, 1.f,
    -1.f,  1.f, 0.f, 0.f,
     1.f,  1.f, 1.f, 0.f,
  };

  bool adaptiveGpuSync = !strictGpuSync;
  bool runtimeStrictGpuSync = strictGpuSync;
  int syncStutterEvents = 0;
  int syncQuietWindows = 0;
  auto syncWindowStart = std::chrono::steady_clock::now();
  const int reconnectRetryMs = 1200;
  const int watchdogNoFrameMs = 1500;

  const std::string controlSocketPath = control_socket_file();
  int controlFd = -1;
  if (enableControlSocket) {
    controlFd = create_control_socket(controlSocketPath);
    if (controlFd >= 0) {
      std::cerr << "Runtime control socket ready: " << controlSocketPath << "\n";
    }
  }

  auto apply_record_mode_to_all = [&](bool enabled) {
    enableRecording = enabled;
    for (auto& cam : vcams) {
      cam.record = enabled;
      cam.recorder.enabled = enabled;
      if (!enabled) cam.recorder.stop();
    }
  };

  auto apply_queue_depth_to_all = [&](int depth) {
    const int clamped = std::clamp(depth, 2, 4);
    for (auto& cam : vcams) {
      cam.requestedBufferCount = clamped;
      cam.reconnectPending = true;
    }
  };

  auto try_reconnect_camera = [&](size_t camIndex, const std::string& reason) -> bool {
    if (camIndex >= vcams.size() || camIndex >= wins.size()) return false;
    auto& cam = vcams[camIndex];
    const std::string stableId = cam.cam.stableId;
    if (stableId.empty()) return false;

    const auto now = std::chrono::steady_clock::now();
    if (cam.lastReconnectAttempt.time_since_epoch().count() != 0) {
      const auto sinceMs = std::chrono::duration_cast<std::chrono::milliseconds>(now - cam.lastReconnectAttempt).count();
      if (sinceMs < reconnectRetryMs) return false;
    }
    cam.lastReconnectAttempt = now;
    std::cerr << "Attempting camera reconnect for " << cam.cam.devPath
              << " (reason: " << reason << ")\n";

    const int reqW = cam.requestedW;
    const int reqH = cam.requestedH;
    const uint32_t prefFmt = cam.preferredPixFmt;
    const int reqBufs = cam.requestedBufferCount;
    const bool lowLatency = cam.lowLatency;
    const bool allowCuda = cam.allowCudaHwMjpeg;
    const bool allowFull = cam.allowFullHwMjpeg;
    const bool allowVaapi = cam.allowVaapiHwMjpeg;
    const bool allowQsv = cam.allowQsvHwMjpeg;
    const bool preferVaapi = cam.preferVaapiHwMjpeg;
    const bool preferCpuYuyv = cam.preferCpuYuyv;
    const bool recEnabled = cam.record;
    const auto recProfile = cam.recorder.profile;

    if (!eglMakeCurrent(edpy, wins[camIndex].surf, wins[camIndex].surf, ctx)) {
      std::cerr << "Reconnect aborted: eglMakeCurrent failed.\n";
      return false;
    }
    cam.shutdown(eglDestroyImageKHR, edpy);

    auto refresh_pool = [&]() {
      auto rescanned = enumerate_cameras(capturePref);
      for (const auto& c : rescanned.cams) {
        auto& vec = candidatePoolByStableId[c.stableId];
        const bool exists = std::any_of(vec.begin(), vec.end(),
                                        [&](const CamInfo& e) { return e.devPath == c.devPath; });
        if (!exists) vec.push_back(c);
      }
    };
    refresh_pool();

    auto itPool = candidatePoolByStableId.find(stableId);
    if (itPool == candidatePoolByStableId.end() || itPool->second.empty()) {
      std::cerr << "Reconnect failed: no candidates found for stable-id " << stableId << "\n";
      cam.reconnectPending = true;
      return false;
    }

    for (const auto& candidate : itPool->second) {
      bool inUse = false;
      for (size_t j = 0; j < vcams.size(); ++j) {
        if (j == camIndex) continue;
        if (vcams[j].fd >= 0 && vcams[j].cam.devPath == candidate.devPath) {
          inUse = true;
          break;
        }
      }
      if (inUse) continue;

      V4L2DmabufCam replacement;
      replacement.cam = candidate;
      replacement.requestedW = reqW;
      replacement.requestedH = reqH;
      replacement.preferredPixFmt = prefFmt;
      replacement.requestedBufferCount = reqBufs;
      replacement.lowLatency = lowLatency;
      replacement.allowCudaHwMjpeg = allowCuda;
      replacement.allowFullHwMjpeg = allowFull;
      replacement.allowVaapiHwMjpeg = allowVaapi;
      replacement.allowQsvHwMjpeg = allowQsv;
      replacement.preferVaapiHwMjpeg = preferVaapi;
      replacement.preferCpuYuyv = preferCpuYuyv;
      replacement.record = recEnabled;
      replacement.recorder.enabled = recEnabled;
      replacement.recorder.profile = recProfile;

      if (!replacement.open_and_configure(capturePref)) {
        replacement.shutdown(eglDestroyImageKHR, edpy);
        continue;
      }

      vcams[camIndex] = std::move(replacement);
      vcams[camIndex].reconnectPending = false;
      vcams[camIndex].consecutiveDqErrors = 0;
      vcams[camIndex].frameClockStarted = false;
      vcams[camIndex].stutterEvents = 0;
      Rect corrected = constrain_rect_to_aspect(wins[camIndex].geom,
                                                vcams[camIndex].width, vcams[camIndex].height);
      if (corrected.w != wins[camIndex].geom.w || corrected.h != wins[camIndex].geom.h) {
        x11_apply_window_geometry(dpy, wins[camIndex].win, corrected);
      }
      wins[camIndex].geom = corrected;
      wins[camIndex].pendingGeom = corrected;
      wins[camIndex].resizePending = false;
      std::cerr << "Reconnect successful: now using " << vcams[camIndex].cam.devPath << "\n";
      return true;
    }

    cam.reconnectPending = true;
    std::cerr << "Reconnect failed for stable-id " << stableId << "; will retry.\n";
    return false;
  };

  auto handle_control_command = [&](const std::string& raw) -> std::string {
    const std::string cmd = trim(raw);
    if (cmd.empty()) return "ERR empty command\n";

    std::istringstream iss(cmd);
    std::string op;
    iss >> op;
    op = to_lower_copy(op);

    auto parse_toggle = [&](const std::string& value, bool& target) -> bool {
      const std::string v = to_lower_copy(value);
      if (v == "on" || v == "1" || v == "true") { target = true; return true; }
      if (v == "off" || v == "0" || v == "false") { target = false; return true; }
      if (v == "toggle") { target = !target; return true; }
      return false;
    };

    if (op == "help") {
      return "OK commands: status | fps on/off/toggle | rec on/off/toggle | sync strict/low/auto | queue 2..4 | cam <idx> rec on/off/toggle | cam <idx> reconnect\n";
    }
    if (op == "status") {
      std::ostringstream out;
      out << "OK overlay=" << (showFpsOverlay ? "on" : "off")
          << " sync=" << (adaptiveGpuSync ? "auto" : (runtimeStrictGpuSync ? "strict" : "low"))
          << " recording=" << (enableRecording ? "on" : "off")
          << " cams=" << vcams.size() << "\n";
      for (size_t i = 0; i < vcams.size(); ++i) {
        const auto& c = vcams[i];
        out << "cam " << i
            << " dev=" << c.cam.devPath
            << " fmt=" << (c.mjpeg ? "MJPEG" : (c.nv12 ? "NV12" : (c.yuyv ? "YUYV" : "UNKNOWN")))
            << " " << c.width << "x" << c.height
            << " fps=" << c.fpsValue
            << " queue=" << c.requestedBufferCount
            << " rec=" << (c.record ? "on" : "off")
            << " reconnect=" << (c.reconnectPending ? "pending" : "no")
            << "\n";
      }
      return out.str();
    }
    if (op == "fps") {
      std::string arg;
      iss >> arg;
      bool v = showFpsOverlay;
      if (!parse_toggle(arg, v)) return "ERR usage: fps on|off|toggle\n";
      showFpsOverlay = v;
      return std::string("OK fps=") + (showFpsOverlay ? "on\n" : "off\n");
    }
    if (op == "rec") {
      std::string arg;
      iss >> arg;
      bool v = enableRecording;
      if (!parse_toggle(arg, v)) return "ERR usage: rec on|off|toggle\n";
      apply_record_mode_to_all(v);
      return std::string("OK rec=") + (enableRecording ? "on\n" : "off\n");
    }
    if (op == "sync") {
      std::string arg;
      iss >> arg;
      arg = to_lower_copy(arg);
      if (arg == "strict") {
        adaptiveGpuSync = false;
        runtimeStrictGpuSync = true;
        return "OK sync=strict\n";
      }
      if (arg == "low") {
        adaptiveGpuSync = false;
        runtimeStrictGpuSync = false;
        return "OK sync=low\n";
      }
      if (arg == "auto") {
        adaptiveGpuSync = true;
        runtimeStrictGpuSync = false;
        syncStutterEvents = 0;
        syncQuietWindows = 0;
        return "OK sync=auto\n";
      }
      return "ERR usage: sync strict|low|auto\n";
    }
    if (op == "queue") {
      int depth = 0;
      iss >> depth;
      if (depth < 2 || depth > 4) return "ERR usage: queue 2|3|4\n";
      apply_queue_depth_to_all(depth);
      return "OK queue depth update scheduled\n";
    }
    if (op == "cam") {
      int idx = -1;
      std::string sub;
      iss >> idx >> sub;
      sub = to_lower_copy(sub);
      if (idx < 0 || static_cast<size_t>(idx) >= vcams.size()) return "ERR camera index out of range\n";
      auto& c = vcams[static_cast<size_t>(idx)];
      if (sub == "reconnect") {
        c.reconnectPending = true;
        return "OK reconnect scheduled\n";
      }
      if (sub == "rec") {
        std::string arg;
        iss >> arg;
        bool v = c.record;
        if (!parse_toggle(arg, v)) return "ERR usage: cam <idx> rec on|off|toggle\n";
        c.record = v;
        c.recorder.enabled = v;
        if (!v) c.recorder.stop();
        enableRecording = std::any_of(vcams.begin(), vcams.end(), [](const V4L2DmabufCam& cam) {
          return cam.record;
        });
        return std::string("OK cam rec=") + (c.record ? "on\n" : "off\n");
      }
      return "ERR usage: cam <idx> rec ... | cam <idx> reconnect\n";
    }
    return "ERR unknown command\n";
  };

  auto drain_control_socket = [&]() {
    if (controlFd < 0) return;
    while (true) {
      sockaddr_un peer{};
      socklen_t peerLen = sizeof(peer);
      char buf[512];
      const ssize_t n = recvfrom(controlFd, buf, sizeof(buf) - 1, 0,
                                 reinterpret_cast<sockaddr*>(&peer), &peerLen);
      if (n < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) break;
        std::cerr << "Control socket recv error: " << strerror(errno) << "\n";
        break;
      }
      buf[n] = '\0';
      const std::string response = handle_control_command(std::string(buf));
      (void)sendto(controlFd, response.data(), response.size(), 0,
                   reinterpret_cast<const sockaddr*>(&peer), peerLen);
    }
  };

  const int xfd = ConnectionNumber(dpy);
  std::vector<pollfd> pfds;
  pfds.reserve(2 + vcams.size());

  bool quit = false;
  bool positionsDirty = false;
  static constexpr int kResizeSettleMs = 140;
  while (!quit) {
    if (g_stopRequested) {
      std::cerr << "Stop requested, saving camera window state and exiting.\n";
      quit = true;
      break;
    }

    pfds.clear();
    pfds.push_back({xfd, POLLIN, 0});
    if (controlFd >= 0) pfds.push_back({controlFd, POLLIN, 0});
    for (auto& c : vcams) if (c.fd >= 0) pfds.push_back({c.fd, POLLIN, 0});
    const int pollRc = poll(pfds.data(), pfds.size(), 10);
    if (pollRc < 0 && errno == EINTR) continue;
    drain_control_socket();

    while (XPending(dpy)) {
      XEvent ev;
      XNextEvent(dpy, &ev);
      if (ev.type == ClientMessage && (Atom)ev.xclient.data.l[0] == WM_DELETE_WINDOW) {
        for (size_t i = 0; i < wins.size(); ++i) {
          if (wins[i].win == (Window)ev.xclient.window) {
            int rx = 0, ry = 0;
            x11_get_window_root_xy(dpy, wins[i].win, rx, ry);
            XWindowAttributes wa{};
            XGetWindowAttributes(dpy, wins[i].win, &wa);
            wins[i].geom = {rx, ry, wa.width, wa.height};
            saved[vcams[i].cam.stableId] = wins[i].geom;
            save_positions_csv(positionsCsv, saved);
            savedResolutions[vcams[i].cam.stableId] = {vcams[i].width, vcams[i].height};
            save_resolutions_csv(resolutionsCsv, savedResolutions);

            if (wins[i].surf != EGL_NO_SURFACE) {
              if (eglMakeCurrent(edpy, wins[i].surf, wins[i].surf, ctx)) {}
            }
            vcams[i].shutdown(eglDestroyImageKHR, edpy);
            if (wins[i].surf != EGL_NO_SURFACE) eglDestroySurface(edpy, wins[i].surf);
            if (wins[i].win) XDestroyWindow(dpy, wins[i].win);
            wins.erase(wins.begin() + i);
            vcams.erase(vcams.begin() + i);
            break;
          }
        }
        if (wins.empty()) { quit = true; break; }
      } else if (ev.type == ConfigureNotify) {
        for (size_t i = 0; i < wins.size(); ++i) {
          auto& w = wins[i];
          if (w.win == ev.xconfigure.window) {
            int rx = 0, ry = 0;
            x11_get_window_root_xy(dpy, w.win, rx, ry);
            Rect nextGeom{rx, ry, ev.xconfigure.width, ev.xconfigure.height};
            w.geom = nextGeom;
            w.pendingGeom = nextGeom;
            w.lastResizeEvent = std::chrono::steady_clock::now();
            w.resizePending = true;
            break;
          }
        }
      }
    }
    if (quit) break;

    const auto nowAfterEvents = std::chrono::steady_clock::now();
    for (size_t i = 0; i < wins.size(); ++i) {
      auto& w = wins[i];
      if (!w.resizePending || i >= vcams.size()) continue;
      const auto sinceMs = std::chrono::duration_cast<std::chrono::milliseconds>(
          nowAfterEvents - w.lastResizeEvent).count();
      if (sinceMs < kResizeSettleMs) continue;

      Rect current = w.pendingGeom;
      int rx = 0, ry = 0;
      XWindowAttributes wa{};
      if (x11_get_window_root_xy(dpy, w.win, rx, ry) && XGetWindowAttributes(dpy, w.win, &wa)) {
        current = {rx, ry, wa.width, wa.height};
      }
      Rect corrected = constrain_rect_to_aspect(current, vcams[i].width, vcams[i].height);
      clamp_rect_to_screen(corrected, screenW, screenH);

      const bool sizeChanged = corrected.w != current.w || corrected.h != current.h;
      const bool posChanged = corrected.x != current.x || corrected.y != current.y;
      if (sizeChanged || posChanged) {
        x11_apply_window_geometry(dpy, w.win, corrected);
        XSync(dpy, False);
      }
      w.geom = corrected;
      w.pendingGeom = corrected;
      w.resizePending = false;
      saved[vcams[i].cam.stableId] = corrected;
      positionsDirty = true;
    }

    for (size_t i = 0; i < vcams.size(); ++i) {
      auto& cam = vcams[i];
      const auto camLoopNow = std::chrono::steady_clock::now();

      if (cam.reconnectPending ||
          (cam.frameClockStarted &&
           std::chrono::duration_cast<std::chrono::milliseconds>(camLoopNow - cam.lastFrameTs).count() > watchdogNoFrameMs) ||
          cam.fd < 0) {
        cam.reconnectPending = true;
        (void)try_reconnect_camera(i, cam.fd < 0 ? "camera fd invalid" : "watchdog timeout");
        if (cam.fd < 0) continue;
      }

      v4l2_buffer b{};
      bool haveFrame = false;
      bool dqFailed = false;
      int dqErrno = 0;
      while (true) {
        v4l2_buffer dq{};
        dq.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        dq.memory = V4L2_MEMORY_MMAP;
        if (ioctl(cam.fd, VIDIOC_DQBUF, &dq) != 0) {
          if (errno == EAGAIN) break;
          dqErrno = errno;
          std::cerr << "VIDIOC_DQBUF failed (" << cam.cam.devPath << "): " << strerror(errno) << "\n";
          dqFailed = true;
          break;
        }
        if (dq.index >= cam.bufs.size()) {
          ioctl(cam.fd, VIDIOC_QBUF, &dq);
          continue;
        }
        if (haveFrame && cam.lowLatency) {
          ioctl(cam.fd, VIDIOC_QBUF, &b);
        }
        b = dq;
        haveFrame = true;
        if (!cam.lowLatency) break;
      }
      if (dqFailed) {
        ++cam.consecutiveDqErrors;
        if (cam.consecutiveDqErrors >= 2 || dqErrno == ENODEV || dqErrno == EIO || dqErrno == ENXIO || dqErrno == EBADF) {
          cam.reconnectPending = true;
          if (cam.requestedBufferCount < 4) {
            ++cam.requestedBufferCount;
            std::cerr << "Increasing capture queue depth to " << cam.requestedBufferCount
                      << " for " << cam.cam.devPath << " after dequeue errors.\n";
          }
        }
        continue;
      }
      cam.consecutiveDqErrors = 0;
      if (!haveFrame) {
        if (cam.frameClockStarted) {
          const auto msSinceFrame = std::chrono::duration_cast<std::chrono::milliseconds>(
              std::chrono::steady_clock::now() - cam.lastFrameTs).count();
          if (msSinceFrame > watchdogNoFrameMs) {
            cam.reconnectPending = true;
          }
        }
        continue;
      }

      {
        const auto frameNow = std::chrono::steady_clock::now();
        if (cam.frameClockStarted) {
          const double frameMs = std::chrono::duration_cast<std::chrono::duration<double, std::milli>>(
              frameNow - cam.lastFrameTs).count();
          if (cam.frameIntervalEwmaMs <= 0.0) cam.frameIntervalEwmaMs = frameMs;
          else cam.frameIntervalEwmaMs = 0.90 * cam.frameIntervalEwmaMs + 0.10 * frameMs;
          if (cam.frameIntervalEwmaMs > 0.0 && frameMs > cam.frameIntervalEwmaMs * 1.8 && frameMs > 18.0) {
            ++cam.stutterEvents;
            ++syncStutterEvents;
          } else {
            cam.stutterEvents = std::max(0, cam.stutterEvents - 1);
          }
        } else {
          cam.frameClockStarted = true;
          cam.frameIntervalEwmaMs = 0.0;
        }
        cam.lastFrameTs = frameNow;
      }
      if (cam.stutterEvents >= 4 && cam.requestedBufferCount < 4) {
        ++cam.requestedBufferCount;
        cam.reconnectPending = true;
        cam.stutterEvents = 0;
        std::cerr << "Detected recurring stutter on " << cam.cam.devPath
                  << "; increasing queue depth to " << cam.requestedBufferCount
                  << " and scheduling reconnect.\n";
      }

      if (!eglMakeCurrent(edpy, wins[i].surf, wins[i].surf, ctx)) {
        std::cerr << "eglMakeCurrent failed\n";
        ioctl(cam.fd, VIDIOC_QBUF, &b);
        continue;
      } else {
        glViewport(0, 0, std::max(1, wins[i].geom.w), std::max(1, wins[i].geom.h));
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        bool rendered = false;
        const uint8_t* recordSourceRgba = nullptr;
        int recordSourceW = 0;
        int recordSourceH = 0;
        if (progNV12 && cam.nv12 && cam.bufs[b.index].yTex && cam.bufs[b.index].uvTex) {
          glUseProgram(progNV12);
          glActiveTexture(GL_TEXTURE0);
          glBindTexture(GL_TEXTURE_2D, cam.bufs[b.index].yTex);
          glActiveTexture(GL_TEXTURE1);
          glBindTexture(GL_TEXTURE_2D, cam.bufs[b.index].uvTex);
          draw_quad(quad);
          rendered = true;
        } else {
          const uint8_t* base = static_cast<const uint8_t*>(cam.bufs[b.index].ptr);
          if (base) {
            if (cam.nv12) {
              const uint8_t* srcY = base;
              const uint8_t* srcUV = base + static_cast<size_t>(cam.strideY) * static_cast<size_t>(cam.height);
              ensure_plane_texture(cam.uploadYTex, cam.uploadYTexW, cam.uploadYTexH,
                                   GL_LUMINANCE, cam.width, cam.height, GL_LINEAR);
              ensure_plane_texture(cam.uploadUVTex, cam.uploadUVTexW, cam.uploadUVTexH,
                                   GL_LUMINANCE_ALPHA, cam.width / 2, cam.height / 2, GL_LINEAR);
              const bool upY = upload_plane_texture(cam.uploadYTex, GL_LUMINANCE,
                                                    cam.width, cam.height, 1,
                                                    srcY, cam.strideY, canUseUnpackRowLength,
                                                    cam.scratchY);
              const bool upUV = upload_plane_texture(cam.uploadUVTex, GL_LUMINANCE_ALPHA,
                                                     cam.width / 2, cam.height / 2, 2,
                                                     srcUV, cam.strideUV, canUseUnpackRowLength,
                                                     cam.scratchUV);
              if (upY && upUV && progNV12) {
                glUseProgram(progNV12);
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_2D, cam.uploadYTex);
                glActiveTexture(GL_TEXTURE1);
                glBindTexture(GL_TEXTURE_2D, cam.uploadUVTex);
                draw_quad(quad);
                rendered = true;
              }
            } else if (cam.mjpeg) {
              const size_t bytesUsed =
                  std::min(static_cast<size_t>(b.bytesused), cam.bufs[b.index].len);
              if (bytesUsed > 0) {
                if (cam.mjpegHw.enabled) {
                  AVFrame* hwFrame = nullptr;
                  if (cam.mjpegHw.decode_frame(base, bytesUsed, hwFrame) && hwFrame) {
                    const int hwW = hwFrame->width;
                    const int hwH = hwFrame->height;
                    bool hwIsNV12 = false;
                    bool hwHasChroma = false;
                    int hwChromaW = 0;
                    int hwChromaH = 0;
                    const AVPixelFormat hwFmt = static_cast<AVPixelFormat>(hwFrame->format);
                    const bool hwIsYuyvPacked = (hwFmt == AV_PIX_FMT_YUYV422);
                    if (hwW > 0 && hwH > 0 &&
                        (hwIsYuyvPacked ||
                         ffmpeg_planar_yuv_info(hwFmt, hwW, hwH, hwIsNV12, hwHasChroma, hwChromaW, hwChromaH))) {
                      if ((hwW != cam.width || hwH != cam.height) && !cam.warnedMjpegHwSizeMismatch) {
                        std::cerr << "MJPEG hardware decode size differs from capture config ("
                                  << cam.cam.devPath << "): decoded=" << hwW << "x" << hwH
                                  << ", configured=" << cam.width << "x" << cam.height << "\n";
                        cam.warnedMjpegHwSizeMismatch = true;
                      }

                      if (hwIsYuyvPacked) {
                        const bool converted = convert_yuyv_to_rgba(hwFrame->data[0], hwW, hwH,
                                                                    hwFrame->linesize[0], cam.yuyvRgba);
                        if (converted) {
                          recordSourceRgba = cam.yuyvRgba.data();
                          recordSourceW = hwW;
                          recordSourceH = hwH;
                          ensure_plane_texture(cam.yuyvTex, cam.yuyvTexW, cam.yuyvTexH,
                                               GL_RGBA, hwW, hwH, GL_LINEAR);
                          const bool up = upload_plane_texture(cam.yuyvTex, GL_RGBA,
                                                               hwW, hwH, 4,
                                                               cam.yuyvRgba.data(), hwW * 4,
                                                               canUseUnpackRowLength, cam.scratchYuyv);
                          if (up && progRGBA) {
                            glUseProgram(progRGBA);
                            glActiveTexture(GL_TEXTURE0);
                            glBindTexture(GL_TEXTURE_2D, cam.yuyvTex);
                            draw_quad(quad);
                            rendered = true;
                          }
                        }
                      } else if (hwIsNV12) {
                        ensure_plane_texture(cam.uploadYTex, cam.uploadYTexW, cam.uploadYTexH,
                                             GL_LUMINANCE, hwW, hwH, GL_LINEAR);
                        ensure_plane_texture(cam.uploadUVTex, cam.uploadUVTexW, cam.uploadUVTexH,
                                             GL_LUMINANCE_ALPHA, hwChromaW, hwChromaH, GL_LINEAR);
                        const bool upY = upload_plane_texture(cam.uploadYTex, GL_LUMINANCE,
                                                              hwW, hwH, 1,
                                                              hwFrame->data[0], hwFrame->linesize[0],
                                                              canUseUnpackRowLength, cam.scratchY);
                        const bool upUV = upload_plane_texture(cam.uploadUVTex, GL_LUMINANCE_ALPHA,
                                                               hwChromaW, hwChromaH, 2,
                                                               hwFrame->data[1], hwFrame->linesize[1],
                                                               canUseUnpackRowLength, cam.scratchUV);
                        if (upY && upUV && progNV12) {
                          glUseProgram(progNV12);
                          glActiveTexture(GL_TEXTURE0);
                          glBindTexture(GL_TEXTURE_2D, cam.uploadYTex);
                          glActiveTexture(GL_TEXTURE1);
                          glBindTexture(GL_TEXTURE_2D, cam.uploadUVTex);
                          draw_quad(quad);
                          rendered = true;
                        }
                      } else {
                        ensure_plane_texture(cam.mjpegYTex, cam.mjpegYTexW, cam.mjpegYTexH,
                                             GL_LUMINANCE, hwW, hwH, GL_LINEAR);
                        const bool upY = upload_plane_texture(cam.mjpegYTex, GL_LUMINANCE,
                                                              hwW, hwH, 1,
                                                              hwFrame->data[0], hwFrame->linesize[0],
                                                              canUseUnpackRowLength, cam.scratchMjpegY);

                        bool upU = true;
                        bool upV = true;
                        GLuint texU = 0;
                        GLuint texV = 0;
                        if (hwHasChroma) {
                          ensure_plane_texture(cam.mjpegUTex, cam.mjpegUTexW, cam.mjpegUTexH,
                                               GL_LUMINANCE, hwChromaW, hwChromaH, GL_LINEAR);
                          ensure_plane_texture(cam.mjpegVTex, cam.mjpegVTexW, cam.mjpegVTexH,
                                               GL_LUMINANCE, hwChromaW, hwChromaH, GL_LINEAR);
                          upU = upload_plane_texture(cam.mjpegUTex, GL_LUMINANCE,
                                                     hwChromaW, hwChromaH, 1,
                                                     hwFrame->data[1], hwFrame->linesize[1],
                                                     canUseUnpackRowLength, cam.scratchMjpegU);
                          upV = upload_plane_texture(cam.mjpegVTex, GL_LUMINANCE,
                                                     hwChromaW, hwChromaH, 1,
                                                     hwFrame->data[2], hwFrame->linesize[2],
                                                     canUseUnpackRowLength, cam.scratchMjpegV);
                          texU = cam.mjpegUTex;
                          texV = cam.mjpegVTex;
                        } else {
                          init_neutral_luma_texture(cam.neutralChromaTex);
                          texU = cam.neutralChromaTex;
                          texV = cam.neutralChromaTex;
                        }
                        if (upY && upU && upV && texU && texV && progYUVPlanar) {
                          glUseProgram(progYUVPlanar);
                          glActiveTexture(GL_TEXTURE0);
                          glBindTexture(GL_TEXTURE_2D, cam.mjpegYTex);
                          glActiveTexture(GL_TEXTURE1);
                          glBindTexture(GL_TEXTURE_2D, texU);
                          glActiveTexture(GL_TEXTURE2);
                          glBindTexture(GL_TEXTURE_2D, texV);
                          draw_quad(quad);
                          rendered = true;
                        }
                      }
                      if (rendered) {
                        cam.warnedMjpegHwSizeMismatch = false;
                      }
                    }
                  }
                }

                if (!rendered && cam.tjDecoder) {
                  int jpegW = 0;
                  int jpegH = 0;
                  int jpegSubsamp = -1;
                  int jpegColorspace = -1;
                  if (tjDecompressHeader3(cam.tjDecoder, base, static_cast<unsigned long>(bytesUsed),
                                          &jpegW, &jpegH, &jpegSubsamp, &jpegColorspace) == 0) {
                    (void)jpegColorspace;
                    if (jpegW == cam.width && jpegH == cam.height) {
                      if (cam.reconfigure_mjpeg_planes(jpegSubsamp, jpegW, jpegH)) {
                        unsigned char* planes[3] = {
                            cam.mjpegPlaneY.data(),
                            cam.mjpegHasChroma ? cam.mjpegPlaneU.data() : nullptr,
                            cam.mjpegHasChroma ? cam.mjpegPlaneV.data() : nullptr,
                        };
                        int strides[3] = {
                            cam.mjpegPlaneStride[0],
                            cam.mjpegPlaneStride[1],
                            cam.mjpegPlaneStride[2],
                        };
                        if (tjDecompressToYUVPlanes(cam.tjDecoder, base, static_cast<unsigned long>(bytesUsed),
                                                    planes, jpegW, strides, jpegH,
                                                    TJFLAG_FASTDCT | TJFLAG_FASTUPSAMPLE) == 0) {
                          ensure_plane_texture(cam.mjpegYTex, cam.mjpegYTexW, cam.mjpegYTexH,
                                               GL_LUMINANCE, cam.mjpegPlaneW[0], cam.mjpegPlaneH[0], GL_LINEAR);
                          const bool upY = upload_plane_texture(cam.mjpegYTex, GL_LUMINANCE,
                                                                cam.mjpegPlaneW[0], cam.mjpegPlaneH[0], 1,
                                                                cam.mjpegPlaneY.data(), cam.mjpegPlaneStride[0],
                                                                canUseUnpackRowLength, cam.scratchMjpegY);

                          bool upU = true;
                          bool upV = true;
                          GLuint texU = 0;
                          GLuint texV = 0;
                          if (cam.mjpegHasChroma) {
                            ensure_plane_texture(cam.mjpegUTex, cam.mjpegUTexW, cam.mjpegUTexH,
                                                 GL_LUMINANCE, cam.mjpegPlaneW[1], cam.mjpegPlaneH[1], GL_LINEAR);
                            ensure_plane_texture(cam.mjpegVTex, cam.mjpegVTexW, cam.mjpegVTexH,
                                                 GL_LUMINANCE, cam.mjpegPlaneW[2], cam.mjpegPlaneH[2], GL_LINEAR);
                            upU = upload_plane_texture(cam.mjpegUTex, GL_LUMINANCE,
                                                       cam.mjpegPlaneW[1], cam.mjpegPlaneH[1], 1,
                                                       cam.mjpegPlaneU.data(), cam.mjpegPlaneStride[1],
                                                       canUseUnpackRowLength, cam.scratchMjpegU);
                            upV = upload_plane_texture(cam.mjpegVTex, GL_LUMINANCE,
                                                       cam.mjpegPlaneW[2], cam.mjpegPlaneH[2], 1,
                                                       cam.mjpegPlaneV.data(), cam.mjpegPlaneStride[2],
                                                       canUseUnpackRowLength, cam.scratchMjpegV);
                            texU = cam.mjpegUTex;
                            texV = cam.mjpegVTex;
                          } else {
                            init_neutral_luma_texture(cam.neutralChromaTex);
                            texU = cam.neutralChromaTex;
                            texV = cam.neutralChromaTex;
                          }

                          if (upY && upU && upV && texU && texV && progYUVPlanar) {
                            glUseProgram(progYUVPlanar);
                            glActiveTexture(GL_TEXTURE0);
                            glBindTexture(GL_TEXTURE_2D, cam.mjpegYTex);
                            glActiveTexture(GL_TEXTURE1);
                            glBindTexture(GL_TEXTURE_2D, texU);
                            glActiveTexture(GL_TEXTURE2);
                            glBindTexture(GL_TEXTURE_2D, texV);
                            draw_quad(quad);
                            rendered = true;
                            cam.warnedMjpegHeader = false;
                            cam.warnedMjpegDecode = false;
                          }
                        } else if (!cam.warnedMjpegDecode) {
                          std::cerr << "MJPEG decode failed (" << cam.cam.devPath
                                    << "): " << tjGetErrorStr() << "\n";
                          cam.warnedMjpegDecode = true;
                        }
                      } else if (!cam.warnedMjpegUnsupportedSubsamp) {
                        std::cerr << "Unsupported MJPEG subsampling from " << cam.cam.devPath
                                  << " (subsamp=" << jpegSubsamp << ").\n";
                        cam.warnedMjpegUnsupportedSubsamp = true;
                      }
                    } else if (!cam.warnedMjpegSizeMismatch) {
                      std::cerr << "MJPEG frame size mismatch from " << cam.cam.devPath
                                << ": header=" << jpegW << "x" << jpegH
                                << ", configured=" << cam.width << "x" << cam.height << "\n";
                      cam.warnedMjpegSizeMismatch = true;
                    }
                  } else if (!cam.warnedMjpegHeader) {
                    std::cerr << "MJPEG header parse failed (" << cam.cam.devPath
                              << "): " << tjGetErrorStr() << "\n";
                    cam.warnedMjpegHeader = true;
                  }
                }
              }
            } else if (cam.yuyv) {
              if (cam.yuyvCpuConvert) {
                const bool converted = convert_yuyv_to_rgba(base, cam.width, cam.height, cam.strideY,
                                                            cam.yuyvRgba);
                if (converted) {
                  recordSourceRgba = cam.yuyvRgba.data();
                  recordSourceW = cam.width;
                  recordSourceH = cam.height;
                  ensure_plane_texture(cam.yuyvTex, cam.yuyvTexW, cam.yuyvTexH,
                                       GL_RGBA, cam.width, cam.height, GL_LINEAR);
                  const bool up = upload_plane_texture(cam.yuyvTex, GL_RGBA,
                                                       cam.width, cam.height, 4,
                                                       cam.yuyvRgba.data(), cam.width * 4,
                                                       canUseUnpackRowLength, cam.scratchYuyv);
                  if (up && progRGBA) {
                    glUseProgram(progRGBA);
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, cam.yuyvTex);
                    draw_quad(quad);
                    rendered = true;
                  }
                }
              } else if (progYUYV) {
                ensure_plane_texture(cam.yuyvTex, cam.yuyvTexW, cam.yuyvTexH,
                                     GL_RGBA, cam.width / 2, cam.height, GL_NEAREST);
                const bool up = upload_plane_texture(cam.yuyvTex, GL_RGBA,
                                                     cam.width / 2, cam.height, 4,
                                                     base, cam.strideY, canUseUnpackRowLength,
                                                     cam.scratchYuyv);
                if (up) {
                  glUseProgram(progYUYV);
                  glUniform1f(locYuyvWidth, static_cast<float>(cam.width));
                  glActiveTexture(GL_TEXTURE0);
                  glBindTexture(GL_TEXTURE_2D, cam.yuyvTex);
                  draw_quad(quad);
                  rendered = true;
                }
              }
            }
          }
        }

        if (!rendered) {
          glClearColor(0.08f, 0.08f, 0.08f, 1.0f);
          glClear(GL_COLOR_BUFFER_BIT);
        }

        if (showFpsOverlay) {
          // Keep overlay bookkeeping entirely out of the hot path unless -fps is explicitly requested.
          const auto now = std::chrono::steady_clock::now();
          if (!cam.fpsStarted) {
            cam.fpsStarted = true;
            cam.fpsWindowStart = now;
            cam.fpsFrameCount = 0;
            cam.fpsValue = 0.0;
          }
          if (rendered) ++cam.fpsFrameCount;
          const double fpsElapsed =
              std::chrono::duration_cast<std::chrono::duration<double>>(now - cam.fpsWindowStart).count();
          if (fpsElapsed >= 0.4) {
            cam.fpsValue = (fpsElapsed > 0.0) ? (static_cast<double>(cam.fpsFrameCount) / fpsElapsed) : 0.0;
            cam.fpsFrameCount = 0;
            cam.fpsWindowStart = now;
          }

          char overlayBuf[96];
          std::snprintf(overlayBuf, sizeof(overlayBuf), "%dx%d %.1f FPS", cam.width, cam.height, cam.fpsValue);
          const std::string nextOverlayText(overlayBuf);
          if (nextOverlayText != cam.overlayText || cam.overlayTex == 0) {
            cam.overlayText = nextOverlayText;
            int overlayW = 0;
            int overlayH = 0;
            overlay_dimensions_for_text(cam.overlayText, overlayW, overlayH);
            render_overlay_text_rgba(cam.overlayRgba, overlayW, overlayH, cam.overlayText);
            ensure_plane_texture(cam.overlayTex, cam.overlayTexW, cam.overlayTexH,
                                 GL_RGBA, overlayW, overlayH, GL_LINEAR);
            if (!cam.overlayRgba.empty()) {
              glBindTexture(GL_TEXTURE_2D, cam.overlayTex);
              glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
              glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, overlayW, overlayH,
                              GL_RGBA, GL_UNSIGNED_BYTE, cam.overlayRgba.data());
            }
          }
        }
        if (cam.record && cam.recorder.enabled) {
          const int winW = std::max(1, wins[i].geom.w);
          const int winH = std::max(1, wins[i].geom.h);
          const bool useDirectRgba =
              recordSourceRgba && recordSourceW > 0 && recordSourceH > 0 &&
              recordSourceW == winW && recordSourceH == winH;
          const int recW = useDirectRgba ? recordSourceW : winW;
          const int recH = useDirectRgba ? recordSourceH : winH;
          const std::string recName =
              cam.cam.stableId.empty() ? cam.cam.devPath : cam.cam.stableId;
          if (cam.recorder.ensure_started(recName, recW, recH)) {
            const size_t recBytes =
                static_cast<size_t>(recW) * static_cast<size_t>(recH) * 4u;
            const uint8_t* recPtr = nullptr;
            if (useDirectRgba) {
              recPtr = recordSourceRgba;
            } else {
              cam.recordRgba.resize(recBytes);
              glPixelStorei(GL_PACK_ALIGNMENT, 1);
              glReadPixels(0, 0, recW, recH, GL_RGBA, GL_UNSIGNED_BYTE, cam.recordRgba.data());
              recPtr = cam.recordRgba.data();
            }
            if (!cam.recorder.write_frame(recPtr, recBytes)) {
              cam.record = false;
              std::cerr << "Recording disabled for " << cam.cam.devPath
                        << " due to recorder pipeline failure.\n";
            }
          } else {
            cam.record = false;
            std::cerr << "Recording disabled for " << cam.cam.devPath
                      << " because recorder startup failed.\n";
          }
        }

        if (showFpsOverlay && progRGBA && cam.overlayTex && cam.overlayTexW > 0 && cam.overlayTexH > 0) {
          const int viewW = std::max(1, wins[i].geom.w);
          const int viewH = std::max(1, wins[i].geom.h);
          int overlayW = std::min(cam.overlayTexW, viewW);
          int overlayH = std::min(cam.overlayTexH, viewH);
          int overlayX = 8;
          int overlayY = 8;  // Bottom-left origin in make_overlay_quad.
          if (overlayX + overlayW > viewW) overlayX = 0;
          if (overlayY + overlayH > viewH) overlayY = 0;
          GLfloat overlayQuad[16];
          make_overlay_quad(viewW, viewH, overlayX, overlayY, overlayW, overlayH, overlayQuad);
          glEnable(GL_BLEND);
          glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
          glUseProgram(progRGBA);
          glActiveTexture(GL_TEXTURE0);
          glBindTexture(GL_TEXTURE_2D, cam.overlayTex);
          draw_quad(overlayQuad);
          glDisable(GL_BLEND);
        }

        if (runtimeStrictGpuSync) glFinish();
        else glFlush();
        eglSwapBuffers(edpy, wins[i].surf);
      }

      ioctl(cam.fd, VIDIOC_QBUF, &b);
    }

    if (adaptiveGpuSync) {
      const auto now = std::chrono::steady_clock::now();
      const auto windowMs = std::chrono::duration_cast<std::chrono::milliseconds>(now - syncWindowStart).count();
      if (windowMs >= 800) {
        if (syncStutterEvents >= 3) {
          if (!runtimeStrictGpuSync) {
            runtimeStrictGpuSync = true;
            std::cerr << "Adaptive sync: switching to strict glFinish() due to stutter.\n";
          }
          syncQuietWindows = 0;
        } else {
          if (runtimeStrictGpuSync) {
            ++syncQuietWindows;
            if (syncQuietWindows >= 3) {
              runtimeStrictGpuSync = false;
              syncQuietWindows = 0;
              std::cerr << "Adaptive sync: returning to low-latency glFlush().\n";
            }
          }
        }
        syncStutterEvents = 0;
        syncWindowStart = now;
      }
    }

    if (positionsDirty) {
      save_positions_csv(positionsCsv, saved);
      positionsDirty = false;
    }
  }

  for (size_t i = 0; i < wins.size(); ++i) {
    if (!wins[i].win) continue;
    int rx = 0, ry = 0;
    x11_get_window_root_xy(dpy, wins[i].win, rx, ry);
    XWindowAttributes wa{};
    XGetWindowAttributes(dpy, wins[i].win, &wa);
    saved[vcams[i].cam.stableId] = {rx, ry, wa.width, wa.height};
    savedResolutions[vcams[i].cam.stableId] = {vcams[i].width, vcams[i].height};
  }
  save_positions_csv(positionsCsv, saved);
  save_resolutions_csv(resolutionsCsv, savedResolutions);

  bool haveCurrent = false;
  if (!wins.empty() && wins[0].surf != EGL_NO_SURFACE) {
    haveCurrent = eglMakeCurrent(edpy, wins[0].surf, wins[0].surf, ctx) == EGL_TRUE;
  }
  for (auto& cam : vcams) cam.shutdown(eglDestroyImageKHR, edpy);

  for (auto& w : wins) {
    if (w.surf != EGL_NO_SURFACE) eglDestroySurface(edpy, w.surf);
    if (w.win) XDestroyWindow(dpy, w.win);
  }

  if (haveCurrent) {
    if (progNV12) glDeleteProgram(progNV12);
    if (progYUYV) glDeleteProgram(progYUYV);
    if (progYUVPlanar) glDeleteProgram(progYUVPlanar);
    if (progRGBA) glDeleteProgram(progRGBA);
  }
  if (controlFd >= 0) {
    close(controlFd);
    unlink(controlSocketPath.c_str());
  }
  if (eglMakeCurrent(edpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT)) {}
  eglDestroyContext(edpy, ctx);
  eglTerminate(edpy);
  XCloseDisplay(dpy);
  return 0;
}
