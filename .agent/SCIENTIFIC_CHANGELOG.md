# Scientific Output Changelog

Use this file for changes that affect scientific or numerical outputs, including:
- saved `.mat` fields or schema
- data loading compatibility
- preprocessing
- analysis metrics
- figures
- tables
- randomization
- tolerances
- trial inclusion/exclusion
- reward accounting
- microscope or eye-tracking alignment

Do not use this for pure documentation changes or behavior-preserving refactors.

Every AI agent must update this file when making changes that affect analysis or save behavior. This includes changes to `BehaviorBoxData.m`, `fcns/readFcn.m`, `BehaviorBoxNose.SaveAllData`, `BehaviorBoxWheel.SaveAllData`, automated analysis output, saved fields, graphs, tables, trial inclusion, moving-mean calculations, level grouping, microscope alignment, or eye-tracking alignment.

## Template

```markdown
## YYYY-MM-DD - Short Change Title

Changed files:
- `path/to/file.m`

Expected output differences:
- Describe field, figure, table, saved array, metric, or tolerance differences.

Validation:
- Exact command run.
- Short result summary.

Compatibility notes:
- Old data impact.
- Nose impact.
- Wheel impact.
- Any manual follow-up needed.
```

## Entries

## 2026-05-07 - Preserve Wheel Stimulus Geometry On Settings Updates

Changed files:
- `BehaviorBoxVisualStimulus.m`
- `BehaviorBoxWheel.m`
- `MockApp/MockApp.m`
- `MockApp/testBehaviorBoxWheelStimulusGeometryUpdate.m`

Expected output differences:
- During live Wheel training, non-geometry `Stimulus_*` setting updates no longer reset the existing `Stimulus` figure position or size.
- Changes to `Stimulus_position_x`, `Stimulus_position_y`, `Stimulus_size_x`, or `Stimulus_size_y` still intentionally reapply the requested figure geometry.
- No saved `.mat` schema, score vectors, level vectors, reward fields, randomization, or analysis tables are expected to change.

Validation:
- `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); run('MockApp/testBehaviorBoxWheelStimulusGeometryUpdate.m');"`
- Passed; printed `BEHAVIORBOX_WHEEL_STIMULUS_GEOMETRY_UPDATE_OK`.
- `matlab -batch "cd('/Users/willsnyder/Desktop/BehaviorBox'); checkcode('BehaviorBoxVisualStimulus.m'); checkcode('BehaviorBoxWheel.m'); checkcode('MockApp/MockApp.m'); checkcode('MockApp/testBehaviorBoxWheelStimulusGeometryUpdate.m');"`
- Completed with existing Code Analyzer warnings in the large class files; no MATLAB execution error.

Compatibility notes:
- Old data impact: none expected.
- Nose impact: none expected; the shared helper signature keeps the previous default geometry-apply behavior unless callers explicitly request preservation.
- Wheel impact: live display geometry is preserved across non-geometry settings updates.
- Manual follow-up: verify on the training computer with the real stimulus display after resizing the window by hand.
