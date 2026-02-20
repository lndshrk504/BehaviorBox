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

Requires a working EGL/GLES stack (Intel, NVIDIA, AMD, etc.).

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

To show a live resolution + FPS overlay (off by default):
```bash
./usbcamv4l -fps
```

To list camera formats/resolutions/FPS capabilities and exit:
```bash
./usbcamv4l -list-cameras
```

To disable startup format benchmarking (enabled by default):
```bash
./usbcamv4l -no-bench
```

To set startup benchmark budget (per camera):
```bash
./usbcamv4l -bench-ms 1500
```

To disable runtime control socket:
```bash
./usbcamv4l -no-control
```

To create a global symlink at `/usr/local/cam`:
```bash
sudo ./install_cam_link.sh
```

To record each camera window to MP4 files:
```bash
./usbcamv4l -rec
```

To prioritize recording FPS (default recording profile):
```bash
./usbcamv4l -rec-fast
```

To prioritize recording quality:
```bash
./usbcamv4l -rec-quality
```

If this is a hybrid graphics system and you specifically want NVIDIA offload, run with PRIME:
```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia ./usbcamv4l
```

Runtime control examples (in another terminal while app is running):
```bash
./usbcamctl status
./usbcamctl fps on
./usbcamctl rec toggle
./usbcamctl sync auto
./usbcamctl queue 4
./usbcamctl cam 0 reconnect
```

## Notes / caveats
- **X11-only** reference implementation (Xlib windows + EGLWindowSurface).
- The app logs active EGL/GL vendor+renderer at startup.
- Zero-copy path is implemented for **NV12** cameras via DMABUF import.
- If NV12 import fails, it falls back to **GPU texture upload + GPU shader conversion**.
- **YUYV** cameras use **GPU texture upload + GPU shader conversion**.
- `-mjpeg` mode prefers **MJPEG** capture, with fallback to NV12/YUYV.
- `-mjpeg` defaults to low-latency decode policy (skip CUDA/CUVID, prefer **Intel QSV** on Intel renderers and **VAAPI** on AMD renderers, then **libturbojpeg** fallback).
- `-mjpeg-hw` enables full hardware backend list; on AMD systems it prioritizes **VAAPI** (and skips CUDA/QSV probes when those devices are not active).
- Overlay text is disabled by default for maximum throughput. Use `-fps` to enable the live resolution/FPS overlay.
- Startup capture-path benchmark is enabled by default (`-bench-ms` controls the time budget, `-no-bench` disables it).
- Runtime control socket defaults to `/tmp/usbcamv4l-control.sock` (override with `USBCAMV4L_CONTROL_SOCKET`).
- Watchdog reconnect attempts to recover disconnected cameras without restarting the app.
- Queue depth now auto-tunes from 2 to 4 buffers when stutter/dequeue errors are detected.
- GPU sync now defaults to adaptive mode (`glFlush` baseline with automatic temporary `glFinish` during stutter spikes).
- Camera window resize snaps to the active feed aspect ratio shortly after resize drag stops (for example, 640x480 stays 4:3).
- If EGLImage/DMABUF import extensions are unavailable, the app falls back to GPU texture upload paths instead of exiting.
- On AMD renderers, YUYV capture uses a stable fallback path (**CPU YUYV unpack + GPU RGBA render**) to avoid known `gfx11xx` LLVM shader backend issues.
- On AMD systems, the app requests Mesa **Zink** automatically (`MESA_LOADER_DRIVER_OVERRIDE=zink`) unless you set `USBCAMV4L_DISABLE_ZINK_WORKAROUND=1`.
- For VAAPI debugging/selection, set `USBCAMV4L_VAAPI_DEVICE=/dev/dri/renderD128` (or your desired render node).
- `-rec` writes per-camera MP4 files under `~/Desktop/USB-Recordings/`.
- `-rec-fast` (or `-rec`) prioritizes throughput and may use `h264_vaapi` (with software fallback) when available.
- `-rec-quality` uses slower `libx264` settings for better visual quality at lower throughput.
- When possible, frames are recorded from CPU-side RGBA buffers to avoid `glReadPixels`.
- YUV->RGB conversion/scaling remains on the GPU.
- Low-latency path drops stale queued frames and uses `glFlush()` by default. Use `-strict-sync` to force conservative `glFinish()`.
