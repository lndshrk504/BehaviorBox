load('/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Microscope/Images/2025-10-16-Females-Shank-Wheel-316902/5/suite2p_anatomical_3/output/FrameMatched3169025.mat')

Trials = unique(Data_Table.TrialNum)';
Is_Left = Data_Table.Side == "Left";
Left_Trials = unique(Data_Table.TrialNum(Is_Left))';
Right_Trials = unique(Data_Table.TrialNum(~Is_Left))';
S_On = Data_Table.Epoch == "S On";
Before = Data_Table.Epoch == "Before";

% Left Stim On
TrialFrames = cellfun(@(x) sum(S_On & Is_Left & Data_Table.TrialNum == x), num2cell(Left_Trials));
Frames_to_Avg = min(TrialFrames);

Left_Frame_Table_Stim = array2table(zeros(numel(Left_Trials), Frames_to_Avg));
NewNames = strrep(Left_Frame_Table_Stim.Properties.VariableNames, 'Var', 'Frame ');
Left_Frame_Table_Stim.Properties.VariableNames = NewNames;
Left_Frame_Table_Stim.Properties.RowNames = cellstr("Trial_"+(Left_Trials)');

c = 0;
for Lt = Left_Trials
    c = c+1;
    WT = find(S_On & Data_Table.TrialNum == Lt);
    WF = Data_Table.Frame(WT(1:Frames_to_Avg))';
    Left_Frame_Table_Stim{c,:} = WF;
end

% Right Stim On
TrialFrames = cellfun(@(x) sum(S_On & ~Is_Left & Data_Table.TrialNum == x), num2cell(Right_Trials));
Frames_to_Avg = min(TrialFrames);

Right_Frame_Table_Stim = array2table(zeros(numel(Right_Trials), Frames_to_Avg));
NewNames = strrep(Right_Frame_Table_Stim.Properties.VariableNames, 'Var', 'Frame ');
Right_Frame_Table_Stim.Properties.VariableNames = NewNames;
Right_Frame_Table_Stim.Properties.RowNames = cellstr("Trial_"+(Right_Trials)');

c = 0;
for Rt = Right_Trials
    c = c+1;
    WT = find(S_On & Data_Table.TrialNum == Rt);
    WF = Data_Table.Frame(WT(1:Frames_to_Avg))';
    Right_Frame_Table_Stim{c,:} = WF;
end


% Left Before Trials
TrialFrames = cellfun(@(x) sum(Before & Is_Left & Data_Table.TrialNum == x), num2cell(Left_Trials));
Frames_to_Avg = min(TrialFrames);

Left_Frame_Table_Before = array2table(zeros(numel(Left_Trials), Frames_to_Avg));
NewNames = strrep(Left_Frame_Table_Before.Properties.VariableNames, 'Var', 'Frame ');
Left_Frame_Table_Before.Properties.VariableNames = NewNames;
Left_Frame_Table_Before.Properties.RowNames = cellstr("Trial_"+(Left_Trials)');

c = 0;
for Lt = Left_Trials
    c = c+1;
    WT = find(Before & Data_Table.TrialNum == Lt);
    Frame_IDs = numel(WT)-(Frames_to_Avg-1):numel(WT);
    WF = Data_Table.Frame(WT(Frame_IDs))';
    Left_Frame_Table_Before{c,:} = WF;
end

% Right Before Trials
TrialFrames = cellfun(@(x) sum(Before & ~Is_Left & Data_Table.TrialNum == x), num2cell(Right_Trials));
Frames_to_Avg = min(TrialFrames);

Right_Frame_Table_Before = array2table(zeros(numel(Right_Trials), Frames_to_Avg));
NewNames = strrep(Right_Frame_Table_Before.Properties.VariableNames, 'Var', 'Frame ');
Right_Frame_Table_Before.Properties.VariableNames = NewNames;
Right_Frame_Table_Before.Properties.RowNames = cellstr("Trial_"+(Right_Trials)');

c = 0;
for Rt = Right_Trials
    c = c+1;
    WT = find(Before & Data_Table.TrialNum == Rt);
    Frame_IDs = numel(WT)-(Frames_to_Avg-1):numel(WT);
    WF = Data_Table.Frame(WT(Frame_IDs))';
    Right_Frame_Table_Before{c,:} = WF;
end

Frames2Avg = struct();
Frames2Avg.LeftBefore = Left_Frame_Table_Before;
Frames2Avg.LeftStim = Left_Frame_Table_Stim;
Frames2Avg.RightBefore = Right_Frame_Table_Before;
Frames2Avg.RightStim = Right_Frame_Table_Stim;

save("Frames2Avg.mat", "Frames2Avg", '-mat')

writetable(Right_Frame_Table_Stim, 'Right_Frame_Table_Stim.csv')
writetable(Right_Frame_Table_Before, 'Right_Frame_Table_Before.csv')
writetable(Left_Frame_Table_Stim, 'Left_Frame_Table_Stim.csv')
writetable(Left_Frame_Table_Before, 'Left_Frame_Table_Before.csv')