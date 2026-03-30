# DLC Eye Tracking Integration Plan For FrameAlignedRecord

Date: 2026-03-30

## User decisions from review

- Do not use `iRecHS2/` for this project.
- Use DeepLabCut from `DLC/` as the active eye-tracking path.
- Keep eye-tracking timing on the same BehaviorBox session clock used by `BehaviorBoxWheel.m` and `BehaviorBoxSerialTime.m`.
- Prepare for eye-tracking integration by designing a dedicated MATLAB class rather than embedding subscriber logic directly into `BehaviorBoxWheel.m`.
- Preserve raw DLC timing fields in saved data even when a shared session `t_us` timestamp is added.

## Current DLC/ToMatlab outputs

The current `DLC/ToMatlab/` code does not yet produce a saved MATLAB table aligned to microscope frames.
It currently produces a live stream and optional sidecar outputs:

### ZeroMQ JSON stream from `dlc_eye_streamer.py`

Per processed frame, the Python publisher emits a JSON payload with:

- `source`
- `frame_id`
- `capture_time_unix_s`
- `capture_time_unix_ns`
- `publish_time_unix_s`
- `publish_time_unix_ns`
- `camera_fps`
- `inference_fps`
- `latency_ms`
- `center_x`
- `center_y`
- `diameter_px`
- `diameter_h_px`
- `diameter_v_px`
- `confidence_mean`
- `valid_points`
- `points`

`points` is a dictionary of all DLC keypoints, each stored as `[x, y, likelihood]`.

### Optional CSV from `dlc_eye_streamer.py --csv`

If the Python streamer is run with `--csv`, it writes a CSV with these columns:

- `frame_id`
- `capture_time_unix_s`
- `publish_time_unix_s`
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

The CSV does not currently include the full `points` dictionary or the nanosecond fields.

### Live display output

If `--display` is enabled, the Python streamer opens a live overlay window that shows:

- DLC keypoints
- estimated center
- horizontal and vertical diameter axes
- frame id
- diameter
- center
- confidence
- camera FPS
- inference FPS
- latency

### MATLAB demo output

`receive_eye_stream_demo.m` subscribes to the latest ZeroMQ message and exposes a MATLAB struct named `eye` in the base workspace with:

- `eye.frame_id`
- `eye.capture_time_s`
- `eye.publish_time_s`
- `eye.x`
- `eye.y`
- `eye.diameter_px`
- `eye.confidence`
- `eye.latency_ms`

This is a demo subscriber only. It is not yet a production BehaviorBox integration.

## Recommended architecture

Create a new helper class named `BehaviorBoxEyeTrack.m`.

This class should be a narrow eye-tracking backend helper, not a new root workflow peer that owns trial logic.
`BehaviorBoxWheel.m` should remain the owner of:

- trial state
- display state
- reward logic
- frame alignment
- session save outputs

`BehaviorBoxEyeTrack.m` should own:

- subscription to the DLC ZeroMQ stream
- buffering of incoming eye samples
- conversion into the shared BehaviorBox session clock
- storage of raw dense eye samples
- eye-tracking connection state and metadata

## Clocking strategy

`BehaviorBoxEyeTrack.m` should not invent an independent experiment clock.
It should share the same session timebase that BehaviorBox already uses for:

- microscope frames
- wheel/display events
- parsed timestamp annotations

Each eye sample should preserve both:

1. raw DLC time fields from the source stream
2. a canonical BehaviorBox session timestamp, `t_us`

This should allow later realignment or clock-quality checks without changing saved schema.

## Why a dedicated eye-tracking class is still useful

Even with a shared session clock, the eye stream is a separate dense data source with its own:

- transport
- buffering
- sample rate
- drop/staleness failure modes
- metadata

That logic should not live inline inside `BehaviorBoxWheel.m`.

## Proposed responsibilities for `BehaviorBoxEyeTrack.m`

### Owns

- Python environment / bridge setup if MATLAB uses `py.*`
- ZeroMQ subscriber creation and teardown
- buffering of latest sample and raw sample record
- session-clock stamping of received eye samples
- quality and health state such as stale stream or missing samples
- export of a session-wide raw eye table and metadata

### Does not own

- trial state machine logic
- reward logic
- stimulus logic
- `FrameAlignedRecord` construction
- microscope-specific logic

## Proposed API for `BehaviorBoxEyeTrack.m`

Minimal public methods:

- `connect()`
- `start()`
- `stop()`
- `close()`
- `setSessionClock(trainStartTime, trainStartWallClock)`
- `pollAvailable(currentTrial)`
- `getLatestSample()`
- `getRecord()`
- `getMeta()`
- `alignToFrames(frame_t_us)`

Optional convenience methods:

- `markTrial(trialNumber)`
- `clearTrialBuffer()`
- `isConnected()`
- `isStale(maxAgeMs)`

## Proposed saved outputs

### `EyeTrackingRecord`

This should be a dense session-wide MATLAB table with one row per received eye sample.

Recommended columns:

- `trial`
- `t_us`
- `capture_time_unix_s`
- `capture_time_unix_ns`
- `publish_time_unix_s`
- `publish_time_unix_ns`
- `frame_id`
- `x`
- `y`
- `diameter_px`
- `diameter_h_px`
- `diameter_v_px`
- `confidence`
- `valid_points`
- `camera_fps`
- `inference_fps`
- `latency_ms`
- `isValid`
- `sampleStatus`

Optional later columns if needed:

- `kp_top_x`, `kp_top_y`, `kp_top_p`
- `kp_bottom_x`, `kp_bottom_y`, `kp_bottom_p`
- `kp_left_x`, `kp_left_y`, `kp_left_p`
- `kp_right_x`, `kp_right_y`, `kp_right_p`
- `kp_center_x`, `kp_center_y`, `kp_center_p`

If the full `points` dictionary is important for later analysis, prefer flattening it into stable columns rather than saving a nested Python dict in MATLAB tables.

### `EyeTrackingMeta`

This should be a struct or scalar table with:

- source address
- stream backend
- model path
- point-name order
- session start wall clock
- session clock source
- sync strategy
- sync offset estimate
- stream start / stop times
- dropped sample or stale-stream counters

## Proposed `FrameAlignedRecord` extension

Do not put dense eye data into `screenEvent`.
Add explicit columns instead.

Recommended initial additive columns for `FrameAlignedRecord`:

- `eye_x`
- `eye_y`
- `eye_diameter_px`
- `eye_confidence`
- `eye_valid_points`
- `eye_latency_ms`
- `eye_sample_count`
- `eye_dt_us`
- `eye_isValid`

Meaning:

- `eye_x`, `eye_y`, `eye_diameter_px`, `eye_confidence`, `eye_valid_points`, `eye_latency_ms`
  copied from the aligned eye sample
- `eye_sample_count`
  number of eye samples falling in or before the frame bin, depending on alignment rule
- `eye_dt_us`
  difference between the frame time and the eye sample time used for that frame row
- `eye_isValid`
  compact validity flag for downstream analysis

## Alignment rule recommendation

Start simple and explicit:

- for each microscope frame, use the nearest previous eye sample in session `t_us`
- carry forward the scalar eye fields from that sample
- also store `eye_dt_us`

This mirrors the current display-state alignment strategy and makes timing quality visible.

Later, if needed, add:

- nearest-sample mode
- interval-summary mode
- interpolation for center position

## Integration points in existing code

Likely places to extend:

- `BehaviorBoxWheel` properties
  add `EyeTrack`, `EyeTrackingRecord`, and maybe `EyeTrackingMeta`
- session setup path
  create and initialize `BehaviorBoxEyeTrack`
- trial loop
  poll or append eye samples during the session
- save path
  save `EyeTrackingRecord` and `EyeTrackingMeta`
- `buildCurrentTrialFrameAlignedRecord_()`
  merge aligned eye columns into per-frame rows

## Recommended sequencing

### Phase 1: scaffolding only

1. Create `BehaviorBoxEyeTrack.m`.
2. Add empty-table and metadata helpers.
3. Add noninvasive save-path support for `EyeTrackingRecord` and `EyeTrackingMeta`.
4. Add additive empty eye columns to `FrameAlignedRecord`.

### Phase 2: live subscriber integration

1. Wrap the `DLC/ToMatlab` subscriber path inside `BehaviorBoxEyeTrack.m`.
2. Stamp each received eye sample into session `t_us`.
3. Save the dense raw eye record without changing frame alignment yet.

### Phase 3: frame alignment

1. Add a helper to align dense eye samples to frame timestamps.
2. Extend `buildCurrentTrialFrameAlignedRecord_()` to populate eye columns.
3. Keep display-event and eye alignment logic separate and additive.

### Phase 4: quality controls

1. Add stale-stream detection.
2. Add eye-sample validity and age metrics.
3. Add optional keypoint flattening if later analysis needs it.

## Invariants to preserve

- `TimestampRecord` remains the sparse event log.
- `WheelDisplayRecord` remains the dense wheel/display state log.
- `FrameAlignedRecord` remains the final per-frame derived table.
- Existing wheel/imaging timing behavior should not change when eye tracking is absent.
- Eye tracking should be additive and skippable if the DLC stream is offline.

## Outputs intentionally changed in the future

When this plan is implemented, expected additive outputs will be:

- `EyeTrackingRecord`
- `EyeTrackingMeta`
- additional eye columns in `FrameAlignedRecord`

The intended invariant is that existing wheel, reward, display, and microscope timing fields remain readable and keep their current meanings.

## Validation plan

### Static / structure

- confirm the new class can be constructed and torn down without changing existing wheel behavior
- confirm save output still succeeds when eye tracking is disabled

### DLC bridge smoke test

- run the Python DLC streamer
- run the MATLAB receiver path
- confirm eye samples are received and stamped with session `t_us`
- confirm `EyeTrackingRecord` grows over time

### Frame alignment smoke test

- run one short imaging session
- confirm `FrameAlignedRecord` includes the new eye columns
- confirm early rows use `NaN` or invalid flags if the eye stream is missing
- confirm valid rows show reasonable `eye_dt_us`

### Failure-mode smoke test

- run with no DLC streamer
- confirm session start, trial loop, save, and frame alignment still work
- confirm eye outputs remain empty/additive rather than crashing the session

## Open design choices

- Whether to name the class `BehaviorBoxEyeTrack.m` or `BehaviorBoxDlcEyeTrack.m`
- Whether to flatten all keypoints now or only save center / diameter initially
- Whether session `t_us` should use MATLAB receive time only at first, or estimate a better mapping from raw DLC capture time into the session clock

## Recommended next action

Implement the scaffolding only:

1. `BehaviorBoxEyeTrack.m`
2. `EyeTrackingRecord`
3. `EyeTrackingMeta`
4. additive empty eye columns in `FrameAlignedRecord`

That keeps the schema stable before live DLC subscription logic is added.
