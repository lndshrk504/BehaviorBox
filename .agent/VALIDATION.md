# Validation Notes

Run the narrowest validation that matches the change. Do not claim broad coverage beyond what actually ran.

## General Rules

For MATLAB code changes, validate in MATLAB, not only by static inspection.

On the current Mac, agents should prefer both MATLAB MCP and `matlab -batch` when useful, choosing whichever produces the most detailed diagnostic information. For handoff-ready validation, report the exact `matlab -batch` command when practical.

Daily production is Linux, so Linux-first validation matters for hardware and production workflows. macOS validation is still useful for analysis workflows.

## Data And Analysis Validation

Use `BehaviorBoxData.m` and `fcns/readFcn.m` as the core compatibility path.

Current useful tests discovered in `fcns/`:

```text
fcns/testBehaviorBoxDataLoad.m
fcns/testBehaviorBoxDataNoEagerMkdir.m
fcns/testBehaviorBoxDataDeferredSaveMkdir.m
fcns/testBehaviorBoxDataAllRootLoads.m
fcns/testBehaviorBoxDataOldAnalysis.m
fcns/testBehaviorBoxDataMixedEyeFieldsLoad.m
fcns/bb_debug_saved_file.m
```

Before changing `BehaviorBoxData.m`, minimum validation should prove:
- new outputs can load again
- Nose analysis does not break
- Wheel analysis does not break
- the relevant graphs are created for visual review of mouse accuracy by trial count at each level
- no real Dropbox subject folders are created during lookup validation

Before changing `SaveAllData`, minimum validation should prove:
- newly saved data can load through `BehaviorBoxData.m`
- newly saved data can load through `fcns/readFcn.m`
- saved `Score` and `Level` fields still support moving-mean analysis by level
- save-time folder creation happens only when intended

A successful Nose or Wheel analysis load is more than "no error." It should create the graphs that let the project owner visually measure, for each level, mouse accuracy on the y-axis versus trial count on the x-axis.

## Common MATLAB Commands

From this Mac workspace:

```bash
matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataNoEagerMkdir.m');"
matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataDeferredSaveMkdir.m');"
matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataMixedEyeFieldsLoad.m');"
matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataOldAnalysis.m');"
```

Linux production equivalent:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataNoEagerMkdir.m');"
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataDeferredSaveMkdir.m');"
```

When modifying root save/data files:

```bash
matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m');"
```

## Arduino Validation

Before changing Arduino sketches:
- compile the affected sketch if `arduino-cli` is already installed and the board target is known
- verify the sketch still works with the MATLAB files that use it
- verify serial protocol compatibility
- use hardware bench validation when behavior, timing, pins, or signaling changes

Do not install `arduino-cli`, board packages, or drivers unless explicitly asked.

## DLC Validation

For DLC eye-tracking or MATLAB bridge work, inspect `DLC/ToMatlab/` and the docs folder first. The active bridge uses ZMQ text communication from the eye-tracking computer to the behavior computer.

Known environments:
- eye-tracking computer: `dlclivegui`
- behavior computer: `bbeyezmq`

Use the narrowest available demo/test entrypoint after inspecting the code. Existing project guidance names:

```bash
matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('DLC/ToMatlab/receive_eye_stream_demo.m');"
```

## Camera Utility Validation

`usbcamv4l/` is Linux-only. Validate on Linux when changing it.

Known production command:

```bash
cam -f -w
```

Known native build smoke path:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/usbcamv4l -fps
```

Report which GPU class was validated: Intel integrated graphics, AMD GPU, or NVIDIA GPU.

## Current Unknowns

The project owner is not sure which tests pass today, which are flaky, or which are hardware-dependent. Agents should inspect and run the narrowest matching checks rather than assuming.
