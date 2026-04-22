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

## 2026-04-21 Fix Mapping Loom Stimulus Controls

1. Goal
- Make `Map-LoomingStimulus` use the intended GUI controls and stimulus semantics.
- Use `Animate_Level` for loom level, use `Map_LoomX` / `Map_LoomY` for loom position, and render the looming stimulus from the same correct/incorrect stimulus-construction path used by `Map-FlashContourX`.

2. Non-goals
- Do not change flash or sweep behavior, save schemas, Arduino timing, or GUI layout.
- Do not add new mapping modes or new GUI fields.

3. Current-state summary
- `BehaviorBoxWheel.buildMappingOptions_()` currently takes loom level from `Starting_opacity_Temp` and loom position from the generic animate X/Y sliders, even though the GUI exposes dedicated loom X/Y fields and animate-level control.
- `BehaviorBoxVisualStimulus.setupMappingScene()` currently renders loom mode with the simplified `buildContourPolyline_()` / `buildRandomSegmentsPolyline_()` placeholders instead of the newer correct/incorrect stimulus generator used for flash mode.
- The result is that loom can appear nonfunctional or semantically wrong: the visible change may be only a subtle single-segment scale pulse, and loom-specific GUI controls do not fully drive the display.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxVisualStimulus.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Static checks:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxVisualStimulus.m');"`
- Focused loom smoke:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); obj=BehaviorBoxVisualStimulus(struct(),Preview=1); obj=obj.updateProps(struct()); [fig,~,~,~,~]=obj.setUpFigure(); t=obj.setupMappingScene('Map-LoomingStimulus','LoomVariant','Correct','LoomLevel',10,'InitialVisible',true); disp([numel(t.MapContourLine.XData) numel(t.MapRandomLine.XData)]); close(fig);"`

6. Milestones
- Patch loom option sourcing in `BehaviorBoxWheel.buildMappingOptions_()`.
- Patch loom stimulus construction in `BehaviorBoxVisualStimulus.setupMappingScene()` so correct and incorrect looming variants use the mapping stimulus polyline builder.
- Run narrow MATLAB validation and inspect the diff.

7. Risks and stop conditions
- Stop if the intended loom behavior requires a saved-output schema change or a new GUI control.
- Stop if the newer mapping stimulus builder cannot safely represent loom incorrect stimuli without breaking flash mode semantics.

8. Handoff notes
- Expected invariants: mapping log schema, acquisition/timestamp handling, flash behavior, sweep behavior, and non-mapping animation paths.
- Intentional visual behavior change: loom should now visibly reflect `Animate_Level`, `Animate_Correct` / `Animate_Incorrect`, and dedicated loom X/Y controls.

## 2026-04-21 Wheel Eye/Frame Aligned Save Outputs

1. Goal
- Implement the mapping-save plan for `Map-FlashContourX` and `Map-SweepLine` so animate saves retain raw `EyeTrackingRecord`, raw `MapLog`, raw `TimestampRecord`, and derive two aligned tables:
  - `FrameAlignedRecord`
  - `EyeAlignedRecord`
- Extend the Wheel training save path so training saves also derive and save `EyeAlignedRecord` when eye samples exist.
- Reuse the existing training drain-all eye path rather than introducing a mapping-specific receive mechanism.
- Keep the exact DeepLabCut sample schema for the current bundled YangLab 8-point pupil model inside `EyeAlignedRecord`.

2. Non-goals
- Do not change the raw `EyeTrackingRecord` schema, raw `MapLog` schema, raw `TimestampRecord` segment schema, GUI layout, or DeepLabCut Python payload contract.
- Do not alter reward logic, Arduino protocols, or non-mapping animation behavior.

3. Current-state summary
- `RunMappingStimulus()` already records raw mapping events into `MappingAnimationLog`, stores timestamp segments in `timestamps_record`, and `SaveAllData(Activity="Animate")` already saves raw `EyeTrackingRecord` and `EyeTrackingMeta`.
- The animate save branch currently mutates `MapLog` with `alignMappingRowsWithEyeTrack_()`, which adds frame-backed eye summary columns onto the raw mapping event table instead of producing separate derived tables.
- There is currently no mapping `FrameAlignedRecord`.
- There is currently no eye-sample-backed `EyeAlignedRecord`.
- The training save branch already saves `EyeTrackingRecord`, `EyeTrackingMeta`, `WheelDisplayRecord`, and `FrameAlignedRecord`, but does not yet derive a training `EyeAlignedRecord`.
- The existing training eye path already uses `BehaviorBoxEyeTrack.pollAvailable()` / `finalDrain()` drain-all semantics and should be reused unchanged.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/MockApp/testBehaviorBoxWheelSaveStatus.m`
- `/Users/willsnyder/Desktop/BehaviorBox/MockApp/testBehaviorBoxWheelMappingSave.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Static checks:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxWheel.m'); checkcode('MockApp/testBehaviorBoxWheelSaveStatus.m'); checkcode('MockApp/testBehaviorBoxWheelMappingSave.m');"`
- Focused mapping save smoke:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelMappingSave.m');"`
- Existing save-regression smoke:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxWheel.m MockApp/testBehaviorBoxWheelSaveStatus.m MockApp/testBehaviorBoxWheelMappingSave.m .agent/PLANS.md`

6. Milestones
- Stop mutating raw `MapLog` during animate save and instead derive dedicated mapping `FrameAlignedRecord` and `EyeAlignedRecord`.
- Implement mapping alignment helpers in `BehaviorBoxWheel.m` using raw `TimestampRecord`, raw `MapLog`, and raw `EyeTrackingRecord`.
- Implement a training `EyeAlignedRecord` builder in `BehaviorBoxWheel.m` using raw `EyeTrackingRecord`, `WheelDisplayRecord`, and `TimestampRecord`.
- Add focused mock coverage for mapping animate saves, including exact `EyeAlignedRecord` DLC point columns and microscope back-reference columns.
- Extend Wheel save smoke coverage so training saves assert `EyeAlignedRecord` presence when eye samples exist.
- Re-run focused MATLAB validation and inspect the saved-file schema.

7. Risks and stop conditions
- Stop if timestamp parsed rows do not expose a stable frame schema (`frame`, `t_us`, `t_arduino_us`, `t_pc_receive_us`) needed for the microscope-backed table.
- Stop if the mapping save path would need to change `EyeTrackingRecord`, `MapLog`, or `TimestampRecord` raw schemas rather than only adding derived tables.
- Stop if the implementation reveals a mismatch between the documented `EyeAlignedRecord` schema and the active YangLab 8-point DLC sample schema.

8. Handoff notes
- Expected invariants: raw eye record columns, raw map-log columns, raw timestamp-segment content, training-frame alignment behavior, and drain-all eye capture semantics.
- Intentional saved-schema changes: animate mapping `.mat` files will gain derived `FrameAlignedRecord` and `EyeAlignedRecord`, `MapLog` will remain the raw event table instead of an eye-augmented convenience table, Wheel training saves will also gain derived `EyeAlignedRecord` when eye samples exist, and Wheel training saves will omit `FrameAlignedRecord` when no frame-backed rows were derived.
- Intentional visual-behavior updates after rollout: `Map-FlashContourX` preview and runtime flash size now match the standard preview stimulus size, and `Map-FlashContourX` vertical placement follows `Animate_YPosition`.

## 2026-04-16 Production DLC Eye Tracking Framework

1. Goal
- Implement the production DeepLabCut Live -> ZeroMQ -> MATLAB eye-tracking framework specified in `Next Steps/DLC_EyeTracking_MATLAB_Framework_Contract.md`.
- Preserve every post-DLC output sample in MATLAB, timestamp samples in the BehaviorBox session clock, save a dense `EyeTrackingRecord`, and derive eye columns for `FrameAlignedRecord` and `WheelDisplayRecord`.
- Keep FLIR pre-DLC frame dropping allowed, but detect and report any missing post-DLC `frame_id` in MATLAB.

2. Non-goals
- Do not change model training, DLC point order, reward logic, Nose workflows, Arduino protocols, GUI layout, or legacy iRecHS2 code.
- Do not make the optional `interval_summary` alignment canonical; implement it for comparison while keeping `previous` as the default.
- Do not remove the Python CSV sidecar during rollout.

3. Current-state summary
- `dlc_eye_streamer.py` publishes one JSON sample per DLC output and writes a CSV, but lacks `message_type`, schema metadata, startup metadata, coordinate-frame metadata, and sufficient send buffering.
- `matlab_zmq_bridge.py` exposes latest-only receive helpers and discards queued messages by design.
- `BehaviorBoxEyeTrack.m` currently receives only the latest JSON message, appends rows directly to a MATLAB table, still has the `RVupil` typo, and does not implement readiness, stale detection, frame-ID continuity, chunked storage, or final drain semantics.
- `BehaviorBoxWheel.m` creates and saves `BehaviorBoxEyeTrack`, but eye columns in derived records are placeholders and no dense-eye alignment helper is wired into save/frame records.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/ToMatlab/dlc_eye_streamer.py`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/ToMatlab/matlab_zmq_bridge.py`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxEyeTrack.m`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/home/wbs/Desktop/BehaviorBox/fcns/testBehaviorBoxEyeTrack.m`
- `/home/wbs/Desktop/BehaviorBox/MockApp/testBehaviorBoxWheelSaveStatus.m`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Python static checks:
  `/home/wbs/miniforge3/envs/dlclivegui/bin/python -m py_compile dlc_eye_streamer.py matlab_zmq_bridge.py`
- MATLAB static checks:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); checkcode('BehaviorBoxEyeTrack.m'); checkcode('BehaviorBoxWheel.m'); checkcode('fcns/testBehaviorBoxEyeTrack.m'); checkcode('MockApp/testBehaviorBoxWheelSaveStatus.m');"`
- MATLAB focused receiver test:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxEyeTrack.m');"`
- MATLAB save/integration smoke:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxEyeTrack.m BehaviorBoxWheel.m fcns/testBehaviorBoxEyeTrack.m MockApp/testBehaviorBoxWheelSaveStatus.m EyeTrack/DeepLabCut/ToMatlab/dlc_eye_streamer.py EyeTrack/DeepLabCut/ToMatlab/matlab_zmq_bridge.py`

6. Milestones
- Update Python payload, CSV metadata, schema/message types, and coordinate-frame handling.
- Add all-queued-message receive support in the MATLAB bridge.
- Rework `BehaviorBoxEyeTrack` around drain-all receive, readiness, stale detection, frame-ID continuity, chunked column storage, final drain, and final record assembly.
- Add a shared eye-alignment helper with `previous` and optional `interval_summary` modes.
- Wire final drain/save and derived joins into `BehaviorBoxWheel`.
- Update focused tests and run Python/MATLAB validation.

7. Risks and stop conditions
- Stop if MATLAB and Python disagree on JSON field names, timestamp types, point names, point shapes, or coordinate-frame semantics.
- Stop if a lossless post-DLC transport cannot be verified without changing the contract from PUB/SUB to PUSH/PULL.
- Stop if frame-aligned or display-record schema changes would break current save tests without explicit test updates documenting the new schema.

8. Handoff notes
- Intentional saved-schema changes: `EyeTrackingRecord` columns are renamed and expanded; `FrameAlignedRecord` and saved `WheelDisplayRecord` receive derived eye columns; `EyeTrackingMeta` gains readiness, stale, CSV, model, camera, and continuity metadata.
- Expected invariants: behavior training proceeds if eye tracking is absent, FLIR frames may be dropped before DLC, DLC point order remains YangLab pupil8, and `previous` alignment remains default.
- Implementation status: completed on 2026-04-16. `BehaviorBoxEyeTrack` now drains all queued samples, records point columns directly, applies readiness/stale/final-drain handling, and exposes `previous` plus `interval_summary` alignment. `BehaviorBoxWheel` now marks trial 0 during setup, increments eye-trial assignment at hold-still start, drains final samples as `trial = NaN`, and saves eye-derived columns into frame/display records.

## 2026-04-16 Reuse Stimulus On Repeat Wrong

1. Goal
- In `BehaviorBoxNose.m` and `BehaviorBoxWheel.m`, keep the exact previous visual stimulus when repeat-wrong repeats the previous correct side after an incorrect response.
- Preserve current side-repetition behavior, reward behavior, trial numbering, and saved field names.
- Store the repeated trial's `StimHistory` row as a copy of the previous row instead of sampling fresh distractors.

2. Non-goals
- Do not change GUI controls, `Repeat_wrong` setting names, scoring codes, reward timing, Arduino protocols, wheel imaging metadata, or saved `.mat` schema.
- Do not change behavior for correct trials, timeout trials, forced left/right modes, or random trials when repeat-wrong is not triggered by a wrong response.

3. Current-state summary
- `DoLoop()` calls `BeforeTrial()` in both workflow classes before waiting for input.
- `BeforeTrial()` calls `PickSideForCorrect()` and then always calls `BehaviorBoxVisualStimulus.DisplayOnScreen(...)`.
- `PickSideForCorrect()` repeats the previous side after wrong trials when `StimulusStruct.side == 5`, or when `Setting_Struct.Repeat_wrong` is enabled in random/other modes.
- `DisplayOnScreen()` deletes existing contour/distractor handles and calls stimulus generators such as `ShowStimulusContour_Density()`, whose distractor selection uses `randperm`/`randi`; therefore the current behavior repeats the side but redraws a new stimulus.
- No relevant `+pkg`, `@Class`, or `private/` dispatch path was found. `startup.m` is minimal.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxNose.m`
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/fcns/testPickSideForCorrect.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Static checks:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('fcns/testPickSideForCorrect.m');"`
- Focused side/repeat smoke:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testPickSideForCorrect.m');"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m BehaviorBoxWheel.m fcns/testPickSideForCorrect.m .agent/PLANS.md`

6. Milestones
- Add a shared-style helper in Nose and Wheel that detects when repeat-wrong is active because the last scored trial was wrong.
- Patch both `BeforeTrial()` methods to copy the previous `StimHistory` row and leave existing figure handles intact when that helper is true.
- Extend focused MATLAB smoke coverage for repeat-wrong stimulus reuse gating.
- Run validation and inspect the final diff.

7. Risks and stop conditions
- Stop if exact stimulus reuse requires saved schema changes or a new GUI setting.
- Stop if the repeat-wrong trigger cannot be distinguished from ordinary forced-side or random behavior.

8. Handoff notes
- Expected invariant outputs: saved field names, scoring codes, `isLeftTrial`, reward/punishment behavior, timing settings, Arduino messages, and wheel imaging fields.
- Intentional output change: repeated wrong trials save duplicated `StimHist` rows for the repeated stimulus instead of newly randomized L/R stimulus matrices.
- Reproducibility control: no RNG seed changes; repeat-wrong trials consume fewer random numbers because they skip stimulus redraw.

## 2026-04-16 Add Wheel ConfirmChoice Gradient

1. Goal
- Add a Wheel-specific `ConfirmChoice` visual cue in `BehaviorBoxWheel.readLeverLoopAnalogWheel`.
- During Wheel response and OnlyCorrect correction, brighten the correct contour from `StimulusStruct.LineColor` toward `StimulusStruct.FlashColor` as wheel displacement moves the correct stimulus toward center.
- Gate the cue only on `Setting_Struct.ConfirmChoice`; do not require `StimulusStruct.FlashStim`.
- During stall blink, temporarily dim as before, then restore the contour to the current gradient color.

2. Non-goals
- Do not change Nose behavior, reward logic, wheel choice thresholds, Arduino protocol, GUI controls, saved field names, or directory layout.
- Do not require `StimulusStruct.FlashStim` for the new Wheel gradient.
- Do not change non-Wheel keyboard response behavior.

3. Current-state summary
- `WaitForInputAndGiveReward()` calls `readLeverLoopAnalogWheel()` for non-keyboard Wheel input.
- `readLeverLoopAnalogWheel()` computes signed `delta`, moves the stimulus, handles stall blink, records `CurrentStimColor`, and decides left/right choices.
- Positive `delta` is accepted as a left choice; negative `delta` is accepted as a right choice.
- `BehaviorBoxVisualStimulus.chooseDistractors()` tags the correct contour with `Tag='Contour'`, so the Wheel cue can target those handles defensively.
- `BehaviorBoxWheel.m` and `BehaviorBoxVisualStimulus.m` are root-level classdefs. No relevant `+pkg`, `@Class`, or `private/` dispatch path was found. `startup.m` is minimal.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/MockApp/MockArduino.m`
- `/Users/willsnyder/Desktop/BehaviorBox/MockApp/testBehaviorBoxWheelConfirmChoiceGradient.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Static checks:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxWheel.m'); checkcode('MockApp/MockArduino.m'); checkcode('MockApp/testBehaviorBoxWheelConfirmChoiceGradient.m');"`
- Focused gradient helper test:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelConfirmChoiceGradient.m');"`
- Existing Wheel save/display smoke:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxWheel.m MockApp/MockArduino.m MockApp/testBehaviorBoxWheelConfirmChoiceGradient.m .agent/PLANS.md`

6. Milestones
- Add small helper methods for `ConfirmChoice` gating, correct-direction progress, color interpolation, and safe line color setting.
- Patch Wheel response and OnlyCorrect loops so contour color follows current correct-choice progress and stall blink restores that color.
- Add a focused MATLAB smoke test with a scripted mock wheel encoder for left/right progress, wrong-direction baseline behavior, color interpolation, and `ConfirmChoice` gating.
- Run focused MATLAB validation and inspect the final diff.

7. Risks and stop conditions
- Stop if the change requires saved `.mat` schema changes or a new GUI setting.
- Stop if the Wheel delta sign convention cannot be confirmed from the existing choice logic.
- Stop if a non-contour stimulus path would be affected in a way that cannot be guarded by missing-handle checks.

8. Handoff notes
- Expected invariant outputs: saved field names, choice decisions, wheel thresholds, reward behavior, Arduino messages, and Nose behavior.
- Intentional behavior changes: Wheel contour brightness varies during response when `ConfirmChoice` is enabled; saved `WheelDisplayRecord.StimColor` and frame-aligned `StimColor` can vary with the displayed gradient.

## 2026-04-16 Cap Random Same-Side Correct Streaks

1. Goal
- Add `Same_Side_Max` handling to `PickSideForCorrect` in `BehaviorBoxNose.m` and `BehaviorBoxWheel.m`.
- In random side mode (`StimulusStruct.side == 1`), prevent a newly randomized side from extending a trailing same-correct-side streak beyond `Same_Side_Max`.
- Preserve repeat-wrong precedence when the previous trial was wrong.

2. Non-goals
- Do not change GUI layout, saved field names, scoring codes, reward timing, Arduino protocols, forced-side modes, keyboard/manual mode, or explicit repeat-wrong mode.
- Do not refactor shared Nose/Wheel code beyond the minimal duplicated helper logic already present in these classes.

3. Current-state summary
- `BeforeTrial()` calls `PickSideForCorrect()` in both root-level MATLAB classdefs before stimulus display.
- `BehaviorBoxData.AddData()` stores `Score` and `isLeftTrial` in `current_data_struct`, which is the history source for this cap.
- `PickSideForCorrect()` already uses `lastScoreWasWrong_()` to decide whether repeat-wrong should preserve the previous correct side.
- No relevant `+pkg`, `@Class`, or `private/` dispatch path was found. `startup.m` is minimal.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxNose.m`
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/fcns/testPickSideForCorrect.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Static checks:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('fcns/testPickSideForCorrect.m');"`
- Focused smoke test:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testPickSideForCorrect.m');"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m BehaviorBoxWheel.m fcns/testPickSideForCorrect.m .agent/PLANS.md`

6. Milestones
- Patch random side selection in Nose and Wheel with a `Same_Side_Max` helper that counts trailing trials where `Score == 1` and `isLeftTrial` matches.
- Keep repeat-wrong preservation for previous wrong trials ahead of the new cap.
- Add deterministic focused tests for left and right streak caps, below-threshold behavior, and repeat-wrong precedence.
- Run MATLAB validation and inspect the final diff.

7. Risks and stop conditions
- Stop if implementing the cap requires changing saved `.mat` schema or historical data conversion.
- Stop if the current data history lacks `Score` or `isLeftTrial` in live runtime paths.

8. Handoff notes
- Expected invariant outputs: saved field names, `CodedChoice` mappings, forced-side behavior, explicit repeat-wrong behavior after wrong trials, reward behavior, and GUI setting names.
- Intentional behavior change: in random mode only, future saved `isLeftTrial` sequences can differ from raw RNG when the proposed random side would extend a trailing same-side correct streak beyond `Same_Side_Max`.

## 2026-04-15 Add Nose Reward Hold Gate

1. Goal
- In `BehaviorBoxNose.GiveRewardAndFlash`, keep the first correct reward pulse behavior and require each later nose reward pulse to wait `Box.SecBwPulse` and then a continuous correct-side hold for `Input_Delay_Respond`.
- Blink contour stimulus during the qualifying hold and keep distractors dim during reward waits.
- Add focused MATLAB smoke coverage for the hold gate.

2. Non-goals
- Do not change Wheel reward behavior, GUI settings, saved field names, Arduino serial commands, pin maps, or reward durations.
- Do not alter trial-choice qualification in `readLeverLoopDigitalCore`.

3. Current-state summary
- `WaitForInputAndGiveReward()` calls `processDecision()`, then correct and OnlyCorrect paths call `GiveRewardAndFlash()`.
- `readLeverLoopDigitalCore()` already gates the initial side choice with `Input_Delay_Respond` and blinks contours during confirmed correct holds.
- `GiveRewardAndFlash()` currently waits for the reward-side sensor before pulse 1, but later pulses only do `pause(this.Box.SecBwPulse)` and a current-sensor check without a continuous hold requirement.
- `BehaviorBoxNose.m` is a root-level classdef. No relevant `+pkg`, `@Class`, or `private/` dispatch path is involved, and `startup.m` is minimal.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxNose.m`
- `/Users/willsnyder/Desktop/BehaviorBox/MockApp/MockArduino.m`
- `/Users/willsnyder/Desktop/BehaviorBox/fcns/testBehaviorBoxNoseRewardHold.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Focused smoke test:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxNoseRewardHold.m');"`
- Static check:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('MockApp/MockArduino.m'); checkcode('fcns/testBehaviorBoxNoseRewardHold.m');"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m MockApp/MockArduino.m fcns/testBehaviorBoxNoseRewardHold.m`

6. Milestones
- Patch the Nose reward wait helper to support immediate and continuous-hold modes.
- Route later Nose reward pulses through the continuous-hold mode after `SecBwPulse`.
- Add or extend mock support for scripted nose tokens and reward-call assertions.
- Run focused MATLAB validation and inspect the final diff.

7. Risks and stop conditions
- Stop if the change requires new GUI settings or Arduino protocol changes.
- Stop if a reliable smoke test requires real hardware rather than a mockable token sequence.

8. Handoff notes
- Expected invariant outputs: saved field names, scoring codes, serial reward commands, reward durations, and Wheel behavior.
- Intentional behavior change: later Nose reward pulses can be delayed until the correct port is held continuously; saved `RewardPulses` and `DrinkTime` may change for sessions where the animal releases or switches ports between pulses.

## 2026-04-15 Normalize OnlyCorrect Reward Semantics

1. Goal
- Make Nose and Wheel OnlyCorrect trials detect `OC` before generic `correct`.
- Use `Box_OCPulse`/`this.Box.OCPulse` for OC reward delivery.
- Preserve saved `WhatDecision` labels as `left correct OC` / `right correct OC`.
- Increment `RewardPulses` where reward/air-puff pulses are actually delivered.

2. Non-goals
- Do not change serial command strings, valve pulse durations, input polling thresholds, side-picking logic, saved field names, or the broader trial loop.
- Do not refactor shared Nose/Wheel code beyond the requested semantic fix.

3. Current-state summary
- `BehaviorBoxNose.DoLoop()` calls `WaitForInputAndGiveReward()`, which calls `processDecision()` and then `GiveRewardAndFlash()`.
- `BehaviorBoxWheel.DoLoop()` calls `WaitForInputAndGiveReward()`, which calls `handleOnlyCorrectMode()`, `processAfterDecision()`, and then `GiveRewardAndFlash()` for correct decisions.
- Both classes save `RewardPulses` through `UpdateData()` into `BehaviorBoxData.AddData()`, but reward delivery currently does not increment that counter.
- Both classes are root-level MATLAB classdefs. No relevant `+pkg`, `@Class`, or `private/` dispatch path was found; `startup.m` is minimal.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxNose.m`
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Static checks:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m');"`
- Targeted semantic smoke:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); assert(convertEnum('left correct OC') == 4); assert(convertEnum('right correct OC') == 3);"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m BehaviorBoxWheel.m`

6. Milestones
- Patch Nose OC decision precedence, keep OC labels, and increment `RewardPulses` on each delivered pulse.
- Patch Wheel OC reward pulse selection and increment `RewardPulses` on each delivered pulse.
- Run focused validation and inspect diff.

7. Risks and stop conditions
- Stop if preserving OC labels would require changing `convertEnum` or saved field names.
- Stop if reward pulse accounting requires guessing whether air-puff pulses should be separated from water pulses.

8. Handoff notes
- Expected invariant outputs: saved field names, `convertEnum` mappings, serial reward commands, reward durations, side-picking, and non-OC trial labels.
- Intentional behavior changes: OC trials now use `OCPulse`; saved OC `WhatDecision` remains `left correct OC` / `right correct OC`; `RewardPulses` now records delivered pulses instead of staying at zero.

## 2026-04-15 Fix Nose And Wheel Session Setup Safety

1. Goal
- Fix `SetupBeforeLoop` in `BehaviorBoxNose.m` and `BehaviorBoxWheel.m` so data-object construction cannot silently reuse stale session paths.
- Reset per-session saved buffers at session setup in both classes.
- Remove the unused Wheel external-trigger wait path.
- Set Nose session start time during setup to match Wheel behavior.
- Add a Wheel animation-specific setup path so animation no longer uses full training setup.

2. Non-goals
- Do not change GUI layout, Arduino serial protocols, reward timing, trial scoring, or saved field names.
- Do not refactor the full Nose/Wheel training loop.
- Do not touch `BehaviorBox_App.mlapp` or large generated app artifacts.

3. Current-state summary
- Active runtime path is `BB_App.Start_Callback -> app.BB.RunTrials -> DoLoop -> SetupBeforeLoop`.
- Wheel animation path is `BB_App.Animate_* -> BehaviorBoxWheel.AnimateStimulus -> SetupBeforeLoop` for non-mapping Go/Rec modes.
- `BehaviorBoxNose.m` and `BehaviorBoxWheel.m` are root-level MATLAB classdefs. No `+pkg`, `@Class`, or `private/` dispatch path is involved, and `startup.m` is minimal.
- Setup currently catches `BehaviorBoxData` construction errors silently, resets counters but not saved buffers, and Wheel has an unused external-trigger branch that calls a nonexistent reader.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxNose.m`
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Static checks:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m');"`
- Existing focused side-picking smoke test, because these files already carry side-picking edits in the worktree:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testPickSideForCorrect.m');"`
- Syntax smoke:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); which BehaviorBoxNose; which BehaviorBoxWheel;"`
- Conflict-marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m BehaviorBoxWheel.m BehaviorBoxData.m fcns/testPickSideForCorrect.m`

6. Milestones
- Patch Nose session data construction and reset state.
- Patch Wheel session data construction, reset state, and remove external trigger branch.
- Add Wheel animation setup and route non-mapping animation callers through it.
- Run focused MATLAB/static validation and inspect diff.

7. Risks and stop conditions
- Stop if the fix requires saved `.mat` field renames or non-additive schema migration.
- Stop if Wheel animation requires the full training setup for an undocumented hardware behavior.
- Stop if data-object construction cannot be made fail-fast without masking the original MATLAB error.

8. Handoff notes
- Expected invariant outputs: saved field names, scoring codes, trial randomization semantics, reward behavior, and non-animation training flow.
- Intentional behavior changes: stale buffer rows from a previous session are no longer saved in later sessions; Nose saved timestamps can start at setup rather than first trial initialization; Wheel external trigger checkbox no longer affects training setup; non-mapping Wheel animation uses a lighter animation setup instead of full training setup.

## 2026-04-15 Fix Nose And Wheel PickSideForCorrect

1. Goal
- Fix `PickSideForCorrect` in `BehaviorBoxNose.m` and `BehaviorBoxWheel.m` so forced left/right modes have priority over repeat-wrong logic.
- Replace the broken manual side-bias correction call with a real scalar side-bias helper.
- Add focused MATLAB smoke coverage for Nose and Wheel side-picking rules.

2. Non-goals
- Do not change saved field names, `CodedChoice` mappings, stimulus rendering, reward timing, Arduino protocols, or the broader trial loop.
- Do not refactor shared Nose/Wheel training code beyond the requested side-picking cleanup.

3. Current-state summary
- `BeforeTrial()` calls `PickSideForCorrect()` in both root-level MATLAB classdefs.
- `PickSideForCorrect()` updates `isLeftTrial`, and later display, response handling, and `BehaviorBoxData.AddData()` save that side.
- Wheel can randomize forced left/right trials when `Repeat_wrong` is enabled.
- Manual keyboard side-bias correction calls `this.SideBias(this)`, but `SideBias` is a property, not a callable method.
- No relevant `+pkg`, `@Class`, or `private/` dispatch path was found. `startup.m` is minimal.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxNose.m`
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/fcns/testPickSideForCorrect.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Static checks:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('fcns/testPickSideForCorrect.m');"`
- Focused smoke test:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testPickSideForCorrect.m');"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m BehaviorBoxWheel.m fcns/testPickSideForCorrect.m`

6. Milestones
- Patch deterministic side-picking priority in both classes.
- Add scalar side-bias helper and replace manual `S` branch call in both classes.
- Add focused headless tests for forced-side precedence, repeat-wrong, random-choice output shape, and scalar side-bias helpers.
- Run MATLAB validation and inspect the final diff.

7. Risks and stop conditions
- Stop if the fix requires changing saved `.mat` schema or `CodedChoice` values.
- Stop if side-bias correction semantics cannot be derived from existing saved `CodedChoice` history without guessing.

8. Handoff notes
- Expected invariant outputs: saved field names, scoring codes, reward behavior, GUI setting names, and non-side-picking paths.
- Intentional behavior change: Wheel `Left Only`/`Right Only` remains forced even when `Repeat_wrong` is enabled; manual side-bias correction no longer errors and chooses the opposite side of the current response bias.

## 2026-04-15 Fix Nose And Wheel Temporary Settings Expiry

1. Goal
- Fix temporary settings in `BehaviorBoxNose.m` and `BehaviorBoxWheel.m` so `Correct Resp.` counts correct responses since temporary mode activation, and `Performance` uses `PerfThresh_Temp`.

2. Non-goals
- Do not change GUI layout, hardware pin/protocol behavior, saved-file schema, or unrelated session logic.
- Do not refactor the full training loop.

3. Current-state summary
- Both classes are root-level MATLAB classdefs, not in `+pkg`, `@Class`, or `private/` folders.
- `BeforeTrial()` calls `UpdateSettings()` and then `CheckTemp()`.
- Temporary GUI values are copied into `Temp_Settings` by stripping the `_Temp` suffix, then overlaid onto `Setting_Struct` while active.
- Existing Nose countdown uses total session correct count; existing Wheel countdown decrements every trial before the trial runs; both ignore `PerfThresh_Temp`.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxNose.m`
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/fcns/testTemporarySettings.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB static checks:
  `matlab -batch "checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('fcns/testTemporarySettings.m');"`
- Focused regression:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testTemporarySettings.m');"`

6. Milestones
- Add minimal temp-session baseline state to both workflow classes.
- Fix Nose countdown/performance mode.
- Fix Wheel countdown/performance mode.
- Add a focused headless test for the temp state rules.
- Run MATLAB validation.

7. Risks and stop conditions
- Stop if the fix requires changing saved `.mat` schema instead of runtime-only state.
- Stop if performance metric semantics cannot be derived from existing session data without guessing.

8. Handoff notes
- Expected invariant outputs: GUI component names, saved field names, and non-temp training behavior.
- Intentional behavior change: temporary settings expire based on post-activation correct responses or `PerfThresh_Temp`, not session-wide prior scores or started trials.

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

## 2026-03-30 Unify Wheel And Frame Timestamps On The PC Session Clock

1. Goal
- Replace the mixed MATLAB/Arduino timing model for wheel-frame alignment with one PC-owned session clock.
- Stamp both wheel/screen events and incoming frame-edge lines into the same session-relative time domain so `FrameAlignedRecord` can be built without cross-clock alignment.
- Merge sparse semantic events from `TimestampRecord.parsed` into `FrameAlignedRecord` so reward pulses, `stim_off`, choice, and trial-end timing are preserved alongside per-frame wheel/display state.
- Move trial display-event timestamps onto the actual post-draw visibility transitions for the ready cue, stimulus-on, distractor dim, and stimulus-off points.

2. Non-goals
- Do not remove existing additive saved outputs such as `TimestampRecord`, `WheelDisplayRecord`, or `FrameAlignedRecord`.
- Do not redesign Arduino firmware protocol in this pass; keep Timekeeper as the frame-edge detector and frame counter source.
- Do not broaden the change into BehaviorBoxData load logic, imaging analysis scripts, or unrelated wheel behavior.

3. Current-state summary
- `BehaviorBoxWheel.beginTimeSegment_()` starts a trial-local MATLAB `tic` and logs annotation rows in that time base.
- `BehaviorBoxSerialTime` parses Arduino-emitted frame and stimulus lines that carry Arduino session-relative times.
- `BehaviorBoxWheel.buildCurrentTrialFrameAlignedRecord_()` currently compares those incompatible clocks directly, which breaks screen-event-to-frame alignment.
- The intended new authority is the Ubuntu/MATLAB session clock created once at training start and shared with `BehaviorBoxSerialTime`.
- The revised target is a hybrid frame clock: preserve raw Arduino frame times, preserve PC receive times, and derive the canonical alignment time from Arduino deltas anchored into the shared PC session clock.
- `WheelDisplayRecord` now carries the per-frame-state source for phase, wheel position, and displayed stimulus color, but `FrameAlignedRecord.screenEvent` still only reflects wheel-display event rows and therefore misses richer parsed annotations such as `reward_1`, `reward_2`, `reward_3`, `stim_off`, and `trial_end`.
- Some display-timing annotations are still logged before the corresponding visual change is drawn, most notably `hold_still_start`, and the requested visual milestones (`Screen On`, stimulus visibility, distractor dimming, stimulus-off) are not yet emitted as explicit trial-aligned events.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxSerialTime.m`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); checkcode('BehaviorBoxSerialTime.m'); checkcode('BehaviorBoxWheel.m');"`
- Conflict-marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" /home/wbs/Desktop/BehaviorBox/BehaviorBoxSerialTime.m /home/wbs/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- If MATLAB execution remains unavailable in this environment, report that blocker explicitly and provide the exact commands for local rerun.

6. Milestones
- Add shared session-clock properties and initialization at training start.
- Make `BehaviorBoxSerialTime` preserve three timing fields for hardware rows: raw Arduino time, PC receive time, and canonical session time.
- Route wheel/screen annotation logging onto the same canonical session clock.
- Rebuild `FrameAlignedRecord` using canonical session time while carrying the audit timing fields through the per-frame table.
- Merge relevant parsed annotation/signal events into each frame bin without overwriting the wheel/display state projection.
- Relocate display-event logging to the true post-draw visibility points and emit additive parsed events for `screen_on`, `stimulus_on`, `distractors_dimmed`, and `stimulus_off`.
- Emit additive post-reward flash events on the first drawn frame of each reward-confirmation flash so reward delivery and reward flash remain distinguishable in `FrameAlignedRecord`.
- Preserve pre-trial setup timing by appending additive `trial = 0` setup frame rows when a setup segment contains microscope frames, so `Screen On` can align to actual pre-trial frames.
- Run the narrowest lint/check path available and inspect the final diff for schema drift.

7. Risks and stop conditions
- Stop if the change would silently alter saved `.mat` schema beyond the explicit timing-field behavior change.
- Stop if MATLAB and incoming serial callbacks cannot reliably share the session clock handle.
- Stop if validation shows callback jitter large enough to exceed the microscope frame interval tolerance.

8. Handoff notes
- Expected invariant outputs: trial decisions, reward counts, wheel traces, and existing additive field names.
- Intentionally changed outputs: `TimestampRecord.parsed` and downstream `FrameAlignedRecord` will carry additive audit timing fields and use a canonical hybrid frame time derived from Arduino deltas anchored to the PC session clock.
- Intentionally changed outputs: `FrameAlignedRecord.screenEvent` will include merged parsed event detail such as reward pulses, `stim_off`, choice, and trial-end annotations in addition to existing wheel-display screen events.
- Intentionally changed outputs: `TimestampRecord.parsed` and `FrameAlignedRecord.screenEvent` will gain additive human-readable visual event timing for cue onset, stimulus onset, distractor dimming, and stimulus-off.
- Intentionally changed outputs: `TimestampRecord.parsed` and `FrameAlignedRecord.screenEvent` will gain additive reward-flash timing entries (`Reward Flash N`) after each delivered reward pulse.
- Intentionally changed outputs: `FrameAlignedRecord` may begin with additive `trial = 0`, `phase = "setup"` rows when setup microscope frames are present, allowing `Screen On` to land on real pre-trial frames.
- Report validation commands, any MATLAB execution blocker, and remaining timing-jitter risk.

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

## 2026-03-27 Review BehaviorBox Files For Debuggability

1. Goal
- Review the root `BehaviorBox*.m` files and identify concrete changes that would make future feature work easier to debug.
- Update `Next Steps, ChatGPT/BehaviorBox_Debugging_Improvements.md` so it reflects those file-specific recommendations instead of only generic debugging guidance.

2. Non-goals
- Do not change MATLAB runtime behavior in this pass.
- Do not edit `BehaviorBox*.m` implementation files in this pass.
- Do not broaden into Arduino or Python changes unless a root-file debugging recommendation depends directly on one of those boundaries.

3. Current-state summary
- The root debug note already distinguishes implemented utilities from pending work, but it has not yet been refreshed from a direct pass over all current root `BehaviorBox*.m` files.
- The root MATLAB classes mix GUI state, hardware calls, save/load behavior, analysis hooks, and app wiring.
- `BehaviorBoxWheel.m` and `BehaviorBoxNose.m` are large stateful workflow classes with many `try/catch` blocks and side effects.
- `BehaviorBoxData.m` remains the main load/analysis surface and still contains broad implicit schema assumptions.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxData.m`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxDataNew.m`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxNose.m`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxVisualStimulus.m`
- `/home/wbs/Desktop/BehaviorBox/Next Steps, ChatGPT/BehaviorBox_Debugging_Improvements.md`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Read-only inspection only in this pass:
  `rg -n "classdef|function |catch|try|disp\\(|fprintf\\(|warning\\(|save\\(|load\\(|addpath|uiputfile|questdlg|serial|arduino|scanimage|microscope" BehaviorBox*.m`
- Read back the updated note:
  `nl -ba 'Next Steps, ChatGPT/BehaviorBox_Debugging_Improvements.md'`

6. Milestones
- Map the root `BehaviorBox*.m` files and identify the main debug blockers for future feature work.
- Distill those blockers into concrete recommendations with file-specific rationale.
- Update the debug note so the recommended work reflects the live codebase.

7. Risks and stop conditions
- Stop if a recommendation would require changing saved-file schema or runtime behavior without explicit user approval.
- Stop if the review reveals a MATLAB/Python or hardware boundary mismatch that cannot be described accurately without broader runtime validation.

8. Handoff notes
- Report the highest-value debugability findings first, with file references.
- Call out which recommendations were added to the note and which remain only verbal suggestions if any.

## 2026-04-07 Plan Eye Tracking Repo Split

1. Goal
- Produce a scoped extraction plan for moving active and legacy eye-tracking code out of `BehaviorBox` into a separate git repository, with explicit ownership boundaries, a history-preserving migration method, and post-split submodule integration.

2. Non-goals
- Do not move files yet.
- Do not rewrite MATLAB or Python interfaces in this pass.
- Do not decide unilaterally which tracker-specific MATLAB-facing files stay in `BehaviorBox` versus move into the new repo without file-level confirmation.

3. Current-state summary
- User decisions now fix several major boundary choices:
- include legacy eye-tracking material
- move `iRecHS2/` into the new repo
- move tracker code into the new repo but keep heavy runtime model files out of the new git repo
- preserve git history
- consume the new repo from `BehaviorBox` as a private submodule
- keep `fcns/EyeTrack.m` in `BehaviorBox`
- keep tracker-specific MATLAB demos/clients in the new repo
- restore legacy material under `legacy/` on the new repo's default branch
- rename the active tracked tree from `DLC/` to `EyeTrack/`
- separate legacy binaries from legacy source/docs while keeping them in the new repo
- mount the submodule at `BehaviorBox/EyeTrack/`
- use `/Users/willsnyder/Desktop/EyeTrack` as the current local staging location
- keep only setup docs and thin MATLAB wrappers in `BehaviorBox` during the transition
- make the extracted repo immediately runnable as a standalone repo
- defer remote creation and hosting details for now; only the local staging folder is in scope
- use a no-deletion transition: keep the current `BehaviorBox` tree intact
- keep the in-repo placeholder path `BehaviorBox/EyeTrack/` empty during the transition
- keep `/Users/willsnyder/Desktop/EyeTrack` empty until the user approves the first scaffold there
- use a root bootstrap file named `bootstrap_eye_track.m` plus top-level `README.md`
- scope `models/README.md` to the active model layout only
- stay plan-only for now; do not scaffold the staging repo yet
- do not add new wrapper code inside `BehaviorBox` until integration actually begins
- document legacy binary placement in the top-level `README.md`
- when scaffolding begins, include placeholder `README.md` files inside subfolders
- when scaffolding begins, create the full empty directory skeleton for `EyeTrack/`, `legacy/iRecHS2/`, `binaries/iRecHS2/`, and `models/`
- Current active tracked eye-tracking files are under `DLC/`, especially `DLC/ToMatlab/`, `DLC/Tests/`, `DLC/environment.yaml`, and the tracked DLC model directory.
- `fcns/EyeTrack.m` is a separate MATLAB helper introduced independently of the DLC path.
- `iRecHS2/` has meaningful git history but is deleted at current `HEAD`; the working tree currently contains only an ignored `.DS_Store` under `iRecHS2/scripts/`.
- This means a history-preserving split can retain `iRecHS2/` history, but an explicit restore step is required if the new repo should expose `iRecHS2/` content on its default branch.
- Current repo search still shows no live runtime references from the main `BehaviorBox` app classes into tracked DLC files beyond planning/docs, so the subsystem remains relatively loosely coupled.
- Because the heavy model directory is currently tracked under `DLC/`, the extraction method must preserve code history while explicitly excluding those model blobs from the new repo history.
- Because the active tracked tree is being renamed during extraction, the migration is no longer a pure preserve-path split; it needs targeted path rewrites in addition to history preservation.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`
- `/Users/willsnyder/Desktop/BehaviorBox/Next Steps/EyeTracking_Repo_Split_Plan.md`

5. Validation commands
- Boundary scan:
  `rg -n "receive_eye_stream_demo|matlab_zmq_bridge|dlc_eye_streamer|EyeTrack\\(|fcns/EyeTrack|ToMatlab|DLC/Tests|pyzmq|PySpin|dlclive" -S /Users/willsnyder/Desktop/BehaviorBox`
- Tracked-file inventory:
  `git ls-files DLC iRecHS2 fcns/EyeTrack.m`
- History scan:
  `git log --oneline --all -- DLC`
- Legacy history scan:
  `git log --oneline --all -- iRecHS2`
- Size scan:
  `du -sh DLC iRecHS2`
- No MATLAB or Python execution is required in this planning-only pass.

6. Milestones
- Map the active and legacy eye-tracking files, tests, assets, and historical deletion points.
- Revise the split plan around confirmed decisions: legacy inclusion, new-repo ownership of tracker-specific MATLAB clients, submodule consumption, external-model storage, and preserved code history.
- Confirm the restore strategy for `iRecHS2/` on the new repo's default branch under `legacy/`.
- Confirm the exact repo/root naming and active-path naming strategy, including the renamed active tree under `EyeTrack/`.
- Confirm the `models/` placeholder-and-ignore convention.
- Create the local staging folder at `/Users/willsnyder/Desktop/EyeTrack`.
- Confirm the separated legacy-binary path and the standalone-run bootstrap shape.
- Confirm only whether to stay plan-only or begin creating the agreed local scaffold under `/Users/willsnyder/Desktop/EyeTrack`.

7. Risks and stop conditions
- Stop before recommending a file move that would strand hidden `BehaviorBox` runtime dependencies.
- Stop before splitting tracker-specific MATLAB files across both repos without a clear canonical owner.
- Stop before allowing the heavy runtime model snapshots back into the new repo history.
- Stop before assuming `iRecHS2/` is "included" if the new repo's default branch would still leave it deleted.
- Stop before leaving the `models/` convention ambiguous enough that users will populate inconsistent model locations.
- Stop before path-rewriting the active tree without a settled destination layout inside `EyeTrack/`.
- Stop before writing workflow notes or repo config that assume finalized remotes or Dropbox sync details that the user has deferred.
- Stop before violating the current no-deletion / keep-placeholder-empty transition rule.
- Stop before scaffolding the staging repo if the user still wants it left empty for evaluation.

8. Handoff notes
- Final handoff should name the proposed extraction boundary, the recommended history-preserving method, the active-tree rename into `EyeTrack/`, the explicit exclusion of heavy model blobs, the legacy-restore requirement under `legacy/`, the separated binary path, the submodule path, the local staging path, the deferred-remote status, the no-deletion transition rule, and the user decisions still required.
- If implementation proceeds later, update this plan with the chosen repo-creation method and post-move validation commands.
1. Goal
- Ensure fcns/readFcn.m preserves all fields saved by BehaviorBoxWheel.SaveAllData and BehaviorBoxNose.SaveAllData, while keeping the existing BehaviorBoxData datastore contract.

2. Non-goals
- Do not change the saved-file schema produced by Wheel or Nose in this pass unless a read-side fix is provably insufficient.
- Do not refactor broader BehaviorBoxData analysis logic beyond the narrow read contract.

3. Current-state summary
- readFcn currently emits a fixed 1x8 cell payload consumed by BehaviorBoxData.loadFiles().
- Wheel SaveAllData writes Settings/newData/Notes for training and Settings/Position_Record/Notes/TimeLog/MapLog/MapMeta/TimestampRecord for animate files; training wheel sessions may also save additive newData tables such as WheelDisplayRecord and FrameAlignedRecord.
- Nose SaveAllData writes Settings/newData/Notes for training and preserves a narrower schema.
- readFcn currently normalizes vector lengths, removes newData.Text, aliases legacy TtimestampRecord, and surfaces Position_Record and top-level Settings into columns 7 and 8.

4. Files likely touched
- /Users/willsnyder/Desktop/BehaviorBox/fcns/readFcn.m
- /Users/willsnyder/Desktop/BehaviorBox/AGENTS.md
- /Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md

5. Validation commands
- MATLAB lint: matlab -batch "run('startup.m'); cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('fcns/readFcn.m');"
- Focused schema smoke check: matlab -batch "run('startup.m'); cd('/Users/willsnyder/Desktop/BehaviorBox'); out = readFcn('/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Data/Will/Wheel/New/3421911/260320_163642_3421911_New_Animate_Wheel.mat',[]); disp(fieldnames(out{3}));"
- Loader smoke check: matlab -batch "run('startup.m'); cd('/Users/willsnyder/Desktop/BehaviorBox'); BBData = BehaviorBoxData('Inv','Will','Inp','Wheel','Sub',{'3421911'},'find',1,'analyze',0); disp(size(BBData.loadedData));"
- Nose loader smoke check: matlab -batch "run('startup.m'); cd('/Users/willsnyder/Desktop/BehaviorBox'); BBData = BehaviorBoxData('Inv','Will','Inp','NosePoke','Str','shank','Sub',{'3376343'},'find',1,'analyze',0); disp(size(BBData.loadedData));"

6. Milestones
- Compare Wheel/Nose SaveAllData saved fields against a real saved wheel file and the current readFcn output contract.
- Patch readFcn narrowly so saved fields are preserved and normalized safely, including a supplemental raw copy of any `newData` fields that `readFcn` changes during normalization.
- Update repo instructions with the active Will/NosePoke and Will/Wheel Dropbox tree layout that `BehaviorBoxData` searches.
- Run the narrowest MATLAB lint and smoke validation.

7. Risks and stop conditions
- Stop if preserving all saved properties requires changing the fixed 8-column datastore contract used by BehaviorBoxData.
- Stop if the saved-file schemas for Wheel and Nose are intentionally divergent in a way that a single readFcn cannot represent without a migration note.
- Stop if MATLAB validation shows a downstream consumer relies on readFcn dropping a field today.

8. Handoff notes
- Expected invariant behavior: existing BehaviorBoxData load path and legacy field access patterns continue to work.
- Allowed behavior change: additive save-side fields remain accessible in loaded newData instead of being dropped or mangled by readFcn.

## 2026-04-07 Document Live Nose And Wheel Data Roots

1. Goal
- Review the live `BehaviorBoxData` loader path and update the repo instructions so they document the actual Nose and Wheel data roots and folder contract used in practice.

2. Non-goals
- Do not change MATLAB load behavior, save behavior, or any data files on disk.
- Do not rewrite `BehaviorBoxData.m` or `fcns/GetFilePath.m`; this is documentation only.

3. Current-state summary
- `BehaviorBoxData.GetFiles()` resolves data under `fullfile(GetFilePath("Data"), Inv, Inp)`.
- `GetFilePath("Data")` currently resolves to `~/Dropbox @RU Dropbox/William Snyder/Data` on macOS and Linux.
- The live investigator/input branches in use are `Will/NosePoke` and `Will/Wheel`.
- The loader first checks exact `Str/Sub` directories, then falls back to recursive subject-name matching under the selected `Inv/Inp` root.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/AGENTS.md`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Read-only path review:
  `rg -n "GetFiles|handleNewStrain|GetFilePath\\(\" /Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxData.m /Users/willsnyder/Desktop/BehaviorBox/fcns/GetFilePath.m /Users/willsnyder/Desktop/BehaviorBox/fcns/testBehaviorBoxDataLoad.m`
- Read-only instructions review:
  `sed -n '1,260p' /Users/willsnyder/Desktop/BehaviorBox/AGENTS.md`

6. Milestones
- Confirm the real data-root and loader behavior from `BehaviorBoxData.m`, `GetFilePath.m`, and the focused smoke test script.
- Update `AGENTS.md` with the verified Nose/Wheel root paths, strain/subject layout, and loader fallback behavior.
- Re-read the edited instructions to confirm wording and scope.

7. Risks and stop conditions
- Stop if the documented Dropbox roots disagree with the code path in `GetFilePath("Data")`.
- Stop if documenting the folder layout would overstate guarantees that the loader does not actually enforce.

8. Handoff notes
- Call out that this pass changes documentation only.
- Report the exact files reviewed and note that MATLAB execution was not needed because behavior was only inspected, not changed.

## 2026-04-07 Add BehaviorBoxData No-Eager-Mkdir Smoke Test

1. Goal
- Add a focused MATLAB smoke test that proves `BehaviorBoxData` does not create a new `Str/Sub` folder during lookup when the subject is missing, and update the repo instructions so this smoke test is part of the documented validation workflow.

2. Non-goals
- Do not change save-time folder creation in `BehaviorBoxWheel.SaveAllData`, `BehaviorBoxNose.SaveAllData`, or `BehaviorBoxData.SaveAllData`.
- Do not touch real Dropbox data during validation.

3. Current-state summary
- `BehaviorBoxData.GetFiles()` now returns the would-be save path for a missing subject without creating the folder.
- Existing save paths in Nose, Wheel, and `BehaviorBoxData.SaveAllData` already create the destination folder on save.
- `fcns/testBehaviorBoxDataLoad.m` covers loading real saved data but does not cover the missing-subject no-mkdir path.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/fcns/testBehaviorBoxDataNoEagerMkdir.m`
- `/Users/willsnyder/Desktop/BehaviorBox/AGENTS.md`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint:
  `matlab -batch "run('startup.m'); cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxData.m'); checkcode('fcns/testBehaviorBoxDataNoEagerMkdir.m');"`
- Focused smoke test:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataNoEagerMkdir.m');"`

6. Milestones
- Add the isolated temporary-root smoke test script.
- Update `AGENTS.md` so both `BehaviorBoxData` smoke tests are documented and routed by use case.
- Run the narrowest MATLAB lint and the new smoke test.

7. Risks and stop conditions
- Stop if the new smoke test needs to touch the real Dropbox tree.
- Stop if documenting the new smoke test would conflict with the existing loader smoke-test workflow.

8. Handoff notes
- Report that the new script validates the lookup path without touching real data roots.
- Call out any remaining gaps in end-to-end GUI save validation.

## 2026-04-07 Add BehaviorBoxData Deferred-Save Folder-Creation Smoke Test

1. Goal
- Add a broader MATLAB smoke test that proves a missing `Str/Sub` folder stays absent during lookup and is created only when `BehaviorBoxData.SaveAllData` runs, then document that test in the repo instructions.

2. Non-goals
- Do not exercise the full GUI or hardware-backed `BehaviorBoxWheel.SaveAllData` path in this pass.
- Do not touch the real Dropbox tree during validation.

3. Current-state summary
- `fcns/testBehaviorBoxDataNoEagerMkdir.m` now proves the lookup path is non-destructive.
- `BehaviorBoxData.SaveAllData` already contains save-time `mkdir` logic for its destination folder.
- The validation docs should distinguish between lookup-only coverage and deferred-save coverage.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/fcns/testBehaviorBoxDataDeferredSaveMkdir.m`
- `/Users/willsnyder/Desktop/BehaviorBox/AGENTS.md`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint:
  `matlab -batch "run('startup.m'); cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('fcns/testBehaviorBoxDataDeferredSaveMkdir.m');"`
- Focused smoke test:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataDeferredSaveMkdir.m');"`

6. Milestones
- Add the temporary-root deferred-save smoke test script.
- Update `AGENTS.md` so the broader save-path smoke test is documented alongside the lookup smoke test.
- Run the narrowest MATLAB lint and smoke validation.

7. Risks and stop conditions
- Stop if the broader smoke test starts depending on live Dropbox data or GUI state.
- Stop if the broader smoke test duplicates the no-eager-mkdir check without adding save-time coverage.

8. Handoff notes
- Report that the new script covers save-time folder creation only in the `BehaviorBoxData.SaveAllData` path.
- Call out that full GUI save validation remains a separate, broader check.

## 2026-04-07 Turn BehaviorBox Debugging Note Into Concrete Plan

1. Goal
- Rewrite `Next Steps/BehaviorBox_Debugging_Improvements.md` from a useful backlog into a concrete phased plan that is easier for Codex to execute, including explicit acceptance criteria, ordering, and missing nose-only coverage.

2. Non-goals
- Do not implement the future debugging helpers in this pass.
- Do not change production MATLAB behavior in this pass.

3. Current-state summary
- The existing note already has good repo-specific content and sensible guardrails.
- It is incomplete as a plan because its baseline is stale, it lacks a nose-only bucket, and its future smoke tests do not define fixtures or success conditions.
- The repo now has more `BehaviorBoxData` smoke tests and stronger `AGENTS.md` validation guidance than the old note reflects.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/Next Steps/BehaviorBox_Debugging_Improvements.md`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Read-only plan review:
  `sed -n '1,260p' /Users/willsnyder/Desktop/BehaviorBox/Next\ Steps/BehaviorBox_Debugging_Improvements.md`
- Cross-check current tooling:
  `rg -n "testBehaviorBoxDataLoad|testBehaviorBoxDataNoEagerMkdir|testBehaviorBoxDataDeferredSaveMkdir|bb_debug_saved_file|MockApp/testBehaviorBoxWheelSaveStatus" /Users/willsnyder/Desktop/BehaviorBox`

6. Milestones
- Convert the note into a plan with phases and explicit scope.
- Add acceptance criteria for each proposed future smoke test or helper.
- Add a nose-only debugging phase parallel to the wheel-only phase.
- Align the baseline and validation commands with the current repo state and `AGENTS.md`.

7. Risks and stop conditions
- Stop if the rewrite drifts from repo reality and starts proposing tooling the current repo structure cannot support.
- Stop if the plan stops distinguishing shared vs. wheel-only vs. nose-only ownership boundaries.

8. Handoff notes
- Report whether the note is now complete enough to drive incremental future work.
- Call out any residual open questions that remain intentionally undecided.

## 2026-04-07 Full Will Wheel/NosePoke Schema Audit And Raw-Payload Accessor

1. Goal
- Audit all `.mat` files under `Will/Wheel` and `Will/NosePoke` for schema variants that affect `readFcn` or `BehaviorBoxData` loading.
- Add a small `BehaviorBoxData` accessor for the preserved raw payload stored in `loadedData(:,5)`.

2. Non-goals
- Do not rewrite historical data files.
- Do not change the fixed 8-column datastore contract unless the audit proves it is insufficient.
- Do not refactor unrelated `BehaviorBoxData` analysis code.

3. Current-state summary
- `readFcn` now preserves top-level unmapped `.mat` fields in column 5 and stores raw pre-normalization copies of changed `newData` fields under `OriginalNewDataFields`.
- Recent wheel and nose trees load through `BehaviorBoxData`, but older roots have not yet been audited comprehensively.
- `BehaviorBoxData` currently has no named accessor for the supplemental raw payload in column 5.

4. Files likely touched
- /Users/willsnyder/Desktop/BehaviorBox/fcns/readFcn.m
- /Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxData.m
- /Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md

5. Validation commands
- MATLAB lint: `checkcode('/Users/willsnyder/Desktop/BehaviorBox/fcns/readFcn.m')`
- Full wheel schema audit via MATLAB MCP over `/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Data/Will/Wheel`
- Full nose schema audit via MATLAB MCP over `/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Data/Will/NosePoke`
- Accessor smoke check via MATLAB MCP on one loaded `BehaviorBoxData` object

6. Milestones
- Run full-tree wheel and nose schema audits, including direct `readFcn` pass/fail checks.
- Patch `readFcn` if the audit exposes additional historical variants.
- Add a small `BehaviorBoxData` accessor for column 5 supplemental payloads.
- Run MATLAB lint and focused accessor/load validation.

7. Risks and stop conditions
- Stop if the full-tree audit reveals a historical schema that cannot be represented safely by the current normalized `newData` plus raw-payload side channel.
- Stop if making old data accessible would require changing saved-file semantics rather than read-time compatibility handling.
- Stop if the accessor would conflict with an existing public `BehaviorBoxData` API name.

8. Handoff notes
- Report total audited file counts, any read failures, the historical variants that still require explicit handling, and how to access the preserved raw payload from `BehaviorBoxData`.

## 2026-04-07 Resume old-data analysis audit

1. Goal
- Resume the old Nose/Wheel analysis audit by validating real `BehaviorBoxData` analysis entrypoints on historical subjects and fix the narrowest analysis-side compatibility bug that still blocks those paths.

2. Non-goals
- Do not refactor analysis methods broadly.
- Do not change saved `.mat` schema or loader behavior in this pass.
- Do not alter numerical methods unless required to unwrap legacy-compatible data structures.

3. Current-state summary
- Historical Wheel subject `2332101` and Nose subject `2333021` now load and analyze through `BehaviorBoxData`, but `PlotLevelGroupsByDay` still fails because `DayBin` table row values are cell-wrapped scalars.
- `DayBin` intentionally returns a row-named table built from cell content, so plotting code must unwrap those cells before numeric operations.

4. Files likely touched
- /Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxData.m
- /Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md

5. Validation commands
- MATLAB inspect old Wheel subject: `run(startup.m); BB=BehaviorBoxData(Inv,Will,Inp,Wheel,Sub,{2332101},find,0,analyze,1,plot,0);`
- MATLAB inspect old Nose subject: `run(startup.m); BB=BehaviorBoxData(Inv,Will,Inp,NosePoke,Sub,{2333021},find,0,analyze,1,plot,0);`
- MATLAB smoke plot old Wheel subject after fix: construct `BehaviorBoxData`, create invisible figure/axes, call `BB.PlotLevelGroupsByDay(InComposite,true,Ax,ax);`
- MATLAB smoke plot old Nose subject after fix: same as above for `NosePoke`.

6. Milestones
- Confirm the exact wrapped types coming out of `DayBin` on old Wheel and old Nose data.
- Patch `PlotLevelGroupsByDay` to unwrap numeric row values without changing `DayBin` output schema.
- Re-run old Wheel and old Nose analysis/plot smoke checks.

7. Risks and stop conditions
- Stop if the fix would require changing `DayBin` output schema rather than adapting the consumer.
- Stop if unwrapping changes the numeric values rather than only their container type.

8. Handoff notes
- Report which analysis entrypoints now work on old Nose/Wheel data and what remains unverified.

9. Outcome update
- Added `fcns/testBehaviorBoxDataOldAnalysis.m` to cover old Wheel subject `2332101` and old Nose subject `2333021` through `AnalyzeAllData`, `PlotLevelGroupsByDay`, and `plotLvByDayOneAxis`.
- Added explicit rescued-session fallback labeling via `GetRescuedSettingsFallback`, using `Include=1` and `rescued-missing-settings` labels when settings metadata is missing.
- Added public helper `GetDayBinScalar` so historical `DayBin` containers can be consumed safely outside nested plotting code.
- Audited the GUI analysis path in `BB_App.m`; its `AnalyzeAllData` + `plotLvByDayOneAxis` sequence is now covered by the regression smoke test.
- Audited `fcns/RescueDataFromAGraph.m`; it only uses `BehaviorBoxData(..., find=true)` and the loader contract, so no further change was required in this pass.

## 2026-04-07 Implement Canonical PlotBinomialLevels In BehaviorBoxData

1. Goal
- Turn `BehaviorBoxData.PlotBinomialLevels` into a working canonical binomial-performance plotting method using the current `BehaviorBoxData` analysis schema.

2. Non-goals
- Do not change saved `.mat` schema, loader behavior, or `AnalyzeAllData` outputs.
- Do not retire `BehaviorBoxDataNew.m` in this pass.
- Do not refactor unrelated plotting methods.

3. Current-state summary
- `BehaviorBoxData.m` is the canonical class.
- `PlotBinomialLevels` was just ported from `BehaviorBoxDataNew.m`, but the donor method only builds figure layout and does not plot the binomial analysis.
- `BehaviorBoxData.m` already has binomial analysis inputs in `LevelMMAnalysis`, `MMCross`, and `PlotLevelGroupsByDay`'s existing `Which` option.

4. Files likely touched
- /Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxData.m
- /Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md

5. Validation commands
- MATLAB lint: `checkcode('BehaviorBoxData.m')`
- MATLAB smoke check: `run('startup.m'); BB=BehaviorBoxData('Inv','Will','Inp','Wheel','Sub',{'2332101'},'find',0,'analyze',1,'plot',0); f=BB.PlotBinomialLevels('Sc',1,'Ax',[]); close(f);`

6. Milestones
- Map the current canonical binomial-analysis data available to plotting.
- Implement the minimal plotting logic in `PlotBinomialLevels`.
- Run narrow MATLAB validation on the historical Wheel subject.

7. Risks and stop conditions
- Stop if a useful implementation requires changing the internal analysis schema rather than consuming current outputs.
- Stop if the plotted quantity cannot be derived unambiguously from current `LevelMM` / `DayMM` data.

8. Handoff notes
- Call out exactly what binomial quantity is plotted and whether it differs from the old `BehaviorBoxDataNew` intent.
## Implement wheel trial and response timing tightening

- date/time: 2026-04-10 15:29 -04:00
- feature_id: behaviorbox-wheel-tighten-timer-semantics
- scope: C:\Users\MBO-Alpha\Desktop\BehaviorBox timing save semantics and existing timer plots
- goal: Make wheel TrialStartTime accumulate the full hold-still interval across resets and make wheel ResponseTime measure stimulus-on to the final committed choice for new data.
- implementation boundary: Edit BehaviorBoxWheel.m timing capture only; keep DrinkTime unchanged; rely on existing BehaviorBoxData timer plots instead of adding a new plotting subsystem.
- status: in-progress
- next review date: 2026-04-17

### Assumptions
- Only new data written after this change needs the tightened semantics.
- Existing BehaviorBoxData timer plots should reflect the corrected values without schema additions.
- DrinkTime should remain reward-delivery timing as currently implemented.

### Acceptance Criteria
- TrialStartTime increases when the hold-still interval resets instead of snapping back to only the final successful hold window.
- ResponseTime is measured from stimulus-on to the final committed choice in normal and OnlyCorrect wheel trials.
- BehaviorBox training saves continue to populate TrialStartTime and ResponseTime and the existing timer plots consume the tightened values.

### Changed Files
- C:\Users\MBO-Alpha\Desktop\BehaviorBox\BehaviorBoxWheel.m
- C:\Users\MBO-Alpha\.codex\PLAN_LOG.md
- C:\Users\MBO-Alpha\Desktop\BehaviorBox\.agent\PLANS.md

### Validation Plan
- MATLAB static check: checkcode('BehaviorBoxWheel.m')
- Focused MATLAB timing smoke test for hold-still resets and OnlyCorrect response timing using repository code paths or a narrow harness.
- Inspect BehaviorBoxData timer plot path to confirm it reads TrialStartTime and ResponseTime directly.
## Complete wheel trial and response timing tightening

- date/time: 2026-04-10 15:33 -04:00
- feature_id: behaviorbox-wheel-tighten-timer-semantics
- scope: C:\Users\MBO-Alpha\Desktop\BehaviorBox timing save semantics and existing timer plots
- goal: Land the wheel timing change so TrialStartTime captures full hold-still initialization across resets and ResponseTime measures stimulus-on to the final committed choice for new data.
- implementation boundary: BehaviorBoxWheel.m only for runtime behavior; existing BehaviorBoxData timer plots are reused without new schema fields or plotting widgets.
- status: done
- next review date: 2026-04-17

### Assumptions
- Only new data written after this change needs the tightened semantics.
- Existing BehaviorBoxData timer plots are the intended display surface for the corrected values.
- DrinkTime remains unchanged by request.

### Acceptance Criteria
- TrialStartTime is derived from a per-trial timer that does not reset when the hold-still sub-interval resets.
- ResponseTime includes the full elapsed time from stimulus on to the final committed choice, including keyboard OnlyCorrect retries.
- BehaviorBoxData timer plots continue to read TrialStartTime and ResponseTime directly for new sessions.

### Changed Files
- C:\Users\MBO-Alpha\Desktop\BehaviorBox\BehaviorBoxWheel.m
- C:\Users\MBO-Alpha\.codex\PLAN_LOG.md
- C:\Users\MBO-Alpha\Desktop\BehaviorBox\.agent\PLANS.md

### Validation Plan
- MATLAB static check: checkcode('BehaviorBoxWheel.m')
- MATLAB class parse check via meta.class.fromName('BehaviorBoxWheel').
- Headless mock save harness attempted via MockApp/testBehaviorBoxWheelSaveStatus.m; blocked by pre-existing mock-environment issues unrelated to this timing patch.

## 2026-04-14 Validate DLC Live Eye Stream Into MATLAB And BehaviorBox Save

1. Goal
- Verify the active DLC Live path can move eye metrics from Python into MATLAB and then into wheel-session saves without breaking current BehaviorBox save/load behavior.
- Land the narrowest production integration needed so wheel sessions can persist additive eye-tracking outputs that reload cleanly through the current `BehaviorBoxData` path.

2. Non-goals
- Do not add eye-tracking logic to `BehaviorBoxNose.m`.
- Do not use `iRecHS2/`; the active path is `DLC/ToMatlab/`.
- Do not change DLC model training, point order, or camera hardware configuration beyond what is required to validate transport.
- Do not redefine existing `TimestampRecord`, `WheelDisplayRecord`, or `FrameAlignedRecord` semantics; only additive eye outputs are allowed.
- Do not commit generated `.mat`, `.csv`, or runtime model artifacts.

3. Current-state summary
- `DLC/ToMatlab/dlc_eye_streamer.py` is the active Python publisher. It emits ZeroMQ JSON payloads with timing, center, diameter, confidence, valid-point count, FPS, latency, and a nested `points` dictionary.
- `DLC/ToMatlab/matlab_zmq_bridge.py` exposes `open_subscriber`, `close_socket`, `recv_latest_dict`, and `recv_latest` for MATLAB via `py.*`.
- `DLC/ToMatlab/receive_eye_stream_demo.m` is only a demo subscriber. It receives the latest tuple and writes a base-workspace `eye` struct; it is not a production MATLAB class.
- No `BehaviorBoxEyeTrack.m` or equivalent production eye-tracking MATLAB class exists in the current working tree.
- `BehaviorBoxWheel.m` already owns wheel/imaging timing and additive save tables. Its `SaveAllData()` path already saves `TimestampRecord`, `WheelDisplayRecord`, and `FrameAlignedRecord` into `newData` for wheel sessions.
- `fcns/readFcn.m` already skips MATLAB tables during trial-vector normalization, which is the current compatibility mechanism for additive session-wide tables.
- Existing repo notes in `Next Steps/DLC_EyeTracking_FrameAlignedRecord_Plan.md` already point toward a dedicated MATLAB helper class and additive `EyeTrackingRecord` / `EyeTrackingMeta` outputs.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`
- `/home/wbs/Desktop/BehaviorBox/DLC/ToMatlab/dlc_eye_streamer.py`
- `/home/wbs/Desktop/BehaviorBox/DLC/ToMatlab/matlab_zmq_bridge.py`
- `/home/wbs/Desktop/BehaviorBox/DLC/ToMatlab/receive_eye_stream_demo.m`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxEyeTrack.m`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxData.m`
- `/home/wbs/Desktop/BehaviorBox/fcns/readFcn.m`
- `/home/wbs/Desktop/BehaviorBox/fcns/testBehaviorBoxDataLoad.m`
- one or more new focused MATLAB/Python smoke tests near `DLC/ToMatlab/` or `fcns/`

5. Validation commands
- Python syntax smoke:
  `python3 -m py_compile /home/wbs/Desktop/BehaviorBox/DLC/ToMatlab/dlc_eye_streamer.py /home/wbs/Desktop/BehaviorBox/DLC/ToMatlab/matlab_zmq_bridge.py`
- MATLAB lint after any `.m` edits:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m'); checkcode('BehaviorBoxEyeTrack.m'); checkcode('DLC/ToMatlab/receive_eye_stream_demo.m');"`
- Existing MATLAB bridge demo with a live publisher:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('DLC/ToMatlab/receive_eye_stream_demo.m');"`
- Existing loader smoke test:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"`
- Add and run a synthetic end-to-end smoke test that does not require FLIR hardware or a DLC model:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('DLC/ToMatlab/test_eye_stream_bridge.m');"`
- Add and run a save-path smoke test that proves additive eye-tracking outputs survive save and reload:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxEyeSaveLoad.m');"`

6. Milestones
- Freeze the Python-to-MATLAB contract.
  Decide the production MATLAB contract for required fields, types, NaN behavior, timestamp fields, and whether the nested `points` dictionary is flattened, stored separately, or omitted from first-pass save outputs.
- Add a synthetic publisher/subscriber smoke path.
  Build a minimal test that publishes representative JSON payloads into `matlab_zmq_bridge.py` and proves MATLAB can receive and normalize them without FLIR or DLCLive.
- Implement the MATLAB eye-tracking receiver class.
  Add `BehaviorBoxEyeTrack.m` as a narrow wheel-side helper that owns Python bridge setup, subscriber lifetime, latest-sample access, session-clock stamping, session-wide buffering, and metadata collection.
- Integrate the receiver into `BehaviorBoxWheel.m`.
  Keep integration wheel-only. Start/stop the helper with the session, poll or drain it at deterministic points, and save additive `EyeTrackingRecord` and `EyeTrackingMeta` outputs. Extend `FrameAlignedRecord` only with additive eye columns if frame-level alignment is included in this pass.
- Prove save and reload compatibility.
  Validate that saved wheel sessions containing eye-tracking outputs can still be read by `BehaviorBoxData` without trimming, schema confusion, or silent loss of additive fields.
- Run one live end-to-end rig check.
  With the real DLC Live publisher running, confirm that MATLAB receives fresh samples, BehaviorBox captures them during a wheel session, and the saved `.mat` file contains the expected eye-tracking outputs with reasonable timing.

7. Risks and stop conditions
- Stop if the MATLAB side is expected to consume a payload shape that the Python publisher does not actually emit.
- Stop if the first implementation tries to save nested Python objects directly into MATLAB tables without an explicit schema decision.
- Stop if the integration would require putting microscopy or eye-tracking logic into `BehaviorBoxNose.m`.
- Stop if additive eye outputs cause `BehaviorBoxData` load regressions or silent field truncation.
- Stop if Python and MATLAB disagree on timestamp units, indexing, NaN semantics, or field names.
- Stop if the only available verification path depends on unavailable FLIR/DLC hardware; in that case, complete the synthetic bridge and save/load smoke tests first and report the remaining live-rig risk explicitly.

8. Handoff notes
- The intended invariant is that existing wheel-session behavior, `TimestampRecord`, `WheelDisplayRecord`, and existing `FrameAlignedRecord` columns keep their current meanings.
- Any saved eye-tracking output must be additive and explicitly named in the handoff, along with whether it is dense sample-level data, frame-aligned data, or metadata.
- Report validation separately for:
  - synthetic publisher -> MATLAB
  - MATLAB class -> BehaviorBox wheel integration
  - saved file -> `BehaviorBoxData` reload
  - live FLIR/DLC rig coverage

## 2026-04-15 Fix EyeTrack Active Bridge Readiness

1. Goal
- Fix urgent EyeTrack review findings 2, 4, 5, 6, and 7 so the active DLC Live -> ZeroMQ -> MATLAB path is usable today on the local `dlclivegui` conda environment.
- Make bundled YangLab pupil-model keypoint mapping explicit and hard to misuse.
- Keep iRecHS2 clearly marked as legacy relic-only material and keep it off the default MATLAB path.

2. Non-goals
- Do not maintain, repair, or validate iRecHS2 runtime code.
- Do not make the environment fully reproducible across machines in this pass.
- Do not change the ZeroMQ JSON field schema or MATLAB tuple field order.
- Do not change saved MATLAB data schema.

3. Current-state summary
- Python producer: `EyeTrack/DeepLabCut/ToMatlab/dlc_eye_streamer.py` emits ZeroMQ JSON with eye metrics.
- Python bridge: `EyeTrack/DeepLabCut/ToMatlab/matlab_zmq_bridge.py` exposes `recv_latest` to MATLAB through `py.*`.
- MATLAB consumer demo: `EyeTrack/DeepLabCut/ToMatlab/receive_eye_stream_demo.m` imports the bridge and reads the latest tuple.
- Bundled model keypoint order is `Lpupil`, `LDpupil`, `Dpupil`, `DRpupil`, `Rpupil`, `RVupil`, `Vpupil`, `VLpupil`.
- `bootstrap_eye_track.m` currently adds legacy iRecHS2 paths by default, which conflicts with active-path-only usage.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/README.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/bootstrap_eye_track.m`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/ToMatlab/README_eye_stream.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/ToMatlab/dlc_eye_streamer.py`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/ToMatlab/receive_eye_stream_demo.m`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/Tests/Spin2DLC.py`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/Tests/TestSpin.py`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/Tests/dlcspin.py`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/environment.yaml`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/models/README.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/legacy/README.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/legacy/iRecHS2/README.md`

5. Validation commands
- Proposed MATLAB static check:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); checkcode('EyeTrack/bootstrap_eye_track.m'); checkcode('EyeTrack/DeepLabCut/ToMatlab/receive_eye_stream_demo.m');"`
- Proposed Python syntax check:
  `python3 -m py_compile EyeTrack/DeepLabCut/ToMatlab/dlc_eye_streamer.py EyeTrack/DeepLabCut/Tests/Spin2DLC.py EyeTrack/DeepLabCut/Tests/TestSpin.py EyeTrack/DeepLabCut/Tests/dlcspin.py`
- Proposed live bridge check after starting publisher in `dlclivegui`:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox/EyeTrack'); paths = bootstrap_eye_track(); run('DeepLabCut/ToMatlab/receive_eye_stream_demo.m');"`

6. Milestones
- Patch active keypoint preset and docs for the bundled YangLab pupil model.
- Patch MATLAB demo Python resolution to prefer `BB_EYETRACK_PYTHON`, active `CONDA_PREFIX`, then common `dlclivegui` paths.
- Remove `prefix:` from the conda environment capture.
- Remove legacy iRecHS2 from default bootstrap paths and document it as relic-only.
- Add PySpin teardown and image-release safety to the camera smoke scripts.

7. Risks and stop conditions
- Stop if MATLAB and Python disagree on the ZeroMQ tuple field order or units.
- Stop if the local `dlclivegui` interpreter cannot be resolved without machine-specific guessing.
- Stop if a change would require modifying iRecHS2 implementation code instead of only isolating/documenting it.

8. Handoff notes
- Expected invariant outputs: JSON field names, MATLAB tuple order, timestamp units, and CSV column names.
- Intended behavior change: users can run the bundled YangLab model using a named preset instead of hand-entering wrong keypoint indices; bootstrap no longer exposes iRecHS2 unless explicitly requested.

## 2026-04-15 Add BehaviorBoxEyeTrack Scaffolding

1. Goal
- Add a new root-level MATLAB helper class, `BehaviorBoxEyeTrack.m`, that logs dense eye-tracking samples from text payloads and now owns the live MATLAB subscriber path.
- Add additive Wheel save outputs, `EyeTrackingRecord` and `EyeTrackingMeta`, without changing existing trial logic ownership.
- Add placeholder eye columns to `FrameAlignedRecord` so later alignment can remain additive.
- Replace `receive_eye_stream_demo.m` as the active MATLAB subscriber and update the EyeTrack README files accordingly.

2. Non-goals
- Do not change Python payload schema or the DLC publisher code in `dlc_eye_streamer.py`.
- Do not change any `BehaviorBoxNose.m` behavior.
- Do not populate frame-aligned eye columns with live values yet.

3. Current-state summary
- `BehaviorBoxSerialTime.m` is the local pattern for a handle-class logger that stores raw text plus a parsed table.
- `BehaviorBoxWheel.m` owns session setup, save-time assembly, and `FrameAlignedRecord`.
- The active eye-tracking producer is the DLC ZeroMQ JSON publisher under `EyeTrack/DeepLabCut/ToMatlab/`.
- `startup.m` is minimal, so any EyeTrack bridge-path assumptions must remain explicit.
- `receive_eye_stream_demo.m` is now deprecated and still contains the only complete MATLAB-side Python bridge setup logic in the repo.
- The bundled YangLab model point order is fixed: `Lpupil`, `LDpupil`, `Dpupil`, `DRpupil`, `Rpupil`, `RVupil`, `Vpupil`, `VLpupil`.

4. MATLAB / Python boundary contract
- Boundary object: ZeroMQ JSON eye sample
  - Owner side: Python producer, MATLAB consumer
  - Carrier: JSON text line / message
  - Fields consumed this pass:
    - `frame_id`: Python int -> MATLAB double
    - `capture_time_unix_s`, `publish_time_unix_s`: Python float seconds -> MATLAB double
    - `capture_time_unix_ns`, `publish_time_unix_ns`: Python int nanoseconds -> MATLAB string in record, exact digits preserved in raw log
    - `center_x`, `center_y`, `diameter_px`, `diameter_h_px`, `diameter_v_px`, `confidence_mean`, `camera_fps`, `inference_fps`, `latency_ms`: Python float -> MATLAB double
    - `valid_points`: Python int -> MATLAB double
    - `points`: Python dict of 8 keypoints -> MATLAB cell column containing an `8x3 double` matrix in fixed model order
- MATLAB bridge object:
  - Owner side: Python helper, MATLAB consumer
  - Carrier: `py.*` bridge to `matlab_zmq_bridge.py`
  - Contract this pass:
    - MATLAB calls a Python helper that opens a `zmq.SUB` socket to either localhost or a configured remote host.
    - MATLAB receives the latest available JSON payload as text and feeds that text into `BehaviorBoxEyeTrack.processReading`.
- Indexing/orientation contract:
  - Python pose rows are 0-based in code comments, but saved MATLAB `points_xyp` is an `8x3` matrix whose row order follows the fixed point-name list above.
  - Columns are `[x y likelihood]`.
- Classic failure modes to avoid:
  - Do not trust MATLAB `jsondecode` alone for nanosecond integer exactness; preserve exact digits separately.
  - Do not transpose or squeeze the 8x3 points matrix.
  - Do not save nested Python objects directly into MATLAB tables.

5. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxEyeTrack.m`
- `/home/wbs/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/home/wbs/Desktop/BehaviorBox/fcns/testBehaviorBoxEyeTrack.m`
- `/home/wbs/Desktop/BehaviorBox/MockApp/testBehaviorBoxWheelSaveStatus.m`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/README.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/ToMatlab/README_eye_stream.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/Tests/README.md`

6. Validation commands
- Static checks:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m'); checkcode('BehaviorBoxEyeTrack.m'); checkcode('fcns/testBehaviorBoxEyeTrack.m'); checkcode('MockApp/testBehaviorBoxWheelSaveStatus.m'); checkcode('EyeTrack/DeepLabCut/ToMatlab/receive_eye_stream_demo.m');"`
- Focused MATLAB smoke tests:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxEyeTrack.m'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxEyeTrack.m BehaviorBoxWheel.m fcns/testBehaviorBoxEyeTrack.m MockApp/testBehaviorBoxWheelSaveStatus.m EyeTrack/README.md EyeTrack/DeepLabCut/ToMatlab/README_eye_stream.md EyeTrack/DeepLabCut/Tests/README.md`

7. Milestones
- Add `BehaviorBoxEyeTrack.m` with raw-text logging, parsed record table, metadata helpers, fixed point-order handling, and a real MATLAB-side Python subscriber.
- Add `EyeTrack` session initialization and save output plumbing in `BehaviorBoxWheel.m`.
- Start and stop the subscriber from Wheel setup/cleanup and tag incoming samples with the active trial number.
- Add empty additive eye columns to `FrameAlignedRecord` row builders.
- Add focused MATLAB smoke coverage for the new class, subscriber wiring, and Wheel save outputs.
- Update active README files so `BehaviorBoxEyeTrack` replaces `receive_eye_stream_demo.m` as the subscriber entrypoint.

8. Risks and stop conditions
- Stop if the Python payload seen in practice does not contain the documented `points` dict or uses a different point-name order than the bundled model docs.
- Stop if preserving exact nanosecond fields would require silently changing the Python schema instead of keeping the MATLAB side additive.
- Stop if additive eye outputs break existing Wheel save/load paths or force microscopy logic outside `BehaviorBoxWheel.m`.
- Stop if MATLAB `pyenv` lifetime or timer behavior requires changing the producer or bridge schema instead of only the MATLAB subscriber side.

9. Handoff notes
- Expected invariant outputs: existing `TimestampRecord`, `WheelDisplayRecord`, current `FrameAlignedRecord` columns, trial logic, reward logic, and save path names.
- Intended output changes: additive `newData.EyeTrackingRecord`, additive `newData.EyeTrackingMeta`, and additive empty eye columns on `FrameAlignedRecord`.
- Intended behavior change: `BehaviorBoxEyeTrack` becomes the active MATLAB subscriber; `receive_eye_stream_demo.m` remains deprecated transitional code only.

## 2026-04-15 Mark EyeTrack Legacy And Smoke-Only Code For Agents

1. Goal
- Make EyeTrack routing unambiguous for future AI agents.
- Mark `DeepLabCut/ToMatlab` as the only active implementation path.
- Mark `DeepLabCut/Tests` as smoke/hardware probe code only, not production implementation code.
- Mark all `legacy/iRecHS2` material as relic-only and not to be maintained or integrated.

2. Non-goals
- Do not change MATLAB or Python runtime behavior.
- Do not repair iRecHS2.
- Do not remove historical files in this pass.

3. Current-state summary
- Active Python/MATLAB bridge is in `EyeTrack/DeepLabCut/ToMatlab`.
- `EyeTrack/DeepLabCut/Tests` contains dependency, camera, and inference smoke scripts that can look implementation-like.
- `EyeTrack/legacy/iRecHS2` contains old eye-tracking code that should not be used for current or future implementations.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/AGENTS.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/README.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/README.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/Tests/AGENTS.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/Tests/README.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/legacy/AGENTS.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/legacy/README.md`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/legacy/iRecHS2/README.md`

5. Validation commands
- None planned; documentation-only guardrail change.

6. Milestones
- Add top-level EyeTrack agent routing instructions.
- Add nested guardrails in smoke-only and relic-only folders.
- Strengthen README warnings where humans and agents will see them.

7. Risks and stop conditions
- Stop if the requested marking requires changing behavior or deleting files.

8. Handoff notes
- Report changed docs/agent files and that no runtime validation was run because no executable code changed.

## 2026-04-15 Add EyeTrack Legacy And Smoke File Headers

1. Goal
- Add top-of-file warnings to editable iRecHS2 source files and DeepLabCut smoke scripts so future agents do not confuse them with active eye-tracking implementation code.

2. Non-goals
- Do not change runtime behavior.
- Do not repair iRecHS2 or smoke scripts.
- Do not modify binary, image, PDF, model, or environment files.

3. Current-state summary
- Active path is `EyeTrack/DeepLabCut/ToMatlab`.
- Smoke-only scripts live in `EyeTrack/DeepLabCut/Tests`.
- Relic-only iRecHS2 source lives under `EyeTrack/legacy/iRecHS2`.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/DeepLabCut/Tests/*.py`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/legacy/iRecHS2/iRecTests/iRecTest1.m`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/legacy/iRecHS2/scripts/*.py`
- `/home/wbs/Desktop/BehaviorBox/EyeTrack/legacy/iRecHS2/scripts/*.m`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- None planned; comment-only guardrail change.

6. Milestones
- Add smoke-only warnings to DeepLabCut test scripts.
- Add relic-only warnings to iRecHS2 MATLAB and Python source files.

7. Risks and stop conditions
- Stop if a file is binary or generated and cannot safely receive a text header.

8. Handoff notes
- Report changed source files and note that no runtime validation was run because no executable logic changed.

## 2026-04-16 Add Nose Wait Blink Setting

1. Goal
- Add optional ready-cue idle blinking during `BehaviorBoxNose.WaitForInputArduino`.
- Use existing `Setting_Struct.Wait_Blink` and `Setting_Struct.Wait_Blink_Sec` values when present.

2. Non-goals
- Do not change Wheel behavior.
- Do not change Arduino serial protocol, sensor pin mapping, or reward timing.
- Do not change saved data schema or numerical analysis outputs.

3. Current-state summary
- `WaitForInput` dispatches to `WaitForInputArduino` for NosePoke Arduino input.
- `WaitForInputArduino` waits for left/right sensors to clear, handles intertrial malingering, then accepts a stable middle sensor through `Middle_StableChoice_StartTrial`.
- `ReadNone()` is intentionally inverted for nose input and returns true when any sensor token is active.
- Existing stall blink behavior is a short nonblocking dim-to-base color blink.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxNose.m`
- `/Users/willsnyder/Desktop/BehaviorBox/fcns/MockBehaviorBoxNoseWaitBlink.m`
- `/Users/willsnyder/Desktop/BehaviorBox/fcns/testBehaviorBoxNoseWaitBlink.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Static checks:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('fcns/MockBehaviorBoxNoseWaitBlink.m'); checkcode('fcns/testBehaviorBoxNoseWaitBlink.m');"`
- Focused wait-blink smoke:
  `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxNoseWaitBlink.m');"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m fcns/MockBehaviorBoxNoseWaitBlink.m fcns/testBehaviorBoxNoseWaitBlink.m .agent/PLANS.md`

6. Milestones
- Patch `WaitForInputArduino` with the idle timer and short ready cue blink.
- Add a focused headless MATLAB smoke script for enabled/disabled blink behavior.
- Run focused MATLAB validation and inspect the final diff.

7. Risks and stop conditions
- Stop if App Designer field names differ from `Wait_Blink` or `Wait_Blink_Sec`.
- Hardware-in-the-loop Nose session start/stop/save remains unverified unless bench hardware is available.

## 2026-04-17 Auto-Switch GUI Input From Detected Arduino Family

1. Goal
- When Arduino polling runs during GUI startup/reset, automatically switch `BB_App` input selection to `NosePoke` or `Wheel` if the discovered behavior Arduinos belong to exactly one family.
- Keep the existing Nose and Wheel connection flow in `BehaviorBoxNose.ConfigureBox`, `BehaviorBoxWheel.ConfigureBox`, and `fcns/arduinoServer.m`.

2. Non-goals
- Do not change Arduino serial protocol, Box ID strings, baud rates, reward pin handling, or timestamp-Arduino behavior.
- Do not change save-data schema, subject loading rules, or non-Nose/Wheel GUI modes beyond avoiding an incorrect default selection.

3. Current-state summary
- `fcns/arduinoServer.m` enumerates serial ports, reads startup text, and extracts `Box ID` identities such as Nose, Wheel, and Time.
- `BB_App.FindArduino` currently searches only the family implied by the current GUI input, which defaults to `NosePoke` at startup.
- `BehaviorBox_OpeningFcn` calls `FindArduino`, then `LoadComputerSpecifics`, then builds either `BehaviorBoxNose` or `BehaviorBoxWheel`.
- `BehaviorBoxNose.ConfigureBox` and `BehaviorBoxWheel.ConfigureBox` each retry connection with family-specific discovery if the selected Arduino lookup fails.
- On single-purpose training machines, a Wheel-only setup can still start in Nose mode, requiring a manual GUI input change before the correct Arduino is selected.

4. Files likely touched
- `/home/wbs/Desktop/BehaviorBox/BB_App.m`
- `/home/wbs/Desktop/BehaviorBox/fcns/arduinoServer.m` (read-only context unless implementation forces a change)
- `/home/wbs/Desktop/BehaviorBox/fcns/inferBehaviorInputFromArduinoInfo.m`
- `/home/wbs/Desktop/BehaviorBox/fcns/testInferBehaviorInputFromArduinoInfo.m`
- `/home/wbs/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- Static checks:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); checkcode('BB_App.m'); checkcode('fcns/inferBehaviorInputFromArduinoInfo.m'); checkcode('fcns/testInferBehaviorInputFromArduinoInfo.m');"`
- Focused helper smoke:
  `matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testInferBehaviorInputFromArduinoInfo.m');"`
- Conflict marker scan:
  `rg -n "^<<<<<<<|^=======|^>>>>>>>" BB_App.m fcns/inferBehaviorInputFromArduinoInfo.m fcns/testInferBehaviorInputFromArduinoInfo.m .agent/PLANS.md`

6. Milestones
- Add a helper that infers a unique behavior input family from discovered Arduino identities.
- Update `BB_App.FindArduino` to poll all Arduinos once, auto-switch the GUI input when exactly one behavior family is present, and then select the matching Arduino.
- Run focused MATLAB validation and inspect the final diff.

7. Risks and stop conditions
- Stop if the app relies on programmatic `Box_Input_type.Value` changes firing callbacks automatically; if not, update the dependent state explicitly.
- Stop if the detected-device list can contain both Nose and Wheel identities on normal single-box setups, because that would make the auto-switch heuristic ambiguous.
- Hardware-in-the-loop confirmation of actual serial connection remains unverified unless a Nose-only or Wheel-only bench setup is available.

8. Handoff notes
- Call out the handshake locations in `BB_App.m`, `BehaviorBoxNose.m`, `BehaviorBoxWheel.m`, and `fcns/arduinoServer.m`.
- Report that validation covers inference logic and MATLAB syntax, not live USB enumeration against attached hardware.
