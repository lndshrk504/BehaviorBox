# Deferred Python Eye-Ingest Pipeline For Training And Mapping

## Summary
Create a new external Python eye receiver on the behavior computer and remove live eye ingest/parsing from MATLAB hot loops. Python will own ZeroMQ subscription, behavior-computer receive-time stamping, chunk persistence, and lightweight status/control. MATLAB will import completed eye chunks outside hot loops, store per-segment eye tables in `EyeTrackRecord`, and build `EyeTrackingRecord`, `FrameAlignedRecord`, and `EyeAlignedRecord` after the fact.

This plan applies to both training and mapping and keeps their eye-data mechanisms as similar as possible. In v1, receive time on the behavior computer is the canonical eye timebase.

## Implementation Changes

### 1. External Python receiver
- Add a new receiver under `/Users/willsnyder/Desktop/BehaviorBox/EyeTrack/DeepLabCut/ToMatlab` that:
  - subscribes to the existing eye ZeroMQ publisher
  - stamps each sample with behavior-computer receive time
  - writes append-only chunk files to a session-specific raw-eye folder under the subject save tree
  - exposes a localhost control/status API for MATLAB
- MATLAB does not launch this process. It is started manually before the session.
- The receiver keeps raw chunk files after save and exposes their paths in its manifests.
- If the receiver stops mid-session, BehaviorBox warns and continues.

### 2. MATLAB eye client rewrite
- Refactor `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxEyeTrack.m` so it no longer owns:
  - the MATLAB timer
  - direct ZeroMQ polling
  - pyenv-based live receive
- New MATLAB responsibilities:
  - connect to the local Python receiver API
  - open and close eye sessions
  - notify Python of training trial boundaries and mapping segment boundaries
  - import completed chunk files only outside hot loops
  - normalize imported chunks into MATLAB tables
  - combine imported segment tables into final save outputs
  - perform alignment after import
- Preserve raw timing columns from Python:
  - behavior receive time
  - remote capture time
  - remote publish time
- Hardcode receive-time alignment in v1 and record that choice in metadata.

### 3. Shared training and mapping segment model
- Add `EyeTrackRecord` as a cell property in `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`.
- Each `EyeTrackRecord{idx}` cell contains one imported MATLAB table for one closed eye segment:
  - training: one cell per trial
  - mapping: one cell per mapping run segment, default one cell for the whole run
- Add `EyeTrackSegmentMeta` in parallel with:
  - session id
  - segment kind
  - trial number
  - mapping mode
  - scanImage file index
  - segment start and end receive-time bounds
  - raw chunk file paths
  - import status and partial-data flags
- Use the same session, segment, finalize, and import workflow for both training and mapping.
- Only the timing differs:
  - training imports closed-trial eye chunks during intertrial, then does a final backlog flush at session end
  - mapping imports chunks after the mapping run stops, then saves

### 4. Hot-loop constraints
- Remove all eye parsing, JSON decoding, table growth, and alignment from:
  - training wheel response loops
  - mapping animation loops
- During hot loops, MATLAB may only:
  - update display
  - read wheel or other input
  - handle microscope timestamp callbacks
  - record lightweight trial or segment boundary markers it already owns
- Use the `BehaviorBoxSerialTime` pattern conceptually:
  - raw durable data first
  - parsed tables later
  - alignment later

### 5. Training and mapping save behavior
- Both training and mapping saves should include:
  - `EyeTrackRecord`
  - `EyeTrackSegmentMeta`
  - combined `EyeTrackingRecord`
  - `EyeTrackingMeta`
- `FrameAlignedRecord` and `EyeAlignedRecord` remain derived outputs.
- Build aligned tables from:
  - microscope frame timestamps
  - screen-event records
  - imported eye tables
- Save-order behavior should be normalized:
  - import and finalize eye data while the receiver session is still active
  - save outputs
  - then close the session cleanly
- Do not stop or disconnect the eye path before save if that risks losing backlog.

### 6. Timebase and alignment rules
- Use receive time on the behavior computer as the canonical eye alignment time in v1.
- Keep remote capture and publish timestamps in raw eye rows for provenance and future comparison.
- Use the same alignment rules for training and mapping wherever possible.
- If no eye data exists, omit `EyeAlignedRecord`.
- If no microscope frames exist, omit `FrameAlignedRecord`.

### 7. Python and MATLAB handoff
- Use both:
  - append-only chunk files for durable raw storage
  - localhost IPC/control for session state, segment state, and import manifests
- Python should tag samples with session and segment information from MATLAB control messages.
- MATLAB should still verify or reassign segment membership at import time using its own boundary times if needed.

## Interfaces And Data Contracts
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
  - add `EyeTrackRecord`
  - add `EyeTrackSegmentMeta`
  - replace live eye polling with receiver-session registration and deferred import and finalize calls
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxEyeTrack.m`
  - becomes the MATLAB-side receiver client, importer, and aligner
- New Python receiver in `/Users/willsnyder/Desktop/BehaviorBox/EyeTrack/DeepLabCut/ToMatlab`
  - chunk writer
  - localhost control and status API
  - session and segment tagging
- Saved session schema additions:
  - `EyeTrackRecord`
  - `EyeTrackSegmentMeta`
  - updated `EyeTrackingMeta` fields describing receiver status, raw chunk locations, and receive-time alignment

## Test Plan
- Python receiver smoke test with a fake local publisher:
  - verify chunk files are written
  - verify status and manifests are exposed correctly
- MATLAB import smoke test:
  - import chunk files into segment tables
  - preserve exact DLC point columns and raw timing fields
- Training integration test:
  - no eye ingest or parsing inside the wheel hot loop
  - intertrial import populates `EyeTrackRecord{trial}`
  - final save contains `EyeTrackRecord`, `EyeTrackingRecord`, `EyeTrackingMeta`, and aligned outputs when available
- Mapping integration test:
  - no eye ingest or parsing inside mapping animation loops
  - post-stop import populates `EyeTrackRecord`
  - final save contains the same eye outputs as training
- Failure tests:
  - receiver absent at session start
  - receiver dies mid-session
  - microscope frames absent
  - eye data absent
- Timebase tests:
  - cross-computer clock offset does not break receive-time alignment
  - training and mapping both align off receive time consistently

## Assumptions And Defaults
- The external Python receiver is started manually before the session.
- v1 hardcodes receive-time alignment and does not add a GUI selector yet.
- `EyeTrackRecord` cells contain MATLAB tables, not raw JSON strings.
- Raw receiver chunk files are retained alongside session data for debugging and postmortem work.
- Training performs best-effort deferred processing during intertrial and always performs a final backlog flush at session end.
