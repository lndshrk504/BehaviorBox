# Wheel/Stimulus Logging Plan For Imaging Sync

Date: 2026-03-24

## User decisions from review

- Keep existing saved fields and add new fields rather than repurposing old ones.
- Keep the wheel reset behavior implicit. Do not add reset-event logging.
- Keep all trial-metric logging inside `BehaviorBoxWheel.m`. Do not move it into `BehaviorBoxSerialInput.m`.
- Do not change the current Timekeeper/annotation clock strategy yet.
- Do not add a new stimulus event stream yet.
- Do build the frame-aligned derived table for imaging analysis.
- Do update analysis to use `TimestampRecord.parsed`.
- Do log values as they were actually drawn, not only as they were intended to be drawn.

## Revised plan summary for improved wheel/display timestamping

The immediate goal is to improve imaging alignment by saving the wheel-driven display state at the point where `BehaviorBoxWheel` makes its final on-screen update, and then aligning those saved MATLAB-side display samples to Timekeeper frame timestamps during analysis.

### Scope now

1. Extend wheel-mode trial logging in `BehaviorBoxWheel.m`.
2. Record wheel/display state inside `readLeverLoopAnalogWheel`, because that is the last function that modifies what is shown on the screen.
3. Save additive per-sample records that preserve:
- the raw wheel value returned by the wheel Arduino
- the program variable `delta`
4. Build a frame-aligned analysis product by joining these saved wheel/display samples to Timekeeper frame timestamps from `TimestampRecord.parsed`.
5. Update downstream analysis to use `TimestampRecord.parsed` rather than reparsing raw timestamp strings.
6. Skip this new logging path entirely when `this.Time` is empty, so wheel-mode behavior remains unchanged if no Time Arduino is connected.

### What this is intended to achieve

- Preserve what the mouse-facing display state was at the point it was updated in MATLAB.
- Allow later analysis to align those saved display samples to imaging frame timestamps.
- Improve reconstruction of stimulus position and visibility over time during wheel trials.

### Important interpretation

This is a MATLAB-side reconstruction aligned to Timekeeper frame timestamps.
It is not yet a redesign of the clocking architecture, and it does not claim a new same-clock display-event ground truth.
For now, the goal is better practical synchronization using:
- saved draw-state samples from `readLeverLoopAnalogWheel`
- saved Timekeeper frame timestamps from `TimestampRecord.parsed`

### Out of scope now

- moving trial logging into `BehaviorBoxSerialInput.m`
- logging every wheel reset event
- redesigning the Timekeeper/annotation clock strategy
- adding a separate new stimulus event stream
- prioritizing ScanImage file-index tracking inside MATLAB

## Records to save

Save the new additive record under the name `WheelDisplayRecord`.

For each relevant draw/update sample in `readLeverLoopAnalogWheel`, save additive fields that include:
- `trial`
- `phase`
- `tTrial`
- `rawWheel`
- `delta`
- `StimColor`
- `screenEvent`
- `level`
- `isLeftTrial`

`WheelDisplayRecord` should be a session-wide MATLAB table with a `trial` column.
Save `tTrial` in seconds as a MATLAB `double`.
Save `phase` as MATLAB string data.
`rawWheel` should come from the variable `dist` in `readLeverLoopAnalogWheel`.
`delta` should come from the variable `delta` in `readLeverLoopAnalogWheel`.
`StimColor` should be included now as a saved column even though the feature that drives it will be added later.
`StimColor` should come from the variable `baseColor` in `readLeverLoopAnalogWheel` until the later contour-brightness feature is implemented or if that feature is turned off.
`StimColor` should be saved as a grayscale MATLAB `double`.
Use the `screenEvent` column to mark timepoints when something happened on the screen.
For the current plan, record both the start and the end of visible idle-blink screen changes triggered by `stallblink` in `readLeverLoopAnalogWheel`.
Use identifiable event names such as `stallblink_start` and `stallblink_end`.
Write the `WheelDisplayRecord` row when the screen state actually changes at the `drawnow` call, not merely when execution enters the surrounding branch logic.
For the current code, `stallblink_start` is associated with the branch beginning near line 1262 of `BehaviorBoxWheel.m`, and `stallblink_end` is associated with the branch ending near line 1276, but the saved event row should be stamped at the actual `drawnow` screen-update point.
For ordinary saved draw-state rows with no discrete screen event, `screenEvent` should be empty.
Only save a new `WheelDisplayRecord` row when the wheel/display state changes or when a screen event occurs. A new row should be written whenever any saved reconstruction-relevant column changes.
Write a normal `WheelDisplayRecord` row whenever any reconstruction-relevant saved field changes and `screenEvent = ""`.
For this plan, the row-change comparison should include `phase`, `rawWheel`, `delta`, `StimColor`, `level`, `isLeftTrial`, and `screenEvent`.
If the wheel/display state does not change, later imaging frames should align to the same most recent saved draw-state row.
`tTrial` should be trial-relative time with `tTrial = 0` immediately after the `hold_still_start` message is added to the timestamp log in `BehaviorBoxWheel.m`.
Implement this by adding a property named `hold_still_start`, setting it equal to `tic` at the `hold_still_start` event, and using `toc(hold_still_start)` for each saved draw/update sample.
Frames that arrive before Hold Still begins should be assigned negative `tTrial` values relative to the later Hold Still start so the frame timeline remains continuous around the Hold Still anchor.
The current anchor for this in code is the `this.logTimeEvent_("hold_still_start", ...)` call in `BehaviorBoxWheel.m`.

Allowed `phase` values for this first implementation:
- `hold_still`
- `response`
- `reward`
- `intertrial`

Use `reward` only after a correct response.
After an incorrect response, transition directly from `response` to `intertrial` with no `reward` phase.
Add a new explicit phase variable in `BehaviorBoxWheel.m` so saved draw-state rows and derived frame rows use one consistent source of truth for trial phase.

## Analysis output

Create a session-wide derived frame-aligned MATLAB table named `FrameAlignedRecord` after each trial during acquisition so analysis-ready frame labels are baked into the saved session outputs.
This table should:
- uses frame timing from `TimestampRecord.parsed`
- maps each imaging frame to the nearest previous saved wheel/display sample, so each frame is aligned to the most recent draw-state that was on screen before the frame clock signal was received
- carries forward the display-state values needed for reconstruction and analysis
- carries forward trial-level outcome fields such as `decision` and `correct` onto all frame rows for that trial
- include per-frame phase labels so later analysis and plotting can annotate each frame by trial phase
- contain one row per Timekeeper frame event
- contain zero rows for trials with no frame events

Committed derived columns for `FrameAlignedRecord`:
- `trial`
- `frame`
- `t_us`
- `phase`
- `tTrial`
- `rawWheel`
- `delta`
- `StimColor`
- `screenEvent`
- `level`
- `isLeftTrial`
- `decision`
- `correct`

Save `decision` as MATLAB string data.
`decision` should be initialized empty for frame rows during the trial and then filled after trial end with the final value derived from `whatdecision`.
`correct` should be initialized as `NaN` for frame rows during the trial and then filled after trial end using the final outcome derived from `whatdecision`.

## Final committed schema

### `WheelDisplayRecord`

- Type: session-wide MATLAB table
- Purpose: stores timepoints when the on-screen draw state changed in a way relevant to later reconstruction
- Columns:
- `trial`
- `phase`
- `tTrial`
- `rawWheel`
- `delta`
- `StimColor`
- `screenEvent`
- `level`
- `isLeftTrial`
- Column definitions:
- `phase` is MATLAB string data with allowed values `hold_still`, `response`, `reward`, and `intertrial`
- `tTrial` is MATLAB `double` seconds
- `rawWheel` comes from `dist` in `readLeverLoopAnalogWheel`
- `delta` comes from `delta` in `readLeverLoopAnalogWheel`
- `StimColor` is a grayscale MATLAB `double` and comes from `baseColor` in `readLeverLoopAnalogWheel` until the later contour-brightness feature is implemented or when that feature is turned off
- `screenEvent` is empty for ordinary draw-state rows and uses identifiable event names for discrete screen events, currently `stallblink_start` and `stallblink_end`
- `level` and `isLeftTrial` are copied from the current trial context
- Timing rules:
- `tTrial = 0` immediately after the `hold_still_start` message is added to the timestamp log
- `hold_still_start` is implemented via a property named `hold_still_start` set equal to `tic`, with saved sample times measured by `toc(hold_still_start)`
- frames that occur before Hold Still begins may later map to negative `tTrial` values relative to the Hold Still anchor
- Row creation rules:
- write a normal `WheelDisplayRecord` row whenever any reconstruction-relevant saved field changes and `screenEvent = ""`
- write an event row whenever a discrete screen event occurs
- row-change comparison includes `phase`, `rawWheel`, `delta`, `StimColor`, `level`, `isLeftTrial`, and `screenEvent`
- `stallblink_start` and `stallblink_end` rows are written at the actual `drawnow` screen-change point rather than only at branch entry or branch exit

### `FrameAlignedRecord`

- Type: session-wide MATLAB table
- Purpose: stores one row per Timekeeper frame event, aligned to the nearest previous saved draw-state row
- Columns:
- `trial`
- `frame`
- `t_us`
- `phase`
- `tTrial`
- `rawWheel`
- `delta`
- `StimColor`
- `screenEvent`
- `level`
- `isLeftTrial`
- `decision`
- `correct`
- Column definitions:
- `phase` is MATLAB string data copied from the nearest previous `WheelDisplayRecord` row
- `tTrial`, `rawWheel`, `delta`, `StimColor`, `screenEvent`, `level`, and `isLeftTrial` are copied from the nearest previous `WheelDisplayRecord` row
- `decision` is MATLAB string data, initialized empty during the trial and filled after trial end from `whatdecision`
- `correct` is initialized as `NaN` during the trial and filled after trial end using the final outcome derived from `whatdecision`
- Construction rules:
- build `FrameAlignedRecord` after each trial during acquisition from `TimestampRecord.parsed` and `WheelDisplayRecord`
- use a per-trial temporary table named `CurrentTrialFrameAlignedRecord`
- match each frame event to the nearest previous `WheelDisplayRecord` row
- write one row per Timekeeper frame event
- trials with no frame events contribute zero rows
- append `CurrentTrialFrameAlignedRecord` into the larger session-wide `FrameAlignedRecord` only if that trial has at least one frame event
- if `this.Time` is empty, skip this timestamp-aligned path entirely

## Implementation sequence

1. Extend `BehaviorBoxWheel.m` properties and save path with new additive fields only.
2. Capture raw wheel values and actual drawn display values during `readLeverLoopAnalogWheel`.
3. Save the new fields into `newData.WheelDisplayRecord` without changing existing `wheel_record`, `StimHist`, or `TimestampRecord`.
4. Use a per-trial temporary variable named `CurrentTrialFrameAlignedRecord` to accumulate frame-aligned rows for the current trial, then reset that temporary variable at the beginning of the next trial.
5. Build `FrameAlignedRecord` after each trial during acquisition from `TimestampRecord.parsed` and the saved `WheelDisplayRecord` rows.
6. Append the per-trial frame-aligned rows into the larger session-wide `FrameAlignedRecord` only if at least one frame event occurred during that trial.
7. Save `FrameAlignedRecord` into the session outputs so later analysis can reuse it directly.
8. If `this.Time` is empty, skip the new timestamp-aligned logging path and continue normal wheel-mode behavior.

## Invariants to preserve

- Existing `wheel_record` must remain readable and retain its current meaning.
- Existing `StimHist` must remain unchanged and continue to store the initial per-trial stimulus snapshot.
- Existing `TimestampRecord` raw and parsed logs must remain saved.
- Existing trial outcome, score, timing, and save-path behavior must remain unchanged.
- If no Time Arduino is connected and `this.Time` is empty, this new feature must be skipped without changing normal wheel-mode behavior.

## Intended output changes

- Additional saved fields for wheel/display reconstruction will appear in the training `.mat` output.
- The training `.mat` output will include `FrameAlignedRecord`, a frame-aligned table derived from `TimestampRecord.parsed` and `WheelDisplayRecord`.
- Replay/reconstruction should reflect the actual drawn display values recorded at the final MATLAB display-update point, not only intended state.
- Each saved frame row should be labeled with the trial phase so later analysis can annotate frames by phase without rebuilding that logic.

## Validation plan

### Static

- `matlab -batch "checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m');"`

### Behavioral smoke test

- Run one short wheel session and confirm the saved `.mat` now contains:
- the existing `wheel_record`
- the new `WheelDisplayRecord`
- the existing `TimestampRecord`
- Confirm `WheelDisplayRecord` rows are only added when the wheel/display state changes.

### Analysis smoke test

- Run one short wheel session and confirm:
- frame rows come from `TimestampRecord.parsed`
- each frame row is matched to the nearest previous `WheelDisplayRecord` row
- `FrameAlignedRecord` is created after each trial and saved into the output `.mat`
- the frame-aligned table can be joined to saved wheel/display values
- each frame row carries the expected phase label
- reconstructed display position changes over time as expected within at least one trial
- frame rows that occurred before Hold Still carry negative `tTrial` values
- a trial with no frame events contributes zero rows to `FrameAlignedRecord`
- `StimColor` is present in `WheelDisplayRecord` and carried into `FrameAlignedRecord` even before the later contour-brightness feature is implemented
- `screenEvent` records both `stallblink_start` and `stallblink_end` rows when idle blink triggers visible screen changes
- the `stallblink_start` and `stallblink_end` rows are written at the actual `drawnow` screen-change point rather than only at branch entry/exit

### Missing-Time-Arduino smoke test

- Run wheel mode with `this.Time` empty and confirm:
- normal wheel behavior still runs
- saving still succeeds
- no `WheelDisplayRecord` timestamp-aligned path is executed

## Execution status

- Planning only. No MATLAB behavior changes have been executed yet.
