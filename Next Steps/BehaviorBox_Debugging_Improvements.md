# BehaviorBox Debugging Improvements

This note is a concrete execution plan for making this repo easier for Codex to debug without widening into broad refactors. It separates the debugging baseline that already exists from phased follow-on work, and it defines what each future debugability task must prove before it is considered done.

## Goal

Make the active MATLAB workflows in this repo easier to reproduce, inspect, and validate in narrow batch runs, with special attention to:

- `BehaviorBoxData.m` save/load behavior
- `BehaviorBoxWheel.m` runtime and save-path failures
- `BehaviorBoxNose.m` runtime and save-path failures
- `BehaviorBoxSerialInput.m` and `BehaviorBoxSerialTime.m` parser and command behavior
- `BehaviorBoxVisualStimulus.m` stimulus selection and rendering decisions

## Non-goals

- Do not change production GUI behavior just to make debugging easier.
- Do not hide hardware-dependent bugs behind mocks.
- Do not broaden into schema changes unless a debugging improvement requires an additive, documented field.
- Do not couple nose code to wheel-only imaging or timestamp artifacts.
- Do not replace narrow repros with one large debug harness that tries to emulate the full app.

## Current baseline

Treat the following utilities as already implemented and usable now. Future work should build on them rather than recreate them.

### Existing smoke tests and helpers

- `MockApp/testBehaviorBoxWheelSaveStatus.m`
- `fcns/testBehaviorBoxDataLoad.m`
- `fcns/testBehaviorBoxDataNoEagerMkdir.m`
- `fcns/testBehaviorBoxDataDeferredSaveMkdir.m`
- `fcns/bb_debug_saved_file.m`

### Current coverage

- headless wheel save and cleanup behavior
- `BehaviorBoxData` load behavior on real saved files
- missing-subject lookup behavior that must not create folders during lookup
- deferred folder creation that must happen only at save time
- one-file structural inspection of saved wheel sessions

### Baseline commands

Run the existing wheel save-status smoke test:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"
```

Run the existing real-data loader smoke test:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
```

Run the non-destructive missing-subject lookup smoke test:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataNoEagerMkdir.m');"
```

Run the deferred-save folder-creation smoke test:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataDeferredSaveMkdir.m');"
```

Run the saved-file debug helper directly on a known file:

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('startup.m'); report = bb_debug_saved_file('/home/wbs/Dropbox @RU Dropbox/William Snyder/Data/Will/Wheel/New/3421911/260326_142506_3421911_New_ContourDensity_Wheel.mat'); assert(report.HasNewData); fprintf('BB_DEBUG_SAVED_FILE_OK\n');"
```

## Phase order

Implement future debugging work in this order unless a concrete bug requires a different sequence.

1. Shared save/load observability
2. Shared serial and stimulus observability
3. Nose-only runtime observability
4. Wheel-only runtime observability

This ordering keeps the common save/load and parser paths inspectable before adding workflow-specific snapshots.

## Definition of done for this plan

This debugging-improvement plan is complete only when:

- every proposed smoke test has a concrete script path, fixture strategy, and success condition
- every snapshot or preflight helper has a named owner and a defined output schema
- both root workflows, Nose and Wheel, have explicit debugability coverage
- shared serial and stimulus paths have at least one non-hardware smoke test each
- the validation commands remain aligned with `AGENTS.md`

## Phase 1: Shared save/load observability

This phase covers work shared by `BehaviorBoxData.m`, `BehaviorBoxWheel.m`, and `BehaviorBoxNose.m`.

### Scope

- save-time validation
- load-time validation
- save/load diagnostics
- subject/strain path resolution
- app-settings capture used by save paths

### Tasks

- Add `validateNewDataForSave_()` helpers in `BehaviorBoxWheel.m` and `BehaviorBoxNose.m`, scoped only to fields each class owns.
- Add a post-load validator in `BehaviorBoxData.m` so loader failures fail earlier and with clearer schema diagnostics.
- Reduce overly broad `try/catch` scopes in save/load hot paths so the failing operation and current state are easier to localize.
- Add a shared session-preflight summary helper for `BehaviorBoxWheel.m` and `BehaviorBoxNose.m`.
- Add a shared debug snapshot helper safe to call from top-level `catch` blocks.
- Add one explicit app-settings schema or manifest for the cached `readSettingsFromApp()` path.
- Add a per-file `LoadReport` or equivalent in `BehaviorBoxData.m`.
- Keep `BehaviorBoxData.m` clearly marked as the active GUI loader/analyzer, and label `BehaviorBoxDataNew.m` clearly as experimental or legacy if that remains the intent.
- Turn known inline uncertainty comments in save/load paths into tests or temporary assertions instead of passive comments.

### Acceptance criteria

#### `validateNewDataForSave_()`

- Input: the exact `newData` struct about to be saved
- Output: either success or an error/warning that names the missing or inconsistent field
- Must not rewrite schema silently
- Must not add wheel-only fields to nose saves

#### Shared session-preflight summary helper

- Must use a stable struct schema rather than an unstructured printed summary.
- The top-level preflight struct must include at least:
  - `SchemaVersion`
  - `GeneratedAt`
  - `Workflow`
  - `Subject`
  - `Strain`
  - `InputMode`
  - `StimulusType`
  - `CurrentLevel`
  - `Paths`
  - `Dependencies`
  - `SettingsSnapshot`
  - `Warnings`
- `Workflow` must distinguish at least `Nose` and `Wheel`.
- `Paths` must be a nested struct including at least:
  - `SaveFolder`
  - `DiaryPath`
  - `SourceRoot`
- `Dependencies` must be a nested struct including at least:
  - `BehaviorBoxDataReady`
  - `KeyboardFallbackActive`
  - `Arduino`
  - `Timekeeper`
  - `VisualStimulus`
- `Arduino`, `Timekeeper`, and `VisualStimulus` must each be nested structs with at least:
  - `Attempted`
  - `Succeeded`
  - `Identity`
  - `Message`
- `Identity` should preserve the resolved port, device name, or class identity when known.
- `SettingsSnapshot` must be a small additive struct containing the app-setting values actually used to derive the preflight summary, rather than a raw copy of the whole app object.
- `Warnings` should be a cellstr so the helper can report degraded-but-usable states without failing the session.
- Must be safe to call before the main loop starts
- Must not require saving a file to inspect its output

#### Shared debug snapshot helper

- Must be safe inside top-level `catch` blocks
- Must use a stable struct schema that is safe to serialize even when some handles are invalid.
- The top-level debug snapshot struct must include at least:
  - `SchemaVersion`
  - `GeneratedAt`
  - `Workflow`
  - `ErrorContext`
  - `RuntimeState`
  - `SettingsSnapshot`
  - `Warnings`
- `ErrorContext` must be a nested struct including at least:
  - `Identifier`
  - `Message`
  - `StackTop`
- `StackTop` should be a short string such as `file:line` for the top stack frame when available.
- `RuntimeState` must include at least:
  - `ActiveTrial`
  - `CurrentPhase`
  - `CurrentDecision`
  - `SessionStarted`
  - `SaveFolder`
- `SettingsSnapshot` must be the most recent additive app-setting snapshot that was safe to capture before the error.
- `Warnings` should be a cellstr containing notes about missing fields, invalid handles, or degraded capture.
- Must not perform GUI-only work that can fail inside the catch path

#### App-settings manifest for `readSettingsFromApp()`

- Must document the observed `readSettingsFromApp()` contract rather than invent a second independent settings path.
- Must use a stable struct schema.
- The top-level manifest struct must include at least:
  - `SchemaVersion`
  - `GeneratedAt`
  - `Workflow`
  - `SourceMethod`
  - `Controls`
  - `Summary`
- `Workflow` must distinguish at least `Nose` and `Wheel`.
- `SourceMethod` should capture the owning method name, currently `readSettingsFromApp`.
- `Controls` must be a struct array with one row per cached app property/tag entry.
- Each row of `Controls` must include at least:
  - `AppProperty`
  - `Tag`
  - `UIType`
  - `Category`
  - `ValueSource`
  - `RawValueClass`
  - `NormalizedValueClass`
  - `NormalizationRule`
  - `IncludedInSettingsSnapshot`
  - `UsedBySavePath`
  - `UsedByPreflight`
  - `Notes`
- `Category` must use a small fixed vocabulary such as:
  - `Stimulus`
  - `Box`
  - `ReadyCue`
  - `Level`
  - `Temp`
  - `Uncategorized`
- `ValueSource` must describe how the value is read, with a small fixed vocabulary such as:
  - `Value`
  - `DropdownIndex`
  - `LogicalCheckbox`
  - `ObjectFallback`
  - `Missing`
- `NormalizationRule` must describe the coercion applied by `readSettingsFromApp()`, using a small fixed vocabulary such as:
  - `none`
  - `str2double_if_numeric`
  - `checkbox_to_logical`
  - `dropdown_value_to_index`
  - `fallback_object_copy`
- `UsedBySavePath` and `UsedByPreflight` must be logical scalars so the manifest makes clear which app settings are relevant to debugging save behavior versus only broader session state.
- `IncludedInSettingsSnapshot` must be a logical scalar indicating whether the field is intended to appear in the additive `SettingsSnapshot` structs used by preflight and catch-path helpers.
- `Notes` should be a cellstr so repo-specific caveats can be attached without changing schema.
- `Summary` must include at least:
  - `NumControls`
  - `NumIncludedInSettingsSnapshot`
  - `NumUsedBySavePath`
  - `NumUsedByPreflight`
  - `CategoriesSeen`
  - `NormalizationRulesSeen`
- The manifest must be additive and observational:
  - it must not change control values
  - it must not choose different coercions than `readSettingsFromApp()`
  - it must not become the runtime source of truth instead of the existing method
- The manifest should be usable to derive the smaller additive `SettingsSnapshot` structs consumed by preflight and debug-snapshot helpers.

#### `SettingsSnapshot`

- Must use a stable struct schema derived from the app-settings manifest rather than a raw dump of all settings.
- The top-level `SettingsSnapshot` struct must include at least:
  - `SchemaVersion`
  - `GeneratedAt`
  - `Workflow`
  - `Subject`
  - `Strain`
  - `InputMode`
  - `Stimulus`
  - `Level`
  - `Save`
  - `Flags`
  - `Warnings`
- `Workflow` must distinguish at least `Nose` and `Wheel`.
- `Subject`, `Strain`, and `InputMode` should preserve the normalized values actually in use at snapshot time.
- `Stimulus` must be a nested struct including at least:
  - `Type`
  - `MappingMode`
  - `LeftChoice`
  - `RightChoice`
- `Level` must be a nested struct including at least:
  - `Current`
  - `Rule`
  - `AutoAdvanceEnabled`
- `Save` must be a nested struct including at least:
  - `ResolvedFolder`
  - `DiaryPath`
  - `Investigator`
  - `InputBranch`
- `Flags` must be a nested struct including at least:
  - `KeyboardFallbackRequested`
  - `ArduinoExpected`
  - `TimekeeperExpected`
  - `VisualStimulusExpected`
- `Warnings` should be a cellstr for missing or ambiguous setting values.
- `SettingsSnapshot` must only include fields whose `IncludedInSettingsSnapshot` manifest flag is true.
- `SettingsSnapshot` must prefer already-normalized values from `readSettingsFromApp()` and must not apply a second independent coercion pass.
- Preflight helpers must populate the full `SettingsSnapshot` schema when the underlying values are available.
- Catch-path debug snapshots may emit a partial `SettingsSnapshot`, but any omitted nested field must be replaced by an empty value plus a note in `Warnings`, not silently removed from the schema.
- Workflow-specific extensions are allowed only as nested structs:
  - optional `Nose` struct for nose-only snapshot fields such as hold requirement or input-device mode
  - optional `Wheel` struct for wheel-only snapshot fields such as acquisition mode or scan-image linkage
- `SettingsSnapshot` must remain small enough to read in a console or saved debug artifact without duplicating the full settings manifest.

#### `LoadReport`

- Must use a stable struct schema rather than an ad hoc cell array or free-form text.
- The top-level `LoadReport` struct must include at least:
  - `SchemaVersion`
  - `GeneratedAt`
  - `Inv`
  - `Inp`
  - `RequestedStr`
  - `RequestedSub`
  - `SourceRoot`
  - `Files`
  - `Summary`
- `SchemaVersion` should be an additive string such as `v1` so future fields can be added without ambiguity.
- `GeneratedAt` should use a sortable wall-clock timestamp with date and time.
- `RequestedStr` and `RequestedSub` should preserve the exact lookup inputs even if path resolution later normalizes them.
- `SourceRoot` should store the resolved `fullfile(GetFilePath("Data"), Inv, Inp)` root used during discovery.
- `Files` must be a struct array with one row per discovered or attempted file.
- Each row of `Files` must include at least:
  - `FilePath`
  - `FileName`
  - `ParentFolder`
  - `SubjectFolder`
  - `ExistsOnDisk`
  - `LoadAttempted`
  - `LoadSucceeded`
  - `TopLevelFields`
  - `HasNewData`
  - `NewDataFields`
  - `FileKind`
  - `SkipReason`
  - `NormalizationApplied`
  - `NormalizationNotes`
  - `TrimApplied`
  - `TrimNotes`
  - `SchemaWarnings`
  - `ErrorIdentifier`
  - `ErrorMessage`
- `FileKind` must use a small fixed vocabulary:
  - `training`
  - `animate_only`
  - `skipped`
  - `unknown`
- `SkipReason` must be empty on loaded files and otherwise use a short machine-readable reason such as:
  - `missing_newData`
  - `animate_only_file`
  - `load_error`
  - `schema_validation_failed`
  - `user_filter_excluded`
- `TopLevelFields` and `NewDataFields` should be stored as cellstr so they are easy to inspect and diff in MATLAB.
- `NormalizationApplied` and `TrimApplied` should be logical scalars, not free-form text.
- `NormalizationNotes`, `TrimNotes`, and `SchemaWarnings` should be cellstr fields so multiple decisions can be captured without inventing extra columns.
- `ErrorIdentifier` and `ErrorMessage` must be empty on successful loads and populated only when load or schema validation failed.
- `Summary` must include aggregate counts at minimum:
  - `NumFilesConsidered`
  - `NumLoadAttempted`
  - `NumLoadSucceeded`
  - `NumTraining`
  - `NumAnimateOnly`
  - `NumSkipped`
  - `NumWithWarnings`
  - `NumWithErrors`
- `Summary` should also include a `SubjectsSeen` cellstr and a `StrainsSeen` cellstr when those can be inferred from the discovered paths.
- Must be accessible after `BehaviorBoxData.loadFiles()`
- Must be exposed both as a property on the `BehaviorBoxData` object and as a returned struct for callers that do not retain the object
- Must not break the existing `loadedData` contract

### Required validation after Phase 1 work

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); checkcode('BehaviorBoxNose.m'); checkcode('BehaviorBoxWheel.m'); checkcode('BehaviorBoxData.m');"
```

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
```

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataNoEagerMkdir.m');"
```

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataDeferredSaveMkdir.m');"
```

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"
```

```bash
rg -n "^<<<<<<<|^=======|^>>>>>>>" BehaviorBoxNose.m BehaviorBoxWheel.m BehaviorBoxData.m BehaviorBoxVisualStimulus.m BehaviorBoxSerialInput.m BehaviorBoxSerialTime.m
```

## Phase 2: Shared serial and stimulus observability

This phase covers debugging improvements shared by `BehaviorBoxSerialInput.m`, `BehaviorBoxSerialTime.m`, and `BehaviorBoxVisualStimulus.m`.

### Scope

- serial command naming and observability
- serial parser repros without hardware
- stimulus selection and level interpretation without drawing

### Tasks

- Add a serial command registry in `BehaviorBoxSerialInput.m` and `BehaviorBoxSerialTime.m`.
- Add lightweight TX/RX history or command counters to the serial classes.
- Add a pure parser smoke test for `BehaviorBoxSerialInput.m` and `BehaviorBoxSerialTime.m` that feeds known sample lines or command sequences without hardware.
- Refactor `BehaviorBoxVisualStimulus.m` so the active method-based implementation is clearly separated from the legacy free-function code below the classdef.
- Add a non-drawing `buildStimulusSpec_()` or `describeStimulusSpec_()` path in `BehaviorBoxVisualStimulus.m`.

### Acceptance criteria

#### Serial command registry

- Every command byte used by acquisition, reward, timestamping, and resets must be named in one place.
- No new magic characters should be introduced outside the registry.

#### TX/RX history or counters

- Must answer:
  - which command was sent
  - when it was sent
  - which port handled it
  - whether a matching response or parse event arrived
- Must be lightweight enough to leave enabled during normal debugging
- Must be written into a `Debug/` folder as structured log output
- Debug log filenames must include the date and time so separate runs do not overwrite one another
- In-memory history may still exist, but the timestamped `Debug/` log is required output
- The `Debug/` folder should live under the active session save folder when one exists; otherwise it should fall back to a deterministic local debug folder under the current working directory
- The minimum filename convention should be:
  - `serial_txrx_<class>_<yyyy_MM_dd-HH_mm_ss>.csv`
  - where `<class>` is `BehaviorBoxSerialInput` or `BehaviorBoxSerialTime`
- If the same class writes multiple logs in one second, append an additive suffix such as `_001`, `_002`, and so on
- The log format should be CSV so it is easy to inspect in MATLAB, spreadsheets, and text diffs
- Every log row must include at least:
  - `timestamp`
  - `direction`
  - `port`
  - `commandName`
  - `rawValue`
  - `eventType`
  - `status`
  - `matchKey`
  - `details`
- `timestamp` should use a sortable wall-clock format with date and time
- `direction` must distinguish `tx`, `rx`, and parser-only events when no outbound command exists
- `commandName` must use the registry name when available, not only the raw byte or line
- `rawValue` must preserve the original byte, char, or line content needed for later debugging
- `eventType` should distinguish at least:
  - command send
  - raw line receive
  - parsed event
  - timeout
  - error
- `status` should distinguish at least:
  - ok
  - timeout
  - parse_error
  - unmatched
  - dropped
- `matchKey` should be the correlation token used to connect a sent command with a later response or parse event when such a token exists
- `details` should be free-form text or serialized metadata for extra context that does not fit the fixed columns
- The logging path must not require hardware to exist; parser-only smoke tests should still be able to emit a valid timestamped debug log
- The log writer must tolerate failures to create the `Debug/` folder by falling back to in-memory history and surfacing a clear warning instead of crashing the main workflow

#### Parser smoke test

- Must not require hardware
- Must feed representative sample lines or command sequences
- Must assert parse classification and key extracted fields
- Must fail if malformed input is silently accepted as valid data

#### Stimulus spec helper

- Must use a stable schema for both the struct and table views.
- The struct view must include at least:
  - `SchemaVersion`
  - `GeneratedAt`
  - `StimulusType`
  - `Level`
  - `LevelMeaning`
  - `LeftAssignment`
  - `RightAssignment`
  - `VisualParams`
  - `Warnings`
- `VisualParams` must be a nested scalar struct holding the key draw parameters needed to reason about output without opening a figure.
- The table view must be a normalized one-row summary with fixed variable names matching the scalar fields of the struct view where practical.
- Must describe:
  - stimulus choice
  - level interpretation
  - left/right assignment
  - key visual parameters needed to reason about what would be drawn
- Must not require figure creation
- Must expose both a MATLAB struct view and a table view

### Required validation after Phase 2 work

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxSerialParsers.m');"
```

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxVisualStimulusPreview.m');"
```

## Phase 3: Nose-only runtime observability

This phase covers debugging improvements that belong only to the nose workflow and must stay out of `BehaviorBoxWheel.m`.

### Scope

- nose-only preflight
- nose decision-loop snapshots
- nose interrupted or partial-save repros

### Tasks

- Add a nose-only runtime snapshot helper such as `getNoseDebugSnapshot_()` in `BehaviorBoxNose.m`.
- Add a nose-only session preflight reporter around `ConfigureBox()` and `SetupBeforeLoop()`.
- Add a narrow nose save or interrupted-session smoke test, for example `fcns/testNoseInterruptedTrialSave.m`.
- Persist the last nose-specific fault context from the main loop when a trial fails.

### Acceptance criteria

#### Nose runtime snapshot

- Must use a stable struct schema and remain catch-safe.
- The top-level nose snapshot struct must include at least:
  - `SchemaVersion`
  - `GeneratedAt`
  - `Workflow`
  - `TrialState`
  - `InputState`
  - `SaveState`
  - `Warnings`
- `Workflow` must be fixed to `Nose`.
- `TrialState` must include at least:
  - `CurrentTrial`
  - `Phase`
  - `WhatDecision`
  - `Level`
  - `IsLeftTrial`
  - `CommittedTrialCount`
- `InputState` must include only nose-owned inputs such as:
  - `HoldState`
  - `PokeState`
  - `LastInputEvent`
- `SaveState` must include at least:
  - `SaveFolder`
  - `PendingSave`
  - `LastSaveAttempted`
- `Warnings` should be a cellstr for degraded capture notes
- Must not include wheel-only timestamp or imaging artifacts

#### Nose preflight reporter

- Must use the shared preflight schema and may extend it only with a nested `Nose` field.
- The optional nested `Nose` field should include at least:
  - `HoldRequirementEnabled`
  - `InputDeviceMode`
  - `InitialSideAssignment`
- The corresponding nose-only preflight smoke test should live under `MockApp/`
- Must be callable without entering the main loop

#### Nose interrupted-save smoke test

- Must reproduce a partial or interrupted save path without real hardware
- Must assert whether a `.mat` file is written, whether critical fields are present, and whether the failure context is inspectable

### Required validation after Phase 3 work

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxSessionPreflight.m');"
```

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testNoseInterruptedTrialSave.m');"
```

## Phase 4: Wheel-only runtime observability

This phase covers debugging improvements that belong only to the wheel workflow and should stay out of `BehaviorBoxNose.m`.

### Scope

- wheel-only runtime snapshots
- wheel preflight and setup visibility
- timestamp and acquisition event visibility
- interrupted and timestamp-integrity repros

### Tasks

- Add `fcns/testInterruptedTrialSave.m` as a narrow wheel-only repro for interrupted-session save behavior.
- Add `fcns/testWheelTimestampIntegrity.m` as a narrow wheel-only repro for timestamp-segment structure and trial-level completeness.
- Add a wheel-only runtime snapshot helper such as `getWheelDebugSnapshot_()` in `BehaviorBoxWheel.m`.
- Add a wheel-only setup or preflight reporter around `ConfigureBox()` and `SetupBeforeLoop()`.
- Persist the last wheel-specific fault context from `DoLoop()` when a trial fails.
- Keep the Timekeeper integration inspectable by logging frame-check requests, timestamp resets, acquisition start/end calls, and segment stores.

### Acceptance criteria

#### Wheel runtime snapshot

- Must use a stable struct schema and remain catch-safe.
- The top-level wheel snapshot struct must include at least:
  - `SchemaVersion`
  - `GeneratedAt`
  - `Workflow`
  - `TrialState`
  - `TimekeeperState`
  - `RecordState`
  - `SaveState`
  - `Warnings`
- `Workflow` must be fixed to `Wheel`.
- `TrialState` must include at least:
  - `CurrentTrial`
  - `Phase`
  - `WhatDecision`
  - `Level`
  - `IsLeftTrial`
  - `CommittedTrialCount`
- `TimekeeperState` must include at least:
  - `ActiveSegmentKind`
  - `ActiveSegmentTrial`
  - `AcquisitionStarted`
  - `LastTimestampReset`
- `RecordState` must include only wheel-owned record summaries such as:
  - `TimestampsRecordRows`
  - `WheelDisplayRecordRows`
  - `FrameAlignedRecordRows`
- `SaveState` must include at least:
  - `SaveFolder`
  - `PendingSave`
  - `LastSaveAttempted`
- `Warnings` should be a cellstr for degraded capture notes
- Must be safe to serialize in a catch path

#### Wheel preflight reporter

- Must use the shared preflight schema and may extend it only with a nested `Wheel` field.
- The optional nested `Wheel` field must include at least:
  - `TimestampSegmentStarted`
  - `ScanImageFileIndex`
  - `AcquisitionMode`
- The shared `Dependencies` block must summarize:
  - wheel Arduino connection result
  - Timekeeper connection result
  - keyboard fallback result
  - timestamp segment start result
  - active ScanImage file index when applicable
- Must be callable before the main loop

#### Interrupted-trial save smoke test

- Must simulate an interrupted wheel session
- Must assert save-path behavior and inspectable fault context

#### Timestamp-integrity smoke test

- Must assert:
  - timestamp segment structure exists
  - trial-level completeness is inspectable
  - saved wheel-side artifacts remain loadable by `BehaviorBoxData`

### Required validation after Phase 4 work

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelSaveStatus.m');"
```

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testInterruptedTrialSave.m');"
```

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testWheelTimestampIntegrity.m');"
```

```bash
matlab -batch "cd('/home/wbs/Desktop/BehaviorBox'); run('fcns/testBehaviorBoxDataLoad.m');"
```

## Guardrails

- Keep additive save fields backward-compatible unless a schema change is explicitly intended and documented.
- Keep headless repro scripts deterministic and side-effect-light.
- Prefer temporary-root validation when the bug class involves folder creation, lookup, or path selection.
- Keep wheel-only fields such as `timestamps_record`, `WheelDisplayRecord`, `FrameAlignedRecord`, imaging metadata, and microscope assumptions out of `BehaviorBoxNose.m`.
- Keep nose-only debugging work free of wheel-only schema assumptions.
