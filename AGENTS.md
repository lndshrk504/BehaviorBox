# Repository Guidelines

## Project Structure & Module Organization
`BehaviorBox_App.mlapp` and the root MATLAB classes (`BehaviorBoxData*.m`, `BehaviorBoxNose.m`, `BehaviorBoxWheel.m`, `BehaviorBoxVisualStimulus.m`) drive the main behavior-box workflow. Reusable MATLAB helpers live in `fcns/`. Hardware firmware and wiring references are kept in `Arduino/` and `Equipment/`. Linux automation lives in `Linux-Scripts/`. `iRecHS2/` contains eye-tracker examples and tests, while `usbcamv4l/` is a separate C++ camera utility with its own `CMakeLists.txt`.

## When working with MATLAB code:
- Use the matlab MCP server for execution and linting
- Prefer MCP tools instead of guessing MATLAB syntax
- Use run_matlab_file for scripts
- Use check_matlab_code before suggesting changes

## Nose vs Wheel Boundary
`BehaviorBoxWheel.m` is the only root MATLAB workflow file that should contain microscopy- or imaging-related logic, including microscope integration, imaging metadata, and imaging timestamps. `BehaviorBoxNose.m` must remain free of microscopy-specific code and should never be required to integrate wheel-only imaging behavior.

This separation is intentional and is the reason the project keeps distinct Nose and Wheel files. If logic is genuinely shared, extract only the microscope-agnostic portion into a helper or shared data path; do not copy microscopy assumptions into `BehaviorBoxNose.m`.

## Build, Test, and Development Commands
Run MATLAB from the repository root so local scripts resolve correctly.

`matlab -batch "run('startup.m')"` initializes the MATLAB session.

`matlab -batch "run('fcns/testArduinoVolts.m')"` runs a quick Arduino voltage sanity check.

`matlab -batch "run('iRecHS2/iRecTests/iRecTest1.m')"` exercises the iRec integration after Opticka is installed.

From `usbcamv4l/`, build the native camera tool with:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/usbcamv4l -fps
```

## Coding Style & Naming Conventions
Follow adjacent file style; the repo has an empty `.editorconfig`, so consistency is enforced by convention. MATLAB classes use `PascalCase` filenames such as `BehaviorBoxNose.m`. Helper scripts in `fcns/` use descriptive names like `copytoStruct.m`, `TestRecord.m`, and `testArduinoVolts.m`. Prefer spaces over tabs; MATLAB blocks here are typically 4-space indented. In `usbcamv4l/`, keep C++17 style with `PascalCase` types and `snake_case` helper functions.

## Testing Guidelines
There is no repo-wide automated test runner or coverage gate. Add focused `.m` verification scripts near the subsystem you changed, following existing patterns like `TestRecord.m`, `testArduinoVolts.m`, or `iRecTest1.m`. For hardware-facing work, note the device, OS, and expected behavior you validated.

## MATLAB SaveData Safety
`SaveAllData` in `BehaviorBoxNose.m` and `BehaviorBoxWheel.m` is a high-risk path and should be coded defensively.
- Normalize mixed path/name types before use (`filedir`, `Sub`) because values may be `cell`, `string`, or `char`.
- Normalize legacy setting containers before concatenation (`Old_Setting_Struct`, `SetUpdate`) to avoid brace-index/cell conversion crashes.
- Build save paths with `fullfile(...)` instead of string concatenation.
- Guard graph-copy/export code with `~isempty(fig) && isvalid(fig)` so data save can continue even if the graph figure is closed.

## Save Regression Checklist
When modifying `BehaviorBoxNose.m`, `BehaviorBoxWheel.m`, or `BehaviorBoxData.m`:
- Run `matlab -batch "checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m');"`.
- Verify one Nose and one Wheel session can start, stop, and save data without callback errors.
- Verify fallback save path behavior (manual file selection) still works if the default folder is unavailable.
- Confirm there are no unresolved conflict markers with `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m BehaviorBoxWheel.m BehaviorBoxData.m`.

## Commit & Pull Request Guidelines
Recent history favors short, imperative commit subjects tied to the changed module, for example `Fix SaveAllData type/path handling for Nose and Wheel`. Keep that style and avoid vague summaries. Pull requests should describe the behavioral change, list the affected hardware path (nose, wheel, Arduino, iRec, or camera), include manual test steps, and attach screenshots for GUI or display changes.

## Branch & Merge Hygiene
- Keep `master` current before merging long-lived branches (for example `patch`) to reduce avoidable conflicts.
- Prefer merge-based integration for long-lived branch histories; use rebase only when intentionally rewriting local commit history.

## Data & Configuration Hygiene
Do not commit generated `.mat`, `.txt`, `.asv`, recordings, or `build/` outputs; they are already ignored. Review `Linux-Scripts/` carefully before running setup scripts, especially anything that changes system startup behavior or requires `sudo`.
