# viewMultiCameras_v4l2_dmabuf_egl

Option 3: **GPU-first processing with EGL/GLES** (V4L2 + DMABUF + EGL/GLES).

Executable name: `usbcamv4l`

## Dependencies (Debian/Ubuntu)
```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config libx11-dev libegl1-mesa-dev libgles2-mesa-dev libdrm-dev
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
- Supported capture formats are currently **NV12** and **YUYV**.
- **MJPEG** cameras are not supported yet (need a decode path).
- Uses `glFinish()` before re-queueing a buffer for correctness. For maximum throughput replace with explicit fencing.
