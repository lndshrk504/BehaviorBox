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
