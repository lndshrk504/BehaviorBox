# Map-FlashContourX and Map-SweepLine Eye-Tracking Save Plan

## Goal

Save eye-tracking data alongside the mapping timestamp and screen-event data produced by `Map-FlashContourX` and `Map-SweepLine`, and derive two aligned tables that make downstream analysis straightforward.

The intended eye-tracking outputs should be as similar as possible to what normal training already saves when eye tracking and microscope frame timestamps are present. In practice, that means:

- keep `EyeTrackingRecord` and `EyeTrackingMeta` in the same style as training saves
- treat `TimestampRecord`, `EyeTrackingRecord`, and `MapLog` as the three raw source records
- derive two aligned tables from those three source records:
  - `FrameAlignedRecord`
  - `EyeAlignedRecord`

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
- The existing training eye path already uses drain-all capture semantics through the normal `BehaviorBoxEyeTrack.pollAvailable()` path, which drains queued samples rather than intentionally keeping only the most recent sample.
- The mapping path does **not** currently reuse the normal animation/training session bootstrap that starts eye tracking and anchors it to the session clock.
- The current eye-tracking lifecycle is still too session-centric. It does not yet clearly separate:
  - the long-lived eye-tracking stream for one mouse
  - the per-session connect/disconnect behavior used by mapping and behavior runs
- There is no derived alignment layer that starts from the three raw source records:
  - parsed timestamp frames in `TimestampRecord`
  - mapping screen events in `MapLog`
  - eye samples in `EyeTrackingRecord`
- There is no `FrameAlignedRecord` for mapping-mode saves
- There is no `EyeAlignedRecord` for mapping-mode saves

## Main Gap

`RunMappingStimulus()` bypasses the normal `SetupBeforeAnimation()` path. That means it does not currently guarantee that:

1. `BehaviorBoxEyeTrack` is initialized
2. the behavior or mapping session connects to an already-running eye stream
3. the eye stream shares the same session clock as timestamps and screen events
4. raw eye data is saved in the animate output file
5. the mapping path disconnects cleanly without implying that the upstream eye stream should stop
6. the mapping path reuses the same drain-all eye receive path and final-drain behavior already used by training

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

### 2. Reuse the existing training drain-all eye path during mapping

During `Map-FlashContourX` and `Map-SweepLine`:

- keep the eye subscriber running for the full session
- reuse the existing `BehaviorBoxEyeTrack.pollAvailable()` drain-all behavior during settle and inter-flash wait intervals
- reuse the existing drain-all behavior during flash-on intervals
- reuse the existing final-drain behavior at session end

The simplest place to do this is inside the existing mapping wait loop so the eye stream is sampled anywhere the mapping code is already updating time-based state.

The design intent here is not to invent a separate mapping-specific eye receive path. It is to route mapping through the same queued drain-all eye capture path already used by normal training.

Use a consistent mapping trial/session label, for example:

- `trial = 0` for the full mapping session

That preserves a clean distinction between mapping runs and ordinary behavioral trials.

The assumption here is:

- the eye-tracking source is already running for the current mouse
- `Map-FlashContourX` and `Map-SweepLine` only connect to that source for the duration of the mapping session
- the default mapping implementation should use the same drain-all receive path as training
- a latest-only fallback path is not acceptable for the normal mapping workflow
- lossless means from the moment the BehaviorBox session connects to the already-running eye stream, not from before connection

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

### 4. Derive two aligned tables from the three raw source records

Add new helpers in `BehaviorBoxWheel.m`, for example:

- `buildMappingFrameAlignedRecord_()`
- `buildMappingEyeAlignedRecord_()`

Inputs:

- parsed frame rows from `TimestampRecord`
- screen events from `MapLog`
- eye samples from `EyeTrackingRecord`

Output:

- `FrameAlignedRecord`
- `EyeAlignedRecord`

The three raw source records are:

- `TimestampRecord`
- `EyeTrackingRecord`
- `MapLog`

`FrameAlignedRecord` should use microscope frame rows from `TimestampRecord` as the backbone.

For each microscope frame row:

- preserve that frame's timing and key frame identifiers
- attach the most recent eye sample whose receive time is less than or equal to that microscope frame time
- attach merged screen-event strings for events whose receive times occurred after the previous microscope frame and at or before the current microscope frame
- attach the current mapping state fields in effect at that microscope frame

`EyeAlignedRecord` should use eye-sample rows from `EyeTrackingRecord` as the backbone.

For each eye-sample row:

- preserve that eye sample's timing and eye-tracking fields
- attach merged screen-event strings for events whose receive times occurred after the previous eye sample and at or before the current eye sample
- attach the microscope frame that was captured immediately after that eye sample, if one exists
- attach the current mapping state fields in effect at that eye sample

This design assumes the eye-tracking stream is intentionally running faster than the microscope stream, for example eye tracking near `100 fps` and microscope frames near `17 fps`. Under that assumption:

- every microscope frame should generally have a recent eye sample at or before it
- multiple eye samples may map to the same later microscope frame in `EyeAlignedRecord`

`FrameAlignedRecord` should deliberately mirror the existing training `FrameAlignedRecord` design in:

- timebase
- eye column names
- microscope-frame row semantics
- use of parsed frame timestamps as the primary alignment index

Explicit alignment rule:

- microscope frame timestamps are the background timebase
- in `FrameAlignedRecord`, each microscope frame row carries the most recent eye sample at or before that frame time
- in `FrameAlignedRecord`, `screenEvent` stores merged event strings for screen events that happened after the previous microscope frame and at or before the current microscope frame
- in `EyeAlignedRecord`, each eye-sample row carries merged event strings for screen events that happened after the previous eye sample and at or before the current eye-sample time
- in `EyeAlignedRecord`, each eye-sample row carries the first microscope frame whose timestamp is greater than or equal to the eye-sample time
- `screenEvent` stores merged event strings, not a single raw event token

### 5. Define the saved schema for the aligned tables

Recommended columns for `FrameAlignedRecord` and `EyeAlignedRecord`:

Base `FrameAlignedRecord` directly on the existing training `FrameAlignedRecord` schema, then add the minimal mapping-specific fields needed for reconstruction.

`EyeAlignedRecord` should not invent a new eye schema. It should be:

- one row per eye sample
- all `EyeTrackingRecord` columns copied through unchanged
- plus mapping/event context columns
- plus microscope back-reference columns

This preserves the exact per-sample DeepLabCut outputs for the active bundled YangLab 8-point pupil model.

Training-style core columns to preserve:

- `trial`
- `t_us`
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

`FrameAlignedRecord` should also preserve the microscope-frame identity columns already used by training, including:

- `frame`
- `t_arduino_us`
- `t_pc_receive_us`

Exact `EyeAlignedRecord` eye-backbone columns copied from `EyeTrackingRecord`:

- `trial`
- `t_us`
- `t_receive_us`
- `frame_id`
- `capture_time_unix_s`
- `capture_time_unix_ns`
- `publish_time_unix_s`
- `publish_time_unix_ns`
- `center_x`
- `center_y`
- `diameter_px`
- `diameter_h_px`
- `diameter_v_px`
- `confidence_mean`
- `valid_points`
- `camera_fps`
- `inference_fps`
- `latency_ms`
- `is_valid`
- `sample_status`

Exact DeepLabCut point columns for the current bundled `yanglab-pupil8` model:

- `Lpupil_x`
- `Lpupil_y`
- `Lpupil_likelihood`
- `LDpupil_x`
- `LDpupil_y`
- `LDpupil_likelihood`
- `Dpupil_x`
- `Dpupil_y`
- `Dpupil_likelihood`
- `DRpupil_x`
- `DRpupil_y`
- `DRpupil_likelihood`
- `Rpupil_x`
- `Rpupil_y`
- `Rpupil_likelihood`
- `RVpupil_x`
- `RVpupil_y`
- `RVpupil_likelihood`
- `Vpupil_x`
- `Vpupil_y`
- `Vpupil_likelihood`
- `VLpupil_x`
- `VLpupil_y`
- `VLpupil_likelihood`

These point columns are the exact per-keypoint `x`, `y`, and `likelihood` values published by the streamer for this model. The center, diameter, confidence, valid-point count, and sample-status fields are streamer-derived summaries and should also be retained.

Recommended mapping/event columns appended to `EyeAlignedRecord`:

- `screenEvent`
- `phase`
- `tTrial`
- `mode`
- `level`
- `variant`
- `x`
- `y`
- `angleDeg`
- `scale`
- `brightness`

Recommended optional event-window helper columns in `EyeAlignedRecord`:

- `screenEvent_count`
- `screenEvent_t_first_us`
- `screenEvent_t_last_us`

Recommended microscope back-reference columns in `EyeAlignedRecord`:

- `nextMicroscopeFrame`
- `nextMicroscopeFrame_t_us`
- `nextMicroscopeFrame_t_arduino_us`
- `nextMicroscopeFrame_t_pc_receive_us`
- `nextMicroscopeFrame_dt_us`

Mapping-specific additions or reinterpretations for both aligned tables:

- `screenEvent`
  use mapping screen events instead of training wheel-phase events
- `phase`
  use expressive mapping values such as `settle`, `sequence`, `interflash`, `flash`, and `sweep`
- `tTrial`
  define relative to mapping-session start, not sequence start
- `mode`
- `level`
- `variant`
- `x`
- `y`
- `angleDeg`
- `scale`
- `brightness`

Keep the raw logs unchanged and add these aligned tables as a convenience layer for analysis, but do not invent a divergent eye-output format from the one already used by training.

Inside `EyeAlignedRecord`, keep the eye-sample column names exactly as they already exist in `EyeTrackingRecord`; do not rename them to `eye_*`-prefixed variants. The `eye_*` alignment-prefix convention should remain a frame-backed-table convention, not an eye-backed-table convention.

For `Map-SweepLine`, mode-specific columns that do not apply to a given row can remain empty, `NaN`, or `""` by the same conventions already used in training-aligned records. The eye-tracking outputs themselves should still be saved in the same way as for `Map-FlashContourX`.

### 6. Define behavior when microscope frames are absent

If a mapping run has no parsed microscope frame rows but does have parsed eye-tracking data:

- omit `FrameAlignedRecord`
- still save `EyeAlignedRecord`

In that case, `EyeAlignedRecord` should:

- use eye-sample receive times as the backbone
- align screen events the same way as in the normal eye-aligned case
- leave the microscope back-reference columns empty, `NaN`, or otherwise explicitly missing when there is no later microscope frame to label

This ensures that mapping runs without parsed microscope frames still produce an aligned eye/event table rather than only raw logs.

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

The test should also verify that:

- `EyeAlignedRecord` contains the exact copied `EyeTrackingRecord` sample columns
- `EyeAlignedRecord` contains the exact 24 bundled `yanglab-pupil8` point columns
- `EyeAlignedRecord` contains the microscope back-reference columns
- expected screen events are represented
- aligned rows use the mapping session timebase
- `FrameAlignedRecord` uses microscope frame timestamps the same way training `FrameAlignedRecord` does
- `EyeAlignedRecord` uses eye-sample times as its backbone
- eye-output naming is compatible with the existing training-save conventions
- when parsed microscope frame rows are present:
  - `FrameAlignedRecord` is saved
  - `EyeAlignedRecord` is saved
  - each `FrameAlignedRecord` row carries the most recent eye sample at or before that frame
  - each `EyeAlignedRecord` row carries the first microscope frame at or after that eye sample
- if frame rows are absent but eye rows are present:
  - `FrameAlignedRecord` is omitted
  - `EyeAlignedRecord` is still saved
- the mapping receive path preserves all eye samples for the test fixture with no loss

## Recommended Implementation Order

1. Separate per-mouse eye-stream ownership from per-session connect/disconnect behavior
2. Reuse the existing training drain-all receive/drain path during mapping
3. Save `EyeTrackingRecord` and `EyeTrackingMeta` in animate outputs
4. Build and save `FrameAlignedRecord`
5. Build and save `EyeAlignedRecord`
6. Add the focused mock save test

## Important Risk

The normal training path is already based on drain-all capture, not an intended latest-only design. The mapping risk is therefore narrower:

- mapping must explicitly reuse that same drain-all training path
- mapping must not introduce a separate latest-only receive path
- if a custom bridge adapter lacking `recv_all_json` is used, it could regress to the `recv_latest_json` fallback, which is not acceptable for the intended mapping workflow

The mapping implementation should not be considered complete unless it is confirmed to use the same drain-all receive semantics as training for the default bridge path, with losslessness defined from the moment the BehaviorBox session connects.

## Expected Result

After this change, a `Map-FlashContourX` or `Map-SweepLine` save file should contain:

- raw timestamp log data
- raw mapping event/state data
- raw eye-tracking data
- eye-tracking metadata

If parsed microscope frame rows are present, the save file should also contain:

- `FrameAlignedRecord` built in the same style as training saves
- `EyeAlignedRecord` built on the eye-sample backbone

If parsed microscope frame rows are absent but eye data exists, the save file should instead contain:

- `EyeAlignedRecord`

Operationally, the eye-tracking workflow should support:

- run multiple mapping or behavior sessions while the stream continues
- connect and disconnect from that stream at the start and end of each session
- rely on the user to start and stop the upstream eye-tracking stream manually

This will allow a new analysis function to reconstruct:

- when each flash or sweep event occurred
- what eye position and eye-state sample was current for each microscope frame
- what screen events had happened by each eye sample
- what was shown on the screen
- what eye sample was most recent at or before each microscope frame
- using outputs that remain close to the existing training eye-tracking and microscope-frame save format
