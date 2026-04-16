scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
cd(repoRoot);
run('startup.m');

baseColor = [0.2 0.3 0.4];
flashColor = [0.8 0.9 1.0];
dimColor = [0.05 0.06 0.07];
turnMag = 100;
stimDistance = 0.3;
threshold = 0.25;
k = stimDistance / turnMag;
halfDist = (threshold / 2) / k;
halfColor = baseColor + 0.5 .* (flashColor - baseColor);

wheel = makeWheel_(baseColor, flashColor, dimColor, turnMag, true, true);
wheel.Box.Timeout_after_time = 0.05;
wheel.a.setWheelScript(halfDist);
wheel.readLeverLoopAnalogWheel(0);
assertHasStimColor_(wheel.WheelDisplayRecord, halfColor(1), ...
    'Left correct movement should record the midpoint gradient color.');
close(wheel.fig);

wheel = makeWheel_(baseColor, flashColor, dimColor, turnMag, false, true);
wheel.Box.Timeout_after_time = 0.05;
wheel.a.setWheelScript(-halfDist);
wheel.readLeverLoopAnalogWheel(0);
assertHasStimColor_(wheel.WheelDisplayRecord, halfColor(1), ...
    'Right correct movement should record the midpoint gradient color.');
close(wheel.fig);

wheel = makeWheel_(baseColor, flashColor, dimColor, turnMag, true, true);
wheel.Box.Timeout_after_time = 0.05;
wheel.a.setWheelScript(-halfDist);
wheel.readLeverLoopAnalogWheel(0);
assertNoBrightRows_(wheel.WheelDisplayRecord, baseColor(1), ...
    'Wrong-direction movement should not brighten the contour.');
close(wheel.fig);

wheel = makeWheel_(baseColor, flashColor, dimColor, turnMag, true, false);
wheel.Box.Timeout_after_time = 0.05;
wheel.a.setWheelScript(halfDist);
wheel.readLeverLoopAnalogWheel(0);
assertNoBrightRows_(wheel.WheelDisplayRecord, baseColor(1), ...
    'ConfirmChoice=false should keep recorded stimulus color at baseline.');
close(wheel.fig);

disp("BEHAVIORBOX_WHEEL_CONFIRM_CHOICE_GRADIENT_OK");

function wheel = makeWheel_(baseColor, flashColor, dimColor, turnMag, isLeftTrial, confirmChoice)
app = MockApp();
gui = struct('MsgBox', app.MsgBox, 'NotesText', app.NotesText);
wheel = BehaviorBoxWheel(gui, app);
wheel.Box.Input_type = 6;
wheel.Box.KeyboardInput = false;
wheel.Box.Timeout_after_time = 1;
wheel.Box.GraphicsUpdateHz = 240;
wheel.a = MockArduino();
wheel.Time = MockTime();
wheel.TrainStartTime = tic;
wheel.hold_still_start = tic;
wheel.i = 1;
wheel.Level = 5;
wheel.CurrentWheelPhase = "response";
wheel.isLeftTrial = isLeftTrial;
wheel.Setting_Struct = struct( ...
    'TurnMag', turnMag, ...
    'RoundUp', false, ...
    'ConfirmChoice', confirmChoice);
wheel.StimulusStruct = struct( ...
    'LineColor', baseColor, ...
    'FlashColor', flashColor, ...
    'DimColor', dimColor, ...
    'FlashStim', false);

fig = figure('Visible', 'off', 'Name', 'WheelConfirmChoiceGradientTest');
wheel.fig = fig;
wheel.LStimAx = axes('Parent', fig, 'Position', [0.00 0.10 0.45 0.80]);
wheel.RStimAx = axes('Parent', fig, 'Position', [0.50 0.10 0.45 0.80]);
wheel.FLAx = gobjects(0);
if isLeftTrial
    line(wheel.LStimAx, [0 1], [0 1], 'Tag', 'Contour', 'Color', baseColor);
    line(wheel.RStimAx, [0 1], [1 0], 'Tag', 'Distractor', 'Color', baseColor);
else
    line(wheel.RStimAx, [0 1], [0 1], 'Tag', 'Contour', 'Color', baseColor);
    line(wheel.LStimAx, [0 1], [1 0], 'Tag', 'Distractor', 'Color', baseColor);
end
end

function assertHasStimColor_(wheelDisplayRecord, expectedColor, message)
colors = double(wheelDisplayRecord.StimColor);
assert(any(abs(colors - expectedColor) < 1e-10), string(message));
end

function assertNoBrightRows_(wheelDisplayRecord, baseColor, message)
colors = double(wheelDisplayRecord.StimColor);
assert(all(colors <= baseColor + 1e-10), string(message));
end
