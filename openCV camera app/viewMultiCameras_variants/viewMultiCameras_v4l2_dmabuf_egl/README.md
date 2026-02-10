# viewMultiCameras_v4l2_dmabuf_egl

Option 3: **Max performance / zero-copy if possible** (V4L2 + DMABUF + EGL/GLES).

## Dependencies (Debian/Ubuntu)
```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config   libx11-dev libegl1-mesa-dev libgles2-mesa-dev libdrm-dev
```

## Build & run
```bash
mkdir -p build
cd build
cmake ..
cmake --build . -j
./viewMultiCameras_v4l2_dmabuf_egl
```

## Notes / caveats
- **X11-only** reference implementation (Xlib windows + EGLWindowSurface).
- Zero-copy path is implemented for **NV12** cameras. If your cameras only support YUYV/MJPEG,
  you'll need to add a packed-format path or use a decode/convert pipeline.
- Uses `glFinish()` before re-queueing a buffer for correctness. For maximum throughput replace with explicit fencing.
