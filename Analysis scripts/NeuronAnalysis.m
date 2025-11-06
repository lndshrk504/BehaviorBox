% This script is for analyzing 3169025 data from 10-16-2025
% Open BB App and load this mouse's data, the get the timestamp variables
% from the workspace as BBData

% Load neuron F traces from .mat file output from Suite2p
Data_Dir = '/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Microscope/Images/2025-10-16-Females-Shank-Wheel-316902/5/suite2p_anatomical_3/output';
%Data_Dir = '/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Microscope/Images/2025-03-06-Female-Shank-Gcamp-Stimulus-Animations/Sequential/output';
Data_Files = dir(Data_Dir);
MAT_idx = contains({Data_Files.name}, ".mat");
F_idx = contains({Data_Files.name}, "_F.");
Fneu_idx = contains({Data_Files.name}, "_Fneu.");
Spks_idx = contains({Data_Files.name}, "_spks.");
% Filter the list of files to only include those that match the criteria
F_Files = Data_Files(F_idx & MAT_idx);
Fneu_Files = Data_Files(Fneu_idx & MAT_idx);
Spks_Files = Data_Files(Spks_idx & MAT_idx);

All_F_Fneu_Spks = cell(1,3);
for FILE = [F_Files Fneu_Files Spks_Files]'
    F_Data = load(fullfile(FILE(1).folder, FILE(1).name));
    All_F_Fneu_Spks{1,1} = [All_F_Fneu_Spks{1,1}; F_Data.data]; % Assuming 'F' contains the neuron F traces
    Fneu_Data = load(fullfile(FILE(2).folder, FILE(2).name));
    All_F_Fneu_Spks{1,2} = [All_F_Fneu_Spks{1,2}; Fneu_Data.data]; % Assuming 'F' contains the neuron F traces
    Spks_Data = load(fullfile(FILE(3).folder, FILE(3).name));
    All_F_Fneu_Spks{1,3} = [All_F_Fneu_Spks{1,3}; Spks_Data.data]; % Assuming 'F' contains the neuron F traces
end

% % Find the indices of the rows with the greatest variability
% rowVariability = std(AllNeurons, 0, 2); % 0 indicates normalization by N-1
% % For example, get the top 10 rows with the highest standard deviation
% [~, sortedIndices] = sort(rowVariability, 'descend');
% %topRows = sortedIndices(1:10); % Adjust the number as needed

fname = fullfile(Data_Dir, 'FrameCounts.txt');
% Option 1: Load as a numeric matrix (auto-detects common delimiters)
Frame_Counts = readtable(fname, 'Delimiter', '\t');
Frame_Counts.Properties.VariableNames = {'File', 'Frames'};

% Get timestamp record from mouse behavior
TimeStamps = BBData.DayData.Mouse3169025{14,3}.TtimestampRecord;
TimeStamps = TimeStamps(3:end);
TS_Filter = cell(size(TimeStamps));
Frame_Num = 0;
for L = 1:length(TimeStamps)
    if isempty(TimeStamps{L})
        continue
    end
    if L>1
        Frame_Num = ts.Frame(end);
    end
    FRAMES = length(TimeStamps{L});
    ts = table('Size', [FRAMES 3], 'VariableTypes', {'string','string','double'},'VariableNames',{'Timestamp', 'Event', 'Frame'});
    ts{:,1} = TimeStamps{L};
    for stamp = 1:FRAMES
        if contains(ts{stamp,1}, "S ") | contains(ts{stamp,1}, "Trial")
            ts.Event(stamp+1) = ts.Timestamp(stamp);
        end
    end
    ts = ts(~contains(ts{:,1}, "S ") & ~contains(ts{:,1}, "Trial"),:);
    ts.Frame = (1+Frame_Num:length(ts.Timestamp)+Frame_Num)';
    TS_Filter{L} = ts;
end

% !!!  For some reason, Trial number 1 and 2 are messed up. There is a bug
% in the way the timestamps are saved. Not yet fixed.
% 
% Tiff stack #1 is always an artifact, before the program loop begins.
% 
% This day has 2 sessions, but only the second was imaged. 
% 
% Because of the above, We are starting from the:
% 3rd timestamp
% and the 3rd image

% Align the timestamps to trials back to front since first trial is
% overwritten right now
% Assume a few more frames were saved than timestamps, align the timestamps
% to frames from back to front

Total_Frames = sum(Frame_Counts.Frames(3:end));
Total_Stamps = sum(cellfun(@(x) size(x,1), TimeStamps));