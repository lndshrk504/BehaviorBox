#include <SDL2/SDL.h>
#include <opencv2/opencv.hpp>

#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>

#include <atomic>
#include <chrono>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
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
static constexpr int DISP_W = 320;
static constexpr int DISP_H = 184;
static constexpr int BYTES_PER_PIXEL = 3; // BGR24
static constexpr int DISP_PITCH = DISP_W * BYTES_PER_PIXEL;

struct Rect {
  int x{SDL_WINDOWPOS_CENTERED};
  int y{SDL_WINDOWPOS_CENTERED};
  int w{DISP_W};
  int h{DISP_H};
};

struct CamInfo {
  std::string devPath;   // /dev/videoN
  std::string card;      // human readable
  std::string busInfo;   // stable-ish identifier
  std::string stableId;  // what we store in CSV
};

static std::string trim(const std::string& s) {
  size_t a = s.find_first_not_of(" \t\r\n");
  size_t b = s.find_last_not_of(" \t\r\n");
  if (a == std::string::npos) return "";
  return s.substr(a, b - a + 1);
}

static std::optional<CamInfo> query_v4l2(const std::string& devPath) {
  int fd = ::open(devPath.c_str(), O_RDONLY | O_NONBLOCK);
  if (fd < 0) return std::nullopt;

  v4l2_capability cap{};
  if (ioctl(fd, VIDIOC_QUERYCAP, &cap) != 0) {
    ::close(fd);
    return std::nullopt;
  }
  ::close(fd);

  // Filter: must support video capture (not metadata-only nodes)
  const bool hasCapture =
      (cap.capabilities & V4L2_CAP_VIDEO_CAPTURE) ||
      (cap.capabilities & V4L2_CAP_VIDEO_CAPTURE_MPLANE);

  if (!hasCapture) return std::nullopt;

  CamInfo info;
  info.devPath = devPath;
  info.card = reinterpret_cast<const char*>(cap.card);
  info.busInfo = reinterpret_cast<const char*>(cap.bus_info);

  // Stable ID preference: bus_info if present, else card + devPath fallback
  if (!trim(info.busInfo).empty()) {
    info.stableId = info.busInfo; // best choice for persistence
  } else {
    info.stableId = info.card + "|" + info.devPath;
  }
  return info;
}

static std::vector<CamInfo> enumerate_cameras() {
  std::vector<CamInfo> cams;
  std::unordered_set<std::string> seenStableIds;

  // Scan /dev/video*
  for (const auto& ent : fs::directory_iterator("/dev")) {
    const auto name = ent.path().filename().string();
    if (name.rfind("video", 0) != 0) continue;

    const std::string devPath = ent.path().string();
    auto qi = query_v4l2(devPath);
    if (!qi) continue;

    // Dedupe: many UVC devices expose multiple nodes
    if (seenStableIds.insert(qi->stableId).second) {
      cams.push_back(*qi);
    }
  }

  // Sort by device path for deterministic ordering
  std::sort(cams.begin(), cams.end(),
            [](const CamInfo& a, const CamInfo& b) { return a.devPath < b.devPath; });

  if ((int)cams.size() > MAX_CAMERAS) cams.resize(MAX_CAMERAS);
  return cams;
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

struct CameraWindow {
  CamInfo cam;

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
      std::cerr << "SDL_CreateRenderer failed: " << SDL_GetError() << "\n";
      return false;
    }

    texture = SDL_CreateTexture(renderer,
                                SDL_PIXELFORMAT_BGR24,
                                SDL_TEXTUREACCESS_STREAMING,
                                DISP_W, DISP_H);
    if (!texture) {
      std::cerr << "SDL_CreateTexture failed: " << SDL_GetError() << "\n";
      return false;
    }

    SDL_ShowWindow(window);
    return true;
  }

  bool init_capture() {
    // Prefer CAP_V4L2 backend on Linux
    cap.open(cam.devPath, cv::CAP_V4L2);
    if (!cap.isOpened()) {
      std::cerr << "Failed to open camera: " << cam.devPath << "\n";
      return false;
    }

    // Ask for small frames to reduce bandwidth/CPU. Not guaranteed.
    cap.set(cv::CAP_PROP_FRAME_WIDTH, DISP_W);
    cap.set(cv::CAP_PROP_FRAME_HEIGHT, DISP_H);
    cap.set(cv::CAP_PROP_BUFFERSIZE, 1);

    bgr.resize(DISP_W * DISP_H * BYTES_PER_PIXEL);
    running.store(true);

    captureThread = std::thread([this]() {
      cv::Mat frame, resized;
      resized.create(DISP_H, DISP_W, CV_8UC3);

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
        if (frame.cols != DISP_W || frame.rows != DISP_H) {
          cv::resize(frame, resized, cv::Size(DISP_W, DISP_H), 0, 0, cv::INTER_AREA);
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
    // Update texture if we have a frame
    bool localHasFrame = false;
    {
      std::lock_guard<std::mutex> lk(frameMutex);
      localHasFrame = hasFrame;
      if (localHasFrame) {
        SDL_UpdateTexture(texture, nullptr, bgr.data(), DISP_PITCH);
      }
    }

    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);

    int ww=0, wh=0;
    SDL_GetWindowSize(window, &ww, &wh);

    // Preserve aspect ratio
    const float srcAspect = float(DISP_W) / float(DISP_H);
    float dstW = float(ww), dstH = float(wh);
    float dstAspect = dstW / dstH;

    SDL_Rect dst{};
    if (dstAspect > srcAspect) {
      // window wider than frame
      dst.h = wh;
      dst.w = int(float(wh) * srcAspect);
      dst.x = (ww - dst.w) / 2;
      dst.y = 0;
    } else {
      // window taller than frame
      dst.w = ww;
      dst.h = int(float(ww) / srcAspect);
      dst.x = 0;
      dst.y = (wh - dst.h) / 2;
    }

    SDL_RenderCopy(renderer, texture, nullptr, &dst);
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
  const std::string positionsFile = "camera_positions.csv";

  auto saved = load_positions_csv(positionsFile);
  auto cams = enumerate_cameras();

  if (cams.empty()) {
    std::cerr << "No capture-capable V4L2 cameras found.\n";
    return 1;
  }

  if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) != 0) {
    std::cerr << "SDL_Init failed: " << SDL_GetError() << "\n";
    return 1;
  }

  std::vector<std::unique_ptr<CameraWindow>> windows;
  windows.reserve(cams.size());

  // Create camera windows
  for (const auto& cam : cams) {
    auto cw = std::make_unique<CameraWindow>();
    cw->cam = cam;

    Rect r;
    auto it = saved.find(cam.stableId);
    if (it != saved.end()) r = it->second; // restore previous geometry

    if (!cw->init_sdl(r)) continue;
    if (!cw->init_capture()) continue;

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
        // Save all positions and exit
        for (auto& cw : windows) {
          update_and_persist_position(*cw, saved, positionsFile);
        }
        quit = true;
        break;
      }

      if (e.type == SDL_WINDOWEVENT) {
        if (e.window.event == SDL_WINDOWEVENT_CLOSE) {
          const Uint32 closingId = e.window.windowID;

          // Find the window
          for (size_t i = 0; i < windows.size(); ++i) {
            if (windows[i]->windowId == closingId) {
              // Save geometry for this camera, then destroy it
              update_and_persist_position(*windows[i], saved, positionsFile);
              windows[i]->stop();
              windows[i]->destroy_sdl();
              windows.erase(windows.begin() + i);
              break;
            }
          }

          if (windows.empty()) {
            quit = true;
            break;
          }
        }
      }
    }

    // Render all windows
    for (auto& cw : windows) {
      cw->render();
    }

    // Small sleep to avoid busy spinning when vsync is off
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }

  // Final save on normal exit (positions may have changed via move/resize)
  for (auto& cw : windows) {
    update_and_persist_position(*cw, saved, positionsFile);
  }

  // Cleanup
  windows.clear();
  SDL_Quit();
  return 0;
}
