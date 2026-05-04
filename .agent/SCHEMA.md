# Saved Data Schema Notes

Saved session data is schema-sensitive. Treat any change to saved fields, field names, loaded structures, or compatibility behavior as a scientific behavior change.

## Canonical Output

All `.mat` files under the Dropbox data root are canonical outputs unless the project owner says otherwise.

Session data should save everything in `DataObject.current_data`, created by `BehaviorBoxData`.

The two most important downstream analysis fields are:
- `Score`
- `Level`

The core project measurement is how many trials a mouse needs to complete before answering consistently above 80 percent at each level. Performance is defined as a moving mean of `Score` over binned trials. A common comparison is the moving mean of the last 20 trials.

The naming conventions for session files live in:
- `BehaviorBoxNose.SaveAllData`
- `BehaviorBoxWheel.SaveAllData`

Do not rename outputs or change save naming without explicitly calling it out.

## Load Path

Saved data must load through:
- `BehaviorBoxData.m`
- `fcns/readFcn.m`

Anything that prevents data saved by Nose or Wheel from loading through those paths is a breaking schema change.

`BehaviorBoxData.m` also performs analysis work downstream of loading, so exact field names matter for analysis compatibility.

## Required Compatibility

Old `.mat` schemas are expected to load unless they are too different and would require major code changes. When in doubt, ask before changing loader behavior.

Field presence matters. Field order does not matter.

The newest additions are:
- microscope frame timestamps
- eye tracking fields

Older data may not contain those fields.

## Nose And Wheel Shape

Nose and Wheel saves are expected to produce comparable output structures. The major intentional difference is that only Wheel saves should include imaging and microscope-related fields.

Including imaging fields in Nose data is not expected to corrupt analysis, but it wastes storage and makes output visually messy. Keep Wheel-only imaging fields out of Nose saves.

## Compatibility Checklist For Agents

Before changing `BehaviorBoxData.m`, `fcns/readFcn.m`, `BehaviorBoxNose.m`, or `BehaviorBoxWheel.m`, answer:
- Does this alter saved field names?
- Does this alter field presence?
- Does this alter file naming?
- Does this alter folder discovery?
- Does this alter how old `.mat` files load?
- Does this alter analysis outputs, figures, tables, or tolerances?
- Does this introduce Wheel-only microscope fields into Nose?

If yes to any item, document expected differences before editing and run targeted validation after editing.
