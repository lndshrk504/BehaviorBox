# Workflow Notes

Use these as starting points. Always inspect the current code before editing.

## Production Training Workflow

The human workflow is the same for Nose and Wheel.

1. On a Linux behavior computer, start `BehaviorBox_App.mlapp`.
2. Run two instances of BehaviorBox on one computer.
3. Enter the subject ID number.
4. The GUI loads the mouse's behavior training history.
5. Start training.
6. The mouse interacts with hardware in an acrylic box.
7. Arduino sensors send serial signals to MATLAB.
8. The mouse performs a visual experiment, identifying whether the correct stimulus appeared on the left or right side.
9. Correct behavior is rewarded with Gatorade.
10. After a few hours, click stop.
11. Data is saved to Dropbox by `BehaviorBoxNose` or `BehaviorBoxWheel`.

## Nose Work

Map these files before editing Nose behavior:
- `BehaviorBox_App.mlapp`
- `BB_App.m`
- `BehaviorBoxNose.m`
- `BehaviorBoxData.m`
- `BehaviorBoxVisualStimulus.m`
- serial helper classes/functions used by Nose
- active Arduino sketch, usually `Arduino/Photogate/Photogate.ino`

Keep Nose free of microscope-specific behavior.

## Wheel Work

Map these files before editing Wheel behavior:
- `BehaviorBox_App.mlapp`
- `BB_App.m`
- `BehaviorBoxWheel.m`
- `BehaviorBoxData.m`
- `BehaviorBoxVisualStimulus.m`
- serial helper classes/functions used by Wheel
- active Arduino sketch, usually `Arduino/Rotary/Rotary.ino`

Wheel owns microscope signaling, acquisition start/end behavior, and frame timestamp recording.

## Data Loader Work

Map these files before changing data loading:
- `BehaviorBoxData.m`
- `fcns/readFcn.m`
- `fcns/GetFilePath.m`
- `fcns/testBehaviorBoxDataLoad.m`
- `fcns/testBehaviorBoxDataNoEagerMkdir.m`
- `fcns/testBehaviorBoxDataDeferredSaveMkdir.m`
- `fcns/testBehaviorBoxDataAllRootLoads.m`
- `fcns/testBehaviorBoxDataOldAnalysis.m`
- `fcns/testBehaviorBoxDataMixedEyeFieldsLoad.m`

Do not create real Dropbox subject folders during lookup validation.

## SaveAllData Work

Before changing `SaveAllData` in `BehaviorBoxNose.m` or `BehaviorBoxWheel.m`:
- inspect current file naming
- inspect path normalization
- inspect setting struct handling
- inspect graph-copy/export logic
- inspect old data compatibility through `BehaviorBoxData.m` and `fcns/readFcn.m`

After edits, validate that newly saved data loads again through both `BehaviorBoxData.m` and `fcns/readFcn.m`.

## Analysis Automation

The project owner wants to revive automated analysis. The intended future direction is a cron job on a Linux computer that runs:

```text
BehaviorBox/NewAnalysis.m
```

The cron run should produce PDFs stored in the data root folder. The analysis functions need updating before this is production-ready.

Agents should treat automated analysis work as scientific-output-affecting unless proven otherwise. Update `.agent/SCIENTIFIC_CHANGELOG.md` for changes that alter figures, tables, saved arrays, preprocessing, metrics, or tolerances.

## DLC Eye Tracking Work

The active eye-tracking bridge is `DLC/ToMatlab/`. `iRecHS2/` is inactive historical reference.

The bridge uses ZMQ text communication from the eye-tracking computer to the behavior computer.

Known Python environments:
- `dlclivegui` on the eye-tracking computer
- `bbeyezmq` on the behavior computer

Model weights are copied into the repo from Dropbox, where they are stored.

Before changing message parsing, inspect the code to determine the exact text format, shapes, dtypes, and indexing conventions.

## GUI Cleanup

There are leftover behavior modes in the GUI that the project owner would like to remove eventually. Only Nose and Wheel are active.

Treat this as a future GUI cleanup task. Before removing GUI modes, map callbacks in `BB_App.m` and verify no active Nose or Wheel path depends on shared callback state.
