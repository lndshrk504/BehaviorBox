scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
cd(repoRoot);
run('startup.m');

cfg = localPickLoaderConfig();
fprintf("BehaviorBoxData load smoke test config: Inv=%s Inp=%s Str=%s Sub=%s\n", ...
    cfg.Inv, cfg.Inp, cfg.Str, cfg.Sub);

BBData = localLoadBehaviorBoxData(cfg);
if isempty(BBData.loadedData)
    cfg = localDiscoverLatestConfig(cfg.Inv, cfg.Inp);
    fprintf("Default subject returned no data. Retrying discovered config: Inv=%s Inp=%s Str=%s Sub=%s\n", ...
        cfg.Inv, cfg.Inp, cfg.Str, cfg.Sub);
    BBData = localLoadBehaviorBoxData(cfg);
end

assert(~isempty(BBData.loadedData), 'BehaviorBoxData loadedData is empty.');
assert(size(BBData.loadedData, 1) == numel(BBData.fds.Files), 'Mismatch between loaded rows and datastore files.');

targetIdx = localPickTargetIndex(BBData.loadedData);
targetFile = string(BBData.fds.Files{targetIdx});
report = bb_debug_saved_file(targetFile);

assert(report.HasNewData, 'Selected file does not contain newData.');
assert(report.CommittedTrialCount >= 1, 'Selected file has no committed trials.');
if report.HasWheelDisplayRecord
    requiredWheelCols = ["trial", "phase", "tTrial"];
    assert(all(ismember(requiredWheelCols, report.WheelDisplayColumns)), 'WheelDisplayRecord is missing required columns.');
end
if report.HasTimestampRecord
    assert(report.TimestampSegmentCount >= 1, 'TimestampRecord has no segments.');
end

fprintf("LoadedData rows: %d\n", size(BBData.loadedData, 1));
fprintf("Target file: %s\n", targetFile);
fprintf("BEHAVIORBOX_DATA_LOAD_OK\n");

function cfg = localPickLoaderConfig()
cfg = struct( ...
    'Inv', localEnvOrDefault("BB_DEBUG_INV", "Will"), ...
    'Inp', localEnvOrDefault("BB_DEBUG_INP", "Wheel"), ...
    'Str', localOptionalEnv("BB_DEBUG_STR"), ...
    'Sub', localEnvOrDefault("BB_DEBUG_SUB", "3421911"));
end

function BBData = localLoadBehaviorBoxData(cfg)
if strlength(cfg.Str) > 0
    BBData = BehaviorBoxData( ...
        'Inv', char(cfg.Inv), ...
        'Inp', char(cfg.Inp), ...
        'Str', char(cfg.Str), ...
        'Sub', {char(cfg.Sub)}, ...
        'find', 1, ...
        'analyze', 0);

    if ~isempty(BBData.loadedData)
        return
    end

    fprintf("BehaviorBoxData load with explicit strain returned no data. Retrying recursive search without Str.\n");
end

BBData = BehaviorBoxData( ...
    'Inv', char(cfg.Inv), ...
    'Inp', char(cfg.Inp), ...
    'Sub', {char(cfg.Sub)}, ...
    'find', 1, ...
    'analyze', 0);
end

function value = localEnvOrDefault(envName, defaultValue)
value = string(getenv(envName));
if strlength(strtrim(value)) == 0
    value = string(defaultValue);
else
    value = strtrim(value);
end
end

function value = localOptionalEnv(envName)
value = string(getenv(envName));
value = strtrim(value);
end

function cfg = localDiscoverLatestConfig(inv, inp)
dataRoot = fullfile(GetFilePath("Data"), inv, inp);
matFiles = dir(fullfile(dataRoot, '**', '*.mat'));
if isempty(matFiles)
    error("testBehaviorBoxDataLoad:NoData", "No .mat files found under %s", dataRoot);
end

badFolders = contains(string({matFiles.folder}), "LevelGroup", "IgnoreCase", true) | ...
    contains(string({matFiles.folder}), "settings", "IgnoreCase", true) | ...
    contains(string({matFiles.folder}), "Rescued", "IgnoreCase", true);
matFiles = matFiles(~badFolders);
if isempty(matFiles)
    error("testBehaviorBoxDataLoad:NoCandidateFiles", "No candidate wheel files found under %s", dataRoot);
end

[~, newestIdx] = max([matFiles.datenum]);
selected = matFiles(newestIdx);
[strainDir, subName] = fileparts(selected.folder);
[~, strainName] = fileparts(strainDir);

cfg = struct( ...
    'Inv', string(inv), ...
    'Inp', string(inp), ...
    'Str', string(strainName), ...
    'Sub', string(subName));
end

function idx = localPickTargetIndex(loadedData)
latestTrainingIdx = [];
for iRow = size(loadedData, 1):-1:1
    sessionData = loadedData{iRow, 3};
    if ~isstruct(sessionData)
        continue
    end
    if isempty(latestTrainingIdx)
        latestTrainingIdx = iRow;
    end
    extras = loadedData{iRow, 5};
    if isfield(sessionData, 'WheelDisplayRecord') || localHasNewDataSessionField(extras, 'WheelDisplayRecord')
        idx = iRow;
        return
    end
end
idx = latestTrainingIdx;
assert(~isempty(idx), 'No training file with newData found in loadedData.');
end

function tf = localHasNewDataSessionField(extras, fieldName)
tf = isstruct(extras) && ...
    isfield(extras, 'NewDataSessionFields') && ...
    isstruct(extras.NewDataSessionFields) && ...
    isfield(extras.NewDataSessionFields, fieldName);
end
