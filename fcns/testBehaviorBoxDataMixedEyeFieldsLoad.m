scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
cd(repoRoot);
run('startup.m');

tempRoot = tempname;
subjectDir = fullfile(tempRoot, '3421911');
mkdir(subjectDir);
cleanupData = onCleanup(@() localSafeRmdir(tempRoot));

Settings = localSettings();
Notes = "";

newData = localBaseNewData(2, Settings, 0);
newData.TtimestampRecord = {struct('trial', 1, 'kind', 'legacy')};
save(fullfile(subjectDir, '260423_100000_3421911_New_ContourDensity_Wheel.mat'), ...
    'Settings', 'newData', 'Notes');

newData = localBaseNewData(2, Settings, 1);
newData.TimestampRecord = {struct('trial', 1, 'kind', 'timestamp')};
newData.WheelDisplayRecord = table((1:3)', (1:3)', ...
    'VariableNames', {'trial', 'frame'});
newData.FrameAlignedRecord = table((1:3)', seconds(1:3)', ...
    'VariableNames', {'frame', 't'});
save(fullfile(subjectDir, '260423_101000_3421911_New_ContourDensity_Wheel.mat'), ...
    'Settings', 'newData', 'Notes');

newData = localBaseNewData(1, Settings, 2);
newData.TimestampRecord = {struct('trial', 1, 'kind', 'timestamp')};
newData.EyeTrackingRecord = table((1:4)', (11:14)', ...
    'VariableNames', {'frame', 'pupil_x'});
newData.EyeTrackingMeta = struct('IsReady', true);
newData.EyeTrackRecord = {newData.EyeTrackingRecord};
newData.EyeTrackSegmentMeta = {struct('Trial', 1)};
newData.WheelDisplayRecord = table((1:2)', (1:2)', ...
    'VariableNames', {'trial', 'frame'});
newData.FrameAlignedRecord = table((1:2)', seconds(1:2)', ...
    'VariableNames', {'frame', 't'});
newData.EyeAlignedRecord = table((1:4)', (21:24)', ...
    'VariableNames', {'frame', 'aligned_x'});
save(fullfile(subjectDir, '260423_102000_3421911_New_ContourDensity_Wheel.mat'), ...
    'Settings', 'newData', 'Notes');

Position_Record = [];
TimeLog = strings(0, 1);
MapLog = table();
MapMeta = struct();
TimestampRecord = {};
EyeTrackingRecord = table();
EyeTrackingMeta = struct('IsReady', false);
save(fullfile(subjectDir, '260423_103000_3421911_New_Animate_Wheel.mat'), ...
    'Settings', 'Position_Record', 'Notes', 'TimeLog', 'MapLog', 'MapMeta', ...
    'TimestampRecord', 'EyeTrackingRecord', 'EyeTrackingMeta');

files = dir(fullfile(subjectDir, '*.mat'));
rows = cell(numel(files), 8);
for i = 1:numel(files)
    rows(i,:) = readFcn(fullfile(files(i).folder, files(i).name));
end

hasTrainingStruct = cellfun(@isstruct, rows(:,3));
assert(sum(hasTrainingStruct) == 3, 'Expected three training files with newData.');
assert(sum(~hasTrainingStruct) == 1, 'Expected one animate-only file without newData.');

trainingRows = find(hasTrainingStruct);
firstExtras = rows{trainingRows(1), 5};
assert(isfield(firstExtras, 'NewDataSessionFields'), ...
    'readFcn should preserve moved session fields in extras.');
assert(isfield(firstExtras.NewDataSessionFields, 'TtimestampRecord'), ...
    'Legacy timestamp fields should remain available in read extras.');

lastData = rows{trainingRows(end), 3};
lastExtras = rows{trainingRows(end), 5};
assert(~isfield(lastData, 'EyeTrackingRecord'), ...
    'EyeTrackingRecord should not remain in day-concatenated behavior data.');
assert(isfield(lastExtras.NewDataSessionFields, 'EyeTrackingRecord'), ...
    'EyeTrackingRecord should remain available in read extras.');

bb = BehaviorBoxData( ...
    'Inv', 'Will', ...
    'Inp', 'w', ...
    'Str', 'w', ...
    'Sub', {'w'}, ...
    'find', 1, ...
    'load', 0, ...
    'analyze', 0);
bb.loadedData = rows;
bb.Sub = {'3421911'};
bb.CombineDays();

out = bb.DayData.Mouse3421911{1,3};
assert(numel(out.Score) == 5, 'Combined behavior data should include all training trials.');
assert(~isfield(out, 'EyeTrackingRecord'), ...
    'Combined behavior data should not include session-wide eye tables.');
assert(~isfield(out, 'TimestampRecord'), ...
    'Combined behavior data should not include session-wide timestamp cells.');

fprintf('BEHAVIORBOX_DATA_MIXED_EYE_FIELDS_LOAD_OK\n');

function Settings = localSettings()
Settings = struct( ...
    'Stimulus_side', 1, ...
    'Stimulus_type', 12, ...
    'Starting_opacity', 0.5, ...
    'Level_EasyLvProb', 1, ...
    'Level_HardLvProb', 0);
end

function newData = localBaseNewData(nTrials, Settings, scoreOffset)
trial = (1:nTrials)';
score = mod(trial + scoreOffset, 2);
newData = struct();
newData.TrialNum = trial;
newData.SmallBin = ones(nTrials, 1);
newData.BigBin = ones(nTrials, 1);
newData.TimeStamp = trial / 10;
newData.Score = score;
newData.Level = ones(nTrials, 1);
newData.isLeftTrial = mod(trial, 2) == 1;
newData.CodedChoice = score + 1;
newData.SetIdx = ones(nTrials, 1);
newData.RewardPulses = score;
newData.InterTMal = zeros(nTrials, 1);
newData.DuringTMal = zeros(nTrials, 1);
newData.TrialStartTime = trial;
newData.ResponseTime = trial + 0.25;
newData.DrinkTime = trial + 0.5;
newData.isTraining = true(nTrials, 1);
newData.SideBias = zeros(nTrials, 1);
newData.BetweenTrialTime = ones(nTrials, 1);
newData.SetStr = "fixture";
newData.SetUpdate = {1};
newData.Settings = Settings;
newData.RewardTime = [];
newData.WhatDecision = [];
newData.LevelGroups = 1;
newData.StimHist = cell(nTrials, 2);
newData.wheel_record = cell(nTrials, 3);
newData.Include = ones(nTrials, 1);
newData.Weight = 25;
end

function localSafeRmdir(targetDir)
if isfolder(targetDir)
    try
        rmdir(targetDir, 's');
    catch
    end
end
end
