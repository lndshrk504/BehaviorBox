# BehaviorBox Debugging Improvements

This note captures concrete changes that would make the `BehaviorBox*.m` workflow easier to debug in future MATLAB sessions, especially in headless `matlab -batch` runs.

## Highest-ROI changes

### 1. Keep one narrow batch repro per bug class
- Add small scripts that reproduce a single failure mode without requiring the full GUI workflow.
- Good initial targets:
  - `fcns/testBehaviorBoxDataLoad.m`
  - `fcns/testInterruptedTrialSave.m`
  - `fcns/testWheelTimestampIntegrity.m`
- These should run from repo root with `matlab -batch` and print one clear success token.

### 2. Add save/load validators
- Add a `validateNewDataForSave_()` helper in `BehaviorBoxWheel.m` and `BehaviorBoxNose.m`.
- Add a post-load validator in `BehaviorBoxData.m`.
- Validate:
  - committed trial arrays have matching lengths
  - additive tables have expected columns
  - timestamp segments have the expected fields and types
  - mixed `char` / `string` / `cellstr` state is normalized before save

### 3. Keep debug logging structured
- Replace scattered `disp(...)`-only diagnostics with a consistent debug log format.
- Log at least:
  - method name
  - trial number
  - current phase
  - event name
  - key counters or lengths
- This could be a text log, a table, or a cell array saved with the session.

### 4. Separate state transitions from side effects
- The root classes currently mix:
  - GUI state
  - hardware calls
  - trial-state transitions
  - save serialization
- Split the most failure-prone paths into narrower helpers:
  - begin trial
  - commit trial
  - store time segment
  - finalize cleanup
  - build save payload
- This makes it easier to test logic without live hardware.

### 5. Keep a minimal mock layer in-repo
- The new `MockApp/` folder is the first step.
- Extend it only as needed for new headless repro scripts.
- Prefer minimal mocks over broad fake frameworks.

## Suggested implementation order

### Phase 1: Small, low-risk additions
1. Add `fcns/testBehaviorBoxDataLoad.m`
2. Add `fcns/testInterruptedTrialSave.m`
3. Add `validateNewDataForSave_()` in wheel and nose
4. Add `bb_debug_saved_file.m` to summarize session integrity

### Phase 2: Better observability
1. Add a `DebugMode` flag to `BehaviorBoxWheel.m`, `BehaviorBoxNose.m`, and `BehaviorBoxData.m`
2. In debug mode:
   - rethrow important exceptions after logging context
   - enable extra invariant checks
   - save richer session-state snapshots

### Phase 3: Cleaner architecture
1. Move save-payload construction into dedicated helpers such as `buildNewDataForSave_()`
2. Move schema validation into dedicated helpers
3. Reduce broad `try/catch` blocks that suppress useful context

## Specific pain points worth addressing

### Broad try/catch blocks
- Many current failures are harder to localize because the error context is swallowed or delayed.
- Prefer smaller `try/catch` scopes and log:
  - current method
  - `this.i`
  - current decision
  - active time segment state

### Parallel arrays and mixed container types
- Several save/load issues come from implicit assumptions about shapes and types.
- Standardize internal representation where practical:
  - prefer `string` internally
  - convert to `char` only where MATLAB APIs require it
  - validate tables before assuming vector-like indexing

### Implicit schema instead of explicit schema helpers
- Save schema is currently spread across runtime classes.
- A clearer pattern is:
  - `buildNewDataForSave_()`
  - `validateNewDataForSave_()`
  - `annotatePartialTrialsForSave_()` or equivalent

## Proposed utility additions

### `bb_debug_saved_file.m`
This helper should summarize one saved `.mat` file and report:
- committed trial count
- max trial number in `WheelDisplayRecord`
- timestamp segments by kind
- whether cleanup is session-level
- whether required additive columns exist
- whether there are missing end-of-trial markers

### `getDebugSnapshot_()`
This helper should capture the current runtime state, for example:
- `i`
- `WhatDecision`
- `Level`
- `isLeftTrial`
- committed trial count
- active time segment kind and trial
- sizes of `timestamps_record`, `WheelDisplayRecord`, and `FrameAlignedRecord`

## Invariants to preserve while improving debugging
- Do not change production GUI behavior just to make debugging easier.
- Do not hide hardware-dependent bugs behind mocks.
- Keep additive save fields backward-compatible.
- Keep headless repro scripts deterministic and side-effect-light.

## Immediate next steps
1. Add `validateNewDataForSave_()` in wheel and nose.
2. Add one interrupted-trial smoke script.
3. Add `getDebugSnapshot_()` or an equivalent runtime-state summary helper.
