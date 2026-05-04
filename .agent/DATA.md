# Data Notes

BehaviorBox session data is not stored inside this git repository. It is stored in Dropbox and discovered by `fcns/GetFilePath.m`.

## Data Roots

Use `GetFilePath("Data")` rather than hard-coding platform paths.

The intended platform-independent data root is:

```text
<Dropbox root>/William Snyder/Data
```

The current `fcns/GetFilePath.m` implementation resolves that as:

```text
macOS/Linux: ~/Dropbox @RU Dropbox/William Snyder/Data
Windows:     G:/Dropbox @RU Dropbox/William Snyder/Data
```

The archive root is:

```text
<Dropbox root>/William Snyder/Data Archive
```

## Active Branches

Only one investigator branch is active today:

```text
Will/
```

Only two input methods are active or expected:

```text
Will/NosePoke/
Will/Wheel/
```

If another investigator joins later, that folder should sit beside `Will/`, not inside it.

## Folder Layout

BehaviorBox data layout is:

```text
<DataRoot>/<Inv>/<Inp>/<Str>/<Sub>/
```

Where:
- `Inv` is usually `Will`
- `Inp` is `NosePoke` or `Wheel`
- `Str` is the strain, group, or cohort folder
- `Sub` is the mouse ID or subject folder

Examples:

```text
~/Dropbox @RU Dropbox/William Snyder/Data/Will/NosePoke/shank/3246453/
~/Dropbox @RU Dropbox/William Snyder/Data/Will/Wheel/New/3421911/
```

Subject folders may be bare IDs such as `3169024` or metadata-decorated names such as `2618912 - F - WT`.

## Data Safety

All `.mat` files under the Dropbox data root are canonical outputs unless the project owner says otherwise. If a `.mat` file looks questionable, stop and ask.

All subject folders under the data root are safe for read-only testing. No subject folders are known to be read-prohibited.

Agents must not create new subject folders in the real Dropbox data root during validation. New folders sync to production computers and can make the live data tree messy. Use temp or shadow roots for validation that creates folders.

Generated `.txt` and metadata files are not currently analysis-critical.

Do not move, rename, delete, rewrite, or mass-edit real Dropbox data unless explicitly requested.

## Loader Contract

`BehaviorBoxData.GetFiles()` resolves animal data through:

```matlab
fullfile(GetFilePath("Data"), Inv, Inp)
```

If an exact `Str/Sub` folder exists, it should be used directly. If it is missing or `Str` is omitted, the loader may fall back to recursive subject search.

Missing-subject lookup should not eagerly create real Dropbox folders. Folder creation belongs to save-time code such as:
- `BehaviorBoxNose.SaveAllData`
- `BehaviorBoxWheel.SaveAllData`
- `BehaviorBoxData.SaveAllData`

## Read-Only Test Expectations

The project owner expects all legitimate data in Dropbox to load for testing. Older schemas should continue to load unless supporting them would require major code changes. If a schema looks too different, stop and ask before adding compatibility code.

