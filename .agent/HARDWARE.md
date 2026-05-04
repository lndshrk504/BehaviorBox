# Hardware Notes

BehaviorBox hardware paths are part of the behavioral contract. Do not change pins, baud rates, serial commands, pulse polarity, or timing semantics casually.

## Active Hardware

Daily training uses Linux computers with two BehaviorBox app instances running on one computer.

The user has built Arduino hardware setups for:
- photogate input used by Nose
- rotary input used by Wheel

Both Nose and Wheel use an acrylic box with sensors read by Arduino. Arduino sends serial signals back to MATLAB.

## Arduino Sketches

All Arduino sketches are active except:

```text
Arduino/triggered-screen-blanker-NLW/triggered-screen-blanker-NLW.ino
```

Most sketches run on Arduino Uno. Screen blanking uses an Adafruit Grand Central M4 Express.

Pin map references:

```text
Arduino/Arduino-uno-pin-map.png.jpeg
Arduino/adafruit_products_Adafruit-Grand-Central-M4-Express-Pinout.png
Arduino/triggered-screen-blanker-NLW/adafruit_products_Adafruit-Grand-Central-M4-Express-Pinout.png
```

Sketch files should be treated as the source of truth for the specific pins they use.

## Arduino To MATLAB Mapping

Active sketch-to-MATLAB consumers:

| Arduino sketch | MATLAB consumers | Notes |
|---|---|---|
| `Arduino/Photogate/Photogate.ino` | `BehaviorBoxSerialInput`, `BehaviorBoxNose` | Nose photogate input path. |
| `Arduino/Rotary/Rotary.ino` | `BehaviorBoxSerialInput`, `BehaviorBoxWheel` | Wheel rotary input path. |
| `Arduino/Timekeeper/Timekeeper.ino` | `BehaviorBoxSerialTime`, `BehaviorBoxWheel` | Wheel timing and microscope timestamp path. |
| `Arduino/FakeRoscope/FakeRoscope.ino` | `Arduino/Timekeeper/Timekeeper.ino` | Used by Timekeeper when not connected to the real microscope. |

Before changing any sketch, inspect both the sketch and its MATLAB consumer. For Timekeeper changes, also inspect the real microscope path and the FakeRoscope fallback path.

## Serial Contract

The stable baud rate is:

```text
115200
```

Stable serial command contracts are the commands used by:
- `BehaviorBoxSerialInput`
- `BehaviorBoxSerialTime`

to communicate with:
- `Arduino/Photogate/Photogate.ino`
- `Arduino/Rotary/Rotary.ino`
- `Arduino/Timekeeper/Timekeeper.ino`

Before editing any sketch or serial MATLAB helper, map the exact command strings, line endings, expected responses, and downstream MATLAB consumer.

## Signal Notes

The reward valve is pulsed at a variable rate to control how much Gatorade is dispensed. No fixed reward pulse width or frequency is currently a global contract; inspect the active workflow before changing reward logic.

The EE-SPX303N photogate output is high when triggered. Datasheet:

```text
Equipment/Photogate devices/photogate-ee-spx303n_403n_ds_e_3_4_csm2162.pdf
```

No connected devices are currently known to require level shifting, relays, transistors, or optoisolation. No unsafe boot/reset states are currently known. Still flag voltage, current, grounding, and startup assumptions when changing hardware-facing code.

## Microscope Boundary

Only Wheel should handle microscope signaling, microscope acquisition start/end behavior, and frame timestamp recording.

`BehaviorBoxNose.m` must remain free of microscope-specific code.

## Camera Utility

`usbcamv4l/` is actively used on Linux only.

Known machines/GPU paths:
- Intel N100 with integrated GPU only
- AMD Ryzen AI Max 395+
- Intel 13th gen with NVIDIA 4060

The user's Mac does not use this utility.

Production command:

```bash
cam -f -w
```

When camera behavior breaks, inspect terminal text output first.
