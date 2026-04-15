% testTemporarySettings
% Focused smoke tests for BehaviorBox temporary settings expiry rules.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
addpath(fullfile(repoRoot, 'fcns'));

testNoseCorrectCountStartsAtActivation();
testNosePerformanceUsesPerfThreshold();
testWheelCorrectCountIgnoresIncorrectAndTimeouts();
testWheelPerformanceUsesPerfThreshold();

fprintf('testTemporarySettings passed.\n');

function testNoseCorrectCountStartsAtActivation()
    bb = newNose();
    bb.app = makeTempApp();
    bb.Setting_Struct = struct('Starting_opacity', 5);
    bb.Temp_Settings = struct( ...
        'TrialNumber', true, ...
        'PerformanceThreshold', false, ...
        'TempOff', false, ...
        'TrialCount', 2, ...
        'TrialCountThreshold', 0, ...
        'Starting_opacity', 1);
    bb.Data_Object = makeData([1 1 0], [1 1 1]);

    bb.CheckTemp();
    assert(bb.Temp_Active, 'Nose temp mode should activate.');
    assert(bb.Temp_CorrectStart == 2, 'Existing correct responses should be stored as the baseline.');
    assert(bb.Temp_Countdown == 2, 'Existing correct responses must not reduce the temp countdown.');
    assert(bb.Setting_Struct.Starting_opacity == 1, 'Nose temp settings should be overlaid while active.');

    advanceCompletedTrials(bb, [1 1 0 1], [1 1 1 1]);
    bb.CheckTemp();
    assert(bb.Temp_Active, 'Nose temp mode should remain active after one new correct response.');
    assert(bb.Temp_Countdown == 1, 'Nose countdown should track new correct responses only.');

    advanceCompletedTrials(bb, [1 1 0 1 1], [1 1 1 1 1]);
    bb.CheckTemp();
    assert(~bb.Temp_Active, 'Nose temp mode should expire after two new correct responses.');
    assert(bb.Setting_Struct.Starting_opacity == 5, 'Nose base settings should be restored after temp expiry.');
    assert(bb.app.TempOff_Temp.Value == 1, 'Nose temp expiry should switch the GUI mode back to Off.');
end

function testNosePerformanceUsesPerfThreshold()
    bb = newNose();
    bb.app = makeTempApp();
    bb.Setting_Struct = struct('Starting_opacity', 5);
    bb.Temp_Settings = struct( ...
        'TrialNumber', false, ...
        'PerformanceThreshold', true, ...
        'TempOff', false, ...
        'TrialCount', 999, ...
        'TrialCountThreshold', 100, ...
        'PerfThresh', 75, ...
        'Starting_opacity', 1);
    bb.Data_Object = makeData([1 0], [1 1]);

    bb.CheckTemp();
    assert(bb.Temp_Active, 'Nose performance mode should remain active below PerfThresh.');

    advanceCompletedTrials(bb, [1 0 1 1], [1 1 1 1]);
    bb.CheckTemp();
    assert(~bb.Temp_Active, 'Nose performance mode should expire using PerfThresh_Temp.');
end

function testWheelCorrectCountIgnoresIncorrectAndTimeouts()
    bb = newWheel();
    bb.app = makeTempApp();
    bb.Setting_Struct = struct('Starting_opacity', 5);
    bb.Temp_Settings = struct( ...
        'TrialNumber', true, ...
        'PerformanceThreshold', false, ...
        'TempOff', false, ...
        'TrialCount', 2, ...
        'TrialCountThreshold', 0, ...
        'Starting_opacity', 1);
    bb.Data_Object = makeData(1, 1);

    bb.CheckTemp();
    assert(bb.Temp_Active, 'Wheel temp mode should activate.');
    assert(bb.Temp_Countdown == 2, 'Wheel countdown should not decrement before a completed trial.');

    advanceCompletedTrials(bb, [1 0 2], [1 1 1]);
    bb.CheckTemp();
    assert(bb.Temp_Active, 'Wheel temp mode should ignore incorrect responses and timeouts for Correct Resp.');
    assert(bb.Temp_Countdown == 2, 'Wheel countdown should only count new correct responses.');

    advanceCompletedTrials(bb, [1 0 2 1], [1 1 1 1]);
    bb.CheckTemp();
    assert(bb.Temp_Active, 'Wheel temp mode should remain active after one new correct response.');
    assert(bb.Temp_Countdown == 1, 'Wheel countdown should decrease after one new correct response.');

    advanceCompletedTrials(bb, [1 0 2 1 1], [1 1 1 1 1]);
    bb.CheckTemp();
    assert(~bb.Temp_Active, 'Wheel temp mode should expire after two new correct responses.');
    assert(bb.Setting_Struct.Starting_opacity == 5, 'Wheel base settings should be restored after temp expiry.');
    assert(bb.app.TempOff_Temp.Value == 1, 'Wheel temp expiry should switch the GUI mode back to Off.');
end

function testWheelPerformanceUsesPerfThreshold()
    bb = newWheel();
    bb.app = makeTempApp();
    bb.Setting_Struct = struct('Starting_opacity', 5);
    bb.Temp_Settings = struct( ...
        'TrialNumber', false, ...
        'PerformanceThreshold', true, ...
        'TempOff', false, ...
        'TrialCount', 999, ...
        'TrialCountThreshold', 100, ...
        'PerfThresh', 80, ...
        'Starting_opacity', 1);
    bb.Data_Object = makeData([1 0 1 0], [1 1 1 1]);

    bb.CheckTemp();
    assert(bb.Temp_Active, 'Wheel performance mode should remain active below PerfThresh.');

    advanceCompletedTrials(bb, [1 0 1 1 1], [1 1 1 1 1]);
    bb.CheckTemp();
    assert(~bb.Temp_Active, 'Wheel performance mode should expire using PerfThresh_Temp.');
end

function app = makeTempApp()
    app = struct();
    app.TrialsRemainingLabel = struct('Text', "_ Trials Remaining");
    app.TempOff_Temp = struct('Value', 0);
end

function bb = newNose()
    [~, bb] = evalc('BehaviorBoxNose(struct(), makeTempApp())');
end

function bb = newWheel()
    [~, bb] = evalc('BehaviorBoxWheel(struct(), makeTempApp())');
end

function dataObject = makeData(scores, levels)
    dataObject = struct();
    dataObject.current_data_struct = struct( ...
        'Score', scores, ...
        'Level', levels);
end

function advanceCompletedTrials(bb, scores, levels)
    if bb.Temp_Active
        bb.Setting_Struct = bb.Temp_Old_Settings;
    end
    bb.Data_Object = makeData(scores, levels);
end
