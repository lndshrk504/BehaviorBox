classdef BehaviorBoxData < handle
    % 4.27.23
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
                options.load logical = true;
                options.analyze logical = true;
                options.plot logical = false;
                options.find logical = false;
            end
            %Apply inputs
            b = properties(this);
            o = fieldnames(options);
            for n = b(matches(b,o))'
                try
                    this.(n{:}) = options.(n{:});
                catch
                end
            end
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
                end
                if options.plot
                    if numel(this.Sub)>1
                        this.plotMM();
                        this.plotLvByDayOneAxis();
                    else
                        f = this.plotLvByDayOneAxis();
                        f.Visible = 1;
                    end
                end
            end
            %Make fields
            this.current_data_struct = this.new_init_data_struct();
        end
        function this = updateBBData(this, varargin)
            for pair = reshape(varargin, 2, [])
                try
                    this.(pair{1}) = pair{2};
                catch
                    error('%s is not a recognized parameter name', pair{1})
                end
            end
        end
        %INPUT INTERFACE FUNCTIONS ==== %log all activity here, which then gets passed to organize
        function GetStartTime(this)
            this.start_time = clock; %Start time is after the mouse begins the first trial
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
            addStruct = struct();
            addStruct.Score = Score;
            addStruct.Level = Level;
            addStruct.isLeftTrial = isLeftTrial;
            addStruct.CodedChoice = CodedChoice;
            addStruct.RewardPulses = RewardPulses;
            addStruct.InterTMal = InterTMal;
            addStruct.DuringTMal = DuringTMal;
            addStruct.TrialStartTime = TrialStartTime;
            addStruct.ResponseTime = ResponseTime;
            addStruct.DrinkTime = DrinkTime;
            addStruct.SideBias = SideBias;
            addStruct.BetweenTrialTime = BetweenTrialTime;
            addStruct.SetIdx = SetIdx;
            addStruct.SetStr = SetStr;
            this.current_data_struct = this.addDataRow(addStruct);
            %this.LevelHist.LastScores{addStruct.Level}(end+1) = addStruct.Score;
            %this.LevelHist.MM = cellfun(@(x)this.LevelMMAnalysis(x), this.LevelHist.LastScores, "ErrorHandler",@errorFuncNaN);
        end
        function addStimEvent(this, ~) %Get the timestamp of when the stimulus appeared
            this.current_data_struct.TimeStamp(end+1) = etime(clock,  this.start_time)/60; %elapsed time in minutes since starting first trial
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
                    %err
                end
            end
            data = this.CleanData();
        end
        %Setup functions ==== %These functions help with plotting the data in the BB window
        %Load data file functions
        function [subfiledir, fds] = GetFiles(this)
            fds = [];
            %Do an initial search for this mouse
            startpath = fullfile(getFilePath(), this.Inv,this.Inp, '**', '*');
            dirlist = dir(startpath);
            dirlist = dirlist([dirlist.isdir] & ...
                ~contains({dirlist.name}, {'.', 'settings', 'alltime', 'Rescued'}, 'IgnoreCase',true) ...
                & contains({dirlist.name}, this.Sub, "IgnoreCase",true));
            [a,b]=findgroups({dirlist.folder});
            dirPath = cellfun(@(x) fullfile(b{:}, x), {dirlist.name} , 'UniformOutput', false);
            filelist = dir(fullfile(getFilePath(), this.Inv,this.Inp, '**', '*.mat'));
            filelist = filelist(contains({filelist.name}, this.Sub) & ~contains({filelist.name}, 'settings', 'IgnoreCase',true));
            switch 1
                %Any files?
                case any(contains({filelist.name}, this.Sub))
                    [subfiledir, fds] = makefiles(dirPath);
                    %Any folders but no files?
                case any(contains({dirlist.name}, this.Sub)) && sum(contains({dirlist.name}, this.Sub)) == 1
                    dirlist = dirlist(contains({dirlist.name}, this.Sub));
                    newpath = dirlist.folder;
                    tree = split(dirlist.folder, filesep);
                    this.Str = tree{end};
                    subfiledir = fullfile(newpath, this.Sub{:}); %Leave fds empty
                otherwise
                    if ~isempty(this.Str)
                        newpath = join([startpath this.Str this.Sub], filesep);
                        if isfolder(newpath)
                            fprintf("Found "+numel(this.Sub)+" subject(s) matching user input:\n - "+cell2mat(join(this.Sub, "\n - "))+"\n")
                        else
                            mkdir(newpath)
                            fprintf("New strain, folders will be created when saving data...\n")
                            subfiledir = newpath;
                        end
                    else
                        newpath = join([startpath this.Str this.Sub], filesep);
                        if isfolder(newpath)
                            fprintf("Found "+numel(this.Sub)+" subject(s) matching user input:\n - "+cell2mat(join(this.Sub, "\n - "))+"\n")
                        else
                            %mkdir(newpath)
                            fprintf("New strain, folders will be created when saving data...\n")
                            subfiledir = newpath;
                        end
                    end
            end
            if ~isempty(fds)
                fprintf("Found "+numel(fds.Files)+" files for "+numel(this.Sub)+" subject(s) matching user input:\n - "+cell2mat(join(this.Sub, "\n - "))+"\n")
            end
            function [SUBDIR, FDS] = makefiles(direc)
                try
                    FDS = fileDatastore(direc, "ReadMode", "file" ,"ReadFcn", @readFcn, "FileExtensions", ".mat", "IncludeSubfolders",false);
                catch
                    FDS = fileDatastore(direc, "ReadMode", "file" ,"ReadFcn", @readFcn, "FileExtensions", ".mat", "IncludeSubfolders",false);
                    FDS.Files = FDS.Files(~contains(FDS.Files, {'Settings'}, "IgnoreCase",true));
                    FDS.Files = FDS.Files(~contains(FDS.Files, {'rescue'}, "IgnoreCase",true));
                    FDS.Files = FDS.Files(contains(FDS.Files, this.Sub));
                end
                forest = cellfun(@(x) split(x,filesep), FDS.Files', 'UniformOutput', false);
                [~,this.Sub]=findgroups(cellfun(@(x) x(end-1), forest));
                [~,strains]=findgroups(cellfun(@(x) x(end-2), forest));
                this.Str = cell2mat(strains);
                if numel(this.Sub)>1
                    w = 2;
                else
                    w = 1;
                end
                file = forest{1}(1:end-w);
                SUBDIR = fullfile(file{:});
            end
        end
        function [varargout] = loadFiles(this)
            if isempty(this.fds)
                return
            end
            t1 = datetime("now");
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
            time = seconds(datetime('now') - t1);
            fprintf("Loaded... etime: " + time + " seconds.\n")
            if nargout >= 1
                varargout{1} = allData;
            end
        end
        function [varargout] = CombineDays(this)
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
                this.DayData.((mouse)) = dayData.((mouse));
                % StimHist = allData(w,4);
                % EmptyIdx = cellfun('isempty', StimHist);
                % L = cellfun(@(x) x.Level ,allData(:,3) , 'UniformOutput',false);
                % L(EmptyIdx) = [];
                % StimHist(EmptyIdx) = [];
                % getLev = @(x)cellfun(@(x) size(x), x, 'UniformOutput',false);
                % Lev = cellfun(@(x) getLev(x), StimHist, 'UniformOutput', false);
                c = 0;
                for d = days
                    Out = struct();
                    bigSession = struct;
                    sessions = struct;
                    StimHist = [];
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
                    catch Err
                        bigSession.Include = ones(size(bigSession.Score)); %For any data that was rescued, there are no settings
                    end
                    bigSession.SetStr = SetStr;
                    this.current_data_struct = bigSession;
                    bigSession = this.CleanData;
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
        function [varargout] = AnalyzeAllData(this)
            t1 = datetime('now');
            Out = struct;
            numSubs = size(this.Sub);
            Out.TrialTbls = cell(numSubs);
            Out.SplitTbls = cell(numSubs);
            Out.LevelTbls = cell(numSubs);
            Out.DayMM = cell(numSubs);
            Out.LevelMM = cell(numSubs);
            sc = 0;
            for S = struct2cell(this.DayData)'
                sc = sc + 1;
                data = S{:}(:,3);
                %[g, groups] = inspectAllSettings(SData)
                %names = cellfun(@(x)fieldnames(x),data,'UniformOutput',false);
                SDData = struct();
                for f = {'Date','TrialNum','LvlTrialNum','BigBin','SmallBin','TimeStamp','Score','Level','isLeftTrial','CodedChoice','Include'}
                    fn = f{:};
                    SDData.(fn) = cell2mat(cellfun(@(x)x.(fn), data, 'UniformOutput', false));
                end
                % SDData = cell2mat(data);
                % TrialTblStruct = struct();
                % for f = fieldnames(SDData)'
                %     try
                %         n = f{:};
                %         TrialTblStruct.(n) = vertcat(SDData.(n));
                %     end
                % end
                % TrialTblStruct = rmfield(TrialTblStruct, {'SetStr', 'Settings'});
                % trialTbl = struct2table(TrialTblStruct);
                trialTbl = struct2table(SDData);
                trialTbl.Level = round(trialTbl.Level);
                trialTbl = this.getLevelTNums(trialTbl);
                Out.TrialTbls{sc} = trialTbl;
                this.trial_table = trialTbl;
                [allDates, Ds] = findgroups(trialTbl.Date');
                Out.SplitTbls{sc} = cellfun(@SplitDayLevels, num2cell(Ds), "UniformOutput", false);
                Out.DayMM{sc} = table;
                try
                    [G,Out.DayMM{sc}.Ds,Out.DayMM{sc}.Ls] = findgroups(trialTbl.Date, trialTbl.Level);
                    Out.DayMM{sc}.DayNums = num2cell(findgroups(Out.DayMM{sc}.Ds));
                    Out.DayMM{sc}.dayBin = splitapply(@(x){this.DayBin(x)}, [trialTbl.Score trialTbl.Level trialTbl.Date allDates'], G);
                    Out.DayMM{sc} = sortrows(Out.DayMM{sc}, {'Ls'});
                catch Err
                    Err
                end
                [G, ~] = findgroups(trialTbl.Level);
                Levels = num2cell(1:20);
                Out.LevelTbls{sc} = cellfun(@(x){trialTbl(trialTbl.Level==x,:)}, Levels, "UniformOutput", true);
                this.LevelHist.LastScores = cellfun(@(x){trialTbl(trialTbl.Level==x,:).Score(end-100:end)}, Levels, "ErrorHandler",@errorFuncZeroCell);
                this.LevelHist.MM = cellfun(@(x)this.LevelMMAnalysis(x), this.LevelHist.LastScores, "ErrorHandler",@errorFuncNaN);
                Out.LevelMM{sc} = splitapply(@(x)this.LevelMMAnalysis(x), [trialTbl.Score allDates'], G)';
                Out.LevelMM{sc}(cellfun(@isempty,Out.LevelMM{sc})) = [];
                MaxLPerf = cellfun(@(x)max(x(:,1)), Out.LevelMM{sc}, "ErrorHandler", @errorFuncZeroCell, 'UniformOutput', true);
                this.MaxLevel = find(MaxLPerf>=0.8, 1, 'last')+1;
            end
            this.AnalyzedData = Out;
            this.current_data_struct = this.new_init_data_struct();
            time = seconds(datetime('now') - t1);
            fprintf("Analyzed... etime: " + time + " seconds.\n")
            if nargout >= 1
                varargout{1} = Out;
            end
            function Out = SplitDayLevels(D)
                [~, Ls] = findgroups(trialTbl.Level');
                r = trialTbl.Date==D;
                Dtbl = trialTbl(r,:);
                Out = Dtbl;
                %Out = cellfun(@(x)Dtbl(Dtbl.Level==x,:), num2cell(Ls), "UniformOutput", false)';
            end
        end
        function Out = SplitDayLevels(this, D)
            [~, Ls] = findgroups(this.trialTbl.Level');
            r = this.trialTbl.Date==D;
            Dtbl = this.trialTbl(r,:);
            Out = Dtbl;
        end
        function Out = LevelMMAnalysis(this, L)
            try
                scores = L(L(:,1)~=2,1);
                bMM = movmean(scores, [this.BB-1 0], 'Endpoints', 'discard');
                B1 = movmean(scores(1:(end-this.SB)), [this.SB-1 0], 'Endpoints', 'discard');
                B2 = movmean(scores((this.SB+1):end), [this.SB-1 0], 'Endpoints', 'discard');
                bSD = std([B1 B2],0,2);
                D = L(L(:,1)~=2,2);
                XCoord = zeros(size(D));
                XCoordLevDay = zeros(size(D));
                offset = D(1);
                dc = 0;
                for d = unique(D')
                    dc = dc + 1;
                    w = D==d;
                    x = 1:numel(D(w));
                    XCoord(w) = (d-1)+normalize(x, 'range');
                    XCoordLevDay(w) = (dc-1)+normalize(x, 'range');
                end
                Out = {[bMM bSD XCoord(this.BB:end) XCoordLevDay(this.BB:end)]};
            catch Err
                if size(L,2)==1
                    Out = {[bMM bSD]};
                else
                    Out = {[NaN NaN NaN NaN]};
                end
            end
        end
        function Out = DayBin(this,D)
            %D is trial scores grouped by Level, and by Day
            Out = num2cell(nan(10,1));
            s = D(:,1);
            Level = D(1,2);
            Date = D(1,3);
            Day = D(1,4);
            these = s(s~=2);
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
                sMM = movmean( [0.5 ; these], [this.SB-1 0], 'Endpoints', 'shrink')';
                xMM = normalize(1:numel(sMM),'range');
                Cross = find( sMM>=0.8, 1, 'first');
                Out = {binned;
                    x;
                    txt;
                    numel(D);
                    mean(these);
                    std(binned);
                    s';
                    sMM;
                    xMM;
                    Cross;
                    Level;
                    Day;
                    Date};
            catch
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
        function data = CleanData(this)
            data = this.current_data_struct;
            try
                names = fieldnames(data);
            catch
            end
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
            if ~isempty(data.Settings)

            end
        end
        %Plot functions
        function PlotAllSubData(this)
            this.sc = 0;
            tic
            for S = struct2cell(this.DayData)'
                this.sc = this.sc+1;
                this.dc = 0;
                for d = [S{:}(:,:)]' % [S{:}(:,:)]'
                    this.dc = this.dc+1;
                    this.date = d{2};
                    %                     if this.dc==17
                    %                         fprintf("Stop!\n")
                    %                     end
                    this.current_data_struct = d{3};
                    this.CleanData();
                    graphFig = figure("Name", "Graphs", "Visible","off");
                    this.Axes = this.CreateAllTimeGraphs(graphFig);
                    title = "Day " +this.dc+" - - - "+this.Sub{this.sc}+" - - - "+d{2};
                    graphFig.Children.Title.String = title;
                    this.PlotNewData();
                    FileDir = [this.filedir{this.sc} filesep 'DayRec' filesep];
                    if ~exist(FileDir)
                        mkdir(FileDir)
                    end
                    filename = FileDir+"Day_"+this.dc+"_"+this.date+"_"+this.Sub{this.sc}+"_Rec";
                    this.SaveManyFigures(graphFig, filename);
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
            try
                setGUI(this.current_data_struct, this.GUInum)
                try
                    %this.plotTimerHists(this.Axes, this.current_data_struct)
                catch
                end
                %this.plotTrialHistory(this.Axes.TrialHistory, this.current_data_struct)
                this.plotBinnedPerformance(this.Axes.BinnedPerf, this.current_data_struct)
                this.plotAllLevelPerformance()
                this.plotSideBias(this.Axes.SideBias, this.current_data_struct)
                this.plotLevelPerf(this.Axes.LevelCount, this.current_data_struct)
            catch err
                %unwrapErr(err)
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
                dat = Data.Score(Data.Score ~=2);
                y = movmean([0.5 ; Data.Score(Data.Score ~=2)], [this.BB-1 0], "Endpoints", "shrink");
                x = (0:(numel(y)-1))';
                try
                    cPerf = plot(x, y, 'Parent',Ax);
                catch err
                    err
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
                smallszs(halfFull) = sum(SortData(halfFull,[4 5 6]),2);%Find which rows were not full bins
                %SortData = [SortData(~halfFull,:) ; SortData(halfFull,:)]; %Put the empty bins last
                [m,~] = size(SortData);
                [~, Levels] = findgroups(SortData(:,1)');
                LAvgs = zeros(size(Levels));
                LStds = zeros(size(Levels));
                total = 1:m;
                for L = Levels
                    fullrows = SortData(:,1) == L & ~halfFull;
                    halffullrows = SortData(:,1) == L & halfFull;
                    Lvrows = SortData(:,1) == L;
                    score = Data.Score(Data.Level==L & Data.Score~=2);
                    LAvgs(L) = mean(score);
                    LStds(L) = std(SortData(Lvrows,2));
                    %len = sum(Lvrows) - (this.BB-mod(numel(score), this.BB))/this.BB;
                    len = sum(Lvrows);
                    yB = movmean([0.5 ; score],[this.BB-1,0],"Endpoints","shrink");
                    yS = movmean([0.5 ; score],[this.SB-1,0],"Endpoints","shrink");
                    LIdx = find(SortData(:,1)==L,1,'first')-0.5;
                    x = LIdx+len*((1:numel(yB))/numel(yB));
                    try
                        pS = plot(x, yS, 'Parent', Ax);
                        pS.LineStyle = ":";
                        p = plot(x,yB, 'Parent', Ax);
                        p.LineWidth = 1.5;
                        p.SeriesIndex = L;
                        pS.SeriesIndex = L;
                    catch
                    end
                    Perf = errorbar( total(fullrows) , SortData(fullrows,2) , SortData(fullrows,3) , 'Parent', Ax);
                    Perf.MarkerFaceColor = "auto";
                    Perf.MarkerEdgeColor = "auto";
                    Perf.LineStyle = 'none';
                    Perf.MarkerMode = "auto";
                    try
                        Perf.Marker = this.Shape_code{L};
                    end
                    Perf.MarkerSize = 9;
                    Perf2 = scatter( total(halffullrows) , SortData(halffullrows,2) , 'Parent', Ax);
                    try
                        Perf2.Marker = Perf.Marker;
                        p.SeriesIndex = L;
                        p2.SeriesIndex = L;
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
                end
                text(total, SortData(:,2), num2cell(round(SortData(:,2),4)*100), ...
                    'Parent',Ax, ...
                    'HorizontalAlignment','center', ...
                    'VerticalAlignment','Bottom')
                %Change limits, ticks, grids:
                Ax.XLim = [0.6 size(SortData,1)+0.6];
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
            tnum = Data.TrialNum;
            Ax = this.Axes.AllLevelPerf; hold(Ax, "on");
            for L = this.current_data_struct.LevelGroups
                w = Data.Level==L & Data.Score~=2;
                score = Data.Score(w);
                x = [0 ; tnum(w)]; %Add point [0, 50%] because at trial #0 the mouse is at 50% (chance) performance, every day you assume the mouse starts from "chance"
                x(1) = x(2)-1;
                score = [0.5 ; score];
                yB = movmean(score, [this.BB-1,0],"Endpoints","shrink");
                yS = movmean(score, [this.SB-1,0],"Endpoints","shrink");
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
                catch
                end
            end
            top = min([max(yB)+0.001 1.05]);
            try
                Ax.YLim = [0.501 top];
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
                t = text(LvIdx, y, countTxt, ...
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
                Ax.XLim = [min(D.Level)-1 max(D.Level)+1];
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

        %For Group Plotting:
        function GroupData(this, opts)
            arguments
                this
                opts.Composite logical = false
                opts.LevGroup logical = false
                opts.LevMM logical = false
                opts.Stim logical = true
            end
            Num = num2cell(1:numel(this.Sub));
            t1 = datetime("now");
            if opts.LevGroup
                LevDay = cellfun(@(x){this.PlotLevelGroupsByLevel(Sc=x)}, Num);
            end
            if opts.LevMM
                ACell = cellfunp(@(x){this.plotLvByDayOneAxis(Sc=x, LevDay=1)}, Num);
            end
            if opts.Stim
                figs = this.PlotStimulusHistory();
            end
            time = seconds(datetime("now") - t1);
            fprintf("Total time: " + time + " seconds.\n")
        end
        function Out = plotLvByDayOneAxis(this, options)
            arguments
                this
                options.save logical = true
                options.Text logical = false
                options.LevDay logical = true
                options.Sc
                options.Training logical = false
            end
            if ~options.Training
                this.sc = options.Sc;
            else
                this.sc=1;
            end
            SUB = this.Sub{this.sc};
            %for SUB = this.Sub
            t1 = datetime("now");
            %this.sc = this.sc+1;
            Ldat = this.AnalyzedData.LevelMM{this.sc};
            HighScore = cellfun(@(x) max([x(:,1) ; 0]), Ldat, 'UniformOutput', true, 'ErrorHandler', @errorFuncNaN);
            maxPassedL = find(HighScore>=0.8, 1, 'last')+1;
            this.trial_table = this.AnalyzedData.TrialTbls{this.sc};
            title = SUB+" All Time Performance";
            f = figure("Name",title, "Visible", "off"); %f.Visible=1;
            T = tiledlayout(1,1,"Parent",f,"TileSpacing","none","Padding","tight");
            Ax = nexttile(T); hold(Ax, "on");
            Ax.Box = 0;
            Ax.XTick = [];
            Ax.YTick = [];
            Ax.Title.String = title;
            numDays = max(cell2mat(this.AnalyzedData.DayMM{this.sc}.DayNums));
            Ax.XLim = [0 numDays];
            Ax.YLim = [0 maxPassedL];
            thresh = 0.8;
            dayLine = xline(1:numDays, 'LineStyle',':');
            yline(0:1:maxPassedL, '-')
            TH = yline(thresh:1:(maxPassedL+1), ':',(100*thresh)+"%", ...
                "LabelHorizontalAlignment","left", ...
                "FontSize",6);
            for L = 1:maxPassedL
                LO = L-1;
                wL = this.AnalyzedData.DayMM{this.sc}.Ls==L;
                Ddat = this.AnalyzedData.DayMM{this.sc}(wL,:);
                try
                    y = Ldat{L}(:,1)';
                    std = Ldat{L}(:,2)';
                    x = Ldat{L}(:,3)';
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
                        %                             PassText = text(PassingDayIdx, levOffset+0.1, "PASSED", ...
                        %                                 "FontSize",6, ...
                        %                                 "HorizontalAlignment","center");
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
                for d = [ Ddat.DayNums' ; [Ddat.dayBin{:}] ]
                    DO = d{1}-1;
                    %Small Bin Moving mean:
                    try
                        x = DO+d{end-1};
                        y = LO+d{end-2};
                        SmallPlot = plot(x,y, ...
                            "Parent",Ax, ...
                            "SeriesIndex",L, ...
                            "LineWidth", 0.5);
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
                    end
                end
            end
            if options.LevDay
                this.PlotLevelGroupsByDay("Ax",Ax, "InComposite",1)
            end
            Ax.XLimitMethod = "tight";
            Ax.YLimitMethod = "tight";
            Ax.Title.String = title;
            if options.save && numel(this.Sub)>1 %Save the figure
                this.SaveManyFigures(f,title+".pdf", Columns=numDays,Rows=maxPassedL)
            end
            time = seconds(datetime("now") - t1);
            fprintf("Plotted "+SUB+ "... etime: " + time + " seconds.\n")
            if options.Training
                Out = Ax;
            else
                Out = f;
            end
            %Add'l fcns:
            function FMTtext(TextHandle)
                [TextHandle(:).FontSize] = deal(12);
                [TextHandle(:).HorizontalAlignment] = deal("center");
                [TextHandle(:).VerticalAlignment] = deal("bottom");
            end
        end
        function PlotLevelGroupsByDay(this, options)
            arguments
                this
                options.InComposite logical = false
                options.Text logical = false
                options.Ax %Axis object
            end
            Ddat = sortrows(this.AnalyzedData.DayMM{this.sc}, "DayNums");
            Ddat.DayNums=cell2mat(Ddat.DayNums);
            if options.InComposite
                Ax = options.Ax;
                Ax.YLim(1) = -1;
                yOff = -1;
            else
                Ax = MakeAxis();
                Ax.YLim = [-0.55 0.05];
                Ax.XLim = [min(Ddat.DayNums)-1 max(Ddat.DayNums)];
                Ax.Title.String = this.Sub{this.sc}+" Level Performance";
                xline(min(Ddat.DayNums):1:max(Ddat.DayNums), '-', 'Color',[0.7 0.7 0.7])
                Ax.YTick = -1:0.25:0;
                Ax.YTickLabel = string(0:25:100)+"%";
                Ax.YMinorTick = "on";
                Ax.YGrid = 1;
                Ax.YMinorGrid = 1;
                hold(Ax, "on")
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
                    CROSS = cellfun(@(x)x(10) ,Ld, "UniformOutput", true, "ErrorHandler", @errorFuncZeroCell)';
                catch err
                    err;
                end
                x = (d-1)+Xrange;
                y = AVG-1;
                for L = [x; y; STD; LevIdx]
                    E = errorbar(L(1), L(2), L(3), ...
                        'LineStyle','none', ...
                        'Marker', this.Shape_code{L(4)}, ...
                        'SeriesIndex',L(4));
                    E.MarkerFaceColor = E.Color;
                    E.CapSize = 1;
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
                            err;
                        end
                    end
                end
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
                Ax = MakeAxis(); hold(Ax, "on")
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
                        err;
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
                        err;
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
                    Name = string(S{:}{1,3}.Settings{:}.Subject);
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
                Dates = cell2mat(S{:}(:,2)');
                Water = cellfun(@(x)sum(x.Score),Daily);
                Weight = zeros(size(Water));
                dc = 0;
                for d = Daily
                    dc = dc+1;
                    try
                        Settings = cell2mat(d{:}.Settings);
                    catch err
                        Settings = d{:}.Settings{3,1};
                    end
                    try
                        WS = Settings.Weight;
                        Weight(dc) = WS(end);
                    catch
                        if isempty(WS) | isempty(Settings)
                            Weight(dc) = NaN;
                        else
                            Weight(dc) = w(end);
                        end
                    end
                end
                dc = 0;
                NewDates = cell(size(Dates));
                for d = Dates
                    dc = dc+1;
                    d = num2str(d);
                    d = datetime(d, 'InputFormat', 'yyMMdd');
                    NewDates{dc} = d;
                end
                PlotData = [NewDates ; num2cell(Weight) ; num2cell(Water)];
                f = figure("Visible", "off");
                t = tiledlayout('flow','Padding','tight', 'TileSpacing','none', 'Parent',f);
                a = nexttile(t); hold(a, 'on');
                a.Title.String = Name+" Daily Weight (grams)";
                P = plot(1:numel(Weight), Weight, 'Parent', a);
                a.XTick = 1:numel(Weight);
                a.XTickLabel = string([NewDates{:}]);
                Last = a.XLim;
                %a.XLim = [Last(2)-25 Last(2)];
                a.YLim = [0 max(P.YData)+2];
                a.PickableParts = "none";
                if options.Save
                    this.SaveManyFigures(f,Name+"Weight")
                end
                a = nexttile(t); hold(a, 'on');
                a.Title.String = Name+" Daily Fluid Intake (mL)";
                P = plot(1:numel(Water), Water*0.004, 'Parent', a);
                a.XTick = 1:numel(Weight);
                a.XTickLabel = string([NewDates{:}]);
                %a.XLim = [Last(2)-25 Last(2)];
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
            n = data(:,6);
            n = categorical(cellfun(@(x) x(1:7),n,'UniformOutput',false));
            d = cell2mat(data(:,2));
            G = findgroups(n,d);
            Output = splitapply(@PlotStims, data, G);



            function Out = PlotStims(In)
                Out = {};
                Stim = BehaviorBoxVisualStimulus();
                SH = this.StimHistory;
                for t = SH
                    if isempty(t{1})
                        continue
                    end
                end
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
                    Include = 1;
                end
                %Airpuff?
                if isfield(Settings, 'Box_Air_Puff_Penalty') && Settings.Box_Air_Puff_Penalty
                    SetStr = strcat(SetStr, 'A');
                end
                Include = 1;
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
        function [Out] = getSideBias(this, Idx, whatDecision)
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
        function SBt = CalculateSB(this, D)
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
            nt = Score~=2;
            [~,lvls] = findgroups(Lev(nt)');
            Avgs = cell(6, numel(lvls));
            try
                Avgs(1,:) = num2cell(accumarray(Lev(nt), Score(nt), [], @mean)'); %This might need to be binned to get a good STD
            catch
                Avgs(1,:) = accumarray(Lev(nt)', Score(nt)', [], @mean)'; %This might need to be binned to get a good STD
            end
            for L = lvls
                wlv = Lev==L & nt;
                scre = Score(wlv);
                lwin = 1:numel(scre);
                [~,~,SBidx] = histcounts(lwin, [1:this.SB:max(lwin) inf]); %Break the big bin into these smaller bins
                savg = accumarray(SBidx', scre, [], @mean);
                Avgs{2,L} = savg;
                Avgs{3,L} = std(savg);
                try
                    Avgs{4,L} = -log10(binocdf(sum(scre), numel(scre),0.5, 'upper'));
                end
            end
            Avgs(end-1,:) = num2cell(groupcounts(Lev(Score~=2)))';
            Avgs(end,:) = num2cell(lvls);
        end
        function [Out] = LevelMM(this)
            try
                Out = {};
                trialWin = this.BB;
                [~,Levels] = findgroups(this.trial_table.Level');
                MM = cell(size(Levels'));
                for L = Levels
                    r = this.trial_table.Level == L & this.trial_table.LvlTrialNum ~= 0;
                    LevTbl = this.trial_table(r,:);
                    m = numel(LevTbl.Date);
                    if m == 0
                        continue
                    end
                    MM{L} = NaN(m,10);
                    MM{L}(:,1) = LevTbl.Score;
                    %Small Bin Moving Mean
                    MM{L}(:,3) = movmean(LevTbl.Score, [this.BB-1 0], 'Endpoints', 'shrink'); %makes movmean of this.BB-1 trials before the current, and only for full bins
                    MM{L}(:,2) = movmean(LevTbl.Score, [this.SB-1 0], 'Endpoints', 'shrink'); %makes movmean of this.BB-1 trials before the current, and only for full bins
                    MM{L}(1:m,4) = (1:m);
                    tc = this.BB-1;
                    for t = trialWin:m
                        tc = tc + 1;
                        t0 = t-trialWin+1;
                        dataWin = LevTbl.Score(t0:t);
                        CCWin = LevTbl.CodedChoice(t0:t);
                        MM{L}(tc,5) = mean(dataWin);
                        MM{L}(tc,6) = std(accumarray(this.SBidx, dataWin, [], @mean));
                        try %Not every computer has the Stats Toolbox and this line fails
                            MM{L}(tc,7) = -log10(binocdf(sum(dataWin), numel(dataWin), 0.5, 'upper'));
                        end
                        SideBias = this.getSideBias(CCWin);
                        MM{L}(tc,8) = SideBias(4);
                    end
                    MM{L}(:,9) = LevTbl.Date;
                    [MM{L}(:,10), ~] = findgroups(LevTbl.Date);
                end
                MM = MM(~cellfun(@isempty, MM));
                Varnames = {'Score','SmallMean', 'BigMean', 'LvTrialNum', 'MeanMM', 'STD', '-Log Binomial', 'SideBias', 'Date', 'DayNum'};
                Out = cellfun(@(x) array2table(x, 'VariableNames', Varnames), MM, "UniformOutput", false);
            catch err
                unwrapErr(err)
            end
        end
        %Setup figures to display data
        function Axes = CreateDailyGraphs(this,P)
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
            [newData] = this.getDataToSave();
            %Settings = [this.Setting_Struct cell2mat(this.Old_Setting_Struct)];
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
            date = string(datetime(this.start_time, "Format", "yyMMdd_HHmmss_"));
            saveasname = date+this.Sub{:}+'_'+this.Str+'_'+this.StimType+this.Inp+".mat";
            newData.Settings = Settings;
            set(this.message_handle,'String',[ 'Saving data as: ' gui_save_string '.mat']);
            if numel(this.SetUpdate) == 1 % Settings never changed during the session.
                newData.SetStr = this.SetStr;
                newData.Include = repmat(this.Include, size(newData.TimeStamp));
                newData.SetIdx = repmat(this.SetIdx, size(newData.TimeStamp));
            elseif numel(this.SetUpdate) > 1
                Ts = this.Include;
                newData.SetStr =  this.SetStr;
                Idcs = unique([cell2mat(this.SetUpdate) length(newData.TimeStamp)]);
                [~, ~, newData.SetIdx] = histcounts(1:length(newData.TimeStamp), Idcs);
                newData.Include = Ts(newData.SetIdx);
            end
            try
                saveasname = date+this.Sub{:}+'_'+this.Str+'_'+this.StimType+this.Inp+".mat";
                savefolder = [this.Data_Object.filedir filesep]; % this.Setting_Struct.Strain filesep num2str(this.Setting_Struct.Subject) filesep];
                fakeNames = {'w', 'W'};
                if ~any(strcmp(num2str(this.Setting_Struct.Subject), fakeNames)) || ~any(strcmp(this.Setting_Struct.Strain, fakeNames)) %do not save if I use a fake name for fake data
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
                end
            catch err
                this.unwrapError(err)
            end
            this.graphFig.MenuBar = 'figure';
        end
        function saveFigure(this, fig, folder, name)
            name = erase(name, '.mat');
            figure_property = struct; %Reset export Settings:
            figure_property.units = 'inches';
            figure_property.format = 'pdf';
            figure_property.Preview= 'none';
            figure_property.Width= '11'; % Figure width on canvas
            figure_property.Height= '8.5'; % Figure height on canvas
            figure_property.Units= 'inches';
            figure_property.Color= 'rgb';
            figure_property.Background= 'w';
            %         figure_property.FixedfontSize= '9';
            %         figure_property.ScaledfontSize= 'auto';
            %         figure_property.FontMode= 'scaled';
            %         figure_property.FontSizeMin= '.5';
            figure_property.FixedLineWidth= '1';
            figure_property.ScaledLineWidth= 'auto';
            figure_property.LineMode= 'none';
            figure_property.LineWidthMin= '0.1';
            figure_property.FontName= 'Helvetica';% Might want to change this to something that is available
            figure_property.FontWeight= 'auto';
            figure_property.FontAngle= 'auto';
            figure_property.FontEncoding= 'latin1';
            %         figure_property.PSLevel= '3';
            figure_property.Renderer= 'painters';
            figure_property.Resolution= '600';
            figure_property.LineStyleMap= 'none';
            figure_property.ApplyStyle= '0';
            figure_property.Bounds= 'tight';
            figure_property.LockAxes= 'off';
            figure_property.LockAxesTicks= 'off';
            figure_property.ShowUI= 'off';
            figure_property.SeparateText= 'off';
            chosen_figure=fig;
            set(chosen_figure,'PaperUnits','inches');
            set(chosen_figure,'PaperPositionMode','auto');
            set(chosen_figure,'PaperSize',[str2double(figure_property.Width) str2double(figure_property.Height)]); % Canvas Size
            set(chosen_figure,'Units','inches');
            hgexport(fig, join([folder name + ".pdf"], filesep), figure_property); %Save as pdf
        end
        function SaveManyFigures(this, fig, filename, options)
            arguments
                this
                fig
                filename string
                options.format string = ".pdf"
                options.Columns = 32 %Inches acroww
                options.Rows = 18 %Inches high
            end
            FigProps = this.getFigProps(fig, options);
            if numel(this.Sub)>1
                %SaveAsName = fullfile(join([this.filedir , filename], filesep));
                SaveAsName = filename;
            else
                tree = split(this.filedir, filesep);
                parent = cell2mat(join([tree{1:end-1}, {'AllTime'}], filesep));
                SaveAsName = cell2mat(join([tree{1:end-1}, {'AllTime'}, {char(filename)}], filesep));
                if exist(parent, "dir") == 7
                else
                    mkdir(parent)
                end
            end
            if ispc
                try
                    print(FigProps, SaveAsName, '-dpdf', ...
                        '-vector', ...
                        '-fillpage')
                catch
                    tree=split(SaveAsName, filesep);
                    mkdir(fullfile(tree{1:end-1}))
                    print(fig, SaveAsName, '-dpdf', ...
                        '-vector', ...
                        '-fillpage')
                end
                %winopen(SaveAsName)
                close(fig)
            else
                print(fig, filename, '-dpdf', ...
                    '-vector', ...
                    '-fillpage')
                fig.Visible = 1;
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
                r = Tbl.Level == L & Tbl.Score ~= 2 & Tbl.Include == 1;
                Tbl.LvlTrialNum(r,:) = (1:sum(r))';
            end
            TotalTrialNum = zeros(size(Tbl.Level));
            Out = addvars(Tbl, TotalTrialNum, 'After','LvlTrialNum');
            Out.TotalTrialNum = (1:numel(Tbl.Level))';
        end
        function [chosen_figure] = getFigProps(fig, options)
            chosen_figure=fig;
            figure_property = struct; %Reset export Settings:
            FigProps = struct;
            figure_property.units = 'inches';
            figure_property.format = 'pdf';
            figure_property.Preview= 'none';
            figure_property.Width= num2str(options.Columns); % Figure width on canvas
            figure_property.Height= num2str(4*options.Rows); % Figure height on canvas
            figure_property.Units= 'inches';
            figure_property.Color= 'rgb';
            figure_property.Background= 'w';
            %         figure_property.FixedfontSize= '9';
            %         figure_property.ScaledfontSize= 'auto';
            %         figure_property.FontMode= 'scaled';
            %         figure_property.FontSizeMin= '.5';
            %figure_property.FixedLineWidth= '1';
            figure_property.ScaledLineWidth= 'auto';
            figure_property.LineMode= 'none';
            %figure_property.LineWidthMin= '0.1';
            figure_property.FontName= 'Helvetica';% Might want to change this to something that is available
            figure_property.FontWeight= 'auto';
            figure_property.FontAngle= 'auto';
            figure_property.FontEncoding= 'latin1';
            %         figure_property.PSLevel= '3';
            %figure_property.Renderer= 'opengl';
            figure_property.Resolution= '600';
            figure_property.LineStyleMap= 'none';
            figure_property.ApplyStyle= '0';
            figure_property.Bounds= 'tight';
            figure_property.LockAxes= 'off';
            figure_property.LockAxesTicks= 'off';
            figure_property.ShowUI= 'off';
            figure_property.SeparateText= 'off';
            set(chosen_figure,'PaperUnits','inches');
            set(chosen_figure,'PaperPositionMode','auto');
            %set(chosen_figure,'PaperOrientation','landscape');
            set(chosen_figure,'PaperSize',[str2double(figure_property.Width) str2double(figure_property.Height)]); % Canvas Size
            set(chosen_figure,'Units','inches');
            FigProps = figure_property;
        end
    end
end %end class
%EXTERNAL FUNCTIONS ====
function Ax = MakeAxis(options)
arguments
    options.Ax = [];
end
if isempty(options.Ax)
    f = figure;
    t = tiledlayout('flow','TileSpacing','none', 'Padding','tight', 'Parent',f);
    Ax = nexttile(t);
    f.Visible = 0;
else
    Ax = options.Ax;
end
Ax.YTick = [];
Ax.XTick = [];
end
function [filepath] = getFilePath
filepath = string;
switch 1
    case ispc
        filepath = 'D:\Dropbox (Dropbox @RU)\Gilbert Lab\BehaviorBoxData\Data\';
    case ismac
        filepath = '/Users/willsnyder/Dropbox (Dropbox @RU)/Gilbert Lab/BehaviorBoxData/Data/';
end
end
function setGUI(Data, GUINums)
try
    GUINums.right = num2str(sum(Data.CodedChoice == [2 ; 4],'all')); %Left Responses
    GUINums.left = num2str(sum(Data.CodedChoice == [1 ; 3],'all')); %Right Responses
    GUINums.rewards = num2str(sum(Data.Score==1));
    GUINums.total_correct = [num2str( 100*round(sum( Data.Score(Data.Score~=2))/numel(Data.Score(Data.Score~=2)),2 ) ) '%'];
    %Add a loop to go thru the handles:
end
end
function unwrapErr(err)
%Is there an error? Send the err object over here and it will be unwrapped in the command window. Maybe too much info?
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
function [A] = errorFuncNaN(~,varargin)
%warning(S.identifier, S.message);
A = NaN;
%B = NaN;
end
function [A] = errorFuncZeroDouble(~,varargin)
%warning(S.identifier, S.message);
A = 0;
%B = NaN;
end
function [A] = errorFuncZeroCell(~,varargin)
%warning(S.identifier, S.message);
A = {0};
%B = NaN;
end
%convert enum to integer
function [int_out] = convertEnum(enum_decision)
switch enum_decision
    case 'left correct'
        int_out = 1;
    case 'right correct'
        int_out = 2;
    case 'left wrong'
        int_out = 3;
    case 'right wrong'
        int_out = 4;
    case 'time out'
        int_out = 5;
    case 'time out - malingering'
        int_out = 6;
    case 'center poke'
        int_out = 6;
    otherwise
        int_out = -1;
end
end
