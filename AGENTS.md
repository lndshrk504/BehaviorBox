# AGENTS.md

## Repository Profile
BehaviorBox is a MATLAB-first scientific repository on macOS. The main workflow lives in `BehaviorBox_App.mlapp`, `BB_App.m`, and the root MATLAB classes `BehaviorBoxData*.m`, `BehaviorBoxNose.m`, `BehaviorBoxWheel.m`, and `BehaviorBoxVisualStimulus.m`. Reusable MATLAB helpers live in `fcns/`. Hardware firmware and references live in `Arduino/` and `Equipment/`. Linux automation lives in `Linux-Scripts/`. Eye-tracker code, examples, and tests live in `iRecHS2/`. `usbcamv4l/` is a separate C++ camera utility with its own `CMakeLists.txt`.

Python is secondary in this repo. Treat `iRecHS2/scripts/` as the main Python area and `ComputerSettings*.mat`, `Settings/`, and saved MATLAB outputs as configuration and schema-sensitive assets.

## Working Agreements
- Before editing, map the real execution path and name the files, functions, classdefs, scripts, and tests involved.
- Prefer read-only exploration first, implementation second, review last.
- Make the smallest defensible change first. Do not do drive-by cleanup.
- Treat scientific and numerical output changes as behavior changes. Call out expected differences in figures, tables, saved arrays, metadata, or tolerances before editing.
- Run the narrowest relevant validation after every meaningful edit. Report the exact command, a short result summary, and what remains unverified.
- Never install packages, change environments, edit large data artifacts, or rewrite directory layouts unless explicitly asked.
- End every task with: changed files, validation run, remaining risks, next best step.

## Mandatory Skill Usage
- If you edit `.m` files, `classdef` files, package folders, MATLAB scripts, or MATLAB tests, use `$matlab-change-verification`.
- If you touch both MATLAB and Python, any `py.` bridge in MATLAB, any `matlab.engine` usage in Python, or any `.mat` / HDF5 interchange, use `$matlab-python-interop`.
- If a change affects figures, numerical outputs, saved arrays, tables, preprocessing, or research reproducibility, use `$analysis-reproducibility-audit`.

## Planning Rule
If the task is multi-file, cross-language, touches multiple directories, crosses a data-format boundary, or is likely to change scientific outputs, create or update an ExecPlan in `.agent/PLANS.md` before broad edits.

## Repo Layout Checklist
Before broad edits, inspect the real equivalents in this repo rather than assuming a template layout:
- Main MATLAB app and workflow files: `BehaviorBox_App.mlapp`, `BB_App.m`, `BehaviorBoxData*.m`, `BehaviorBoxNose.m`, `BehaviorBoxWheel.m`, `BehaviorBoxVisualStimulus.m`
- MATLAB helper and analysis folders: `fcns/`, `Imaging Analysis scripts/`, `Stimulus/`
- Hardware and environment folders: `Arduino/`, `Equipment/`, `Linux-Scripts/`
- Python helpers and mixed-language areas: `iRecHS2/scripts/`
- Tests and verification scripts: `fcns/testArduinoVolts.m`, `fcns/TestRecord.m`, `iRecHS2/iRecTests/iRecTest1.m`
- Config and schema-sensitive assets: `ComputerSettings*.mat`, `Settings/`, saved `.mat` outputs, `BBAppOutput.txt`
- Native camera utility: `usbcamv4l/`

For MATLAB work, also inspect any `+pkg`, `@Class`, `private/`, `startup.m`, and `addpath` logic before changing behavior. Current `startup.m` is minimal, so do not assume it manages repo paths for you.

## MATLAB Operating Rules
- MATLAB owns MATLAB behavior. Validate `.m` changes in MATLAB, not only by static inspection.
- Use the MATLAB MCP server for execution and linting when available.
- Prefer MCP tools instead of guessing MATLAB syntax.
- Use `run_matlab_file` for scripts and `check_matlab_code` before suggesting or landing MATLAB changes.
- Prefer noninteractive MATLAB runs with `matlab -batch ...` over GUI actions.
- Keep paths deterministic. Do not add `addpath(genpath(...))` unless the repo already depends on it.
- Do not rename outputs, move data directories, or change saved-file schema without an explicit note in the handoff.
- If MATLAB and Python disagree on shapes, dtypes, indexing, or file schema, stop and explain the mismatch before forcing a fix.
- Do not install Python packages or MATLAB toolboxes unless explicitly asked.

## Nose vs Wheel Boundary
`BehaviorBoxWheel.m` is the only root MATLAB workflow file that should contain microscopy- or imaging-related logic, including microscope integration, imaging metadata, and imaging timestamps. `BehaviorBoxNose.m` must remain free of microscopy-specific code and should never be required to integrate wheel-only imaging behavior.

This separation is intentional. If logic is genuinely shared, extract only the microscope-agnostic portion into a helper or shared data path; do not copy microscopy assumptions into `BehaviorBoxNose.m`.

## Local Validation
Run the narrowest matching checks, in this order when relevant:

1. Initialize MATLAB from the repo root when a session setup step is needed:
   `matlab -batch "run('startup.m')"`
2. For Arduino-facing work, use the focused smoke test:
   `matlab -batch "run('fcns/testArduinoVolts.m')"`
3. For iRec integration work, use the focused test entrypoint after Opticka is installed:
   `matlab -batch "run('iRecHS2/iRecTests/iRecTest1.m')"`
4. If a MATLAB test suite is added or available for the changed area, prefer the narrowest `runtests` target. Use repo-wide `runtests` only when justified:
   `matlab -batch "results = runtests; assertSuccess(results);"`
5. If Python under `iRecHS2/scripts/` is changed and there is no formal test suite, run the smallest reproducible script or analysis entrypoint and report exactly what you ran.
6. For `usbcamv4l/`, validate with the native build from that directory:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/usbcamv4l -fps
```

There is no repo-wide Python test runner or coverage gate today. Do not claim broader automated coverage than you actually ran.

## Coding Style and Change Scope
Follow adjacent file style; the repo has an empty `.editorconfig`, so consistency is enforced by convention. MATLAB classes use `PascalCase` filenames such as `BehaviorBoxNose.m`. Helper scripts in `fcns/` use descriptive names like `copytoStruct.m`, `TestRecord.m`, and `testArduinoVolts.m`. Prefer spaces over tabs; MATLAB blocks here are typically 4-space indented. In `usbcamv4l/`, keep C++17 style with `PascalCase` types and `snake_case` helper functions.

Add focused verification scripts near the subsystem you changed, following existing patterns like `TestRecord.m`, `testArduinoVolts.m`, or `iRecTest1.m`. For hardware-facing work, note the device, OS, and expected behavior you validated.

## MATLAB SaveData Safety
`SaveAllData` in `BehaviorBoxNose.m` and `BehaviorBoxWheel.m` is a high-risk path and should be coded defensively.
- Normalize mixed path/name types before use (`filedir`, `Sub`) because values may be `cell`, `string`, or `char`.
- Normalize legacy setting containers before concatenation (`Old_Setting_Struct`, `SetUpdate`) to avoid brace-index or cell-conversion crashes.
- Build save paths with `fullfile(...)` instead of string concatenation.
- Guard graph-copy and export code with `~isempty(fig) && isvalid(fig)` so data save can continue even if the graph figure is closed.

## Save Regression Checklist
When modifying `BehaviorBoxNose.m`, `BehaviorBoxWheel.m`, or `BehaviorBoxData.m`:
- Run `matlab -batch "checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m');"`.
- Verify one Nose and one Wheel session can start, stop, and save data without callback errors.
- Verify fallback save-path behavior, including manual file selection, still works if the default folder is unavailable.
- Confirm there are no unresolved conflict markers with `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m BehaviorBoxWheel.m BehaviorBoxData.m`.

## Commit and Pull Request Guidelines
Recent history favors short, imperative commit subjects tied to the changed module, for example `Fix SaveAllData type/path handling for Nose and Wheel`. Keep that style and avoid vague summaries. Pull requests should describe the behavioral change, list the affected hardware path such as nose, wheel, Arduino, iRec, or camera, include manual test steps, and attach screenshots for GUI or display changes.

## Branch and Merge Hygiene
- Keep `master` current before merging long-lived branches such as `patch` to reduce avoidable conflicts.
- Prefer merge-based integration for long-lived branch histories. Use rebase only when intentionally rewriting local commit history.

## Data and Configuration Hygiene
Do not commit generated `.mat`, `.txt`, `.asv`, recordings, or `build/` outputs; they are already ignored. Review `Linux-Scripts/` carefully before running setup scripts, especially anything that changes system startup behavior or requires `sudo`.

## Definition of Done
A task is done only when:
- the diff is scoped
- the target behavior is validated with MATLAB and/or Python as appropriate
- schema, tolerance, and output changes are called out explicitly
- follow-up work is listed if anything remains unresolved

## Review Guidelines
- Flag numerical regressions, silent shape changes, path brittleness, hidden environment coupling, and saved-file schema drift as high priority.
- Treat missing validation for changed analysis code as a real issue, not a paperwork issue.
