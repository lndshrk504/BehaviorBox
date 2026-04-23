# BehaviorBox

BehaviorBox is a MATLAB-first behavioral training and analysis repository for the lab's nose-poke and wheel workflows. The main GUI lives in `BehaviorBox_App.mlapp` / `BB_App.m`, the runtime task logic lives in `BehaviorBoxNose.m` and `BehaviorBoxWheel.m`, and session loading, saving, and analysis live in `BehaviorBoxData.m`.

The repo also includes:

- visual stimulus generation for task presentation
- Arduino firmware and wiring references for connected hardware
- eye-tracking streamer, receiver, import, and alignment code
- headless MATLAB smoke tests for save/load paths
- a separate Linux-only multi-camera utility in `usbcamv4l/`

## Main entry points

- `BehaviorBox_App.mlapp`: App Designer source for the main GUI
- `BB_App.m`: exported/generated MATLAB class for the app (`BehaviorBox_App`)
- `BehaviorBoxNose.m`: nose-poke task runtime
- `BehaviorBoxWheel.m`: wheel task runtime, including wheel-specific imaging and timestamp logic
- `BehaviorBoxData.m`: data loading, saving, plotting, and aggregate analysis
- `BehaviorBoxVisualStimulus.m`: visual stimulus rendering
- `BehaviorBoxEyeTrack.m`: receiver-backed eye-tracking client, importer, and alignment helper

## Repository layout

| Path | Purpose |
| --- | --- |
| `fcns/` | MATLAB helpers, analysis utilities, and focused smoke tests |
| `MockApp/` | Headless MATLAB harness for debugging `BehaviorBoxWheel` logic without the full GUI or hardware |
| `EyeTrack/` | Active eye-tracking streamer/receiver boundary, MATLAB importer code, and legacy references |
| `Arduino/` | Sketches and wiring references for behavior and timing hardware |
| `Equipment/` | CAD files, board references, and hardware assets |
| `Linux-Scripts/` | Linux setup and automation scripts |
| `Imaging Analysis scripts/` | Analysis scripts for frame/timestamp alignment and downstream imaging work |
| `usbcamv4l/` | Separate Linux-only C++ camera viewer/recorder |
| `Next Steps/` | Design notes, handoff material, and planning docs |

## Platform notes

- Linux is the default runtime and validation environment for this repo.
- Development also happens on macOS, and occasionally on Windows.
- `usbcamv4l/` is Linux-only.
- The active eye-tracking path is the `EyeTrack/DeepLabCut/` tree. `EyeTrack/legacy/iRecHS2/` remains in the repo as legacy reference material.

## Quick start

From MATLAB, start in the repo root:

```matlab
cd('/path/to/BehaviorBox');
run('startup.m');
app = BehaviorBox_App;
```

Notes:

- `startup.m` is intentionally minimal and does not recursively add the repo to the MATLAB path.
- Keep path additions explicit when running isolated scripts or harnesses.
- For wheel-only save/cleanup debugging, prefer the headless harness in `MockApp/` before reconstructing a full GUI session.

## Data layout

BehaviorBox data roots are resolved through `GetFilePath("Data")`, then organized under:

```text
Inv/Inp/Str/Sub
```

where:

- `Inv` is the investigator branch
- `Inp` is the workflow branch such as `NosePoke` or `Wheel`
- `Str` is the strain/group folder
- `Sub` is the subject folder

`BehaviorBoxData.GetFiles()` first checks an explicit `Str/Sub` path when available, then falls back to a recursive search under the workflow root. Missing subject folders are not created during lookup; they are created later by save-time code such as `BehaviorBoxData.SaveAllData`, `BehaviorBoxNose.SaveAllData`, or `BehaviorBoxWheel.SaveAllData`.

## Focused validation commands

These are the narrow, repeatable checks that match common development paths:

Initialize MATLAB formatting/session state:

```bash
matlab -batch "run('startup.m')"
```

Wheel save/cleanup smoke test without the real GUI or Arduinos:

```bash
matlab -batch "cd('/path/to/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"
```

Load one real BehaviorBox data path and validate saved-file structure:

```bash
matlab -batch "cd('/path/to/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
```

Validate missing-subject lookup without touching the real data tree:

```bash
matlab -batch "cd('/path/to/BehaviorBox'); run('fcns/testBehaviorBoxDataNoEagerMkdir.m');"
```

Validate deferred folder creation at save time:

```bash
matlab -batch "cd('/path/to/BehaviorBox'); run('fcns/testBehaviorBoxDataDeferredSaveMkdir.m');"
```

Probe Arduino digital input levels from MATLAB:

```matlab
addpath(fullfile('/path/to/BehaviorBox', 'fcns'));
testArduinoVolts
```

The loader and save-path smoke tests support environment overrides such as `BB_DEBUG_INV`, `BB_DEBUG_INP`, `BB_DEBUG_STR`, `BB_DEBUG_SUB`, and `BB_DEBUG_FILENAME`.

## Eye tracking

The active eye-tracking boundary lives under [`EyeTrack/`](EyeTrack/README.md).

Relevant files:

- [`EyeTrack/bootstrap_eye_track.m`](EyeTrack/bootstrap_eye_track.m)
- [`EyeTrack/DeepLabCut/README.md`](EyeTrack/DeepLabCut/README.md)
- [`EyeTrack/DeepLabCut/ToMatlab/README.md`](EyeTrack/DeepLabCut/ToMatlab/README.md)
- [`EyeTrack/DeepLabCut/ToMatlab/README_eye_stream.md`](EyeTrack/DeepLabCut/ToMatlab/README_eye_stream.md)
- [`EyeTrack/DeepLabCut/TWO_COMPUTER_EYE_TRACKING_QUICKSTART.md`](EyeTrack/DeepLabCut/TWO_COMPUTER_EYE_TRACKING_QUICKSTART.md)
- [`EyeTrack/DeepLabCut/ToMatlab/run_eye_stream_receive_test.m`](EyeTrack/DeepLabCut/ToMatlab/run_eye_stream_receive_test.m)

The active eye-tracking runtime is a three-stage pipeline:

- Python streamer on the eye-tracking computer:
  `EyeTrack/DeepLabCut/ToMatlab/dlc_eye_streamer.py`
- Python deferred receiver on the behavior computer:
  `EyeTrack/DeepLabCut/ToMatlab/behavior_eye_receiver.py`
- MATLAB-side client/import/alignment path:
  `BehaviorBoxEyeTrack.m`

Transport is split accordingly:

- ZeroMQ JSON stream from streamer to receiver
- append-only per-segment CSV + JSON chunks written by the receiver
- localhost HTTP control/status API used by MATLAB to open sessions, close segments, and import finalized chunks

`EyeTrack/DeepLabCut/ToMatlab/matlab_zmq_bridge.py` and `receive_eye_stream_demo.m` are retained as older reference/demo tooling, but they are no longer the production ingest path used by BehaviorBox.

## Mock harness

[`MockApp/README.md`](MockApp/README.md) documents the headless mock harness used to debug `BehaviorBoxWheel` save logic, cleanup, and related MATLAB-side state handling without the full App Designer session.

## Native camera utility

[`usbcamv4l/README.md`](usbcamv4l/README.md) documents the Linux-only camera viewer/recorder. Build it from inside `usbcamv4l/`:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/usbcamv4l -fps
```

## Hardware and firmware

- Arduino sketches live in `Arduino/`
- hardware references and CAD assets live in `Equipment/`
- Linux automation and machine setup scripts live in `Linux-Scripts/`

When changing hardware-facing code, preserve pin assignments, serial contracts, and timing behavior unless the change explicitly requires breaking them.

## Development notes

- Prefer the smallest targeted validation over repo-wide test runs.
- Treat saved `.mat` structure changes as behavior changes.
- Keep MATLAB path handling explicit; this repo does not rely on a broad `addpath(genpath(...))` startup pattern.
- Generated outputs such as saved data, recordings, and build artifacts should stay out of git.

## Related docs

- [`AGENTS.md`](AGENTS.md): repo-specific development and validation instructions
- [`MockApp/README.md`](MockApp/README.md): wheel debug harness
- [`EyeTrack/README.md`](EyeTrack/README.md): eye-tracking subtree overview
- [`usbcamv4l/README.md`](usbcamv4l/README.md): native camera utility
