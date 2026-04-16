scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
cd(repoRoot);
run('startup.m');

app = MockApp();
gui = struct('MsgBox', app.MsgBox, 'NotesText', app.NotesText);
wheel = BehaviorBoxWheel(gui, app);

baseColor = [0.2 0.3 0.4];
flashColor = [0.8 0.9 1.0];
dimColor = [0.05 0.06 0.07];
thresh = 0.25;

wheel.StimulusStruct = struct( ...
    'LineColor', baseColor, ...
    'FlashColor', flashColor, ...
    'DimColor', dimColor, ...
    'FlashStim', false);
wheel.Setting_Struct = struct('ConfirmChoice', true);

assert(wheel.wheelConfirmChoiceEnabled_(), ...
    'ConfirmChoice should enable the Wheel gradient even when FlashStim is false.');

wheel.isLeftTrial = true;
assertClose_(wheel.wheelCorrectChoiceProgress_(0, thresh), 0, 'Left trial starts at baseline.');
assertClose_(wheel.wheelCorrectChoiceProgress_(thresh / 2, thresh), 0.5, 'Left trial midpoint progress is wrong.');
assertClose_(wheel.wheelCorrectChoiceProgress_(thresh, thresh), 1, 'Left trial threshold progress is wrong.');
assertClose_(wheel.wheelCorrectChoiceProgress_(-thresh, thresh), 0, 'Left trial wrong-direction movement should not brighten.');
assertClose_(wheel.wheelConfirmChoiceColor_(thresh / 2, thresh, baseColor, flashColor), ...
    baseColor + 0.5 .* (flashColor - baseColor), ...
    'Left trial midpoint color is wrong.');

wheel.isLeftTrial = false;
assertClose_(wheel.wheelCorrectChoiceProgress_(0, thresh), 0, 'Right trial starts at baseline.');
assertClose_(wheel.wheelCorrectChoiceProgress_(-thresh / 2, thresh), 0.5, 'Right trial midpoint progress is wrong.');
assertClose_(wheel.wheelCorrectChoiceProgress_(-thresh, thresh), 1, 'Right trial threshold progress is wrong.');
assertClose_(wheel.wheelCorrectChoiceProgress_(thresh, thresh), 0, 'Right trial wrong-direction movement should not brighten.');
assertClose_(wheel.wheelConfirmChoiceColor_(-thresh, thresh, baseColor, flashColor), ...
    flashColor, ...
    'Right trial threshold color should be FlashColor.');

wheel.Setting_Struct.ConfirmChoice = false;
assert(~wheel.wheelConfirmChoiceEnabled_(), 'ConfirmChoice=false should disable the Wheel gradient.');

fig = figure('Visible', 'off', 'Name', 'WheelConfirmChoiceGradientTest');
cleanupFig = onCleanup(@() close(fig));
ax = axes('Parent', fig);
contourLine = line(ax, [0 1], [0 1], 'Tag', 'Contour', 'Color', baseColor);
distractorLine = line(ax, [0 1], [1 0], 'Tag', 'Distractor', 'Color', baseColor);

wheel.isLeftTrial = true;
restoreColor = wheel.wheelConfirmChoiceColor_(thresh / 2, thresh, baseColor, flashColor);
wheel.setLineColorSafe_([contourLine; distractorLine], dimColor);
wheel.setLineColorSafe_(contourLine, restoreColor);
wheel.setLineColorSafe_(distractorLine, baseColor);

assertClose_(contourLine.Color, restoreColor, ...
    'Stall restore should return contour to the current gradient color.');
assertClose_(distractorLine.Color, baseColor, ...
    'Stall restore should return distractor to baseline line color.');

disp("BEHAVIORBOX_WHEEL_CONFIRM_CHOICE_GRADIENT_OK");

function assertClose_(actual, expected, message)
actual = double(actual);
expected = double(expected);
assert(isequal(size(actual), size(expected)), string(message) + " Size mismatch.");
assert(all(abs(actual(:) - expected(:)) < 1e-10), string(message));
end
