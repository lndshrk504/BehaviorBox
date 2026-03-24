# Wheel/Stimulus Logging Plan For Imaging Sync

Date: 2026-03-24

## User decisions from review

- Keep existing saved fields and add new fields rather than repurposing old ones.
- Keep `wheelchoice` as the derived stimulus-offset trace. This is preferable for later stimulus reconstruction.
- Keep the wheel reset behavior implicit. Do not add reset-event logging.
- Keep `wheelchoicetime` as trial-relative time.
- Keep all trial-metric logging inside `BehaviorBoxWheel.m`. Do not move it into `BehaviorBoxSerialInput.m`.
- Do not change the current Timekeeper/annotation clock strategy yet.
- Do not add a new stimulus event stream yet.
- Do store both the derived display trace and the additional values needed to recreate what the mouse actually saw on the display.
- Do build the frame-aligned derived table for imaging analysis.
- Do update analysis to use `TimestampRecord.parsed`.
- Do log values as they were actually drawn, not only as they were intended to be drawn.

## Resulting plan

### Scope now

1. Extend wheel-trial logging in `BehaviorBoxWheel.m` so each trial stores more than `{decision, wheelchoice, wheelchoicetime}`.
2. Save additional per-trial traces that preserve:
- the raw wheel readout returned by `this.a.ReadWheel()`
- the existing derived `wheelchoice` trace
- the actual drawn display state at draw time
3. Build a frame-aligned analysis table using `TimestampRecord.parsed` so imaging frames can be joined to behavioral and display state.
4. Update downstream analysis to consume `TimestampRecord.parsed` instead of reparsing raw timestamp strings.

### Out of scope now

- Moving trial logging responsibilities into `BehaviorBoxSerialInput.m`
- Logging every wheel reset event
- Unifying hardware and MATLAB annotation clocks
- Adding a separate, broader stimulus event stream beyond the existing `Time.Log`

## Proposed records to add

### 1. Draw-time wheel/display record

Primary new per-trial record stored from `BehaviorBoxWheel.m`.

Suggested contents per sample:
- `trial`
- `scanImageFile`
- `phase`
- `tTrial`
- `rawWheel`
- `wheelchoice`
- `useXform`
- `txR`
- `txL`
- `axRPosX`
- `axLPosX`
- `blinkActive`
- `stimVisible`
- `level`
- `isLeftTrial`

Notes:
- `rawWheel` preserves the direct readout from `this.a.ReadWheel()`.
- `wheelchoice` preserves the current derived stimulus-offset trace.
- `txR` / `txL` capture the actual hgtransform translation when that path is used.
- `axRPosX` / `axLPosX` capture the actual axes positions when that path is used instead.
- These values should be recorded when the draw state is actually pushed, not just when a new wheel sample is read.

### 2. Frame-aligned derived table

Derived analysis product built from saved wheel/display traces plus `TimestampRecord.parsed`.

Suggested columns:
- `trial`
- `scanImageFile`
- `frame`
- `t_us`
- `epoch`
- `stimVisible`
- `level`
- `isLeftTrial`
- `rawWheel`
- `wheelchoice`
- `txR`
- `txL`
- `axRPosX`
- `axLPosX`
- `blinkActive`
- `decision`
- `correct`

Notes:
- This table is the intended join point for later microscopy outputs.
- The source of frame timing should be `TimestampRecord.parsed`, not raw string parsing.

## Implementation sequence

1. Extend `BehaviorBoxWheel.m` properties and save path with new additive fields only.
2. Capture raw wheel values and actual drawn display values during `readLeverLoopAnalogWheel`.
3. Save the new fields into `newData` without changing existing `wheel_record`, `StimHist`, or `TimestampRecord`.
4. Add a focused analysis helper or update the existing imaging script to use `TimestampRecord.parsed`.
5. Build the frame-aligned table from the saved records.

## Invariants to preserve

- Existing `wheel_record` must remain readable and retain its current meaning.
- Existing `StimHist` must remain unchanged and continue to store the initial per-trial stimulus snapshot.
- Existing `TimestampRecord` raw and parsed logs must remain saved.
- Existing trial outcome, score, timing, and save-path behavior must remain unchanged.

## Intended output changes

- Additional saved fields for wheel/display reconstruction will appear in the training `.mat` output.
- Analysis will gain a frame-aligned table derived from `TimestampRecord.parsed`.
- Replay/reconstruction should reflect the actual drawn display values, not only intended state.

## Validation plan

### Static

- `matlab -batch "checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m');"`

### Behavioral smoke test

- Run one short wheel session and confirm the saved `.mat` now contains:
- the existing `wheel_record`
- the new additive wheel/display fields
- the existing `TimestampRecord`

### Analysis smoke test

- Run the updated analysis path on one known imaging session and confirm:
- frame rows come from `TimestampRecord.parsed`
- the frame-aligned table can be joined to saved wheel/display values
- reconstructed display position changes over time as expected within at least one trial

## Open decisions left for implementation

- exact field names for the new additive records
- whether the frame-aligned table is saved during acquisition or produced only during analysis
- which minimal visual-state flags beyond position are necessary for acceptable reconstruction now

## Execution status

- Planning only. No MATLAB behavior changes have been executed yet.
