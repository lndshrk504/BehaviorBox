    # Execution Plans for this repo

    Use an execution plan for any task that is:
    - multi-file
    - cross-language or cross-runtime
    - likely to take more than one validation cycle
    - likely to change scientific outputs, saved-file schema, or numerical behavior

    Every plan must include:
    1. Goal
    2. Non-goals
    3. Current-state summary
    4. Files likely touched
    5. Validation commands
    6. Milestones
    7. Risks and stop conditions
    8. Handoff notes

    Operating rules:
    - keep milestones small and verifiable
    - run validation after every milestone
    - do not widen scope without updating the plan
    - update the plan when reality changes
    - For MATLAB milestones, include the exact `matlab -batch` command you will run.
- If the task crosses MATLAB and Python, list both sides of the boundary and the file/schema contract.

    Required stop conditions:
    - stop if MATLAB and Python disagree on shapes, dtypes, indexing, or file schema
- stop if a change would silently alter saved `.mat`, `.h5`, `.json`, or `.csv` outputs without an explicit migration note

## 2026-03-23 Add Criterion Analytics To BehaviorBoxData

1. Goal
- Add the additive `TrialsToCriterion80`, `trialsToCriterionSliding`, and `trialsToCriterionBayes` methods from the reviewed `BehaviorBoxData_Revised.m` into the live `BehaviorBoxData.m`.

2. Non-goals
- Do not change acquisition behavior, save-path behavior, plotting, GUI wiring, or existing analysis outputs unless the new methods are explicitly called.
- Do not merge any other revised-file changes.

3. Current-state summary
- `BehaviorBoxData.m` is a plain root-level classdef, not in a package, class folder, or `private/` folder.
- The class is instantiated from `BehaviorBoxNose.m`, `BehaviorBoxWheel.m`, and `BB_App.m`.
- No existing `TrialsToCriterion*` methods are present in the live repo.
- `BehaviorBoxData` constructor adds the local `fcns/` folder to path.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxData.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint: `checkcode('BehaviorBoxData.m')`
- MATLAB smoke check:
  `Tbl = table([1;1;1;0;1;1;1;1],[1;1;1;1;1;1;1;1],'VariableNames',{'Score','Level'});`
  `bb = BehaviorBoxData('find',true);`
  `T = bb.TrialsToCriterion80(Tbl,'Window',4,'Criterion',0.75);`
  `disp(T);`

6. Milestones
- Add the new instance method and static helpers only.
- Run MATLAB lint.
- Run the focused in-memory smoke check.

7. Risks and stop conditions
- This is analysis code, so the allowed behavior change is limited to new outputs from explicit calls to the new methods.
- Stop if adding the methods changes class parsing, constructor dispatch, or existing analysis/save behavior.

8. Handoff notes
- Call out that existing outputs should remain invariant unless a caller starts using the new methods.
- Report the exact validation commands and any remaining gaps.

## 2026-03-23 Add Timekeeper Frame Reset Command

1. Goal
- Add a serial command to `Arduino/Timekeeper/Timekeeper.ino` so sending character `0` resets the emitted frame counter to zero.
- Call that new reset path from `BehaviorBoxWheel.m` during `SetupBeforeLoop`.

2. Non-goals
- Do not change Timekeeper timestamp semantics or reset the session microsecond clock.
- Do not change `BehaviorBoxSerialTime.m` parsing unless the new firmware behavior requires it.
- Do not modify `Rotary.ino` or `Photogate.ino`; use them only as reference patterns.

3. Current-state summary
- `Rotary.ino` already handles serial command `0` by resetting its encoder state.
- `Timekeeper.ino` currently has no command parser in `loop()`.
- `BehaviorBoxWheel.SetupBeforeLoop()` prepares the time log but does not currently reset the Timekeeper frame counter.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/Arduino/Timekeeper/Timekeeper.ino`
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint: `checkcode('BehaviorBoxWheel.m')`
- Read-only firmware sanity review via diff and direct inspection because no Arduino build path is currently configured in the repo instructions.

6. Milestones
- Add a non-blocking serial command handler in `Timekeeper.ino` for `0`.
- Reset the frame counter safely without resetting the monotonic time base.
- Call the reset from `BehaviorBoxWheel.SetupBeforeLoop()` before opening the new time segment.
- Run focused validation on the MATLAB side and inspect the final diff.

7. Risks and stop conditions
- Stop if the reset design would also reset session timestamps or silently alter the logged time base.
- Stop if the MATLAB call site would race with serial setup in a way that risks losing the reset command.

8. Handoff notes
- Report whether buffered events are cleared or retained on reset.
- Call out that frame numbering after reset will restart from zero/one depending on whether the first emitted frame is counted post-edge.

## 2026-03-24 Extend Wheel/Stimulus Logging For Imaging Sync

1. Goal
- Add additive logging in `BehaviorBoxWheel.m` so saved wheel trials include:
- the raw `ReadWheel()` value
- the existing derived `wheelchoice` value
- the actual drawn display values needed to reconstruct what the mouse saw
- a frame-aligned derived table built from `TimestampRecord.parsed`

2. Non-goals
- Do not repurpose or redefine existing `wheel_record`, `StimHist`, or `TimestampRecord`.
- Do not move trial-metric logging into `BehaviorBoxSerialInput.m`.
- Do not add explicit wheel reset-event logging.
- Do not change the Timekeeper/annotation clock strategy in this pass.
- Do not add a new stimulus event stream beyond the existing `Time.Log`.

3. Current-state summary
- `BehaviorBoxWheel.readLeverLoopAnalogWheel()` reads `this.a.ReadWheel()` but saves only the derived/clipped `wheelchoice` trace and trial-relative `wheelchoicetime`.
- `BehaviorBoxWheel` already saves `wheel_record`, `StimHist`, and `TimestampRecord`.
- `TimestampRecord.parsed` already exposes structured frame/signal/annotation rows, but the current imaging analysis script still reparses raw strings.
- The user prefers to keep logging responsibilities inside `BehaviorBoxWheel.m`.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxData.m`
- `/Users/willsnyder/Desktop/BehaviorBox/Imaging Analysis scripts/MatchFramesToTimestamps.m`
- `/Users/willsnyder/Desktop/BehaviorBox/Next Steps, ChatGPT/Wheel_Stimulus_ImagingSync_Plan.md`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint:
  `matlab -batch "checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m');"`
- Conflict-marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" /Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m /Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxData.m /Users/willsnyder/Desktop/BehaviorBox/Imaging\ Analysis\ scripts/MatchFramesToTimestamps.m`
- Manual wheel-session smoke test after implementation:
  run one short wheel trial and inspect the saved `.mat` for existing `wheel_record`, new additive wheel/display fields, and `TimestampRecord`

6. Milestones
- Define additive field names and save schema without changing existing fields.
- Capture raw wheel values plus actual drawn display values in `BehaviorBoxWheel.readLeverLoopAnalogWheel()`.
- Save the new fields into training output.
- Update or replace the imaging analysis step so it uses `TimestampRecord.parsed`.
- Build the frame-aligned table and verify it reconstructs one known trial sensibly.

7. Risks and stop conditions
- Stop if the new fields require redefining existing saved-field semantics instead of adding new ones.
- Stop if the proposed frame-aligned table cannot be built cleanly from current `TimestampRecord.parsed` plus saved wheel/display traces.
- Stop if a change would silently alter existing saved `.mat` schema beyond explicit additive fields.

8. Handoff notes
- Preserve backward compatibility of `wheel_record`, `StimHist`, and `TimestampRecord`.
- Call out exactly which new fields are additive.
- Report whether the frame-aligned table is saved during acquisition or generated only during analysis.

## 2026-03-25 Implement WheelDisplayRecord And FrameAlignedRecord In BehaviorBoxWheel

1. Goal
- Implement the committed additive wheel/imaging sync schema directly in `BehaviorBoxWheel.m`.
- Save `WheelDisplayRecord` and `FrameAlignedRecord` into training output without redefining existing saved fields.

2. Non-goals
- Do not change `BehaviorBoxData.m`, imaging analysis scripts, or Arduino firmware in this pass.
- Do not redefine `wheel_record`, `StimHist`, or `TimestampRecord`.
- Do not run MATLAB validation unless the user explicitly asks for it.

3. Current-state summary
- `BehaviorBoxWheel.readLeverLoopAnalogWheel()` already has the needed source variables `dist`, `delta`, `baseColor`, and the idle-blink logic that drives `stallblink`.
- `BehaviorBoxWheel.WaitForInput()` already logs `hold_still_start`, which is the chosen `tTrial` anchor.
- `BehaviorBoxWheel.AfterTrial()` already stores the current timestamp segment into `timestamps_record`.
- Training save already writes `newData.TimestampRecord` for wheel sessions.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- No validation commands will be run in this pass unless the user explicitly requests them.
- Smallest proposed MATLAB follow-up if requested:
  `matlab -batch "checkcode('BehaviorBoxWheel.m')"`

6. Milestones
- Add additive properties and table helpers for `WheelDisplayRecord` and `FrameAlignedRecord`.
- Capture wheel/display rows and `stallblink_start`/`stallblink_end` events at draw time in `readLeverLoopAnalogWheel()`.
- Add phase-anchor rows for `hold_still`, `response`, `reward`, and `intertrial`.
- Build `CurrentTrialFrameAlignedRecord` and append session-wide `FrameAlignedRecord` after each trial.
- Save both additive tables into `newData` for wheel sessions when `this.Time` exists.

7. Risks and stop conditions
- Stop if implementing the new tables would require changing the meaning of existing saved fields.
- Stop if the current timestamp segment lacks enough information to build `FrameAlignedRecord` without inventing a new clocking rule.
- Stop if a needed change would force edits outside `BehaviorBoxWheel.m` in this pass.

8. Handoff notes
- Call out that saved `.mat` output intentionally gains additive `WheelDisplayRecord` and `FrameAlignedRecord` fields.
- Report that implementation was not MATLAB-validated in this pass unless the user later requests validation.

## 2026-03-27 Restore BehaviorBoxData Compatibility With Additive Wheel Tables

1. Goal
- Reproduce and fix the GUI subject-load failure triggered by the additive `WheelDisplayRecord` and `FrameAlignedRecord` fields now saved by `BehaviorBoxWheel.m`.
- Keep the new wheel-session outputs additive while restoring `BehaviorBoxData` load compatibility for existing GUI and analysis entrypoints.

2. Non-goals
- Do not remove the new wheel/imaging sync fields from saved wheel `.mat` files.
- Do not refactor broader `BehaviorBoxData` analysis logic outside the narrow load-compatibility path unless required by the fix.
- Do not change Nose-session behavior.

3. Current-state summary
- `BB_App.loadGuiInputAsStruct()` constructs `BehaviorBoxData("Inv",Invest,"Inp",Inp,"Sub",Sub,find=1)`.
- `BehaviorBoxData.loadFiles()` reads all matching `.mat` files through `fileDatastore(..., "ReadFcn", @readFcn)`.
- `fcns/readFcn.m` normalizes `newData` fields by trimming any field with `numel > total`, assuming one-dimensional vector-like indexing.
- Wheel sessions saved after commit `be34e53` add `newData.WheelDisplayRecord` and `newData.FrameAlignedRecord` as MATLAB tables, and one-subscript table indexing now throws inside `readFcn`.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/fcns/readFcn.m`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`
- Possibly `/home/wbs/Desktop/BehaviorBox/BehaviorBoxData.m` only if the narrow `readFcn` fix is insufficient

5. Validation commands
- Reproduction:
  `matlab -batch "run('startup.m'); cd('/home/wbs/Desktop/BehaviorBox'); BBData = BehaviorBoxData('Inv','Will','Inp','Wheel','Sub',{'3421911'},'find',1,'analyze',0);"`
- MATLAB lint:
  `matlab -batch "run('startup.m'); cd('/home/wbs/Desktop/BehaviorBox'); checkcode('fcns/readFcn.m');"`
- Focused post-fix smoke check:
  `matlab -batch "run('startup.m'); cd('/home/wbs/Desktop/BehaviorBox'); BBData = BehaviorBoxData('Inv','Will','Inp','Wheel','Sub',{'3421911'},'find',1,'analyze',0); disp(size(BBData.loadedData));"`

6. Milestones
- Reproduce the failure on real wheel data through the same `BehaviorBoxData` entrypoint the GUI uses.
- Inspect one affected saved file to confirm the new table fields and their shape.
- Patch the narrow load-normalization path so additive table fields are preserved or skipped safely.
- Run MATLAB lint and rerun the reproduction command to confirm the loader works.

7. Risks and stop conditions
- Stop if the failure is not limited to table-field normalization and instead reflects broader schema drift in downstream analysis.
- Stop if the fix would require silently discarding additive saved fields without documenting that compatibility tradeoff.
- Stop if MATLAB reveals a second incompatible field type after table handling is fixed.

8. Handoff notes
- Expected invariant behavior: subject lookup, file discovery, and legacy analysis outputs should continue to work on preexisting files.
- Allowed behavior change: additive wheel-table fields remain present in loaded `newData` without being vector-cropped.
- Report exact validation commands, whether `WheelDisplayRecord` and `FrameAlignedRecord` remain accessible after load, and any remaining downstream risks.

## 2026-03-27 Preserve Partial Wheel Trials And Clarify Save Status

1. Goal
- Fix `BehaviorBoxWheel` so active Time-Arduino trial segments are preserved on stop/cleanup.
- Prevent cleanup segments from being mislabeled as the next trial number.
- Save explicit committed vs in-progress status for additive wheel/timestamp outputs without removing partial-trial data.

2. Non-goals
- Do not remove partial trials from `WheelDisplayRecord` or `TimestampRecord`.
- Do not change Nose behavior in this pass.
- Do not redefine the meaning of legacy committed-trial arrays such as `Score`, `Level`, or `CodedChoice`.

3. Current-state summary
- `DoLoop()` increments `this.i` before checking the stop button.
- `AfterTrial()` commits the behavioral row through `UpdateData()`, then later stores the Time-Arduino segment.
- `cleanUP()` currently starts a `cleanup` segment using the current `this.i`, which can already be the next trial number.
- Saved March 26 wheel files show `WheelDisplayRecord` and/or `TimestampRecord` ahead of the committed behavioral arrays, and `cleanup` can appear as the max trial number.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint:
  `matlab -batch "run('startup.m'); cd('/home/wbs/Desktop/BehaviorBox'); checkcode('BehaviorBoxWheel.m');"`
- Focused saved-file review helper after implementation:
  inspect March 26 wheel files to confirm the intended save-status annotations and that no frame rows are present.

6. Milestones
- Preserve any active Time segment before cleanup resets the logger.
- Make cleanup session-level rather than using the next trial number.
- Add additive save metadata that explicitly marks `WheelDisplayRecord` rows and `TimestampRecord` segments as `committed`, `in_progress`, or `session`.
- Keep legacy committed-trial arrays scoped to committed trials only.

7. Risks and stop conditions
- Stop if the status-annotation change would force loader changes outside the wheel path in this pass.
- Stop if preserving the active trial segment would duplicate already-stored trial segments on a normal clean end.
- Stop if the save-status annotations require removing or renaming existing fields instead of adding new ones.

8. Handoff notes
- Call out the new additive save metadata fields and status labels explicitly.
- Report that old March 26 files remain unchanged; only future saves receive the clearer status annotations.

## 2026-03-27 Clarify usbcamv4l Linux-Only Support And GPU Targets

1. Goal
- Make repo instructions explicit that `usbcamv4l` is Linux-only.
- Make the `usbcamv4l` build/runtime surface that Linux-only constraint directly.
- Document that `usbcamv4l` is expected to run on Linux systems with Intel integrated graphics, AMD GPUs, and NVIDIA GPUs.

2. Non-goals
- Do not add macOS or Windows support for `usbcamv4l`.
- Do not change camera capture, rendering, decode, or recording behavior in this pass.
- Do not widen the GPU backend matrix beyond clarifying the existing Intel/AMD/NVIDIA intent.

3. Current-state summary
- Repo-level instructions now describe the overall repo as Linux-first, but they do not yet state that `usbcamv4l` itself is Linux-only.
- `usbcamv4l` already depends on Linux/X11/V4L2/DRM/EGL/GLES facilities in `main.cpp` and `CMakeLists.txt`.
- `usbcamv4l/README.md` already references Intel, AMD, and NVIDIA GPU paths, but the Linux-only constraint is implicit rather than enforced at configure time.
- `print_usbcamv4l_help()` does not currently mention Linux-only support or the intended GPU families.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/AGENTS.md`
- `/home/wbs/Desktop/BehaviorBox/usbcamv4l/CMakeLists.txt`
- `/home/wbs/Desktop/BehaviorBox/usbcamv4l/README.md`
- `/home/wbs/Desktop/BehaviorBox/usbcamv4l/main.cpp`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Configure:
  `cmake -S /home/wbs/Desktop/BehaviorBox/usbcamv4l -B /tmp/usbcamv4l-build -DCMAKE_BUILD_TYPE=Release`
- Build:
  `cmake --build /tmp/usbcamv4l-build -j`
- Help smoke check:
  `/tmp/usbcamv4l-build/usbcamv4l --help`

6. Milestones
- Add the ExecPlan entry before multi-file edits.
- Update repo instructions for Linux-first validation and Linux-only `usbcamv4l` expectations.
- Add a configure-time Linux-only guard and clarify runtime/help text.
- Run focused Linux configure/build/help validation.

7. Risks and stop conditions
- Stop if the existing `usbcamv4l` build no longer configures cleanly on Linux after the Linux-only guard is added.
- Stop if clarifying GPU support would require changing backend-selection logic rather than documentation/enforcement.
- Stop if validation reveals platform assumptions beyond Linux/X11/V4L2 that need separate design work.

8. Handoff notes
- Report that `usbcamv4l` remains Linux-only by design.
- Call out that Intel iGPU, AMD GPU, and NVIDIA GPU support is an intended Linux target matrix, not a promise of identical backend behavior across all drivers.
- Include exact validation commands and note any GPU-specific behavior that remains unverified on the current machine.

## 2026-03-27 Save MockApp Harness And Debugging Guidance

1. Goal
- Save the temporary headless mock app and mock hardware classes into a reusable repo folder.
- Document how to use that harness for future wheel save/load debugging.
- Record concrete debugging-improvement ideas in `Next Steps, ChatGPT/`.

2. Non-goals
- Do not refactor the production `BehaviorBox*.m` classes in this pass.
- Do not change runtime GUI or hardware behavior.
- Do not add broad path setup changes in `startup.m`.

3. Current-state summary
- A temporary mock harness under `/tmp` was sufficient to exercise `BehaviorBoxWheel.cleanUP()` and `BehaviorBoxWheel.SaveAllData()` in `matlab -batch` without live GUI or Arduino hardware.
- The repo does not yet have a persistent `MockApp/` folder or instructions pointing contributors to that workflow.
- `AGENTS.md` already has MATLAB validation guidance, but it does not mention the new mock harness.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/MockApp/MockControl.m`
- `/home/wbs/Desktop/BehaviorBox/MockApp/MockArduino.m`
- `/home/wbs/Desktop/BehaviorBox/MockApp/MockTime.m`
- `/home/wbs/Desktop/BehaviorBox/MockApp/MockApp.m`
- `/home/wbs/Desktop/BehaviorBox/MockApp/testBehaviorBoxWheelSaveStatus.m`
- `/home/wbs/Desktop/BehaviorBox/MockApp/README.md`
- `/home/wbs/Desktop/BehaviorBox/AGENTS.md`
- `/home/wbs/Desktop/BehaviorBox/Next Steps, ChatGPT/BehaviorBox_Debugging_Improvements.md`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint:
  `matlab -batch "run('startup.m'); cd('/home/wbs/Desktop/BehaviorBox'); checkcode('MockApp/MockControl.m'); checkcode('MockApp/MockArduino.m'); checkcode('MockApp/MockTime.m'); checkcode('MockApp/MockApp.m');"`
- Headless mock-harness smoke test:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"`

6. Milestones
- Save the mock classes and smoke script into `MockApp/`.
- Add local usage instructions in `MockApp/README.md`.
- Update repo instructions to point at `MockApp/` for headless wheel debugging when GUI/hardware are blockers.
- Write the broader debugging-improvement recommendations into `Next Steps, ChatGPT/BehaviorBox_Debugging_Improvements.md`.

7. Risks and stop conditions
- Stop if the mock harness requires path hacks broader than adding `MockApp/` explicitly inside the smoke script.
- Stop if moving the temp mock files into the repo changes the behavior of existing MATLAB name resolution.
- Stop if the smoke script no longer runs in `matlab -batch` from repo root after relocation.

8. Handoff notes
- Call out that `MockApp/` is for headless debugging only and is not used by production app workflows.
- Report the exact `matlab -batch` command for the smoke script.
- Note any remaining gaps where live hardware validation is still required.

## 2026-03-27 Add Saved-File Debug Helper And BehaviorBoxData Loader Smoke Test

1. Goal
- Add a reusable MATLAB helper that summarizes the integrity of a saved wheel `.mat` file.
- Add a reproducible headless `BehaviorBoxData` loader smoke test that exercises the GUI-equivalent load path and prints a clear success token.

2. Non-goals
- Do not change production acquisition, analysis, or save behavior in this pass.
- Do not refactor `BehaviorBoxData.m` or `BehaviorBoxWheel.m` unless validation reveals a real bug.
- Do not add global path setup changes in `startup.m`.

3. Current-state summary
- `MockApp/testBehaviorBoxWheelSaveStatus.m` now provides a headless wheel save-path smoke test.
- There is not yet a reusable helper for inspecting saved wheel files directly.
- There is not yet a reusable headless smoke script for the `BehaviorBoxData` loader path that the GUI uses.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/fcns/bb_debug_saved_file.m`
- `/home/wbs/Desktop/BehaviorBox/fcns/testBehaviorBoxDataLoad.m`
- `/home/wbs/Desktop/BehaviorBox/AGENTS.md`
- `/home/wbs/Desktop/BehaviorBox/MockApp/README.md`
- `/home/wbs/Desktop/BehaviorBox/Next Steps, ChatGPT/BehaviorBox_Debugging_Improvements.md`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint:
  `matlab -batch "run('startup.m'); cd('/home/wbs/Desktop/BehaviorBox'); checkcode('fcns/bb_debug_saved_file.m'); checkcode('fcns/testBehaviorBoxDataLoad.m');"`
- Loader smoke test:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"`

6. Milestones
- Add `bb_debug_saved_file.m` under `fcns/`.
- Add `testBehaviorBoxDataLoad.m` under `fcns/`.
- Update repo instructions to mention the loader smoke test.
- Run MATLAB lint and the new loader smoke test.

7. Risks and stop conditions
- Stop if the loader smoke script needs machine-specific path assumptions beyond `GetFilePath("Data")` and documented local overrides.
- Stop if the saved-file helper reveals a new loader or schema bug in the current repo that should be fixed before landing the test.
- Stop if the new smoke script depends on mutating real saved data rather than read-only inspection.

8. Handoff notes
- Report the default subject/config used by the loader smoke test and any override mechanism.
- Call out that the smoke script is still a data-availability-dependent validation, not a pure unit test.
