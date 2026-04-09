# AGENTS.md

## Repository Profile
BehaviorBox is a MATLAB-first scientific repository whose programs are primarily run on Linux computers. This pack targets the Windows CUDA and microscopy workstation, which may own microscope-analysis validation even when Linux remains the default runtime for core BehaviorBox behavior. The main workflow lives in `BehaviorBox_App.mlapp`, `BB_App.m`, and the root MATLAB classes `BehaviorBoxData*.m`, `BehaviorBoxNose.m`, `BehaviorBoxWheel.m`, and `BehaviorBoxVisualStimulus.m`. Reusable MATLAB helpers live in `fcns/`. Hardware firmware and references live in `Arduino/` and `Equipment/`. Linux automation lives in `Linux-Scripts/`. DeepLabCut eye-tracking models, bridge code, and tests live in `DLC/`. `iRecHS2/` remains in the repo as legacy reference material and should not be treated as the active eye-tracking path unless a task explicitly targets it. `usbcamv4l/` is a separate Linux-only C++ camera utility with its own `CMakeLists.txt`, intended to run on Linux systems with Intel integrated graphics, AMD GPUs, and NVIDIA GPUs.

Python is secondary in this repo. Treat `DLC/ToMatlab/` and `DLC/Tests/` as the main Python and MATLAB/Python eye-tracking area. Treat `iRecHS2/` as historical reference only unless a task explicitly targets that legacy path. Treat `ComputerSettings*.mat`, `Settings/`, and saved MATLAB outputs as configuration and schema-sensitive assets.

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
- Headless debug harness: `MockApp/`
- Hardware and environment folders: `Arduino/`, `Equipment/`, `Linux-Scripts/`
- Python helpers and mixed-language areas: `DLC/ToMatlab/`, `DLC/Tests/`, `iRecHS2/` (legacy reference only)
- Tests and verification scripts: `fcns/testArduinoVolts.m`, `fcns/TestRecord.m`, `fcns/testBehaviorBoxDataLoad.m`, `fcns/testBehaviorBoxDataNoEagerMkdir.m`, `fcns/testBehaviorBoxDataDeferredSaveMkdir.m`, `fcns/testSerialDebugLogging.m`, `DLC/ToMatlab/receive_eye_stream_demo.m`, `DLC/Tests/CheckReqs.py`, `DLC/Tests/TestSpin.py`
- Config and schema-sensitive assets: `ComputerSettings*.mat`, `Settings/`, saved `.mat` outputs, `BBAppOutput.txt`
- Native camera utility: `usbcamv4l/`
- On this Windows machine, the local BehaviorBox clone is at `C:\Users\MBO-Alpha\Desktop\BehaviorBox`.
- `BehaviorBoxData` animal-data root is `fullfile(GetFilePath("Data"), this.Inv, this.Inp)`.
- The macOS reference root for `GetFilePath("Data")` is `/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Data`; on Windows, resolve the equivalent local Dropbox or mirrored data root before validation and do not hardcode the macOS path into Windows workflows.
- The live `BehaviorBoxData` investigator/input branches currently in use are `Will/NosePoke` and `Will/Wheel`.
- Nose session data currently lives under the local equivalent of `.../Will/NosePoke/<group>/<mouse_id>/`.
- Wheel session data currently lives under the local equivalent of `.../Will/Wheel/<group>/<mouse_id>/`.
- In both trees, the first subfolder is the group/strain and the next subfolder is the mouse ID / cage-number identifier.
- Use `Inp='NosePoke'` for nose sessions and `Inp='Wheel'` for wheel sessions when constructing `BehaviorBoxData`.
- Current active Nose work is under the `shank` branch, with `3246453` as one active subject folder.
- The current active Nose cages in training are the `324645*` and `337634*` mice under the `shank` branch.
- Current reference location for active Wheel data is the `New/3421911` branch under `Will/Wheel`.

For MATLAB work, also inspect any `+pkg`, `@Class`, `private/`, `startup.m`, and `addpath` logic before changing behavior. Current `startup.m` is minimal, so do not assume it manages repo paths for you.

## MATLAB Operating Rules
- MATLAB owns MATLAB behavior. Validate `.m` changes in MATLAB, not only by static inspection.
- Use the MATLAB MCP server as the default path for execution and linting when available.
- Prefer MCP tools instead of guessing MATLAB syntax.
- Use `check_matlab_code` for static checks and `run_matlab_file` or MATLAB MCP execution for narrow script runs before suggesting or landing MATLAB changes.
- Use noninteractive `matlab -batch ...` runs for reproducible headless validation, repo-documented smoke tests, startup-dependent flows, and any result you need to report as an exact terminal command.
- If choosing between MCP and `matlab -batch`, prefer MCP for iteration and `matlab -batch` for validation and handoff-ready verification.
- When live App Designer state or hardware is the main blocker, prefer the reusable headless harness under `MockApp/` before reconstructing the full GUI manually.
- Keep `MockApp/` explicit-path only. Add that folder inside the repro script or command that needs it instead of relying on global path state.
- Unless the task explicitly targets another OS, treat Linux as the default environment for smoke tests, validation commands, and reported runtime expectations. For Windows NVIDIA or microscope-analysis tasks, validate on Windows and call out that exception explicitly.
- Keep paths deterministic. Do not add `addpath(genpath(...))` unless the repo already depends on it.
- Do not rename outputs, move data directories, or change saved-file schema without an explicit note in the handoff.
- If MATLAB and Python disagree on shapes, dtypes, indexing, or file schema, stop and explain the mismatch before forcing a fix.
- Do not install Python packages or MATLAB toolboxes unless explicitly asked.

## Arduino Operating Rules
- Arduino firmware owns Arduino timing, pin state, interrupts, and serial protocol behavior. Do not treat a sketch change as safe without at least a compile check, and use bench validation when the change affects pulses, edge timing, or connected hardware.
- Before editing a sketch, map the full signal path: sketch name, board target if known, pin numbers, pin direction, active level, pulse width, baud rate, serial command strings, downstream consumer, and the narrowest validation path.
- Preserve existing pin assignments, baud rates, pulse polarity, pulse widths, line endings, and serial message formats unless the requested change explicitly calls for breaking that contract. Call out every such contract change in the handoff.
- Keep pins and timing constants explicit near the top of the sketch using `constexpr` or `#define`. Do not scatter magic pin numbers or timing literals through `loop()` and helper functions.
- Prefer nonblocking timing with `millis()` or `micros()` for periodic signals, fake hardware clocks, and multi-signal coordination. Use `delay()` only when the blocking behavior is itself the required device behavior.
- Keep interrupt handlers minimal: capture timestamps, increment counters, or set flags only. Do not print to `Serial`, allocate memory, call long-running functions, or perform blocking waits inside an ISR.
- Mark ISR-shared state `volatile`, and protect multibyte reads or writes on AVR using `ATOMIC_BLOCK` or a brief interrupt disable/enable region.
- Set every input and output mode explicitly in `setup()`, and establish safe startup levels so attached devices do not see spurious start, reward, trigger, or acquisition pulses during boot.
- For board-to-board links, document the exact wiring assumptions in the handoff: source pin, destination pin, shared ground, expected idle state, active edge or level, and any voltage-level assumptions.
- When emulating external hardware such as a microscope, camera, or stimulus source, match the receiving system's real edge semantics and tolerance, not just the nominal rate. If the consumer counts rising edges, document that and design the fake signal accordingly.
- Do not change upload ports, board package assumptions, or programmer settings unless explicitly asked. Never install `arduino-cli`, board packages, or drivers as part of a normal code task.
- Treat hardware safety as part of correctness. Flag uncertain voltage compatibility, current draw, pull-up or pull-down assumptions, relay or valve transients, and any missing resistor, transistor, or optoisolator requirements before landing the change.

## Nose vs Wheel Boundary
`BehaviorBoxWheel.m` is the only root MATLAB workflow file that should contain microscopy- or imaging-related logic, including microscope integration, imaging metadata, and imaging timestamps. `BehaviorBoxNose.m` must remain free of microscopy-specific code and should never be required to integrate wheel-only imaging behavior.

This separation is intentional. If logic is genuinely shared, extract only the microscope-agnostic portion into a helper or shared data path; do not copy microscopy assumptions into `BehaviorBoxNose.m`.

## BehaviorBoxData Loader Contract
- `BehaviorBoxData.GetFiles()` and `fcns/testBehaviorBoxDataLoad.m` resolve animal data through `fullfile(GetFilePath("Data"), Inv, Inp)`.
- The macOS reference roots are `~/Dropbox @RU Dropbox/William Snyder/Data/Will/NosePoke` for Nose data and `~/Dropbox @RU Dropbox/William Snyder/Data/Will/Wheel` for Wheel data. On Windows, resolve the equivalent local mirror before validation.
- The current fresh-data locations to keep in mind when validating against active training are the `NosePoke/shank/3246453` branch for one active Nose subject and the `Wheel/New/3421911` branch for Wheel.
- The currently active Nose training cohorts are the `324645*` and `337634*` mice under the `NosePoke/shank/` branch.
- The intended folder layout is `Inv/Inp/Str/Sub`, where `Str` is the strain folder and `Sub` is the mouse folder.
- In practice, subject folders may be bare IDs such as `3169024` or metadata-decorated names such as `2618912 - F - WT`. If `Str` and the exact `Sub` folder name are known, `BehaviorBoxData.GetFiles()` checks that path directly first.
- If the exact `Str/Sub` path is missing or `Str` is omitted, `BehaviorBoxData.GetFiles()` falls back to a recursive search under `Inv/Inp` and matches directory names containing the requested subject string. It excludes historical folder names containing `time`, `_`, `settings`, `alltime`, or `Rescued`.
- If no matching subject directory exists, `BehaviorBoxData.handleNewStrain()` returns the would-be `Str/Sub` save path without creating the folder during lookup. The actual folder creation is deferred to save-time code such as `BehaviorBoxWheel.SaveAllData`, `BehaviorBoxNose.SaveAllData`, or `BehaviorBoxData.SaveAllData`. If `Str` is empty or the GUI placeholder `w`, it defaults the strain folder to `New`.
- Use `fcns/testBehaviorBoxDataLoad.m` for real-data loader coverage, `fcns/testBehaviorBoxDataNoEagerMkdir.m` for the non-destructive missing-subject lookup path that must not touch the real Dropbox tree, and `fcns/testBehaviorBoxDataDeferredSaveMkdir.m` for the broader deferred-save check that proves the folder is created only when `BehaviorBoxData.SaveAllData` runs.

## Save And Imaging Sync Contract
- `BehaviorBoxWheel.SaveAllData` has two distinct save modes that produce different `.mat` schemas. Do not assume every wheel-related `.mat` file has the same top-level fields.
- Training saves write top-level `Settings`, `newData`, and `Notes`. The microscopy-sync artifacts for wheel sessions live inside `newData`, not as separate top-level variables.
- Wheel training saves add these sync-critical `newData` fields when `this.Box.Input_type == 6`:
  `wheel_record`, `TimestampRecord`, `WheelDisplayRecord`, and `FrameAlignedRecord`.
- `newData.TimestampRecord` is the canonical saved timestamp stream for wheel-session sync work. It is a cell array of segment structs built from `this.timestamps_record`.
- Each `TimestampRecord` segment can include:
  `trial`, `kind`, `scanImageFile`, `raw`, `parsed`, `trialCommitted`, and `trialStatus`.
- `TimestampRecord.raw` is the raw line log captured from the Timekeeper serial stream for that segment.
- `TimestampRecord.parsed` is the structured parsed table from `BehaviorBoxSerialTime` and is the preferred source for downstream sync logic when present. Its base columns are:
  `kind`, `t_us`, `t_arduino_us`, `t_pc_receive_us`, `frame`, `event`, `trial`, `side`, `correct`, and `rewardPulse`.
- Save-time annotation adds `trialCommitted` and `trialStatus` to both the segment struct and `TimestampRecord.parsed` so downstream code can distinguish committed trials, in-progress trials, and session-level cleanup segments.
- `newData.WheelDisplayRecord` is the wheel/display state log sampled during trial execution. It is saved as a table with columns:
  `trial`, `t_us`, `phase`, `tTrial`, `rawWheel`, `delta`, `StimColor`, `screenEvent`, `level`, and `isLeftTrial`.
- Save-time annotation adds `trialCommitted` and `trialStatus` to `WheelDisplayRecord` so downstream code can filter out in-progress rows cleanly.
- `newData.FrameAlignedRecord` is the matched frame log saved by `BehaviorBoxWheel`. It is the frame-by-frame alignment table that ties imaging frames to behavior state. Its columns are:
  `trial`, `frame`, `t_us`, `t_arduino_us`, `t_pc_receive_us`, `phase`, `tTrial`, `rawWheel`, `delta`, `StimColor`, `screenEvent`, `level`, `isLeftTrial`, `decision`, and `correct`.
- For microscopy analysis, treat `newData.TimestampRecord`, `newData.WheelDisplayRecord`, and especially `newData.FrameAlignedRecord` as the primary saved BehaviorBox sync artifacts that explain how ScanImage or other image frames map onto behavior time, trial phase, wheel state, and behavior events.
- Prefer `newData.FrameAlignedRecord` and `newData.TimestampRecord.parsed` over reparsing raw strings when those saved fields are available.
- `BehaviorBoxWheel.SaveAllData("Activity","Animate",...)` produces a different animation-oriented file shape with top-level `Settings`, `Position_Record`, `Notes`, `TimeLog`, `MapLog`, `MapMeta`, and `TimestampRecord`.
- In animation saves, `TimeLog` is the flattened raw timestamp log, `TimestampRecord` carries the segment structs, and `MapLog` / `MapMeta` hold the mapping-animation outputs. These are top-level fields, not nested under `newData`.
- `BehaviorBoxData.loadFiles()` reads session files through `fileDatastore(..., "ReadFcn", @readFcn)`. `readFcn` returns an 8-column cell row with:
  filename, session date, `newData`, `StimHist`, extras, subject-folder name, `Position_Record`, and `Settings`.
- `readFcn` collects top-level fields other than `Settings`, `newData`, `StimHist`, and `Position_Record` into the extras struct. For animation or mapping files, this is where `TimeLog`, `MapLog`, `MapMeta`, `TimestampRecord`, `Notes`, and any preserved raw-field copies remain available.
- `BehaviorBoxData.GetReadExtras()` is the supported way to access those top-level extras after load.
- `readFcn` canonicalizes historical wheel timestamp fields by copying `TtimestampRecord` into `newData.TimestampRecord` when needed. Treat `TimestampRecord` as the normalized field name going forward, and treat `TtimestampRecord` as historical compatibility data.
- `readFcn` preserves additive session-wide tables such as `WheelDisplayRecord` and `FrameAlignedRecord` during normalization; they are not trial vectors and must not be trimmed like per-trial numeric arrays.
- `BehaviorBoxData.CombineDays()` combines only rows that contain `newData`. Animate-only files that have `Position_Record` / `TimeLog` but no `newData` are read but excluded from the combined training-session analysis path.
- For microscope or sync work, start by identifying which file type you have:
  wheel training session file with `newData`, or animation/mapping file with top-level `TimeLog` / `MapLog`.
- For wheel-image synchronization, use `newData.FrameAlignedRecord` as the first-choice matched frame log, use `newData.TimestampRecord.parsed` as the detailed event/frame timeline, and fall back to `TimestampRecord.raw` or top-level `TimeLog` only when the parsed artifacts are missing.
- Legacy imaging scripts such as `Imaging Analysis scripts/MatchFramesToTimestamps.m` and downstream `FrameMatched*.mat` outputs are analysis artifacts built after the save. They are not the primary save contract of `BehaviorBoxWheel.SaveAllData`.
- Any change to the field names, nesting level, segment semantics, timestamp edge semantics, or frame-alignment columns above is a saved-file schema change and must be called out explicitly in the handoff.

## Local Validation
Run the narrowest matching checks, in this order when relevant:

Unless a task explicitly targets another OS, run and report smoke tests as Linux-first validations. If you validate on macOS or Windows instead, say so explicitly and call out any platform-specific assumptions.

1. Initialize MATLAB from the repo root when a session setup step is needed:
   `matlab -batch "run('startup.m')"`
2. When debugging `BehaviorBoxWheel.m` save/cleanup logic without real GUI or hardware, use the headless smoke test:
   `matlab -batch "cd('C:\Users\MBO-Alpha\Desktop\BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"`
3. When debugging the `BehaviorBoxData` loader path that the GUI uses, run the headless smoke test:
   `matlab -batch "cd('C:\Users\MBO-Alpha\Desktop\BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"`
   Current loader defaults in that script are `Inv=Will`, `Inp=Wheel`, and `Sub=3421911`; override with `BB_DEBUG_INV`, `BB_DEBUG_INP`, `BB_DEBUG_STR`, and `BB_DEBUG_SUB` when targeting a known Nose or Wheel subject tree.
   For current fresh-data checks, the relevant Nose branch is `BB_DEBUG_INP=NosePoke`, `BB_DEBUG_STR=shank`, `BB_DEBUG_SUB=3246453`; the active Nose cohorts currently being trained are the `324645*` and `337634*` mice. The current Wheel branch remains `BB_DEBUG_STR=New`, `BB_DEBUG_SUB=3421911`.
4. When debugging missing-subject handling or typo resistance in `BehaviorBoxData`, run the isolated smoke test that shadows `GetFilePath("Data")` onto a temporary root so the real Dropbox tree is untouched:
   `matlab -batch "cd('C:\Users\MBO-Alpha\Desktop\BehaviorBox'); run('fcns/testBehaviorBoxDataNoEagerMkdir.m');"`
   Default test config is `Inv=Will`, `Inp=Wheel`, `Str=New`, `Sub=9999999`; override with `BB_DEBUG_INV`, `BB_DEBUG_INP`, `BB_DEBUG_STR`, and `BB_DEBUG_SUB` when you want to probe a different missing subject path.
5. When debugging deferred folder creation in `BehaviorBoxData`, run the broader smoke test that first proves lookup is non-destructive and then verifies `BehaviorBoxData.SaveAllData` creates the folder and `.mat` file at save time:
   `matlab -batch "cd('C:\Users\MBO-Alpha\Desktop\BehaviorBox'); run('fcns/testBehaviorBoxDataDeferredSaveMkdir.m');"`
   Default test config is `Inv=Will`, `Inp=Wheel`, `Str=New`, `Sub=9999999`, `BB_DEBUG_FILENAME=behaviorbox_save_validation`; override the same `BB_DEBUG_*` variables when you need a different temporary path shape or output filename.
6. When debugging `Debug_SerialLogMode`, serial TX/RX observability, or serial write-on-failure artifacts, run the focused smoke test:
   `matlab -batch "cd('C:\Users\MBO-Alpha\Desktop\BehaviorBox'); run('fcns/testSerialDebugLogging.m');"`
   This smoke test covers the `memory`, `file`, and `failure` modes on temporary roots, verifies the canonical CSV header, and checks that paired JSON/CSV failure artifacts are written only in `failure` mode.
7. For Arduino sketch changes, compile the narrowest affected sketch with `arduino-cli` when it is already installed and the board target is known. Report the exact fully qualified board name and sketch path, for example:
   `arduino-cli compile --fqbn arduino:avr:uno Arduino/Rotary`
8. For Arduino-facing work that depends on BehaviorBox MATLAB integration, use the focused smoke test:
   `matlab -batch "run('fcns/testArduinoVolts.m')"`
9. For Arduino timing, serial-protocol, or inter-device signaling changes, also run the narrowest hardware-in-the-loop bench check you can and report the board, connected pins, baud rate, expected pulse width or frequency, and what you observed. If no bench hardware is available, say so explicitly.
10. For DLC eye-tracking / MATLAB bridge integration work, use the focused demo entrypoint when the streamer and bridge dependencies are available:
   `matlab -batch "cd('C:\Users\MBO-Alpha\Desktop\BehaviorBox'); run('DLC/ToMatlab/receive_eye_stream_demo.m');"`
11. If a MATLAB test suite is added or available for the changed area, prefer the narrowest `runtests` target. Use repo-wide `runtests` only when justified:
   `matlab -batch "results = runtests; assertSuccess(results);"`
12. If Python under `DLC/ToMatlab/` or `DLC/Tests/` is changed and there is no formal test suite, run the smallest reproducible script or analysis entrypoint and report exactly what you ran.
13. For `usbcamv4l/`, treat it as Linux-only and validate from a Linux environment with the native build from that directory. When relevant, call out whether validation was performed on Intel integrated graphics, AMD GPU, or NVIDIA GPU hardware:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/usbcamv4l -fps
```

There is no repo-wide Python test runner or coverage gate today. Do not claim broader automated coverage than you actually ran.

## Coding Style and Change Scope
Follow adjacent file style; the repo has an empty `.editorconfig`, so consistency is enforced by convention. MATLAB classes use `PascalCase` filenames such as `BehaviorBoxNose.m`. Helper scripts in `fcns/` use descriptive names like `copytoStruct.m`, `TestRecord.m`, and `testArduinoVolts.m`. Prefer spaces over tabs; MATLAB blocks here are typically 4-space indented. In `usbcamv4l/`, keep C++17 style with `PascalCase` types and `snake_case` helper functions.

Add focused verification scripts near the subsystem you changed, following existing patterns like `TestRecord.m`, `testArduinoVolts.m`, or `receive_eye_stream_demo.m`. For hardware-facing work, note the device, OS, and expected behavior you validated.

## MATLAB SaveData Safety
`SaveAllData` in `BehaviorBoxNose.m` and `BehaviorBoxWheel.m` is a high-risk path and should be coded defensively.
- Normalize mixed path/name types before use (`filedir`, `Sub`) because values may be `cell`, `string`, or `char`.
- Normalize legacy setting containers before concatenation (`Old_Setting_Struct`, `SetUpdate`) to avoid brace-index or cell-conversion crashes.
- Build save paths with `fullfile(...)` instead of string concatenation.
- Guard graph-copy and export code with `~isempty(fig) && isvalid(fig)` so data save can continue even if the graph figure is closed.

## Save Regression Checklist
When modifying `BehaviorBoxNose.m`, `BehaviorBoxWheel.m`, or `BehaviorBoxData.m`:
- Run `matlab -batch "checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m');"`.
- Run `matlab -batch "cd('C:\Users\MBO-Alpha\Desktop\BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"` when the change touches `BehaviorBoxData` load compatibility or subject discovery.
- Run `matlab -batch "cd('C:\Users\MBO-Alpha\Desktop\BehaviorBox'); run('fcns/testBehaviorBoxDataNoEagerMkdir.m');"` when the change touches `BehaviorBoxData` folder lookup, typo handling, or deferred folder creation.
- Run `matlab -batch "cd('C:\Users\MBO-Alpha\Desktop\BehaviorBox'); run('fcns/testBehaviorBoxDataDeferredSaveMkdir.m');"` when the change touches save-time folder creation or the contract that missing subject folders are created only when save runs.
- Run `matlab -batch "cd('C:\Users\MBO-Alpha\Desktop\BehaviorBox'); run('fcns/testSerialDebugLogging.m');"` when the change touches `BehaviorBoxSerialInput.m`, `BehaviorBoxSerialTime.m`, `Debug_SerialLogMode`, serial logging retention, or serial write-on-failure artifacts.
- Verify one Nose and one Wheel session can start, stop, and save data without callback errors.
- Verify fallback save-path behavior, including manual file selection, still works if the default folder is unavailable.
- Confirm there are no unresolved conflict markers with `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m BehaviorBoxWheel.m BehaviorBoxData.m`.

## Commit and Pull Request Guidelines
Recent history favors short, imperative commit subjects tied to the changed module, for example `Fix SaveAllData type/path handling for Nose and Wheel`. Keep that style and avoid vague summaries. Pull requests should describe the behavioral change, list the affected hardware path such as nose, wheel, Arduino, DLC eye tracking, or camera, include manual test steps, and attach screenshots for GUI or display changes.

## Branch and Merge Hygiene
- Keep `master` current before merging long-lived branches such as `patch` to reduce avoidable conflicts.
- Prefer merge-based integration for long-lived branch histories. Use rebase only when intentionally rewriting local commit history.

## Data and Configuration Hygiene
Do not commit generated `.mat`, `.txt`, `.asv`, recordings, or `build/` outputs; they are already ignored. Review `Linux-Scripts/` carefully before running setup scripts, especially anything that changes system startup behavior or requires `sudo`.

## Definition of Done
A task is done only when:
- the diff is scoped
- the target behavior is validated with MATLAB, Python, and/or Arduino as appropriate
- schema, tolerance, and output changes are called out explicitly
- pin maps, serial protocol changes, and timing changes are called out explicitly for hardware-facing work
- follow-up work is listed if anything remains unresolved

## Review Guidelines
- Flag numerical regressions, silent shape changes, path brittleness, hidden environment coupling, and saved-file schema drift as high priority.
- Treat missing validation for changed analysis code as a real issue, not a paperwork issue.
- For Arduino and hardware-facing reviews, flag pin-map drift, pulse-width or polarity changes, baud-rate or serial-protocol drift, ISR misuse, blocking timing paths, unsafe startup states, and unverified voltage-level assumptions as high priority.
