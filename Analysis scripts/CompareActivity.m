% Scripts to compare neuron activity between like stimulus conditions
%
%
% Uses the outputs of MatchFramesToTimestamps
%
%
%

% Get the fluorescence data and neuron activity
load('/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Microscope/Images/2025-10-16-Females-Shank-Wheel-316902/5/suite2p_anatomical_3/output/All_Activity_3169025.mat')
% Get the matched frames and timestamps
load('/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Microscope/Images/2025-10-16-Females-Shank-Wheel-316902/5/suite2p_anatomical_3/output/FrameMatched3169025.mat')

% A = All_F_Fneu_Spks{1,1}';
% B = All_F_Fneu_Spks{1,2}';
% spks = All_F_Fneu_Spks{1,3}';

Neuron_ = All_F_Fneu_Spks{1,3}';
N_Table = array2table(Neuron_);
N_Table = N_Table(Data_Table.Frame,:); % Crop out the frames we do not have timestamps for (first trial, and first 2 tiff files right now)
N_Table = varfun(@double, N_Table, "OutputFormat","table");
NewVarNames = strrep(N_Table.Properties.VariableNames, 'double_', '');
N_Table.Properties.VariableNames = NewVarNames;

Big_Table = [Data_Table, N_Table];

% Find all Left stimulus trials:

W_Left = Big_Table.Side == "Left";
W_Right = Big_Table.Side == "Right";

Right_Table = Big_Table(W_Right,:);
Left_Table = Big_Table(W_Left,:);
Before = Left_Table.Epoch == "Before";
Stim_On = Left_Table.Epoch == "S On";
After = Left_Table.Epoch == "After";
L_Trials = unique(Left_Table.TrialNum)';
LTS = struct(); % Left Trials Structure
LTS.Stim_On = {};
LTS.Stim_On = table;
LTS.Before = {};
LTS.Before = table;
LTS.After = {};
Stim_On_Table = table;

Frame_Total = 23; % How many frames after Stim On, so total is this + 1
S_on_WinStart = 25;
S_on_WinEnd = S_on_WinStart+Frame_Total;
W_T = S_on_WinStart:1:S_on_WinEnd;
NewVarNames = ["Neu_Trial_ID" string(Left_Table{W_T ,6})'];
AddTable = array2table(zeros(1,Frame_Total+2)); % +1 to account for 0 timepoint, +1 for neuron id label in column 0
AddTable.Properties.VariableNames = NewVarNames;
AddTable.Properties.VariableTypes{1} = 'string';

% Fill in Before Trials frame values
All_tic = tic;
for N = 10:size(Left_Table,2)
    tic
    for T = L_Trials
        W_T = Left_Table.TrialNum == T & Before;
% Make AddTable a row of zeros long enough for a few seconds e.g. 1x50
% zeros
% Then copy the data from the fluorescence table into the AddTable
        trial_data_win = Left_Table(W_T, N);
        trial_data_win = rows2vars(trial_data_win);
        AddTable{1,1} = cell2mat(trial_data_win{1,1}) + "_Trial_"+T;
        AddTable{1,2:end} = 0;
        max_frames = size(trial_data_win,2);
        frameDiff = numel(trial_data_win)-(Frame_Total+2);
        start_frame = 2+frameDiff;
        End_Frame = start_frame+Frame_Total;
        Fnum = 0;
        for f = End_Frame:-1:start_frame % First column has the ID 
            Fnum = f-frameDiff;
            AddTable{1, Fnum} = trial_data_win{1,f};
        end
        LTS.Before = [LTS.Before ; AddTable];
    end
    toc
    disp("Neuron "+(N-10))
end
TotalTime = toc(All_tic);
disp("Total time: "+TotalTime/60+" min");

All_tic = tic;
for N = 10:size(Left_Table,2)
    tic
    for T = L_Trials
        W_T = Left_Table.TrialNum == T;
% Make AddTable a row of zeros long enough for a few seconds e.g. 1x50
% zeros
% Then copy the data from the fluorescence table into the AddTable
        trial_data_win = Left_Table(W_T & Stim_On, N);
        trial_data_win = rows2vars(trial_data_win);
        AddTable{1,1} = cell2mat(trial_data_win{1,1}) + "_Trial_"+T;
        max_frames = size(trial_data_win,2);
        for f = 2:(Frame_Total+2) % First column has the ID 
            if f > max_frames
                break
            end
            AddTable{1, f} = trial_data_win{1,f};
        end
        LTS.Stim_On = [LTS.Stim_On ; AddTable];
    end
    toc
    disp("Neuron "+(N-10))
end
TotalTime = toc(All_tic);
disp("Total time: "+TotalTime/60+" min");

