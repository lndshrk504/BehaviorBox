# BehaviorBox Mapping Stimuli Plan (hgtransform-based)

**Scope of this document:** planning + design audit only.  
**Not included yet:** no code changes, no diff/patch.  
**Primary constraint from PI/user:** **all new mapping stimulus modes must move graphics using `hgtransform`** (object transforms), not by moving axes or regenerating geometry.

**Repository:** `BehaviorBox-master.zip` (provided)  
**Target MATLAB files for later patch:**  
- `BehaviorBoxWheel.m` (orchestration, timing, ScanImage, Timekeeper integration)  
- `BehaviorBoxVisualStimulus.m` (stimulus figure + drawing primitives)

---

## 0) Experimental goals and hard requirements

### 0.1 What the mapping animations are for
- Present basic visual stimuli on a MATLAB stimulus figure shown on a screen in front of the mouse.
- Stimuli are intended for V1 mapping (orientation/position receptive field characterization).

### 0.2 Imaging and timing constraints
- The mapping runner must start ScanImage acquisition **before any stimulus becomes visible**.
- After acquisition begins, enforce a **5 s “settling pause”** before any stimulus is shown (screen is on, but stimuli remain invisible).
- The mapping runner must clearly mark at least these events:
  - acquisition start
  - display on (stimulus figure visible / unblanked)
  - “stimulus sequence begins”
  - “stimulus sequence ends”
  - per-epoch events as needed: “flash”, “sweep start/stop”, “loom in/out”, “reward delivered”, etc.

### 0.3 Logging requirements
You want two logs:

1) **Timekeeper log** (frame-clock synchronized; currently `this.Time.Log` from `BehaviorBoxSerialTime` callback):
- Must contain frame timestamps from ScanImage frame clock pin.
- Must contain event markers that can be aligned to frames.

2) **Stimulus animation log** (parameter trace; to pair with Timekeeper):
- A separate log containing time-stamped values such as:
  - x/y position
  - orientation
  - size/scale
  - brightness (fixation dot)
  - stimulus identity (mode, correct/incorrect)
- Must have a defined **time origin** so it can be reconstructed relative to the microscope’s frame log.

### 0.4 Rendering/performance constraint
- **All motion must be performed using `hgtransform`** (set `hgtransform.Matrix`), not by moving axes or recreating plot objects each frame.
- Prefer “create once → update transform/visibility/color” loops.

---

## 1) Current code architecture relevant to mapping modes

### 1.1 Timekeeper Arduino (ground truth for frame timing)
File: `Arduino/Timekeeper/Timekeeper.ino`

Observed behavior:
- Pin 3 rising edge (ScanImage frame clock) prints lines like:
  - `"<timestamp_us>, F <frameCount>"`
  - where `<timestamp_us>` is microseconds since last stimulus-on rising edge
- Pin 2 change (stimulus gate) prints:
  - rising: `"S On-Frame reset <absolute_us>"`
  - falling: `"S Off <absolute_us>"`
  - rising also resets `frameCount=0` and resets the reference time `startTime`

**Implication:** The only *hardware-accurate* events currently supported are **Stim On/Off** via pin 2.  
Additional labeled events (Display On, Flash, Reward, etc.) are **not** currently emitted by Timekeeper.ino.

### 1.2 MATLAB timestamp collector
File: `BehaviorBoxSerialTime.m`

- Stores all received lines verbatim into `this.Log` (string array).
- Does not timestamp lines itself and does not provide an API for “insert event”.

**Implication:** If MATLAB simply appends text into `Time.Log`, ordering vs. incoming serial lines is not guaranteed and the event will not be frame-synchronous.

### 1.3 MATLAB analysis expectations (important format constraint)
File: `Imaging Analysis scripts/MatchFramesToTimestamps.m`

- Treats any line containing `"S "` or `"Trial"` as an “event line”.
- Copies event text to `ts.Event(stamp+1)` (aligns event to *next* frame row).
- Removes `"S "` / `"Trial"` rows from timestamp parsing.

**Hard constraint (unless analysis changes):**
- Any non-frame line in the Timekeeper stream must start with `"S "` or `"Trial"` or it will break numeric parsing.

### 1.4 Existing `hgtransform` infrastructure in the stimulus renderer
File: `BehaviorBoxVisualStimulus.m`

- Already maintains pooled `hgtransform` groups:
  - `LStimGroup`, `RStimGroup` with Tag `StimulusTransform`
- Provides `getWheelMotionTargets()` so `BehaviorBoxWheel.readLeverLoopAnalogWheel()` can translate objects instead of axes.
- Uses pooled polyline graphics (NaN-separated segments) for contour and distractors.

**Opportunity:** Extend this exact pattern for mapping stimuli so *mapping* also uses pooled objects + `hgtransform`.

### 1.5 Existing “animation” entry points
File: `BehaviorBoxWheel.m` + GUI in `BB_App.m`

- GUI animation dropdown currently lists: `Y-Line`, `X-Line`, `Bar`, `Stimulus`, `Dot`
- `BehaviorBoxVisualStimulus.DisplayOnScreen(..., AnimateMode=true, StimType=...)` routes to `PlotXLine/PlotYLine/PlotBar/PlotDot`

**Plan direction:** Add new `StimType` values for mapping modes + add a dedicated mapping runner in `BehaviorBoxWheel` (separate from legacy `MoveStimuli()`).

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
  - `MapAx` spanning `[0 0 1 1]` in normalized units (full figure)
  - `XLim = [-1 1]`, `YLim = [-1 1]` (or another standardized mapping coordinate system)
- Create one `hgtransform` group under `MapAx`:
  - `MapGroup = hgtransform('Parent', MapAx, 'Tag', 'MappingTransform')`
- Create subgroups if needed:
  - `StimGroup` (for mapping stimulus)
  - `FixGroup` (for fixation dot, so it can be repositioned without affecting stimulus)

**Why separate axis?**
- Avoid interference with `LStimAx/RStimAx` and the wheel-task pooling logic.
- Avoid accidental wheel-motion parenting.
- Easier to define “x positions across the screen” for receptive field mapping.

### 2.3 Deterministic timing
Mapping is a calibration tool; reproducibility matters.

**Implementation plan:**
- Use a high-resolution MATLAB timer approach:
  - `t0 = tic;`.

### 2.4 Reward gating (fixation dot)
Reward delivery must be:
- optional (enabled by checkbox)
- rate-limited (cooldown)
- logged (both in animation log and, ideally, in Timekeeper event stream)

---

## 3) Proposed mapping modes

Below are the mapping modes you requested, expressed as concrete “modes” that will become `StimType` values (GUI dropdown items) and runnable sequences in `BehaviorBoxWheel`.

### 3.1 Mode A: Flash contour at discrete x-positions
**Goal:** identify cells responsive to contour at different horizontal locations.

**Stimulus geometry:**
- “Level 1 contour”: 5 segments with spacing (“5-dashed line”) in original vertical orientation.
- Implement as a single NaN-separated polyline so it’s one `Line` object.
- Parented under `StimGroup` (`hgtransform`).

**Animation:**
- Choose `N = 5` x positions across screen (`linspace(xMin,xMax,N)`).
- For each x position:
  - set transform translation to `[x, 0]`
  - set Visible `on` for `FlashDuration` (default 0.5 s)
  - set Visible `off`
  - wait `InterFlashInterval` (default 2.0 s)
- No smooth motion between positions (move while invisible).

**Optional fixation dot overlay:**
- Fixation dot runs concurrently (fade cycle). See Mode E.

**Logging:**
- Animation log event rows:
  - `DisplayOn`
  - `SequenceStart`
  - for each flash: `FlashOn` with x position, `FlashOff`
  - `SequenceEnd`
- If Timekeeper event injection is implemented (recommended; see Section 5), emit:
  - `S Display On`
  - `S Seq Start`
  - `S Flash On x=...`
  - `S Flash Off`
  - `S Seq End`

### 3.2 Mode B: Sweep a vertical line across the display
**Goal:** map spatial receptive fields by moving an edge.

**Stimulus geometry:**
- Solid line spanning full Y range (e.g. from `y=-1` to `y=1`).
- Base geometry centered at origin; parent under `StimGroup`.

**Animation:**
- Start x at `xMin` (e.g. -1.2) and sweep to `xMax` (+1.2)
- Constant speed `SweepSpeed` (units: normalized-x per second)
- Update translation each frame: `x = x0 + SweepSpeed * t`
- Stop when x exceeds bounds.

**Control variables:**
- `SweepSpeed` should be GUI-controlled (requested).
- `SweepDirection` optional.

**Logging:**
- `SweepStart`, continuous trace (optional), `SweepEnd`

### 3.3 Mode C: Sweep an oriented line (arbitrary angle), moving perpendicular to its orientation
**Goal:** map orientation preference; edge moves orthogonal to its orientation.

**Stimulus geometry:**
- Base line segment spanning beyond the screen bounds (so it stays full height after rotation).
- Use `makehgtform('zrotate',theta)` for orientation (theta in radians).
- Use translation along perpendicular direction:
  - If line direction unit vector is `u = [cosθ, sinθ]` (in x-y),
  - perpendicular motion direction `v = [-sinθ, cosθ]`
  - position = `p = p0 + v * (speed * t)`

**Angle convention (must be explicit):**
- Proposed: **angle is degrees CCW from +x axis** (MATLAB `zrotate` convention).
  - angle=0 → horizontal line
  - angle=90 → vertical line
- If you prefer “degrees from vertical”, we can convert: `theta = deg2rad(90 - angleFromVertical)`.

**Control variables:**
- `OrientedLineAngleDeg` (GUI: you already have `Animate_LineAngle`)
- `SweepSpeed` (reuse `Animate_Speed` or add mapping-specific speed)

**Logging:**
- `AngleDeg` stored in each event row and/or as metadata.

### 3.4 Mode D: Looming stimulus (correct or incorrect), configurable x-position
**Goal:** size tuning / looming response; compare contour vs random-segment control.

**Stimulus variants:**
1) **Correct looming:** same 5-segment contour (continuous orientation/spacing).
2) **Incorrect looming:** 5 segments with random orientations, randomized offsets that prevent continuity.

**Implementation approach:**
- Build both variants as separate line objects (or separate `hgtransform` groups).
- Enable one based on `LoomVariant` setting (`Correct` / `Incorrect` / `Alternate`).

**Animation:**
- Position at `xCenter` (GUI-controlled) and maybe `yCenter`.
- Apply scale transform:
  - `s(t) = sMin + (sMax - sMin) * 0.5 * (1 + sin(2π t / period))`
- Optionally include temporal envelope (e.g., ramp in, hold, ramp out).

**Control variables:**
- `LoomX` (default 0.5 or the center of the figure)
- `LoomY` (default 0.5 or the center of the figure)
- `LoomMinScale`, `LoomMaxScale`
- `LoomPeriodSec`
- `LoomVariant`

**Logging:**
- Per-cycle events `LoomPeak`, or continuous trace of `scale` if desired.

### 3.5 Mode E: Fixation dot (fading) with reward at peak brightness
**Goal:** encourage fixation/attention to a location; reward paired with dot brightness peak.

**Stimulus geometry:**
- Dot implemented as:
  - a small filled circle patch (recommended, fast) OR scatter with filled marker
- Parent dot under its own `FixGroup` (`hgtransform`) so position changes do not affect the stimulus group.

**Animation:**
- Brightness modulation:
  - `b(t) = 0.5*(1 + sin(2π t / period))` (0→1)
  - dot color = `[b b b]` on black background
- Reward logic:
  - detect peak crossing (e.g., `b(t)` crossing above `PeakThreshold` with refractory)
  - deliver reward once per cycle with cooldown `RewardCooldownSec`
  - log `RewardGiven`

**Control variables:**
- `FixEnabled` (checkbox)
- `FixX`, `FixY` (defaults 0,0)
- `FixRadius` (size)
- `FixPeriodSec`
- `FixPeakThreshold` (e.g. 0.98)
- `FixRewardSide` (R/L) and `FixRewardCooldownSec`

**Overlay behavior:**
- Fixation dot can run during all mapping modes A–D:
  - main loop updates both stimulus transform(s) and dot brightness.

---

## 4) MATLAB implementation plan (no code yet)

### 4.1 Changes planned in `BehaviorBoxVisualStimulus.m`
**Add mapping-specific infrastructure:**
- New public methods:
  - `setupMappingScene(mode, opts)`  
    Creates/clears mapping axis, creates required graphics for the mode, returns handles.
  - `getMappingTargets()`  
    Returns relevant hgtransform handle(s) and graphics handles for fast updates (similar to `getWheelMotionTargets()`).
- New private helpers:
  - `ensureMappingAxis_()`
  - `ensureMappingPools_()` (create MapGroup, FixGroup, line objects, dot patch)
  - geometry builders:
    - `buildContourPolyline_(...)`
    - `buildRandomSegmentsPolyline_(...)`
    - `buildLongLine_(...)`
- New properties (private):
  - `MapAx`
  - `MapGroup` (hgtransform)
  - `FixGroup` (hgtransform)
  - handles to pooled mapping graphics:
    - `MapContourLine`
    - `MapRandomLine`
    - `MapSweepLine`
    - `FixDotPatch`

**Key rule:** All these graphics are created once and then re-used.

**Coordinate system:**
- Default mapping axis:
  - `XLim=[-1 1]`, `YLim=[-1 1]`
  - `axis(MapAx,'manual')` to avoid autoscale jitter
  - `MapAx.Visible='off'` (no ticks)

### 4.2 Changes planned in `BehaviorBoxWheel.m`
**Add a dedicated mapping runner function** (new method):
- `RunMappingStimulus(this, mode, opts)`  
  Handles acquisition start, settle pause, sequence timing, and logging.

**Modify `AnimateStimulus()` dispatch:**
- If GUI `Animate_Style` begins with `"Map-"` (or matches a set), call `RunMappingStimulus()` instead of legacy `MoveStimuli()`.

**Core orchestration steps inside `RunMappingStimulus`:**
1) Ensure stimulus figure exists (`this.Stimulus_Object.setUpFigure()`).
2) **Start acquisition** (ScanImage):
   - `this.a.Acquisition('Start')`
3) **Display on**:
   - ensure mapping axis exists and background is black
   - ensure all mapping objects are initially `Visible='off'`
4) **5-second settling pause**:
   - while maintaining black screen, no objects visible
5) **Start Timekeeper “Stimulus gate”** (decision point; see Section 5):
   - `this.a.TimeStamp('On')` at **display on** to define time origin; then rely on animation log for detailed events
6) Run the selected mapping mode sequence, updating `hgtransform.Matrix` at each step.
7) End sequence:
   - hide objects
   - `this.a.TimeStamp('Off')` at end of session (if using gate)
   - optionally `this.a.Acquisition('End')` (or leave running depending on your workflow)
8) Save:
   - mapping animation log (table/struct) alongside `this.Time.Log`

**Stop/abort behavior:**
- At every loop iteration check:
  - GUI stop button (`this.stop_handle.Value`)
  - Animate_End state (`this.app.Animate_End.Value`)
- On abort, hide objects and safely stop timestamp gate.

---

## 5) Event logging strategy (crucial) — minimal vs. recommended

This section addresses a core technical issue:

> You want many labeled events inserted into a **frame-clock synchronized** log.  
> The current Timekeeper design only emits `S On` and `S Off` based on a single stimulus gate pin.

### 5.1 Minimal viable approach (no Arduino changes)
- Use Timekeeper’s existing `"S On"` / `"S Off"` only.
- Make **animation log** the source of truth for all detailed events (FlashOn/Off, SweepStart, RewardGiven, etc.).
- Define animation log time origin to align to `"S On"`:
  - Start MATLAB `tic` immediately after sending `this.a.TimeStamp('On')`
  - record all event times as `t_us = 1e6 * toc(t0)`
- During analysis:
  - Use `"S On"` to locate frame=0 (or frame index where stim starts)
  - Map animation log times onto frames by nearest timestamp match.

**Pros:** no hardware/Arduino changes.  
**Cons:** events are not embedded in Timekeeper stream; timing alignment relies on MATLAB scheduling accuracy (usually within a frame).

### 5.2 Recommended approach (enables true event markers in Time.Log)
**Modify Timekeeper.ino** to accept serial commands that insert event markers *without resetting* the time origin.

Proposed Arduino behavior (conceptual):
- Maintain volatile variables:
  - `lastAdjustedMicros`, `lastTimestamp`, `frameCount`
  - updated in `RecordFrame()`
- In `loop()`, read serial lines like:
  - `E DisplayOn`
  - `E FlashOn x=...`
  - `E Reward`
- When received, immediately print:
  - `S <EventText> <timestamp>`
  - where `<timestamp>` is either:
    - absolute adjusted micros, or
    - `lastAdjustedMicros - startTime` to stay in the same reference frame as frame timestamps

**MATLAB side:**
- Add a method to `BehaviorBoxSerialTime` to send event strings to the Timekeeper Arduino over serial.
- In mapping code, call `this.Time.SendEvent("DisplayOn")`, etc.

**Pros:** event markers appear in the same stream as frame timestamps and are aligned in ordering.  
**Cons:** requires Arduino + MATLAB serial class changes (outside the two target .m files you originally scoped).

### 5.3 A middle-ground hardware approach (extra pins)
If you have spare wires and want to avoid serial handling:
- Add additional interrupt pins for “event strobes” (pin 4/5 etc) on the Timekeeper Arduino.
- Pulse those pins from the Behavior Arduino for labeled events.

This still requires Arduino firmware modifications but keeps event stamping in interrupts.

---

## 6) Animation log specification (paired log)

### 6.1 File format (recommended)
Write a MATLAB table (easy to save to `.mat` and export to `.csv`):

Columns:
- `t_us` (double): microseconds since mapping start (aligned to Timekeeper `"S On"` by design)
- `event` (string): `DisplayOn`, `SeqStart`, `FlashOn`, `FlashOff`, `SweepStart`, `SweepEnd`, `LoomPeak`, `RewardGiven`, etc.
- `mode` (string): mapping mode identifier
- `x` (double), `y` (double) position
- `angleDeg` (double)
- `scale` (double)
- `brightness` (double) (fixation dot)
- `variant` (string): `Correct` / `Incorrect` (looming)
- `notes` (string): freeform

### 6.2 Metadata (header struct)
Store alongside the table:
- coordinate system description (`XLim`, `YLim`, units)
- monitor calibration if available (pixels per unit, distance to mouse)
- all GUI parameters used for the run
- exact start time (datetime) for provenance

---

## 7) GUI properties to add (or re-use) in `BB_App.m`

### 7.1 Re-use existing GUI controls where sensible
Already present in the animate panel:
- `Animate_Speed` → can map to `SweepSpeed`
- `Animate_LineAngle` → can map to `OrientedLineAngleDeg`
- `Animate_XPosition`, `Animate_YPosition` → can map to `FixX/FixY` or `LoomX/LoomY`
- `Animate_End` → abort mapping loops
- `Animate_MimicTrial` → not used for mapping (leave off)

### 7.2 New GUI properties to add (recommended)
Add these as new `uieditfield` / `uicheckbox` controls and mirror into `Setting_Struct` or a new `MappingStruct`:

| GUI Property (proposed name) | Type | Default | Used by | Notes |
|---|---:|---:|---|---|
| `Map_SettlePauseSec` | numeric | 5.0 | all | pause after acquisition before stim visible |
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
| `Fix_Enable` | checkbox | false | A–D | overlay |
| `Fix_X` | numeric | 0.0 | A–D | |
| `Fix_Y` | numeric | 0.0 | A–D | |
| `Fix_Radius` | numeric | 0.03 | A–D | in mapping coords |
| `Fix_PeriodSec` | numeric | 2.0 | A–D | fade cycle |
| `Fix_PeakThreshold` | numeric | 0.98 | A–D | reward trigger |
| `Fix_RewardCooldownSec` | numeric | 2.0 | A–D | refractory |
| `Fix_RewardSide` | dropdown | Right | A–D | valve side |

### 7.3 Add new animate dropdown items (StimType strings)
Extend `Animate_Style.Items` to include:
- `Map-FlashContourX`
- `Map-SweepVerticalLine`
- `Map-SweepOrientedLine`
- `Map-LoomingStimulus`

Fixation dot is an overlay toggle, not necessarily its own mode.

---

## 8) Validation & test plan

### 8.1 Rendering correctness
- Verify all mapping modes run with **no axis position changes** (only `hgtransform.Matrix` updates).
- Confirm no graphics are created/destroyed in the animation loop (pooling works).

### 8.2 Timing correctness
- Confirm acquisition starts first.
- Confirm for `Map_SettlePauseSec=5`, stimuli remain invisible for 5 seconds after acquisition begins.
- Confirm that `"S On"` and `"S Off"` boundaries bracket the stimulus epoch as expected.

### 8.3 Logging correctness
- Ensure Timekeeper stream remains parseable (no non-numeric lines without `"S "` prefix).
- Ensure animation log has:
  - correct event count
  - monotonic time
  - correct parameter values

### 8.4 Reward correctness
- With fixation enabled, confirm:
  - reward occurs near brightness peak only
  - cooldown enforced
  - events logged (`RewardGiven`)

---

## 9) Decisions to confirm before code is written (but we can proceed with sensible defaults)

1) **Meaning of Timekeeper `"S On"` in mapping sessions**
   - Keep as “stimulus sequence start” (recommended for continuity), OR
   - repurpose as “display on / mapping start” to capture the 5 s settling epoch explicitly.

2) **Angle convention for oriented sweep**
   - Proposed: degrees CCW from +x axis (MATLAB convention).  
   - If you want “degrees from vertical”, I will implement conversion and document it.

3) **Coordinate units**
   - Proposed: normalized [-1,1] mapping coordinates.
   - If you have monitor calibration, we can convert to degrees of visual angle later.

---

## 10) Summary of planned code changes (later patch)

### `BehaviorBoxVisualStimulus.m`
- Add mapping axis + pooled mapping graphics.
- Add methods to create mapping stimuli and expose hgtransform handles.

### `BehaviorBoxWheel.m`
- Add mapping runner that:
  - starts acquisition
  - enforces settle pause
  - runs mapping sequences by updating hgtransform matrices
  - writes animation log + saves with Time.Log

### `BB_App.m`
- Add GUI items + numeric fields for mapping parameters (or reuse existing where appropriate).

---

**End of plan.**
