# MockApp

This folder contains a small headless MATLAB harness for debugging `BehaviorBoxWheel.m` without the real App Designer GUI, the behavior Arduino, or the Time Arduino.

## Files
- `MockControl.m`: minimal UI control object with `.Value`, `.Text`, `.String`, `.Enable`, `.Type`, and `.Tag`
- `MockArduino.m`: minimal behavior-Arduino stub with `.Acquisition(...)`
- `MockTime.m`: minimal Time-Arduino stub with `.Reset()` and `.LogEvent(...)`
- `MockApp.m`: minimal mock App Designer object with the properties needed by the current wheel smoke test
- `testBehaviorBoxWheelSaveStatus.m`: headless smoke test for wheel cleanup and save-status behavior

## When to use it
- Use this harness when a bug lives in `BehaviorBoxWheel` save logic, cleanup logic, timestamp segment handling, or other code that can run without real hardware.
- Prefer this before reconstructing a full GUI session when the failing path is mostly MATLAB-side state handling.
- Do not use it as a substitute for live hardware validation when the bug depends on actual serial timing, wheel input, reward timing, or microscope/ScanImage integration.

## Recommended command
From the repo root:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"
```

The script adds `MockApp/` to the MATLAB path explicitly and uses `tempdir` for its save artifact, so it does not depend on `startup.m` adding the folder globally.

## Related loader smoke test
For the `BehaviorBoxData` path used by the GUI load button, use:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
```

That script uses `bb_debug_saved_file.m` to print a structural summary of one loaded file after `BehaviorBoxData` finishes loading.

Optional environment overrides for the loader smoke test:
- `BB_DEBUG_INV`
- `BB_DEBUG_INP`
- `BB_DEBUG_STR`
- `BB_DEBUG_SUB`

Example:

```bash
BB_DEBUG_SUB=2517423\ -\ M\ -\ WT matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
```

## Extending the harness
- Add new fields to `MockApp.m` only when a new debug path actually needs them.
- Keep mocks minimal and deterministic.
- If you add another headless repro, prefer a new script alongside `testBehaviorBoxWheelSaveStatus.m` rather than expanding one script to cover unrelated workflows.
