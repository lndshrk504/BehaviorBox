classdef BehaviorBoxData < handle
    % 12.13.2023 Will Snyder
    %====================================================================
    %Data class
    %This Class stores all the data during training, and analyzes the
    % group data in analysis.
    %AddStimEvent() as interface logs the times the stimulus was presented
    %The input data is then logged in time and stored.
    %Get functions are used to covert that data to averages, performance
    %matrices, activity rates and others which then get plotted in the GUI.
    % Small_Bin_Size: divides # of trials in each data set into Small_Bins
    % (multiples of 10 are preferred)
    %This class is called by BehaviorBoxSuper/Nose/Wheel
    %THIS FILE IS PART OF A SET OF FILES CONTAINING:
    %BehaviorBox.mlapp
    %BehaviorBoxWheel.m OR %BehaviorBoxNose.m
    %BehaviorBoxData.m
    %BehaviorBoxVisualStimulus.m
    % Optional and currently unused files:
    %BehaviorBoxSuper.m
    %BehaviorBoxSub2.m
    %BehaviorBoxVisualGratingObject.m
    %BehaviorBoxVisualStimulusTraining.m
    %
    %   Will Snyder 12/2022
    %====================================================================
    properties
        TrainingNow=0;
        BB = []; %Trials in a big bin e.g. 40
        SB = []; %Trials in a small bin e.g. 20
        SBidx = [] %Pre made bin ID vector for analysis
        start_time; %When trial 1 stimulus first appears
        date = [];
        current_data_struct = struct();
        Inv = char;
        Inp = char;
        Sub = {};
        Str = char;
        dc = []; %Day count
        sc = 1; %Subj count
        filedir = char; %file directory
        fds; %FileDataStore
        loadedData;
        AnalyzedData;
        DayData;
        LevelHist;
        MaxLevel;
        sameday_data_struct = struct();
        trial_table = table;
        GUInum = struct();
        Settings = {};
        StimType;
        StimHistory = {};
        wheelchoice_record = {};
        Axes = struct();
        Shape_code = {'o', 's', '^', 'd', 'p', 'h', 'o', '*', 'd', 'p', 'o', 'h', '^', 'd', 'p', '*', 'o', '*', 'd', 'h'};
    end
    methods
        %constructor
        function this = BehaviorBoxData(options)
            arguments
                options.Inv (1,:) char = 'Will';
                options.Inp (1,:) char;
                options.Str (1,:) char;
                options.Sub (1,:) cell;
                options.BB double = 60;
                options.SB double = 30;
                options.load logical = 1;
                options.analyze logical = 1;
                options.plot logical = 0;
                options.find logical = 0;
            end
            addpath("fcns/")
            %Apply inputs
            this = copytoStruct(this, options);
            this.date = char(datetime("now", "Format","yyMMdd"));
            [~,~,this.SBidx] = histcounts((1:this.BB)', [1:this.SB:this.BB inf]);
            %Find subject data
            [this.filedir, this.fds] = this.GetFiles();
            if options.load
                this.loadFiles();
            end
            if ~options.find && options.analyze
                try
                    this.AnalyzeAllData();
                    if numel(this.Sub)>1
                        this.SortSubjects();
                    end
                catch err
                    unwrapErr(err)
                end
                if options.plot && isscalar(this.Sub)
                    f = this.plotLvByDayOneAxis();
                    f.Visible = 1;
                elseif options.plot
                    this.GroupData();
                end
            end
            %Make fields
            this.current_data_struct = this.new_init_data_struct();
        end
        function this = updateBBData(this, varargin)
            for pair = reshape(varargin, 2, [])
                this.(pair{1}) = pair{2};
            end
        end
        %INPUT INTERFACE FUNCTIONS ==== %log all activity here, which then gets passed to organize
        function GetStartTime(this)
            %this.start_time = clock; %Start time is after the mouse begins the first trial
            this.start_time = datetime("now");
        end
        function AddData(this, Level, isLeftTrial, WhatDecision, RewardPulses, InterTMal, DuringTMal, TrialStartTime, ResponseTime, DrinkTime, BetweenTrialTime, SideBias, SetIdx, SetStr)
            CodedChoice = convertEnum(WhatDecision);
            switch true
                case any(CodedChoice == [1 2])
                    Score = 1;
                case any(CodedChoice == [3 4])
                    Score = 0;
                case any(CodedChoice == [5 6])
                    Score = 2;
            end
            addStruct = struct('Score', Score, 'Level', Level, 'isLeftTrial', isLeftTrial, ...
                'CodedChoice', CodedChoice, 'RewardPulses', RewardPulses, 'InterTMal', InterTMal, ...
                'DuringTMal', DuringTMal, 'TrialStartTime', TrialStartTime, 'ResponseTime', ResponseTime, ...
                'DrinkTime', DrinkTime, 'BetweenTrialTime', BetweenTrialTime, 'SideBias', SideBias, ...
                'SetIdx', SetIdx, 'SetStr', SetStr);
            this.current_data_struct = this.addDataRow(addStruct);
        end
        function addStimEvent(this, ~) %Get the timestamp of when the stimulus appeared
            %this.current_data_struct.TimeStamp(end+1) = etime(clock,  this.start_time)/60; %elapsed time in minutes since starting first trial
            this.current_data_struct.TimeStamp(end+1) = minutes(datetime("now")-this.start_time);
        end
        function [data] = addDataRow(this, add) %This fx adds the data from each trial to the data_struct
            %Match the field names and concatenate data with values in add
            fold = fieldnames(this.current_data_struct);
            fnew = fieldnames(add);
            for i = fnew'
                try
                    x = i{:};
                    if isempty(add.(x))
                        continue
                    elseif isstring(add.(x))
                        try
                            this.current_data_struct.(fold{strcmpi(fold, x)}){end+1} = string(add.(x));
                        catch
                            this.current_data_struct.(fold{strcmpi(fold, x)})(end+1) = string(add.(x));
                        end
                    else
                        this.current_data_struct.(fold{strcmpi(fold, x)})(end+1) = add.(x); %horizontal concatenate
                    end
                catch err
                    unwrapErr(err)
                end
            end
            data = this.CleanData();
        end
        %Setup functions ==== %These functions help with plotting the data in the BB window
        %Load data file functions
        function [subfiledir, fds] = GetFiles(this)
            fds = [];
            subfiledir = pwd;

            if any(matches([this.Sub, this.Str], 'w', 'IgnoreCase', true))
                return
            end

            ONEMOUSE = false;
            NEW = false;

            % Construct the starting path for directory search
            startpath = fullfile(GetFilePath("Data"), this.Inv, this.Inp, '**', '*');
            dirlist = dir(startpath);
            dirlist = dirlist([dirlist.isdir] & ...
                ~contains({dirlist.name}, {'.', 'settings', 'alltime', 'Rescued'}, 'IgnoreCase',true) ...
                & contains({dirlist.name}, this.Sub, "IgnoreCase",true));

            % Attempt to group directories
            if isempty(dirlist)
                NEW = true;
            elseif isscalar(dirlist) % Just one subject
                dirPath = fullfile(dirlist.folder, dirlist.name);
                % If this.Sub is only 1 mouse's name:
                filelist = dir(fullfile(GetFilePath("Data"), this.Inv,this.Inp, '**', '*.mat'));
                filelist = filelist(contains({filelist.name}, this.Sub) & ~contains({filelist.name}, 'settings', 'IgnoreCase',true));           
                ONEMOUSE = true;
            else % A whole Group
                [~,b]=findgroups({dirlist.folder}');
                if isscalar(b)
                    dirPath = cellfun(@(x) fullfile(b{:}, x), {dirlist.name}' , 'UniformOutput', false);
                else
                    1;
                end
            end

            % Determine the action based on conditions
            if NEW
                % Handle paths based on user input and state
                subfiledir = handleNewStrain(this, dirlist);
            else ONEMOUSE % any(contains({filelist.name}, this.Sub))
                % If any files match the subject, proceed to create file datastore
                [subfiledir, fds] = this.makefiles(dirPath);
            end

            % Report found files if fds is populated
            if ~isempty(fds)
                fprintf("Found "+numel(fds.Files)+" files for "+numel(this.Sub)+" subject(s) matching user input:\n - "+cell2mat(join(this.Sub, "\n - "))+"\n")
            end

        end

        function [SUBDIR, FDS] = makefiles(this, direc)
            FDS = [];
            SUBDIR = [];
            try
                FDS = fileDatastore(direc, "ReadMode", "file" ,"ReadFcn", @readFcn, "FileExtensions", ".mat", "IncludeSubfolders",true);
                forest = cellfun(@(x) split(x,filesep), FDS.Files', 'UniformOutput', false);
                [~,this.Sub]=findgroups(cellfun(@(x) x(end-1), forest));
                [~,strains]=findgroups(cellfun(@(x) x(end-2), forest));
                this.Str = cell2mat(strains);
                if numel(this.Sub)>1
                    % Use strain folder for directory when multiple subjects
                    w = 2;
                else
                    % Use subject folder for directory
                    w = 1;
                end
                file = forest{1}(1:end-w);
                SUBDIR = fullfile(join(file(:),filesep));
            catch err
                display(err.message)
                try
                    SUBDIR = direc{:};
                    tree = split(direc, filesep);
                    this.Sub = tree(end);
                    this.Str = tree{end-1};
                catch
                end
            end
        end

        function subdirPath = handleNewStrain(this, dirlist)
            if ~isempty(this.Str)
                newpath = fullfile(GetFilePath("Data"), this.Inv, this.Inp, this.Str, this.Sub);
                actionOnFolderPresence(newpath, this.Sub);
                subdirPath = newpath;
            else
                fprintf("Indicated filepath not found - Check the file path..?\n");
                this.Str = 'New';
                newpath = fullfile(GetFilePath("Data"), this.Inv, this.Inp, 'New', this.Sub);
                this.actionOnFolderPresence(newpath, this.Sub);
                subdirPath = newpath;
            end
        end

        function actionOnFolderPresence(this, newpath, subjects)
            if isfolder(newpath)
                fprintf("Found %d subject(s) matching user input:\n - %s\n", ...
                    numel(subjects), cell2mat(join(subjects, "\n - ")));
            else
                mkdir(newpath{:});
                fprintf("New strain, folders will be created when saving data...\n");
            end
        end

        function [varargout] = loadFiles(this, options)
            arguments
                this
                % How many trials to remove from the end of each day, to accomodate for the mouse's waning attention/interest in the task
                options.CropEnd double = 30
            end
            tic
            if isempty(this.fds)
                return
            end
            try
                p = gcp("nocreate");
                if isempty(p)
                    aD = this.fds.readall("UseParallel",false);
                else
                    aD = this.fds.readall("UseParallel",true);
                end
            catch
                aD = this.fds.readall("UseParallel",false);
            end
            allData = cell(numel(aD),6);
            for i = 1:6
                allData(:,i) = cellfun(@(x) x{i}, aD, 'UniformOutput', false);
            end
            this.loadedData = allData;
            this.CombineDays();
            if nargout >= 1
                varargout{1} = allData;
            end
            fprintf("Loaded... : " + toc + " seconds.\n")
        end
        function [varargout] = CombineDays(this, options)
            arguments
                this
                options.CE double = 30
            end
            if isempty(this.loadedData)
                %fprintf(".\n")
                return
            end
            allData = this.loadedData;
            dayData = struct;
            for S = this.Sub
                try
                    name = S{:}(1:7);
                catch
                    name = S{:};
                end
                mouse = "Mouse" + name;
                w = contains(allData(:,6), name); %only needed if there are multiple subjects
                [~,days] = findgroups(cell2mat(allData(w,2))');
                dayData.((mouse)) = cell(numel(days'),4);
                % StimHist = allData(w,4);
                % EmptyIdx = cellfun('isempty', StimHist);
                % L = cellfun(@(x) x.Level ,allData(:,3) , 'UniformOutput',false);
                % L(EmptyIdx) = [];
                % StimHist(EmptyIdx) = [];
                % getLev = @(x)cellfun(@(x) size(x), x, 'UniformOutput',false);
                % Lev = cellfun(@(x) getLev(x), StimHist, 'UniformOutput', false);
                c = 0;
                for d = days
                    if d == 231117
                        1;
                    end
                    bigSession = struct;
                    sessions = struct;
                    c = c+1;
                    dayData.((mouse)){c,2} = d;
                    wD = vertcat(allData{:,2}) == d;
                    try
                        StimHist = allData{wD & w, 4};
                        sessions = [allData{wD & w ,3}];
                        %sessions.StimHist = StimHist;
                    catch %Fails for only one day, when include wasn't added correctly.
                        StimHist = allData{wD & w, 4};
                        data = allData(wD & w ,3);
                        % bigSesh = cellfun(@(x) ...
                        %     [{x.Score} {x.Level} {x.isLeftTrial} {x.CodedChoice} {x.SetIdx}], ...
                        %     allData(:,3), 'UniformOutput', true)
                        % cellfun(@(x)cell2struct(x, {'Score', 'Level', 'isLeftTrial', 'CodedChoice', 'SetIdx'}), bigSesh )
                        names = cellfun(@(x) fieldnames(x), data, 'UniformOutput', false);
                        [a, b] =findgroups(cellfun(@numel, names));
                        fullTotal = max(cellfun(@(x) numel(x), names));
                        n = setdiff(names{1}, names{2});
                        if isempty(n)
                            n = setdiff(names{2}, names{1});
                        end
                        if isempty(n)
                            try
                                oddOne = a==find(b~=fullTotal);
                                n = setdiff(names{1}, names{oddOne});
                            catch err
                                unwrapErr(err)
                            end
                        end
                        switch 1
                            case n{:} == "Include"
                                for m = find(cellfun(@(x) numel(x)~=fullTotal, names))'
                                    thisD = data{m};
                                    thisD.Include = ~thisD.isTraining;
                                    data{m} = thisD;
                                end
                            case n{:} == "wheel_record"
                                for m = find(cellfun(@(x) numel(x)~=fullTotal, names))'
                                    thisD = data{m};
                                    thisD.wheel_record = cell(numel(thisD.TimeStamp), 3);
                                    fulldata = setdiff(1:numel(data),m);
                                    nameOrder = fieldnames(data{fulldata(1)});
                                    data{m} = orderfields(thisD, nameOrder);
                                end
                            case n{:} == "Text"
                                for m = find(cellfun(@(x) numel(x)==fullTotal, names))'
                                    data{m} = rmfield(data{m}, 'Text');
                                end
                        end
                        try
                            sessions = cell2mat(data);
                        catch err
                            unwrapErr(err)
                        end
                    end
                    if all(cellfun(@isempty, {sessions.Score}))
                        continue
                    end
                    % Remove the sessions with no values for TrialNum (means
                    % training session was aborted before the first trial)
                    wEmpty = zeros(size(sessions));
                    for i = 1:numel(sessions)
                        if isempty(sessions(i).TrialNum)
                            wEmpty(i) = i;
                        end
                    end
                    wEmpty(wEmpty==0)=[];
                    sessions(wEmpty) = [];
                    for i = 2:numel(sessions)
                        numPrevSettings = sum(cellfun(@numel, {sessions(1:i-1).Settings}));
                        sessions(i).SetIdx = sessions(i).SetIdx + numPrevSettings;
                    end
                    dayData.((mouse)){c,1} = sessions;
                    %Vertcat all fields
                    for f = fieldnames(sessions)'%{'TimeStamp', 'Score', 'Level', 'isLeftTrial', 'CodedChoice', 'SetIdx'}
                        try
                            bigSession.(f{:}) = vertcat(sessions.(f{:} ) );
                        catch
                            try
                                bigSession.(f{:}) = sessions.(f{:});
                            catch err
                                unwrapErr(err)
                            end
                        end
                    end
                    %bigSession.Settings = {sessions.Settings};
                    idx = 0;
                    Include = zeros(sum(cellfun(@numel,{sessions.Settings})), 1);
                    SetStr = {zeros(sum(cellfun(@numel,{sessions.Settings})), 1)};
                    for j = {sessions.Settings}
                        sets = j{:};
                        for k = 1:numel(sets)
                            idx = idx+1;
                            [SetStr{idx}, Include(idx)] = this.structureSettings(sets(k));
                        end
                    end
                    try
                        bigSession.Include = Include(bigSession.SetIdx);
                    catch
                        warning("Sub: "+cell2mat(S)+" Day "+d+" - Rescued data found, settings info is missing");
                        bigSession.Include = ones(size(bigSession.Score)); %For any data that was rescued, there are no settings
                    end
                    bigSession.SetStr = SetStr;
                    this.current_data_struct = bigSession;
                    %bigSession = this.CleanData(IsAnalysis=1); % Crop trials
                    bigSession = this.CleanData(IsAnalysis=0); % Do not
                    bigSession.Date = repmat(d, numel(bigSession.Score),1);
                    bigSession.LvlTrialNum = zeros(numel(bigSession.Score),1); %Will be filled in later on
                    theseFirst = ["Date";
                        "TrialNum";
                        "LvlTrialNum";
                        "BigBin";
                        "SmallBin";
                        "TimeStamp";
                        "Score";
                        "Level";
                        "isLeftTrial";
                        "CodedChoice";
                        "Include"];
                    finalorder = vertcat(theseFirst, setdiff(fieldnames(bigSession), theseFirst));
                    Out = orderfields(bigSession, finalorder);
                    Out.StimulusHistory = vertcat(StimHist);
                    dayData.((mouse)){c,3} =Out;

                end
                emptyDays = cellfun(@isempty, dayData.(mouse)(:,1));
                dayData.(mouse)(emptyDays,:) = [];
            end
            this.DayData = dayData;
            this.findDayData()
            if nargout >= 1
                varargout{1} = dayData;
            end
        end
        function findDayData(this)
            if numel(this.Sub) > 1
                return
            end
            dat = struct2cell(this.DayData);
            wD = [dat{:}{:,2}] == str2double(this.date);
            if any(wD)
                this.dc = numel(dat{:}(:,1));
                this.sameday_data_struct = dat{:}{wD',1};
                fprintf("Found today's earlier data...\n")
            else
                this.dc = 1+numel(dat{:}(:,1));
            end
        end
        function [varargout] = AnalyzeAllData(this, options)
            arguments
                this
                options.CropEnd double = 30 % How many trials to remove from the end of each day, to accomodate for the mouse's waning attention/interest in the task
            end
            tic
            Out = struct;
            numSubs = size(this.Sub);
            Out.TrialTbls = cell(numSubs);
            Out.SplitTbls = cell(numSubs);
            Out.LevelTbls = cell(numSubs);
            Out.DayMM = cell(numSubs);
            Out.LevelMM = cell(numSubs);
            SC = 0;
            for S = struct2cell(this.DayData)'
                SC = SC + 1;
                data = S{:}(:,3);
                SDData = struct();
                for f = {'Date','TrialNum','LvlTrialNum','BigBin','SmallBin','TimeStamp','Score','Level','isLeftTrial','CodedChoice','Include'}
                    fn = f{:};
                    SDData.(fn) = cell2mat(cellfun(@(x)x.(fn), data, 'UniformOutput', false));
                end
                trialTbl = struct2table(SDData);
                trialTbl.Level = round(trialTbl.Level);
                trialTbl = this.getLevelTNums(trialTbl);
                Out.TrialTbls{SC} = trialTbl;
                this.trial_table = trialTbl;
                [allDates, Ds] = findgroups(trialTbl.Date');
                %Out.SplitTbls{SC} = cellfun(@SplitDays, num2cell(Ds), "UniformOutput", false);
                Out.DayMM{SC} = table;
                try
                    [G,Out.DayMM{SC}.Ds,Out.DayMM{SC}.Ls] = findgroups(trialTbl.Date, trialTbl.Level);
                    Out.DayMM{SC}.DayNums = num2cell(findgroups(Out.DayMM{SC}.Ds));
                    Out.DayMM{SC}.dayBin = splitapply(@(x){this.DayBin(x)}, [trialTbl.Score trialTbl.Level trialTbl.Date allDates'], G);
                    Out.DayMM{SC} = sortrows(Out.DayMM{SC}, {'Ls'});
                catch Err
                    unwrapErr(Err);
                end
                U_Lvs = unique(trialTbl.Level);
                [G, Lvs] = findgroups(trialTbl.Level);
                AllLevels = num2cell(1:20);
                Out.LevelTbls{SC} = cellfun(@(x){trialTbl(trialTbl.Level==x,:)}, AllLevels, "UniformOutput", true);
                % Out.LevelTbls{SC}(cellfun(@(x)size(x,1), Out.LevelTbls{SC}) == 0) This gives indices of empty levels
                this.LevelHist.LastScores = cellfun(@(x){trialTbl(trialTbl.Level==x,:).Score(end-100:end)}, AllLevels, "ErrorHandler",@errorFuncZeroCell);
                %this.LevelHist.MM = cellfun(@(x)this.LevelMMAnalysis(x), this.LevelHist.LastScores, "ErrorHandler",@errorFuncNaN);
                Out.LevelMM{SC} = cell(1, max(Lvs));
                LMM = splitapply(@(x)this.LevelMMAnalysis(x), [trialTbl.Score allDates' trialTbl.Include], G)';
                for i = 1:numel(LMM)
                    Out.LevelMM{SC}{Lvs(i)} = LMM{i};
                end
            end
            this.AnalyzedData = Out;
            this.SortSubjects();
            this.AnalyzedData.CrossTable = this.MMCross();
            this.current_data_struct = this.new_init_data_struct();
            fprintf("Analyzed... : " + toc + " seconds.\n")
            if nargout >= 1
                varargout{1} = Out;
            end
        end
        function SortSubjects(this)
            %Reorder everything in this.AnalyzedData to put Hets first, WTs last
            this.AnalyzedData.Subjects = this.Sub;
            WTs = find(contains(this.AnalyzedData.Subjects, "WT"));
            Hets = find(~contains(this.AnalyzedData.Subjects, "WT"));
            order = [Hets WTs];
            for f = fieldnames(this.AnalyzedData)'
                try
                    this.AnalyzedData.(f{:}) = this.AnalyzedData.(f{:})(order);
                catch err
                end
            end
            this.Sub = this.Sub(order);
        end
        function Out = LevelMMAnalysis(this, L)
            try
                Inc = L(L(:,1)~=2,3);
                scores = L(L(:,1)~=2,1);
                bMM = this.newMM(scores,"Type", "Big");
                sMM = this.newMM(scores,"Type", "Small", "Endpoints", 1, "FromChance", 0);
                try
                    bSD = sMM(:,2);
                catch
                    bSD = bMM;
                end
                D = L(L(:,1)~=2,2);
                XCoord = zeros(size(D));
                XCoordLevDay = zeros(size(D));
                % Binomial
                BiCDF = zeros(numel(scores),2);
                try
                    BiCDF(this.BB:numel(scores),2) = bMM;
                catch
                    BiCDF(:,2) = NaN;
                end
                tc = this.BB-1;
                for t = 1:numel(scores)
                    tc = tc + 1;
                    t0 = max(t-this.BB+1,1);
                    dataWin = scores(t0:t);
                    BiCDF(t,1) = binocdf(sum(dataWin), numel(dataWin), 0.5, 'upper');
                end
                try
                    BiCDF(:,2) = [];
                    BiCDF( 1:this.BB-1,:) = [];
                catch % Only fails when all responses are timeouts and th BiCDF vector is empty
                end
                % offset = D(1);
                DC = 0;
                for d = unique(D')
                    DC = DC + 1;
                    w = D==d;
                    x = 1:numel(D(w));
                    XCoord(w) = (d-1)+normalize(x, 'range');
                    XCoordLevDay(w) = (DC-1)+normalize(x, 'range');
                end
                if numel(scores) < this.BB
                    FIRST = [bMM bSD nan(size(bMM)) nan(size(bMM)) nan(size(bMM)) BiCDF];
                else
                    FIRST = [bMM bSD(this.BB:end) XCoord(this.BB:end) XCoordLevDay(this.BB:end) Inc(this.BB:end) BiCDF];
                end
                Names = {'bMM', 'bSD', 'XCoord', 'XCoordLevDay', 'Inc', 'BiCDF'};
                try
                    Out = {array2table(FIRST, "VariableNames", Names)};
                catch err
                    % unwrapErr(err);
                    Out = {array2table(nan(1,numel(Names)), "VariableNames", Names)};
                end
            catch Err
                unwrapErr(Err)
                if size(L,2)==1
                    Out = {[bMM bSD]};
                else
                    Out = {[NaN NaN NaN NaN]};
                end
            end
        end
        function Cross = MMCross(this)
            % Moving Mean Cross (the threshold)
            arguments
                this
            end
            OverBinomial = array2table(num2cell(zeros(20,3)), "VariableNames", {'p<0.05', 'p<0.01', 'p<0.001'});
            OverBinomial_AVG = OverBinomial;
            SUBS = this.AnalyzedData.Subjects;
            WT = contains(SUBS, 'WT');
            Het = contains(SUBS, 'Het');
            IDX = [repmat("Het", 1, sum(Het)) repmat("WT", 1, sum(WT))];
            Lev = this.AnalyzedData.LevelMM;
            for L = 1:max(cellfun(@(x) numel(x), Lev, UniformOutput=true))
                CROSS_1 = cellfun(@(x) find(x{L}{:,6} < 0.05, 1, "first")+this.BB, Lev, UniformOutput=0, ErrorHandler=@errorFuncNaN);
                CROSS_1(cellfun('isempty', CROSS_1)) = {NaN};
                OverBinomial{L,"p<0.05"} = {[ {[CROSS_1{Het}]} {[CROSS_1{WT}]} ]} ;
                OverBinomial_AVG{L,"p<0.05"} = {[mean(cell2mat(CROSS_1(Het)), "omitmissing") mean(cell2mat(CROSS_1(WT)), "omitmissing") ; std(cell2mat(CROSS_1(Het)), "omitmissing") std(cell2mat(CROSS_1(WT)), "omitmissing") ; sum(cellfun(@(x) ~isnan(x), CROSS_1(Het))) sum(cellfun(@(x) ~isnan(x), CROSS_1(WT)))]};
                CROSS_2 = cellfun(@(x) find(x{L}{:,6} < 0.01, 1, "first")+this.BB, Lev, UniformOutput=0, ErrorHandler=@errorFuncNaN);
                CROSS_2(cellfun('isempty', CROSS_2)) = {NaN};
                OverBinomial{L,"p<0.01"} = {[ {[CROSS_2{Het}]} {[CROSS_2{WT}]} ]};
                OverBinomial_AVG{L,"p<0.01"} = {[mean(cell2mat(CROSS_2(Het)), "omitmissing") mean(cell2mat(CROSS_2(WT)), "omitmissing") ; std(cell2mat(CROSS_2(Het)), "omitmissing") std(cell2mat(CROSS_2(WT)), "omitmissing") ; sum(cellfun(@(x) ~isnan(x), CROSS_2(Het))) sum(cellfun(@(x) ~isnan(x), CROSS_2(WT)))]};
                CROSS_3 = cellfun(@(x) find(x{L}{:,6} < 0.001, 1, "first")+this.BB, Lev, UniformOutput=0, ErrorHandler=@errorFuncNaN);
                CROSS_3(cellfun('isempty', CROSS_3)) = {NaN};
                OverBinomial{L,"p<0.001"} = {[ {[CROSS_3{Het}]} {[CROSS_3{WT}]} ]};
                OverBinomial_AVG{L,"p<0.001"} = {[mean(cell2mat(CROSS_3(Het)), "omitmissing") mean(cell2mat(CROSS_3(WT)), "omitmissing") ; std(cell2mat(CROSS_3(Het)), "omitmissing") std(cell2mat(CROSS_3(WT)), "omitmissing") ; sum(cellfun(@(x) ~isnan(x), CROSS_3(Het))) sum(cellfun(@(x) ~isnan(x), CROSS_3(WT)))]};
            end
            Cross = {OverBinomial ; OverBinomial_AVG};
        end
        function MM = newMM(this, scores, options)
            arguments
                this
                scores
                options.Type string = ""
                options.BinSize double = []
                options.FromChance = [] % Append the Scores with a 0.5 to start the moving mean from 50%
                options.Endpoints = [] %Shrink or Discard
            end
            % Init settings variables:
            Endpoints = [];
            FromChance = [];
            switch 1 %Either the BinSize is a number or the Type is specified
                case options.Type == "Big" % Returns a numel(scores) x 1 vector
                    Endpoints = 0;
                    FromChance = 0;
                    BinSize = this.BB;
                case options.Type == "Small" % Returns a numel(scores) x 3 vector
                    Endpoints = 1;
                    FromChance = 1;
                    BinSize = this.SB;
                case ~isempty(options.BinSize)
                    BinSize = options.BinSize;
                    Endpoints = 1;
                    FromChance = 1;
                otherwise
            end
            %Check defaults against inputs, override if specified
            if ~isempty(options.Endpoints)
                Endpoints = options.Endpoints;
            end
            if ~isempty(options.FromChance)
                FromChance = options.FromChance;
            end
            % Decode settings
            if Endpoints
                EP = 'shrink';
            else
                EP = 'discard';
            end
            if FromChance
                APP = 0.5;
            else
                APP = [];
            end
            if options.Type == "Big"
                % large bin moving mean
                MM = movmean([APP ; scores], [BinSize-1 0], 'Endpoints', EP);
                if isempty(MM)
                    MM = movmean([APP ; scores], [BinSize-1 0], 'Endpoints', 'shrink');
                end
            else
                % small bin moving mean
                sMM = movmean([APP ; scores], [BinSize-1 0], 'Endpoints', EP);
                if numel(scores)<this.SB
                    MM = sMM;
                    return
                end
                % For standard deviation:
                B1 = movmean(scores(1:(numel(scores)-this.SB)), [this.SB-1 0], 'Endpoints', 'discard');
                B2 = movmean(scores((this.SB+1):numel(scores)), [this.SB-1 0], 'Endpoints', 'discard');
                STD = std([B1 B2],0,2);
                if EP == "shrink"
                    EXT_STD = nan(numel(sMM)-numel(STD)-1,1);
                    STD = [NaN ; EXT_STD ; STD];
                    EXT_B1 = nan(numel(sMM)-numel(B1)-1,1);
                    B1 = [NaN ; B1 ; EXT_B1];
                    EXT_B2 = nan(numel(sMM)-numel(B2)-1,1);
                    B2 = [NaN ; EXT_B2 ; B2];
                    MM = [sMM STD B1 B2];
                else
                    EXT = numel(sMM)-numel(STD);
                    sMM = sMM(EXT+1:end);
                    MM = [sMM STD];
                end
            end
        end
        function Out = DayBin(this,D)
            %D is trial scores grouped by Level, and by Day
            Out = num2cell(nan(17,1)); % THIS MUST BE UPDATED EVERYTIME NEW THINGS ARE ADDED
            s = D(:,1);
            these = s(s~=2);
            if numel(these)==0
                return
            end
            Level = D(1,2);
            if Level == 16
                A = 1;
            end
            Date = D(1,3);
            Day = D(1,4);
            try
                %Binning stuff
                xid = [0:this.SB:numel(these) numel(these)];
                x = normalize(xid,'range');
                x(1) = [];
                [~,~,idx] = histcounts((1:numel(these)), [1:this.SB:numel(these) Inf]);
                binned = accumarray(idx', these, {}, @mean)';
                if numel(binned)<=1
                    x = 0.5;
                end
                txt = string(cellfun(@(x){num2str(round(100*x,1))}, num2cell(binned)));
                %Moving mean Stuff
                sMMIn = this.newMM(these,"Type","Small", "Endpoints",1, "FromChance", 1);
                sMM = sMMIn(:,1)';
                bMM = this.newMM(these,"Type","Big", "Endpoints",1, "FromChance", 1)';
                xMM = normalize(1:numel(sMM),'range');
                BiCDF = zeros(1, numel(these));
                tc = 0;
                for t = 1:numel(these)
                    tc = tc + 1;
                    t0 = max(t-this.BB+1,1);
                    dataWin = these(t0:t);
                    BiCDF(1,t) = binocdf(sum(dataWin), numel(dataWin), 0.5, 'upper');
                end
                BiCDF = [NaN BiCDF];
                sCross = find(sMM>=0.8, 1, 'first'); %When did today's performance cross the threshold?
                bCross = find(bMM>=0.8, 1, 'first'); %When did today's performance cross the threshold?
                Binomial_Cross1 = find(BiCDF(this.SB:end)<=0.05, 1, 'first')+(this.SB-1);
                Binomial_Cross2 = find(BiCDF(this.SB:end)<=0.01, 1, 'first')+(this.SB-1);
                Binomial_Cross3 = find(BiCDF(this.SB:end)<=0.001, 1, 'first')+(this.SB-1);
                BiCross = [Binomial_Cross1 Binomial_Cross2 Binomial_Cross3];
                if isempty(sCross)
                    sCross = NaN;
                end
                if isempty(bCross)
                    bCross = NaN;
                end
                Day_Bin = {binned;
                    x;
                    txt;
                    numel(these);
                    mean(these);
                    std(binned);
                    s';
                    sMM;
                    xMM;
                    bMM;
                    sCross;
                    bCross;
                    BiCDF;
                    BiCross;
                    Level;
                    Day;
                    Date};
                Names = {'binned', 'x', 'txt', 'numel', 'mean', 'std', 's', 'sMM', 'xMM', 'bMM', 'sCross', 'bCross', 'BiCDF', 'BiCross', 'Level', 'Day', 'Date'};
                Out = cell2table(Day_Bin, "RowNames", Names);
            catch err
                unwrapErr(err)
            end
        end
        function [dataMatrix] = getDataToSave(this) %Make the data table for saving the data:
            %Arrange the save data for the analysis functions
            dataMatrix = this.current_data_struct;
            names = fieldnames(dataMatrix);
            for n = names(structfun(@isrow, dataMatrix) & structfun(@length, dataMatrix) > 1)' %Make sure everything is saved as a column
                dataMatrix.(n{:}) = dataMatrix.(n{:})';
            end
        end
        function data = CleanData(this, options)
            arguments
                this
                options.IsAnalysis logical = 0
                options.CE double = 30
            end
            data = this.current_data_struct;
            names = fieldnames(data);
            for n = names(structfun(@isrow, this.current_data_struct) & structfun(@length, this.current_data_struct) > 1)'
                data.(n{:}) = data.(n{:})';
            end
            data.TrialNum = zeros(size(data.Level));
            data.SmallBin = zeros(size(data.Level));
            data.BigBin = zeros(size(data.Level));
            try
                [~,data.LevelGroups] =findgroups(data.Level');
            catch
            end
            rows = data.Score ~= 2;
            data.TrialNum(rows) = (1:sum(rows));
            if isempty(this.SB) || isempty(this.BB) %For later analysis, the bin sizes will be changing
                return
            end
            for Lev = data.LevelGroups
                rows = data.Level == Lev & data.Score ~= 2;
                m = sum(rows);
                if m==0
                    continue
                end
                [~, ~, data.SmallBin(rows)] = histcounts((1:m)', [1:this.SB:m inf]); %Small Bin
                [~, ~, data.BigBin(rows)] = histcounts((1:m)', [1:this.BB:m inf]); %Large Bin
            end
            if options.IsAnalysis && options.CE ~= 0 && max(data.TrialNum) >= 120
                % Crop the last few trials

                %Either use the Include vector to later crop (more work)
                data.Include(end-options.CE+1:end) = 2;
                m = numel(data.TrialNum);
                % Or just remove them
                for n = names'
                    try
                        if numel(data.(n{:}))~=m
                            continue
                        end
                        data.(n{:})(end-options.CE+1:end) = [];
                    catch err
                        unwrapErr(err)
                    end
                end
            end
        end
        %Plot functions
        function PlotAllSubData(this)
            this.sc = 0;
            tic
            for S = struct2cell(this.DayData)'
                this.sc = this.sc+1;
                this.dc = 0;
                for d = [S{:}(:,:)]'
                    this.dc = this.dc+1;
                    this.date = d{2};
                    %                     if this.dc==17
                    %                         fprintf("Stop!\n")
                    %                     end
                    this.current_data_struct = d{3};
                    this.CleanData();
                    graphFig = figure("Name", "DayRec"+filesep+this.Sub{this.sc}, "Visible","on");
                    this.Axes = this.CreateDailyGraphs(graphFig);
                    title = "Day " +this.dc+" - - - "+this.Sub{this.sc}+" - - - "+d{2};
                    graphFig.Children.Title.String = title;
                    this.PlotNewData();
                    FileDir = [this.filedir{this.sc} filesep 'DayRec' filesep this.Sub{this.sc} filesep];
                    if ~exist(FileDir,"dir")
                        mkdir(FileDir)
                    end
                    this.SaveManyFigures([], string(d{2})+"_"+this.Sub{this.sc});
                    close(graphFig)
                end
            end
            toc
        end
        function PlotNewData(this)
            structfun(@cla, this.Axes)
            if ~isfield(this.current_data_struct, 'LevelGroups')
                this.current_data_struct = CleanData(this.current_data_struct);
            end
            trialTbl = this.current_data_struct;
            [G,ID] = findgroups(this.current_data_struct.Level);
            DATE = ones(size(this.current_data_struct.Score));
            this.AnalyzedData.DayMM = splitapply(@(x){this.DayBin(x)}, [this.current_data_struct.Score this.current_data_struct.Level DATE DATE], G);
            this.AnalyzedData.LevMM = splitapply(@(x)this.LevelMMAnalysis(x), [trialTbl.Score DATE DATE], G);
            try
                this.setGUI(this.current_data_struct, this.GUInum)
                % try
                %     this.plotTimerHists(this.Axes, this.current_data_struct)
                % catch
                % end
                %this.plotTrialHistory(this.Axes.TrialHistory, this.current_data_struct)
                this.plotBinnedPerformance(this.Axes.BinnedPerf, this.current_data_struct)
                this.plotAllLevelPerformance()
                this.plotSideBias(this.Axes.SideBias, this.current_data_struct)
                this.plotLevelPerf(this.Axes.LevelCount, this.current_data_struct)
            catch err
                unwrapErr(err)
            end
        end
        function plotTimerHists(this, ~, Data)
            %plot time to start trial histogram of session
            %Time to Start extends if the mouse malingers and picks L or R when the ready cue is up
            f = fieldnames(this.Axes);
            f = flip(f(contains(f, 'Time')));
            n = fieldnames(this.current_data_struct);
            if any(~contains(n, "Time"))
                return
            end
            D = [this.current_data_struct.TrialStartTime', this.current_data_struct.ResponseTime'];
            if isrow(D) && length(D) > 3
                D = [Data.TrialStartTime, Data.ResponseTime];
            end
            c = 0;
            for a = f'
                hold(this.Axes.(a{:}), 'on')
                c = c+1;
                h = bar(1:numel(Data.Score), D(:,c), 1, ...
                    'Parent', this.Axes.(a{:}), ...
                    'FaceColor', 'flat', ...
                    'EdgeColor', 'none');
                switch a{:} %Different colors for each graph
                    case "ResponseTime"
                        Correct = find(Data.Score == 1);
                        Wrong = find(Data.Score == 0);
                        [h.CData(Correct,:)] = repmat([0 1 0], numel(Correct), 1);
                        [h.CData(Wrong,:)] = repmat([1 0 0], numel(Wrong), 1);
                end
                this.Axes.(a{:}).XLimitMethod = 'tight';
            end
        end
        function plotTrialHistory(this, Ax, Data)
            try
                hold(Ax, 'on')
                [LRT, plotScore] = this.CalculateTH(Data.isLeftTrial, Data.Score);
                colors = {[0 1 1], [1 1 0], [1 1 1]};
                b = bar(1:numel(Data.isLeftTrial), 1, 'Parent', Ax, 'FaceColor', 'flat', 'EdgeColor', 'None');
                for s = 1:3
                    if isempty(LRT{s})
                        continue
                    end
                    [b.CData(LRT{s},:)] = repmat(colors{s}, numel(LRT{s}), 1);
                end
                % dat = Data.Score(Data.Score ~=2);
                y = movmean([0.5 ; Data.Score(Data.Score ~=2)], [this.BB-1 0], "Endpoints", "shrink");
                x = (0:(numel(y)-1))';
                try
                    cPerf = plot(x, y, 'Parent',Ax);
                catch err
                    unwrapErr(err)
                end
                cPerf.LineWidth = 2;
                cPerf.Color = 'w';
                for L = Data.LevelGroups
                    w = Data.Level == L;
                    x = find(w);
                    hs = scatter(x, plotScore(w), 5, [.5 0 0], 'filled', 'Parent', Ax);
                    hs.MarkerEdgeColor = 'flat';
                    hs.Marker = deal(this.Shape_code(L));
                    hs.SizeData = 15;
                    hs.YJitter = "density";
                    hs.YJitterWidth = 0.01;
                end
                Ax.XLimitMethod = "tight";
                Ax.XLim = [0.5 numel(Data.Score)+0.5];
            catch
            end
        end
        function plotSideBias(this, Ax, D)
            hold(Ax, 'on')
            try
                if sum(D.Score~=2)==0
                    return
                end
                SBt = this.CalculateSB(D);
                yline(Ax, 0.5, '-',"Color",[0.4 0.4 0.4])
                lc = 0;
                for SBl = SBt
                    try
                        lc = lc+1;
                        thisLev = D.LevelGroups(lc);
                        s = scatter(SBl{:}(2,:), 0.5+SBl{:}(1,:), 'Parent', Ax); %Adding 0.5 makes 0 right bias and 1 left bias
                        [s.CDataMode] = deal('auto');
                        [s.MarkerFaceColor] = deal('flat');
                        [s.MarkerEdgeColor] = deal('flat');
                        try
                            [s.Marker] = deal(this.Shape_code(thisLev));
                        catch
                        end
                        [s.CDataMode] = deal('auto');
                        [s.SeriesIndex] = deal(thisLev);
                    catch err
                        unwrapErr(err) %this fails when there is a timeout trial... fix later
                    end
                end
                Ax.YLim = [-0.05 1.05];
                Ax.XLim = [0.5 sum(D.TrialNum~=0)+0.5];
                Ax.XLimitMethod = "tight";
                Ax.YGrid = 'on';
            catch err
                unwrapErr(err)
            end
        end
        function plotBinnedPerformance(this, Ax, Data)
            hold(Ax, 'on')
            if sum(Data.Score~=2)==0
                return
            end
            try
                [SortData] = this.CalculateBP();
                [~,Lidx]=sort(SortData(:,1));
                SortData = SortData(Lidx,:);
                halfFull = sum(SortData(:,[4 5 6]),2)<this.BB;
                [m,~] = size(SortData);
                [~, Levels] = findgroups(SortData(:,1)');
                total = 1:m;
                COUNT = 0;
                for L = Levels
                    COUNT=COUNT+1;
                    fullrows = SortData(:,1) == L & ~halfFull;
                    halffullrows = SortData(:,1) == L & halfFull;
                    Lvrows = SortData(:,1) == L;
                    yB = cell2mat(this.AnalyzedData.DayMM{COUNT}{10,1});
                    yS = cell2mat(this.AnalyzedData.DayMM{COUNT}{8,1});
                    yBinom = this.AnalyzedData.DayMM{COUNT}{13,1};
                    LIdx = find(SortData(:,1)==L,1,'first')-0.5;
                    len = sum(Lvrows);
                    x = LIdx+len*((1:numel(yB))/numel(yB));
                    try
                        pS = plot(x, yS, 'Parent', Ax, 'DisplayName',"Small Bin");
                        pS.LineStyle = ":";
                        p = plot(x,yB, 'Parent', Ax, 'DisplayName',"Big Bin");
                        p.LineWidth = 1.5;
                        p.SeriesIndex = L;
                        pS.SeriesIndex = L;
                    catch
                    end
                    Perf = errorbar( total(fullrows) , SortData(fullrows,2) , SortData(fullrows,3) , 'Parent', Ax, 'DisplayName',"Binned");
                    Perf.MarkerFaceColor = "auto";
                    Perf.MarkerEdgeColor = "auto";
                    Perf.LineStyle = 'none';
                    Perf.MarkerMode = "auto";
                    try
                        Perf.Marker = this.Shape_code{L};
                    catch
                    end
                    Perf.MarkerSize = 9;
                    Perf2 = scatter( total(halffullrows) , SortData(halffullrows,2) , 'Parent', Ax, 'DisplayName',"Marker");
                    try
                        Perf2.Marker = Perf.Marker;
                        p.SeriesIndex = L;
                        % p2.SeriesIndex = L;
                    catch
                    end
                    Perf2.MarkerFaceColor = "auto";
                    Perf2.MarkerFaceColor = 'flat';
                    Perf.SeriesIndex = L;
                    Perf2.SeriesIndex = L;
                end
                text(total, 0.03*ones(size(total)), num2cell(round(SortData(:,8)',2)), ...
                    'Parent',Ax, ...
                    'HorizontalAlignment','center')
                try
                    text(total, SortData(:,2), Data.SetStr(SortData(:,10)'), ...
                        'Parent',Ax, ...
                        'HorizontalAlignment','center', ...
                        'VerticalAlignment','Top')
                catch
                end
                text(total, SortData(:,2), num2cell(round(SortData(:,2),4)*100), ...
                    'Parent',Ax, ...
                    'HorizontalAlignment','center', ...
                    'VerticalAlignment','Bottom')
                %Change limits, ticks, grids:
                Ax.XLim = [0.6 size(SortData,1)+0.6];
                %Ax.XLim = [0 numel(Levels)];
                Ax.YLim = [0.45 1.01];
                Ax.YTick = 0:0.25:1;
                Ax.YGrid = 1;
                Ax.YMinorTick = 1;
                Ax.YMinorGrid = 1;
                Ax.YAxis.MinorTickValues = 0:0.1:1;
                Ax.YAxis.TickLabels = [];
            catch err
                unwrapErr(err)
            end
        end
        function plotAllLevelPerformance(this)
            Data = this.current_data_struct;
            if all(Data.Score == 2)
                return
            end
            tnum = Data.TrialNum;
            Ax = this.Axes.AllLevelPerf; hold(Ax, "on");
            COUNT = 0;
            for L = this.current_data_struct.LevelGroups
                COUNT=COUNT+1;
                w = Data.Level==L & Data.Score~=2;
                x = [0 ; tnum(w)]; %Add point [0, 50%] because at trial #0 the mouse is at 50% (chance) performance, every day you assume the mouse starts from "chance"
                x(1) = x(2)-1;
                yB = cell2mat(this.AnalyzedData.DayMM{COUNT}{10,1});
                yS = cell2mat(this.AnalyzedData.DayMM{COUNT}{8,1});
                yBinom = cell2mat(this.AnalyzedData.DayMM{COUNT}{13,1});
                try
                    p2s = plot(x,yS,'Parent', Ax, ...
                        "LineStyle",":");
                    p2s.SeriesIndex = L;
                    p2s.LineWidth = 2;
                    err = zeros(size(yB));
                    p2B = errorbar(x,yB, err,'Parent', Ax, ...
                        "LineStyle","none");
                    p2B.SeriesIndex = L;
                    p2B.MarkerFaceColor = "auto";
                    p2B.Marker = deal(this.Shape_code(L));
                    p2BN = plot(x,yBinom,'Parent', this.Axes.Binomial, ...
                        "LineStyle","-");
                    p2BN.SeriesIndex = L;
                    p2BN.LineWidth = 2;
                catch
                end
            end
            top = min([max(yB)+0.001 1.05]);
            try
                Ax.YLim = [0.501 top];
            catch
            end
            %Change limits, ticks, grids:
            Ax.XLim = [0.5 numel(tnum)+0.5];
            Ax.XTick = 0:10:numel(tnum);
            Ax.XAxis.TickLabels = [];
            Ax.YLim = [0.45 1.01];
            Ax.YTick = 0:0.25:1;
            Ax.YGrid = 1;
            Ax.YMinorTick = 1;
            Ax.YMinorGrid = 1;
            Ax.YAxis.MinorTickValues = 0:0.1:1;
            Ax.YAxis.TickLabels = [];
            %Change limits, ticks, grids:
            %this.Axes.Binomial.XLim = [0.5 numel(tnum)+0.5];
            %this.Axes.Binomial.XAxis.TickLabels = [];
            %this.Axes.Binomial.YScale = "log";
            % this.Axes.Binomial.YLim = [-0.1 1];
            % this.Axes.Binomial.YGrid = 1;
            % this.Axes.Binomial.YMinorTick = 1;
            % this.Axes.Binomial.YMinorGrid = 1;
            % this.Axes.Binomial.YAxis.TickLabels = [];
        end
        function plotLevelPerf(this, Ax, D)
            hold(Ax, 'on')
            if sum(D.Score~=2)==0
                return
            end
            try
                [~, Avgs] = this.CalculateLP(D.Level, D.Score);
                %Avgs{:,L} = {1BigMean} {2All Small Means} {3BigSTD} {4numel} {5Level#}
                for L = Avgs
                    Lev = L{end};
                    try
                        x = Lev;
                        y = L{1};
                        err = L{3};
                        if L{end-1} == 0
                            y = NaN;
                            err = NaN;
                        end
                        s = errorbar(x, y, err, 'Parent', Ax);
                        s.Marker = this.Shape_code(Lev);
                        s.MarkerFaceColor = "auto";
                        s.SeriesIndex = Lev;
                        if numel(L{2})>1
                            y = L{2}';
                            x = Lev*ones(size(y));
                            dots = scatter(x, y, "filled", ...
                                "Parent", Ax,...
                                "MarkerEdgeColor","flat", ...
                                "MarkerFaceColor", "flat", ...
                                "SizeData", 4, ...
                                "YJitter","density");
                            dots.CData = s.Color;
                        end
                    catch
                    end
                end
                %Big average on scatter point
                LvIdx = cellfun(@(x) x, Avgs(end,:), 'UniformOutput', true);
                y = cell2mat(Avgs(1,:));
                avgTxt = cellfun(@(x) string(100*round(x,3)), Avgs(1,:));
                text(LvIdx, y, avgTxt, ...
                    'Parent', Ax, ...
                    'HorizontalAlignment','right', ...
                    'VerticalAlignment','top', ...
                    'FontSize',8)
                %Level count at y = 0.48
                y = 0.48*ones(size(LvIdx));
                countTxt = cellfun(@(x) num2str(x), Avgs(5,:), 'UniformOutput', false);
                text(LvIdx, y, countTxt, ...
                    'Parent', Ax, ...
                    'HorizontalAlignment','center', ...
                    'FontSize',8);
                %                 % -Log Binom
                %                 y = 0.45*ones(size(LvIdx));
                %                 NegLogBinom = cellfun(@(x) string(round(x,1)), Avgs(4,:));
                %                 text(LvIdx, y, NegLogBinom, ...
                %                     'Parent', Ax, ...
                %                     'HorizontalAlignment','center', ...
                %                     'VerticalAlignment','top', ...
                %                     'FontSize',8)
                %Change limits, ticks, grids:
                Ax.XLim = [0 max(D.Level)+1];
                Ax.YLim = [0.43 1.05];
                Ax.YTick = 0:0.25:1;
                Ax.YGrid = 1;
                Ax.YMinorTick = 1;
                Ax.YMinorGrid = 1;
                Ax.YAxis.MinorTickValues = 0:0.1:1;
                Ax.YAxis.TickLabels = [];
            catch err
                unwrapErr(err)
            end
        end
        %For Group Plotting:
        function GroupData(this, opts)
            arguments
                this
                opts.Composite logical = 0
                opts.LevGroup logical = 0
                opts.History logical = 0
                opts.Stim logical = 0
                opts.LevelProgress logical = 0
                opts.LevelProgressIndividual logical = 1
                opts.Save logical = 1
            end
            Num = num2cell(1:numel(this.Sub));
            tic
            if opts.LevelProgress
                this.BinomialProgress();
                if opts.Save
                    this.SaveManyFigures([],'Binomial', SameFolder=1)
                    close all
                end
            end
            if opts.LevelProgressIndividual
                for P = 1:3
                    this.BinomialProgressIndividual("WhichPValue",P);
                    if opts.Save
                        this.SaveManyFigures([],'BinomialIndividual', SameFolder=1)
                        close all
                    end
                end
            end
            if opts.LevGroup
                cellfun(@(x){this.PlotLevelGroupsByDay(Sc=x)}, Num); drawnow
                if opts.Save
                    this.SaveManyFigures([],'LevelGroup', SameFolder=1)
                    close all
                end
            end
            if opts.History
                ACell = cellfun(@(x){this.plotLvByDayOneAxis(Sc=x, LevDay=0)}, Num);
                if opts.Save
                    this.SaveManyFigures([],'AllLevelsByDay', SameFolder=1)
                    close all
                end
                cellfun(@(x) set(x, 'Visible', 'on'), ACell)
            end
            if opts.Stim
                this.PlotStimulusHistory();
            end
            time = toc;
            fprintf("Total time: " + time + " seconds.\n")
        end
        function Out = DailyProgress(this, options)
            % This fcn normalizes the performance to each day to show the mouse's
            % progress at each day of the level
            arguments
                this
                options.Sc double = 1
                options.AllMice logical = 0
                options.Lvs double = 10:16 % Do not display levels below this
                options.Moveable logical = 0 % Unused
                options.Threshold double = 0.7 % Passing threshold for each level
                options.count double = 10 % Num of consecutive trials above threshold before passing
                options.tol double = 0 % How many below-threshold trials in the streak of options.count to be tolerated
            end
            Out = struct();
            % Pull the cumulative Level and Day data
            LEVDATA = cellfun(@(x)this.AnalyzedData.LevelMM{x}, num2cell(1:numel(this.Sub)), UniformOutput=false);
            DAYDATA = cellfun(@(x)this.AnalyzedData.DayMM{x}, num2cell(1:numel(this.Sub)), UniformOutput=false);
            SUBS = this.AnalyzedData.Subjects;
            for L = options.Lvs
                % Prepare and format 2x2 subplot
                Ax = MakeAxis();
                Bx = nexttile; hold(Bx,"on");
                Cx = nexttile; hold(Cx,"on");
                Dx = nexttile; hold(Dx,"on");
                Ex = nexttile; hold(Ex,"on");
                Fx = nexttile; hold(Fx,"on");
                Ax.Title.String = "By Day";
                Bx.Title.String = "By Trial";
                Cx.Title.String = "Days to Pass";
                Dx.Title.String = "Trials To Pass";
                Ex.Title.String = "Binomial by Day";
                Fx.Title.String = "Binomial by Trial";
                Ax.Parent.Title.String = "Level "+L;
                Ax.Box=0;
                Bx.Box=0;
                Cx.Box=0;
                Dx.Box=0;
                Ax.YLim = [0.4 1]; Bx.YLim = [0.4 1];
                SC = 0;
                % Matrix to record passing data:
                PassIdx = zeros(numel(SUBS),9);
                % 1 Did they pass
                % 2 at which trial number
                % 3 Threshold for passing (in case TH is later lowered)
                % 4 Day of passing
                % 5 Did they see that level at all
                % 6 Cumulative over-threshold passing-trial
                % 7 Het = 1 or WT = 0
                % 8 Male = 1 or Female = 0
                % 9 Lowest binomial p-value
                LD = cell(size(SUBS));
                for SUBDATA = [DAYDATA ; LEVDATA]
                    SC = SC + 1;
                    thisSub = SUBS{SC};
                    PassIdx(SC,7) = contains(thisSub, "Het");
                    PassIdx(SC,8) = contains(thisSub, "- M -");
                    ColorIdx = PassIdx(SC,7)+1;
                    %Check if they've seen this level:
                    if ~any(SUBDATA{1}.Ls == L)
                        continue
                    end
                    try
                        dayData = SUBDATA{1};
                        LevData = SUBDATA{2};
                        lev = LevData{L};
                        lx = lev(:,4);
                        ly = lev(:,1);
                        lb = lev(:,6); %binomial p-value
                        plot(lx,lb,"Parent",Ex,"SeriesIndex",ColorIdx, "LineWidth",3, "DisplayName",thisSub);
                        plot((1:numel(ly))+(this.BB-1),lb,"Parent",Fx,"SeriesIndex",ColorIdx, "LineWidth",3, "DisplayName",thisSub);
                        PassIdx(SC,9) = min(lb);
                        lp = plot(lx,ly,"Parent",Ax,"SeriesIndex",ColorIdx, "LineWidth",3, "DisplayName",thisSub);
                        lpB = plot((1:numel(ly))+(this.BB-1),ly,"Parent",Bx,"SeriesIndex",ColorIdx, "LineWidth",3, "DisplayName",thisSub);
                        % From cumulative LevelTable, find the trials over the threshold
                        % overThreshEx = cellfun(@(x)find(x(:,1)>=options.Threshold & x(:,5)==1)+this.BB, LevData, 'UniformOutput', false, 'ErrorHandler',@errorFuncNaN);
                        % TrialEx = cellfun(@(x) this.consecutiveTrial(x, options.count, options.tol), overThreshEx, "UniformOutput",true);
                        overThresh = cellfun(@(x)find(x(:,1)>=options.Threshold)+this.BB, LevData, 'UniformOutput', false, 'ErrorHandler',@errorFuncNaN);
                        Trial = cellfun(@(x) this.consecutiveTrial(x, options.count, options.tol), overThresh, "UniformOutput",true);
                        PassIdx(SC,6)=Trial(L);
                        LD{SC}=ly;
                        if any(ly>=options.Threshold)
                            PassIdx(SC,3)=options.Threshold;
                            PassIdx(SC,1)=1;
                            PassIdx(SC,2)=find(ly>=options.Threshold, 1, 'first')+(this.BB-1);
                            PassIdx(SC,4)=ceil(lx(PassIdx(SC,2)-(this.BB-1)));
                        else
                            PassIdx(SC,3)=max(ly);
                            PassIdx(SC,2)=find(ly==max(ly), 1, 'last')+(this.BB-1);
                        end
                        %Bx.XLim = [60 numel(ly+59)];
                        dc = 0;
                        data = dayData(dayData.Ls==L,:);
                        for d = data.dayBin'
                            dayy = d{:}{8};
                            dayx = d{:}{9} + dc;
                            dp = plot(dayx,dayy,"Parent",Ax, "SeriesIndex",ColorIdx, 'HandleVisibility','off');
                            dc = dc + 1;
                        end
                        PassIdx(SC,5)=1;
                        %dayBars = xline(1:numel(data.dayBin), 'LineStyle',':', 'LineWidth',3, 'HandleVisibility','off', Parent=Ax);
                    catch err
                        unwrapErr(err)
                        1;
                    end
                end
                if ~options.Moveable
                    THA = yline(0.8, 'LineStyle','-', 'LineWidth',3, ...
                        'ButtonDownFcn',@MouseDown_TH, "Parent",Ax, 'HandleVisibility','off');
                    THB = yline(0.8, 'LineStyle','-', 'LineWidth',3, ...
                        'ButtonDownFcn',@MouseDown_TH, "Parent",Bx, 'HandleVisibility','off');
                else
                end
                legend(Ax); legend(Bx);
                % Plot a bar graph of trials to pass
                if ~all(PassIdx(:,1)) && min(PassIdx( PassIdx(:,1) ~=1 ,3))~=0
                    NewTH = min(PassIdx(PassIdx(:,1)~=1,3));
                    PassIdx(:,3) = NewTH;
                    SC = 0;
                    for LevData = LEVDATA
                        SC = SC + 1;
                        overThresh = cellfun(@(x)find(x(:,1)>=NewTH)+this.BB, LevData{:}, 'UniformOutput', false, 'ErrorHandler',@errorFuncNaN);
                        Trial = cellfun(@(x) this.consecutiveTrial(x, options.count, options.tol), overThresh, "UniformOutput",true);
                        PassIdx(SC,6) = Trial(L);
                        %PassIdx(SC,2)=find(ly>=NewTH, 1, 'first')+59;
                        %PassIdx(SC,4)=ceil(lx(PassIdx(SC,2)-59));
                    end
                    THA.Value = NewTH; THA.Label = num2str(NewTH);
                    THB.Value = NewTH; THB.Label = num2str(NewTH);
                    % %Reset the trial count for whoeveer has passed the
                    % %levels at 80% to the new lower threshold
                    % WHICH = PassIdx(:,1)~=1;
                    % pc = 0;
                    % for w = WHICH'
                    %     pc = pc+1;
                    %     if w == 0
                    %         continue
                    %     end
                    %     try
                    %         PassIdx(pc,2)=find(LD{pc}>=NewTH,1,"first")+59;
                    %     catch err
                    %         unwrapErr(err)
                    %         1;
                    %     end
                    % end
                end
                SC = 1;
                for P = PassIdx'
                    ColorIdx = P(7)+1;
                    if isnan(P(6))
                        P(6) = P(2);
                    end
                    Bday = bar(SC, P(4), "Parent",Cx, "SeriesIndex",ColorIdx);
                    Blev = bar(SC, P(6), "Parent",Dx, "SeriesIndex",ColorIdx);
                    SC = SC + 1;
                end
                Dx.XTick = [1:numel(SUBS)];
                Dx.XTickLabel = SUBS;
            end

            function MouseDown_TH(obj, events)
                TH_Mouse = true;
                Ax.XLimMode="manual";
                Ax.YLimMode="manual";
            end
        end
        function Out = BinomialProgress(this, options)
            % This fcn normalizes the performance to each day to show the mouse's
            % progress at each day of the level
            arguments
                this
                options.Sc double = 1
                options.Lvs double = [3 6 8 10 12 16] %
                options.Threshold double = 0.7 % Passing threshold for each level
                options.count double = 10 % Num of consecutive trials above threshold before passing
                options.tol double = 0 % How many below-threshold trials in the streak of options.count to be tolerated
                options.BarOnly logical = true
            end
            Out = struct();
            SUBS = this.AnalyzedData.Subjects;
            deets = split(SUBS{1},'-');
            Data = this.AnalyzedData.CrossTable{2};
            Ax = MakeAxis();
            hold(Ax, "on")
            Ax.Parent.Title.String = string(this.Str)+deets{2};
            Ax.Parent.Parent.Name = Ax.Parent.Title.String;
            Ax.Box=0;
            LabelList = [];
            lc = 0;
            for L = options.Lvs
                % Prepare and format 2x2 subplot
                try

                    ThisData = cell2mat(Data{L,1});
                    if ThisData == 0
                        continue
                    end
                    %x = [1 2];
                    x = lc + normalize([1 2 3 4], "range");
                    x([1 4]) = [];

                    y = ThisData(1,:);
                    Err = ThisData(2,:);
                    B = bar(x, y, "Parent",Ax, "FaceColor","flat");
                    B.CData(1,:) = Ax.ColorOrder(1,:);
                    B.CData(2,:) = Ax.ColorOrder(2,:);
                    if ~options.BarOnly
                        E_Bar = errorbar(x, y, Err, ...
                            "Parent", Ax, ...
                            "LineStyle","none");
                    end
                    N_Label = text(x, -0.1.*[1 1], "n = "+string(ThisData(3,:)), "VerticalAlignment","top", "HorizontalAlignment","center");
                    Level_Label = text(lc+0.5, -10, "Level "+L, "VerticalAlignment","top", "HorizontalAlignment","center");
                    Text = text(x, y, string(round(y, 2))+' +/- '+string(round(Err, 2)), "VerticalAlignment","bottom", "HorizontalAlignment","center");
                catch err
                    unwrapErr
                end
                lc = lc + 1;
            end
            Ax.YLim(1) = -20;
            Ax.YTick = 0:25:200;
        end
        function Out = BinomialProgressIndividual(this, options)
            % This fcn normalizes the performance to each day to show the mouse's
            % progress at each day of the level
            arguments
                this
                options.Sc double = 1
                options.Lvs double = [1:20] %  [2 3 5 6 8] %
                options.Threshold double = 0.7 % Passing threshold for each level
                options.count double = 10 % Num of consecutive trials above threshold before passing
                options.tol double = 0 % How many below-threshold trials in the streak of options.count to be tolerated
                options.BarOnly logical = true
                options.NameLegend logical = true
                options.WhichPValue = 3 % 1 is 0.05, 2 is 0.01 3 is 0.001
            end
            Out = struct();
            SUBS = this.AnalyzedData.Subjects;
            deets = split(SUBS{1},'-');
            Data = this.AnalyzedData.CrossTable{1};
            Ax = MakeAxis();
            hold(Ax, "on")
            Ax.Parent.Title.String = string(this.Str)+deets{2}+Data.Properties.VariableNames{options.WhichPValue};
            Ax.Parent.Parent.Name = Ax.Parent.Title.String;
            Ax.Box=0;
            LabelList = [];
            lc = 0;
            for L = options.Lvs
                % Prepare and format 2x2 subplot
                try
                    ThisData = cell2mat(Data{L,options.WhichPValue}{:});
                    if ThisData == 0
                        continue
                    end
                    %x = [1 2];
                    x = lc + normalize(1:(6+numel(ThisData)), "range");
                    x([1 2 3 end-2 end-1 end]) = [];

                    y = ThisData(1,:);
                    %Err = ThisData(2,:);
                    B = bar(x, y, "Parent",Ax, "FaceColor","flat");
                    for II = find(contains(this.Sub, "- Het"))
                        B.CData(II,:) = Ax.ColorOrder(1,:);
                    end
                    for II = find(contains(this.Sub, "- WT"))
                        B.CData(II,:) = Ax.ColorOrder(2,:);
                    end
                    Level_Label = text(lc+0.5, -180, "Level "+L, "VerticalAlignment","top", "HorizontalAlignment","center");
                    Text = text(x, y, string(round(y, 2)), "VerticalAlignment","bottom", "HorizontalAlignment","center");
                    if options.NameLegend
                        Names = text(x, -75*ones(size(x)), this.Sub, "HorizontalAlignment","center", "Rotation",90);
                    end
                catch err
                    unwrapErr
                end
                lc = lc + 1;
            end
            Ax.YLim(1) = -180;
        end
        function Out = consecutiveTrial(this, vec, count, tol)
            arguments
                this
                vec
                count
                tol double = 0
            end
            Test = (count-1):-1:0;
            for v = count:numel(vec)
                win = v-Test;
                Nums = vec(win);
                if Nums(end)-Nums(1) <= ((count-1) + tol)
                    Out = vec(v);
                    return
                end
            end
            Out = NaN;
        end
        function Out = plotLvByDayOneAxis(this, options)
            arguments
                this
                options.save logical = true
                options.Text logical = false
                options.LevDay logical = true
                options.Sc = 1
                options.Training logical = false
            end
            tic;
            Out = [];
            try
                if ~options.Training
                    this.sc = options.Sc;
                else
                    this.sc=1;
                end
                SUB = this.Sub{this.sc};
                Ldat = this.AnalyzedData.LevelMM{this.sc};
                HighScore = cellfun(@(x) max([x(:,1) ; 0]), Ldat, 'UniformOutput', true, 'ErrorHandler', @errorFuncNaN);
                maxPassedL = find(HighScore>=0.8 & ~cellfun('isempty', Ldat), 1, 'last');
                highestSeen = max(unique(this.trial_table.Level));
                this.trial_table = this.AnalyzedData.TrialTbls{this.sc};
                title = SUB+" All Time Performance";
                f = figure("Name",title, "Visible", "off");  f.Visible=1;
                T = tiledlayout(1,1,"Parent",f,"TileSpacing","none","Padding","tight");
                Ax = nexttile(T); hold(Ax, "on");
                Ax.Box = 0;
                Ax.XTick = [];
                Ax.YTick = [];
                Ax.Title.String = title;
                numDays = max(cell2mat(this.AnalyzedData.DayMM{this.sc}.DayNums));
                Ax.XLim = [0 numDays];
                Ax.YLim = [0 highestSeen];
                thresh = 0.8;
                dayLine = xline(1:numDays, 'LineStyle',':');
                yline(0:1:highestSeen, '-')
                TH = yline(thresh:1:(highestSeen+1), ':',(100*thresh)+"%", ...
                    "LabelHorizontalAlignment","left", ...
                    "FontSize",6);
                for L = unique(this.trial_table.Level)' % maxPassedL
                    LO = L-1;
                    wL = this.AnalyzedData.DayMM{this.sc}.Ls==L;
                    Ddat = this.AnalyzedData.DayMM{this.sc}(wL,:);
                    try
                        y = Ldat{L}{:,1}';
                        std = Ldat{L}{:,2}';
                        x = Ldat{L}{:,3}';
                        %Perf
                        dn = "Level "+L+": All Time ";
                        AllTime = plot(x,LO+y, ...
                            "Parent",Ax, ...
                            "SeriesIndex",L, ...
                            "LineWidth",1, ...
                            "DisplayName",dn+"Accuracy");
                        %STD
                        Y = LO+[y+std fliplr(y-std)];
                        X = [x fliplr(x)];
                        P = patch(X,Y,AllTime.Color, ...
                            "Parent", Ax, ...
                            "EdgeColor", "none", ...
                            "FaceAlpha", 0.4);
                        P.DisplayName = dn+"STD";
                    catch
                    end
                    try
                        if any(y>thresh)
                            %PASSING
                            PassingDayIdx = floor( x( find( y>=thresh,1, 'first') ) )+0.5;
                            TT = this.BB+find(y>=thresh,1, 'first')+" Trials";
                            TrialText = text(PassingDayIdx, LO+0.2, TT, ...
                                "FontSize",6, ...
                                "HorizontalAlignment","center", ...
                                "Color",AllTime.Color);
                            %Threshold Integrand:
                            yPatch = LO+[max(y,thresh) max(y-thresh,thresh)];
                            xPatch = [x fliplr(x)];
                            threshPatch = patch(xPatch,yPatch,AllTime.Color, ...
                                "Parent", Ax, ...
                                "EdgeColor", "none");
                            firstPass = find(y>=thresh,1, 'first');
                            yPass = y(firstPass:end);
                            OverThresh = max(yPass-thresh,0)*100;
                            TimeOverThresh = sum(OverThresh)/numel(yPass);
                            UnderThresh = min(yPass-thresh,0)*100;
                            TimeUnderThresh = sum(UnderThresh)/numel(OverThresh);
                            TXT = round(TimeOverThresh,2)+"% from Thresh per trial";
                            ThreshText = text(numDays, LO+0.1,TXT, ...
                                "FontSize",12, ...
                                "HorizontalAlignment","right", ...
                                "Color",AllTime.Color);
                        end
                    catch %They have not passed this level
                    end
                    if numel(unique(cellfun(@numel,Ddat.dayBin))) > 1
                        howBig = cellfun(@numel,Ddat.dayBin');
                        [group, GROUPS]=findgroups(howBig);
                    end
                    for d = [ Ddat.DayNums' ; {Ddat.dayBin{:}} ]
                        DO = d{1}-1;
                        %Small Bin Moving mean:
                        try
                            x = DO+cell2mat(d{2}{9,1});
                            y = LO+cell2mat(d{2}{8,1});
                            SmallPlot = plot(x,y, ...
                                "Parent",Ax, ...
                                "SeriesIndex",L, ...
                                "LineWidth", 0.5);
                            newColor = SmallPlot.Color * 1.5;
                            newColor(newColor>1) = 1;
                            SmallPlot.Color = newColor;
                        catch
                        end
                        %Daily bin values:
                        try
                            if options.Text
                                x = DO+Ddat.dayBin{wD}{2};
                                y = LO+Ddat.dayBin{wD}{1};
                                BinPlot = scatter(x,y, ...
                                    "Parent",Ax, ...
                                    "SeriesIndex",L, ...
                                    "Marker", this.Shape_code{L}, ...
                                    "SizeData",10);
                                BinPlot.MarkerFaceColor = BinPlot.MarkerEdgeColor;
                                Txt = text(x, y, Ddat.dayBin{wD}{3}, ...
                                    "HorizontalAlignment","center", ...
                                    "VerticalAlignment","bottom", ...
                                    "FontSize",6);
                            end
                        catch
                        end
                    end
                end
                if options.LevDay
                    this.PlotLevelGroupsByDay("Ax",Ax, "InComposite",1)
                end
                Ax.XLimitMethod = "tight";
                Ax.YLimitMethod = "tight";
                Ax.Title.String = title;
                if options.Training
                    Out = Ax;
                else
                    Out = f;
                end
            catch err
                unwrapErr(err)
            end
        end
        function Out = PlotLevelGroupsByDay(this, options)
            arguments
                this
                options.InComposite logical = false
                options.Text logical = false
                options.Ax %Axis object
                options.Sc
            end
            tic
            %Out = [];
            if ~isempty(options.Sc)
                this.sc = options.Sc;
            else
                this.sc=1;
            end
            SUB = this.Sub{this.sc};
            Ddat = sortrows(this.AnalyzedData.DayMM{this.sc}, "DayNums");
            Ddat.DayNums=cell2mat(Ddat.DayNums);
            if options.InComposite
                Ax = options.Ax;
                Ax.YLim(1) = -1;
                %yOff = -1;
            else
                Ax = VertAxes(); hold(Ax, 'on'); Ax.Parent.Parent.Visible = 1;
                T = Ax.Parent; f = T.Parent; f.Name = SUB;
                Ax.Parent.Title.String = SUB+" Level Performance";
                FMTAxis(Ax)
                A1 = nexttile(T); A1.XLim = Ax.XLim; hold(A1, 'on')
                A2 = nexttile(T); A2.XLim = Ax.XLim; hold(A2, 'on')
                A3 = nexttile(T); A3.XLim = Ax.XLim; hold(A3, 'on')
                A4 = nexttile(T); A4.XLim = Ax.XLim; hold(A4, 'on')
                A5 = nexttile(T); A5.XLim = Ax.XLim; hold(A5, 'on')
                A6 = nexttile(T); A6.XLim = Ax.XLim; hold(A6, 'on')
                A7 = nexttile(T); A7.XLim = Ax.XLim; hold(A7, 'on')
                A8 = nexttile(T); A8.XLim = Ax.XLim; hold(A8, 'on')
                A9 = nexttile(T); A9.XLim = Ax.XLim; hold(A9, 'on')
                A10 = nexttile(T); A10.XLim = Ax.XLim; hold(A10, 'on')
                A11 = nexttile(T); A11.XLim = Ax.XLim; hold(A11, 'on')
                A12 = nexttile(T); A12.XLim = Ax.XLim; hold(A12, 'on')
                A13 = nexttile(T); A13.XLim = Ax.XLim; hold(A13, 'on')
                A14 = nexttile(T); A14.XLim = Ax.XLim; hold(A14, 'on')
                A15 = nexttile(T); A15.XLim = Ax.XLim; hold(A15, 'on')
            end
            for d = unique(Ddat.DayNums')
                clear x y Ctxt Atxt Ntxt cross CROSS num NUM AVG avg
                wD = Ddat.DayNums==d;
                Ld = Ddat.dayBin(wD);
                LevIdx = Ddat.Ls(wD)';
                Xrange = normalize([0 LevIdx LevIdx(end)+1], "range");
                Xrange = Xrange(2:end-1);
                NUM = cellfun(@(x)x{4} ,Ld, "UniformOutput", true)';
                AVG = cellfun(@(x)x{5} ,Ld, "UniformOutput", true)';
                STD = cellfun(@(x)x{6} ,Ld, "UniformOutput", true)';
                try
                    bCROSS = cellfun(@(x)x{11} ,Ld, "UniformOutput", true, "ErrorHandler", @errorFuncNaN)';
                    sCROSS = cellfun(@(x)x{10} ,Ld, "UniformOutput", true, "ErrorHandler", @errorFuncNaN)';
                catch err
                    unwrapErr(err);
                end
                x = (d-1)+Xrange;
                y = AVG-1;
                try
                    for L = [x; y; STD; LevIdx; sCROSS; bCROSS]
                        E = errorbar(L(1), L(2), L(3), ...
                            'LineStyle','none', ...
                            'Marker', this.Shape_code{L(4)}, ...
                            'SeriesIndex',L(4), 'Parent',Ax);
                        E.MarkerFaceColor = E.Color;
                        E.CapSize = 1;
                        %Plot bars
                        switch L(4)
                            case 1
                                LvAX = A1;
                            case 2
                                LvAX = A2;
                            case 3
                                LvAX = A3;
                            case 4
                                LvAX = A4;
                            case 5
                                LvAX = A5;
                            case 6
                                LvAX = A6;
                            case 7
                                LvAX = A7;
                            case 8
                                LvAX = A8;
                            case 9
                                LvAX = A9;
                            case 10
                                LvAX = A10;
                            case 11
                                LvAX = A11;
                            case 12
                                LvAX = A12;
                            case 13
                                LvAX = A13;
                            case 14
                                LvAX = A14;
                            case 15
                                LvAX = A15;
                        end
                        B = bar((d-1), L([5 6]), 'Parent',LvAX, 'EdgeColor','none',SeriesIndex=L(4),BarWidth=1);
                        %C = bar((d-1), L(6), 'Parent',Az, 'EdgeColor','none',SeriesIndex=L(4),BarWidth=0.1); hold(Az, 'on')
                    end
                catch err
                    unwrapErr(err)
                end
                if options.Text
                    avg = string(round(100*AVG,1));
                    Atxt = text(x, y, avg); FMTtext(Atxt);
                    num = string(NUM);
                    y = -ones(size(x))+0.1;
                    Ntxt = text(x, y, num); FMTtext(Ntxt);
                    if ~isempty(cell2mat(CROSS))
                        NE = ~cellfun(@isempty,CROSS);
                        x = x(NE); CROSS = CROSS(NE);
                        cross = string(cell2mat(CROSS));
                        y = -ones(size(x))+0.2;
                        try
                            Ctxt = text(x, y, cross); FMTtext(Ctxt);
                        catch err
                            unwrapErr(err);
                        end
                    end
                end
            end
            %NORMALIZE Level graphs between subjects
            Out = {f};
            fprintf("Plotted "+SUB+ "... etime: " + toc + " seconds.\n")
            function AxOUT = VertAxes()
                f = figure;
                t = tiledlayout(16,1,'TileSpacing','none', 'Padding','tight', 'Parent',f);
                AxOUT = nexttile(t);

            end
            function FMTAxis(AxIn)
                AxIn.YLim = [-0.55 0.05];
                AxIn.YTick = -1:0.25:0;
                AxIn.YTickLabel = string(0:25:100)+"%";
                AxIn.YMinorTick = "on";
                AxIn.YGrid = 1;
                AxIn.YMinorGrid = 1;
                AxIn.XLim = [min(Ddat.DayNums)-1 max(Ddat.DayNums)];
                xline(min(Ddat.DayNums):1:max(Ddat.DayNums), '-', 'Color',[0.7 0.7 0.7], 'Parent',AxIn)
                %hold(AxIn, 'on')
            end
        end
        function Out = PlotLevelGroupsByLevel(this, options)
            arguments
                this
                options.Sc
                options.Text logical = false
                options.Ani logical = false
            end
            this.sc = options.Sc;
            Ddat = sortrows(this.AnalyzedData.DayMM{this.sc}, "Ls");
            Ddat.DayNums=cell2mat(Ddat.DayNums);
            % try
            %     f = findobj('Type', 'figure');
            %     Ax = f.Children.findobj('Type', 'Axes');
            %     clo(Ax)
            % catch
            %     Ax = MakeAxis();
            % end
            %Ax.YLim = [min(Ddat.DayNums)-1 1];
            %Ax.XLim = [min(Ddat.DayNums)-1 max(Ddat.DayNums)];
            %yline(findgroups(Ddat.DayNums), '-', 'Color',[0.7 0.7 0.7])
            for L = unique(Ddat.Ls)'
                Ax = MakeAxis(); hold(Ax, "on"); Ax.Parent.Parent.Visible = 1;
                Ax.Title.String = this.Sub{this.sc}+" Level "+L+" Performance";
                xline(0:1:max(Ddat.DayNums), '-', 'Color',[0.7 0.7 0.7])
                yline(findgroups(Ddat.DayNums)-0.2, ':', 'Color',[0.5 0.5 0.5]) ; if options.Ani; drawnow; end
                Ax.YLim = [L-.57 L+0.03];
                wL = Ddat.Ls==L;
                Ld = Ddat.dayBin;
                for d = [Ddat.DayNums(wL)' ; findgroups(Ddat.DayNums(wL)')]
                    clear x Xrange y NUM AVG STD LevIdx tDAT DAT
                    xOff = (d(2)-1);
                    yOff = L-1;
                    Ax.XLim = [-0.5 d(2) ]; if options.Ani; drawnow; end
                    wD = Ddat.DayNums==d(1);
                    try
                        LevIdx = cellfun(@(x)x{11} ,Ld(wD), "UniformOutput", true, "ErrorHandler", @errorFuncNaN)';
                        AVG = cellfun(@(x)x{5}+yOff ,Ld(wD), "UniformOutput", true)';
                        NUM = cellfun(@(x)x{4} ,Ld(wD), "UniformOutput", true)';
                        STD = cellfun(@(x)x{6} ,Ld(wD), "UniformOutput", true)';
                    catch err
                        unwrapErr(err);
                    end
                    if numel(LevIdx)>1
                        1;
                    end
                    Xrange = normalize([LevIdx max(LevIdx)+1], "range");
                    Xrange = Xrange(1:end-1);
                    x = xOff+Xrange;
                    try
                        tDAT = [x ; AVG ; STD ; LevIdx];
                        tDAT(:, isnan(LevIdx) ) = [];
                        DAT = mat2cell( tDAT , 4, [ones( size(tDAT,2) ,1)] );
                    catch err
                        unwrapErr(err);
                    end
                    Plots = cellfun(@(x){plotLv(x)}, DAT);
                end
                %if options.Ani; drawnow; end
                a = 1;
                % if options.Text
                %     avg = string(round(100*AVG,1));
                %     Atxt = text(x, y, avg); FMTtext(Atxt);
                %     num = string(NUM);
                %     y = -ones(size(x))+0.1;
                %     Ntxt = text(x, y, num); FMTtext(Ntxt);
                %     if ~isempty(cell2mat(CROSS))
                %         NE = ~cellfun(@isempty,CROSS);
                %         x = x(NE); CROSS = CROSS(NE);
                %         cross = string(cell2mat(CROSS));
                %         y = -ones(size(x))+0.2;
                %         try
                %             Ctxt = text(x, y, cross); FMTtext(Ctxt);
                %         catch err
                %             err;
                %         end
                %     end
                % end
                this.filedir = fullfile(pwd, this.Sub{this.sc}, 'LevelGroups', "SinceLev"+L+"Grouped");
                title = "SinceLev"+L+"Grouped";
                this.SaveManyFigures(Ax.Parent.Parent,this.filedir+".pdf", Columns=max(Ddat.DayNums) , Rows=1 )
                pause(1)
            end
            if options.Ani; drawnow; end
            Out = Ax;




            function E = plotLv(In)
                xR = In(1);
                yL = In(2);
                std = In(3);
                Level = In(4);
                E = errorbar(xR, yL, std,'Parent',Ax, ...
                    'SeriesIndex', Level);
                S = scatter(xR, yL, 'filled', ...
                    'Marker', this.Shape_code{Level}, ...
                    'Parent',Ax, ...
                    'SeriesIndex', Level);
                %S.MarkerFaceColor = E.Color;
                %S.MarkerEdgeColor = E.Color;
                if Level == L
                    S.SizeData = 200;
                    S.AlphaData = 0.7;
                    E.CapSize = 0;
                    E.LineWidth = 5;
                else
                    S.SizeData = 75;
                    E.CapSize = 2;
                    E.LineWidth = 4;
                end
                %drawnow
            end
        end
        function t = PlotWeightAndWater(this, options)
            arguments
                this
                options.Save logical = false
            end
            for S = struct2cell(this.DayData)'
                try
                    Name = string(S{:}{1,3}.Settings(end).Subject);
                catch
                    try
                        Sets = cell2mat(S{:}{1,3}.Settings);
                        Names = {Sets.Animal_ID};
                        Name = string(Names{1});
                    catch err
                        Set = S{:}{1,1}.Settings;
                        Name = Set.Subject;
                    end
                end
                Daily = S{:}(:,3)';
                Settings = cellfun(@(x) x.Settings, Daily,'UniformOutput',false);
                Weight = cellfun(@(x) mode(double([x.Weight])), Settings, 'UniformOutput', true, 'ErrorHandler', @errorFuncNaN); %This should get the last value for each day
                Dates = cell2mat(S{:}(:,2)');
                Weight(isoutlier(Weight)) = deal(NaN);
                Water = cellfun(@(x)sum(x.Score),Daily);
                NewDates = cellfun(@(x) datetime(string(x), 'InputFormat', 'yyMMdd'), num2cell(Dates), 'UniformOutput', false);
                tickWindow = 1:3:numel(Weight);
                f = figure("Visible", "off");
                t = tiledlayout('flow','Padding','tight', 'TileSpacing','none', 'Parent',f);
                a = nexttile(t); hold(a, 'on');
                a.Title.String = Name+" Daily Weight (grams)";
                P = plot(1:numel(Weight), Weight, 'Parent', a);
                a.XTick = tickWindow;
                a.XTickLabel = string([NewDates{tickWindow}]);
                a.YLim = [0 max(P.YData)+2];
                a.PickableParts = "none";
                if options.Save
                    this.SaveManyFigures(f,Name+"Weight")
                end
                a = nexttile(t); hold(a, 'on');
                a.Title.String = Name+" Daily Fluid Intake (mL)";
                P = plot(1:numel(Water), Water*0.004, 'Parent', a);
                a.XTick = tickWindow;
                a.XTickLabel = string([NewDates{tickWindow}]);
                a.YLim = [0 max(P.YData)+0.5];
                a.PickableParts = "none";
                if options.Save
                    this.SaveManyFigures(f,Name+"Fluid")
                end
            end
        end
        function Out = PlotStimulusHistory(this)
            arguments
                this
            end
            data = this.loadedData;
            data(any(cellfun('isempty', data(:,[4 5])), 2),:) = [];
            score = cellfun(@(x)x.Score,data(:,3),'UniformOutput',false);
            data(:,end+1) = score;
            n = data(:,6);
            n = categorical(cellfun(@(x) x(1:7),n,'UniformOutput',false));
            %d = cell2mat(data(:,2));
            G = findgroups(n);
            Out = splitapply(@(x)SortStims(x), data, G);
            F = figure("MenuBar","none","Name", "Stimulus",'NumberTitle', 'off', 'Visible','off');F.Position = [1 31 362 1147]; F.Renderer = "painters"; F.InvertHardcopy = 'off';
            F.Color = 'k';
            Out = cellfun(@(x)PlotStims(x,F),Out);
            function Out = SortStims(In)
                stim = In(:,4);
                choice = In(:,5);
                %rawD = vertcat(In{:,[4 5]});
                getSizeDists = @(x)cellfun(@(x)size(x,1),x,'UniformOutput',false);
                getLvl = @(x)cellfun(@(x)min(cell2mat(x), [],2)+1,x,'UniformOutput',false);
                getTrialNum = @(x)cellfun(@(x)(1:numel(x))',x,'UniformOutput',false);
                NumDistractors = cellfun(@(x)getSizeDists(x),In(:,4),'UniformOutput',false);
                Levels = getLvl(NumDistractors);
                TrialNum = getTrialNum(Levels);
                D = [TrialNum Levels In(:,7) stim choice]';
                dc = 0;
                BigHist = struct();
                for Day = D
                    try
                        dc = dc+1;
                        DAYS = repelem({dc},numel(Day{1,:}),1);
                        dExpand = [];
                        EXPAND = struct();
                        try
                            dExpand = [DAYS num2cell(Day{1,:}) num2cell(Day{2,:}) num2cell(Day{3,:}) Day{4,:} Day{5,:}]';
                        catch
                            rows = (1:size(Day{5,:},1))';
                            dExpand = [DAYS(rows) num2cell(Day{1,:}(rows)) num2cell(Day{2,:}(rows)) num2cell(Day{3,:}(rows)) Day{4,:}(rows,:) Day{5,:}(rows,:)]';
                        end
                        EXPAND = cell2struct(dExpand, {'Day','TNum','Lev','Score','LStim','RStim','Outcome','ChoiceX','ChoiceY'});
                        if dc>1
                            BigHist =[BigHist;EXPAND];
                        else
                            BigHist = EXPAND;
                        end
                        % for t = dExpand
                        %     %TrialNum
                        %     %Level
                        %     %Left Stim
                        %     %Right Stim
                        %     %Outcome
                        %     % 6 & 7 are wheel position & time
                        %     %Plan:
                        %     % Call a plotting function to plot each stim, label outcome.
                        %
                        % end
                    catch err
                        unwrapErr(err);
                    end
                end
                HistT = struct2table(BigHist);
                S=split(HistT.Outcome);
                HistT = addvars(HistT,S(:,1),'NewVariableNames','Side');
                HistT = addvars(HistT,S(:,2),'NewVariableNames','Correct');
                HistT = sortrows(HistT,{'Lev','Score','Correct'},{'descend','ascend','ascend'});
                Out = {HistT};
            end
            function Out = PlotStims(In,F)
                T = tiledlayout(20,3, "TileSpacing","none","Padding","tight", "Parent",F);
                Sobj = BehaviorBoxVisualStimulus();
                Sobj.FinishLine = 0;
                Sobj.figpos = [];
                Sobj.InputType = 5;
                tc = 0;
                for t = table2cell(In)'
                    tc = tc+1;
                    if tc>20
                        MakeReport(F)
                        tc = 1;
                        clo(F)
                        T = tiledlayout(20,3, "TileSpacing","none","Padding","tight", "Parent",F);
                    end
                    [Sobj.fig, Sobj.LStimAx, Sobj.RStimAx, ~, Sobj.ChoiceAx] = Sobj.setUpFigure("StimHist",1,"T",T);
                    [L,R] = Sobj.ShowStimulusContour_Density("SH",t);
                    LL = Sobj.LStimAx.findobj('Type','Line');
                    RL = Sobj.RStimAx.findobj('Type','Line');
                    [LL.LineWidth] = deal(2);
                    [RL.LineWidth] = deal(2);
                end
            end
            function MakeReport(inFig)
                tic
                import mlreportgen.dom.*
                import mlreportgen.report.*
                enlarge = 4;
                AXES = inFig.findobj('Type','Axes');
                [AXES(:).Visible] = deal('off');
                inFig.InvertHardcopy = 'off';
                inFig.Renderer = "painters"; % To keep it as a vector
                rpt = Report('HexGridPlots', 'html');
                FigReporter = Figure(inFig);
                FigReporter.Scaling = "none";
                Img = Image(getSnapshotImage(FigReporter, rpt));
                Img.Height = string(enlarge*inFig.Position(4))+'px';
                Img.Width = string(enlarge*inFig.Position(3))+'px';
                append(rpt, Img);
                close(rpt)
                rptview(rpt)
                toc
            end
        end
        %Calculate functions
        function [Set, I] = structureSettings(~, Settings)
            try
                %Find settings, they have had many different names over the years...
                SetStr = ""; %Get the label for the settings (to go on top of the performance scatter)
                Include = 0;
                if isfield(Settings, 'Stimulus_side')
                    switch Settings.Stimulus_side %Settings are stored in the Settings structure, copied from BB when saving data.
                        case 1
                            SetStr = strcat(SetStr, '*');
                            Include = 1;
                        case 2
                            SetStr = strcat(SetStr, 'L');
                        case 3
                            SetStr = strcat(SetStr, 'R');
                        case 4
                            SetStr = strcat(SetStr, 'aRp');
                            Include = 1;
                        case 5
                            SetStr = strcat(SetStr, 'aRn');
                            Include = 1;
                        case 6
                            SetStr = strcat(SetStr, 'SB');
                        case 7
                            SetStr = strcat(SetStr, 's*');
                            Include = 1;
                        case 8 %Keyboard
                            SetStr = strcat(SetStr, 'K');
                            Include = 1;
                    end
                end
                if isfield(Settings, 'Stimulus_type') && Settings.Stimulus_type == 12
                    SetStr = strcat(SetStr, 'P');
                    Include = 0;
                end
                if isfield(Settings, 'TrainingChoices') && Settings.TrainingChoices ~=3
                    SetStr = strcat(SetStr, 'T');
                    Include = 0;
                end
                if isfield(Settings, 'Repeat_wrong') && Settings.Repeat_wrong
                    SetStr = strcat(SetStr, 'rw');
                    Include = 0;
                end
                %Airpuff?
                if isfield(Settings, 'Box_Air_Puff_Penalty') && Settings.Box_Air_Puff_Penalty
                    SetStr = strcat(SetStr, 'A');
                end
                Set = SetStr;
                I = Include;
            catch err
                unwrapErr(err)
            end
        end
        function [LRT, plotScore] = CalculateTH(~, isLeftTrial, Score)
            LRT = {find(isLeftTrial == 1 & Score ~=2), find(~isLeftTrial == 1 & Score ~=2), find(Score==2)};
            plotScore = Score;
            plotScore(plotScore==1) = 0.8;
            plotScore(plotScore==0) = 0.5;
            plotScore(plotScore==2) = 0.2;
        end
        function [SortData] = CalculateBP(this)
            Data = this.current_data_struct;
            try
                SortData = [];
                DayData = [];
                for Lev = Data.LevelGroups
                    rows = Data.Level == Lev & Data.Score ~= 2;
                    m = sum(rows);
                    if m==0
                        continue
                    end
                    try
                        levelTbl = [ Data.SmallBin(rows) Data.BigBin(rows) (1:m)' Data.Score(rows) Data.CodedChoice(rows) Data.TimeStamp(rows) Data.SetIdx(rows)]; %Makes array from table
                    catch
                        levelTbl = [ Data.SmallBin(rows)' Data.BigBin(rows)' (1:m)' Data.Score(rows)' Data.CodedChoice(rows)' Data.TimeStamp(rows)' Data.SetIdx(rows)'];
                    end
                    Sides = this.getSideBias(levelTbl(:,2), levelTbl(:,5) );
                    trialIdcs = accumarray(levelTbl(:,2), levelTbl(:,3), [], @(x)x(end));
                    timeStamps = accumarray(levelTbl(:,2), levelTbl(:,6), [], @(x)x(end));
                    SetIdcs = accumarray(levelTbl(:,2), levelTbl(:,7), [], @mode); %Get the mode of the SetIdx for each large bin
                    Perf = this.binnedAVG(levelTbl(:,[1 2]), levelTbl(:,4));
                    [m,~] = size(Perf);
                    LevData = [repmat(Lev, size(Perf,1), 1) Perf(1:m, :) Sides(1:m, :) trialIdcs(1:m, :) timeStamps(1:m, :) SetIdcs]; % (1:m, :) term trims off incomplete bins and timeouts.
                    DayData = [DayData ; LevData];
                end
                SortData = sortrows(DayData, 8);
            catch err %Keeps breaking because not all fields of Data are rows or columns
                unwrapErr(err)
            end
        end
        function [Out] = getSideBias(~, Idx, whatDecision)
            switch nargin
                case 2 %only side choice data supplied, make ID vector to match the input
                    whatDecision = Idx;
                    Idx = ones(size(whatDecision));
            end
            [~, I] = findgroups(Idx');
            Out = zeros(size(I',1),4);
            LeftCorrect = accumarray(Idx, whatDecision==1, [], @sum);
            LeftTotal = accumarray(Idx, sum(whatDecision==[1 3],2), [], @sum);
            RightCorrect = accumarray(Idx, whatDecision==2, [], @sum);
            RightTotal = accumarray(Idx, sum(whatDecision==[2 4],2), [], @sum);
            T = accumarray(Idx, sum(whatDecision==[5 6],2), [], @sum);
            SB = (RightCorrect./RightTotal)*(0.5)-(LeftCorrect./LeftTotal)*(0.5);
            for i = find(isnan(SB'))
                if RightCorrect(i) == 0
                    SB(i) = 0.5;
                elseif LeftCorrect(i) == 0
                    SB(i) = -0.5;
                end
            end
            Out(:,1:3) = [LeftTotal T RightTotal];
            Out(:,4) = SB;
        end
        function [Out] = binnedAVG(this, index, data)
            binSize = this.BB/this.SB;
            try
                [~, ~, b] = histcounts( 1:max(index(:,1)), [1:binSize:max(index(:,1)) inf]);
                AVG = accumarray(index(:,2), data, [], @mean);
                STD = accumarray(b', accumarray(index(:,1), data, [], @mean), [], @std);
                Out = [AVG STD];
            catch
                Out = [0 0];
            end
        end
        function SBt = CalculateSB(~, D)
            try
                SBt = cell(1, numel(D.LevelGroups));
                lc = 0;
                for L = D.LevelGroups
                    lc = lc + 1;
                    SBl = zeros(2, sum(D.TrialNum~=0 & D.Level==L));
                    LS = D.CodedChoice(D.Level == L);
                    LS = LS(LS ~= 5 & LS ~= 6);
                    SBl(2,:) = D.TrialNum(D.Level==L & D.TrialNum~=0)';
                    tn = 1:numel(LS);
                    if isempty(tn)
                        continue
                    end
                    for t = tn
                        if t >= 21 %After 20 trials use the last 20
                            dat = t-19:t;
                        else %Before that use every trial but correct the extreme value for the short interval
                            dat = 1:t;
                        end
                        LeftCorrect = sum(LS(dat)==1);
                        LeftWrong = sum(LS(dat)==3);
                        LeftTotal = LeftWrong + LeftCorrect;
                        RightCorrect = sum(LS(dat)==2);
                        RightWrong = sum(LS(dat)==4);
                        RightTotal = RightWrong + RightCorrect;
                        Lside = sum(D.isLeftTrial(dat))/length(D.isLeftTrial(dat));
                        Rside = sum(~D.isLeftTrial(dat))/length(D.isLeftTrial(dat));
                        SB = (RightWrong/RightTotal)*(0.5)-(LeftWrong/LeftTotal)*(0.5);
                        %SB = (RightWrong/RightTotal)*(LeftCorrect/LeftTotal)*(0.5)-(LeftWrong/LeftTotal)*(RightCorrect/RightTotal)*(0.5);
                        if isnan(SB) %If they have neglected a side for the whole set of 20, give maximum bias.
                            if LeftTotal == LeftCorrect || RightTotal == RightCorrect
                                SB = 0;
                            elseif LeftTotal == 0
                                SB = 0.5;
                            elseif RightTotal == 0
                                SB = -0.5;
                            end
                            %             elseif abs(SB) == 0.5
                            %                 if sign(SB) > 0 %positive 1 if SB is positive
                            %                     SB = (RightWrong - LeftWrong)/(LeftTotal + RightTotal);
                            %                 else %negative 1 if SB is neg
                            %                     SB = (RightWrong - LeftWrong)/(LeftTotal + RightTotal);
                            %                 end
                        end
                        if t < 21 %Correct for short interval
                            SB = SB*(t/10);
                        end
                        SBl(1,t) = SB;
                    end
                    SBt{lc} = SBl;
                end
            catch err
                unwrapErr(err)
            end
        end
        function [lvls, Avgs] = CalculateLP(this, Lev, Score)
            nt = Score'~=2;
            lvls = this.current_data_struct.LevelGroups;
            if numel(lvls)==1
                y=lvls;
            else
                y=max(lvls);
            end
            Avgs = num2cell(nan(6, y));
            Avgs(6,:) = num2cell(1:y);
            Avgs(5,:) = deal({0});
            for L = lvls
                wlv = Lev'==L & nt;
                scre = Score(wlv)';
                lwin = 1:numel(scre);
                [~,~,SBidx] = histcounts(lwin, [1:this.SB:max(lwin) inf]); %Break the big bin into these smaller bins
                savg = accumarray(SBidx', scre, [], @mean);
                Avgs{1,L} = mean(scre);
                Avgs{2,L} = savg;
                Avgs{3,L} = std(savg);
                try
                    Avgs{4,L} = -log10(binocdf(sum(scre), numel(scre),0.5, 'upper'));
                end
                Avgs{5,L} = sum(wlv);
            end
            unseen = [Avgs{5,:}] == 0;
            Avgs(:,unseen) = [];
        end
        %Setup figures to display data
        function Axes = CreateDailyGraphs(this,P)
            %Create the TiledLayout in the Panel for all of the graphs...
            r = 5;
            c = 5;
            TL = tiledlayout(P, r, c, ...
                'Padding','tight', ...
                'TileSpacing','tight');
            % Create Binned Perf
            BP = nexttile(TL, [1 4]);
            BP.Tag = 'Axes_BinnedPerf';
            %title(BP, 'Binned Performance')
            BP.Toolbar.Visible = 'off';
            BP.TickLabelInterpreter = 'none';
            BP.YLim = [0 1];
            BP.TickLength = [0 0];
            %BP.YTick = [0 0.5 0.75 1];
            %BP.YTickLabelRotation = 90;
            %BP.YTickLabel = {''; '50%'; '75%'; ''};
            BP.YGrid = 'on';
            BP.XTick = [];
            BP.YTick = [];
            BP.NextPlot = 'add';
            BP.Box = 'off';
            %BP.BoxStyle = 'full';
            BP.PickableParts = 'none';

            % Create LP
            LP = nexttile(TL, [1 1]);
            LP.Tag = 'Axes_LevelCount';
            %title(LP, 'Level Performance')
            LP.Toolbar.Visible = 'off';
            LP.YLim = [0 1];
            LP.XTick = [];
            LP.YTick = [];
            %LP.YTick = [0 0.1 0.5 0.75 1];
            %LP.YTickLabelRotation = 90;
            %LP.YTickLabel = {''; '#'; '50%'; '75%'; ''};
            LP.YGrid = 'on';
            LP.TickDir = 'none';
            LP.NextPlot = 'add';
            LP.Box = 'off';
            %LP.BoxStyle = 'full';
            LP.PickableParts = 'none';

            % Create axes8
            DT = nexttile(TL, [2 5]);
            DT.Tag = 'Axes_AllLevelPerf';
            %title(DT, 'Performance by Trial')
            DT.Toolbar.Visible = 'off';
            DT.TickLength = [0 0];
            DT.XTick = [];
            DT.YTick = [];
            DT.NextPlot = 'add';
            DT.Box = 'off';
            %DT.BoxStyle = 'full';
            DT.PickableParts = 'none';

            %             % Create TH
            %             TH = nexttile(TL, [1 5]);
            %             TH.Tag = 'Axes_TrialHistory';
            %             %title(TH, 'Trial History')
            %             TH.Toolbar.Visible = 'off';
            %             TH.YLim = [0 1];
            %             TH.TickLength = [0 0];
            %             TH.YTick = [0.2 0.5 0.8];
            %             TH.YTickLabelRotation = 0;
            %             %TH.YTickLabel = {'T'; 'W'; 'C'};
            %             TH.XTick = [];
            %             TH.YTick = [];
            %             TH.NextPlot = 'add';
            %             TH.Box = 'off';
            %             %TH.BoxStyle = 'full';
            %             TH.HitTest = 'off';
            %             TH.PickableParts = 'none';

            % Create SB
            SB = nexttile(TL, [1 5]);
            SB.Tag = 'Axes_SideBias';
            %title(SB, 'Side Bias History')
            SB.Toolbar.Visible = 'off';
            SB.YLim = [0 1];
            SB.TickLength = [0 0];
            SB.XTick = [];
            SB.YTick = [];
            SB.NextPlot = 'add';
            SB.Box = 'off';
            %SB.BoxStyle = 'full';
            SB.PickableParts = 'none';

            % Create Binomial by trial
            BN = nexttile(TL, [1 5]);
            BN.Tag = 'Axes_Binomial';
            %title(BN, 'Side Bias History')
            BN.Toolbar.Visible = 'off';
            BN.YLim = [0 1];
            BN.TickLength = [0 0];
            BN.XTick = [];
            BN.YTick = [];
            BN.NextPlot = 'add';
            BN.Box = 'off';
            %BN.BoxStyle = 'full';
            BN.PickableParts = 'none';

            %             % Create axes6
            %             ST = nexttile(TL, [1 1]);
            %             ST.Tag = 'Axes_TimeToStart';
            %             title(ST, 'Time to Start')
            %             ST.Toolbar.Visible = 'off';
            %             ST.TickLength = [0 0];
            %             ST.XTick = [];
            %             ST.YTick = [];
            %             ST.NextPlot = 'add';
            %             ST.Box = 'on';
            %             ST.BoxStyle = 'full';
            %             ST.PickableParts = 'none';

            %             % Create axes7
            %             RT = nexttile(TL, [1 1]);
            %             RT.Tag = 'Axes_ResponseTime';
            %             title(RT, 'Response Time')
            %             RT.Toolbar.Visible = 'off';
            %             RT.TickLength = [0 0];
            %             RT.XTick = [];
            %             RT.YTick = [];
            %             RT.NextPlot = 'add';
            %             RT.Box = 'on';
            %             RT.BoxStyle = 'full';
            %             RT.PickableParts = 'none';

            for a = P.Children.Children'
                Axes.(erase(a.Tag, 'Axes_')) = a; %Make the axes structure
            end
            drawnow
        end
        %Setup figures to display data
        function Axes = CreateAllTimeGraphs(this,P)
            %Create the TiledLayout in the Panel for all of the graphs...
            r = 4;
            c = 5;
            TL = tiledlayout(P, r, c, ...
                'Padding','tight', ...
                'TileSpacing','tight');
            % Create Binned Perf
            BP = nexttile(TL, [1 4]);
            BP.Tag = 'Axes_BinnedPerf';
            %title(BP, 'Binned Performance')
            BP.Toolbar.Visible = 'off';
            BP.TickLabelInterpreter = 'none';
            BP.YLim = [0 1];
            BP.TickLength = [0 0];
            %BP.YTick = [0 0.5 0.75 1];
            %BP.YTickLabelRotation = 90;
            %BP.YTickLabel = {''; '50%'; '75%'; ''};
            BP.YGrid = 'on';
            BP.XTick = [];
            BP.YTick = [];
            BP.NextPlot = 'add';
            BP.Box = 'off';
            %BP.BoxStyle = 'full';
            BP.PickableParts = 'none';

            % Create LP
            LP = nexttile(TL, [1 1]);
            LP.Tag = 'Axes_LevelCount';
            %title(LP, 'Level Performance')
            LP.Toolbar.Visible = 'off';
            LP.YLim = [0 1];
            LP.XTick = [];
            LP.YTick = [];
            %LP.YTick = [0 0.1 0.5 0.75 1];
            %LP.YTickLabelRotation = 90;
            %LP.YTickLabel = {''; '#'; '50%'; '75%'; ''};
            LP.YGrid = 'on';
            LP.TickDir = 'none';
            LP.NextPlot = 'add';
            LP.Box = 'off';
            %LP.BoxStyle = 'full';
            LP.PickableParts = 'none';

            % Create axes8
            DT = nexttile(TL, [2 5]);
            DT.Tag = 'Axes_AllLevelPerf';
            %title(DT, 'Performance by Trial')
            DT.Toolbar.Visible = 'off';
            DT.TickLength = [0 0];
            DT.XTick = [];
            DT.YTick = [];
            DT.NextPlot = 'add';
            DT.Box = 'off';
            %DT.BoxStyle = 'full';
            DT.PickableParts = 'none';

            %             % Create TH
            %             TH = nexttile(TL, [1 5]);
            %             TH.Tag = 'Axes_TrialHistory';
            %             %title(TH, 'Trial History')
            %             TH.Toolbar.Visible = 'off';
            %             TH.YLim = [0 1];
            %             TH.TickLength = [0 0];
            %             TH.YTick = [0.2 0.5 0.8];
            %             TH.YTickLabelRotation = 0;
            %             %TH.YTickLabel = {'T'; 'W'; 'C'};
            %             TH.XTick = [];
            %             TH.YTick = [];
            %             TH.NextPlot = 'add';
            %             TH.Box = 'off';
            %             %TH.BoxStyle = 'full';
            %             TH.HitTest = 'off';
            %             TH.PickableParts = 'none';

            % Create SB
            SB = nexttile(TL, [1 5]);
            SB.Tag = 'Axes_SideBias';
            %title(SB, 'Side Bias History')
            SB.Toolbar.Visible = 'off';
            SB.YLim = [0 1];
            SB.TickLength = [0 0];
            SB.XTick = [];
            SB.YTick = [];
            SB.NextPlot = 'add';
            SB.Box = 'off';
            %SB.BoxStyle = 'full';
            SB.PickableParts = 'none';

            %             % Create axes6
            %             ST = nexttile(TL, [1 1]);
            %             ST.Tag = 'Axes_TimeToStart';
            %             title(ST, 'Time to Start')
            %             ST.Toolbar.Visible = 'off';
            %             ST.TickLength = [0 0];
            %             ST.XTick = [];
            %             ST.YTick = [];
            %             ST.NextPlot = 'add';
            %             ST.Box = 'on';
            %             ST.BoxStyle = 'full';
            %             ST.PickableParts = 'none';

            %             % Create axes7
            %             RT = nexttile(TL, [1 1]);
            %             RT.Tag = 'Axes_ResponseTime';
            %             title(RT, 'Response Time')
            %             RT.Toolbar.Visible = 'off';
            %             RT.TickLength = [0 0];
            %             RT.XTick = [];
            %             RT.YTick = [];
            %             RT.NextPlot = 'add';
            %             RT.Box = 'on';
            %             RT.BoxStyle = 'full';
            %             RT.PickableParts = 'none';

            for a = P.Children.Children'
                Axes.(erase(a.Tag, 'Axes_')) = a; %Make the axes structure
            end
        end
        %save data when done, give unique name for stimulus, input, etc.
        function SaveAllData(this)
            fakeNames = {'w', 'W'};
            if any(strcmp(num2str(this.Setting_Struct.Subject), fakeNames)) || any(strcmp(this.Setting_Struct.Strain, fakeNames))
                return; % Do not save if using fake data names
            end
            D = string(datetime(this.Data_Object.start_time, "Format", "yyMMdd_HHmmss"));
            stim = erase(this.app.Stimulus_type.Value, ' ');
            input = this.app.Box_Input_type.Value;
            Sub = this.Setting_Struct.Subject;
            Str = this.Data_Object.Str;
            savefolder = fullfile(this.Data_Object.filedir);
            saveasname = join([D Sub Str stim input], '_');
            [newData] = this.getDataToSave();
            newData.SetUpdate = this.SetUpdate;
            nonEmptyRows = any(~cellfun(@isempty, this.StimHistory'))';
            newData.StimHist = this.StimHistory(nonEmptyRows,:);
            rmv = {'GUI_numbers', 'encoder'};
            for r = rmv
                try
                    Settings = rmfield(Settings, r);
                end
            end
            if this.Box.Input_type == 6
                newData.wheel_record = this.wheelchoice_record;
                newData.wheel_record(any(cellfun(@isempty, newData.wheel_record)'),:) = [];
            end
            dateStr = char(datetime(this.start_time, 'Format', 'yyMMdd_HHmmss'));
            newData.Settings = Settings;
            set(this.message_handle,'String',[ 'Saving data as: ' gui_save_string '.mat']);
            if isscalar(this.SetUpdate) % Settings never changed during the session.
                newData.SetStr = this.SetStr;
                newData.Include = repmat(this.Include, size(newData.TimeStamp));
                newData.SetIdx = repmat(this.SetIdx, size(newData.TimeStamp));
            elseif numel(this.SetUpdate) > 1
                newData.SetStr =  this.SetStr;
                Idcs = unique([cell2mat(this.SetUpdate) length(newData.TimeStamp)]);
                [~, ~, newData.SetIdx] = histcounts(1:length(newData.TimeStamp), Idcs);
                newData.Include = this.Include(newData.SetIdx);
            end
            newData.Weight = this.Setting_Struct.Weight;
            nonEmptyRows = any(~cellfun(@isempty, this.StimHistory'))';
            newData.StimHist = this.StimHistory(nonEmptyRows, :);
            Notes = this.GuiHandles.NotesText.String;
            try
                try
                    save([savefolder, saveasname], 'Settings', 'newData', 'Text')
                    this.saveFigure(this.graphFig, savefolder, saveasname)
                    dispstring = ['Data saved as: ', saveasname];
                    fprintf([dispstring, '\n']);
                    set(this.message_handle,'String',dispstring);
                catch err
                    this.unwrapError(err)
                    [file,path] = uiputfile(pwd , 'Choose folder to save training data' , saveasname);
                    exportapp(this.app.figure1, [path file '.jpg'])
                    save([path file],  'Settings', 'newData', 'Text')
                end
            catch err
                this.unwrapError(err)
            end
            this.graphFig.MenuBar = 'figure';
        end
        function saveFigure(~, fig, folder, name)
            % saveFigure Save the given figure to a specified folder as a PDF file.
            %   saveFigure(fig, folder, name)
            %   fig    - Handle to the MATLAB figure to be saved.
            %   folder - Destination folder where the figure should be saved.
            %   name   - The name to use for the saved PDF file.
            name = erase(name, '.mat');
            % Create the complete filename
            fullPath = fullfile(folder, name + ".pdf");

            % Set figure properties before saving
            set(fig, 'Units', 'inches', 'PaperUnits', 'inches', 'PaperSize', [11 8.5], ...
                'PaperPositionMode', 'auto', 'PaperPosition', [0 0 11 8.5]);

            % Save the figure as a PDF using exportgraphics
            exportgraphics(fig, fullPath, 'ContentType', 'vector', 'Resolution', 600);
        end
        function SaveManyFigures(this, fig, filename, options)
            arguments
                this
                fig
                filename string
                options.format string = ".pdf"
                options.Columns = 30     %Inches across
                options.Rows = 5 %Inches high
                options.SameFolder logical = false
            end
            if isempty(fig) % Put empty brackets [] for the figure
                tic
                FIG = findobj('Type','figure');
                FIG(contains({FIG.Name}, 'BehaviorBox')) = [];
                if all({FIG.Name}=="")
                    Names = {FIG.Number};
                else
                    Names = {FIG.Name};
                end
                Names = strrep(Names, '<0.', '-below-');
                Names = strrep(Names, ' ', '-');
                if options.SameFolder %Make a folder using filename to save all files
                    SavePathName = fullfile(this.filedir, filename, string(Names)'+filename);
                    if ~isfolder(fullfile(this.filedir, filename))
                        mkdir(fullfile(this.filedir, filename))
                    end
                else %Save in the mouse's folder
                    SavePathName = fullfile(this.filedir, string({FIG.Name})', filename);
                    if ~isfolder(fullfile(this.filedir, string({FIG.Name})'))
                        mkdir(fullfile(this.filedir, string({FIG.Name})'))
                    end
                end
                c = 0;
                for f = FIG'
                    c = c+1;
                    fprops = this.getFigProps(f, options);
                    this.SvFig(SavePathName(c),fprops)
                end
                fprintf("Saved "+numel(FIG)+ " files... etime: " + toc + " seconds.\n")
                return
            end
            %winopen(SaveAsName)
            close(fig)
        end
        function SvFig(~, Name, Props, options)
            arguments
                ~
                Name
                Props
                options.format = ".pdf"
            end
            if options.format == ".pdf"
                print(Name, Props, '-dpdf', ...
                    '-vector', ...
                    '-fillpage')
            end
        end
        function [g, groups] = inspectAllSettings(allData)
            x = cellfun(@(x) x.Settings, allData(:,3), 'UniformOutput', false); %get all the settings in a cell
            y = cellfun(@(x) x{:}, x, 'UniformOutput', false); %get the settings
            z = cellfun(@fieldnames, y, 'UniformOutput', false);
            names = vertcat(z{:});
            [g,groups] = findgroups(names);
        end
    end %end methods
    methods(Static)
        function setGUI(Data, GUINums)
            try
                GUINums.right = num2str(sum(Data.CodedChoice == [2 ; 4],'all')); %Left Responses
                GUINums.left = num2str(sum(Data.CodedChoice == [1 ; 3],'all')); %Right Responses
                GUINums.rewards = num2str(sum(Data.Score==1));
                GUINums.total_correct = [num2str( 100*round(sum( Data.Score(Data.Score~=2))/numel(Data.Score(Data.Score~=2)),2 ) ) '%'];
                %Add a loop to go thru the handles:
            end
        end
        function [struct_out] = new_init_data_struct() %Initialize data structure
            %Use these names to match the analysis scripts:
            structOrder = {
                'TrialNum',
                'SmallBin',
                'BigBin',
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
                'LevelGroups',
                'StimHist',
                'wheel_record',
                'Include'};
            struct_out = struct();
            for i = structOrder'
                struct_out.(i{:}) = [];
            end
        end
        function [Out] = getLevelTNums(Tbl)
            [~,Levels] = findgroups(Tbl.Level');
            for L = Levels
                r = Tbl.Level == L & Tbl.Score ~= 2; %& Tbl.Include == 1;
                Tbl.LvlTrialNum(r,:) = (1:sum(r))';
            end
            TotalTrialNum = zeros(size(Tbl.Level));
            Out = addvars(Tbl, TotalTrialNum, 'After','LvlTrialNum');
            Out.TotalTrialNum = (1:numel(Tbl.Level))';
        end
        function [fig] = getFigProps(fig, options)
            figProps = struct;
            figProps.units = 'inches';
            figProps.format = 'pdf';
            figProps.Width = num2str(options.Columns);
            figProps.Height = num2str(options.Rows);
            figProps.Renderer = 'painters';
            figProps.Resolution = '600';
            set(fig, 'PaperUnits', 'inches', 'PaperPositionMode', 'auto', 'PaperSize', ...
                [str2double(figProps.Width) str2double(figProps.Height)]);
        end
        function unwrapError(err)
            getReport(err, "extended")
        end
    end
end