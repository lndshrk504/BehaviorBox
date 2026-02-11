# viewMultiCameras variants (Linux)

This archive contains **three C++ implementations** of the same behavior:

- Up to **4** USB (V4L2) cameras
- **One window per camera**
- Small preview window size
- Window position/size saved to a readable CSV and restored on next run

Window geometry CSV is stored at:
- `$XDG_CONFIG_HOME/viewMultiCameras/camera_positions.csv` (preferred)
- or `~/.config/viewMultiCameras/camera_positions.csv`

## Variants

### Option 1: OpenCV + SDL2 (simple / portable)
Folder: `viewMultiCameras_opencv_sdl/`

- OpenCV `VideoCapture` per camera (V4L2 backend)
- SDL2 streaming texture per window

### Option 2: GStreamer + GL sink (lower CPU, manageable complexity)
Folder: `viewMultiCameras_gst_gl/`

- Disabled in this repo on this machine due session-reset instability.
- Kept only as a stub that exits with a message.

### Option 3: V4L2 + DMABUF export + EGL/OpenGL ES (max performance, zero-copy *if possible*)
Folder: `viewMultiCameras_v4l2_dmabuf_egl/`

- Uses raw V4L2 streaming buffers, exports them as DMABUF fds
- Imports DMABUF into EGLImages and samples in OpenGL ES
- **X11 + EGL only** in this reference implementation
- Zero-copy depends on your camera pixel format + GPU driver support

> Note: For truly maximum throughput you should use explicit GPU fencing before re-queuing buffers. The provided implementation uses conservative synchronization for correctness.
