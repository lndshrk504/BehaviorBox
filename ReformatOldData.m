function [files, allData] = ReformatOldData(Input, Investigator, WhichStrain, WhichMice)
% This reformats all of the old data files and saves them in the new format.

% !!! Data is stored by BehaviorBox as such:
%               [    1                 2                          3            4                    5                     6                  7                         8                       9                   10                         11             12   13 ]
% data = double([Timestamp' ActivityCorrectWrongTimeout' DifficultyLevel' isLeftTrial' [this.what_decision_record]' RewardPulses' [this.interPuffRecord]' [this.duringPuffRecord]' [this.betweenTrialsRecord]' ResponseTime'  [this.drinkDwellTimeRecord]' SetIdx' T']);
% Data will be saved in newData structure with the following fields:
% 3  Timestamp
% 4  Score
% 5  Level
% 6  isLeftTrial
% 7  WhatDecision
%    CodedChoice
% 8  RewardPulses
% 9  InterTMal
% 10 DuringTMal
% 11 Trial Start Time / Between trials time
% 12 ResponseTime
% 13 drinkDwellTime
%    Between Trial time (remove if its all zeros)
%    SetUpdateRec (this is Updated When)
% 14 SetIdx (which settings label to use if there were changes
% 15 isTraining (these bins are removed when counting days to master)
%    SideBias (replace with zeros)
%    Wheel Record (remove this from the newData structure and put in parent structure)
%    SetStr

    dbstop if error
    evalin('base', 'clc')
    if nargin == 0 %Supply empty variables
        Input = {'Wheel'};
        Investigator = 'Will'; %Put the relevant mice in this folder
        WhichStrain = {'16p'}; %Must be chars in cells % 8/15/22 On my mac at home Matlab and my whole computer crashed when I did all the mice (6500 files). I think from not deleting all of the intermediate variables...
        WhichMice = {'all'}; %Must be chars in cells
    end
    tree = split(pwd, filesep);
    tree{end+1} = 'New Archive';
    tree{end+1} = Input{:};
    tree{end+1} = WhichStrain{:};
    tree{end+1} = '';
    newtree = join(tree, filesep);
    for I = Input
        [files, allData, toChange] = GetFiles(I, Investigator, WhichStrain, WhichMice);
        count = 0;
        order = [9 1 2 3 4 5 6 7 8];
        for f = allData(toChange,:)'
            count = count +1;
            cIdx = toChange(count);
            try
%                 if ~isempty(f{3}) 
%                     continue %Skip the training data I have already reformatted
%                 end
                switch true
                    case contains(Input, 'wheel', 'IgnoreCase', true)
                        %newData = WheelRearrangeData(thisData);
                        newData = NoseRearrangeData(f{2});
                    case contains(Input, 'nose', 'IgnoreCase', true)
                        newData = NoseRearrangeData(f{2});
                    otherwise
                        fprintf("No reformat method for this input type \n")
                end
                tbl = struct2cell(newData)';
                trialTblnames = fieldnames(newData);
                findrows = find(cellfun(@isrow, tbl));
                findrows = findrows(findrows <= 6);
                for r = findrows
                    tbl{r} = tbl{r}';
                end
                try
                    trialTbl = cell2mat(tbl(1:6));
                catch %Fails if trial data was dropped, vectors are unequal lengths (that time I put input ignored for 'q' seconds and it crashed)
                    [m,~] = size(newData.Score);
                    for col = find(cellfun(@numel, tbl(1:6)) ~= m)
                        tbl{col} = tbl{col}(1:m);
                    end
                    try
                        trialTbl = cell2mat(tbl(1:6));
                    catch err
                        unwrapErr(err)
                    end
                end
                %Add some stuff to trialTbl before saving...
                [m,~] = size(trialTbl);
                trialNo = 1:m;
                try
                    trialTbl = [trialNo' trialTbl newData.Include(tbl{6})];
                catch
                    trialTbl = [trialNo' trialTbl newData.Include(tbl{6})'];
                end
                trialTbl(:,9) = deal((f{1}));
                trialTbl = trialTbl(:,order);
                trialTblnames = trialTblnames(1:6);
                trialTblnames = ["Date YYMMDD" ; "TrialNum" ; trialTblnames ; "Include"];
                allData{cIdx,3} = trialTbl; %the data
                try
%                     if ~exist(replace(files(cIdx).folder, 'Will', 'New Archive'), 'dir')
%                         mkdir(replace(files(cIdx).folder, 'Will', 'New Archive'))
%                     end
%                     save([replace(files(cIdx).folder, 'Will', 'New Archive') filesep files(cIdx).name], 'newData', "trialTbl", "trialTblnames")
                    save([files(cIdx).folder filesep files(cIdx).name], 'newData', "trialTbl", "trialTblnames", '-append')
                catch err
                        unwrapErr(err)
%                     try
%                         if ~exist(replace(files(cIdx).folder, 'Will', 'New Archive'), 'dir')
%                             mkdir(replace(files(cIdx).folder, 'Will', 'New Archive'))
%                         end
%                         save([replace(files(cIdx).folder, 'Will', 'New Archive') filesep files(cIdx).name], 'newData', "trialTbl", "trialTblnames")
%                     catch err
%                         unwrapErr(err)
%                     end
                end
%                 if exist('wheel_record','var')
%                     save([files(cIdx).folder filesep files(cIdx).name], 'newData', "trialTbl", "trialTblnames", '-append')
%                 else
%                     save([files(cIdx).folder filesep files(cIdx).name], 'newData', "trialTbl", "trialTblnames", '-append')
%                 end
            catch err
                unwrapErr(err)
            end
            clear newData trialTbl trialTblnames tbl thisData newData wheel_record %clear these variables so they are not used again
        end %End of files loop
    end %End of input loop
end %End of Main function
function unwrapErr(err, ~)
%fprintf('Error at line %d \n', line_num.line)
errFields = fields(err);
for i = 1:numel(errFields)
    if ~matches(errFields{i}, 'stack')
        if ~isempty(err.(errFields{i}))
            disp([errFields{i} ': ' err.(errFields{i})])
        end
    elseif matches(errFields{i}, 'stack')
        for L = numel(err.stack):-1:1
            disp(['In fx ' err.stack(L).name ', line ' num2str(err.stack(L).line)])
        end
    end
end
end
function [files, allData, toChange] = GetFiles(Input, Investigator, WhichStrain, WhichMice)
%Get all of the files in the Investigator / Input folder, subjects do not matter
    current = mfilename('fullpath'); %Get the training data filepath
    [thispath,~,~] = fileparts(current);
    invPath = [thispath filesep Investigator filesep '**/*.mat'];
    Inv = dir(thispath);
    whichInv = contains({Inv.name}, Investigator,IgnoreCase=1);
    Inv = Inv(whichInv);
    invPath = [Inv.folder filesep Inv.name filesep '**/*.mat'];
    files = dir(invPath);
    skipnames = {'settings', 'statistics', 'cage(#)'};
    files(contains( {files.name}, skipnames, IgnoreCase=true)) = [];
    files = files(contains({files.folder}, Input));
%     if sum(whichInv)>1
%         whichInv = find(whichInv,1,'first');
%         disp( [ 'Multiple matches for INVESTIGATOR, guessing & using: "' Inv(whichInv).name '". Check spelling and try again if wrong...'] )
%     end
%     Inp = dir( [ thispath filesep Inv(whichInv).name filesep ] );
%     Inp = Inp( [ Inp.isdir ] );
%     whichInp = contains({Inp.name}, Input, IgnoreCase = 1);
%     if sum(whichInp)>1
%         whichInp = find(whichInp,1,'first');
%         disp( [ 'Multiple matches for INPUT, guessing & using: "' Inp(whichInp).name '". Check spelling and try again if wrong...'] )
%     end
%     Groups = dir( [ thispath filesep Inv(whichInv).name filesep Inp(whichInp).name filesep ] );
%     Groups = Groups( [Groups.isdir] );
%     Groups(ismember({Groups.name},{'.', '..', 'w', 'W', 'Strain'})) = []; %Skip the random names I use when I test the box:
%     contains({Groups.name}, WhichStrain)
% 
%     switch true %Find which groups
%         case isempty(WhichStrain)
%             gPath = [Groups(1).folder filesep '**/*.mat'];
%         case contains(WhichStrain, 'all', 'IgnoreCase', true)
%             gPath = [Groups(1).folder filesep '**/*.mat'];
%         case ~any(contains(WhichStrain, 'all', 'IgnoreCase', true))
%             allGroups = 1:numel(Groups);
%             whichGroups = allGroups(contains({Groups.name}, WhichStrain));
%             gPath =[Groups(whichGroups).folder filesep Groups(whichGroups).name filesep '**/*.mat'];
%     end
%     files = dir(gPath);
%     skipnames = {'settings', 'statistics', 'cage(#)'};
%     files(contains( {files.name}, skipnames, IgnoreCase=true)) = [];
    if ~contains(WhichMice, 'all') && ~isempty(WhichMice)
        files = files(contains({files.folder}', WhichMice));
    end
    zerosList = [];
    loadedfiles = cell(size(files));
    count = 1;
    allData = cell(numel(files),4);
%
% Add this into files loop to check for wheel record
%     try %Only wheel mice have this structure
%         if isfield(thisData.newData, 'wheel_record')
%             wheel_record = thisData.newData.wheel_record;
%             thisData.newData = rmfield(thisData.newData, 'wheel_record');
%         end
%     end
    for f = files'
        allData{count, 1} = str2double(f.name(1:6));
        allData{count, 4} = f.name;
        loadedfiles{count} = load([f.folder filesep f.name]);
        try
            if any(all(loadedfiles{count}.trialTbl(:,:) == 0)) %check if any columns are all zeros
                if any(find(all(loadedfiles{count}.trialTbl(:,:) == 0))~=6)
                    zerosList = [zerosList count]; %Add these to the list so they can be manually restored from Dropbox
                end
            end
        catch %err
            %unwrapErr(err)
        end
        count = count+1;
    end
    allData(:,2) = loadedfiles;
%     if numel(zerosList)>0
%         fprintf(['Recover ' num2str(numel(zerosList)) ' files that have all-zero or lost data...\n']);
%         fprintf([' - ' cell2mat(join({files(zerosList).name}, '\n - ')) '\n']);
%     elseif numel(zerosList) == 0
%         %fprintf(['No files found with all-zero data.\n']);
%     end
    names = cellfun(@fieldnames, loadedfiles, 'UniformOutput', false);
    cellfind = @(string)(@(cell_contents)(strcmp(string,cell_contents))); % % Taken from comments of: https://www.mathworks.com/matlabcentral/answers/2015-find-index-of-cells-containing-my-string
    toKeep = cellfun(@any, cellfun(cellfind('trialTbl'),names,'UniformOutput',false));
    for r = find(toKeep')
        allData{r,3} = allData{r,2}.trialTbl;
    end
    toChange = ~cellfun(@any, cellfun(cellfind('trialTbl'),names,'UniformOutput',false));
    if sum(toChange) > 0
        fprintf(['Found ' num2str(sum(toChange)) ' files to reformat...\n']);
        fprintf([' - ' cell2mat(join({files(toChange).name}, '\n - ')) '\n']);
        %changeData = loadedfiles(toChange);
        toChange = find(toChange);
    else
        fprintf(['No files to update...\n']);
    end
%Check who has settings
    hasSet = zeros(size(allData(:,2)));
    names = {};
    c = 0;
    for a = allData(:,2)'
        c = c+1;
        d = a{:};
        try
            if isfield(d.newData, 'SetStr')
                hasSet(c) = 1;
            end
            if isfield(d, 'SetStr')
                hasSet(c) = 2;
            end
            if isfield(d.Settings, 'SetStr')
                hasSet(c) = 3;
                if numel(d.newData.Settings) == numel(d.newData.SetStr)
                    hasSet(c) = 4;
                else
                    hasSet(c) = 0;
                    names{c} = allData{c,4};
                end
            end
        catch
            names{c} = allData{c,4};
        end
    end
end
function [score, isLeftTrial, CodedChoice] = fixAllZeros(d)
%Get score (col 4), isLeftTrial (col 6) and CodedChoice (col 7), from wheel_record
score = contains({d.wheel_record{:,1}}', 'correct');
isLeftTrial = nan(size(score));
CodedChoice = nan(size(score));
count = 1;
for t = {d.wheel_record{:,1}}
    switch 1
        case contains(t, 'left correct')
            isLeftTrial(count) = 1;
            CodedChoice(count) = 1;
        case contains(t, 'left wrong')
            isLeftTrial(count) = 0;
            CodedChoice(count) = 3;
        case contains(t, 'right correct')
            isLeftTrial(count) = 0;
            CodedChoice(count) = 2;
        case contains(t, 'right wrong')
            isLeftTrial(count) = 1;
            CodedChoice(count) = 4;
        otherwise %Never reached
    end
    count = count+1;
end
end
function [newData] = NoseRearrangeData(thisData)
    try
        %These are all of the possible fields in the structure. Fill in as many as possible:
        % CodedWhatDecision is changed to CodedChoice to remove confusion with WhatDecision
            structOrder = {
                'TimeStamp', 
                'Score', 
                'Level', 
                'isLeftTrial',
                'CodedChoice',
                'SetIdx'
                'RewardPulses', 
                'InterTMal', 
                'DuringTMal', 
                'TrialStartTime', 
                'ResponseTime', 
                'DrinkTime', 
                'isTraining',
                'SideBias',
                'BetweenTrialTime',
                'SetStr',
                'SetUpdate',
                'Settings',
                'RewardTime',
                'WhatDecision',
                'wheel_record',
                'Include'};
        thefields = fieldnames(thisData);
        newData = struct();
        switch true
            case any(contains(thefields, 'trialTbl', 'IgnoreCase', true)) %Pass through                
%                 if numel(fieldnames(thisData.newData)) == numel(structOrder)
%                     %Check if the names are in the same order before return... but not now
%                     return %Skip the rest of this fx
%                 else
%                     fprintf("Add new reformat method \n")
%                     fprintf("Add new reformat method \n")
%                 end
                thesenames = fieldnames(thisData.newData); %Get names of current data struct
                %Rename the fields to match the desired names:
                Wrec = zeros(size(thesenames)); %also for debug, extra names are a zero
                for k = 1:numel(thesenames)
                    phrase = thesenames{k};
                    if contains(thesenames{k}, 'Rec', 'IgnoreCase',true) %Remove the 'Rec' from the name to search the other list of names:
                        phrase = cell2mat(split(thesenames{k}, 'Rec'));
                    end
                    w = matches(structOrder, phrase, "IgnoreCase",true);
                    if all(w==0)
                        w = contains(structOrder, phrase(1:5), "IgnoreCase",true);
                    end
                    if isa(thisData.newData.(thesenames{k}), 'int8') %The random level function was outpitting int8, which messes up analysis code.
                        newData.(structOrder{w}) = double(thisData.newData.(thesenames{k}));
                    else
                        try %Fails for wheel_record
                             newData.(structOrder{w}) = thisData.newData.(thesenames{k});
                             Wrec(k) = find(w);
                        catch err
                            try
                                unwrapErr(err)
                            catch
                                fprintf([phrase ' ' num2str(find(w)) '.  ' ]) %for debug
                                unwrapErr(err)
                            end
                        end
                    end
                end
                if isfield(thisData.newData, 'wheel_record')
                    newData.wheel_record = thisData.newData.wheel_record;
                end
                namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
%                 for i = namesNotPresent' %Add empty zero vectors for missing fields
%                     newData.(i{:}) = zeros(size(newData.CodedChoice));
%                 end
            case any(contains(thefields, 'newData', 'IgnoreCase', true)) && any(contains(thefields, 'Settings', 'IgnoreCase', true))
                try
                [~,n] = size(thisData.data);
                end
                switch true
                    case numel(thefields) == 2
                        thesenames = fieldnames(thisData.newData); %Get names of current data struct
                        if all(matches(thesenames, structOrder))
                            newData = thisData.newData;
                            return
                        elseif ~all(matches(thesenames, structOrder))
                            %Rename the fields to match the desired names:
                            Wrec = zeros(size(thesenames));
                            for k = 1:numel(thesenames)
                                phrase = thesenames{k};
                                if contains(thesenames{k}, 'Rec', 'IgnoreCase',true) %Remove the 'Rec' from the name to search the other list of names:
                                    phrase = cell2mat(split(thesenames{k}, 'Rec'));
                                end
                                w = matches(structOrder, phrase, "IgnoreCase",true);
                                if all(w==0)
                                    w = contains(structOrder, phrase(1:5), "IgnoreCase",true);
                                end
                                %fprintf([phrase ' ' num2str(find(w)) '.  ' ]) %for debug
                                if isa(thisData.newData.(thesenames{k}), 'int8') %The random level function was outpitting int8, which messes up analysis code.
                                    newData.(structOrder{w}) = double(thisData.newData.(thesenames{k}));
                                else
                                    newData.(structOrder{w}) = thisData.newData.(thesenames{k});
                                end
                                Wrec(k) = find(w);
                            end
                            namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
                            for i = namesNotPresent' %Add empty zero vectors for missing fields
                                newData.(i{:}) = zeros(size(newData.CodedChoice));
                            end
                        end
                    case numel(thefields) == 3
                        thesenames = fieldnames(thisData.newData); %Get names of current data struct
                        %Rename the fields to match the desired names:
                        Wrec = zeros(size(thesenames)); %also for debug, extra names are a zero
                        for k = 1:numel(thesenames)
                            phrase = thesenames{k};
                            if contains(thesenames{k}, 'Rec', 'IgnoreCase',true) %Remove the 'Rec' from the name to search the other list of names:
                                phrase = cell2mat(split(thesenames{k}, 'Rec'));
                            end
                            w = matches(structOrder, phrase, "IgnoreCase",true);
                            if all(w==0)
                                w = contains(structOrder, phrase(1:5), "IgnoreCase",true);
                            end
                            if isa(thisData.newData.(thesenames{k}), 'int8') %The random level function was outpitting int8, which messes up analysis code.
                                newData.(structOrder{w}) = double(thisData.newData.(thesenames{k}));
                            else
                                try %Fails for wheel_record
                                     newData.(structOrder{w}) = thisData.newData.(thesenames{k});
                                     Wrec(k) = find(w);
                                catch err
                                    try
                                        newData.wheel_record = thisData.newData.wheel_record;
                                    catch
                                        fprintf([phrase ' ' num2str(find(w)) '.  ' ]) %for debug
                                        unwrapErr(err)
                                    end
                                end
                            end
                        end
                        namesNotPresent = structOrder(~matches(structOrder, fieldnames(newData), "IgnoreCase",true));
                        for i = namesNotPresent'
                            newData.(i{:}) = zeros(size(newData.CodedChoice));
                        end
                    case n == 15
                        thesenames = { %Names of the data
                            'TimeStamp', 
                            'Score', 
                            'Level', 
                            'isLeftTrial', 
                            'CodedChoice', 
                            'RewardPulses', 
                            'InterTMal', 
                            'DuringTMal', 
                            'trialstarttime', 
                            'ResponseTime', 
                            'DrinkTime', 
                            'BetweenTrialtime',
                            'sideBias'
                            'SetIdx', 
                            'isTraining'};
                        for row = 1:n
                            newData.(thesenames{row}) = double(thisData.newData(:,row));
                        end
                        namesNotPresent = structOrder(~matches(structOrder, thesenames, "IgnoreCase",true));
                        for i = namesNotPresent'
                            newData.(i{:}) = zeros(size(newData.CodedChoice));
                        end
                    case n == 9
                        thesenames = {
                        'TimeStamp', 
                        'Score', 
                        'Level', 
                        'ResponseTime', 
                        'isLeftTrial', 
                        'CodedChoice'
                        'RewardPulses', 
                        'InterTMal',
                        'DuringTMal'};
                    case n == 13
                        thesenames = { %Names of the data
                            'TimeStamp', 
                            'Score', 
                            'Level', 
                            'isLeftTrial', 
                            'CodedChoice', 
                            'RewardPulses', 
                            'InterTMal', 
                            'DuringTMal', 
                            'trialstarttime', 
                            'ResponseTime', 
                            'DrinkTime', 
                            'SetIdx', 
                            'isTraining'};
                    otherwise
                        fprintf("Add new reformat method \n")
                        fprintf("Add new reformat method \n")
                end
            case any(contains(thefields, 'RepairedBehaviorData', 'IgnoreCase', true)) && all(~contains(thefields, 'Settings', 'IgnoreCase', true))
                %In this format, every trial is a column (Repaired Behavior Data) and Settings were not yet saved
                [m,~] = size(thisData.RepairedBehaviorData);
                if all(thisData.RepairedBehaviorData(1,:) - thisData.RepairedBehaviorData(4,:)<1) % Row 4 used to be a second timestamp, for some reason
                   thisData.RepairedBehaviorData(4,:) = 0; %Remove the erroneous response time values if they are erroneous
                end
                if any(thisData.RepairedBehaviorData(5,:)==-1)
                   thisData.RepairedBehaviorData(:,thisData.RepairedBehaviorData(5,:)==-1) = []; %There was a time when the program would add 2 columns for every trial.
                end
                switch true
                    case m == 7
                        thesenames = {
                        'TimeStamp', 
                        'Score', 
                        'Level', 
                        'ResponseTime', 
                        'isLeftTrial', 
                        'RewardPulses', 
                        'RewardTime'};
                    case m == 5
                        thesenames = {
                        'TimeStamp', 
                        'Score', 
                        'Level', 
                        'ResponseTime', 
                        'isLeftTrial'};
                    otherwise
                        fprintf("Add new reformat method \n")
                        fprintf("Add new reformat method \n")
                end
                for row = 1:m %Put the old data into a new structure as named vectors
                    newData.(thesenames{row}) = double(thisData.RepairedBehaviorData(row,:))'; %Save as column vectors instead of rows
                end
                namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
                for i = namesNotPresent' %Add empty zero vectors for missing fields
                    newData.(i{:}) = zeros(size(newData.Score));
                end
            case any(contains(thefields, 'data'))
                [~,n] = size(thisData.data);
                switch true
                    case n == 9
                        thesenames = {
                        'TimeStamp', 
                        'Score', 
                        'Level', 
                        'ResponseTime', 
                        'isLeftTrial', 
                        'CodedChoice'
                        'RewardPulses', 
                        'InterTMal',
                        'DuringTMal'};
                    case n == 13
                        thesenames = { %Names of the data
                            'TimeStamp', 
                            'Score', 
                            'Level', 
                            'isLeftTrial', 
                            'CodedChoice', 
                            'RewardPulses', 
                            'InterTMal', 
                            'DuringTMal', 
                            'trialstarttime', 
                            'ResponseTime', 
                            'DrinkTime', 
                            'SetIdx', 
                            'isTraining'};
                    otherwise
                        fprintf("Add new reformat method \n")
                        fprintf("Add new reformat method \n")
                end
                for col = 1:n %Put the old data into a new structure as named vectors
                    newData.(thesenames{col}) = double(thisData.data(:,col)); %Save to the structure
                end
                namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
                for i = namesNotPresent' %Add empty zero vectors for missing fields
                    newData.(i{:}) = zeros(size(newData.Score));
                end
                % Data saved as: ["Timestamp", 'Score', 'Difficulty', 'ResponseTime', 'isLeftTrial', 'WhatDecision', 'RewardPulses', 'InterTMal', 'DuringTMal']
            case all(~contains(thefields, 'data')) && any(contains(thefields, 'RepairedBehaviorData', 'IgnoreCase', true)) && any(contains(thefields, 'Settings', 'IgnoreCase', true))
                [m,~] = size(thisData.RepairedBehaviorData);
                if all(thisData.RepairedBehaviorData(1,:) - thisData.RepairedBehaviorData(4,:)<1) % Row 4 used to be a second timestamp, for some reason
                   thisData.RepairedBehaviorData(4,:) = 0; %Remove the erroneous response time values if they are erroneous
                end
                if any(thisData.RepairedBehaviorData(5,:)==-1)
                   thisData.RepairedBehaviorData(:,thisData.RepairedBehaviorData(5,:)==-1) = []; %There was a time when the program would add 2 columns for every trial.
                end
                switch true
                    case m == 6
                        thesenames = {
                        'TimeStamp', 
                        'Score', 
                        'Level', 
                        'ResponseTime', 
                        'RewardPulses', 
                        'RewardTime'};
                    case m == 7
                        thesenames = {
                        'TimeStamp', 
                        'Score', 
                        'Level', 
                        'ResponseTime', 
                        'isLeftTrial', 
                        'RewardPulses', 
                        'RewardTime'};
                    otherwise
                        fprintf("Add new reformat method \n")
                        fprintf("Add new reformat method \n")
                end
                for row = 1:m %Put the old data into a new structure as named vectors
                    newData.(thesenames{row}) = double(thisData.RepairedBehaviorData(row,:))'; %Save as column vectors instead of rows
                end
                namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
                for i = namesNotPresent' %Add empty zero vectors for missing fields
                    newData.(i{:}) = zeros(size(newData.Score));
                end
            case numel(thefields) == 1 %In this format, every trial is a column (Repaired Behavior Data), % The program has crashed, so settings are not saved and are in the filename
                thesenames = {
                    'TimeStamp', 
                    'Score', 
                    'Level', 
                    'ResponseTime', 
                    'isLeftTrial', 
                    'RewardPulses', 
                    'RewardTime'};
                [m,~] = size(thisData.RepairedBehaviorData);
                for row = 1:m %Put the old data into a new structure as named vectors
                    newData.(thesenames{row}) = double(thisData.RepairedBehaviorData(row,:));
                end
                namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
                for i = namesNotPresent' %Add empty zero vectors for missing fields
                    newData.(i{:}) = zeros(size(thisData.RepairedBehaviorData));
                end
                names = fieldnames(newData);
                for t = names' %Transpose into columns to make the table later
                    newData.(t{:}) = newData.(t{:})';
                end
                %Reorder the fields according to structOrder
                ID = zeros(size(structOrder));
                c = 1;
                for n = structOrder' %Find the order or the current structure in relation to the ideal
                    ID(c) = find(contains(names, n{:},"IgnoreCase",true));
                    c = c+1;
                end
                ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
                newData = orderfields(newData, ID ); %Reorder this structure to match others:
            case numel(thefields) == 2 %In this format, every trial is a column (Repaired Behavior Data)
                thesenames = {
                    'TimeStamp', 
                    'Score', 
                    'Level', 
                    'isLeftTrial', 
                    'Coded', 
                    'Pulse', 
                    'InterT', 
                    'DuringT', 
                    'trialstarttime', 
                    'ResponseTime', 
                    'DrinkTime', 
                    'SetIdx', 
                    'isTraining'};
            case any(numel(thefields) == [3 4 5 7 8 9 10]) %Pass through
                try
                    thesenames = fieldnames(thisData.newData); %Get names of current data struct
                    %Rename the fields to match the desired names:
                    Wrec = zeros(size(thesenames));
                    for k = 1:numel(thesenames)
                        phrase = thesenames{k};
                        if contains(thesenames{k}, 'Rec', 'IgnoreCase',true) %Remove the 'Rec' from the name to search the other list of names:
                            phrase = cell2mat(split(thesenames{k}, 'Rec'));
                        end
                        phrase;
                        w = matches(structOrder, phrase, "IgnoreCase",true);
                        if all(w==0)
                            w = contains(structOrder, phrase, "IgnoreCase",true);
                        end
                        newData.(structOrder{w}) = thisData.newData.(thesenames{k});
                        Wrec(k) = find(w);
                    end
                    namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
                    for i = namesNotPresent' %Add empty zero vectors for missing fields
                        newData.(i{:}) = zeros(size(newData.CodedChoice));
                    end
                    ID = zeros(size(structOrder));
                    c = 1;
                    thesenames = fieldnames(newData);
                    for n = structOrder'
                        ID(c) = find(contains(thesenames, n{:},"IgnoreCase",true), 1, "last"); %[n, ID(c)] %for debug
                        c = c+1;
                    end
                    ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
                    newData = orderfields(newData, ID ); %Reorder this structure to match others:
                catch err
                    unwrapErr(err)
                end
            case numel(thefields) == 6 % new data format method as of BB 4.45. In this format, every trial is a row (data)
                try
                    [~,n] = size(thisData.data);
                catch
                    thisData.data = thisData.newData;
                    [~,n] = size(thisData.newData);
                end
                switch true
        %             case isfield(thisData, 'newData')
                    % % Pass through:
        %                 %                [    1        2      3         4                     5                    6                  7                        8                         9                    10                   11                     12           13      14    15 ]
        %                 % Data saved as: [Timestamp' Score' Level' isLeftTrial' [this.what_decision_record]' RewardPulses' [this.interPuffRecord]' [this.duringPuffRecord]' [this.betweenTrialsRecord]' ResponseTime'  [this.drinkDwellTimeRecord]' BetweenTrials  SideBias SetIdx' T' ]
        %                if numel(fieldnames(thisData.newData)) > 10
        %                    newData = thisData.newData;
        %                else
        %                     dataMethod = 4;
        %                     intermediate = thisData.newData;
        %                     intermediate(:,[5 13]) = [];
        %                end
                    case n == 1
                        try
                            thesenames = fieldnames(thisData.newData); %Get names of current data struct
                            %Rename the fields to match the desired names:
                            Wrec = zeros(size(thesenames));
                            for k = 1:numel(thesenames)
                                phrase = thesenames{k};
                                if contains(thesenames{k}, 'Rec', 'IgnoreCase',true) %Remove the 'Rec' from the name to search the other list of names:
                                    phrase = cell2mat(split(thesenames{k}, 'Rec'));
                                end
                                phrase;
                                w = matches(structOrder, phrase, "IgnoreCase",true);
                                if all(w==0)
                                    w = contains(structOrder, phrase, "IgnoreCase",true);
                                end
                                newData.(structOrder{w}) = thisData.newData.(thesenames{k});
                                Wrec(k) = find(w);
                            end
                            namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
                            for i = namesNotPresent' %Add empty zero vectors for missing fields
                                newData.(i{:}) = zeros(size(newData.CodedChoice));
                            end
                            ID = zeros(size(structOrder));
                            c = 1;
                            thesenames = fieldnames(newData);
                            for n = structOrder'
                                ID(c) = find(contains(thesenames, n{:},"IgnoreCase",true), 1, "last"); %[n, ID(c)] %for debug
                                c = c+1;
                            end
                            ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
                            newData = orderfields(newData, ID ); %Reorder this structure to match others:
                        catch err
                            unwrapErr(err)
                        end
                    case isempty(thisData.data) || n == 0
                        fprintf("Add new reformat method \n")
                        fprintf("Add new reformat method \n")
                    case n == 8 %For a few days the data was recorded differently as I figured out some stuff with the new data format
                        thesenames = {
                            'TimeStamp', 
                            'Score', 
                            'Level',  
                            'isLeftTrial', 
                            'CodedChoice', 
                            'RewardPulses',  
                            'SetIdx', 
                            'IsTraining'};
                        for row = 1:n
                            newData.(thesenames{row}) = double(thisData.data(:,row));
                        end
                        namesNotPresent = structOrder(~matches(structOrder, thesenames, "IgnoreCase",true));
                        for i = namesNotPresent'
                            newData.(i{:}) = zeros(size(newData.CodedChoice));
                        end
                        newData.SetStr = thisData.SetStr;
                        newData.SetUpdateRec = cell2mat(thisData.UpdatedWhen);
                        ID = zeros(size(structOrder));
                        c = 1;
                        thesenames = fieldnames(newData);
                        for n = structOrder'
                            ID(c) = find(contains(thesenames, n{:},"IgnoreCase",true), 1, "last");
                            c = c+1;
                        end
                        ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
                        newData = orderfields(newData, ID ); %Reorder this structure to match others:
                    case n == 9 %First time the data structure was saved it was missing some stuff:
                       fprintf("Add new reformat method \n")
                       fprintf("Add new reformat method \n")
                        % Data saved as: ["Timestamp", 'Score', 'Difficulty', 'ResponseTime', 'isLeftTrial', 'WhatDecision', 'RewardPulses', 'InterTMal', 'DuringTMal']
                    case n == 12
                        %                [    1        2          3              4              5             6             7               8                  9            10      11     12  ]
                        % Data saved as: [Timestamp' Score' DifficultyLevel' ResponseTime' isLeftTrial' what_decision' RewardPulses RewardValveOpenTime  SettingsIndex  ((unsure about remaining)) ]
                        thesenames = {
                            'TimeStamp', 
                            'Score', 
                            'Level',  
                            'ResponseTime',
                            'isLeftTrial', 
                            'CodedChoice', 
                            'RewardPulses',  
                            'RewardTime', 
                            'SetIdx', 
                            'IsTraining', 
                            'InterT', 
                            'DuringT'};
                        for row = 1:n
                            newData.(thesenames{row}) = double(thisData.data(:,row));
                        end
                        namesNotPresent = structOrder(~matches(structOrder, thesenames, "IgnoreCase",true));
                        for i = namesNotPresent'
                            newData.(i{:}) = zeros(size(newData.CodedChoice));
                        end
                        newData.SetStr = thisData.SetStr;
                        newData.SetUpdateRec = cell2mat(thisData.UpdatedWhen);
                        thesenames = fieldnames(newData);
                        c = 1;
                        ID = zeros(size(structOrder));
                        for n = structOrder'
                            ID(c) = find(contains(thesenames, n{:},"IgnoreCase",true));
                            c = c+1;
                        end
                        ID = [ID setdiff(1:numel(thesenames), ID)];
                        newData = orderfields(newData, ID );
                    case n == 13
                        %                [    1        2          3              4                     5                    6                  7                        8                         9                    10                   11                  12   13 ]
                        % Data saved as: [Timestamp' Score' DifficultyLevel' isLeftTrial' [this.what_decision_record]' RewardPulses' [this.interPuffRecord]' [this.duringPuffRecord]' [this.betweenTrialsRecord]' ResponseTime'  [this.drinkDwellTimeRecord]' SetIdx' T']                    
        % 3  Timestamp
        % 4  Score
        % 5  Level
        % 6  isLeftTrial
        % 7  WhatDecision
        %    CodedChoice
        % 8  RewardPulses
        % 9  InterTMal
        % 10 DuringTMal
        % 11 Trial Start Time / Between trials time
        % 12 ResponseTime
        % 13 drinkDwellTime
        %    Between Trial time (remove if its all zeros)
        %    SetUpdateRec (this is Updated When)
        % 14 SetIdx (which settings label to use if there were changes
        % 15 isTraining (these bins are removed when counting days to master)
        %    SideBias (replace with zeros)
        %    Wheel Record (remove this from the newData structure and put in parent structure)
        %    SetStr
                        thesenames = { %Names of the data
                            'TimeStamp', 
                            'Score', 
                            'Level', 
                            'isLeftTrial', 
                            'CodedChoice', 
                            'RewardPulses', 
                            'InterTMal', 
                            'DuringTMal', 
                            'trialstarttime', 
                            'ResponseTime', 
                            'DrinkTime', 
                            'SetIdx', 
                            'isTraining'};
                        for row = 1:n
                            newData.(thesenames{row}) = double(thisData.data(:,row));
                        end
                        namesNotPresent = structOrder(~matches(structOrder, thesenames));
                        for i = namesNotPresent'
                            newData.(i{:}) = zeros(size(newData.CodedChoice));
                        end
                        newData.SetStr = thisData.SetStr;
                        newData.SetUpdateRec = cell2mat(thisData.UpdatedWhen);
                        names = fieldnames(newData);
                        ID = [];
                        c = 1;
                        for n = structOrder' %Find the order or the current structure in relation to the ideal
                            n
                            ID(c) = find(contains(names, n{:},"IgnoreCase",true), 1, "last")
                            c = c+1;
                        end
                        ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
                        newData = orderfields(newData, ID ); %Reorder this structure to match others:
                    case n == 15
                        thesenames = { %Names of the data
                            'TimeStamp', 
                            'Score', 
                            'Level', 
                            'isLeftTrial', 
                            'CodedChoice', 
                            'RewardPulses', 
                            'InterTMal', 
                            'DuringTMal', 
                            'trialstarttime', 
                            'ResponseTime', 
                            'DrinkTime', 
                            'BetweenTrialtime',
                            'sideBias'
                            'SetIdx', 
                            'isTraining'};
                        for row = 1:n
                            newData.(thesenames{row}) = double(thisData.data(:,row));
                        end
                        namesNotPresent = structOrder(~matches(structOrder, thesenames, "IgnoreCase",true));
                        for i = namesNotPresent'
                            newData.(i{:}) = zeros(size(newData.CodedChoice));
                        end
                end
            otherwise
                fprintf("Add new reformat method \n")
                fprintf("Add new reformat method \n")
        end
        if all(newData.Level < 1) %Check level formatting
            newData.Level = double(newData.Level*10);
        end
        try
            if any(any(newData.Score == [0.2 0.5 0.8]')) %Check score formatting
                newData.Score(newData.Score == 0.8) = 1;
                newData.Score(newData.Score == 0.5) = 0;
                newData.Score(newData.Score == 0.2) = 2;
            end
        catch
        end
        if ~all(matches(fieldnames(newData), structOrder)) %Reorder the fields according to structOrder (code should be the same for all):
            ID = zeros(size(structOrder'));
            c = 1;
            names = fieldnames(newData);
            for n = structOrder' %Find the order or the current structure in relation to the ideal
                try
                ID(c) = find(contains(names, n{:},"IgnoreCase",true), 1, "last"); %Add "last" argument to find because of CodedChoice and WhatDecision
                catch err
                    unwrapErr(err)
                end
                c = c+1;
            end
            ID = [ID setdiff(1:numel(names), ID)]; %Fill in missing numbers for fields not contained in the ideal order
            newData = orderfields(newData, ID ); %Reorder this structure to match others:
        end
        try
            try
                if isfield(thisData, 'Old_Settings')
                    newData.Settings = [thisData.Settings cell2mat(thisData.Old_Settings)];
                elseif isfield(thisData, 'Settings')
                    newData.Settings = thisData.Settings;
                end
                if isfield(newData.Settings, 'encoder')
                    newData.Settings = rmfield(newData.Settings, 'encoder');
                end
            catch %Fails if there are no settings (Program crashed)
                try
                    O = cell2mat(thisData.Old_Settings);
                catch err
                    unwrapErr(err)
                end
                f1 = fieldnames(thisData.Settings);
                f2 = fieldnames(O);
                O = rmfield(O, f2(~matches(f2, f1)));
                if isfield(O, 'encoder')
                    newData.Settings = rmfield(O, 'encoder');
                end
                newData.Settings = [thisData.Settings O];
            end
            [newData.SetStr, newData.Include] = LabelSettingsandMakeData(newData.Settings);
            if numel(newData.Settings) ~= numel(newData.SetStr)
                disp("Not enough settings")
            end
            names = fieldnames(newData);
            for r = find(cellfun(@isrow, struct2cell(newData)'))
                try
                    newData.(names{r}) = newData.(names{r})';
                end
            end
        catch err
            newData.SetStr = "";
            newData.SetIdx = ones(size(newData.TimeStamp));
            newData.Include = 0;
            unwrapErr(err)
        end
    catch err
        unwrapErr(err)
    end
end
function [SetVector, IVector] = LabelSettingsandMakeData(Settings)
%I is include, as in include this trial in the performance count
    SetVector = string();
    IVector = nan(size(Settings));
    try
        howBig = numel(Settings);
        for i = 1:howBig
            if ~isfield(Settings(i), 'Stimulus_side')
                continue
            end
            [SetVector(i), IVector(i)] = structureSettings(Settings(i));
        end
    catch err
        unwrapErr(err)
    end
end
function [Set, I] = structureSettings(SettingsIn)
    SetStr = ""; %Get the label for the settings (to go on top of the performance scatter)
    Include = 0;
    if isfield(SettingsIn, 'Stimulus_side')
        switch SettingsIn.Stimulus_side %Settings are stored in the Settings structure, copied from BB when saving data.
            case 1
                SetStr = strcat(SetStr, '*');
                Include = 1;
            case 2
                SetStr = strcat(SetStr, 'L');
                Include = 0;
            case 3
                SetStr = strcat(SetStr, 'R');
                Include = 0;
            case 4
                SetStr = strcat(SetStr, 'aRp');
                Include = 1;
            case 5
                SetStr = strcat(SetStr, 'aRn');
                Include = 0;
            case 6
                SetStr = strcat(SetStr, 'SB');
                Include = 1;
            case 7
                SetStr = strcat(SetStr, 's*');
                Include = 1;
            case 8
                SetStr = strcat(SetStr, 'K');
                Include = 1;
        end
    end
    if isfield(SettingsIn, 'TrainingChoices') & SettingsIn.TrainingChoices ~=3 %BBPractice, would show two correct stimuli. I was using this to get rid of side biases, by showing the mice that both sides reward water always.
        switch SettingsIn.TrainingChoices
            case 1
                SetStr = strcat(SetStr, 'Tuw');
            case 2
                SetStr = strcat(SetStr, 'nToc'); %Nose only correct or timeout
            case 3
                SetStr = strcat(SetStr, '*'); %this code will never be reached=
            case 4
                SetStr = strcat(SetStr, 'P');
            case 5
                SetStr = strcat(SetStr, 'wT1');
            case 6
                SetStr = strcat(SetStr, 'wT3');
            case 7
                SetStr = strcat(SetStr, 'wT2oc');
            case 8
                SetStr = strcat(SetStr, 'T1');
            case 9
                SetStr = strcat(SetStr, 'T2');
            case 10
                SetStr = strcat(SetStr, 'T3');
        end
        if SettingsIn.TrainingChoices ~=3
            Include = 0;
        end
    end
    if isfield(SettingsIn, 'Repeat_wrong') & SettingsIn.Repeat_wrong
        SetStr = strcat(SetStr, 'rw');
        Include = 0;
    end
    if  isfield(SettingsIn, 'Prompt') & SettingsIn.Prompt
        SetStr = strcat(SetStr, 'P');
        Include = 0;
    end
    %Special Training Settings:
    if isfield(SettingsIn, 'Unlimited') & SettingsIn.Unlimited
        SetStr = strcat(SetStr, 'Tuw'); %Training unlimited rewards
        Include = 0;
    end
    if isfield(SettingsIn, 'Stimulus_side') & SettingsIn.Stimulus_type == 12 %BBPractice, would show two correct stimuli. I was using this to get rid of side biases, by showing the mice that both sides reward water always.
        SetStr = strcat(SetStr, 'T');
        Include = 0;
    end
    %Airpuff?
    if isfield(SettingsIn, 'Air_Puff_Penalty') & SettingsIn.Air_Puff_Penalty
        SetStr = strcat(SetStr, 'A');
    end
    Set = SetStr;
    I = Include;
end

function [newData] = WheelRearrangeData(thisData)
try
%These are all of the possible fields in the structure. Fill in as many as possible:
        structOrder = {
            'TimeStamp', 
            'Score', 
            'Level', 
            'isLeftTrial',
            'CodedChoice',
            'RewardPulses', 
            'InterTMal', 
            'DuringTMal', 
            'TrialStartTime', 
            'ResponseTime', 
            'DrinkTime', 
            'SetIdx'
            'isTraining',
            'SideBias',
            'BetweenTrialTime',
            'SetStr',
            'SetUpdateRec',
            'Settings',
            'RewardTime',
            'WhatDecision'};
% 3  Timestamp
% 4  Score
% 5  Level
% 6  isLeftTrial
% 7  WhatDecision
%    CodedChoice
% 8  RewardPulses
% 9  InterTMal
% 10 DuringTMal
% 11 Trial Start Time / Between trials time
% 12 ResponseTime
% 13 drinkDwellTime
%    Between Trial time (remove if its all zeros)
%    SetUpdateRec (this is Updated When)
% 14 SetIdx (which settings label to use if there were changes
% 15 isTraining (these bins are removed when counting days to master)
%    SideBias (replace with zeros)
%    Wheel Record (remove this from the newData structure and put in parent structure)
%    SetStr
    thefields = fieldnames(thisData);
    newData = struct();
    switch true
        case numel(thefields) == 1 %In this format, every trial is a column (Repaired Behavior Data), % The program has crashed, so settings are not saved and are in the filename
            thesenames = {
                'TimeStamp', 
                'Score', 
                'Level', 
                'ResponseTime', 
                'isLeftTrial', 
                'RewardPulses', 
                'RewardTime'};
            newData = struct();
            [m,~] = size(thisData.RepairedBehaviorData);
            for row = 1:m %Put the old data into a new structure as named vectors
                newData.(thesenames{row}) = double(thisData.RepairedBehaviorData(row,:));
            end
            namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
            for i = namesNotPresent' %Add empty zero vectors for missing fields
                newData.(i{:}) = zeros(size(thisData.RepairedBehaviorData));
            end
            names = fieldnames(newData);
            for t = names' %Transpose into columns to make the table later
                newData.(t{:}) = newData.(t{:})';
            end
            ID = [];
            c = 1;
            for n = structOrder' %Find the order or the current structure in relation to the ideal
                ID(c) = find(contains(names, n{:},"IgnoreCase",true));
                c = c+1;
            end
            ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
            newData = orderfields(newData, ID ); %Reorder this structure to match others:
        case numel(thefields) == 2 %In this format, every trial is a column (Repaired Behavior Data)
            thesenames = {
                'TimeStamp', 
                'Score', 
                'Level', 
                'isLeftTrial', 
                'Coded', 
                'Pulse', 
                'InterT', 
                'DuringT', 
                'trialstarttime', 
                'ResponseTime', 
                'DrinkTime', 
                'SetIdx', 
                'isTraining'};
    
        case any(numel(thefields) == [3 4 5 7 8 9 10]) %Pass through
            try
                thesenames = fieldnames(thisData.newData); %Get names of current data struct
                %Rename the fields to match the desired names:
                Wrec = zeros(size(thesenames));
                for k = 1:numel(thesenames)
                    phrase = thesenames{k};
                    if contains(thesenames{k}, 'Rec', 'IgnoreCase',true) %Remove the 'Rec' from the name to search the other list of names:
                        phrase = cell2mat(split(thesenames{k}, 'Rec'));
                    end
                    phrase;
                    w = matches(structOrder, phrase, "IgnoreCase",true);
                    if all(w==0)
                        w = contains(structOrder, phrase, "IgnoreCase",true);
                    end
                    newData.(structOrder{w}) = thisData.newData.(thesenames{k});
                    Wrec(k) = find(w);
                end
                namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
                for i = namesNotPresent' %Add empty zero vectors for missing fields
                    newData.(i{:}) = zeros(size(newData.CodedChoice));
                end
                ID = zeros(size(structOrder));
                c = 1;
                thesenames = fieldnames(newData);
                for n = structOrder'
                    ID(c) = find(contains(thesenames, n{:},"IgnoreCase",true), 1, "last"); %[n, ID(c)] %for debug
                    c = c+1;
                end
                ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
                newData = orderfields(newData, ID ); %Reorder this structure to match others:
            catch err
                unwrapErr(err)
            end

        
        case numel(thefields) == 6 % new data format method as of BB 4.45. In this format, every trial is a row (data)
            try
                [~,n] = size(thisData.data);
            catch
                thisData.data = thisData.newData;
                [~,n] = size(thisData.newData);
            end
            switch true
    %             case isfield(thisData, 'newData')
                % % Pass through:
    %                 %                [    1        2      3         4                     5                    6                  7                        8                         9                    10                   11                     12           13      14    15 ]
    %                 % Data saved as: [Timestamp' Score' Level' isLeftTrial' [this.what_decision_record]' RewardPulses' [this.interPuffRecord]' [this.duringPuffRecord]' [this.betweenTrialsRecord]' ResponseTime'  [this.drinkDwellTimeRecord]' BetweenTrials  SideBias SetIdx' T' ]
    %                if numel(fieldnames(thisData.newData)) > 10
    %                    newData = thisData.newData;
    %                else
    %                     dataMethod = 4;
    %                     intermediate = thisData.newData;
    %                     intermediate(:,[5 13]) = [];
    %                end
                case n == 1
                    try
                        thesenames = fieldnames(thisData.newData); %Get names of current data struct
                        %Rename the fields to match the desired names:
                        Wrec = zeros(size(thesenames));
                        for k = 1:numel(thesenames)
                            phrase = thesenames{k};
                            if contains(thesenames{k}, 'Rec', 'IgnoreCase',true) %Remove the 'Rec' from the name to search the other list of names:
                                phrase = cell2mat(split(thesenames{k}, 'Rec'));
                            end
                            phrase;
                            w = matches(structOrder, phrase, "IgnoreCase",true);
                            if all(w==0)
                                w = contains(structOrder, phrase, "IgnoreCase",true);
                            end
                            newData.(structOrder{w}) = thisData.newData.(thesenames{k});
                            Wrec(k) = find(w);
                        end
                        namesNotPresent = structOrder(~contains(structOrder, thesenames, "IgnoreCase",true));
                        for i = namesNotPresent' %Add empty zero vectors for missing fields
                            newData.(i{:}) = zeros(size(newData.CodedChoice));
                        end
                        ID = zeros(size(structOrder));
                        c = 1;
                        thesenames = fieldnames(newData);
                        for n = structOrder'
                            ID(c) = find(contains(thesenames, n{:},"IgnoreCase",true), 1, "last"); %[n, ID(c)] %for debug
                            c = c+1;
                        end
                        ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
                        newData = orderfields(newData, ID ); %Reorder this structure to match others:
                    catch err
                        unwrapErr(err)
                    end
                case isempty(thisData.data) || n == 0
                case n == 8 %For a few days the data was recorded differently as I figured out some stuff with the new data format
                    thesenames = {
                        'TimeStamp', 
                        'Score', 
                        'Level',  
                        'isLeftTrial', 
                        'CodedChoice', 
                        'RewardPulses',  
                        'SetIdx', 
                        'IsTraining'};
                    for row = 1:n
                        newData.(thesenames{row}) = double(thisData.data(:,row));
                    end
                    namesNotPresent = structOrder(~matches(structOrder, thesenames, "IgnoreCase",true));
                    for i = namesNotPresent'
                        newData.(i{:}) = zeros(size(newData.CodedChoice));
                    end
                    newData.SetStr = thisData.SetStr;
                    newData.SetUpdateRec = cell2mat(thisData.UpdatedWhen);
                    ID = zeros(size(structOrder));
                    c = 1;
                    thesenames = fieldnames(newData);
                    for n = structOrder'
                        ID(c) = find(contains(thesenames, n{:},"IgnoreCase",true), 1, "last");
                        c = c+1;
                    end
                    ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
                    newData = orderfields(newData, ID ); %Reorder this structure to match others:
                case n == 9 %First time the data structure was saved it was missing some stuff:
                    % Data saved as: ["Timestamp", 'Score', 'Difficulty', 'ResponseTime', 'isLeftTrial', 'WhatDecision', 'RewardPulses', 'InterTMal', 'DuringTMal']

                case n == 12
                    %                [    1        2          3              4              5             6             7               8                  9            10      11     12  ]
                    % Data saved as: [Timestamp' Score' DifficultyLevel' ResponseTime' isLeftTrial' what_decision' RewardPulses RewardValveOpenTime  SettingsIndex  ((unsure about remaining)) ]
                    thesenames = {
                        'TimeStamp', 
                        'Score', 
                        'Level',  
                        'ResponseTime',
                        'isLeftTrial', 
                        'CodedChoice', 
                        'RewardPulses',  
                        'RewardTime', 
                        'SetIdx', 
                        'IsTraining', 
                        'InterT', 
                        'DuringT'};
                    for row = 1:n
                        newData.(thesenames{row}) = double(thisData.data(:,row));
                    end
                    namesNotPresent = structOrder(~matches(structOrder, thesenames, "IgnoreCase",true));
                    for i = namesNotPresent'
                        newData.(i{:}) = zeros(size(newData.CodedChoice));
                    end
                    newData.SetStr = thisData.SetStr;
                    newData.SetUpdateRec = cell2mat(thisData.UpdatedWhen);
                    thesenames = fieldnames(newData);
                    c = 1;
                    ID = zeros(size(structOrder));
                    for n = structOrder'
                        ID(c) = find(contains(thesenames, n{:},"IgnoreCase",true));
                        c = c+1;
                    end
                    ID = [ID setdiff(1:numel(thesenames), ID)];
                    newData = orderfields(newData, ID );
                case n == 13
                    %                [    1        2          3              4                     5                    6                  7                        8                         9                    10                   11                  12   13 ]
                    % Data saved as: [Timestamp' Score' DifficultyLevel' isLeftTrial' [this.what_decision_record]' RewardPulses' [this.interPuffRecord]' [this.duringPuffRecord]' [this.betweenTrialsRecord]' ResponseTime'  [this.drinkDwellTimeRecord]' SetIdx' T']
                    
    % 3  Timestamp
    % 4  Score
    % 5  Level
    % 6  isLeftTrial
    % 7  WhatDecision
    %    CodedChoice
    % 8  RewardPulses
    % 9  InterTMal
    % 10 DuringTMal
    % 11 Trial Start Time / Between trials time
    % 12 ResponseTime
    % 13 drinkDwellTime
    %    Between Trial time (remove if its all zeros)
    %    SetUpdateRec (this is Updated When)
    % 14 SetIdx (which settings label to use if there were changes
    % 15 isTraining (these bins are removed when counting days to master)
    %    SideBias (replace with zeros)
    %    Wheel Record (remove this from the newData structure and put in parent structure)
    %    SetStr
                    thesenames = { %Names of the data
                        'TimeStamp', 
                        'Score', 
                        'Level', 
                        'isLeftTrial', 
                        'CodedChoice', 
                        'RewardPulses', 
                        'InterTMal', 
                        'DuringTMal', 
                        'trialstarttime', 
                        'ResponseTime', 
                        'DrinkTime', 
                        'SetIdx', 
                        'isTraining'};
                    for row = 1:n
                        newData.(thesenames{row}) = double(thisData.data(:,row));
                    end
                    namesNotPresent = structOrder(~matches(structOrder, thesenames));
                    for i = namesNotPresent'
                        newData.(i{:}) = zeros(size(newData.CodedChoice));
                    end
                    newData.SetStr = thisData.SetStr;
                    newData.SetUpdateRec = cell2mat(thisData.UpdatedWhen);
                    names = fieldnames(newData);
                    ID = [];
                    c = 1;
                    for n = structOrder' %Find the order or the current structure in relation to the ideal
                        n
                        ID(c) = find(contains(names, n{:},"IgnoreCase",true), 1, "last")
                        c = c+1;
                    end
                    ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
                    newData = orderfields(newData, ID ); %Reorder this structure to match others:
                case n == 15
                    thesenames = { %Names of the data
                        'TimeStamp', 
                        'Score', 
                        'Level', 
                        'isLeftTrial', 
                        'CodedChoice', 
                        'RewardPulses', 
                        'InterTMal', 
                        'DuringTMal', 
                        'trialstarttime', 
                        'ResponseTime', 
                        'DrinkTime', 
                        'BetweenTrialtime',
                        'sideBias'
                        'SetIdx', 
                        'isTraining'};
                    for row = 1:n
                        newData.(thesenames{row}) = double(thisData.data(:,row));
                    end
                    namesNotPresent = structOrder(~matches(structOrder, thesenames, "IgnoreCase",true));
                    for i = namesNotPresent'
                        newData.(i{:}) = zeros(size(newData.CodedChoice));
                    end
                    newData.SetStr = thisData.SetStr;
                    newData.SetUpdateRec = cell2mat(thisData.UpdatedWhen);
                    ID = zeros(size(structOrder));
                    c = 1;
                    thesenames = fieldnames(newData);
                    for n = structOrder'
                        ID(c) = find(contains(thesenames, n{:},"IgnoreCase",true), 1, "last");
                        c = c+1;
                    end
                    ID = [ID setdiff(1:numel(thesenames), ID)]; %Fill in missing numbers for fields not contained in the ideal order
                    newData = orderfields(newData, ID ); %Reorder this structure to match others:
            end
    end
    try
        newData.Settings = [thisData.Settings cell2mat(thisData.Old_Settings)]; %smaller to save data as a structure with many values, rather than many structures
        if isfield(newData.Settings, 'encoder')
            newData.Settings = rmfield(newData.Settings, 'encoder');
        end
    end
catch err
    unwrapErr(err)
end
end
