# Map-FlashContourX Eye-Tracking Save Plan

## Goal

Save eye-tracking data alongside the mapping timestamp and screen-event data produced by `Map-FlashContourX`, and add a derived aligned table that makes downstream analysis straightforward.

The intended eye-tracking outputs should be as similar as possible to what normal training already saves when eye tracking and microscope frame timestamps are present. In practice, that means:

- keep `EyeTrackingRecord` and `EyeTrackingMeta` in the same style as training saves
- use microscope frame timestamps from the parsed timestamp log as the alignment backbone
- produce a `FrameAlignedRecord`-like mapping output rather than inventing a totally different eye-alignment schema

Assume the upstream eye-tracking stream is running continuously while a mouse is being mapped or trained. The system should support:

- connecting to the stream when a behavior or mapping session starts
- disconnecting from the stream when that behavior or mapping session ends

Explicit ownership rule:

- starting the upstream eye-tracking stream is a manual user action
- stopping the upstream eye-tracking stream is a manual user action
- no MATLAB code in `BehaviorBoxWheel` should own once-per-mouse stream start or stop
- `BehaviorBoxWheel` should only connect to an already-running stream and disconnect when the current session ends

## Current State

- `RunMappingStimulus()` in `BehaviorBoxWheel.m` already saves:
  - `TimeLog`
  - `MapLog`
  - `MapMeta`
  - `TimestampRecord`
- The animate-save branch of `SaveAllData()` does **not** currently save:
  - `EyeTrackingRecord`
  - `EyeTrackingMeta`
- The mapping path does **not** currently reuse the normal animation/training session bootstrap that starts eye tracking and anchors it to the session clock.
- The current eye-tracking lifecycle is still too session-centric. It does not yet clearly separate:
  - the long-lived eye-tracking stream for one mouse
  - the per-session connect/disconnect behavior used by mapping and behavior runs
- There is no mapping-specific aligned table that combines:
  - parsed timestamp frames
  - mapping screen events
  - eye samples
- There is no fallback aligned table for mapping runs that have eye samples but no parsed microscope frame rows

## Main Gap

`RunMappingStimulus()` bypasses the normal `SetupBeforeAnimation()` path. That means it does not currently guarantee that:

1. `BehaviorBoxEyeTrack` is initialized
2. the behavior or mapping session connects to an already-running eye stream
3. the eye stream shares the same session clock as timestamps and screen events
4. raw eye data is saved in the animate output file
5. the mapping path disconnects cleanly without implying that the upstream eye stream should stop
6. eye samples received during mapping are preserved losslessly

## Files Involved

- `BehaviorBoxWheel.m`
- `BehaviorBoxEyeTrack.m`
- `MockApp/testBehaviorBoxWheelSaveStatus.m`
- New focused mock test for mapping saves

## Plan

### 1. Separate eye-stream lifetime from session connection lifetime

At the start of `RunMappingStimulus()`:

- reset session state
- initialize `BehaviorBoxEyeTrack`
- reset the timekeeper session state
- connect to the already-running eye stream
- call the same session-clock setup used by training and normal animation

Recommended implementation:

- define two distinct layers:
  - eye-stream lifetime: manual user-owned process outside `BehaviorBoxWheel`
  - session lifetime: connect when a behavior or mapping run starts, disconnect when it ends
- extract the common per-session bootstrap already used by `SetupBeforeAnimation()`
- reuse that helper from the mapping path
- treat `EyeTrack.start()` / `EyeTrack.stop()` as session-level connect/disconnect only
- do not add GUI or runtime code that attempts to launch or terminate the upstream eye streamer

This should make mapping sessions behave like normal animate sessions with respect to:

- `TrainStartTime`
- `TrainStartWallClock`
- per-session stream connection
- shared `t_us` origin across eye data, timestamps, and mapping events

### 2. Keep eye tracking active during the mapping run

During `Map-FlashContourX`:

- keep the eye subscriber running for the full session
- poll eye data during settle and inter-flash wait intervals
- poll eye data during flash-on intervals

The simplest place to do this is inside the existing mapping wait loop so the eye stream is sampled anywhere the mapping code is already updating time-based state.

Use a consistent mapping trial/session label, for example:

- `trial = 0` for the full mapping session

That preserves a clean distinction between mapping runs and ordinary behavioral trials.

The assumption here is:

- the eye-tracking source is already running for the current mouse
- `Map-FlashContourX` only connects to that source for the duration of the mapping session
- the eye-receive path used during mapping must be lossless, not latest-only

### 3. Save raw eye-tracking outputs in animate saves

Extend the `Activity == "Animate"` branch of `SaveAllData()` so that mapping/animate output files also save:

- `EyeTrackingRecord`
- `EyeTrackingMeta`

These should be written alongside the existing animate outputs:

- `TimeLog`
- `MapLog`
- `MapMeta`
- `TimestampRecord`

This gives the saved `.mat` file all three raw streams needed for later analysis:

1. timestamp frames and parsed events
2. mapping screen events
3. eye samples

These raw eye outputs should match the normal training-save pattern as closely as possible so a downstream analysis function can treat training and mapping sessions consistently.

### 4. Add a derived mapping-aligned table

Add a new helper in `BehaviorBoxWheel.m`, for example:

- `buildMappingFrameAlignedRecord_()`

Inputs:

- parsed frame rows from `TimestampRecord`
- screen events from `MapLog`
- eye samples from `EyeTrackingRecord`

Output:

- `FrameAlignedRecord`
- `MapFrameAlignedRecord`

Both aligned outputs should exist.

Recommended relationship:

- first build a training-style `FrameAlignedRecord`
- then derive `MapFrameAlignedRecord` from `FrameAlignedRecord` by adding or preserving the mapping-specific display/state fields needed for analysis

Each aligned row should be keyed on the shared session clock `t_us` and should contain:

- microscope frame timing from parsed frame rows in `TimestampRecord`
- the screen event whose receive time fell just before that frame, so the event is assigned to the first microscope frame after it was received
- the eye sample whose receive time fell just before that frame, so the sample is assigned to the first microscope frame after it was received
- current mapping state fields

This aligned mapping table should deliberately mirror the existing training `FrameAlignedRecord` design in:

- timebase
- eye column names
- microscope-frame row semantics
- use of parsed frame timestamps as the primary alignment index

Explicit alignment rule:

- microscope frame timestamps are the background timebase
- screen events are aligned to the first microscope frame whose timestamp is greater than or equal to the screen-event receive time
- eye samples are aligned to the first microscope frame whose timestamp is greater than or equal to the eye-sample receive time

### 5. Define the saved schema for the aligned mapping table

Recommended columns for `MapFrameAlignedRecord`:

Base this directly on the existing training `FrameAlignedRecord` schema, then add the minimal mapping-specific fields needed for reconstruction.

Training-style core columns to preserve:

- `trial`
- `frame`
- `t_us`
- `t_arduino_us`
- `t_pc_receive_us`
- `phase`
- `tTrial`
- `screenEvent`
- `mode`
- `level`
- `variant`
- `x`
- `y`
- `angleDeg`
- `scale`
- `brightness`
- `eye_x`
- `eye_y`
- `eye_diameter_px`
- `eye_confidence`
- `eye_valid_points`
- `eye_latency_ms`
- `eye_sample_count`
- `eye_dt_us`
- `eye_isValid`

Mapping-specific additions or reinterpretations:

- `screenEvent`
  use mapping screen events instead of training wheel-phase events
- `mode`
- `level`
- `variant`
- `x`
- `y`
- `angleDeg`
- `scale`
- `brightness`

Keep the raw logs unchanged and add these aligned tables as a convenience layer for analysis, but do not invent a divergent eye-output format from the one already used by training.

### 6. Add a no-frame fallback aligned output

If a mapping run has no parsed microscope frame rows but does have parsed eye-tracking data, save a fallback aligned table:

- `MapEyeAlignedEventRecord`

This fallback table should:

- use eye-sample receive times as the background timebase
- align mapping screen events to the first eye sample whose receive time is greater than or equal to the screen-event receive time
- preserve the same mapping event/state fields used by `MapFrameAlignedRecord` where possible

This ensures that mapping runs without parsed microscope frames still produce an aligned event table rather than only raw logs.

### 7. Disconnect cleanly at mapping end without stopping the mouse-level stream

At the end of `RunMappingStimulus()`:

- finalize the per-session eye-tracking state before saving
- disconnect from the eye stream
- perform one last poll or drain step if needed

This reduces the chance of losing trailing eye samples near:

- `SequenceEnd`
- `AcquisitionEnd`
- final `TimestampRecord` storage

Important lifecycle rule:

- ending a mapping or behavior session should **not** imply stopping the upstream eye-tracking process for that mouse
- stopping the upstream eye-tracking process remains a manual user action

### 8. Add focused validation for the mapping save path

Add a new focused mock test, for example:

- `MockApp/testBehaviorBoxWheelMappingSave.m`

The test should:

- create a fake mapping `TimestampRecord`
- create a fake `MapLog`
- create a fake `BehaviorBoxEyeTrack` record
- run the animate/mapping save path
- assert that the saved file contains:
  - `EyeTrackingRecord`
  - `EyeTrackingMeta`
  - `FrameAlignedRecord`
  - `MapFrameAlignedRecord`

The test should also verify that:

- expected eye columns are present
- expected screen events are represented
- aligned rows use the mapping session timebase
- aligned rows use microscope frame timestamps the same way training `FrameAlignedRecord` does
- eye-output naming is compatible with the existing training-save conventions
- `MapFrameAlignedRecord` is derived from `FrameAlignedRecord`
- if frame rows are absent but eye rows are present, `MapEyeAlignedEventRecord` is saved
- the mapping receive path preserves all eye samples for the test fixture with no loss

## Recommended Implementation Order

1. Separate per-mouse eye-stream ownership from per-session connect/disconnect behavior
2. Replace latest-only mapping eye capture with a lossless receive/drain path
3. Save `EyeTrackingRecord` and `EyeTrackingMeta` in animate outputs
4. Build and save `FrameAlignedRecord`, then derive `MapFrameAlignedRecord`
5. Add the no-frame fallback `MapEyeAlignedEventRecord`
6. Add the focused mock save test

## Important Risk

The current `BehaviorBoxEyeTrack` path is still latest-sample oriented. That is not acceptable for this mapping requirement.

The mapping implementation should not be considered complete unless the receive path used during mapping is lossless with respect to arriving eye samples.

## Expected Result

After this change, a `Map-FlashContourX` save file should contain:

- raw timestamp log data
- raw mapping event/state data
- raw eye-tracking data
- eye-tracking metadata
- `FrameAlignedRecord` built in the same style as training saves
- `MapFrameAlignedRecord` derived from `FrameAlignedRecord`
- `MapEyeAlignedEventRecord` when eye data exists but parsed microscope frame rows do not

Operationally, the eye-tracking workflow should support:

- run multiple mapping or behavior sessions while the stream continues
- connect and disconnect from that stream at the start and end of each session
- rely on the user to start and stop the upstream eye-tracking stream manually

This will allow a new analysis function to reconstruct:

- when each flash occurred
- what was shown on the screen
- what eye sample was closest to each frame or event
- using outputs that remain close to the existing training eye-tracking and microscope-frame save format
