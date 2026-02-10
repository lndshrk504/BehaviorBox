#include <SDL2/SDL.h>
#include <opencv2/opencv.hpp>

#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>

#include <algorithm>
#include <atomic>
#include <cerrno>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <memory>
#include <mutex>
#include <optional>
#include <sstream>
#include <string>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace fs = std::filesystem;

static constexpr int MAX_CAMERAS = 4;
static constexpr int DEFAULT_FRAME_W = 320;
static constexpr int DEFAULT_FRAME_H = 184;
static constexpr int BYTES_PER_PIXEL = 3; // BGR24

struct Rect {
  int x{SDL_WINDOWPOS_CENTERED};
  int y{SDL_WINDOWPOS_CENTERED};
  int w{DEFAULT_FRAME_W};
  int h{DEFAULT_FRAME_H};
};

struct CamInfo {
  std::string devPath;   // /dev/videoN
  std::string card;      // human readable
  std::string busInfo;   // stable-ish identifier
  std::string stableId;  // what we store in CSV
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
  int nodeNumber{-1}; // from /dev/videoN
  int sysfsIndex{-1}; // from /sys/class/video4linux/videoN/index
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

static bool probe_capture_stream(const std::string& devPath) {
  cv::VideoCapture probe;
  if (!probe.open(devPath, cv::CAP_V4L2)) {
    std::cerr << "Probe open failed: " << devPath << "\n";
    return false;
  }

  probe.set(cv::CAP_PROP_FRAME_WIDTH, DEFAULT_FRAME_W);
  probe.set(cv::CAP_PROP_FRAME_HEIGHT, DEFAULT_FRAME_H);
  probe.set(cv::CAP_PROP_BUFFERSIZE, 1);
  probe.set(cv::CAP_PROP_FOURCC, cv::VideoWriter::fourcc('M', 'J', 'P', 'G'));

  cv::Mat frame;
  for (int i = 0; i < 80; ++i) {
    if (probe.read(frame) && !frame.empty()) {
      probe.release();
      return true;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(25));
  }

  std::cerr << "Probe read failed: " << devPath << "\n";
  probe.release();
  return false;
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

static bool stepwise_contains(const v4l2_frmsize_stepwise& sw, uint32_t w, uint32_t h) {
  if (w < sw.min_width || w > sw.max_width || h < sw.min_height || h > sw.max_height) return false;
  if (sw.step_width > 0 && ((w - sw.min_width) % sw.step_width) != 0) return false;
  if (sw.step_height > 0 && ((h - sw.min_height) % sw.step_height) != 0) return false;
  return true;
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
        v4l2_frmsizeenum fsEnum{};
        fsEnum.pixel_format = fmt.pixelformat;
        fsEnum.index = sizeIdx;
        if (ioctl(fd, VIDIOC_ENUM_FRAMESIZES, &fsEnum) != 0) break;

        if (fsEnum.type == V4L2_FRMSIZE_TYPE_DISCRETE) {
          add_resolution_unique(out, seen,
                                static_cast<int>(fsEnum.discrete.width),
                                static_cast<int>(fsEnum.discrete.height));
        } else if (fsEnum.type == V4L2_FRMSIZE_TYPE_STEPWISE ||
                   fsEnum.type == V4L2_FRMSIZE_TYPE_CONTINUOUS) {
          add_stepwise_resolutions(fsEnum.stepwise);
        }
      }
    }
  };

  enum_for_type(V4L2_BUF_TYPE_VIDEO_CAPTURE);
  enum_for_type(V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE);

  ::close(fd);

  if (out.empty()) {
    out.push_back(Resolution{DEFAULT_FRAME_W, DEFAULT_FRAME_H});
  }

  std::sort(out.begin(), out.end(),
            [](const Resolution& a, const Resolution& b) {
              const int64_t areaA = static_cast<int64_t>(a.w) * static_cast<int64_t>(a.h);
              const int64_t areaB = static_cast<int64_t>(b.w) * static_cast<int64_t>(b.h);
              if (areaA != areaB) return areaA < areaB;
              if (a.w != b.w) return a.w < b.w;
              return a.h < b.h;
            });
  return out;
}

static Resolution choose_resolution_interactively(const CamInfo& cam,
                                                  const std::vector<Resolution>& available,
                                                  const Resolution& fallback) {
  if (available.empty()) return fallback;

  size_t defaultIdx = 0;
  for (size_t i = 0; i < available.size(); ++i) {
    if (available[i].w == fallback.w && available[i].h == fallback.h) {
      defaultIdx = i;
      break;
    }
  }

  std::cout << "\nCamera: " << cam.card << " [" << cam.devPath << "]\n";
  std::cout << "Available resolutions:\n";
  for (size_t i = 0; i < available.size(); ++i) {
    std::cout << "  " << (i + 1) << ") " << available[i].w << "x" << available[i].h << "\n";
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
    if (!best.has_value() || r.w > best->w) best = r;
  }
  return best;
}

static int choose_common_height_interactively(
    const std::vector<int>& heights,
    const std::vector<CamInfo>& orderedCams,
    const std::unordered_map<std::string, std::vector<Resolution>>& availableByStableId,
    int fallbackHeight) {
  if (heights.empty()) return fallbackHeight;

  size_t defaultIdx = 0;
  for (size_t i = 0; i < heights.size(); ++i) {
    if (heights[i] == fallbackHeight) {
      defaultIdx = i;
      break;
    }
  }

  std::cout << "\nAll-camera resolution mode:\n";
  std::cout << "Select one pixel height that all cameras can use.\n";
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

    if (preferredIdx < 0) {
      std::cerr << "Probe failed for all nodes in group " << kv.first
                << ", keeping all candidates for startup fallback.\n";
    }

    if (preferredIdx >= 0) {
      selected.push_back(cands[preferredIdx]);
    }
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

static std::unordered_map<std::string, Rect> load_positions_csv(const std::string& file) {
  std::unordered_map<std::string, Rect> out;
  std::ifstream in(file);
  if (!in.is_open()) return out;

  std::string line;
  bool first = true;
  while (std::getline(in, line)) {
    line = trim(line);
    if (line.empty()) continue;

    if (first) {
      first = false; // skip header (expected)
      if (line.find("camera_id") != std::string::npos) continue;
    }

    // Very simple CSV parsing: camera_id,x,y,w,h
    // camera_id should not contain commas (we store bus_info)
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
    } catch (...) {
      continue;
    }
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

struct CameraWindow {
  CamInfo cam;
  int frameW{DEFAULT_FRAME_W};
  int frameH{DEFAULT_FRAME_H};

  SDL_Window* window{nullptr};
  SDL_Renderer* renderer{nullptr};
  SDL_Texture* texture{nullptr};
  Uint32 windowId{0};

  cv::VideoCapture cap;
  std::thread captureThread;
  std::atomic<bool> running{false};

  std::mutex frameMutex;
  std::vector<uint8_t> bgr; // DISP_W * DISP_H * 3
  bool hasFrame{false};

  ~CameraWindow() {
    stop();
    destroy_sdl();
  }

  void stop() {
    running.store(false);
    if (captureThread.joinable()) captureThread.join();
    if (cap.isOpened()) cap.release();
  }

  void destroy_sdl() {
    if (texture) { SDL_DestroyTexture(texture); texture = nullptr; }
    if (renderer) { SDL_DestroyRenderer(renderer); renderer = nullptr; }
    if (window) { SDL_DestroyWindow(window); window = nullptr; }
  }

  bool init_sdl(const Rect& r) {
    std::string title = cam.card + " [" + cam.devPath + "]";
    window = SDL_CreateWindow(
        title.c_str(),
        r.x, r.y,
        r.w, r.h,
        SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN);

    if (!window) {
      std::cerr << "SDL_CreateWindow failed: " << SDL_GetError() << "\n";
      return false;
    }
    windowId = SDL_GetWindowID(window);

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!renderer) {
      // Fallback for systems lacking an accelerated renderer.
      renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    }
    if (!renderer) {
      std::cerr << "SDL_CreateRenderer failed: " << SDL_GetError() << "\n";
      return false;
    }

    texture = SDL_CreateTexture(renderer,
                                SDL_PIXELFORMAT_BGR24,
                                SDL_TEXTUREACCESS_STREAMING,
                                frameW, frameH);
    if (!texture) {
      std::cerr << "SDL_CreateTexture failed: " << SDL_GetError() << "\n";
      return false;
    }

    SDL_ShowWindow(window);
    return true;
  }

  bool init_capture() {
    // Open the exact verified device node instead of integer camera indices.
    if (!cap.open(cam.devPath, cv::CAP_V4L2)) {
      cap.open(cam.devPath, cv::CAP_ANY);
    }

    if (!cap.isOpened()) {
      std::cerr << "Failed to open camera: " << cam.devPath << "\n";
      return false;
    }

    // Ask for small frames to reduce bandwidth/CPU. Not guaranteed.
    cap.set(cv::CAP_PROP_FRAME_WIDTH, frameW);
    cap.set(cv::CAP_PROP_FRAME_HEIGHT, frameH);
    cap.set(cv::CAP_PROP_BUFFERSIZE, 1);
    cap.set(cv::CAP_PROP_FOURCC, cv::VideoWriter::fourcc('M', 'J', 'P', 'G'));

    bgr.resize(static_cast<size_t>(frameW) * static_cast<size_t>(frameH) * BYTES_PER_PIXEL);
    running.store(true);

    captureThread = std::thread([this]() {
      cv::Mat frame, resized;
      resized.create(frameH, frameW, CV_8UC3);

      while (running.load()) {
        if (!cap.read(frame) || frame.empty()) {
          std::this_thread::sleep_for(std::chrono::milliseconds(10));
          continue;
        }

        // Ensure 3-channel BGR
        if (frame.channels() == 1) {
          cv::cvtColor(frame, frame, cv::COLOR_GRAY2BGR);
        } else if (frame.channels() == 4) {
          cv::cvtColor(frame, frame, cv::COLOR_BGRA2BGR);
        }

        // Resize to display texture size (constant)
        if (frame.cols != frameW || frame.rows != frameH) {
          cv::resize(frame, resized, cv::Size(frameW, frameH), 0, 0, cv::INTER_AREA);
        } else {
          resized = frame;
        }

        if (!resized.isContinuous()) resized = resized.clone();

        {
          std::lock_guard<std::mutex> lk(frameMutex);
          std::memcpy(bgr.data(), resized.data, bgr.size());
          hasFrame = true;
        }
      }
    });

    return true;
  }

  void render() {
    bool localHasFrame = false;
    {
      std::lock_guard<std::mutex> lk(frameMutex);
      localHasFrame = hasFrame;
      if (localHasFrame) {
        SDL_UpdateTexture(texture, nullptr, bgr.data(), frameW * BYTES_PER_PIXEL);
      }
    }

    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);

    int ww=0, wh=0;
    SDL_GetWindowSize(window, &ww, &wh);
    if (ww <= 0 || wh <= 0) {
      SDL_RenderPresent(renderer);
      return;
    }

    const float srcAspect = float(frameW) / float(frameH);
    float dstW = float(ww), dstH = float(wh);
    float dstAspect = dstW / dstH;

    SDL_Rect dst{};
    if (dstAspect > srcAspect) {
      dst.h = wh;
      dst.w = int(float(wh) * srcAspect);
      dst.x = (ww - dst.w) / 2;
      dst.y = 0;
    } else {
      dst.w = ww;
      dst.h = int(float(ww) / srcAspect);
      dst.x = 0;
      dst.y = (wh - dst.h) / 2;
    }

    if (localHasFrame) SDL_RenderCopy(renderer, texture, nullptr, &dst);
    SDL_RenderPresent(renderer);
  }
};

static void update_and_persist_position(const CameraWindow& cw,
                                        std::unordered_map<std::string, Rect>& pos,
                                        const std::string& csvFile) {
  Rect r;
  SDL_GetWindowPosition(cw.window, &r.x, &r.y);
  SDL_GetWindowSize(cw.window, &r.w, &r.h);
  pos[cw.cam.stableId] = r;
  (void)save_positions_csv(csvFile, pos);
}

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
      return 0;
    }
    std::cerr << "Warning: unknown argument '" << arg << "' (ignored)\n";
  }

  if (chooseEachResolution && chooseAllResolution) {
    std::cerr << "Choose only one resolution mode: -choose-each-res or -choose-all-res\n";
    return 1;
  }

  const std::string positionsFile = positions_file();
  const std::string resolutionsFile = resolutions_file();

  std::unordered_map<std::string, Rect> saved;
  if (!resetWindowPositions) {
    saved = load_positions_csv(positionsFile);
  } else {
    std::cerr << "Ignoring saved window positions due to -reset.\n";
  }
  auto savedResolutions = load_resolutions_csv(resolutionsFile);
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

  if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) != 0) {
    std::cerr << "SDL_Init failed: " << SDL_GetError() << "\n";
    return 1;
  }

  std::unordered_set<std::string> discoveredStableIds;
  for (const auto& cam : cams) discoveredStableIds.insert(cam.stableId);
  const int targetWindowCount =
      std::min<int>(MAX_CAMERAS, static_cast<int>(discoveredStableIds.size()));

  std::vector<std::unique_ptr<CameraWindow>> windows;
  windows.reserve(static_cast<size_t>(targetWindowCount));
  std::unordered_set<std::string> openedStableIds;
  std::unordered_map<std::string, Resolution> chosenResolutionByStableId;

  std::vector<CamInfo> orderedUniqueCams;
  orderedUniqueCams.reserve(static_cast<size_t>(targetWindowCount));
  {
    std::unordered_set<std::string> seen;
    for (const auto& cam : cams) {
      if (seen.insert(cam.stableId).second) {
        orderedUniqueCams.push_back(cam);
        if ((int)orderedUniqueCams.size() >= targetWindowCount) break;
      }
    }
  }

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
      if (!selected.has_value()) {
        // Should not happen once commonHeights was computed, but keep a safe fallback.
        selected = Resolution{DEFAULT_FRAME_W, DEFAULT_FRAME_H};
      }
      chosenResolutionByStableId[cam.stableId] = *selected;
      std::cerr << "Chosen all-camera resolution for " << cam.devPath
                << ": " << selected->w << "x" << selected->h << "\n";
    }
  }

  for (const auto& cam : cams) {
    if ((int)windows.size() >= targetWindowCount) break;
    if (openedStableIds.find(cam.stableId) != openedStableIds.end()) continue;

    Resolution desired;
    auto desiredIt = chosenResolutionByStableId.find(cam.stableId);
    if (desiredIt != chosenResolutionByStableId.end()) {
      desired = desiredIt->second;
    } else {
      if (chooseEachResolution) {
        const auto available = enumerate_supported_resolutions(cam.devPath);
        desired = choose_resolution_interactively(cam, available, desired);
      } else {
        auto savedResIt = savedResolutions.find(cam.stableId);
        if (savedResIt != savedResolutions.end()) desired = savedResIt->second;
      }
      chosenResolutionByStableId[cam.stableId] = desired;
    }

    auto cw = std::make_unique<CameraWindow>();
    cw->cam = cam;
    cw->frameW = desired.w;
    cw->frameH = desired.h;

    Rect r;
    auto it = saved.find(cam.stableId);
    if (it != saved.end()) r = it->second;
    if (chooseEachResolution || chooseAllResolution) {
      r.w = desired.w;
      r.h = desired.h;
    }

    if (!cw->init_sdl(r)) continue;
    if (!cw->init_capture()) {
      std::cerr << "Failed camera candidate " << cam.devPath
                << " (group=" << cam.stableId << "), trying next candidate.\n";
      cw->destroy_sdl();
      continue;
    }

    openedStableIds.insert(cam.stableId);
    savedResolutions[cam.stableId] = desired;
    (void)save_resolutions_csv(resolutionsFile, savedResolutions);
    std::cerr << "Started camera window: " << cam.devPath
              << " @ " << desired.w << "x" << desired.h << "\n";
    windows.emplace_back(std::move(cw));
  }

  if (windows.empty()) {
    std::cerr << "No camera windows could be created.\n";
    SDL_Quit();
    return 1;
  }

  bool quit = false;
  while (!quit && !windows.empty()) {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT) {
        for (auto& cw : windows) update_and_persist_position(*cw, saved, positionsFile);
        quit = true;
        break;
      }

      if (e.type == SDL_WINDOWEVENT && e.window.event == SDL_WINDOWEVENT_CLOSE) {
        const Uint32 closingId = e.window.windowID;

        for (size_t i = 0; i < windows.size(); ++i) {
          if (windows[i]->windowId == closingId) {
            update_and_persist_position(*windows[i], saved, positionsFile);
            windows[i]->stop();
            windows[i]->destroy_sdl();
            windows.erase(windows.begin() + i);
            break;
          }
        }
        if (windows.empty()) { quit = true; break; }
      }
    }

    for (auto& cw : windows) cw->render();
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }

  for (auto& cw : windows) update_and_persist_position(*cw, saved, positionsFile);
  for (const auto& cw : windows) {
    savedResolutions[cw->cam.stableId] = Resolution{cw->frameW, cw->frameH};
  }
  (void)save_resolutions_csv(resolutionsFile, savedResolutions);

  windows.clear();
  SDL_Quit();
  return 0;
}
