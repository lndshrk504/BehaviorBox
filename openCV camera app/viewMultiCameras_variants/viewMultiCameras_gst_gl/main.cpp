#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>

#include <gst/gst.h>
#include <gst/video/videooverlay.h>

#include <linux/videodev2.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>

#include <chrono>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace fs = std::filesystem;

static constexpr int MAX_CAMERAS = 4;

// Try a few common capture sizes (even dimensions help with YUV).
struct Size { int w; int h; };
static constexpr Size kPreferredSizes[] = {
  {320, 240},
  {640, 480},
  {1280, 720},
};

struct Rect {
  int x{SDL_WINDOWPOS_CENTERED};
  int y{SDL_WINDOWPOS_CENTERED};
  int w{320};
  int h{240};
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

static std::string positions_file() {
  const char* xdg = std::getenv("XDG_CONFIG_HOME");
  const char* home = std::getenv("HOME");
  std::string baseDir;
  if (xdg && std::strlen(xdg) > 0) baseDir = xdg;
  else if (home && std::strlen(home) > 0) baseDir = std::string(home) + "/.config";
  else baseDir = ".";

  std::string dir = baseDir + "/viewMultiCameras";
  std::error_code ec;
  fs::create_directories(dir, ec);
  return dir + "/camera_positions.csv";
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

  const bool hasCapture =
      (cap.capabilities & V4L2_CAP_VIDEO_CAPTURE) ||
      (cap.capabilities & V4L2_CAP_VIDEO_CAPTURE_MPLANE);

  if (!hasCapture) return std::nullopt;

  CamInfo info;
  info.devPath = devPath;
  info.card = reinterpret_cast<const char*>(cap.card);
  info.busInfo = reinterpret_cast<const char*>(cap.bus_info);

  if (!trim(info.busInfo).empty()) info.stableId = info.busInfo;
  else info.stableId = info.card + "|" + info.devPath;

  return info;
}

static std::vector<CamInfo> enumerate_cameras() {
  std::vector<CamInfo> cams;
  std::unordered_set<std::string> seenStableIds;

  for (const auto& ent : fs::directory_iterator("/dev")) {
    const auto name = ent.path().filename().string();
    if (name.rfind("video", 0) != 0) continue;

    const std::string devPath = ent.path().string();
    auto qi = query_v4l2(devPath);
    if (!qi) continue;

    if (seenStableIds.insert(qi->stableId).second) cams.push_back(*qi);
  }

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
      first = false;
      if (line.find("camera_id") != std::string::npos) continue;
    }

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

static std::optional<uintptr_t> sdl_x11_window_id(SDL_Window* win) {
  SDL_SysWMinfo info;
  SDL_VERSION(&info.version);
  if (SDL_GetWindowWMInfo(win, &info) != SDL_TRUE) return std::nullopt;
  if (info.subsystem != SDL_SYSWM_X11) return std::nullopt;
  return (uintptr_t)info.info.x11.window;
}

struct GstCamWindow {
  CamInfo cam;

  SDL_Window* window{nullptr};
  Uint32 windowId{0};

  GstElement* pipeline{nullptr};
  GstElement* sink{nullptr};
  GstBus* bus{nullptr};

  bool isPlaying{false};

  ~GstCamWindow() { stop(); destroy_window(); }

  void destroy_window() {
    if (window) {
      SDL_DestroyWindow(window);
      window = nullptr;
    }
  }

  void stop() {
    if (pipeline) {
      gst_element_set_state(pipeline, GST_STATE_NULL);
      if (bus) { gst_object_unref(bus); bus = nullptr; }
      if (sink) { gst_object_unref(sink); sink = nullptr; }
      gst_object_unref(pipeline);
      pipeline = nullptr;
    }
    isPlaying = false;
  }

  bool init_window(const Rect& r) {
    std::string title = cam.card + " [" + cam.devPath + "]";
    window = SDL_CreateWindow(title.c_str(), r.x, r.y, r.w, r.h,
                              SDL_WINDOW_RESIZABLE | SDL_WINDOW_SHOWN);
    if (!window) {
      std::cerr << "SDL_CreateWindow failed: " << SDL_GetError() << "\n";
      return false;
    }
    windowId = SDL_GetWindowID(window);
    return true;
  }

  GstElement* try_build_pipeline(int w, int h, bool useDmabuf, bool useCaps) {
    std::ostringstream oss;
    oss << "v4l2src device=" << cam.devPath << " ";
    if (useDmabuf) oss << "io-mode=dmabuf ";
    oss << "! queue max-size-buffers=1 leaky=downstream ";
    if (useCaps) {
      oss << "! video/x-raw,width=" << w << ",height=" << h << ",framerate=30/1 ";
    }
    oss << "! glupload ! glcolorconvert ! glimagesink name=sink sync=false qos=true";

    GError* err = nullptr;
    GstElement* pipe = gst_parse_launch(oss.str().c_str(), &err);
    if (!pipe) {
      if (err) {
        std::cerr << "gst_parse_launch error: " << err->message << "\n";
        g_error_free(err);
      }
      return nullptr;
    }
    return pipe;
  }

  bool start_pipeline() {
    auto xidOpt = sdl_x11_window_id(window);
    if (!xidOpt) {
      std::cerr << "Requires SDL on X11 (needed for GstVideoOverlay).\n";
      return false;
    }
    const uintptr_t xid = *xidOpt;

    const bool dmabufModes[] = {true, false};
    const bool capsModes[] = {true, false};

    for (auto sz : kPreferredSizes) {
      for (bool dmabuf : dmabufModes) {
        for (bool caps : capsModes) {
          GstElement* pipe = try_build_pipeline(sz.w, sz.h, dmabuf, caps);
          if (!pipe) continue;

          GstElement* s = gst_bin_get_by_name(GST_BIN(pipe), "sink");
          if (!s) { gst_object_unref(pipe); continue; }

          gst_video_overlay_set_window_handle(GST_VIDEO_OVERLAY(s), (guintptr)xid);

          int ww=0, wh=0;
          SDL_GetWindowSize(window, &ww, &wh);
          gst_video_overlay_set_render_rectangle(GST_VIDEO_OVERLAY(s), 0, 0, ww, wh);

          auto ret = gst_element_set_state(pipe, GST_STATE_PLAYING);
          if (ret == GST_STATE_CHANGE_FAILURE) {
            gst_element_set_state(pipe, GST_STATE_NULL);
            gst_object_unref(s);
            gst_object_unref(pipe);
            continue;
          }

          GstState st = GST_STATE_NULL, pending = GST_STATE_NULL;
          ret = gst_element_get_state(pipe, &st, &pending, 2 * GST_SECOND);
          if (ret == GST_STATE_CHANGE_FAILURE || st != GST_STATE_PLAYING) {
            gst_element_set_state(pipe, GST_STATE_NULL);
            gst_object_unref(s);
            gst_object_unref(pipe);
            continue;
          }

          pipeline = pipe;
          sink = s; // keep ref
          bus = gst_element_get_bus(pipeline);
          isPlaying = true;

          std::cerr << "Started " << cam.devPath << " @ "
                    << (caps ? std::to_string(sz.w) + "x" + std::to_string(sz.h) : std::string("default"))
                    << " dmabuf=" << (dmabuf ? "yes" : "no") << "\n";
          return true;
        }
      }
    }
    return false;
  }

  void on_resize() {
    if (!sink) return;
    int ww=0, wh=0;
    SDL_GetWindowSize(window, &ww, &wh);
    gst_video_overlay_set_render_rectangle(GST_VIDEO_OVERLAY(sink), 0, 0, ww, wh);
    gst_video_overlay_expose(GST_VIDEO_OVERLAY(sink));
  }

  void pump_bus() {
    if (!bus) return;
    while (true) {
      GstMessage* msg = gst_bus_pop(bus);
      if (!msg) break;

      switch (GST_MESSAGE_TYPE(msg)) {
        case GST_MESSAGE_ERROR: {
          GError* err = nullptr;
          gchar* dbg = nullptr;
          gst_message_parse_error(msg, &err, &dbg);
          std::cerr << "GStreamer ERROR (" << cam.devPath << "): "
                    << (err ? err->message : "unknown") << "\n";
          if (dbg) std::cerr << "  debug: " << dbg << "\n";
          if (err) g_error_free(err);
          if (dbg) g_free(dbg);
          stop();
          break;
        }
        case GST_MESSAGE_EOS:
          std::cerr << "GStreamer EOS (" << cam.devPath << ")\n";
          stop();
          break;
        default:
          break;
      }
      gst_message_unref(msg);
      if (!isPlaying) break;
    }
  }
};

static void persist_window_geom(SDL_Window* w, const std::string& key,
                                std::unordered_map<std::string, Rect>& saved,
                                const std::string& csv) {
  Rect r;
  SDL_GetWindowPosition(w, &r.x, &r.y);
  SDL_GetWindowSize(w, &r.w, &r.h);
  saved[key] = r;
  (void)save_positions_csv(csv, saved);
}

int main(int argc, char** argv) {
  const std::string csv = positions_file();

  gst_init(&argc, &argv);
  if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) != 0) {
    std::cerr << "SDL_Init failed: " << SDL_GetError() << "\n";
    return 1;
  }

  auto saved = load_positions_csv(csv);
  auto cams = enumerate_cameras();
  if (cams.empty()) {
    std::cerr << "No capture-capable V4L2 cameras found.\n";
    SDL_Quit();
    return 1;
  }

  std::vector<std::unique_ptr<GstCamWindow>> wins;
  wins.reserve(cams.size());

  for (const auto& cam : cams) {
    auto cw = std::make_unique<GstCamWindow>();
    cw->cam = cam;

    Rect r;
    auto it = saved.find(cam.stableId);
    if (it != saved.end()) r = it->second;

    if (!cw->init_window(r)) continue;
    if (!cw->start_pipeline()) { cw->destroy_window(); continue; }

    wins.emplace_back(std::move(cw));
  }

  if (wins.empty()) {
    std::cerr << "No camera windows could be created.\n";
    SDL_Quit();
    return 1;
  }

  bool quit = false;
  while (!quit && !wins.empty()) {
    for (auto& w : wins) w->pump_bus();

    SDL_Event e;
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT) {
        for (auto& w : wins) persist_window_geom(w->window, w->cam.stableId, saved, csv);
        quit = true;
        break;
      }

      if (e.type == SDL_WINDOWEVENT) {
        if (e.window.event == SDL_WINDOWEVENT_CLOSE) {
          const Uint32 closingId = e.window.windowID;
          for (size_t i = 0; i < wins.size(); ++i) {
            if (wins[i]->windowId == closingId) {
              persist_window_geom(wins[i]->window, wins[i]->cam.stableId, saved, csv);
              wins[i]->stop();
              wins[i]->destroy_window();
              wins.erase(wins.begin() + i);
              break;
            }
          }
          if (wins.empty()) { quit = true; break; }
        } else if (e.window.event == SDL_WINDOWEVENT_RESIZED ||
                   e.window.event == SDL_WINDOWEVENT_SIZE_CHANGED) {
          const Uint32 id = e.window.windowID;
          for (auto& w : wins) if (w->windowId == id) { w->on_resize(); break; }
        }
      }
    }

    SDL_Delay(5);
  }

  for (auto& w : wins) persist_window_geom(w->window, w->cam.stableId, saved, csv);

  wins.clear();
  SDL_Quit();
  return 0;
}
