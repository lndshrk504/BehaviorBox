scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
cd(repoRoot);
run('startup.m');

set(0, 'DefaultFigureVisible', 'off');
cleanupFigures = onCleanup(@() close(findall(0, 'Type', 'figure', 'Name', 'Stimulus')));

app = MockApp();
gui = struct('MsgBox', app.MsgBox, 'NotesText', app.NotesText);
wheel = BehaviorBoxWheel(gui, app);
wheel.i = 12;

stim = BehaviorBoxVisualStimulus(wheel.StimulusStruct, Preview=true);
[fig, leftAx, rightAx, finishAx] = stim.setUpFigure();
wheel.Stimulus_Object = stim;
wheel.fig = fig;
wheel.LStimAx = leftAx;
wheel.RStimAx = rightAx;
wheel.FLAx = finishAx;

fig.Position = [2 2 4 4];
manualPosition = fig.Position;

app.Stimulus_LineColor.Value = "0.8";
wheel.UpdateSettings();

assert(isequaln(round(fig.Position, 12), round(manualPosition, 12)), ...
    'Non-geometry stimulus setting updates should preserve the live Stimulus figure geometry.');
assert(all(abs(wheel.Stimulus_Object.LineColor - [0.8 0.8 0.8]) < 1e-12), ...
    'Non-geometry stimulus setting update did not update the stimulus property.');

app.Stimulus_size_y.Value = "5";
wheel.UpdateSettings();

expectedPosition = [wheel.StimulusStruct.position_x, ...
    wheel.StimulusStruct.position_y, ...
    wheel.StimulusStruct.size_x, ...
    wheel.StimulusStruct.size_y];
assert(isequaln(round(fig.Position, 12), round(expectedPosition, 12)), ...
    'Stimulus geometry field updates should reapply the requested figure geometry.');

disp("BEHAVIORBOX_WHEEL_STIMULUS_GEOMETRY_UPDATE_OK");
