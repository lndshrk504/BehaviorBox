# BehaviorBox AI Bootstrap

Read this directory before broad edits. These notes are for AI agents working in this repository and complement the repo-level `AGENTS.md`.

## Read Order

1. `AGENTS.md` for required working rules.
2. `.agent/DATA.md` before touching data loading, saves, analysis, or subject discovery.
3. `.agent/SCHEMA.md` before changing `BehaviorBoxData.m`, `fcns/readFcn.m`, `BehaviorBoxNose.m`, or `BehaviorBoxWheel.m`.
4. `.agent/HARDWARE.md` before Arduino, serial, microscope, wheel, photogate, reward, or camera work.
5. `.agent/VALIDATION.md` before and after edits.
6. `.agent/WORKFLOWS.md` for common task paths.
7. `.agent/SCIENTIFIC_CHANGELOG.md` when a change affects analysis, saved outputs, figures, tables, preprocessing, or reproducibility.

## Project Shape

BehaviorBox is a MATLAB-first behavioral training and analysis repo. The production app entrypoint is `BehaviorBox_App.mlapp`. `BB_App.m` exists mainly so Codex and other AI agents can inspect the readable App Designer code path.

There are exactly two active behavior modes:
- Nose, implemented through `BehaviorBoxNose.m`
- Wheel, implemented through `BehaviorBoxWheel.m`

Both workflows interact with:
- `BehaviorBoxData.m`
- `BehaviorBoxVisualStimulus.m`
- serial input/time helpers such as `BehaviorBoxSerialInput` and `BehaviorBoxSerialTime`
- Arduino sketches under `Arduino/`

Python is secondary and mainly supports DLC eye tracking through `DLC/ToMatlab/` and `DLC/Tests/`. `iRecHS2/` is historical reference only and is inactive.

## Agent Defaults

Prefer read-only inspection first, smallest defensible edit second, and narrow validation third. Do not install packages, edit environments, create real Dropbox subject folders, or change directory layout unless explicitly requested.

For MATLAB work, use MATLAB for validation. On the current Mac, use either MATLAB MCP or `matlab -batch`, choosing whichever gives the clearest diagnostic detail for the task. For handoff-ready validation, prefer an exact `matlab -batch` command when practical.

## Production Reality

Daily behavior training is run on Linux computers. The app can theoretically work on macOS, Windows, and Linux, but Linux is the production path and may expose issues that are not visible on the user's personal Mac.

Analysis workflows are expected to run on the user's personal Mac without hardware.

MATLAB version should be treated as flexible. Agents can assume these toolboxes should be installed:
- Statistics and Machine Learning Toolbox
- Image Analysis tools
- Image Processing Toolbox
- Computer Vision Toolbox

## High-Risk Areas

Treat these as high-risk:
- save paths and `SaveAllData`
- `BehaviorBoxData.m` loading, subject discovery, and analysis
- `fcns/readFcn.m`
- saved `.mat` schema compatibility
- Arduino serial contracts, pins, and baud rates
- Wheel-only microscope acquisition and frame timestamp behavior
- DLC ZMQ message parsing and MATLAB/Python shape or dtype assumptions
- real Dropbox data trees

