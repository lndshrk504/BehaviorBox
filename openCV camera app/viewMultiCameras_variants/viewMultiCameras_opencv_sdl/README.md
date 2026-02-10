# viewMultiCameras_opencv_sdl

Option 1: **Simple / portable** (OpenCV capture + SDL2 display).

## Dependencies (Debian/Ubuntu)
```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config libsdl2-dev libopencv-dev
```

## Build & run
```bash
mkdir -p build
cd build
cmake ..
cmake --build . -j
./viewMultiCameras_opencv_sdl
```
