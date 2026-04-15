scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(fullfile(repoRoot, 'MockApp'));
cd(repoRoot);
run('startup.m');

testResetThenSustainedHoldRewards();
testWrongSideDoesNotRewardBeforeFastForward();
testFastForwardDuringPulseGapStopsNextReward();

disp("BEHAVIORBOX_NOSE_REWARD_HOLD_OK");

function testResetThenSustainedHoldRewards()
    [nose, arduino, fig] = makeRewardWorkflow();
    cleanup = onCleanup(@() closeIfValid(fig));

    arduino.setTokenScript('--LL-MLLLLLLLLLLL');

    nose.GiveRewardAndFlash();

    assert(numel(arduino.RewardCalls) == 2, "Expected both left reward pulses after a renewed sustained hold.");
    assert(all(arduino.RewardCalls == "L"), "Expected left reward commands for a left-correct trial.");
    assert(nose.RewardPulses == 2, "RewardPulses should count delivered reward pulses.");
    assert(arduino.RewardReadCounts(2) >= 9, ...
        "Second reward was delivered before the interrupted hold could reset and complete.");
end

function testWrongSideDoesNotRewardBeforeFastForward()
    [nose, arduino, fig] = makeRewardWorkflow();
    cleanup = onCleanup(@() closeIfValid(fig));

    arduino.setTokenScript('LLRRRRRRRRRRRRRRRRRR');
    arduino.FastForwardAtRead = 8;
    arduino.FastForwardControl = nose.app.FastForward;

    nose.GiveRewardAndFlash();

    assert(isscalar(arduino.RewardCalls), "Wrong-side hold should not qualify for a later reward pulse.");
    assert(nose.RewardPulses == 1, "Only the first pulse should be counted before fast-forward exits.");

    contour = findobj(nose.fig.Children, 'Tag', 'Contour');
    distractor = findobj(nose.fig.Children, 'Tag', 'Distractor');
    assert(isequal(round(contour.Color, 6), round(nose.StimulusStruct.LineColor, 6)), ...
        "Contour color should be restored after reward wait exits.");
    assert(isequal(round(distractor.Color, 6), round(nose.StimulusStruct.DimColor, 6)), ...
        "Distractor should remain dim after reward wait exits.");
end

function testFastForwardDuringPulseGapStopsNextReward()
    [nose, arduino, fig] = makeRewardWorkflow();
    cleanup = onCleanup(@() closeIfValid(fig));

    nose.Box.SecBwPulse = 0.2;
    arduino.setTokenScript('LLLLLLLLLLLLLLLLLLLL');
    arduino.FastForwardAfterRewards = 1;
    arduino.FastForwardControl = nose.app.FastForward;

    nose.GiveRewardAndFlash();

    assert(isscalar(arduino.RewardCalls), "Fast-forward during SecBwPulse should stop the next reward.");
    assert(nose.RewardPulses == 1, "RewardPulses should not count skipped pulses after fast-forward.");
end

function [nose, arduino, fig] = makeRewardWorkflow()
    app = MockApp();
    app.Box_Input_type.Value = 'NosePoke';
    gui = struct('MsgBox', app.MsgBox, 'NotesText', app.NotesText);
    nose = BehaviorBoxNose(gui, app);

    fig = figure('Visible', 'off', 'Name', 'RewardHoldTest');
    ax = axes('Parent', fig);
    line(ax, [0 1], [0 1], 'Tag', 'Contour', 'Color', [1 1 1]);
    line(ax, [0 1], [1 0], 'Tag', 'Distractor', 'Color', [1 1 1]);

    arduino = MockArduino();
    nose.a = arduino;
    nose.fig = fig;
    nose.stop_handle = app.Stop;
    nose.Skip = app.Skip;
    nose.FF = app.FastForward;
    nose.Pause = app.Pause;
    nose.message_handle = app.text1;
    nose.WhatDecision = 'left correct';
    nose.RewardPulses = 0;
    nose.Setting_Struct = struct('Input_Delay_Respond', 0.04);
    nose.Box = struct( ...
        'Input_type', 3, ...
        'LeftPulse', 2, ...
        'RightPulse', 2, ...
        'OCPulse', 2, ...
        'Air_Puff_Penalty', false, ...
        'AirPuffPulses', 0, ...
        'SecBwPulse', 0);
    nose.StimulusStruct = struct( ...
        'LineColor', [1 1 1], ...
        'DimColor', [0.2 0.2 0.2], ...
        'FlashColor', [0 1 0], ...
        'BackgroundColor', [0 0 0], ...
        'FreqAnimation', 1, ...
        'FlashStim', true, ...
        'RepFlashAfterC', 0, ...
        'RepFlashAfterW', 0);
end

function closeIfValid(fig)
    if ~isempty(fig) && isvalid(fig)
        close(fig);
    end
end
