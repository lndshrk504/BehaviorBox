scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
cd(repoRoot);
run('startup.m');

roots = localAuditRoots();
maxFolders = localOptionalPositiveInteger("BB_DATA_AUDIT_MAX_FOLDERS");

report = table();
for rootIdx = 1:numel(roots)
    root = string(roots(rootIdx));
    if ~isfolder(root)
        error("testBehaviorBoxDataAllRootLoads:MissingRoot", "Data root does not exist: %s", root);
    end
    rootReport = localAuditRoot(root, maxFolders);
    report = [report; rootReport]; %#ok<AGROW>
end

failed = report(report.Status == "failed", :);
fprintf("BehaviorBoxData root audit summary:\n");
fprintf("  Roots: %d\n", numel(roots));
fprintf("  Checked folders: %d\n", height(report));
fprintf("  Constructor loads: %d\n", sum(report.Mode == "constructor"));
fprintf("  Direct folder loads: %d\n", sum(report.Mode == "direct"));
fprintf("  Skipped derivative folders: %d\n", sum(report.Status == "skipped"));
fprintf("  Failed folders: %d\n", height(failed));

if ~isempty(failed)
    disp(failed(:, {'RootName', 'RelativeFolder', 'FileCount', 'Mode', 'Message'}));
end

assert(isempty(failed), "One or more BehaviorBoxData data folders failed to load.");
fprintf("BEHAVIORBOX_DATA_ALL_ROOT_LOADS_OK\n");

function roots = localAuditRoots()
envValue = strtrim(string(getenv("BB_DATA_AUDIT_ROOTS")));
if strlength(envValue) > 0
    parts = split(envValue, pathsep);
    roots = parts(strlength(strtrim(parts)) > 0);
else
    roots = [string(GetFilePath("Data")); string(GetFilePath("Archive"))];
end
end

function maxFolders = localOptionalPositiveInteger(envName)
rawValue = strtrim(string(getenv(envName)));
maxFolders = Inf;
if strlength(rawValue) == 0
    return
end
parsed = str2double(rawValue);
if isfinite(parsed) && parsed > 0
    maxFolders = floor(parsed);
end
end

function report = localAuditRoot(root, maxFolders)
matFiles = dir(fullfile(root, '**', '*.mat'));
folders = unique(string({matFiles.folder})', 'stable');
if isfinite(maxFolders)
    folders = folders(1:min(numel(folders), maxFolders));
end

rows = cell(numel(folders), 10);
for i = 1:numel(folders)
    folder = folders(i);
    [relativeFolder, parts] = localRelativeParts(root, folder);
    folderFiles = dir(fullfile(folder, '*.mat'));
    if localShouldSkipFolder(parts)
        rows(i,:) = localReportRow(root, relativeFolder, folderFiles, "skipped", "skip", "", 0, 0, "known derivative folder");
        continue
    end

    [mode, cfg] = localFolderConfig(parts);
    try
        switch mode
            case "constructor"
                [loadedRows, dayCount] = localConstructorLoad(root, cfg);
            otherwise
                [loadedRows, dayCount] = localDirectFolderLoad(folder);
        end
        rows(i,:) = localReportRow(root, relativeFolder, folderFiles, "ok", mode, cfg.Sub, loadedRows, dayCount, "");
    catch err
        rows(i,:) = localReportRow(root, relativeFolder, folderFiles, "failed", mode, cfg.Sub, 0, 0, err.message);
    end
end

report = cell2table(rows, 'VariableNames', ...
    {'Root', 'RootName', 'RelativeFolder', 'FileCount', 'Status', 'Mode', 'Subject', 'LoadedRows', 'DayCount', 'Message'});
report.Root = string(report.Root);
report.RootName = string(report.RootName);
report.RelativeFolder = string(report.RelativeFolder);
report.Status = string(report.Status);
report.Mode = string(report.Mode);
report.Subject = string(report.Subject);
report.Message = string(report.Message);
if iscell(report.FileCount)
    report.FileCount = cell2mat(report.FileCount);
end
if iscell(report.LoadedRows)
    report.LoadedRows = cell2mat(report.LoadedRows);
end
if iscell(report.DayCount)
    report.DayCount = cell2mat(report.DayCount);
end
end

function [relativeFolder, parts] = localRelativeParts(root, folder)
relativeFolder = erase(folder, root);
relativeFolder = regexprep(relativeFolder, ['^' regexptranslate('escape', filesep)], '');
if strlength(relativeFolder) == 0
    parts = strings(0, 1);
else
    parts = split(relativeFolder, filesep);
end
end

function tf = localShouldSkipFolder(parts)
skipExact = [
    "Settings"
    "Genotyping Results"
    "Graphs"
    "LevelGroup"
    "DayTrial"
    "Male DayTrial"
    "Female DayTrial"
    "TrialsTo"
    "AllTime"
    "AllLevelsByDay"
    "Rescued Graph Data"];
tf = any(ismember(parts, skipExact)) || any(contains(parts, "Binomial", "IgnoreCase", true));
end

function [mode, cfg] = localFolderConfig(parts)
cfg = struct('Inv', "", 'Inp', "", 'Str', "", 'Sub', "");
if numel(parts) >= 4
    mode = "constructor";
    cfg.Inv = parts(1);
    cfg.Inp = parts(2);
    cfg.Str = parts(3);
    cfg.Sub = parts(4);
elseif numel(parts) == 3
    mode = "constructor";
    cfg.Inv = parts(1);
    cfg.Inp = parts(2);
    cfg.Sub = parts(3);
else
    mode = "direct";
    if ~isempty(parts)
        cfg.Sub = parts(end);
    end
end
end

function [loadedRows, dayCount] = localConstructorLoad(root, cfg)
warnState = warning('off', 'all');
cleanupWarnings = onCleanup(@() warning(warnState));
args = { ...
    'DataRoot', root, ...
    'Inv', char(cfg.Inv), ...
    'Inp', char(cfg.Inp), ...
    'Sub', {char(cfg.Sub)}, ...
    'find', 1, ...
    'analyze', 0};
if strlength(cfg.Str) > 0
    args = [args, {'Str', char(cfg.Str)}];
end
bbData = BehaviorBoxData(args{:});
clear cleanupWarnings
loadedRows = size(bbData.loadedData, 1);
dayCount = localDayCount(bbData);
assert(loadedRows > 0, "BehaviorBoxData returned no loadedData rows.");
end

function [loadedRows, dayCount] = localDirectFolderLoad(folder)
warnState = warning('off', 'all');
cleanupWarnings = onCleanup(@() warning(warnState));
files = dir(fullfile(folder, '*.mat'));
rows = cell(numel(files), 8);
for i = 1:numel(files)
    rows(i,:) = readFcn(fullfile(files(i).folder, files(i).name));
end

bbData = BehaviorBoxData( ...
    'Inv', 'audit', ...
    'Inp', 'w', ...
    'Str', 'w', ...
    'Sub', {'w'}, ...
    'find', 1, ...
    'load', 0, ...
    'analyze', 0);
bbData.loadedData = rows;
[~, subjectName] = fileparts(folder);
bbData.Sub = {subjectName};
if any(cellfun(@isstruct, rows(:,3)))
    bbData.CombineDays();
end
clear cleanupWarnings
loadedRows = size(rows, 1);
dayCount = localDayCount(bbData);
end

function dayCount = localDayCount(bbData)
dayCount = 0;
if isempty(bbData.DayData) || ~isstruct(bbData.DayData)
    return
end
names = fieldnames(bbData.DayData);
for i = 1:numel(names)
    dayCount = dayCount + size(bbData.DayData.(names{i}), 1);
end
end

function row = localReportRow(root, relativeFolder, folderFiles, status, mode, subject, loadedRows, dayCount, message)
[~, rootName] = fileparts(root);
row = {char(root), char(rootName), char(relativeFolder), numel(folderFiles), char(status), char(mode), ...
    char(subject), loadedRows, dayCount, char(message)};
end
