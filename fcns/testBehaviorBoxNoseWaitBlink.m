scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
addpath(fullfile(repoRoot, 'MockApp'));
cd(repoRoot);
run('startup.m');

assert(runWaitBlinkCase_(true), ...
    "Wait_Blink=true should dim the ready cue after Wait_Blink_Sec of no sensor input.");
assert(~runWaitBlinkCase_(false), ...
    "Wait_Blink=false should not dim the ready cue during no-input waiting.");

disp("BEHAVIORBOX_NOSE_WAIT_BLINK_OK");

function didDim = runWaitBlinkCase_(waitBlinkEnabled)
    app = MockApp();
    app.Box_Input_type.Value = 'NosePoke';
    gui = struct('MsgBox', app.MsgBox, 'NotesText', app.NotesText);
    nose = MockBehaviorBoxNoseWaitBlink(gui, app);

    fig = figure('Visible', 'off', 'Name', 'NoseWaitBlinkTest');
    ax = axes('Parent', fig, 'Tag', 'ReadyCue');
    dot = scatter(ax, 0, 0, 100, ...
        'MarkerFaceColor', [1 1 1], ...
        'MarkerEdgeColor', 'none', ...
        'Tag', 'ReadyCueDot');

    arduino = MockArduino();
    arduino.setTokenScript(repmat('-', 1, 1000));
    nose.a = arduino;
    nose.fig = fig;
    nose.ReadyCueAx = ax;
    nose.stop_handle = app.Stop;
    nose.message_handle = app.text1;
    nose.Box = struct('Input_type', 3);
    nose.StimulusStruct = struct( ...
        'LineColor', [1 1 1], ...
        'DimColor', [0.2 0.2 0.2], ...
        'FlashColor', [0 1 0], ...
        'BackgroundColor', [0 0 0], ...
        'FreqAnimation', 1, ...
        'FlashStim', true);
    nose.Setting_Struct = struct( ...
        'IntertrialMalCancel', false, ...
        'Input_Delay_Start', 0, ...
        'Input_Delay_Respond', 0, ...
        'Wait_Blink', waitBlinkEnabled, ...
        'Wait_Blink_Sec', 0.03);

    stopTimer = timer( ...
        'ExecutionMode', 'singleShot', ...
        'StartDelay', 0.20, ...
        'TimerFcn', @(~, ~) set(app.Stop, 'Value', true));
    cleanup = onCleanup(@() cleanupCase_(fig, stopTimer));

    start(stopTimer);
    nose.WaitForInputArduino();

    didDim = any(all(abs(nose.ReadyCueColorHistory - nose.StimulusStruct.DimColor) < 1e-10, 2));
    assert(all(abs(dot.MarkerFaceColor - nose.StimulusStruct.LineColor) < 1e-10), ...
        "Ready cue color should be restored after WaitForInputArduino exits.");
end

function cleanupCase_(fig, timers)
    try
        stop(timers);
        delete(timers);
    catch
    end
    if ~isempty(fig) && isvalid(fig)
        close(fig);
    end
end
