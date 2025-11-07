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

Neuron_ = All_F_Fneu_Spks{1,3}';
N_Table = array2table(Neuron_);
N_Table = N_Table(Data_Table.Frame,:); % Crop out the frames we do not have timestamps for (first trial, and first 2 tiff files right now)
N_Table = varfun(@double, N_Table, "OutputFormat","table");
newVarNames = strrep(N_Table.Properties.VariableNames, 'double_', '');
N_Table.Properties.VariableNames = newVarNames;

Big_Table = [Data_Table, N_Table];

% Find all Left stimulus trials:

W_Left = Data_Table.Side == "Left";
W_Right = Data_Table.Side == "Right";

Right_Table = Big_Table(W_Right,:);
Left_Table = Big_Table(W_Left,:);
Before = Left_Table.Epoch == "Before";
Stim_On = Left_Table.Epoch == "S On";
After = Left_Table.Epoch == "After";
L_Trials = unique(Left_Table.TrialNum)';
LTS = struct(); % Left Trials Structure
LTS.Stim_On = {};
LTS.Before = {};
LTS.After = {};
Stim_On_Table = table;
for T = L_Trials
    W_T = Left_Table.TrialNum == T;
    %LTS.("Trial"+T) = Left_Table(W_T,:);
    LTS.Stim_On = table;
    NewVarNames = ["NeuronName" string(Left_Table{W_T & Stim_On,[6]})'];
    for N = 10:size(Left_Table,2)
        AddTable = rows2vars(Left_Table(W_T & Stim_On,[N]));
        AddTable.Properties.VariableNames = NewVarNames;
        LTS.Stim_On = [LTS.Stim_On ; AddTable];
    end
    
end

% Strategy: 1 Compare average activity between individual neurons
% Loop through each of 5700 neurons, then each trial and sort into left and
% right then correct vs incorrect

% A big table of [left correct] [etc] broken into [Stim on] or [Before] or [After] spikes
% each row is a trial
% neuron_1_trial_1
% neuron_1_trial_2
% neuron_1_trial_3
% Make an average for each neuron at each timepoint
% each column is stim on timepoint or frames since stim on
%
% Strategy 2: Compare every neuron to every other neuron
% Permute through each possible pair combination from 1 to 5717
% and compare those neurons' "correlation" or "coherence" or mutual
% information

% Strategy 3: For a pair or neurons:
% Compare spiking activity to stimulus-on-frame and make a
% cumulative histogram, repeating for every trial 
%
%
%
%