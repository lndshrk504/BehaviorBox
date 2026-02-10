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
static constexpr int REQ_W = 640;
static constexpr int REQ_H = 480;

struct Rect { int x{0}; int y{0}; int w{320}; int h{240}; };

struct CamInfo {
  std::string devPath;
  std::string card;
  std::string busInfo;
  std::string stableId;
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
  if (ioctl(fd, VIDIOC_QUERYCAP, &cap) != 0) { ::close(fd); return std::nullopt; }
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
  std::unordered_set<std::string> seen;
  for (const auto& ent : fs::directory_iterator("/dev")) {
    const auto name = ent.path().filename().string();
    if (name.rfind("video", 0) != 0) continue;
    auto qi = query_v4l2(ent.path().string());
    if (!qi) continue;
    if (seen.insert(qi->stableId).second) cams.push_back(*qi);
  }
  std::sort(cams.begin(), cams.end(),
            [](const CamInfo& a, const CamInfo& b){ return a.devPath < b.devPath; });
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

static GLuint make_program() {
  GLuint vs = compile_shader(GL_VERTEX_SHADER, kVS);
  GLuint fs = compile_shader(GL_FRAGMENT_SHADER, kFS_NV12);
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

// ---- V4L2 + DMABUF ----
struct V4L2DmabufCam {
  CamInfo cam;
  int fd{-1};
  int width{0}, height{0};
  int strideY{0}, strideUV{0};
  bool nv12{false};

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

    v4l2_format fmt{};
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    fmt.fmt.pix.width = REQ_W;
    fmt.fmt.pix.height = REQ_H;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_NV12;
    fmt.fmt.pix.field = V4L2_FIELD_NONE;

    if (ioctl(fd, VIDIOC_S_FMT, &fmt) == 0 && fmt.fmt.pix.pixelformat == V4L2_PIX_FMT_NV12) {
      nv12 = true;
    } else {
      // packed fallback
      std::memset(&fmt, 0, sizeof(fmt));
      fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
      fmt.fmt.pix.width = REQ_W;
      fmt.fmt.pix.height = REQ_H;
      fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
      fmt.fmt.pix.field = V4L2_FIELD_NONE;
      if (ioctl(fd, VIDIOC_S_FMT, &fmt) != 0) {
        std::cerr << "VIDIOC_S_FMT failed for NV12 and YUYV: " << cam.devPath << "\n";
        return false;
      }
      nv12 = false;
      std::cerr << "Warning: " << cam.devPath << " not NV12; packed-format zero-copy not implemented here.\n";
    }

    width = (int)fmt.fmt.pix.width;
    height = (int)fmt.fmt.pix.height;
    strideY = (int)fmt.fmt.pix.bytesperline;
    strideUV = strideY;

    v4l2_requestbuffers req{};
    req.count = 4;
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;
    if (ioctl(fd, VIDIOC_REQBUFS, &req) != 0 || req.count < 2) {
      std::cerr << "VIDIOC_REQBUFS failed: " << cam.devPath << "\n";
      return false;
    }

    bufs.resize(req.count);

    for (unsigned i = 0; i < req.count; ++i) {
      v4l2_buffer b{};
      b.type = req.type;
      b.memory = req.memory;
      b.index = i;
      if (ioctl(fd, VIDIOC_QUERYBUF, &b) != 0) {
        std::cerr << "VIDIOC_QUERYBUF failed\n";
        return false;
      }

      bufs[i].len = b.length;
      bufs[i].ptr = mmap(nullptr, b.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, b.m.offset);
      if (bufs[i].ptr == MAP_FAILED) {
        std::cerr << "mmap failed\n";
        return false;
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
        return false;
      }
    }

    v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    if (ioctl(fd, VIDIOC_STREAMON, &type) != 0) {
      std::cerr << "VIDIOC_STREAMON failed\n";
      return false;
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
    if (fd >= 0) { close(fd); fd = -1; }
  }
};

struct XWin {
  Window win{0};
  EGLSurface surf{EGL_NO_SURFACE};
  Rect geom{};
  bool alive{true};
};

int main(int argc, char** argv) {
  const std::string csv = positions_file();
  auto saved = load_positions_csv(csv);

  Display* dpy = XOpenDisplay(nullptr);
  if (!dpy) {
    std::cerr << "XOpenDisplay failed. This implementation requires X11.\n";
    return 1;
  }
  Atom WM_DELETE_WINDOW = XInternAtom(dpy, "WM_DELETE_WINDOW", False);

  EGLDisplay edpy = eglGetDisplay((EGLNativeDisplayType)dpy);
  if (edpy == EGL_NO_DISPLAY) { std::cerr << "eglGetDisplay failed\n"; return 1; }
  if (!eglInitialize(edpy, nullptr, nullptr)) { std::cerr << "eglInitialize failed\n"; return 1; }
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
    std::cerr << "eglChooseConfig failed\n"; return 1;
  }
  EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
  EGLContext ctx = eglCreateContext(edpy, cfg, EGL_NO_CONTEXT, ctxAttrs);
  if (ctx == EGL_NO_CONTEXT) { std::cerr << "eglCreateContext failed\n"; return 1; }

  auto eglCreateImageKHR =
      (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
  auto eglDestroyImageKHR =
      (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
  auto glEGLImageTargetTexture2DOES =
      (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");
  if (!eglCreateImageKHR || !eglDestroyImageKHR || !glEGLImageTargetTexture2DOES) {
    std::cerr << "Missing EGLImage extension functions.\n";
    return 1;
  }

  auto cams = enumerate_cameras();
  if (cams.empty()) { std::cerr << "No capture-capable V4L2 cameras found.\n"; return 1; }

  std::vector<XWin> wins;
  std::vector<V4L2DmabufCam> vcams;
  wins.reserve(cams.size());
  vcams.reserve(cams.size());

  int screen = DefaultScreen(dpy);
  Window root = RootWindow(dpy, screen);

  for (const auto& c : cams) {
    Rect r{0, 0, 320, 240};
    auto it = saved.find(c.stableId);
    if (it != saved.end()) r = it->second;

    Window w = XCreateSimpleWindow(dpy, root, r.x, r.y, (unsigned)r.w, (unsigned)r.h,
                                   0, BlackPixel(dpy, screen), BlackPixel(dpy, screen));
    XStoreName(dpy, w, (c.card + " [" + c.devPath + "]").c_str());
    XSelectInput(dpy, w, StructureNotifyMask | ExposureMask);
    XSetWMProtocols(dpy, w, &WM_DELETE_WINDOW, 1);
    XMapWindow(dpy, w);

    EGLSurface surf = eglCreateWindowSurface(edpy, cfg, (EGLNativeWindowType)w, nullptr);
    if (surf == EGL_NO_SURFACE) { std::cerr << "eglCreateWindowSurface failed\n"; continue; }

    if (!eglMakeCurrent(edpy, surf, surf, ctx)) { std::cerr << "eglMakeCurrent failed\n"; eglDestroySurface(edpy, surf); continue; }

    V4L2DmabufCam cam;
    cam.cam = c;
    if (!cam.open_and_configure()) { eglDestroySurface(edpy, surf); continue; }

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
          std::cerr << "EGLImage creation failed; NV12 zero-copy path may not work on this stack.\n";
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

    wins.push_back({w, surf, r, true});
    vcams.push_back(std::move(cam));
  }

  if (wins.empty()) { std::cerr << "No camera windows could be created.\n"; return 1; }

  if (!eglMakeCurrent(edpy, wins[0].surf, wins[0].surf, ctx)) { std::cerr << "eglMakeCurrent failed\n"; return 1; }
  GLuint prog = make_program();
  glUseProgram(prog);
  GLint locY = glGetUniformLocation(prog, "texY");
  GLint locUV = glGetUniformLocation(prog, "texUV");
  glUniform1i(locY, 0);
  glUniform1i(locUV, 1);

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
            int rx=0, ry=0;
            x11_get_window_root_xy(dpy, wins[i].win, rx, ry);
            XWindowAttributes wa{};
            XGetWindowAttributes(dpy, wins[i].win, &wa);
            wins[i].geom = {rx, ry, wa.width, wa.height};
            saved[vcams[i].cam.stableId] = wins[i].geom;
            save_positions_csv(csv, saved);

            wins[i].alive = false;
            XUnmapWindow(dpy, wins[i].win);
            break;
          }
        }
        bool anyAlive = false;
        for (auto& w : wins) anyAlive |= w.alive;
        if (!anyAlive) { quit = true; break; }
      } else if (ev.type == ConfigureNotify) {
        for (auto& w : wins) {
          if (w.win == ev.xconfigure.window) {
            int rx=0, ry=0;
            x11_get_window_root_xy(dpy, w.win, rx, ry);
            w.geom = {rx, ry, ev.xconfigure.width, ev.xconfigure.height};
            break;
          }
        }
      }
    }

    for (size_t i = 0; i < vcams.size(); ++i) {
      if (!wins[i].alive) continue;
      auto& cam = vcams[i];

      v4l2_buffer b{};
      b.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
      b.memory = V4L2_MEMORY_MMAP;

      if (ioctl(cam.fd, VIDIOC_DQBUF, &b) != 0) {
        if (errno == EAGAIN) continue;
        continue;
      }

      if (!eglMakeCurrent(edpy, wins[i].surf, wins[i].surf, ctx)) {
        // best effort
      } else {
        glViewport(0, 0, wins[i].geom.w, wins[i].geom.h);
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        if (cam.nv12 && b.index < cam.bufs.size() && cam.bufs[b.index].yTex && cam.bufs[b.index].uvTex) {
          glActiveTexture(GL_TEXTURE0);
          glBindTexture(GL_TEXTURE_2D, cam.bufs[b.index].yTex);
          glActiveTexture(GL_TEXTURE1);
          glBindTexture(GL_TEXTURE_2D, cam.bufs[b.index].uvTex);

          glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), quad + 0);
          glEnableVertexAttribArray(0);
          glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), quad + 2);
          glEnableVertexAttribArray(1);
          glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        } else {
          // Packed formats not handled in this reference. Extend here if needed.
        }

        // Conservative sync before re-queue for correctness
        glFinish();
        eglSwapBuffers(edpy, wins[i].surf);
      }

      ioctl(cam.fd, VIDIOC_QBUF, &b);
    }
  }

  // Final save
  for (size_t i = 0; i < wins.size(); ++i) {
    if (!wins[i].win) continue;
    int rx=0, ry=0;
    x11_get_window_root_xy(dpy, wins[i].win, rx, ry);
    XWindowAttributes wa{};
    XGetWindowAttributes(dpy, wins[i].win, &wa);
    saved[vcams[i].cam.stableId] = {rx, ry, wa.width, wa.height};
  }
  save_positions_csv(csv, saved);

  // Cleanup
  if (eglMakeCurrent(edpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT)) {}
  for (auto& cam : vcams) cam.shutdown(eglDestroyImageKHR, edpy);

  for (auto& w : wins) {
    if (w.surf != EGL_NO_SURFACE) eglDestroySurface(edpy, w.surf);
    if (w.win) XDestroyWindow(dpy, w.win);
  }

  glDeleteProgram(prog);
  eglDestroyContext(edpy, ctx);
  eglTerminate(edpy);
  XCloseDisplay(dpy);
  return 0;
}
