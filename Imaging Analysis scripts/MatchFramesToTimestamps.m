% This script is for matching ScanImage timestamps to data saved by BehaviorBox
% It was written for mouse 3169025's data/images recorded 10-16-2025 in
% Rockefeller Brain Observatory
%
% To reproduce:
% Open BehaviorBox App and load the mouse's data, then get the timestamp variables
% from the workspace variable called BBData
%
% !!!  For some reason, Trial number 1's timestamps were not saved. There
% is a bug in the way the timestamps are saved. Not yet fixed.
%
% scanimage Tiff stack #1 is always an artefact, before the program loop begins.
%
% This day had 2 sessions, but only the second was imaged.
%
% Because of the above, We are starting from the:
% 2nd trial (of behavior)
% and the 3rd image (saved from scanimage)

% The below section is commented out, it was to combine Suite2p output back
% when there were errors from saving to .mat format

% % Load neuron F traces from .mat file output from Suite2p
% Data_Dir = '/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Microscope/Images/2025-10-16-Females-Shank-Wheel-316902/5/suite2p_anatomical_3/output';
% %Data_Dir = '/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Microscope/Images/2025-03-06-Female-Shank-Gcamp-Stimulus-Animations/Sequential/output';
% Data_Files = dir(Data_Dir);
% variableName = 'All_F_Fneu_Spks';
% if exist(variableName, 'var') ~= 1
%     fullFilePath = fullfile(Data_Dir, "All_Activity.mat");
%     % Check if the file exists
%     if exist(fullFilePath, 'file') == 2
%         tic
%         load(fullFilePath, "All_F_Fneu_Spks")
%         disp("Fluorescence data loaded")
%         toc
%     else
%         tic
%         F_Files_fds = fileDatastore(Data_Dir, FileExtensions=".mat", ReadFcn=@load);
%         F_Files_fds.Files(contains(F_Files_fds.Files, "Matched")) = [];
%         F_Planes = F_Files_fds.readall;
% 
%         All_F_Fneu_Spks = cell(1,3);
%         All_F_Fneu_Spks{1,1} = cell2mat(cellfun(@(x) x.F(find(x.iscell(:,1)),:), F_Planes, 'UniformOutput', false));
%         All_F_Fneu_Spks{1,2} = cell2mat(cellfun(@(x) x.Fneu(find(x.iscell(:,1)),:), F_Planes, 'UniformOutput', false));
%         All_F_Fneu_Spks{1,3} = cell2mat(cellfun(@(x) x.spks(find(x.iscell(:,1)),:), F_Planes, 'UniformOutput', false));
%         disp("Fluorescence data created")
%         toc
% 
%         tic
%         Save_Name = fullfile(Data_Dir, "All_Activity.mat");
%         save(Save_Name, "All_F_Fneu_Spks", '-mat')
%         disp("Fluorescence data saved")
%         toc
%     end
% end
% % Find the indices of the rows with the greatest variability
% rowVariability = std(AllNeurons, 0, 2); % 0 indicates normalization by N-1
% % For example, get the top 10 rows with the highest standard deviation
% [~, sortedIndices] = sort(rowVariability, 'descend');
% %topRows = sortedIndices(1:10); % Adjust the number as needed

fname = fullfile(Data_Dir, 'FrameCounts.txt'); % This is metadata that can come from the MBO python software package. 
Frame_Counts = readtable(fname, 'Delimiter', '\t');
Frame_Counts.Properties.VariableNames = {'Trial', 'Frames'};
TrialNum = (0:1:numel(Frame_Counts.Frames)-1)';

Frame_Counts = addvars(Frame_Counts, TrialNum, 'NewVariableNames', 'TrialNum');

% Get timestamp record from mouse behavior
%
%TimeStamps = BBData.DayData.Mouse3169025{14,3}.TtimestampRecord; % Get the whole day, all sessions
TimeStamps = BBData.loadedData{25,3}.TtimestampRecord; % Get the specific session data
Event_Choice = BBData.loadedData{25,3}.wheel_record(:,1);
Side = BBData.loadedData{25,3}.isLeftTrial;
CodedChoice = BBData.loadedData{25,3}.CodedChoice;
% !!!  For some reason, Trial number 1 and 2 timestamps are not saved. There is a bug
% in the way the timestamps are saved. Not yet fixed.
TimeStamps(cellfun('isempty',TimeStamps)) = [];
Lost_Trials = TrialNum(end)-numel(TimeStamps);
TrialID = num2cell((1+Lost_Trials):TrialNum(end));

TS_Filter = cell(size(TimeStamps));
Frame_Num = 0;
tsrecord_id = num2cell(1:numel(TimeStamps));
for L = [TimeStamps' ; TrialID ; tsrecord_id]
    ts_id = L{3}; % ID for current timestamp record
    trial_id = L{2}; % Use trial ID to find the frame count from saved TIFF
    trial_choice = Event_Choice(trial_id);
    ROWS = length(L{1});
    ts = table('Size', [ROWS 9], ...
        'VariableTypes', {'double', 'double', 'string', 'string', 'string', 'double' 'string', 'string', 'string'}, ...
        'VariableNames',{'TrialNum', 'Frame', 'Timestamp', 'Epoch', 'Event', 'StimOnsetTime', 'Side', 'Choice', 'Score'});
    ts{:,3} = L{1};
    ts.Score(:) = deal(trial_choice);
    ts.TrialNum(:) = deal(trial_id);
    if Side(trial_id) == 1
        SIDE = "Left";
    else
        SIDE = "Right";
    end
    ts.Side(:) = deal(SIDE);
    switch CodedChoice(trial_id)
        case 1
            CHOICE = "Left";
        case 2
            CHOICE = "Right";
        case 3
            CHOICE = "Left";
        case 4
            CHOICE = "Right";
        otherwise
            CHOICE = "";
    end
    ts.Choice(:) = deal(CHOICE);
    for stamp = 1:ROWS
        if contains(ts{stamp,3}, "S ") | contains(ts{stamp,3}, "Trial")
            ts.Event(stamp+1) = ts.Timestamp(stamp);
        end
    end
    ts = ts(~contains(ts{:,3}, "S ") & ~contains(ts{:,3}, "Trial"),:);

    % Apply the frame counts
    w = Frame_Counts.TrialNum==trial_id;
    FRAMES = Frame_Counts.Frames(w);
    Extra_Counts = FRAMES-size(ts,1);
    w_before = Frame_Counts.TrialNum<trial_id;
    Frames_Before = sum(Frame_Counts.Frames(w_before));
    Frame_Id = Extra_Counts+Frames_Before+1:Frames_Before+FRAMES;
    ts.Frame = Frame_Id';

    % Stimulus and hold still interval times
    Times = str2double(split(ts.Timestamp, ', '));
    Times = Times(:,1);
    ts.Timestamp(:) = Times;
    diffTimes = diff(Times);
    diffTimes(diffTimes<0) = 0; % Filter out any negative values, when the arduino clock flips over
    Stim_On_Frame = find(contains(ts.Event, "S On"));
    w_ts = Stim_On_Frame-1:-1:1; % Go in reverse order to show time before stim came on
    ts.Epoch(w_ts) = deal("Before");
    for W = w_ts
        TimeSince = -1 * sum(diffTimes(W:Stim_On_Frame))/1000000; % -1 offset because of diffTimes being a shorter vector, convert from microseconds
        ts.StimOnsetTime(W) = TimeSince;
    end
    Stim_Off_Frame = find(contains(ts.Event, "S Off"));
    w_ts = Stim_On_Frame:Stim_Off_Frame-1;
    ts.Epoch(w_ts) = deal("S On");
    for W = w_ts
        TimeSince = sum(diffTimes(Stim_On_Frame:W-1))/1000000; % -1 offset because of diffTimes being a shorter vector, convert from microseconds
        ts.StimOnsetTime(W) = TimeSince;
    end
    w_ts = Stim_Off_Frame:length(ts.Event);
    ts.Epoch(w_ts) = deal("After");
    for W = w_ts
        TimeSince = sum(diffTimes(Stim_Off_Frame:W-1))/1000000; % -1 offset because of diffTimes being a shorter vector, convert from microseconds
        ts.StimOnsetTime(W) = TimeSince;
    end
    TS_Filter{ts_id} = ts;
end
Data_Table = cell2mat(TS_Filter);
tic
save("FrameMatched3169025.mat", "Data_Table", '-mat')
toc