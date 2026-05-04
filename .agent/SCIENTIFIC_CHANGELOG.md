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

No scientific-output-affecting changes recorded yet.
