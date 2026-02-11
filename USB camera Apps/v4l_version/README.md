# viewMultiCameras_v4l2_dmabuf_egl

Option 3: **GPU-first processing with EGL/GLES** (V4L2 + DMABUF + EGL/GLES).

Executable name: `usbcamv4l`

## Dependencies (Debian/Ubuntu)
```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config libx11-dev libegl1-mesa-dev libgles2-mesa-dev libdrm-dev libturbojpeg0-dev libavcodec-dev libavutil-dev
```

Or use the helper script:
```bash
./install_deps.sh
```

Requires a working EGL/GLES stack (Intel, NVIDIA, etc.).

## Build & run
```bash
mkdir -p build
cd build
cmake ..
cmake --build . -j
./usbcamv4l
```

To prefer MJPEG capture (useful to reduce USB bandwidth):
```bash
./usbcamv4l -mjpeg
```

To allow full hardware MJPEG decode backends (including CUDA/CUVID):
```bash
./usbcamv4l -mjpeg -mjpeg-hw
```

If this is a hybrid graphics system and you specifically want NVIDIA offload, run with PRIME:
```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia ./usbcamv4l
```

## Notes / caveats
- **X11-only** reference implementation (Xlib windows + EGLWindowSurface).
- The app logs active EGL/GL vendor+renderer at startup.
- Zero-copy path is implemented for **NV12** cameras via DMABUF import.
- If NV12 import fails, it falls back to **GPU texture upload + GPU shader conversion**.
- **YUYV** cameras use **GPU texture upload + GPU shader conversion**.
- `-mjpeg` mode prefers **MJPEG** capture, with fallback to NV12/YUYV.
- `-mjpeg` defaults to low-latency decode policy (skip CUDA/CUVID, prefer **Intel QSV**, use **VAAPI** fallback on Intel renderers, then **libturbojpeg** fallback).
- `-mjpeg-hw` enables full hardware backend list including **CUDA/CUVID**.
- YUV->RGB conversion/scaling remains on the GPU.
- Low-latency path drops stale queued frames and uses `glFlush()` by default. Use `-strict-sync` to force conservative `glFinish()`.
