scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(fullfile(repoRoot, 'MockApp'));
cd(repoRoot);
run('startup.m');

rng(7, 'twister');

app = MockApp();
gui = struct('MsgBox', app.MsgBox, 'NotesText', app.NotesText);

nose = configureWorkflow(BehaviorBoxNose(gui, app), app);
wheel = configureWorkflow(BehaviorBoxWheel(gui, app), app);

exercisePickSide(nose, "Nose");
exercisePickSide(wheel, "Wheel");

disp("BEHAVIORBOX_PICK_SIDE_FOR_CORRECT_OK");

function workflow = configureWorkflow(workflow, app)
    workflow.message_handle = app.text1;
    workflow.Setting_Struct = struct('Repeat_wrong', false);
    workflow.StimulusStruct = struct('side', 1);
    workflow.Data_Object = struct('current_data_struct', struct( ...
        'Score', [], ...
        'CodedChoice', []));
    workflow.i = 2;
    workflow.current_side = "";
end

function exercisePickSide(workflow, label)
    workflow.i = 2;
    workflow.Setting_Struct.Repeat_wrong = true;
    workflow.Data_Object.current_data_struct.Score = 1;

    workflow.StimulusStruct.side = 2;
    vals = zeros(1, 20);
    for k = 1:numel(vals)
        vals(k) = workflow.PickSideForCorrect(0, []);
    end
    assert(all(vals == 1), label + " forced-left mode should stay left when Repeat_wrong is enabled.");
    assert(strcmp(workflow.current_side, 'left'), label + " current_side should match forced-left mode.");

    workflow.StimulusStruct.side = 3;
    for k = 1:numel(vals)
        vals(k) = workflow.PickSideForCorrect(1, []);
    end
    assert(all(vals == 0), label + " forced-right mode should stay right when Repeat_wrong is enabled.");
    assert(strcmp(workflow.current_side, 'right'), label + " current_side should match forced-right mode.");

    workflow.StimulusStruct.side = 5;
    workflow.Data_Object.current_data_struct.Score = [1 0];
    assert(workflow.PickSideForCorrect(1, []) == 1, label + " repeat-wrong should preserve previous left side after wrong.");
    assert(strcmp(workflow.current_side, 'left'), label + " current_side should update after repeat-wrong left.");
    assert(workflow.PickSideForCorrect(0, []) == 0, label + " repeat-wrong should preserve previous right side after wrong.");
    assert(strcmp(workflow.current_side, 'right'), label + " current_side should update after repeat-wrong right.");

    workflow.StimulusStruct.side = 1;
    workflow.Setting_Struct.Repeat_wrong = false;
    workflow.Data_Object.current_data_struct.Score = 1;
    for k = 1:numel(vals)
        vals(k) = workflow.PickSideForCorrect(0, []);
    end
    assert(all(vals == 0 | vals == 1), label + " random mode should return binary side values.");

    workflow.StimulusStruct.side = 1;
    workflow.Setting_Struct.Repeat_wrong = true;
    workflow.Data_Object.current_data_struct.Score = [1 0];
    assert(workflow.PickSideForCorrect(1, []) == 1, label + " global Repeat_wrong should preserve previous side after wrong.");

    workflow.Data_Object.current_data_struct.CodedChoice = [1 3 1 2];
    SB = workflow.currentResponseSideBias_();
    assert(SB > 0, label + " positive side bias should mean left-biased responses.");
    [sideChoice, sideText, biasText] = workflow.correctSideForBias_(SB);
    assert(sideChoice == 0, label + " left response bias should be corrected with a right trial.");
    assert(strcmp(sideText, 'Right trial'), label + " positive bias side label mismatch.");
    assert(strcmp(biasText, 'Left bias'), label + " positive bias label mismatch.");

    workflow.Data_Object.current_data_struct.CodedChoice = [2 4 2 1];
    SB = workflow.currentResponseSideBias_();
    assert(SB < 0, label + " negative side bias should mean right-biased responses.");
    [sideChoice, sideText, biasText] = workflow.correctSideForBias_(SB);
    assert(sideChoice == 1, label + " right response bias should be corrected with a left trial.");
    assert(strcmp(sideText, 'Left trial'), label + " negative bias side label mismatch.");
    assert(strcmp(biasText, 'Right bias'), label + " negative bias label mismatch.");

    workflow.Data_Object.current_data_struct.CodedChoice = [5 6];
    assert(workflow.currentResponseSideBias_() == 0, label + " timeout-only data should not imply side bias.");
end
