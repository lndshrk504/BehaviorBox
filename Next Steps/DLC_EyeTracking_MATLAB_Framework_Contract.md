# DLC Eye Tracking MATLAB Framework Contract

Date: 2026-04-16

This document defines the implementation contract for the production eye
tracking framework. The goal is to capture every DeepLabCut output sample that
is delivered by the DLC wrapper, timestamp those samples in the BehaviorBox
session timebase, save the dense eye record, and derive aligned eye columns for
both microscope-frame rows and display-state rows.

This plan supersedes the older DLC eye-tracking frame-alignment plan in this
folder.

## Active Path

The active eye-tracking path is:

- `EyeTrack/DeepLabCut/ToMatlab/dlc_eye_streamer.py`
- `EyeTrack/DeepLabCut/ToMatlab/matlab_zmq_bridge.py`
- `BehaviorBoxEyeTrack.m`
- `BehaviorBoxWheel.m`
- `BehaviorBoxSerialTime.m`

Do not use legacy `iRecHS2/` code or the historical smoke scripts in
`EyeTrack/DeepLabCut/Tests/` as production implementation paths.

## Core Decisions

- FLIR camera frames may be dropped before DLC inference. The FLIR camera can
  produce around 300 FPS on the development machine, which is far above the
  display and microscope frame rates.
- DLC output samples must not be silently dropped after inference.
- `EyeTrackingRecord` is the dense, lossless record of DLC output samples.
- `FrameAlignedRecord` is a derived microscope-frame table and is inherently
  lossy with respect to the higher-rate eye stream.
- `WheelDisplayRecord` remains a compact state-change record. It should not be
  expanded into redundant 60 Hz rows when nothing changes on screen.
- Eye data should be joined into both `FrameAlignedRecord` and
  `WheelDisplayRecord` using a shared alignment helper that tolerates variable
  eye-tracking frame rates.
- Eye tracking must be non-blocking for behavior training. A training session
  can continue if eye tracking is unavailable.
- Eye tracking startup and runtime failures must not be silent. MATLAB console
  output and saved metadata must report the failure.
- No backward compatibility is required for previous eye-tracking dry runs.
  The naming and schema created now become the future standard.

## Behavioral Contract

### What Must Be Lossless

The lossless unit is one DLC output sample, not one raw FLIR camera frame.

Every successfully processed DLC pose emitted by the Python streamer during a
connected production session must either:

1. appear in the MATLAB `EyeTrackingRecord`, or
2. be marked as missing by explicit frame-ID gap detection and saved metadata.

There must be no silent loss after DLC inference.

### What May Be Lossy

The following derived outputs may be lossy:

- `FrameAlignedRecord`
- `WheelDisplayRecord` with eye columns
- any per-frame or per-display summary columns

Those records are analysis conveniences. They must not be the only saved copy
of the eye stream.

## Timestamp Standard

`BehaviorBoxSerialTime.m` provides the model for this design: raw incoming
hardware messages are preserved, parsed, and converted into the shared
BehaviorBox session clock.

`BehaviorBoxEyeTrack.m` should follow the same pattern.

### Required Eye Timestamps

Each eye sample must save:

- `t_us`: canonical eye sample time in the BehaviorBox session clock
- `t_receive_us`: MATLAB receive time in the BehaviorBox session clock
- `capture_time_unix_s`
- `capture_time_unix_ns`
- `publish_time_unix_s`
- `publish_time_unix_ns`
- `latency_ms` from the Python streamer

The preferred canonical `t_us` is the FLIR capture time mapped into the
BehaviorBox session clock, not the MATLAB receive time.

### Session Clock Mapping

At session start, `BehaviorBoxWheel.m` owns:

- `TrainStartTime`
- `TrainStartWallClock`

`BehaviorBoxSerialTime.m` and `BehaviorBoxEyeTrack.m` must share this same
session clock.

When the first eye sample is received, `BehaviorBoxEyeTrack.m` must save an
anchor in `EyeTrackingMeta`:

- first DLC `capture_time_unix_ns`
- first sample `t_receive_us`
- session `TrainStartWallClock`
- estimated first-sample `t_us`
- first-sample receive lag, `t_receive_us - t_us`

For each later sample:

```text
t_us = capture_time_unix_ns converted into microseconds relative to TrainStartWallClock
```

`t_receive_us` remains available as the MATLAB-side receive timestamp.

The implementation should use the explicit conversion:

```matlab
session_start_unix_us = round(posixtime(TrainStartWallClock) * 1e6);
capture_unix_us = round(double(capture_time_unix_ns) / 1000);
t_us = capture_unix_us - session_start_unix_us;
```

Unix nanosecond values should be stored as `int64` in MATLAB when practical. If
MATLAB table or JSON handling makes `int64` unsafe for a specific field, store
the raw nanosecond value as a string and save a derived double microsecond value
for calculations.

This clock mapping assumes the Python streamer and MATLAB are using the same
machine clock, or clocks with negligible offset. If a future Jetson or remote
computer runs the streamer, production use requires either clock synchronization
or an explicit offset-calibration handshake.

This preserves the scientifically relevant camera capture time while still
making transport and inference latency auditable.

## DLC Naming Standard

The DLC model is the naming authority.

MATLAB must use the same point names emitted by the Python streamer. For the
current YangLab pupil model, the point order is:

- `Lpupil`
- `LDpupil`
- `Dpupil`
- `DRpupil`
- `Rpupil`
- `RVpupil`
- `Vpupil`
- `VLpupil`

The typo `RVupil` must not be used in the production schema.

The Python payload should carry the canonical point-name order, model preset,
model path, and model type. `BehaviorBoxEyeTrack.m` should use those names when
constructing the MATLAB record rather than relying on an unrelated hardcoded
default.

## Coordinate Frame Contract

Eye-tracking coordinates must explicitly state which image coordinate frame they
use. This matters because the FLIR camera can use a hardware sensor ROI and the
DLC wrapper can also use a software crop before inference.

Production standard:

- Saved `center_x`, `center_y`, and `<point_name>_x/y` columns use acquired FLIR
  frame coordinates.
- Acquired FLIR frame coordinates mean `(0, 0)` is the upper-left pixel of the
  frame delivered to Python after the FLIR `sensor_roi` has been applied.
- These saved coordinates should not silently switch to raw DLC crop-relative
  coordinates. If DLC inference runs on a software crop, the Python streamer
  must convert crop-relative DLC output back into acquired-frame coordinates
  before publishing and writing CSV rows.
- `sensor_roi` and `crop` must be saved in metadata so coordinates can later be
  mapped to full camera sensor coordinates if needed.

Coordinate relationship:

```text
acquired_frame_x = dlc_crop_x + crop_x1
acquired_frame_y = dlc_crop_y + crop_y1
full_sensor_x = acquired_frame_x + sensor_roi_x
full_sensor_y = acquired_frame_y + sensor_roi_y
```

If DLCLive already returns acquired-frame coordinates when a crop is used, the
Python streamer must not add the crop offset a second time. This should be
verified during implementation with a small coordinate sanity test in the
preview window and CSV output.

## Dense Saved Record

### `EyeTrackingRecord`

`EyeTrackingRecord` is the authoritative dense MATLAB table. It must contain
one row per received DLC output sample.

Required scalar columns:

- `trial`
- `t_us`
- `t_receive_us`
- `frame_id`
- `capture_time_unix_s`
- `capture_time_unix_ns`
- `capture_time_unix_ns_text` if `int64` transport is unsafe
- `publish_time_unix_s`
- `publish_time_unix_ns`
- `publish_time_unix_ns_text` if `int64` transport is unsafe
- `source`
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

Example MATLAB schema for required scalar columns:

| Column | MATLAB type | Notes |
| --- | --- | --- |
| `trial` | `double` | Numeric trial. Trial 0 during setup/screen-settle period. Use `NaN` for final drain samples after stop/save. |
| `t_us` | `double` | Capture-time timestamp mapped into BehaviorBox session time. |
| `t_receive_us` | `double` | MATLAB receive time in BehaviorBox session time. |
| `frame_id` | `double` | DLC output frame ID from Python. |
| `capture_time_unix_s` | `double` | Raw Python capture wall-clock seconds. |
| `capture_time_unix_ns` | `int64` | Preferred raw Python capture wall-clock nanoseconds. |
| `capture_time_unix_ns_text` | `string` | Fallback exact representation if needed. |
| `publish_time_unix_s` | `double` | Raw Python publish wall-clock seconds. |
| `publish_time_unix_ns` | `int64` | Preferred raw Python publish wall-clock nanoseconds. |
| `publish_time_unix_ns_text` | `string` | Fallback exact representation if needed. |
| `source` | `string` | Stream source identifier. |
| `center_x`, `center_y` | `double` | Derived pupil center in DLC image coordinates. |
| `diameter_px` | `double` | Derived pupil diameter estimate. |
| `diameter_h_px`, `diameter_v_px` | `double` | Horizontal and vertical diameter estimates. |
| `confidence_mean` | `double` | Mean likelihood/confidence across valid points. |
| `valid_points` | `double` | Count of points passing likelihood and finite-value checks. |
| `camera_fps`, `inference_fps` | `double` | Python-side rate estimates. |
| `latency_ms` | `double` | Python-side capture-to-publish latency. |
| `is_valid` | `logical` | Compact validity flag. |
| `sample_status` | `string` | `ok`, `partial_points`, `missing_points`, `invalid_json`, or other status. |

Required point columns:

- one `<point_name>_x` column per DLC point
- one `<point_name>_y` column per DLC point
- one `<point_name>_likelihood` column per DLC point

For the current model this means columns such as:

- `Lpupil_x`
- `Lpupil_y`
- `Lpupil_likelihood`
- `RVpupil_x`
- `RVpupil_y`
- `RVpupil_likelihood`

The older `points_xyp` cell matrix may be kept internally if it is useful, but
the saved production table should expose stable point-specific columns so the
raw data are readable and easy to join.

### `EyeTrackingMeta`

`EyeTrackingMeta` must save:

- ZMQ address or transport address
- stream source mode
- Python executable
- bridge directory
- model path
- model preset
- model type
- point-name order
- camera model
- camera serial number
- sensor ROI
- DLC crop
- CSV sidecar path, if any
- session clock source
- session start wall clock
- first capture timestamp anchor
- first receive timestamp anchor
- sample count
- first and last DLC frame ID
- missing DLC frame count
- maximum DLC frame ID gap
- duplicate DLC frame count
- timer or polling configuration
- last error message
- connection start and stop wall-clock times
- whether startup succeeded
- whether runtime gaps were detected
- `StaleThresholdSeconds`, default `2.0`
- stale stream event count
- last stale start time in session microseconds
- last fresh sample time in session microseconds
- last fresh DLC frame ID
- whether the startup ready condition was met
- whether the CSV sidecar was present and writable

## Python Payload Metadata Contract

The Python streamer should publish a metadata message when the stream starts and
should also include a small stable metadata subset with every sample.

The startup metadata message must be distinguishable from sample messages by
message fields:

- `message_type = "metadata"`
- `schema_version = 1`

The startup metadata message should include:

- `message_type`
- `schema_version`
- `model_path`
- `model_preset`
- `model_type`
- `point_names`
- `camera_model`
- `camera_serial`
- `sensor_roi`
- `crop`
- `csv_path`
- `stream_start_unix_ns`

Each sample must be distinguishable from metadata messages by message fields:

- `message_type = "sample"`
- `schema_version = 1`

Each sample should include at least:

- `message_type`
- `schema_version`
- `model_preset`
- `model_type`
- `point_names`
- `camera_serial`
- `sensor_roi`
- `crop`
- `csv_path`

Repeating this small metadata subset in every sample makes individual samples
self-describing and protects against missing a separate startup metadata
message.

## Transport Contract

The current live bridge uses a latest-only ZeroMQ subscriber. That is not
acceptable for production eye tracking.

The production bridge must drain all queued samples.

Required changes for implementation:

- `dlc_eye_streamer.py` must not configure the published DLC output in a way
  that silently drops post-DLC samples under normal expected load.
- `matlab_zmq_bridge.py` must provide a receive function that returns all
  currently queued JSON messages, not only the latest message.
- `BehaviorBoxEyeTrack.m` must process every returned message per poll.
- MATLAB polling may run slower than the eye stream as long as queued messages
  are drained in batches and frame-ID continuity is preserved.
- The receiver must detect and report frame-ID gaps.
- Any DLC `frame_id` gap after the first valid sample must increment
  `MissingFrameCount`, print a MATLAB warning, and be saved in
  `EyeTrackingMeta`.
- `PUB/SUB` is acceptable only if validation proves no missing frame IDs at the
  expected production DLC output rate. Otherwise production must switch to a
  lossless or backpressure-capable transport.

If PUB/SUB high-water-mark tuning is not sufficient to guarantee no post-DLC
loss, the transport should be changed to a lossless or backpressure-capable
pattern for production, such as PUSH/PULL with bounded buffering plus explicit
drop detection.

The Python CSV sidecar is required during production rollout and its path must
be saved in `EyeTrackingMeta`. Later, after the MATLAB receive path has been
validated in production, the CSV sidecar may become optional. The MATLAB
`EyeTrackingRecord` remains the target production record.

CSV sidecar requirements during rollout:

- one row per DLC output sample
- `frame_id`
- capture and publish timestamps
- scalar eye metrics
- all DLC point columns using the same point names as MATLAB
- enough fields to audit DLC output continuity against `EyeTrackingRecord`

The CSV does not need MATLAB-only fields such as trial assignment, but it must
be sufficient to verify that MATLAB did not miss post-DLC samples.

## MATLAB Receiver Contract

`BehaviorBoxEyeTrack.m` should behave like an eye-stream equivalent of
`BehaviorBoxSerialTime.m`.

It owns:

- bridge setup
- stream connection
- polling or callback-based receive loop
- batch draining of queued messages
- raw message capture when practical
- parsing into a dense table
- session-clock timestamping
- point-name fidelity
- frame-ID continuity checks
- metadata and health status

It does not own:

- trial logic
- reward logic
- display-state logic
- microscope frame parsing
- final trial decision logic

### Startup Readiness

A port-open check means an eye stream may be available, but it is not enough to
mark eye tracking as ready. Eye tracking is ready only after MATLAB receives and
parses at least one ready sample.

Ready sample rule:

```text
valid JSON + expected point names present + sample_status is "ok" or "partial_points"
```

When BehaviorBox attempts to connect, MATLAB should wait up to 2 seconds for one
ready sample. If no ready sample arrives within 2 seconds, behavior training
continues, MATLAB prints a visible warning, and `EyeTrackingMeta.Ready` remains
false.

The production assumption is that the Python streamer is started before
BehaviorBox, so data should already be streaming when MATLAB connects.

### Runtime Behavior

If the stream is unavailable at session start:

- behavior training continues
- MATLAB prints a visible warning to the console
- `EyeTrackingRecord` is saved as an empty table
- `EyeTrackingMeta` records the failure reason

If the stream fails during a session:

- behavior training continues
- MATLAB prints a visible warning to the console
- `EyeTrackingMeta` records the failure reason and last successful sample
- missing DLC frame IDs are counted if frame continuity can be assessed

Startup and runtime failures should not be swallowed by empty `catch` blocks.
They should be converted into warnings and saved metadata.

Recommended MATLAB warning IDs:

- `BehaviorBoxEyeTrack:StartupUnavailable`
- `BehaviorBoxEyeTrack:NotReady`
- `BehaviorBoxEyeTrack:StaleStream`
- `BehaviorBoxEyeTrack:FrameIdGap`
- `BehaviorBoxEyeTrack:RuntimeFailure`

### Stale Stream Detection

If eye tracking was correctly set up and at least one valid sample was received,
MATLAB should treat the stream as stale when no new eye sample has been received
for `StaleThresholdSeconds`. The default threshold is `2.0` seconds.

For each stale episode:

- MATLAB prints one visible warning to the console.
- warnings are not repeated every poll tick while the same stale episode is
  ongoing.
- the next valid sample ends the stale episode.
- `EyeTrackingMeta` records stale count, last stale start time, last fresh
  sample time, last fresh frame ID, and the stale threshold.

### MATLAB Storage And Performance Strategy

`BehaviorBoxEyeTrack.m` should not grow a MATLAB table one row at a time during
long sessions. Imaging sessions can last up to 2 hours. At 100 Hz, that is up
to roughly 720,000 DLC output samples before considering setup time, and each
sample will include scalar fields plus flattened DLC point columns.

The receiver should buffer parsed samples in chunks and convert those chunks
into the final `EyeTrackingRecord` table when saving or at controlled flush
points. The preferred representation is column-oriented chunk buffers because
MATLAB stores numeric, logical, and string arrays efficiently by column. A chunk
can be a struct whose fields are column vectors or cell/string arrays, for
example one chunk containing 5,000-10,000 samples.

A practical chunk should store fields such as:

- `trial` as a double vector
- `t_us` and `t_receive_us` as double vectors
- frame IDs and scalar metrics as double vectors
- validity flags as logical vectors
- statuses and source strings as string arrays
- flattened point columns as double vectors

`getRecord()` or the save path should concatenate chunk columns and construct
the final MATLAB table once, rather than rebuilding a table on every received
sample. Raw JSON strings may be retained for short debugging windows, but the
production design should not require storing every raw JSON message indefinitely
if the parsed dense table contains all required fields.

Primary design: keep column-oriented chunks in memory during the session and
build the final table during save. A controlled flush point means an explicit,
non-lossy conversion or persistence step outside the per-sample hot path, such
as final save or a future periodic disk flush if memory pressure requires it.
Controlled flushes must preserve frame-ID continuity, metadata, and trial
assignment.

## Trial Assignment Contract

Eye sample trial assignment should use the BehaviorBox trial state associated
with the sample's canonical `t_us`, not simply the trial value at the moment
MATLAB drains a queued batch.

Required trial rules:

- Eye samples received during the setup phase and the 5-second screen-settle
  pause are assigned `trial = 0`.
- A new trial begins at the hold-still interval. That is the point where the
  trial count should be incremented for eye tracking.
- Intertrial periods are assigned to the trial that immediately preceded them.
- Batch draining must preserve this rule even if queued samples are parsed after
  the trial state has advanced.
- When the BehaviorBox stop button is hit and the save-all-data path is reached,
  `BehaviorBoxWheel.m` should do one final drain of all remaining queued eye
  output before building `EyeTrackingRecord`. These final-drain samples are saved
  with `trial = NaN`.

Exact boundary rule:

```text
sample.t_us < first_hold_still_start_t_us -> trial = 0
hold_still_start_t_us(trial N) <= sample.t_us < hold_still_start_t_us(trial N+1) -> trial = N
final drain after stop/save -> trial = NaN
```

## Derived Alignment Contract

Dense eye data must be preserved first. Alignment helpers operate on saved or
in-memory dense eye data.

### Shared Alignment Helper

Create one shared helper that can join eye samples into any target table with a
session-clock timestamp column.

Conceptual API:

```matlab
targetWithEye = alignEyeSamplesToTable(eyeRecord, targetTable, options)
```

Required options:

- target time column, default `t_us`
- alignment mode, default `previous`
- supported alignment modes: `previous` and `interval_summary`
- maximum accepted absolute age, optional
- eye-column prefix, default `eye_`
- whether to count all eye samples in the preceding interval

Required output behavior:

- target row count is unchanged
- eye columns are added or updated
- missing eye samples produce `NaN` values and `eye_is_valid = false`
- `eye_dt_us` makes timing quality visible
- `previous` alignment is the default production behavior for now
- `interval_summary` is available as an optional analysis method

The canonical alignment mode is intentionally not finalized in this contract.
Both modes should be implemented so the default `previous` mode can be compared
against `interval_summary` on real sessions before choosing the long-term
standard.

### Alignment Modes

#### `previous` Mode

`previous` mode assigns each target row one representative eye sample: the most
recent eye sample whose `t_us` is less than or equal to the target row `t_us`.

This mode is simple, readable, and conservative. It is the default mode until
production data show whether another mode should become canonical.

`previous` mode should save at least:

- representative `eye_frame_id`
- representative `eye_t_us`
- `eye_dt_us = target.t_us - eye.t_us`
- scalar eye fields from that representative sample
- `eye_sample_count` for the relevant target interval when available

#### `interval_summary` Mode

`interval_summary` mode summarizes every eye sample that falls inside the target
row interval. It is optional, but should be implemented alongside `previous` so
it can be evaluated on real data.

This mode is useful because eye tracking can run faster than microscope frames
and display-state changes. A single representative sample is easy to inspect,
but a summary of all samples in the interval better preserves what happened
during that frame or display state.

Recommended interval-summary columns include:

- `eye_sample_count`
- `eye_frame_id_first`
- `eye_frame_id_last`
- `eye_t_us_first`
- `eye_t_us_last`
- `eye_center_x_mean`
- `eye_center_y_mean`
- `eye_center_x_median`
- `eye_center_y_median`
- `eye_diameter_px_mean`
- `eye_confidence_mean_interval`
- `eye_valid_fraction`

The dense `EyeTrackingRecord` remains the source of truth. Interval summaries
are derived convenience columns, not a replacement for the raw eye samples.

### Frame-Aligned Rule

For each microscope frame row in `FrameAlignedRecord`, use the eye sample with
the largest `eye.t_us` such that:

```text
eye.t_us <= frame.t_us
```

This assigns each frame the most recent eye sample captured before that
microscope frame was recorded.

Also save:

- the representative eye sample DLC `frame_id`
- the representative eye sample `t_us`
- `eye_dt_us = frame.t_us - eye.t_us`
- the count of all eye samples in `(previous_frame.t_us, frame.t_us]`

This makes the frame-aligned record easy to read while preserving the full
dense eye record elsewhere.

For optional `interval_summary` mode, each microscope frame row should summarize
eye samples in:

```text
previous_microscope_frame.t_us < eye.t_us <= current_microscope_frame.t_us
```

For the first microscope frame, the interval starts at session start. Eye
samples before the first frame remain in `EyeTrackingRecord` even if they do not
contribute to a frame interval.

### Display-State Rule

`WheelDisplayRecord` remains a state-change record. It should not be expanded
to 60 Hz when the screen content did not change.

For each row in `WheelDisplayRecord`, use the same shared alignment helper to
attach the closest appropriate eye sample to that display-state timestamp.

Default `previous` rule:

```text
eye.t_us <= display_row.t_us
```

For optional `interval_summary` mode, each display row should summarize the eye
samples collected while that display state was active:

```text
display_row.t_us <= eye.t_us < next_display_row.t_us
```

For the last display row, the interval ends at session stop or save time. Eye
samples outside display-state intervals remain in `EyeTrackingRecord`.

The helper may support `nearest` or `next` alignment later if a specific
analysis needs that, but those modes are not part of the required production
contract today.

## Proposed Eye Columns For Derived Tables

Use names that preserve the DLC terminology and avoid ambiguous generic names.

Representative-sample columns for both `FrameAlignedRecord` and saved
`WheelDisplayRecord`:

- `eye_frame_id`
- `eye_t_us`
- `eye_dt_us`
- `eye_center_x`
- `eye_center_y`
- `eye_diameter_px`
- `eye_diameter_h_px`
- `eye_diameter_v_px`
- `eye_confidence_mean`
- `eye_valid_points`
- `eye_latency_ms`
- `eye_sample_count`
- `eye_is_valid`
- `eye_sample_status`

Optional interval-summary columns for both derived records:

- `eye_frame_id_first`
- `eye_frame_id_last`
- `eye_t_us_first`
- `eye_t_us_last`
- `eye_center_x_mean`
- `eye_center_y_mean`
- `eye_center_x_median`
- `eye_center_y_median`
- `eye_diameter_px_mean`
- `eye_confidence_mean_interval`
- `eye_valid_fraction`

The existing placeholder names such as `eye_x`, `eye_y`, and `eye_confidence`
should be replaced by the clearer names above.

## BehaviorBoxWheel Integration Points

`BehaviorBoxWheel.m` remains the owner of the training session and final saved
outputs.

Required integration points:

1. Session initialization creates or discovers `BehaviorBoxEyeTrack`.
2. Session start passes `TrainStartTime` and `TrainStartWallClock` to
   `BehaviorBoxEyeTrack`.
3. Trial changes call `markTrial`.
4. The eye receiver drains queued samples during the session.
5. Save output includes dense `EyeTrackingRecord`.
6. Save output includes `EyeTrackingMeta`.
7. `FrameAlignedRecord` is populated from the dense eye record using the shared
   alignment helper.
8. Saved `WheelDisplayRecord` is populated from the dense eye record using the
   same helper.
9. When stop/save is reached, `BehaviorBoxWheel.m` drains all remaining queued
   eye samples and marks final-drain samples with `trial = NaN`.
10. Eye tracking absence does not prevent session save.
11. Eye tracking absence or failure produces visible MATLAB console output.

## Implementation Phases

### Phase 1: Contract And Schema Standardization

- Adopt canonical DLC point names.
- Remove the `RVupil` typo from MATLAB code and tests.
- Define final `EyeTrackingRecord` variable names.
- Define final derived eye-column names.
- Define final `EyeTrackingMeta` fields.
- Define final MATLAB table variable types for `EyeTrackingRecord`.
- Define `message_type` and `schema_version` fields for metadata and sample
  messages.
- Define coordinate-frame normalization and metadata fields.

### Phase 2: Lossless MATLAB Receive Path

- Add an all-queued-message receive function to `matlab_zmq_bridge.py`.
- Change `BehaviorBoxEyeTrack.m` from latest-only receive to batch draining.
- Increase or redesign ZMQ buffering so post-DLC samples are not silently lost.
- Add frame-ID continuity checks.
- Add visible MATLAB warnings for startup, runtime failure, stale stream
  episodes, and detected frame-ID gaps.

### Phase 3: Timestamp Mapping

- Map Python `capture_time_unix_ns` into BehaviorBox session `t_us`.
- Preserve MATLAB `t_receive_us`.
- Save first-sample clock anchors in `EyeTrackingMeta`.
- Save receive lag and timing-quality fields.

### Phase 4: Dense Eye Record

- Save one MATLAB row per DLC output sample.
- Flatten every DLC point into stable `<point>_x`, `<point>_y`, and
  `<point>_likelihood` columns.
- Store model, point-name, coordinate-frame, and streamer metadata.
- Compare MATLAB frame IDs against the required Python CSV sidecar during smoke
  tests.
- Buffer samples in column-oriented chunks before final table conversion.
- Design storage for imaging sessions up to 2 hours.

### Phase 5: Derived Joins

- Implement the shared eye-alignment helper.
- Implement `previous` alignment as the default mode.
- Implement `interval_summary` alignment as an optional mode.
- Populate `FrameAlignedRecord` eye columns from dense eye samples.
- Populate saved `WheelDisplayRecord` eye columns from dense eye samples.
- Preserve target table row counts.
- Keep the canonical alignment mode undecided until real-session outputs can be
  compared.

### Phase 6: Production Validation

- Run with no eye streamer and confirm training continues with visible warning.
- Run with the streamer and confirm MATLAB receives every DLC frame ID.
- Confirm `EyeTrackingRecord` count matches Python CSV row count for a short
  test.
- Confirm `FrameAlignedRecord.eye_dt_us` is nonnegative under the default
  previous-sample rule.
- Confirm `interval_summary` mode preserves target table row counts while
  adding interval sample counts and summary fields.
- Confirm `WheelDisplayRecord` remains state-change based.
- Confirm metadata includes camera serial, model path, CSV path, point names,
  first/last frame IDs, missing-frame counters, and stale-stream counters.
- Confirm eye tracking is not marked ready until MATLAB receives one ready
  sample within the 2-second readiness timeout.
- Confirm setup-phase samples are trial 0, intertrial samples stay assigned
  to the preceding trial, and final-drain samples use `trial = NaN`.
- Confirm chunked buffering can represent a 2-hour session without row-by-row
  table growth during live acquisition.

## Acceptance Criteria

The production framework is complete when:

- A behavior session can run with eye tracking enabled.
- A behavior session can run with eye tracking unavailable.
- MATLAB reports eye tracking startup failure visibly when the stream is absent.
- MATLAB reports one warning per stale-stream episode when no new eye sample is
  received for 2 seconds after eye tracking was ready.
- `EyeTrackingRecord` contains every received DLC output sample.
- DLC frame ID gaps are detected and saved.
- Canonical DLC point names are preserved in MATLAB.
- The typo `RVupil` is gone from the production standard.
- `EyeTrackingRecord.t_us` uses camera capture time mapped to the BehaviorBox
  session clock.
- `EyeTrackingRecord.t_receive_us` preserves MATLAB receive time.
- `FrameAlignedRecord` contains derived eye columns for microscope frame rows.
- Saved `WheelDisplayRecord` contains derived eye columns for display-state
  rows.
- `previous` alignment is implemented as the default derived-join mode.
- `interval_summary` alignment is implemented as an optional derived-join mode.
- The dense eye record is saved separately from the derived aligned records.
- A short validation run shows MATLAB `EyeTrackingRecord.frame_id` continuity
  and agrees with the required Python CSV sidecar.
- Eye tracking is marked ready only after MATLAB receives one ready sample
  within the 2-second readiness timeout, not merely after a port-open check.
- `BehaviorBoxEyeTrack` stores live samples in column-oriented chunks and only
  builds the final `EyeTrackingRecord` table at save time or controlled flush
  points.
- Stop/save performs a final drain of queued eye samples and saves those
  final-drain rows with `trial = NaN`.

## Open Risks To Monitor

- PUB/SUB may still drop messages if MATLAB falls behind and high-water marks
  are exceeded.
- MATLAB table growth row by row may become a bottleneck during long sessions
  up to 2 hours.
- Trial assignment can be wrong if queued samples are labeled with the current
  MATLAB trial instead of the sample's canonical timestamp.
- MATLAB timer callbacks may fall behind if JSON decoding is too slow.
- Python and MATLAB wall-clock conversion assumes both timestamps come from the
  same machine clock or clocks with negligible offset.
- If a future Jetson emits eye tracking at a much lower and more variable rate,
  alignment must tolerate sparse eye samples without invalidating the session.

## Risk Mitigations

- Batch-drain the receiver instead of polling one sample at a time.
- Buffer parsed samples in column-oriented chunks before converting to MATLAB
  tables.
- Label eye samples by timestamp-defined trial intervals, not by the trial value
  at batch-drain time.
- Save missing-frame counters and maximum frame-ID gap.
- Keep the Python CSV sidecar during production rollout as an independent audit
  trail.
- Use explicit `eye_dt_us` and `eye_sample_count` fields in derived tables.
- Treat `EyeTrackingRecord` as the source of truth for eye data.
- Treat `FrameAlignedRecord` and `WheelDisplayRecord` eye columns as derived,
  convenient summaries.
