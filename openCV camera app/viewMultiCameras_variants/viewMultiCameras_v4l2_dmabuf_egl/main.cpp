#include <X11/Xlib.h>
#include <X11/Xatom.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#include <drm/drm_fourcc.h>

#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <poll.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
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

static std::string to_lower_ascii(std::string s) {
  for (char& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return s;
}

static bool str_contains_case_insensitive(const std::string& haystack, const std::string& needle) {
  if (needle.empty()) return true;
  return to_lower_ascii(haystack).find(to_lower_ascii(needle)) != std::string::npos;
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

static bool probe_capture_stream(const std::string& devPath) {
  int fd = ::open(devPath.c_str(), O_RDWR | O_NONBLOCK);
  if (fd < 0) return false;

  auto close_fd = [&]() {
    if (fd >= 0) {
      ::close(fd);
      fd = -1;
    }
  };

  v4l2_capability cap{};
  if (ioctl(fd, VIDIOC_QUERYCAP, &cap) != 0) {
    close_fd();
    return false;
  }
  const uint32_t effectiveCaps =
      (cap.capabilities & V4L2_CAP_DEVICE_CAPS) ? cap.device_caps : cap.capabilities;
  const bool hasCapture =
      (effectiveCaps & V4L2_CAP_VIDEO_CAPTURE) ||
      (effectiveCaps & V4L2_CAP_VIDEO_CAPTURE_MPLANE);
  if (!hasCapture) {
    close_fd();
    return false;
  }

  v4l2_format fmt{};
  fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  fmt.fmt.pix.width = DEFAULT_FRAME_W;
  fmt.fmt.pix.height = DEFAULT_FRAME_H;
  fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_NV12;
  fmt.fmt.pix.field = V4L2_FIELD_NONE;
  if (ioctl(fd, VIDIOC_S_FMT, &fmt) == 0 && fmt.fmt.pix.pixelformat == V4L2_PIX_FMT_NV12) {
    close_fd();
    return true;
  }

  std::memset(&fmt, 0, sizeof(fmt));
  fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  fmt.fmt.pix.width = DEFAULT_FRAME_W;
  fmt.fmt.pix.height = DEFAULT_FRAME_H;
  fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
  fmt.fmt.pix.field = V4L2_FIELD_NONE;
  const bool ok = (ioctl(fd, VIDIOC_S_FMT, &fmt) == 0 &&
                   fmt.fmt.pix.pixelformat == V4L2_PIX_FMT_YUYV &&
                   (fmt.fmt.pix.width % 2) == 0);
  close_fd();
  return ok;
}

static CameraScanResult enumerate_cameras() {
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
    for (size_t i = 0; i < cands.size(); ++i) {
      if (!probe_capture_stream(cands[i].cam.devPath)) continue;
      preferredIdx = static_cast<int>(i);
      cands[i].preferred = true;
      break;
    }
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

static bool x11_get_window_root_xy(Display* dpy, Window w, int& rx, int& ry) {
  Window child;
  int wx, wy;
  if (!XTranslateCoordinates(dpy, w, DefaultRootWindow(dpy), 0, 0, &wx, &wy, &child)) return false;
  rx = wx;
  ry = wy;
  return true;
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
precision mediump float;
varying vec2 vUV;
uniform sampler2D texYUYV;
uniform float frameWidth;
void main() {
  float pixelX = floor(vUV.x * frameWidth);
  float pairX = floor(pixelX * 0.5);
  float pairWidth = frameWidth * 0.5;

  vec2 packedUV = vec2((pairX + 0.5) / pairWidth, vUV.y);
  vec4 yuyv = texture2D(texYUYV, packedUV);

  float y = (mod(pixelX, 2.0) < 0.5) ? yuyv.r : yuyv.b;
  float u = yuyv.g - 0.5;
  float v = yuyv.a - 0.5;

  float r = y + 1.402 * v;
  float g = y - 0.344136 * u - 0.714136 * v;
  float b = y + 1.772 * u;
  gl_FragColor = vec4(r, g, b, 1.0);
}
)";

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

static void draw_quad(const GLfloat* quad) {
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), quad + 0);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), quad + 2);
  glEnableVertexAttribArray(1);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

static void configure_nvidia_offload_env() {
  // Respect user-provided values if they already exist.
  setenv("__NV_PRIME_RENDER_OFFLOAD", "1", 0);
  setenv("__GLX_VENDOR_LIBRARY_NAME", "nvidia", 0);
  setenv("__VK_LAYER_NV_optimus", "NVIDIA_only", 0);
}

static bool ensure_nvidia_context(EGLDisplay edpy, EGLConfig cfg, EGLContext ctx) {
  EGLint pbAttrs[] = {EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE};
  EGLSurface probe = eglCreatePbufferSurface(edpy, cfg, pbAttrs);
  if (probe == EGL_NO_SURFACE) {
    std::cerr << "Failed to create EGL probe surface for renderer verification.\n";
    return false;
  }
  if (!eglMakeCurrent(edpy, probe, probe, ctx)) {
    std::cerr << "eglMakeCurrent failed during renderer verification.\n";
    eglDestroySurface(edpy, probe);
    return false;
  }

  const char* eglVendor = eglQueryString(edpy, EGL_VENDOR);
  const char* glVendor = reinterpret_cast<const char*>(glGetString(GL_VENDOR));
  const char* glRenderer = reinterpret_cast<const char*>(glGetString(GL_RENDERER));
  std::cerr << "EGL vendor: " << (eglVendor ? eglVendor : "(null)") << "\n";
  std::cerr << "GL vendor: " << (glVendor ? glVendor : "(null)") << "\n";
  std::cerr << "GL renderer: " << (glRenderer ? glRenderer : "(null)") << "\n";

  bool isNvidia = false;
  if (eglVendor && str_contains_case_insensitive(eglVendor, "nvidia")) isNvidia = true;
  if (glVendor && str_contains_case_insensitive(glVendor, "nvidia")) isNvidia = true;
  if (glRenderer && str_contains_case_insensitive(glRenderer, "nvidia")) isNvidia = true;

  eglMakeCurrent(edpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  eglDestroySurface(edpy, probe);

  if (!isNvidia) {
    std::cerr << "ERROR: active renderer is not NVIDIA. Aborting to keep processing off CPU/non-NVIDIA GPUs.\n";
    std::cerr << "Tip: run with NVIDIA PRIME offload enabled.\n";
    return false;
  }
  return true;
}

// ---- V4L2 + DMABUF ----
struct V4L2DmabufCam {
  CamInfo cam;
  int requestedW{DEFAULT_FRAME_W};
  int requestedH{DEFAULT_FRAME_H};
  int fd{-1};
  int width{0}, height{0};
  int strideY{0}, strideUV{0};
  bool nv12{false};
  bool yuyv{false};
  GLuint uploadYTex{0};
  GLuint uploadUVTex{0};
  GLuint yuyvTex{0};
  std::vector<uint8_t> scratchY;
  std::vector<uint8_t> scratchUV;
  std::vector<uint8_t> scratchYuyv;

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

  bool open_and_configure() {
    fd = ::open(cam.devPath.c_str(), O_RDWR | O_NONBLOCK);
    if (fd < 0) { std::cerr << "open failed: " << cam.devPath << "\n"; return false; }

    nv12 = false;
    yuyv = false;

    auto fail = [&]() -> bool {
      for (auto& b : bufs) {
        if (b.ptr && b.ptr != MAP_FAILED) munmap(b.ptr, b.len);
        if (b.dmabuf >= 0) close(b.dmabuf);
        b = Buf{};
      }
      bufs.clear();
      if (fd >= 0) {
        close(fd);
        fd = -1;
      }
      return false;
    };

    v4l2_format fmt{};
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    fmt.fmt.pix.width = requestedW;
    fmt.fmt.pix.height = requestedH;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_NV12;
    fmt.fmt.pix.field = V4L2_FIELD_NONE;

    if (ioctl(fd, VIDIOC_S_FMT, &fmt) == 0 && fmt.fmt.pix.pixelformat == V4L2_PIX_FMT_NV12) {
      nv12 = true;
      yuyv = false;
    } else {
      // Packed YUYV fallback; conversion remains on GPU via fragment shader.
      std::memset(&fmt, 0, sizeof(fmt));
      fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
      fmt.fmt.pix.width = requestedW;
      fmt.fmt.pix.height = requestedH;
      fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
      fmt.fmt.pix.field = V4L2_FIELD_NONE;
      if (ioctl(fd, VIDIOC_S_FMT, &fmt) != 0) {
        std::cerr << "VIDIOC_S_FMT failed for NV12 and YUYV: " << cam.devPath
                  << " (requested " << requestedW << "x" << requestedH << ")\n";
        return fail();
      }
      if (fmt.fmt.pix.pixelformat != V4L2_PIX_FMT_YUYV) {
        std::cerr << "Unsupported fallback format from " << cam.devPath
                  << ": '" << fourcc_to_string(fmt.fmt.pix.pixelformat)
                  << "' (need NV12 or YUYV).\n";
        return fail();
      }
      nv12 = false;
      yuyv = true;
      std::cerr << "Warning: " << cam.devPath
                << " is YUYV; using GPU shader conversion path.\n";
    }

    width = (int)fmt.fmt.pix.width;
    height = (int)fmt.fmt.pix.height;
    if (yuyv && (width % 2) != 0) {
      std::cerr << "Unsupported odd-width YUYV frame from " << cam.devPath
                << ": " << width << "x" << height << "\n";
      return fail();
    }
    strideY = (int)fmt.fmt.pix.bytesperline;
    if (strideY <= 0) strideY = nv12 ? width : width * 2;
    strideUV = nv12 ? strideY : 0;
    std::cerr << "Configured " << cam.devPath << ": "
              << width << "x" << height << " " << fourcc_to_string(fmt.fmt.pix.pixelformat)
              << " (stride=" << strideY << ")\n";

    v4l2_requestbuffers req{};
    req.count = 4;
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
    if (uploadYTex) glDeleteTextures(1, &uploadYTex);
    if (uploadUVTex) glDeleteTextures(1, &uploadUVTex);
    if (yuyvTex) glDeleteTextures(1, &yuyvTex);
    uploadYTex = 0;
    uploadUVTex = 0;
    yuyvTex = 0;
    scratchY.clear();
    scratchUV.clear();
    scratchYuyv.clear();
    if (fd >= 0) { close(fd); fd = -1; }
  }
};

struct XWin {
  Window win{0};
  EGLSurface surf{EGL_NO_SURFACE};
  Rect geom{};
};

int main(int argc, char** argv) {
  bool resetWindowPositions = false;
  bool chooseEachResolution = false;
  bool chooseAllResolution = false;
  for (int i = 1; i < argc; ++i) {
    const std::string arg = argv[i];
    if (arg == "-reset" || arg == "--reset") {
      resetWindowPositions = true;
      continue;
    }
    if (arg == "-choose-each-res" || arg == "--choose-each-resolution" ||
        arg == "-choose-res" || arg == "--choose-resolution") {
      chooseEachResolution = true;
      continue;
    }
    if (arg == "-choose-all-res" || arg == "--choose-all-resolution") {
      chooseAllResolution = true;
      continue;
    }
    if (arg == "-h" || arg == "--help") {
      std::cout << "Usage: " << argv[0] << " [-reset] [-choose-each-res] [-choose-all-res]\n";
      std::cout << "  -reset   Ignore saved window positions and start with defaults.\n";
      std::cout << "  -choose-each-res   Choose resolution separately for each camera.\n";
      std::cout << "  -choose-all-res    Choose one common pixel height for all cameras.\n";
      std::cout << "  Requires active NVIDIA EGL/GL renderer; exits otherwise.\n";
      return 0;
    }
    std::cerr << "Warning: unknown argument '" << arg << "' (ignored)\n";
  }

  if (chooseEachResolution && chooseAllResolution) {
    std::cerr << "Choose only one resolution mode: -choose-each-res or -choose-all-res\n";
    return 1;
  }

  configure_nvidia_offload_env();

  const std::string positionsCsv = positions_file();
  const std::string resolutionsCsv = resolutions_file();

  std::unordered_map<std::string, Rect> saved;
  if (!resetWindowPositions) {
    saved = load_positions_csv(positionsCsv);
  } else {
    std::cerr << "Ignoring saved window positions due to -reset.\n";
  }
  auto savedResolutions = load_resolutions_csv(resolutionsCsv);

  auto scan = enumerate_cameras();
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
      std::cerr << "Use -choose-each-res to set per-camera resolutions instead.\n";
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
  if (!ensure_nvidia_context(edpy, cfg, ctx)) {
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
  if (!eglCreateImageKHR || !eglDestroyImageKHR || !glEGLImageTargetTexture2DOES) {
    std::cerr << "Missing EGLImage extension functions.\n";
    eglDestroyContext(edpy, ctx);
    eglTerminate(edpy);
    XCloseDisplay(dpy);
    return 1;
  }

  std::vector<XWin> wins;
  std::vector<V4L2DmabufCam> vcams;
  wins.reserve(static_cast<size_t>(targetWindowCount));
  vcams.reserve(static_cast<size_t>(targetWindowCount));

  int screen = DefaultScreen(dpy);
  Window root = RootWindow(dpy, screen);

  std::unordered_set<std::string> openedStableIds;
  for (const auto& c : cams) {
    if (static_cast<int>(wins.size()) >= targetWindowCount) break;
    if (openedStableIds.find(c.stableId) != openedStableIds.end()) continue;

    Resolution desired;
    auto desiredIt = chosenResolutionByStableId.find(c.stableId);
    if (desiredIt != chosenResolutionByStableId.end()) {
      desired = desiredIt->second;
    } else {
      if (chooseEachResolution) {
        const auto available = enumerate_supported_resolutions(c.devPath);
        desired = choose_resolution_interactively(c, available, desired);
      } else {
        auto savedResIt = savedResolutions.find(c.stableId);
        if (savedResIt != savedResolutions.end()) desired = savedResIt->second;
      }
      chosenResolutionByStableId[c.stableId] = desired;
    }

    Rect r{};
    auto it = saved.find(c.stableId);
    if (it != saved.end()) r = it->second;
    if (chooseEachResolution || chooseAllResolution) {
      r.w = desired.w;
      r.h = desired.h;
    }

    Window w = XCreateSimpleWindow(dpy, root, r.x, r.y, (unsigned)r.w, (unsigned)r.h,
                                   0, BlackPixel(dpy, screen), BlackPixel(dpy, screen));
    XStoreName(dpy, w, (c.card + " [" + c.devPath + "]").c_str());
    XSelectInput(dpy, w, StructureNotifyMask | ExposureMask);
    XSetWMProtocols(dpy, w, &WM_DELETE_WINDOW, 1);
    XMapWindow(dpy, w);

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
    if (!cam.open_and_configure()) {
      std::cerr << "Failed camera candidate " << c.devPath
                << " (group=" << c.stableId << "), trying next candidate.\n";
      eglDestroySurface(edpy, surf);
      XDestroyWindow(dpy, w);
      continue;
    }

    if (cam.nv12) {
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
  GLuint progNV12 = make_program(kFS_NV12);
  GLuint progYUYV = make_program(kFS_YUYV);
  GLint locY = glGetUniformLocation(progNV12, "texY");
  GLint locUV = glGetUniformLocation(progNV12, "texUV");
  GLint locYuyv = glGetUniformLocation(progYUYV, "texYUYV");
  GLint locYuyvWidth = glGetUniformLocation(progYUYV, "frameWidth");
  glUseProgram(progNV12);
  glUniform1i(locY, 0);
  glUniform1i(locUV, 1);
  glUseProgram(progYUYV);
  glUniform1i(locYuyv, 0);

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

  const int xfd = ConnectionNumber(dpy);
  std::vector<pollfd> pfds;
  pfds.reserve(1 + vcams.size());

  bool quit = false;
  while (!quit) {
    pfds.clear();
    pfds.push_back({xfd, POLLIN, 0});
    for (auto& c : vcams) if (c.fd >= 0) pfds.push_back({c.fd, POLLIN, 0});
    poll(pfds.data(), pfds.size(), 10);

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
        for (auto& w : wins) {
          if (w.win == ev.xconfigure.window) {
            int rx = 0, ry = 0;
            x11_get_window_root_xy(dpy, w.win, rx, ry);
            w.geom = {rx, ry, ev.xconfigure.width, ev.xconfigure.height};
            break;
          }
        }
      }
    }
    if (quit) break;

    for (size_t i = 0; i < vcams.size(); ++i) {
      auto& cam = vcams[i];

      v4l2_buffer b{};
      b.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
      b.memory = V4L2_MEMORY_MMAP;

      if (ioctl(cam.fd, VIDIOC_DQBUF, &b) != 0) {
        if (errno == EAGAIN) continue;
        std::cerr << "VIDIOC_DQBUF failed (" << cam.cam.devPath << "): " << strerror(errno) << "\n";
        continue;
      }

      if (!eglMakeCurrent(edpy, wins[i].surf, wins[i].surf, ctx)) {
        std::cerr << "eglMakeCurrent failed\n";
        ioctl(cam.fd, VIDIOC_QBUF, &b);
        continue;
      } else {
        glViewport(0, 0, std::max(1, wins[i].geom.w), std::max(1, wins[i].geom.h));
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        if (b.index >= cam.bufs.size()) {
          ioctl(cam.fd, VIDIOC_QBUF, &b);
          continue;
        }

        bool rendered = false;
        if (cam.nv12 && cam.bufs[b.index].yTex && cam.bufs[b.index].uvTex) {
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
              init_plane_texture(cam.uploadYTex, GL_LUMINANCE, cam.width, cam.height, GL_LINEAR);
              init_plane_texture(cam.uploadUVTex, GL_LUMINANCE_ALPHA, cam.width / 2, cam.height / 2, GL_LINEAR);
              const bool upY = upload_plane_texture(cam.uploadYTex, GL_LUMINANCE,
                                                    cam.width, cam.height, 1,
                                                    srcY, cam.strideY, canUseUnpackRowLength,
                                                    cam.scratchY);
              const bool upUV = upload_plane_texture(cam.uploadUVTex, GL_LUMINANCE_ALPHA,
                                                     cam.width / 2, cam.height / 2, 2,
                                                     srcUV, cam.strideUV, canUseUnpackRowLength,
                                                     cam.scratchUV);
              if (upY && upUV) {
                glUseProgram(progNV12);
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_2D, cam.uploadYTex);
                glActiveTexture(GL_TEXTURE1);
                glBindTexture(GL_TEXTURE_2D, cam.uploadUVTex);
                draw_quad(quad);
                rendered = true;
              }
            } else if (cam.yuyv) {
              init_plane_texture(cam.yuyvTex, GL_RGBA, cam.width / 2, cam.height, GL_NEAREST);
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

        if (!rendered) {
          glClearColor(0.08f, 0.08f, 0.08f, 1.0f);
          glClear(GL_COLOR_BUFFER_BIT);
        }

        glFinish();
        eglSwapBuffers(edpy, wins[i].surf);
      }

      ioctl(cam.fd, VIDIOC_QBUF, &b);
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
  }
  if (eglMakeCurrent(edpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT)) {}
  eglDestroyContext(edpy, ctx);
  eglTerminate(edpy);
  XCloseDisplay(dpy);
  return 0;
}
