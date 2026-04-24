scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
cd(repoRoot);
run('startup.m');

cleanupFigures = onCleanup(@() close(findall(0, 'Type', 'figure', 'Name', 'Stimulus')));

wheel = makeWheel_();
stim = BehaviorBoxVisualStimulus(struct( ...
    'InputType', 6, ...
    'FinishLine', false, ...
    'SpotlightToggle', false, ...
    'LineColor', [0.6 0.6 0.6]), Preview=true);
[fig, leftAx, rightAx] = stim.setUpFigure();
fig.Visible = 'off';
wheel.fig = fig;
wheel.LStimAx = leftAx;
wheel.RStimAx = rightAx;
wheel.Stimulus_Object = stim;

[rightGroup, leftGroup] = stim.getWheelMotionTargets();
rightGroup.Matrix = makehgtform('translate', [10 0 0]);
leftGroup.Matrix = makehgtform('translate', [-10 0 0]);
wheel.LStimAx.Position(1) = -0.18;
wheel.RStimAx.Position(1) = 0.32;
wheel.CurrentRawWheel = 55;
wheel.CurrentDelta = -0.22;
wheel.CurrentStimColor = 0.1;

wheel.resetReusedWheelStimulusForNewTrial_();

assert(abs(wheel.LStimAx.Position(1) - 0) < 1e-12, ...
    'Reused Wheel stimulus should reset the left stimulus axis position.');
assert(abs(wheel.RStimAx.Position(1) - 0.5) < 1e-12, ...
    'Reused Wheel stimulus should reset the right stimulus axis position.');
assert(isequal(round(leftGroup.Matrix, 12), eye(4)), ...
    'Reused Wheel stimulus should reset the left hgtransform matrix.');
assert(isequal(round(rightGroup.Matrix, 12), eye(4)), ...
    'Reused Wheel stimulus should reset the right hgtransform matrix.');
assert(wheel.CurrentRawWheel == 0, ...
    'Reused Wheel stimulus should reset the recorded raw wheel position.');
assert(wheel.CurrentDelta == 0, ...
    'Reused Wheel stimulus should reset the recorded stimulus delta.');
assert(abs(wheel.CurrentStimColor - 0.6) < 1e-12, ...
    'Reused Wheel stimulus should reset the recorded stimulus color to baseline.');

fallbackWheel = makeWheel_();
fallbackWheel.fig = figure('Visible', 'off', 'Name', 'Stimulus');
fallbackWheel.LStimAx = axes('Parent', fallbackWheel.fig, 'Position', [-0.15 0 0.5 1]);
fallbackWheel.RStimAx = axes('Parent', fallbackWheel.fig, 'Position', [0.28 0 0.5 1]);
leftTransform = hgtransform('Parent', fallbackWheel.LStimAx, 'Tag', 'StimulusTransform');
rightTransform = hgtransform('Parent', fallbackWheel.RStimAx, 'Tag', 'StimulusTransform');
leftTransform.Matrix = makehgtform('translate', [-5 0 0]);
rightTransform.Matrix = makehgtform('translate', [5 0 0]);
fallbackWheel.Stimulus_Object = struct();
fallbackWheel.CurrentRawWheel = 8;
fallbackWheel.CurrentDelta = 0.11;

fallbackWheel.resetReusedWheelStimulusForNewTrial_();

assert(abs(fallbackWheel.LStimAx.Position(1) - 0) < 1e-12, ...
    'Fallback Wheel reset should restore the left axis position.');
assert(abs(fallbackWheel.RStimAx.Position(1) - 0.5) < 1e-12, ...
    'Fallback Wheel reset should restore the right axis position.');
assert(isequal(round(leftTransform.Matrix, 12), eye(4)), ...
    'Fallback Wheel reset should clear left tagged hgtransform motion.');
assert(isequal(round(rightTransform.Matrix, 12), eye(4)), ...
    'Fallback Wheel reset should clear right tagged hgtransform motion.');
assert(fallbackWheel.CurrentRawWheel == 0 && fallbackWheel.CurrentDelta == 0, ...
    'Fallback Wheel reset should clear recorded wheel displacement.');

disp("BEHAVIORBOX_WHEEL_REPEAT_WRONG_RESET_OK");

function wheel = makeWheel_()
app = MockApp();
gui = struct('MsgBox', app.MsgBox, 'NotesText', app.NotesText);
wheel = BehaviorBoxWheel(gui, app);
wheel.StimulusStruct = struct('LineColor', [0.6 0.6 0.6]);
end
