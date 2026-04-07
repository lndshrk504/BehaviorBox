# Eye Tracking Repo Split Plan

Date: 2026-04-07
Revised: 2026-04-07 after user decisions

## Review Outcome

The earlier plan still had three wrong assumptions:

- it treated the extraction as mostly `DLC/` plus optional legacy material
- it assumed model/export artifacts would likely live in the new git repo
- it left too much ambiguity around MATLAB-facing ownership

Your latest answers make the target state much clearer.

The new repo should:

- own the tracker-specific MATLAB demos and clients
- include active and legacy eye-tracking code
- restore legacy material onto the new repo's default branch
- keep legacy content under `legacy/` with an identifying path
- rename the active tracked tree from `DLC/` to `EyeTrack/`
- avoid storing the heavy runtime model files in git
- be consumable from `BehaviorBox` as a submodule at `BehaviorBox/EyeTrack/`
- separate legacy binaries from legacy source/docs while still keeping them in the repo

`BehaviorBox` should keep only thin adapters and `BehaviorBox`-specific integration logic.

## Confirmed Decisions

From your answers, the plan now assumes:

1. The new repo includes both active and legacy eye-tracking material.
2. Tracker-specific MATLAB demos and clients belong to the new repo, not `BehaviorBox`.
3. `DLC/ToMatlab/receive_eye_stream_demo.m` is owned by the new repo.
4. `DLC/ToMatlab/matlab_zmq_bridge.py` is owned by the new repo.
5. Historical `iRecHS2` MATLAB clients should be restored onto the new repo's default branch.
6. Legacy code should live under `legacy/` using an identifying path such as `legacy/iRecHS2/`.
7. Legacy assets should be included alongside the legacy code.
8. `fcns/EyeTrack.m` stays in `BehaviorBox`.
9. The heavy runtime model files should not live in the new git repo.
10. The new repo should adopt a `models/` folder convention for manually copied runtime models.
11. The active tracked tree should be renamed from `DLC/` to `EyeTrack/` during extraction.
12. Git history should be preserved for the extracted tracked code and legacy material.
13. `BehaviorBox` should consume the new repo as a submodule mounted at `BehaviorBox/EyeTrack/`.
14. The migration should use a short transition period with setup docs and thin MATLAB wrappers before local copies are removed.
15. The extracted repo should be immediately runnable as a standalone repo.
16. The local staging location for the future repo should be `/Users/willsnyder/Desktop/EyeTrack`.
17. The separated legacy-binary path should be `binaries/iRecHS2/`.
18. The repo should include a tracked `models/README.md` or equivalent manifest for copied runtime models.
19. The bootstrap should include both a top-level `README.md` and a root bootstrap/setup script named `bootstrap_eye_track.m`.
20. `models/README.md` should document only the active model layout, not legacy binary/model placement.
21. Remote creation and hosting setup are deferred; for now only the local staging folder is required.
22. Nothing should be deleted from the current `BehaviorBox` folder during the transition period.
23. The in-repo placeholder path `BehaviorBox/EyeTrack/` should remain empty during the transition period.
24. The local staging folder `/Users/willsnyder/Desktop/EyeTrack` should remain empty until the user is ready to evaluate a scaffold there.
25. The next step remains plan-only for now; do not scaffold `/Users/willsnyder/Desktop/EyeTrack` yet.
26. During the current transition, do not add new wrapper code inside `BehaviorBox`; keep only the existing tree plus setup/docs.
27. Legacy binary placement should be documented in the top-level `README.md`, not in a separate `binaries/README.md`.
28. When the first scaffold is created, it should include placeholder `README.md` files inside the subfolders.
29. When the first scaffold is created, it should create the full empty directory skeleton:
    - `EyeTrack/ToMatlab/`
    - `EyeTrack/Tests/`
    - `legacy/iRecHS2/`
    - `binaries/iRecHS2/`
    - `models/`

## Current Repo Facts

### Active tracked eye-tracking content at current `HEAD`

The active tracked eye-tracking surface in this repo is:

- `DLC/ToMatlab/dlc_eye_streamer.py`
  Main Python streamer for FLIR/PySpin capture, DLCLive inference, pupil metrics, ZeroMQ publishing, optional overlay, and optional CSV output.
- `DLC/ToMatlab/matlab_zmq_bridge.py`
  Python helper used by MATLAB for ZeroMQ subscription.
- `DLC/ToMatlab/receive_eye_stream_demo.m`
  MATLAB demo subscriber using `pyenv`, `py.sys.path`, and `py.importlib`.
- `DLC/Tests/*.py`
  Focused dependency and hardware smoke scripts.
- `DLC/environment.yaml`
  DLC-related Python environment description.

There is also a tracked DLC model/export directory in the current repo:

- `DLC/DLC_PupilTracking_YangLab_resnet_50_iteration-0_shuffle-1/*`

But the revised plan does not treat that tracked directory as something to preserve in the new repo's git history. Instead, it treats runtime models as externally stored assets that should be copied into a non-history-bearing `models/` directory for actual use.

### Legacy tracked eye-tracking history

The legacy `iRecHS2/` tree is not present as tracked files in the current working tree, but it does exist in git history.

Key historical files include:

- `iRecHS2/scripts/irechs2.m`
  MATLAB `classdef iRecHS2 < handle` TCP client for the legacy eye tracker.
- `iRecHS2/scripts/sample_matlab.m`
  MATLAB sample using Psychtoolbox and the legacy `iRecHS2` client.
- `iRecHS2/scripts/irechs2.py`
  Python client for the legacy tracker.
- `iRecHS2/scripts/iRecSpotMovements.py`
- `iRecHS2/scripts/SpotStimulus.py`
- `iRecHS2/iRecTests/*`
  Legacy tests and documentation.
- historical legacy assets such as PDFs, images, and `iRecHS2.exe`

Important repo-history fact:

- `iRecHS2/` was explicitly deleted from `BehaviorBox` in commit `b5105c4` with message `Remove iRec, DeepLabCut is the new eye tracking method`.

That means the migration must do more than "preserve history". It must also explicitly restore the legacy tree into the new repo's default branch if the new repo is meant to contain usable legacy material.

### Files that should remain in `BehaviorBox`

Confirmed stay-put file:

- `fcns/EyeTrack.m`

What it is:

- a standalone MATLAB helper using `webcam`, `vision.CascadeObjectDetector`, and `vision.PointTracker`
- introduced separately from the DLC/ZeroMQ path
- not part of the current DLC streamer/subscriber path

Expected local ownership in `BehaviorBox` after the split:

- `fcns/EyeTrack.m`
- thin `BehaviorBox` adapters or wrappers
- app/session wiring inside `BehaviorBox`
- documentation about submodule setup and usage

### Current coupling level

Current repo search did not show active runtime references from:

- `BehaviorBoxWheel.m`
- `BehaviorBoxNose.m`
- `BB_App.m`
- `BehaviorBox_App.mlapp`

into the current tracked DLC files beyond planning/documentation references.

That suggests the eye-tracking subsystem is still loosely coupled enough to split cleanly, as long as ownership of adapter code stays disciplined.

## Files, Functions, And Scripts Involved

### New eye-tracking repo candidates

Tracked active candidates, to be renamed under the new repo's active tree:

- `DLC/ToMatlab/dlc_eye_streamer.py`
- `DLC/ToMatlab/matlab_zmq_bridge.py`
- `DLC/ToMatlab/receive_eye_stream_demo.m`
- `DLC/ToMatlab/README_eye_stream.md`
- `DLC/Tests/2CheckReqs.py`
- `DLC/Tests/CheckReqs.py`
- `DLC/Tests/GSTOCV.py`
- `DLC/Tests/Spin2DLC.py`
- `DLC/Tests/TestSpin.py`
- `DLC/Tests/VerCheck.py`
- `DLC/Tests/dlcspin.py`
- `DLC/environment.yaml`

Historical legacy candidates to restore from git history:

- `iRecHS2/scripts/irechs2.m`
- `iRecHS2/scripts/sample_matlab.m`
- `iRecHS2/scripts/irechs2.py`
- `iRecHS2/scripts/iRecSpotMovements.py`
- `iRecHS2/scripts/SpotStimulus.py`
- `iRecHS2/scripts/sample.py`
- `iRecHS2/iRecTests/*`
- legacy docs/assets including PDFs, images, and `iRecHS2.exe`

Candidates that should not be preserved in the new repo's git history:

- heavy runtime model files currently under `DLC/DLC_PupilTracking_YangLab_resnet_50_iteration-0_shuffle-1/`

### BehaviorBox-retained files

- `fcns/EyeTrack.m`
- any future `BehaviorBox`-specific wrapper or adapter code
- app wiring inside `BehaviorBox` root classes

### Current active entrypoints and interfaces

- `dlc_eye_streamer.py`
  Main Python runtime entrypoint.
- `matlab_zmq_bridge.py`
  Defines `open_subscriber`, `close_socket`, `recv_latest_dict`, and `recv_latest`.
- `receive_eye_stream_demo.m`
  Defines `receive_eye_stream_demo()`.

### Historical legacy entrypoints and interfaces

- `irechs2.m`
  Defines `classdef iRecHS2 < handle` with `connect`, `start`, `stop`, `close`, `send`, and `get`.
- `sample_matlab.m`
  Demonstrates MATLAB-side visualization driven by the legacy tracker.
- `irechs2.py`
  Python client with matching legacy protocol concepts.

## Final Ownership Model

### Canonical ownership

Recommended and now mostly confirmed ownership model:

- the new repo owns eye-tracker-specific code, legacy tracker code, tracker-specific MATLAB clients/demos, tracker-side Python helpers, legacy assets, and eye-tracking tests
- `BehaviorBox` owns only `BehaviorBox`-specific adapters, wrappers, and app integration

This is the cleanest possible submodule boundary.

### Explicit file-level ownership now settled

Owned by the new repo:

- `DLC/ToMatlab/receive_eye_stream_demo.m`
- `DLC/ToMatlab/matlab_zmq_bridge.py`
- restored legacy MATLAB clients such as `iRecHS2/scripts/irechs2.m` and `iRecHS2/scripts/sample_matlab.m`

Owned by `BehaviorBox`:

- `fcns/EyeTrack.m`
- thin adapters that call into the submodule
- any `BehaviorBox` session-specific integration layer

## Recommended Repo Shape

### Revised extraction rule

This is no longer a pure preserve-path split.

Because you explicitly want the active tracked tree renamed from `DLC/` to `EyeTrack/`, the extraction should preserve history but perform targeted path rewrites where they improve the new repo boundary.

The guiding rule is now:

- preserve history
- minimize renames
- but do the key renames that define the new repo identity cleanly on day one

The first extraction should do only the structural changes that are now explicitly required:

- rename active tracked content under `DLC/` into `EyeTrack/`
- restore legacy content under `legacy/iRecHS2/`
- separate legacy binaries from legacy source/docs
- exclude runtime model blobs from git history
- add a `models/` convention for external runtime models

### Recommended initial structure after extraction

```text
EyeTrack/
  EyeTrack/
    ToMatlab/
    Tests/
    environment.yaml
  legacy/
    iRecHS2/
      ...
  binaries/
    iRecHS2/
      ...
  models/
    ...
  README.md
```

This structure means:

- current active tracker code is clearly named for the subsystem instead of for DeepLabCut alone
- legacy code becomes explicit and segregated
- legacy binaries are kept, but not mixed into legacy source/doc paths
- runtime models have a known landing place without becoming part of git history
- the repo can be documented as a standalone toolchain rather than only as an extracted fragment

### Why I am not recommending an even broader rename yet

A deeper reorganization such as:

- splitting `EyeTrack/ToMatlab/` into top-level `matlab/` and `python/`
- flattening tests into top-level `tests/`
- redistributing docs across new folders

would be reasonable later, but it adds unnecessary path-rewrite risk on top of the rename you already want. The first migration should stop once the active tree is renamed, legacy is restored, binaries are separated, and models are externalized.

## Revised Migration Method

### Core method

Use a history-preserving extraction in a temporary clone, then add the result back to `BehaviorBox` as a private submodule.

### Why this is still the right method

This repo needs more than a simple copy because you want:

- code history preserved
- legacy material recovered from deleted history
- active eye-tracking files extracted cleanly
- the active tracked tree renamed into `EyeTrack/`
- model blobs deliberately excluded from the new repo's git history

That is a good fit for a temporary-clone workflow using `git filter-repo` or an equivalent path-filtering method.

### Revised extraction sequence

1. Create a fresh temporary clone of `BehaviorBox`.
2. Filter that clone down to the eye-tracking code paths that belong in the new repo.
3. Rename the active tracked paths from `DLC/...` into `EyeTrack/...`.
4. Explicitly exclude the tracked heavy model/export files from the extracted repo's git history.
5. Inspect the filtered history to confirm the active code history is intact after the path rewrite.
6. Restore the legacy `iRecHS2/` tree from git history onto the new repo's default branch under `legacy/iRecHS2/`.
7. Restore legacy non-binary assets there as well.
8. Restore legacy binaries under a separate top-level binary path.
9. Create a tracked `models/` directory convention, but keep actual heavy runtime models out of git.
10. Add standalone setup/docs so the extracted repo can run on its own immediately.
11. Initialize the local staging repo at `/Users/willsnyder/Desktop/EyeTrack`.
12. Later, connect that repo to its private remote(s).
13. Add the repo back into `BehaviorBox` as a submodule at `BehaviorBox/EyeTrack/`.
14. Keep a short transition period in `BehaviorBox` with setup docs and thin MATLAB wrappers.
15. Remove superseded local copies from `BehaviorBox` after the wrapper path is stable.

## Important Consequence Of Excluding Runtime Models From Git

This point is now central, not optional.

The current `BehaviorBox` repo tracks heavy model/export artifacts under `DLC/`.
Your new policy is:

- runtime model files do not belong in the new git repo
- users will manually copy the needed model into `models/`

That means the history-preserving extraction must be selective:

- preserve code history for the eye-tracking code
- do not preserve the heavy model blobs in the new repo history

This is a good idea.

It keeps the new repo:

- smaller
- faster to clone
- cleaner as a submodule
- less dependent on a particular trained artifact staying inside git forever

## Model And Binary Asset Plan

Current size facts from the working tree:

- `DLC/` is about `187M`
- the tracked DLC model directory is about `187M`
- two single files are about `92M` each:
  - `snapshot-650000.data-00000-of-00001`
  - `snapshot-650000.pb`

Revised decision:

- do not keep those heavy runtime model files in the new repo's git history
- instead, establish a `models/` directory in the repo for user-provided runtime models

Recommended convention:

- track the `models/` directory itself
- track only placeholders/docs inside `models/`
- do not track the copied runtime model contents
- document exactly what must be copied there

That keeps the repo usable without making git the storage system for large trained artifacts.

## Proposed BehaviorBox Submodule Model

### Fixed submodule path

The submodule should be mounted at:

- `BehaviorBox/EyeTrack/`

That means the final in-repo path will be:

- `/Users/willsnyder/Desktop/BehaviorBox/EyeTrack`

### Local staging path before submodule integration

The local staging location outside the repo should be:

- `/Users/willsnyder/Desktop/EyeTrack`

That is a good staging choice because it keeps the new repo independent while you decide on external hosting.

Current transition rule:

- the staging folder exists
- it should stay empty until the user is ready to evaluate the first scaffold there

### Hosting status

Remote creation is intentionally deferred for now.

Current assumption:

- the local staging repo lives at `/Users/willsnyder/Desktop/EyeTrack`
- GitHub and Dropbox hosting will be set up later by the user
- the current task should not assume a finalized remote or Dropbox-sync workflow yet

### BehaviorBox retention during the transition period

Keep in `BehaviorBox` during transition:

- all existing current files
- `fcns/EyeTrack.m`
- setup docs

Do not do during transition:

- do not delete anything from the current `BehaviorBox` folder
- do not populate `BehaviorBox/EyeTrack/` yet
- do not add new integration wrapper code yet

Any future wrapper work should happen only after the user approves the first scaffold under `/Users/willsnyder/Desktop/EyeTrack`.

## Risks And Stop Conditions

1. Mixed ownership risk
   If tracker-specific files remain duplicated across both repos, ownership and bug-fix responsibility will drift quickly.

2. Path-rewrite risk
   Restoring legacy content under `legacy/iRecHS2/` changes the path seen at the new repo's default branch even though history is preserved. That is fine, but it must be intentional and documented.

3. Model-location drift
   If the `models/` convention is not documented and gitignored clearly, users will put models in inconsistent places.

4. Private submodule friction
   A private submodule is workable, but it complicates fresh clones and onboarding until hosting/auth is finalized.

5. Deferred-hosting ambiguity
   Because remote creation is postponed, the first local scaffold should avoid assumptions that depend on GitHub URLs, Dropbox paths, or sync behavior.

6. Overly long transition
   A "short transition" is good; leaving both copies around for too long is not.

Stop if any proposed extraction step would:

- duplicate canonical ownership of the same tracker-specific file in both repos
- reintroduce the heavy runtime model blobs into the new repo history
- leave the new repo without the legacy content that you explicitly want restored
- leave `BehaviorBox` with undocumented assumptions about the `EyeTrack` submodule layout
- leave the extracted repo not immediately runnable on its own
- violate the current no-deletion / keep-placeholder-empty transition rule

## Recommended Next Implementation Phase

Once the remaining questions below are answered, the next version of the plan should include:

- exact keep/move file list
- exact filtered-path list for the history-preserving extraction
- exact excluded-path list for the heavy model artifacts
- exact restore target for legacy files under `legacy/`
- exact `models/` folder convention and ignore rules
- exact submodule-add and transition sequence for `BehaviorBox`

## New Questions

1. Do you want the next step to remain plan-only, or do you want me to create the first standalone local scaffold under `/Users/willsnyder/Desktop/EyeTrack` now using the agreed empty directory tree plus placeholder `README.md` files and `bootstrap_eye_track.m`?
