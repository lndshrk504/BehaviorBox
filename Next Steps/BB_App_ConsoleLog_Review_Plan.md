# BB App Console Log Review And Plan

Date: 2026-04-20

## Goal

Clean up how `BB_App` captures MATLAB Command Window output, shows that text in the GUI `Output` tab, and persists a reliable session log on disk.

The target behavior is:

- the GUI `Output` tab mirrors the text the user would expect from the MATLAB console
- the persisted log is authoritative and lives under the repo root in `Logs/`
- log lifecycle is deterministic and owned by one place
- the runtime classes do not fight over MATLAB's global `diary` state

## Scope

This note reviews:

- the current console-log implementation in `BB_App.m`
- the related runtime behavior in `BehaviorBoxNose.m` and `BehaviorBoxWheel.m`
- the relevant MATLAB logging methodology for `diary`, `evalc`, and App Designer text areas

This note does not implement the change. It defines the design and the plan.

## Current code path

### App startup / setup path in `BB_App.m`

Current setup behavior:

1. `BB_App` calls `setupDiaryFile(app, "BBAppOutput.txt")`
2. `setupDiaryFile` clears `MsgBox`, calls `diary off`, deletes `BBAppOutput.txt` if it exists, then calls `diary(fileName)`
3. `configureBehaviorBox` reads `BBAppOutput.txt` directly into `app.MsgBox.Value`
4. `finalizeSetup` reads `BBAppOutput.txt` again into `app.MsgBox.Value`, then calls `diary off`

Relevant locations:

- `BB_App.m:831-845`
- `BB_App.m:852-860`
- `BB_App.m:946-955`

### Runtime path in `BehaviorBoxNose.m`

Current nose runtime behavior:

1. `SetupBeforeLoop` creates `BBTrialLog_yyyyMMdd_HHmmss.txt`
2. the file is placed in `this.Data_Object.filedir`
3. `this.textdiary` points to that file
4. `diary(diaryname)` is called again from the runtime object
5. `updateMessageBox` tails the file incrementally using `textdiary_pos`
6. on any read failure, the code deletes the log file and restarts `diary`

Relevant locations:

- `BehaviorBoxNose.m:431-442`
- `BehaviorBoxNose.m:2217-2262`

### Runtime path in `BehaviorBoxWheel.m`

Current wheel runtime behavior:

1. `SetupBeforeLoop` creates `BBTrialLog_yyyyMMdd_HHmmss.txt`
2. the file is placed in `this.Data_Object.filedir`
3. `this.textdiary` points to that file
4. `diary(diaryname)` is called again from the runtime object
5. `updateMessageBox` rereads the entire file with `fileread`

Relevant locations:

- `BehaviorBoxWheel.m:454-460`
- `BehaviorBoxWheel.m:2220-2229`

### Background updater in `BB_App.m`

`BB_App.m` also contains `updateMsgBoxInBackground`, which polls `app.BB.textdiary` every two seconds and rereads the entire file. This appears to be an alternate design path and should not coexist with the runtime-specific refresh logic.

Relevant location:

- `BB_App.m:692-707`

## Findings

### 1. Log ownership is split across three places

`BB_App`, `BehaviorBoxNose`, and `BehaviorBoxWheel` all participate in log lifecycle. That is the root structural problem.

- `BB_App` owns setup logging
- `BehaviorBoxNose` owns nose trial logging
- `BehaviorBoxWheel` owns wheel trial logging

MATLAB `diary` is global state. It should have one owner for open, rotate, close, and path selection.

### 2. The current app-level log path is cwd-dependent

`setupDiaryFile(app, "BBAppOutput.txt")` uses a relative filename. Later, `configureBehaviorBox` and `finalizeSetup` read `'BBAppOutput.txt'` again by literal name.

This means behavior depends on the current working directory rather than an explicit absolute path.

### 3. Setup logs and trial logs are separate artifacts with no explicit contract

The current implementation uses:

- `BBAppOutput.txt` during app setup
- `BBTrialLog_*.txt` during a training run

The transition between those files is implicit. The code does not define whether the GUI `Output` tab is supposed to show:

- only the setup log
- only the trial log
- a continuous session log

### 4. Nose and wheel use different GUI-refresh methods for the same job

Nose:

- incremental tail with file-position tracking

Wheel:

- full-file reread using `fileread`

App:

- separate unused background full-file poller

This is a design smell. The GUI log-display path should have one implementation.

### 5. Nose currently deletes the active log on read failure

This is the riskiest behavior in the current code. A read error should never destroy the authoritative session log.

Current failure behavior in `BehaviorBoxNose.updateMessageBox`:

- catch any read error
- delete the log file if it exists
- restart `diary`
- clear the GUI box

That turns a transient display problem into data loss.

### 6. The current runtime log location is wrong for the desired purpose

Today the runtime log is written under `this.Data_Object.filedir`, which is effectively the subject/session data area.

For a GUI console log, the better location is the repo root:

```text
BehaviorBox/Logs/
```

That separates:

- operator console/session logs
- saved experiment data

### 7. The UI API is inconsistent

`BB_App` writes `app.MsgBox.Value`, while the runtime classes write `GuiHandles.MsgBox.String`.

For an App Designer text area, the current API should be standardized on `Value`.

## MATLAB methodology review

### `diary` is the right primitive for whole-session Command Window capture

MathWorks documents `diary` as capturing entered commands, keyboard input, and text output from the Command Window.

Important points from the official documentation:

- `diary` captures Command Window text to a text file
- if the filename is relative, MATLAB resolves it relative to the current folder when logging is enabled
- `get(0,'Diary')` reports whether diary logging is on
- `get(0,'DiaryFile')` reports the current diary file

That matches the BehaviorBox need much better than ad hoc `evalc` wrapping.

Official references:

- `diary`: https://www.mathworks.com/help/matlab/ref/diary.html
- write-to-diary overview: https://www.mathworks.com/help/matlab/import_export/write-to-a-diary-file.html

### `evalc` is useful in narrow cases, but not as the main session logger

MathWorks documents `evalc` as capturing what would normally be written to the Command Window for one evaluated expression.

That is not the right main design here because:

- it only captures code that is explicitly wrapped in `evalc`
- it is less efficient and harder to debug than normal MATLAB execution
- when using `evalc`, `diary` is disabled

That makes `evalc` a poor fit for BehaviorBox-wide console logging, especially with callbacks, timers, and runtime objects.

Use `evalc` only if a specific narrow operation must capture text as a string without using the session log.

Official reference:

- `evalc`: https://www.mathworks.com/help/matlab/ref/evalc.html

### App Designer text area behavior matters

MathWorks documents `TextArea.Value` as the supported property for multi-line text display. Multiple lines should be represented as a string array or cell array of character vectors. The `scroll` function can move the view to the bottom.

This matters for the GUI mirror:

- the app should write `MsgBox.Value`
- the app can keep only a recent window of lines in memory for responsiveness
- the app can call `scroll(app.MsgBox, "bottom")` after refresh

Official reference:

- `TextArea`: https://www.mathworks.com/help/matlab/ref/matlab.ui.control.textarea.html

## Design iteration

I considered three plausible designs.

### Option A: keep the current split and only tidy names

Description:

- keep `BB_App` setup log
- keep separate nose/wheel trial logs
- clean up some filenames and helper names

Why I reject it:

- still leaves multiple owners for global `diary`
- still leaves the setup-to-run transition implicit
- still keeps GUI-refresh logic duplicated

### Option B: replace the design with `evalc`

Description:

- wrap setup and runtime calls with `evalc`
- append captured text to the GUI and a file

Why I reject it:

- only captures wrapped expressions
- creates intrusive plumbing across many call sites
- conflicts conceptually with `diary`
- worse fit for callback-heavy behavior code

### Option C: one app-owned `diary` log plus one GUI tail helper

Description:

- `BB_App` owns the `diary` lifecycle
- one authoritative file under `Logs/`
- the GUI mirrors that file through a single tail helper
- runtime classes stop creating or deleting log files

Why I choose it:

- matches MATLAB's actual logging primitive
- removes cross-class ownership ambiguity
- preserves console behavior with minimal semantic change
- gives one stable file contract and one stable UI contract

## Chosen design

### Authoritative log location

The authoritative GUI console log should be written to:

```text
fullfile(repoRoot, "Logs")
```

The implementation should create the folder if it does not already exist.

### Authoritative filename format

Recommended filename format:

```text
BBConsoleLog_yyyyMMdd_HHmmss_<BoxID>.txt
```

Example:

```text
BBConsoleLog_20260420_153412_Wheel.txt
```

### Box ID source

Use the resolved box identity that `FindArduino` discovers and stores in `app.Arduino_Com.Value`.

That value should be normalized into a file-safe token:

- keep letters and numbers
- keep `_` and `-`
- replace other characters with `_`
- trim repeated separators

Fallbacks:

1. resolved Arduino identity from `FindArduino`
2. current input mode, such as `Wheel` or `NosePoke`
3. `UnknownBox`

### One log file per app session, not one file per object

Refined decision:

- create one log file for the app session after the box identity is known
- keep that log active through setup, run, stop, and cleanup
- if multiple training runs happen in the same app instance, write session boundary banners into the same file rather than reopening `diary`

This avoids mid-session `diary` churn and keeps ownership simple.

If a future requirement demands one file per training run, the same helper can later rotate files at `Start_Callback`, but that should not be the first cleanup step.

### The GUI is a live mirror, not the authoritative store

The authoritative artifact is the file in `Logs/`.

The GUI `Output` tab should be treated as a live mirror of that file:

- incrementally tailed
- refreshed on a timer or on key state transitions
- allowed to keep only a bounded recent window in memory

### Central ownership

`BB_App` should own:

- path construction
- folder creation
- `diary on`
- `diary off`
- current log metadata
- GUI refresh
- final flush on close

`BehaviorBoxNose` and `BehaviorBoxWheel` should not own:

- log file naming
- log file creation
- log file deletion
- direct `diary` lifecycle

## Proposed app-level contract

Add explicit properties in `BB_App` for log state:

- `ConsoleLogRoot`
- `ConsoleLogPath`
- `ConsoleLogFileName`
- `ConsoleLogBoxID`
- `ConsoleLogReadOffset`
- `ConsoleLogTimer`
- `ConsoleLogIsActive`

Recommended helpers in `BB_App`:

- `resolveRepoRoot_()`
- `sanitizeBoxId_(rawId)`
- `buildConsoleLogPath_(boxId, timestamp)`
- `openConsoleLog_()`
- `closeConsoleLog_()`
- `writeConsoleLogBanner_(text)`
- `refreshConsoleLogView_()`
- `startConsoleLogTimer_()`
- `stopConsoleLogTimer_()`

## Refined implementation plan

### Phase 1: centralize path and naming in `BB_App`

Goal:

- stop using hard-coded `'BBAppOutput.txt'`
- define the future `Logs/` path contract first

Tasks:

- determine repo root explicitly from `BB_App.m`
- create `Logs/` under the repo root if needed
- derive Box ID after `FindArduino`
- build a full absolute log path using timestamp plus Box ID
- store the path on `app`
- use `get(0,'DiaryFile')` and `get(0,'Diary')` for sanity checks during development

Acceptance criteria:

- the log path is absolute, never relative
- the filename includes timestamp and Box ID
- the log goes under `BehaviorBox/Logs/`

### Phase 2: make `BB_App` the only `diary` owner

Goal:

- remove split ownership of MATLAB's global `diary`

Tasks:

- move all log open/close operations into `BB_App`
- stop calling `diary` from `BehaviorBoxNose`
- stop calling `diary` from `BehaviorBoxWheel`
- replace `finalizeSetup` shutdown of `diary` with banner-based phase transitions

Acceptance criteria:

- `diary(` appears only in the central logging helper path
- `BehaviorBoxNose.m` and `BehaviorBoxWheel.m` no longer create their own diary files
- no runtime class deletes a console log file

### Phase 3: replace duplicate GUI refresh logic with one incremental tail helper

Goal:

- one display path for the `Output` tab

Tasks:

- remove or retire `updateMsgBoxInBackground`
- remove the wheel full-file reread path
- remove the nose destructive recovery path
- implement one offset-based tail reader in `BB_App`
- store `ConsoleLogReadOffset` on the app
- write `MsgBox.Value`
- scroll the text area to the bottom after refresh

Recommended behavior:

- refresh at a modest cadence such as 0.25 to 0.5 seconds while training is active
- optionally slow to 1 second when idle
- keep the entire file on disk, but only the last N lines in the GUI if needed for responsiveness

Acceptance criteria:

- the GUI no longer rereads the entire log file on every update
- the GUI no longer deletes the log on read error
- the `Output` tab tracks the live log cleanly

### Phase 4: define transition and boundary markers

Goal:

- make the log readable as an operator artifact

Tasks:

- write a session-start banner after log open
- write a setup-complete banner
- write a training-start banner with subject, strain, input mode, and timestamp
- write a training-end banner
- write an app-close banner

Recommended banner fields:

- wall-clock timestamp
- Box ID
- input mode
- subject
- strain
- investigator

Acceptance criteria:

- one log is readable without external context
- a single file can represent multiple starts/stops cleanly if the app remains open

### Phase 5: add final flush and close behavior

Goal:

- ensure the file and GUI end in a consistent state

Tasks:

- on stop or app close, call `diary off`
- perform one final `refreshConsoleLogView_()`
- stop and delete the refresh timer cleanly
- leave the final path visible in the GUI or console for debugging

Acceptance criteria:

- no orphan timer
- no active `diary` left on after app close
- final file contents match the last visible GUI output

## Specific code cleanup targets

### `BB_App.m`

Change:

- replace `setupDiaryFile(app, "BBAppOutput.txt")` with a central `openConsoleLog_()` path
- remove direct reads of `'BBAppOutput.txt'`
- own refresh logic and timer

Keep:

- existing startup/setup prints, which can continue to use `fprintf`

### `BehaviorBoxNose.m`

Change:

- remove runtime-owned `diary(diaryname)` creation
- remove delete-and-recreate behavior on read errors
- stop owning `textdiary` as an authoritative file path

Transition-friendly compromise:

- if minimizing churn, keep `textdiary` only as a mirror of `app.ConsoleLogPath` for one phase, then remove it later

### `BehaviorBoxWheel.m`

Change:

- remove runtime-owned `diary(diaryname)` creation
- stop rereading the whole file every update
- stop owning the log lifecycle

Transition-friendly compromise:

- same as nose: `textdiary` can temporarily alias the app-owned path during refactor

## Validation plan

### Static checks

- verify that the only remaining `diary(` calls are in the centralized app helper path
- verify there are no remaining hard-coded references to `BBAppOutput.txt`
- verify there are no remaining `BBTrialLog_*.txt` path creators in nose/wheel runtime setup

### Manual MATLAB checks

1. Launch the app with Wheel hardware available.
2. Confirm a file is created under `BehaviorBox/Logs/`.
3. Confirm the filename contains the current timestamp and Box ID.
4. Confirm setup messages appear both in the file and in the GUI `Output` tab.
5. Press `Start`.
6. Confirm runtime messages append to the same file and appear in the GUI.
7. Press stop or end the run.
8. Confirm the log is finalized cleanly and remains on disk.
9. Repeat with Nose mode.

### Edge-case checks

- change the current working directory and confirm the log still goes to `BehaviorBox/Logs/`
- run with no resolved Arduino identity and confirm fallback filename behavior such as `UnknownBox`
- confirm no console log is created in the subject data folder
- confirm repeated training starts in one app instance append clear session markers rather than opening ambiguous new files

## Recommended first implementation pass

The first pass should be conservative:

1. Add app-owned log path construction under `Logs/`
2. Keep one app-owned `diary` active after box discovery
3. Keep existing `fprintf` usage
4. Replace hard-coded setup file reads with the stored absolute path
5. Move GUI refresh to one offset-based app helper
6. Stop runtime classes from deleting or reopening log files

That gets the architecture right before any more ambitious features.

## Optional later improvements

These are useful, but not required for the first cleanup:

- add a sidecar metadata file, for example `.json`, next to the text log
- add severity-tagged helper functions such as `logInfo`, `logWarn`, `logError`
- keep an in-memory ring buffer for the GUI while preserving the full file on disk
- add a button to open the current log file location from the GUI
- add a small smoke test for filename generation and path sanitization

## Final recommendation

Do not replace the current design with `evalc`.

The correct cleanup direction is:

- keep `diary` as the capture primitive
- move ownership into `BB_App`
- write one authoritative log in `BehaviorBox/Logs/`
- name it with timestamp plus Box ID
- make the GUI `Output` tab a clean live mirror of that file
- remove runtime-owned log creation and any destructive recovery behavior

That is the smallest design that is both cleaner and more reliable than the current implementation.
