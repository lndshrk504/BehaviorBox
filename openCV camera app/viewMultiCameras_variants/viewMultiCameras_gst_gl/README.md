# viewMultiCameras_gst_gl

Option 2: **Lower CPU, manageable complexity** using **GStreamer + GL sink**.

## Dependencies (Debian/Ubuntu)
```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config libsdl2-dev   libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev   gstreamer1.0-gl gstreamer1.0-plugins-base gstreamer1.0-plugins-good
```

## Build
```bash
mkdir -p build
cd build
cmake ..
cmake --build . -j
```

Run:
```bash
./viewMultiCameras_gst_gl
```

## Notes
- This implementation embeds `glimagesink` into **SDL2 X11 windows** using `GstVideoOverlay`.
- If your session is Wayland-only, you may need an X11 session or adapt the window-handle code.
