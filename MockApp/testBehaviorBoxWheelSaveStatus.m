scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
cd(repoRoot);
run('startup.m');

validationDir = fullfile(tempdir, 'behaviorbox_wheel_save_validation');
if ~isfolder(validationDir)
    mkdir(validationDir);
end

app = MockApp();
gui = struct('MsgBox', app.MsgBox, 'NotesText', app.NotesText);
wheel = BehaviorBoxWheel(gui, app);
wheel.Box.Input_type = 6;
wheel.a = MockArduino();
wheel.Time = MockTime();
wheel.Setting_Struct.Subject = "999999";
wheel.Setting_Struct.Strain = "New";
wheel.Setting_Struct.One_ScanImage_File = true;
wheel.Setting_Struct.Weight = NaN;
wheel.TimeScanImageFileIndex = 2;

trialParsed = table( ...
    repmat("annotation", 2, 1), ...
    ["trial_start"; "trial_end"], ...
    [100; 200], ...
    [1; 1], ...
    [1; 1], ...
    'VariableNames', {'kind', 'event', 't_us', 'trial', 'scanImageFile'});
wheel.timestamps_record = {struct( ...
    'trial', 1, ...
    'kind', "trial", ...
    'scanImageFile', 1, ...
    'raw', ["trial_start"; "trial_end"], ...
    'parsed', trialParsed)};

wheel.Time.RawLog = ["trial_start"; "choice_left"];
wheel.Time.Log = wheel.Time.RawLog;
wheel.Time.ParsedLog = table( ...
    repmat("annotation", 2, 1), ...
    ["trial_start"; "choice_left"], ...
    [300; 400], ...
    [2; 2], ...
    [2; 2], ...
    'VariableNames', {'kind', 'event', 't_us', 'trial', 'scanImageFile'});
wheel.TimeSegmentKind = "trial";
wheel.TimeSegmentTrial = 2;

wheel.WheelDisplayRecord = table( ...
    [1; 2], ...
    ["reward"; "reward"], ...
    [0.5; 0.6], ...
    [1; 2], ...
    [0.1; 0.2], ...
    [0.8; 0.9], ...
    ["reward_on"; "reward_on"], ...
    [5; 5], ...
    [true; true], ...
    'VariableNames', {'trial', 'phase', 'tTrial', 'rawWheel', 'delta', 'StimColor', 'screenEvent', 'level', 'isLeftTrial'});
wheel.FrameAlignedRecord = table();

wheel.cleanUP();

assert(numel(wheel.timestamps_record) == 3, 'Expected committed trial, active trial, and cleanup segments.');
assert(strcmp(string(wheel.timestamps_record{2}.kind), "trial"), 'Active trial segment was not preserved.');
assert(wheel.timestamps_record{2}.trial == 2, 'Preserved active segment has wrong trial number.');
assert(strcmp(string(wheel.timestamps_record{3}.kind), "cleanup"), 'Cleanup segment missing after cleanUP.');
assert(isnan(wheel.timestamps_record{3}.trial), 'Cleanup segment should be session-level (NaN trial).');

newData = BehaviorBoxData.new_init_data_struct();
newData.TrialNum = 1;
newData.SmallBin = 1;
newData.BigBin = 1;
newData.TimeStamp = 1.5;
newData.Score = 1;
newData.Level = 5;
newData.isLeftTrial = true;
newData.CodedChoice = 1;
newData.SetIdx = 1;
newData.RewardPulses = 1;
newData.InterTMal = 0;
newData.DuringTMal = 0;
newData.TrialStartTime = 0.1;
newData.ResponseTime = 0.2;
newData.DrinkTime = 0.3;
newData.isTraining = 0;
newData.SideBias = 0;
newData.BetweenTrialTime = 0.4;
newData.SetStr = "";
newData.SetUpdate = 0;
newData.Settings = struct();
newData.RewardTime = 0.3;
newData.WhatDecision = "left correct OC";
newData.LevelGroups = 5;
newData.StimHist = cell(0, 2);
newData.wheel_record = cell(0, 3);
newData.Include = 1;

wheel.Data_Object = struct( ...
    'current_data_struct', newData, ...
    'start_time', datetime(2026, 3, 27, 12, 0, 0), ...
    'Str', "New", ...
    'filedir', validationDir);

wheel.SaveAllData();

saveFile = fullfile(validationDir, '260327_120000_999999_New_Contour_Wheel.mat');
loaded = load(saveFile, 'newData');

wheelVars = string(loaded.newData.WheelDisplayRecord.Properties.VariableNames);
assert(all(ismember(["trialCommitted", "trialStatus"], wheelVars)), 'WheelDisplayRecord status columns missing.');
assert(loaded.newData.WheelDisplayRecord.trialCommitted(1), 'Committed wheel trial should be marked committed.');
assert(loaded.newData.WheelDisplayRecord.trialStatus(2) == "in_progress", 'Uncommitted wheel trial should be marked in_progress.');

assert(loaded.newData.TimestampRecord{1}.trialStatus == "committed", 'Committed timestamp segment status is wrong.');
assert(~loaded.newData.TimestampRecord{2}.trialCommitted, 'Uncommitted timestamp segment should not be marked committed.');
assert(loaded.newData.TimestampRecord{2}.trialStatus == "in_progress", 'Active timestamp segment status is wrong.');
assert(loaded.newData.TimestampRecord{3}.trialStatus == "session", 'Cleanup timestamp segment should be session-level.');
assert(all(loaded.newData.TimestampRecord{2}.parsed.trialStatus == "in_progress"), 'Parsed active timestamp rows are missing status annotations.');

app2 = MockApp();
gui2 = struct('MsgBox', app2.MsgBox, 'NotesText', app2.NotesText);
wheel2 = BehaviorBoxWheel(gui2, app2);
wheel2.Box.Input_type = 6;
wheel2.a = MockArduino();
wheel2.Time = MockTime();
wheel2.Setting_Struct.One_ScanImage_File = false;
wheel2.Setting_Struct.Weight = NaN;
wheel2.TimeScanImageFileIndex = 4;
wheel2.Time.RawLog = "trial_start";
wheel2.Time.Log = wheel2.Time.RawLog;
wheel2.Time.ParsedLog = table( ...
    "annotation", ...
    "trial_start", ...
    500, ...
    4, ...
    4, ...
    'VariableNames', {'kind', 'event', 't_us', 'trial', 'scanImageFile'});
wheel2.TimeSegmentKind = "trial";
wheel2.TimeSegmentTrial = 4;

wheel2.cleanUP();

assert(isscalar(wheel2.timestamps_record), 'Per-trial cleanup should preserve the active segment.');
assert(wheel2.timestamps_record{1}.trial == 4, 'Per-trial cleanup stored the wrong trial number.');
assert(any(string(wheel2.timestamps_record{1}.parsed.event) == "acq_end"), 'Per-trial cleanup should append acq_end before storing.');

disp("BEHAVIORBOX_WHEEL_SAVE_STATUS_OK");
