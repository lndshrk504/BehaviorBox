# usbcams

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
./usbcams
```

## Reset window layout
Launch with `-reset` (or `--reset`) to ignore saved window positions and start each camera window at the default size/placement:

```bash
./usbcams -reset
```

## Choose each camera resolution interactively
Launch with `-choose-each-res` (or `--choose-each-resolution`) to list supported resolutions for each detected camera and choose one per camera:

```bash
./usbcams -choose-each-res
```

## Choose one common height for all cameras
Launch with `-choose-all-res` (or `--choose-all-resolution`) to probe all cameras, then choose from heights common to every camera. Each camera will use its best width at the selected height:

```bash
./usbcams -choose-all-res
```

Selections are persisted per camera. After using `-choose-all-res` (or `-choose-each-res`), the next normal run (`./usbcams`) reuses those capture resolutions and the saved window positions.
