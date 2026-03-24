    # Execution Plans for this repo

    Use an execution plan for any task that is:
    - multi-file
    - cross-language or cross-runtime
    - likely to take more than one validation cycle
    - likely to change scientific outputs, saved-file schema, or numerical behavior

    Every plan must include:
    1. Goal
    2. Non-goals
    3. Current-state summary
    4. Files likely touched
    5. Validation commands
    6. Milestones
    7. Risks and stop conditions
    8. Handoff notes

    Operating rules:
    - keep milestones small and verifiable
    - run validation after every milestone
    - do not widen scope without updating the plan
    - update the plan when reality changes
    - For MATLAB milestones, include the exact `matlab -batch` command you will run.
- If the task crosses MATLAB and Python, list both sides of the boundary and the file/schema contract.

    Required stop conditions:
    - stop if MATLAB and Python disagree on shapes, dtypes, indexing, or file schema
- stop if a change would silently alter saved `.mat`, `.h5`, `.json`, or `.csv` outputs without an explicit migration note

## 2026-03-23 Add Criterion Analytics To BehaviorBoxData

1. Goal
- Add the additive `TrialsToCriterion80`, `trialsToCriterionSliding`, and `trialsToCriterionBayes` methods from the reviewed `BehaviorBoxData_Revised.m` into the live `BehaviorBoxData.m`.

2. Non-goals
- Do not change acquisition behavior, save-path behavior, plotting, GUI wiring, or existing analysis outputs unless the new methods are explicitly called.
- Do not merge any other revised-file changes.

3. Current-state summary
- `BehaviorBoxData.m` is a plain root-level classdef, not in a package, class folder, or `private/` folder.
- The class is instantiated from `BehaviorBoxNose.m`, `BehaviorBoxWheel.m`, and `BB_App.m`.
- No existing `TrialsToCriterion*` methods are present in the live repo.
- `BehaviorBoxData` constructor adds the local `fcns/` folder to path.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxData.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint: `checkcode('BehaviorBoxData.m')`
- MATLAB smoke check:
  `Tbl = table([1;1;1;0;1;1;1;1],[1;1;1;1;1;1;1;1],'VariableNames',{'Score','Level'});`
  `bb = BehaviorBoxData('find',true);`
  `T = bb.TrialsToCriterion80(Tbl,'Window',4,'Criterion',0.75);`
  `disp(T);`

6. Milestones
- Add the new instance method and static helpers only.
- Run MATLAB lint.
- Run the focused in-memory smoke check.

7. Risks and stop conditions
- This is analysis code, so the allowed behavior change is limited to new outputs from explicit calls to the new methods.
- Stop if adding the methods changes class parsing, constructor dispatch, or existing analysis/save behavior.

8. Handoff notes
- Call out that existing outputs should remain invariant unless a caller starts using the new methods.
- Report the exact validation commands and any remaining gaps.

## 2026-03-23 Add Timekeeper Frame Reset Command

1. Goal
- Add a serial command to `Arduino/Timekeeper/Timekeeper.ino` so sending character `0` resets the emitted frame counter to zero.
- Call that new reset path from `BehaviorBoxWheel.m` during `SetupBeforeLoop`.

2. Non-goals
- Do not change Timekeeper timestamp semantics or reset the session microsecond clock.
- Do not change `BehaviorBoxSerialTime.m` parsing unless the new firmware behavior requires it.
- Do not modify `Rotary.ino` or `Photogate.ino`; use them only as reference patterns.

3. Current-state summary
- `Rotary.ino` already handles serial command `0` by resetting its encoder state.
- `Timekeeper.ino` currently has no command parser in `loop()`.
- `BehaviorBoxWheel.SetupBeforeLoop()` prepares the time log but does not currently reset the Timekeeper frame counter.

4. Files likely touched
- `/Users/willsnyder/Desktop/BehaviorBox/Arduino/Timekeeper/Timekeeper.ino`
- `/Users/willsnyder/Desktop/BehaviorBox/BehaviorBoxWheel.m`
- `/Users/willsnyder/Desktop/BehaviorBox/.agent/PLANS.md`

5. Validation commands
- MATLAB lint: `checkcode('BehaviorBoxWheel.m')`
- Read-only firmware sanity review via diff and direct inspection because no Arduino build path is currently configured in the repo instructions.

6. Milestones
- Add a non-blocking serial command handler in `Timekeeper.ino` for `0`.
- Reset the frame counter safely without resetting the monotonic time base.
- Call the reset from `BehaviorBoxWheel.SetupBeforeLoop()` before opening the new time segment.
- Run focused validation on the MATLAB side and inspect the final diff.

7. Risks and stop conditions
- Stop if the reset design would also reset session timestamps or silently alter the logged time base.
- Stop if the MATLAB call site would race with serial setup in a way that risks losing the reset command.

8. Handoff notes
- Report whether buffered events are cleared or retained on reset.
- Call out that frame numbering after reset will restart from zero/one depending on whether the first emitted frame is counted post-edge.
