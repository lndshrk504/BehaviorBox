scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
addpath(fullfile(repoRoot, 'fcns'));
cd(repoRoot);

tempRoot = tempname;
cleanupData = onCleanup(@() localSafeRmdir(tempRoot));

noseFile = localSaveNoseFixture(tempRoot);
wheelFile = localSaveWheelFixture(tempRoot);
localAssertSavedSchema(noseFile);
localAssertSavedSchema(wheelFile);
localAssertBehaviorBoxDataLoad(tempRoot, "Will", "NosePoke", "999994");
localAssertBehaviorBoxDataLoad(tempRoot, "Will", "Wheel", "999993");

fprintf("BEHAVIORBOX_SAVE_SCHEMA_SETTINGS_OWNER_OK\n");

function saveFile = localSaveNoseFixture(tempRoot)
saveDir = fullfile(tempRoot, 'Will', 'NosePoke', 'New', '999994');
mkdir(saveDir);

app = MockApp();
app.Box_Input_type.Value = "NosePoke";
app.Box_Input_type.String = "NosePoke";
app.Subject.Value = "999994";
app.Strain.Value = "New";
gui = struct('MsgBox', app.MsgBox, 'NotesText', app.NotesText);
nose = BehaviorBoxNose(gui, app);
nose.message_handle = app.text1;
nose.Setting_Struct = localSettings("999994");
nose.SetUpdate = {0};
nose.SetIdx = 1;
nose.SetStr = "fixture";
nose.Include = 1;
nose.StimHistory = cell(4, 2);
nose.Data_Object = struct( ...
    'current_data_struct', localBaseNewData(), ...
    'start_time', datetime(2026, 3, 27, 12, 10, 0), ...
    'Str', "New", ...
    'Inp', "NosePoke", ...
    'Sub', {{'999994'}}, ...
    'filedir', saveDir);

nose.SaveAllData();
saveFile = fullfile(saveDir, '260327_121000_999994_New_Contour_NosePoke.mat');
assert(isfile(saveFile), 'Nose save fixture did not create the expected .mat file.');
end

function saveFile = localSaveWheelFixture(tempRoot)
saveDir = fullfile(tempRoot, 'Will', 'Wheel', 'New', '999993');
mkdir(saveDir);

app = MockApp();
app.Subject.Value = "999993";
app.Strain.Value = "New";
gui = struct('MsgBox', app.MsgBox, 'NotesText', app.NotesText);
wheel = BehaviorBoxWheel(gui, app);
wheel.Box.Input_type = 0;
wheel.message_handle = app.text1;
wheel.Setting_Struct = localSettings("999993");
wheel.SetUpdate = {0};
wheel.SetIdx = 1;
wheel.SetStr = "fixture";
wheel.Include = 1;
wheel.StimHistory = cell(4, 2);
wheel.Data_Object = struct( ...
    'current_data_struct', localBaseNewData(), ...
    'start_time', datetime(2026, 3, 27, 12, 11, 0), ...
    'Str', "New", ...
    'Inp', "Wheel", ...
    'Sub', {{'999993'}}, ...
    'filedir', saveDir);

wheel.SaveAllData();
saveFile = fullfile(saveDir, '260327_121100_999993_New_Contour_Wheel.mat');
assert(isfile(saveFile), 'Wheel save fixture did not create the expected .mat file.');
end

function localAssertSavedSchema(saveFile)
loaded = load(saveFile);
assert(isfield(loaded, 'Settings'), 'Saved file is missing top-level Settings.');
assert(isfield(loaded, 'newData'), 'Saved file is missing newData.');
assert(~isfield(loaded.newData, 'Settings'), 'newData.Settings should not be saved in new files.');
assert(~isfield(loaded.newData, 'SetStr'), 'newData.SetStr should not be saved in new files.');
assert(isfield(loaded.newData, 'SetUpdate'), 'newData.SetUpdate should remain saved.');
assert(isfield(loaded.newData, 'SetIdx'), 'newData.SetIdx should remain saved.');

row = readFcn(saveFile);
assert(isfield(row{3}, 'Settings'), 'readFcn should inject in-memory newData.Settings for compatibility.');
assert(isfield(row{3}, 'SetStr'), 'readFcn should inject in-memory newData.SetStr for compatibility.');
assert(isfield(row{5}, 'CompatibilityFields'), 'readFcn should mark compatibility-injected fields in extras.');
end

function localAssertBehaviorBoxDataLoad(tempRoot, invName, inpName, subName)
bbData = BehaviorBoxData( ...
    'DataRoot', tempRoot, ...
    'Inv', char(invName), ...
    'Inp', char(inpName), ...
    'Str', 'New', ...
    'Sub', {char(subName)}, ...
    'find', 1, ...
    'analyze', 0);
assert(size(bbData.loadedData, 1) == 1, 'BehaviorBoxData should load the new-schema fixture.');
mouseField = matlab.lang.makeValidName("Mouse" + subName);
combined = bbData.DayData.(mouseField){1, 3};
assert(numel(combined.Score) == 2, 'Combined fixture should retain both trials.');
assert(isfield(combined, 'Settings'), 'Combined fixture should retain settings from top-level Settings.');
assert(isfield(combined, 'SetStr'), 'Combined fixture should reconstruct SetStr from Settings.');
end

function Settings = localSettings(subject)
Settings = struct( ...
    'Subject', char(subject), ...
    'Strain', 'New', ...
    'Weight', 25, ...
    'Stimulus_side', 1, ...
    'Stimulus_type', 12, ...
    'Starting_opacity', 0.5, ...
    'Level_EasyLvProb', 1, ...
    'Level_HardLvProb', 0);
end

function newData = localBaseNewData()
nTrials = 2;
trial = (1:nTrials)';
newData = BehaviorBoxData.new_init_data_struct();
newData.TrialNum = trial;
newData.SmallBin = ones(nTrials, 1);
newData.BigBin = ones(nTrials, 1);
newData.TimeStamp = trial / 10;
newData.Score = [1; 0];
newData.Level = ones(nTrials, 1);
newData.isLeftTrial = [true; false];
newData.CodedChoice = [1; 2];
newData.SetIdx = ones(nTrials, 1);
newData.RewardPulses = [1; 0];
newData.InterTMal = zeros(nTrials, 1);
newData.DuringTMal = zeros(nTrials, 1);
newData.TrialStartTime = trial;
newData.ResponseTime = trial + 0.25;
newData.DrinkTime = trial + 0.5;
newData.isTraining = true(nTrials, 1);
newData.SideBias = zeros(nTrials, 1);
newData.BetweenTrialTime = ones(nTrials, 1);
newData.SetStr = "preexisting duplicate";
newData.SetUpdate = {0};
newData.Settings = localSettings("preexisting");
newData.RewardTime = zeros(nTrials, 1);
newData.WhatDecision = ["left correct"; "right wrong"];
newData.LevelGroups = ones(nTrials, 1);
newData.StimHist = cell(nTrials, 2);
newData.wheel_record = cell(nTrials, 3);
newData.Include = ones(nTrials, 1);
end

function localSafeRmdir(targetDir)
if isfolder(targetDir)
    try
        rmdir(targetDir, 's');
    catch
    end
end
end
