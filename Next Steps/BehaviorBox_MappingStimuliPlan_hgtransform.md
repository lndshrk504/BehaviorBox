# BehaviorBox Mapping Stimuli Plan (hgtransform-based)

**Scope of this document:** planning + design audit only.  
**Not included yet:** no code changes, no diff/patch.  
**Primary constraint from PI/user:** **all new mapping stimulus modes must move graphics using `hgtransform`** (object transforms), not by moving axes or regenerating geometry.  
**Current preferred logging direction:** mapping events should be appended directly into `this.Time.Log` from MATLAB using `this.Time.Log(end+1,1) = ...`, rather than relying on Timekeeper stimulus-gate semantics or legacy parser compatibility.

**Repository:** `BehaviorBox-master.zip` (provided)  
**Target MATLAB files for later patch:**  
- `BehaviorBoxWheel.m` (orchestration, timing, ScanImage, mapping event logging)  
- `BehaviorBoxVisualStimulus.m` (stimulus figure + drawing primitives)  
- `BB_App.m` (GUI items / parameter plumbing)

---

## 0) Experimental goals and hard requirements

### 0.1 What the mapping animations are for
- Present basic visual stimuli on a MATLAB stimulus figure shown on a screen in front of the mouse.
- Stimuli are intended for V1 mapping (orientation/position receptive field characterization).

### 0.2 Imaging and timing constraints
- The mapping runner must start ScanImage acquisition **before any stimulus becomes visible**.
- After acquisition begins, enforce a **5 s settling pause** before any stimulus is shown.
- The screen may be on during the settling pause, but mapping stimuli must remain invisible.
- Once the sequence begins, the selected mapping mode should **loop continuously until the user presses Stop/Abort**.
- The mapping runner must clearly mark at least these events:
  - acquisition start
  - display on / mapping scene ready
  - settling pause start
  - settling pause end
  - stimulus sequence begins
  - stimulus sequence ends
  - per-epoch events as needed: flash on/off, sweep start/stop, looming peak, reward delivered, abort, etc.

### 0.3 Logging requirements
You want two logs:

1) **Combined timestamp/event log** (`this.Time.Log`)
- Contains frame timestamp lines arriving from `BehaviorBoxSerialTime`.
- Also contains mapping event markers appended directly from MATLAB code in `BehaviorBoxWheel`.
- Does **not** need to preserve compatibility with `MatchFramesToTimestamps.m`.
- Event lines should be structured so a new parser can read them reliably.

2) **Mapping animation log** (paired parameter trace)
- A separate table or struct containing time-stamped values such as:
  - x/y position
  - orientation
  - size/scale
  - brightness (fixation dot)
  - stimulus identity (mode, correct/incorrect)
- Must share a defined time origin with the mapping events written into `this.Time.Log`.
- Remains the best place for dense sampled state during sweeps / looming / dot fading.

### 0.4 Rendering/performance constraint
- **All motion must be performed using `hgtransform`** (set `hgtransform.Matrix`), not by moving axes or recreating plot objects each frame.
- Prefer "create once -> update transform/visibility/color" loops.

---

## 1) Current code architecture relevant to mapping modes

### 1.1 Timekeeper Arduino still matters for frame clocks, but not as the mapping event API
File: `Arduino/Timekeeper/Timekeeper.ino`

Observed behavior:
- Pin 3 rising edge (ScanImage frame clock) prints lines like:
  - `"<timestamp_us>, F <frameCount>"`
  - where `<timestamp_us>` is microseconds since the Arduino's current reference time
- Pin 2 change (stimulus gate) prints:
  - rising: `"S On-Frame reset <absolute_us>"`
  - falling: `"S Off <absolute_us>"`
  - rising also resets `frameCount=0` and resets the reference time `startTime`

**Implication:** The Arduino is still useful as the source of frame-clock lines, but the new mapping feature should **not** depend on its current stimulus-on/off implementation for event labeling. The preferred design is to log mapping events directly from MATLAB into `this.Time.Log`.

### 1.2 MATLAB timestamp collector already supports the mixed-log model
File: `BehaviorBoxSerialTime.m`

- Stores all received lines verbatim into `this.Log` (string array).
- `BehaviorBoxWheel.m` already appends human-readable strings directly into `this.Time.Log` in several places.
- This means the mapping runner can use the same pattern for direct event logging.

**Implication:** `this.Time.Log` should be treated as a **mixed-source log**:
- callback-driven frame timestamp lines from Timekeeper
- MATLAB-appended mapping event lines

The new analysis function should be written to parse that mixed log intentionally, rather than assuming all rows share the same origin or syntax.

### 1.3 Legacy analysis script is not a design constraint
File: `Imaging Analysis scripts/MatchFramesToTimestamps.m`

- This file was an early draft and later development has moved elsewhere.
- The new mapping implementation should **not** constrain event names, prefixes, or log grammar to satisfy it.
- A new reader/parser will be written for the output produced by the new mapping code.

**Implication:** We should choose the event format based on clarity and future parsing, not on preserving old `"S "` / `"Trial"` assumptions.

### 1.4 Existing `hgtransform` infrastructure in the stimulus renderer
File: `BehaviorBoxVisualStimulus.m`

- Already maintains pooled `hgtransform` groups:
  - `LStimGroup`, `RStimGroup` with Tag `StimulusTransform`
- Provides `getWheelMotionTargets()` so `BehaviorBoxWheel.readLeverLoopAnalogWheel()` can translate objects instead of axes.
- Uses pooled polyline graphics (NaN-separated segments) for contour and distractors.

**Opportunity:** Extend this exact pattern for mapping stimuli so mapping also uses pooled objects plus `hgtransform`.

### 1.5 Existing animation entry points and direct log appends
File: `BehaviorBoxWheel.m` + GUI in `BB_App.m`

- GUI animation dropdown currently lists: `Y-Line`, `X-Line`, `Bar`, `Stimulus`, `Dot`
- `BehaviorBoxVisualStimulus.DisplayOnScreen(..., AnimateMode=true, StimType=...)` routes to `PlotXLine/PlotYLine/PlotBar/PlotDot`
- `BehaviorBoxWheel.m` already uses direct log appends such as:
  - `this.Time.Log(end+1,1) = "Trial "+this.i;`
  - `this.Time.Log(end+1,1) = "Reward";`
  - `this.Time.Log(end+1,1) = "Stim off";`

**Plan direction:** Add new `StimType` values for mapping modes and add a dedicated mapping runner in `BehaviorBoxWheel` that follows the same direct-append logging pattern, but with a more structured format for future parsing.

---

## 2) Design principles for the new mapping modes

### 2.1 Create-once, transform-many
For each mapping mode:
- Create the stimulus graphics once (line(s), patches) in a stable axis.
- Parent all movable graphics under an `hgtransform` group (e.g. `MapGroup`).
- Animate by updating:
  - `MapGroup.Matrix` (translate/rotate/scale)
  - visibility (`Visible`)
  - color/brightness (`Color`, `FaceColor`)

### 2.2 A dedicated full-screen mapping axis
Mapping stimuli are not left/right choice stimuli. They should use a single coordinate space across the whole display.

**Implementation plan:**
- Add a new axis to `BehaviorBoxVisualStimulus`:
  - `MapAx` spanning `[0 0 1 1]` in normalized figure units
  - `XLim = [-1 1]`, `YLim = [-1 1]`
- Create one main `hgtransform` group under `MapAx`:
  - `MapGroup = hgtransform('Parent', MapAx, 'Tag', 'MappingTransform')`
- Create a separate transform for the fixation dot:
  - `FixGroup = hgtransform('Parent', MapAx, 'Tag', 'FixationTransform')`

**Why separate axis?**
- Avoid interference with `LStimAx/RStimAx` and existing wheel-task pooling logic.
- Avoid accidental wheel-motion parenting.
- Easier to define "x positions across the screen" for receptive field mapping.

### 2.3 Deterministic timing
Mapping is a calibration tool; reproducibility matters.

**Implementation plan:**
- Use a high-resolution MATLAB timer:
  - `t0 = tic;`
- Use one explicit MATLAB time origin for both:
  - event strings appended to `this.Time.Log`
  - rows in the mapping animation log

### 2.4 Reward gating (fixation dot)
Reward delivery must be:
- optional (enabled by checkbox)
- rate-limited (cooldown)
- logged in both:
  - `this.Time.Log` as discrete event lines
  - the mapping animation log as event/parameter rows

---

## 3) Proposed mapping modes

Below are the mapping modes you requested, expressed as concrete modes that will become `StimType` values (GUI dropdown items) and runnable sequences in `BehaviorBoxWheel`.

### 3.1 Mode A: Flash contour at discrete x-positions
**Goal:** identify cells responsive to contour at different horizontal locations.

**Stimulus geometry:**
- "Level 1 contour": 5 segments with spacing ("5-dashed line") in original vertical orientation.
- Implement as a single NaN-separated polyline so it is one `Line` object.
- Parent it under `MapGroup`.

**Animation:**
- Choose `N = 5` x positions across screen (`linspace(xMin,xMax,N)`).
- For each x position:
  - set transform translation to `[x, 0]`
  - set `Visible='on'` for `FlashDuration` (default 0.5 s)
  - set `Visible='off'`
  - wait `InterFlashInterval` (default 2.0 s)
- No smooth motion between positions; move while invisible.

**Optional fixation dot overlay:**
- Fixation dot runs concurrently. See Mode E.

**Logging:**
- Append structured event strings to `this.Time.Log`, such as:
  - `DisplayOn`
  - `SettleStart`
  - `SettleEnd`
  - `SequenceStart`
  - `FlashOn` with x position
  - `FlashOff`
  - `SequenceEnd`
- Also store corresponding rows in the mapping animation log.

### 3.2 Mode B: Sweep a vertical line across the display
**Goal:** map spatial receptive fields by moving an edge.

**Stimulus geometry:**
- Solid line spanning full Y range (e.g. from `y=-1` to `y=1`).
- Base geometry centered at origin; parent under `MapGroup`.

**Animation:**
- Start x at `xMin` (e.g. -1.2) and sweep to `xMax` (+1.2).
- Constant speed `SweepSpeed` (units: normalized-x per second).
- Update translation each frame: `x = x0 + SweepSpeed * t`
- Stop when x exceeds bounds.

**Control variables:**
- `SweepSpeed` should be GUI-controlled.
- `SweepDirection` optional.

**Implementation note:**
- This mode should use the shared `Map-SweepLine` code path with `angleDeg = 90`, rather than a separate vertical-line runner.

**Logging:**
- `SweepStart`
- optional sampled state rows in the mapping animation log during the sweep
- `SweepEnd`

### 3.3 Mode C: Sweep an oriented line (arbitrary angle), moving perpendicular to its orientation
**Goal:** map orientation preference; edge moves orthogonal to its orientation.

**Stimulus geometry:**
- Base line segment spanning beyond the screen bounds (so it stays full height after rotation).
- Use `makehgtform('zrotate',theta)` for orientation (`theta` in radians).
- Use translation along the perpendicular direction:
  - if line direction unit vector is `u = [cos(theta), sin(theta)]`
  - perpendicular motion direction is `v = [-sin(theta), cos(theta)]`
  - position is `p = p0 + v * (speed * t)`

**Angle convention (must be explicit):**
- Proposed: **angle is degrees CCW from +x axis** (MATLAB `zrotate` convention).
  - angle = 0 -> horizontal line
  - angle = 90 -> vertical line

**Control variables:**
- `OrientedLineAngleDeg` (GUI: existing `Animate_LineAngle`)
- `SweepSpeed`

**Implementation note:**
- This mode should also use the shared `Map-SweepLine` path; the oriented case differs only by `angleDeg`.

**Logging:**
- store `AngleDeg` in event rows and metadata
- append `SweepStart` / `SweepEnd` events to `this.Time.Log`

### 3.4 Mode D: Looming stimulus (correct or incorrect), configurable x-position
**Goal:** size tuning / looming response; compare contour vs random-segment control.

**Stimulus variants:**
1) **Correct looming:** same 5-segment contour (continuous orientation/spacing).
2) **Incorrect looming:** 5 segments with random orientations and offsets that prevent continuity.

**Implementation approach:**
- Build both variants as separate line objects (or separate transform groups).
- Enable one based on `LoomVariant` (`Correct` / `Incorrect` / `Alternate`).

**Animation:**
- Position at `xCenter` and optionally `yCenter`.
- Apply scale transform:
  - `s(t) = sMin + (sMax - sMin) * 0.5 * (1 + sin(2*pi*t/period))`
- Optionally include temporal envelope (ramp in / hold / ramp out).

**Control variables:**
- `LoomX`
- `LoomY`
- `LoomMinScale`, `LoomMaxScale`
- `LoomPeriodSec`
- `LoomVariant`

**Logging:**
- `LoomStart`
- `LoomPeak` or continuous sampled `scale`
- `LoomEnd`

### 3.5 Mode E: Fixation dot (fading) with reward at peak brightness
**Goal:** encourage fixation/attention to a location; reward paired with dot brightness peak.

**Stimulus geometry:**
- Dot implemented as:
  - a small filled circle patch (recommended, fast), or
  - a scatter marker if patch behavior is awkward
- Parent dot under `FixGroup` so position changes do not affect the main stimulus group.

**Animation:**
- Brightness modulation:
  - `b(t) = 0.5 * (1 + sin(2*pi*t/period))`
  - dot color = `[b b b]` on black background
- Reward logic:
  - detect peak crossing (e.g. `b(t)` crossing above `PeakThreshold` with refractory)
  - deliver reward once per cycle with cooldown `RewardCooldownSec`
  - log `RewardGiven`

**Control variables:**
- `FixEnabled`
- `FixX`, `FixY`
- `FixRadius`
- `FixPeriodSec`
- `FixPeakThreshold`
- `FixRewardSide`
- `FixRewardCooldownSec`

**Overlay behavior:**
- Fixation dot can run during all mapping modes A-D.
- Main loop updates both the stimulus transforms and the dot brightness.

---

## 4) MATLAB implementation plan (no code yet)

### 4.1 Changes planned in `BehaviorBoxVisualStimulus.m`
**Add mapping-specific infrastructure:**
- New public methods:
  - `setupMappingScene(mode, opts)`  
    Creates/clears the mapping axis, creates required graphics for the mode, returns handles.
  - `getMappingTargets()`  
    Returns the relevant `hgtransform` handle(s) and graphics handles for fast updates.
- New private helpers:
  - `ensureMappingAxis_()`
  - `ensureMappingPools_()` (create `MapGroup`, `FixGroup`, line objects, dot patch)
  - geometry builders:
    - `buildContourPolyline_(...)`
    - `buildRandomSegmentsPolyline_(...)`
    - `buildLongLine_(...)`
- New private properties:
  - `MapAx`
  - `MapGroup`
  - `FixGroup`
  - `MapContourLine`
  - `MapRandomLine`
  - `MapSweepLine`
  - `FixDotPatch`

**Key rule:** All graphics are created once and then re-used.

**Coordinate system:**
- `XLim=[-1 1]`, `YLim=[-1 1]`
- `axis(MapAx,'manual')` to avoid autoscale jitter
- `MapAx.Visible='off'`

### 4.2 Changes planned in `BehaviorBoxWheel.m`
**Add a dedicated mapping runner function** (new method):
- `RunMappingStimulus(this, mode, opts)`  
  Handles acquisition start, settling pause, sequence timing, event logging, and saving.

**Modify `AnimateStimulus()` dispatch:**
- If GUI `Animate_Style` begins with `"Map-"` (or matches a set), call `RunMappingStimulus()` instead of legacy `MoveStimuli()`.

**Recommended helper inside `BehaviorBoxWheel.m`:**
- `appendMappingEvent_(eventName, opts)`  
  Formats a structured string and appends it into `this.Time.Log` using the same direct syntax you prefer.

**Core orchestration steps inside `RunMappingStimulus`:**
1) Ensure the stimulus figure exists (`this.Stimulus_Object.setUpFigure()`).
2) Ensure mapping axis exists and all mapping objects are initially hidden.
3) Start ScanImage acquisition:
   - `this.a.Acquisition('Start')`
4) Reset or initialize logs for the mapping run.
5) Start a MATLAB timer:
   - `t0 = tic;`
6) Append startup events directly into `this.Time.Log`, e.g.:
   - `AcquisitionStart`
   - `DisplayOn`
   - `SettleStart`
7) Hold the black screen for `Map_SettlePauseSec`.
8) Append `SettleEnd` and `SequenceStart`.
9) Run the selected mapping mode sequence, updating `hgtransform.Matrix` and logging event rows as needed.
   - Repeat the selected mode continuously until the user presses Stop/Abort.
10) At sequence end:
   - append `SequenceEnd`
   - hide all mapping objects
   - optionally append `AcquisitionEnd`
   - optionally stop acquisition depending on workflow
11) Save:
   - combined `this.Time.Log`
   - mapping animation log (table/struct)
   - mapping metadata

**Stop/abort behavior:**
- At every loop iteration check:
  - GUI stop button (`this.stop_handle.Value`)
  - `this.app.Animate_End.Value`
- On abort:
  - hide mapping objects
  - append an `Abort` event
  - save logs in whatever state exists

---

## 5) Event logging strategy (direct MATLAB append model)

This plan assumes:

> Mapping events belong to the MATLAB runner, and the primary way to mark them is by appending structured event strings directly into `this.Time.Log`.

### 5.1 Design choice
- Do **not** make Timekeeper stimulus-gate semantics a dependency for this feature.
- Do **not** add a required serial event-injection API to `BehaviorBoxSerialTime`.
- Do **not** preserve log grammar solely for `MatchFramesToTimestamps.m`.
- Do use the same direct append style already present elsewhere in `BehaviorBoxWheel.m`.

### 5.2 Recommended `this.Time.Log` line format
Use a consistent machine-readable event format so the next analysis function can parse it cleanly.

**Recommended pattern:**
- prefix: `MAP`
- fields: key/value pairs
- include at least:
  - `event`
  - `mode`
  - `t_us`

**Example lines:**
- `MAP event=AcquisitionStart mode=FlashContourX t_us=0`
- `MAP event=DisplayOn mode=FlashContourX t_us=8123`
- `MAP event=SettleStart mode=FlashContourX t_us=10420`
- `MAP event=SettleEnd mode=FlashContourX t_us=5011054`
- `MAP event=SequenceStart mode=FlashContourX t_us=5013021`
- `MAP event=FlashOn mode=FlashContourX t_us=5532044 x=-0.8 y=0`
- `MAP event=FlashOff mode=FlashContourX t_us=6032110`
- `MAP event=RewardGiven mode=FlashContourX t_us=8011102 side=Right`
- `MAP event=SequenceEnd mode=FlashContourX t_us=15042009`

**Why this format:**
- readable in MATLAB and text exports
- easy to parse later
- no reliance on positional tokens or legacy prefixes
- easy to extend with optional fields (`angleDeg`, `scale`, `brightness`, `variant`, `notes`)

### 5.3 Time origin and mixed-source ordering
The mapping runner should define one explicit MATLAB-side time origin.

**Recommended default:**
- start `t0 = tic;` immediately after `this.a.Acquisition('Start')` returns

**Implications:**
- acquisition, settling pause, and stimulus sequence all share one timeline
- event lines appended into `this.Time.Log` can include `t_us = round(1e6 * toc(t0))`
- the mapping animation log uses the same `t0`

Because `this.Time.Log` is mixed-source, the future parser should assume:
- some lines come from Timekeeper callbacks
- some lines come from MATLAB direct appends
- ordering is still meaningful, but line type must be parsed intentionally

### 5.4 Why keep the mapping animation log
`this.Time.Log` is a good event ledger, but it is not ideal for dense sampled state.

The mapping animation log should remain the authoritative place for:
- continuous position traces during sweeps
- scale traces during looming
- brightness traces for the fixation dot
- run metadata that is awkward to serialize into one text line

---

## 6) Mapping animation log specification (paired log)

### 6.1 File format (recommended)
Write a MATLAB table (easy to save to `.mat` and export to `.csv`).

Columns:
- `t_us` (double): microseconds since the mapping run's MATLAB time origin
- `event` (string): `DisplayOn`, `SettleStart`, `SettleEnd`, `SequenceStart`, `FlashOn`, `FlashOff`, `SweepStart`, `SweepEnd`, `LoomPeak`, `RewardGiven`, etc.
- `mode` (string): mapping mode identifier
- `x` (double), `y` (double): position
- `angleDeg` (double)
- `scale` (double)
- `brightness` (double)
- `variant` (string): `Correct` / `Incorrect`
- `notes` (string): freeform

### 6.2 Metadata (header struct)
Store alongside the table:
- coordinate system description (`XLim`, `YLim`, units)
- time-origin description (e.g. `"tic after Acquisition('Start') returned"`)
- event line format version (e.g. `MAP key=value v1`)
- monitor calibration if available
- all GUI parameters used for the run
- exact wall-clock start time (`datetime`)

---

## 7) GUI properties to add (or re-use) in `BB_App.m`

### 7.1 Re-use existing GUI controls where sensible
Already present in the animate panel:
- `Animate_Speed` -> can map to `SweepSpeed`
- `Animate_LineAngle` -> can map to `OrientedLineAngleDeg`
- `Animate_XPosition`, `Animate_YPosition` -> can map to `FixX/FixY` or `LoomX/LoomY`
- `Animate_End` -> abort mapping loops
- `Animate_MimicTrial` -> not used for mapping

### 7.2 New GUI properties to add (recommended)
Add these as new `uieditfield` / `uicheckbox` controls and mirror them into `Setting_Struct` or a new `MappingStruct`.

| GUI Property (proposed name) | Type | Default | Used by | Notes |
|---|---:|---:|---|---|
| `Map_SettlePauseSec` | numeric | 5.0 | all | pause after acquisition before stimulus visible |
| `Map_FlashDurationSec` | numeric | 0.5 | Mode A | contour on-time |
| `Map_InterFlashIntervalSec` | numeric | 2.0 | Mode A | off-time between flashes |
| `Map_FlashCount` | integer | 5 | Mode A | number of x positions |
| `Map_FlashXMin` | numeric | -0.8 | Mode A | normalized |
| `Map_FlashXMax` | numeric | +0.8 | Mode A | normalized |
| `Map_SweepXMin` | numeric | -1.2 | B/C | start |
| `Map_SweepXMax` | numeric | +1.2 | B/C | end |
| `Map_LoomMinScale` | numeric | 0.5 | Mode D | |
| `Map_LoomMaxScale` | numeric | 1.5 | Mode D | |
| `Map_LoomPeriodSec` | numeric | 2.0 | Mode D | |
| `Map_LoomVariant` | dropdown | Correct | Mode D | Correct / Incorrect / Alternate |
| `Fix_Enable` | checkbox | false | A-D | overlay |
| `Fix_X` | numeric | 0.0 | A-D | |
| `Fix_Y` | numeric | 0.0 | A-D | |
| `Fix_Radius` | numeric | 0.03 | A-D | in mapping coordinates |
| `Fix_PeriodSec` | numeric | 2.0 | A-D | fade cycle |
| `Fix_PeakThreshold` | numeric | 0.98 | A-D | reward trigger |
| `Fix_RewardCooldownSec` | numeric | 2.0 | A-D | refractory |
| `Fix_RewardSide` | dropdown | Right | A-D | valve side |

### 7.3 Add new animate dropdown items (`StimType` strings)
Extend `Animate_Style.Items` to include:
- `Map-FlashContourX`
- `Map-SweepVerticalLine`
- `Map-SweepOrientedLine`
- `Map-LoomingStimulus`

Fixation dot is an overlay toggle, not necessarily its own mode.

---

## 8) Validation and test plan

### 8.1 Rendering correctness
- Verify all mapping modes run with **no axis position changes** (only `hgtransform.Matrix` updates).
- Confirm no graphics are created or destroyed in the animation loop (pooling works).

### 8.2 Timing correctness
- Confirm acquisition start command is issued before any stimulus becomes visible.
- Confirm for `Map_SettlePauseSec = 5`, stimuli remain invisible for 5 seconds after acquisition begins.
- Confirm that after `SequenceStart`, the selected mode repeats continuously until the user stops or aborts the run.
- Confirm event order in `this.Time.Log` is sensible:
  - `AcquisitionStart`
  - `DisplayOn`
  - `SettleStart`
  - `SettleEnd`
  - `SequenceStart`
  - mode-specific events
  - `SequenceEnd`

### 8.3 Logging correctness
- Ensure `this.Time.Log` contains structured `MAP ...` lines for mapping events.
- Ensure mapping event `t_us` values are monotonic.
- Ensure the mapping animation log uses the same time origin as the `MAP ...` lines.
- Ensure all required fields for each mode are present when expected.
- No requirement to satisfy the legacy `MatchFramesToTimestamps.m` parser.

### 8.4 Reward correctness
- With fixation enabled, confirm:
  - reward occurs near brightness peak only
  - cooldown is enforced
  - `RewardGiven` is logged in both the event log and the animation log

---

## 9) Decisions to confirm before code is written (but we can proceed with sensible defaults)

1) **Time origin for mapping logs**
   - Recommended: `t0 = tic;` immediately after `this.a.Acquisition('Start')` returns
   - Alternative: display-on or sequence-start origin if you want a shorter timeline

2) **Event string format**
   - Recommended: `MAP key=value ...`
   - Alternative: more human-readable free text, but that makes the future parser less clean

3) **Angle convention for oriented sweep**
   - Proposed: degrees CCW from +x axis (MATLAB convention)
   - If you prefer degrees from vertical, implement conversion and document it

4) **Coordinate units**
   - Proposed: normalized `[-1,1]` mapping coordinates
   - If you have monitor calibration, convert to degrees of visual angle later

---

## 10) Summary of planned code changes (later patch)

### `BehaviorBoxVisualStimulus.m`
- Add mapping axis and pooled mapping graphics.
- Add methods to create mapping stimuli and expose `hgtransform` handles.

### `BehaviorBoxWheel.m`
- Add a dedicated mapping runner.
- Add structured direct event appends into `this.Time.Log`.
- Add mapping animation log creation and saving.
- Use a shared `Map-SweepLine` implementation for both vertical and oriented sweeps.
- Keep mapping runs alive until Stop/Abort rather than ending after one pass.

### `BB_App.m`
- Add GUI items and numeric fields for mapping parameters (or reuse existing controls where appropriate).

### `BehaviorBoxSerialTime.m` / `Timekeeper.ino`
- No required protocol changes for the first implementation of mapping modes.
- Continue using Timekeeper primarily for frame-clock lines.

---

**End of plan.**
