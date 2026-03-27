# BehaviorBox Debugging Improvements

This note is intentionally repo-aligned. It separates debugging work that already exists from work that is still worth doing, so future changes do not duplicate utilities that are already in place.

## Current status as of 2026-03-27

The following existing utilities were smoke tested successfully:

- `MockApp/testBehaviorBoxWheelSaveStatus.m`
- `fcns/testBehaviorBoxDataLoad.m`
- `fcns/bb_debug_saved_file.m`

Observed during the batch runs:

- MATLAB warned that `/home/wbs/Desktop/BehaviorBox/LiveImageAcquisition` does not exist.
- MATLAB warned about a permission-denied generic video support-package path under `/root/Documents/MATLAB/SupportPackages/...`.
- Those warnings did not fail the smoke tests.

The saved-file helper also produced useful output on a real wheel session file. In the sampled file, the helper reported:

- `WheelDisplayRecord` present, but status columns absent
- `FrameAlignedRecord` present with `0` rows
- `TimestampRecord` present, but segment status fields absent
- cleanup recorded as non-session-level

That means the current utilities are functional and already useful for locating remaining schema and observability gaps.

## Bucket 1: Already implemented and usable now

These should be treated as the current baseline, not future work.

### Existing utilities

- `MockApp/` is already the in-repo minimal headless harness for `BehaviorBoxWheel` save and cleanup logic.
- `MockApp/testBehaviorBoxWheelSaveStatus.m` already provides a narrow wheel save/cleanup smoke path without the full GUI or live hardware.
- `fcns/testBehaviorBoxDataLoad.m` already provides a narrow loader smoke test for the `BehaviorBoxData` path used by the GUI.
- `fcns/testBehaviorBoxDataLoad.m` already calls `bb_debug_saved_file.m`, so the saved-file summary helper is already integrated into a useful loader repro.
- `fcns/bb_debug_saved_file.m` already summarizes saved wheel-session files and surfaces structural issues such as missing status fields or missing trial-end markers.

### Exact commands

Run the existing wheel save-status smoke test:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"
```

Run the existing loader smoke test:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
```

Run the saved-file debug helper directly on a known file:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('startup.m'); report = bb_debug_saved_file('/home/wbs/Dropbox @RU Dropbox/William Snyder/Data/Will/Wheel/New/3421911/260326_142506_3421911_New_ContourDensity_Wheel.mat'); assert(report.HasNewData); fprintf('BB_DEBUG_SAVED_FILE_OK\n');"
```

### What this bucket already covers

- wheel save and cleanup behavior in a headless path
- `BehaviorBoxData` load behavior on real saved files
- one-file structural inspection of saved wheel sessions

## Bucket 2: Pending shared save/load work

This bucket is for changes that belong in both `BehaviorBoxWheel.m`, `BehaviorBoxNose.m`, or `BehaviorBoxData.m`, without leaking wheel-only or imaging-only state into nose code.

### Priority work

- Add `validateNewDataForSave_()` helpers in `BehaviorBoxWheel.m` and `BehaviorBoxNose.m`, but scope each validator only to fields that class actually owns.
- Add a post-load validator in `BehaviorBoxData.m` so loader failures fail earlier and with clearer schema diagnostics.
- Keep the new validators layered on top of existing helpers rather than replacing them blindly.
- In `BehaviorBoxWheel.m`, reuse existing save-path helpers such as `annotateTimestampSegmentsForSave_()` and `annotateWheelDisplayRecordForSave_()`.
- In `BehaviorBoxNose.m`, reuse existing helpers such as `ensureColumns()` and `alignDataLengths()` instead of creating a second parallel save-normalization path.
- Reduce overly broad `try/catch` scopes in save/load hot paths so the failing operation and current state are easier to localize.
- Normalize mixed `char` / `string` / `cell` save-state inputs before save and after load, but do not change saved-file schema casually.

### Important constraint

Do not copy wheel-only fields such as `timestamps_record`, `WheelDisplayRecord`, `FrameAlignedRecord`, imaging metadata, or microscope assumptions into `BehaviorBoxNose.m`.

### Exact commands after work in this bucket

Run static checks on the shared save/load classes:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m');"
```

Run the existing loader smoke test:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
```

Run the existing wheel save-status smoke test to confirm shared save-path changes did not regress wheel behavior:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"
```

Check for unresolved merge markers in the save/load classes:

```bash
rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m BehaviorBoxWheel.m BehaviorBoxData.m
```

## Bucket 3: Pending wheel-only debugging work

This bucket is for debugging improvements that belong only to the wheel workflow and should stay out of `BehaviorBoxNose.m`.

### Priority work

- Add `fcns/testInterruptedTrialSave.m` as a narrow wheel-only repro for interrupted-session save behavior.
- Add `fcns/testWheelTimestampIntegrity.m` as a narrow wheel-only repro for timestamp-segment structure and trial-level completeness.
- Add a wheel-only runtime snapshot helper such as `getDebugSnapshot_()` or `getWheelDebugSnapshot_()` in `BehaviorBoxWheel.m`.
- The wheel snapshot helper should include only wheel-owned runtime state, for example:
  - `i`
  - `WhatDecision`
  - `Level`
  - `isLeftTrial`
  - committed trial count
  - active time-segment kind and trial
  - sizes of `timestamps_record`, `WheelDisplayRecord`, and `FrameAlignedRecord`
- Keep wheel debug logging structured and consistent so batch repros surface:
  - method name
  - trial number
  - phase
  - event name
  - key counters or row counts

### Why this bucket remains separate

- `timestamps_record`, `WheelDisplayRecord`, and `FrameAlignedRecord` are wheel-side debugging and save artifacts.
- Wheel is also the only root workflow file that should carry microscope or imaging-related integration logic.
- Keeping wheel-only debugging work isolated prevents nose-path debugging improvements from becoming coupled to wheel-specific schema.

### Exact commands after work in this bucket

Run the existing wheel save-status smoke test:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"
```

Run the new interrupted-trial save smoke test after it is added:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testInterruptedTrialSave.m');"
```

Run the new wheel timestamp-integrity smoke test after it is added:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testWheelTimestampIntegrity.m');"
```

Run the existing loader smoke test again to verify wheel save-output changes still load cleanly:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
```

## Guardrails

- Do not change production GUI behavior just to make debugging easier.
- Do not hide hardware-dependent bugs behind mocks.
- Keep additive save fields backward-compatible unless a schema change is explicitly intended and documented.
- Keep headless repro scripts deterministic and side-effect-light.
- Prefer one narrow batch repro per bug class instead of one broad debug harness that tries to emulate the entire app.
