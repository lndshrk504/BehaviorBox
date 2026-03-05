# BehaviorBox – Feature Outline / Roadmap Notes

## 0) Goals and constraints

### Primary goals
- **Fleet reliability**: predictable behavior across **~15 Linux rigs**.
- **Reproducibility**: every session is traceable to **code version + parameter snapshot + rig state**.
- **Operator safety rails**: reduce human errors (wrong subject / wrong protocol / wrong settings).
- **Developer velocity**: support dev on **macOS**, occasional **Windows**, deployment on **Linux**.

### Operating constraints / assumptions
- Two primary paradigms:
  - **Freely moving** (nose response): `BehaviorBoxNose.m`
  - **Head-fixed** (wheel response, often w/ imaging): `BehaviorBoxWheel.m`
- Hardware variability: multiple USB serial devices; rigs may have different monitor indices and USB enumeration order.
- Sessions can be long; reliability and data integrity matter more than “fast iteration” on rigs.

### Repo organization (recommended target state)
- `app/` (GUI code, app orchestration)
- `tasks/` (Wheel / Nose tasks and future tasks)
- `io/` (serial wrappers, timekeeper wrapper, any device abstraction)
- `data/` (data model + export + manifest)
- `analysis/` (offline analysis utilities)
- `fcns/` (small shared utilities only; no major systems logic)
- `config/` (defaults)
- `rig_config/` (per-rig overrides; **not tracked** or tracked as templates only)
- `scripts/` (install, update, diagnostics)

---

## 1) Fleet-grade deployment & operability

### 1.1 Rig-aware configuration system (single source of truth)

**Feature definition**
- Add a per-rig configuration layer that is loaded at startup and used to resolve:
  - data roots (local + optional network mirror)
  - monitor/display indices and display modes
  - expected hardware IDs (e.g., “Nose1”, “Time2”, “Wheel3”)
  - runtime policies (e.g., strict vs permissive preflight, logging verbosity)
- Split config into:
  - **Repo-tracked defaults** (portable, safe)
  - **Per-rig overrides** (machine-specific, not hard-coded)

**Proposed artifacts**
- `config/defaults.json` (tracked)
- `rig_config/rig_<RIGID>.json` (not tracked, or tracked as `rig_<RIGID>.json.template`)
- Optional: `config/schema.json` (validation rules)

**Core config fields (suggested)**
- `rig_id`: `"Rig07"`
- `os_expected`: `"linux"` (warn if mismatch)
- `data_root_local`: `"/data/BehaviorBox"`
- `data_root_network` (optional): `"/mnt/labshare/BehaviorBox"`
- `display`: 
  - `screen_index`: 1
  - `fullscreen`: true
  - `expected_refresh_hz`: 60
  - `gamma_profile` (optional): `"rig07_gamma.mat"`
- `hardware_expected`:
  - `behavior_arduino_ids`: ["Nose1"] or ["Wheel1"]
  - `timekeeper_ids`: ["Time2"]
- `policies`:
  - `preflight_required`: true
  - `allow_start_with_warnings`: false
  - `log_level`: "INFO"

**Implementation notes**
- Load order (override precedence):
  1) defaults
  2) rig override (by hostname or explicit file)
  3) user override (optional; dev convenience)
  4) session overrides (explicit settings saved with session)
- Validate at startup and show a single “Config errors” dialog that is actionable.

**Acceptance criteria**
- A rig can be fully configured **without editing MATLAB code**.
- Startup shows **Rig ID** and resolved data path in the UI.
- Missing critical config values prevents starting an experiment (with clear message).

---

### 1.2 Release train workflow (stable vs dev; update/rollback)

**Feature definition**
- Formalize a deployment channel for rigs:
  - Rigs track **stable releases** (tags or a `stable` branch).
  - Development happens on `main` or feature branches.
- Add an operator-safe update mechanism.

**Proposed artifacts**
- `scripts/update_to_latest_stable.sh`
- `scripts/rollback_to_previous.sh` (optional)
- UI: “Version / Update” panel that displays:
  - current git commit hash
  - current tag
  - dirty status

**Implementation notes**
- On rigs: “only fast-forward to stable tag” (no interactive merges).
- Keep an auto-generated `VERSION.txt` in builds (optional).

**Acceptance criteria**
- Any rig can be updated in <1 minute with a single action.
- Rollback is straightforward (previous stable tag).
- Session manifest always records the version.

---

### 1.3 Preflight / self-test mode (“don’t start broken”)

**Feature definition**
- Add a deterministic preflight checklist run:
  - automatically at app startup
  - and manually via “Run Preflight” button

**Suggested checks**
- **Display**: correct screen index available; fullscreen works; refresh rate within tolerance.
- **Hardware**: expected Arduino IDs detected; timekeeper available if required.
- **Filesystem**: data root writable; enough free space for estimated session.
- **Permissions**: can create session directories; no permission denied.
- **Clock**: system time sanity (optional).

**Outputs**
- A `preflight.json` report saved to:
  - session folder (if session started)
  - or a rig diagnostics folder (`/data/BehaviorBox/_diagnostics/`)

**Acceptance criteria**
- Start button is disabled until preflight passes (or policy allows warnings).
- Preflight report is human-readable and machine-readable.

---

### 1.4 Observability: structured logs + rotation + optional fleet telemetry

**Feature definition**
- Standardize logging across app/task/data layers:
  - log levels: DEBUG/INFO/WARN/ERROR
  - structured context fields: rig_id, subject_id, session_id, task, trial
- Log rotation and retention policy.

**Proposed artifacts**
- `logs/` folder under data root:
  - `behaviorbox_YYYYMMDD.log`
- `fcns/bb_log.m` (or a small logging class) with consistent formatting.

**Optional fleet telemetry**
- Periodic “heartbeat” file to a shared directory:
  - `Rig07_status.json` including:
    - last_seen
    - current_state (IDLE/RUNNING/ERROR)
    - software_version
    - devices_detected
    - disk_free_gb

**Acceptance criteria**
- When a rig fails, logs make root cause obvious (at least where to look).
- Logs do not grow without bound.

---

## 2) Scientific reproducibility & data governance

### 2.1 Session manifest + version stamping (always-on)

**Feature definition**
- Every session writes a `session_manifest.json` containing:
  - code version (git hash/tag + dirty)
  - full settings snapshot (Setting_Struct)
  - rig config snapshot (or a reference + hash)
  - detected devices and IDs
  - display properties (screen index, refresh rate, resolution)
  - file list written

**Suggested schema (fields)**
- `session_id`: unique (timestamp + rig + subject)
- `rig_id`, `subject_id`, `task_mode` (Wheel/Nose)
- `started_at`, `ended_at`, `operator` (optional)
- `code`: `{ git_hash, git_tag, dirty }`
- `matlab`: `{ version, toolboxes }`
- `os`: `{ name, version, hostname }`
- `settings`: full serialized Setting_Struct
- `devices`: list of `{ id_string, port, role }`
- `display`: `{ screen_index, refresh_hz, resolution, fullscreen }`
- `artifacts`: list of files + hashes (optional)

**Acceptance criteria**
- Any dataset is explainable without tribal knowledge.
- Manifest is always written even on abort/crash (best effort).

---

### 2.2 Data integrity: atomic writes, autosave, resumability

**Feature definition**
- Prevent partial/corrupted files by:
  - writing to temp name then renaming (atomic)
  - periodic autosave checkpoints for long sessions
  - graceful shutdown path on stop/abort/close

**Implementation notes**
- Use session folder structure:
  - `raw/` for primary logs
  - `derived/` for summaries
  - `tmp/` for in-progress writes
- A “session lock” file to prevent two app instances writing to the same folder.

**Acceptance criteria**
- Power loss or MATLAB crash leaves either:
  - a complete file, or
  - an obvious incomplete temp file with recoverable state.

---

### 2.3 Standardized export layer (optional NWB / or stable intermediate)

**Feature definition**
- Keep current MAT/CSV outputs.
- Add an export layer that can write:
  - a stable intermediate format (e.g., one “trial table” + one “events table”)
  - optional NWB export for cross-lab portability.

**Implementation notes**
- Consider Python-based NWB export invoked from MATLAB (isolated dependency).
- Decide minimal NWB mapping: trials, stimuli metadata, responses, rewards, imaging sync.

**Acceptance criteria**
- Export is deterministic and versioned.
- Downstream analysis can rely on the intermediate format even if the UI evolves.

---

## 3) Experimental control improvements

### 3.1 Protocol templates + parameter locking

**Feature definition**
- Introduce the concept of a **named protocol**:
  - e.g., `Wheel_OrientationDisc_v3`
- Protocol defines:
  - default settings
  - which fields are operator-editable
  - “stage” progression rules (optional)

**UX details**
- Protocol picker in GUI.
- Locked fields appear disabled with a tooltip explaining why.

**Acceptance criteria**
- Running “the same protocol” across rigs actually means the same settings.
- Operators cannot accidentally drift critical timing parameters.

---

### 3.2 Adaptive difficulty engines as pluggable modules

**Feature definition**
- Move difficulty selection logic into an interchangeable “policy” module:
  - Staircase (1-up/1-down, 2-up/1-down, etc.)
  - Blocked schedules with constraints
  - Bayesian/QUEST-like (optional)

**Data requirements**
- Persist per-subject state (e.g., current threshold estimate) in a subject profile.

**Acceptance criteria**
- The adaptive method is recorded in the session manifest.
- The same data + seed yields the same sequence (reproducible simulation).

---

### 3.3 Trial scheduler with constraint solving

**Feature definition**
- A scheduler that generates trial sequences subject to constraints:
  - max repeats
  - balanced condition counts
  - catch trial rate
  - minimum spacing between certain trial types
  - block structure with transitions

**Implementation notes**
- Use a deterministic RNG seed stored in manifest.
- Build scheduler tests (distribution, constraints satisfied).

**Acceptance criteria**
- Operators select “scheduler type” and constraints from GUI.
- Trial sequences pass constraint checks and are reproducible.

---

## 4) Operator UX improvements

### 4.1 Subject management workflow (reduce friction + mistakes)

**Feature definition**
- Add subject selection tools that support:
  - quick lookup
  - barcode/QR input (optional)
  - “continue last session” (autoload prior protocol + stage)
  - show last performance snapshot

**Artifacts**
- `subjects/subject_<ID>.json` storing:
  - current stage
  - last protocol
  - last rig
  - notes/tags

**Acceptance criteria**
- Starting a session requires explicit subject confirmation.
- Wrong-subject mistakes become rare.

---

### 4.2 Structured run notes + reason codes + timestamped markers

**Feature definition**
- In-session annotation:
  - reason codes: microscope issue, animal grooming, rig freeze, etc.
  - free text notes
  - “mark event” button that writes a timestamped marker into the log

**Outputs**
- Markers stored in the behavior data and summarized in session report.

**Acceptance criteria**
- Notes are searchable and machine-readable.
- Markers can be plotted on timelines during analysis.

---

### 4.3 End-of-session auto-report (QC + rapid feedback)

**Feature definition**
- Automatically generate a summary artifact per session:
  - PDF or PNG bundle
  - saved in `derived/` folder

**Suggested contents**
- Trial counts, reward counts, abort/timeouts
- Performance vs condition (psychometric-like summary)
- Reaction time distributions (wheel)
- Lapse/guess rate estimates (simple)
- For imaging sessions: alignment sanity checks (time deltas, missing pulses/frames if tracked)

**Acceptance criteria**
- Report generates without manual steps.
- Operators can quickly decide whether a session is usable.

---

## 5) Engineering improvements (cross-platform dev + robustness)

### 5.1 Simulation mode (mock hardware + deterministic replay)

**Feature definition**
- A mode where:
  - Arduino inputs are simulated (nose/wheel events)
  - timekeeper pulses simulated
  - display can be windowed/headless (as much as MATLAB allows)
- Support record/replay:
  - feed a recorded event stream back into the system for debugging.

**Implementation notes**
- Abstract device input behind interfaces:
  - `IBehaviorInput` (real serial vs simulated)
  - `ITimekeeper` (real serial vs simulated)
- Deterministic seeds for scheduler and simulated noise.

**Acceptance criteria**
- Most app logic can be exercised on macOS/Windows without hardware.
- Bugs can be reproduced from a saved event stream.

---

### 5.2 Test harness + CI (prevent regressions before rigs break)

**Feature definition**
- Add MATLAB unit tests for:
  - settings validation/serialization
  - trial scheduler constraints
  - manifest generation
  - file discovery routines
  - simulation mode determinism

**CI proposal**
- GitHub Actions (or similar) runs:
  - lint/static checks (basic)
  - `matlab -batch "run('tests/run_all_tests.m')"`

**Acceptance criteria**
- PRs that break core behavior are caught before deployment.
- Tests run in a few minutes (fast feedback).

---

### 5.3 Plugin architecture for paradigms (reduce duplication)

**Feature definition**
- Refactor shared logic into a base task interface:
  - `setup()`, `runTrial()`, `teardown()`
  - `applySettings()`, `validateSettings()`
  - `writeData()`, `finalizeSession()`
- Wheel and Nose become implementations that reuse shared modules:
  - settings manager
  - scheduler
  - data logger
  - report generator
  - device abstractions

**Migration strategy**
- Step 1: extract shared utilities (settings, manifest, logging) without changing behavior.
- Step 2: wrap existing tasks behind an adapter layer.
- Step 3: gradually de-duplicate trial loop components.

**Acceptance criteria**
- Adding a new task does not require copy/paste of the existing task files.
- Shared modules are testable in isolation.

---

## 6) Implementation sequencing (suggested)

### Phase 1 (highest ROI, lowest risk)
1. Rig-aware config system (load + validate)  
2. Session manifest + version stamping  
3. Preflight checklist + UI surfacing  
4. Structured logs + rotation  

### Phase 2 (ops + UX)
5. End-of-session auto-report  
6. Subject management + continue workflow  
7. Run notes + markers  

### Phase 3 (science + sophistication)
8. Protocol templates + locking  
9. Trial scheduler constraints + deterministic seeding  
10. Adaptive difficulty modules  

### Phase 4 (engineering acceleration)
11. Simulation mode + record/replay  
12. Tests + CI  
13. Plugin architecture migration  

---

## 7) “Definition of Done” checklist (use for each feature)
For each feature, consider it done when:
- [ ] Requirements are documented (this outline + a short spec).
- [ ] Config/paths are cross-platform (Linux first, macOS/Windows dev safe).
- [ ] Logging exists for success/failure paths.
- [ ] A minimal test exists (even if only in simulation mode).
- [ ] The session manifest reflects the feature (if applicable).
- [ ] Backward compatibility plan is clear (old sessions still readable).

