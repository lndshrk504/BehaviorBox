classdef BehaviorBoxWheel < handle
    %BehaviorBox Super class
    % WBS 10 . 10 . 2024
    %====================================================================
    %Super Class for BehaviorBox Ver 1.4
    %This Class is called by the GUI BehaviorBox via RunTraining()and runs the Training
    %loop, reads levers, gives rewards, plots data, etc. It stores data in the BehaviorBoxData.
    %Air Puff penalty code is being added
    %It interacts with class BehaviorBoxVisualStimulusTraining.m to create the
    %visual stimuli.
    %THIS FILE IS PART OF A SET OF FILES CONTAINING (ALL NEEDED):
    %BehaviorBox_App.mlapp
    %BehaviorBoxData.m
    %BehaviorBoxWheel.m
    %BehaviorBoxNose.m
    %BehaviorBoxVisualStimulus.m
    %====================================================================
    properties (SetAccess = public)
        fig; %The figure window that shows the stimulus
        figpos;
        ReadyCueAx;
        LStimAx; %Axis that contains the left stimulus plot
        RStimAx; %Axis that contains the left stimulus plot
        FLAx; %Axis that contains the 2 finish line triangles
        graphFig;
        TrialPhase char = 'intertrial' % Either : BeforeTrial, Intertrial, AfterTrial
        ReadyCueStruct = struct();
        StimulusStruct = struct();
        LevelStruct = struct();
        %Structures of variables:
        Stimulus_Object = struct();
        Data_Object = struct();
        Current_Settings char = 'default'
        Setting_Struct = struct();
        Temp_Settings = struct();
        Temp_Old_Settings = struct();
        Temp_Countdown = 0;
        Temp_iStart logical = false; % Flag for when starting a new temporary session
        Temp_Active logical = false;
        Temp_CorrectStart = 0;
        Temp_TrialStart = 0;
        SetIdx = {};
        SetStr = {};
        Include = {};
        GuiHandles = struct();
        app = struct();
        appProps; % Cached list of app properties that map into Setting_Struct
        appPropsTypes;
        appPropsTags;
        dropdowns;
        %Interface handles:
        message_handle;
        Pause;
        FF;
        Skip;
        stop_handle;
        Axes = struct();
        Buttons = struct();
        Data = struct();
        GUI_numbers = struct();
        Old_Setting_Struct = {}; %After the settings are updated, the older ones are stored here for plotting
        SetUpdate = {0};
        StimHistory = cell(400,2); %Use the one in BBData
        Box = struct(); %Equipment variables for arduino, sensors, valves
        a; %The arduino for behavior
        Time; % The arduino for timestampping
        EyeTrack; % Eye-tracking helper, present only when a source is found
        %Variables for running training loop:
        i=0; %Trial Number
        trial; %All trial data that is added to data structure
        counter_for_alternate = 0;
        current_side;
        Level;
        isCorrect = 1;
        isLeftTrial = 1; %Overwritten when the first trial starts, but initialized as 1 to prevent a crash
        isTraining = 0; %Set during setup, if 1 run BBSuper loop, if 0 run BBSub1 loop %Use this for the new NosePoke settings.
        RewardPulses = 0;
        SideBias;
        timeout_counter = 0;
        variable_counter;
        %Behavior counters:
        DuringTMal = 0; %How many airpuffs did the mouse get when they picked the wrong stimulus during the trial?
        duringPuffRecord = [];
        InterTMal = 0; %How many times did the mouse go to try and suck water from the Left/Right reward port during the intertrial period instead of starting a new trial?
        interPuffRecord = [];
        WhatDecision;
        wheelchoice = cell(1,1e6); %Use the one in BBData
        wheelchoicetime = cell(1,1e6);
        timestamps = cell(1,1e6);
        wheelchoice_record = cell(400,3); %All wheel choice processes with what_decision
        timestamps_record = cell(0,1); % Timestamp log segments saved as structs
        TimeSegmentKind string = ""
        TimeSegmentTrial double = NaN
        TimeSegmentTic = []
        TimeScanImageFileIndex double = 0
        TrainStartTime = []
        TrainStartWallClock = NaT
        %Timers during each trial:
        start_time; %Clock time at initiation of first trial
        t1; %Used to record times between different functions
        BetweenTrialTime = 0; %Manual mode: time to use keyboard to pick trial, also to watch the mouse and wait for them to calm down between trials
        TrialStartTime = 0; %Elapsed trial-init time before stimulus on, including hold-still resets
        ResponseTime = 0; %Elapsed time from stimulus on to the final committed choice
        DrinkTime = 0; %Time mouse spent drinking reward
        timers = struct();
        %SoundObjs: (only created if sounds is used)
        Sound_Object = struct();
        Sound_Struct = struct(); %This is only used to make the sounds, which are not used anymore since mice are trained concurrently.
        textdiary
        MappingAnimationLog = table();
        MappingMetadata = struct();
        WheelDisplayRecord = table();
        FrameAlignedRecord = table();
        CurrentTrialFrameAlignedRecord = table();
        CurrentWheelPhase string = "intertrial"
        CurrentRawWheel double = 0
        CurrentDelta double = 0
        CurrentStimColor double = NaN
        hold_still_start = []
    end
    methods
        function this = BehaviorBoxWheel(GUI_handles, app)
            this.app = app;
            this.GuiHandles = GUI_handles;
            try
                this.stop_handle.Value = 0;
                this.getGUI();
            catch err
                this.unwrapError(err)
            end
        end
        function RunTrials(this)
            try
                delete(findobj("Type", "figure", "Name", "Graphs"))
                this.getGUI(); %Set up arduino, make sounds if used
                this.DoLoop(); %the actual loop
            catch err
                this.unwrapError(err)
                this.cleanUP();
            end
            try
                if ~isempty(this.textdiary) && exist(char(this.textdiary), 'file') == 2
                    this.GuiHandles.MsgBox.String = fileread(this.textdiary);
                end
            catch err
                this.unwrapError(err)
            end
            diary off
        end
        function DoLoop(this)
            this.SetupBeforeLoop();
            errorc = 0;
            while 1
                try
                    this.i = this.i+1;
                    if errorc >= 5 || get(this.stop_handle, 'Value') %check if stop pressed
                        close(this.fig)
                        break;
                    end
                    this.BeforeTrial();
                    this.WaitForInput();
                    this.WaitForInputAndGiveReward();
                    this.AfterTrial()
                    this.app.TabGroup.SelectedTab = this.app.TabGroup.Children(5);
                    pause(0.1); drawnow;
                    errorc = 0;
                catch err
                    this.unwrapError(err)
                    errorc = errorc + 1;
                end
            end
            this.cleanUP();
            this.SaveAllData();
        end
        %get the GUI settings for the experiment
        function getGUI(this)
            % %Get handles to GUI figure, the buttons, axes, message line:
            % this.timers.betweenTrialsRecord = []; %Set up timers structure
            % this.timers.TrialStartTimeRecord = [];
            % this.timers.response_timeRecord = [];
            % this.timers.drinkDwellTimeRecord = [];
            this.stop_handle = this.app.Stop; %Buttons
            this.Skip = this.app.Skip;
            this.FF = this.app.FastForward;
            this.Pause = this.app.Pause;
            this.message_handle = this.app.text1;
            this.GUI_numbers.trial_no = 0; %GUI Numbers and their handles on the figure
            this.GUI_numbers.choices = 0;
            this.GUI_numbers.difficulty = 0;
            this.GUI_numbers.time = 0;
            this.GUI_numbers.handle.trial_no = this.app.text16; %Every input must be a string, not a number
            this.GUI_numbers.handle.choices = this.app.text19;
            this.GUI_numbers.handle.difficulty = this.app.text17;
            this.GUI_numbers.handle.time = this.app.text3;
            props = properties(this.app); %Get all names
            props(props == "MsgBox") = [];
            props(props == "NotesText") = [];
            skiptypes = {'buttongroup', 'figure', 'label', 'panel', 'annotationpane', 'axes', 'tab', 'uigridlayout', 'null', 'uistatebutton'};
            types = this.GetType(this.app, props); %cellfun(@(x) this.app.(x).Type, props, 'UniformOutput', false); %Get their types
            props = props(~contains(types, skiptypes, "IgnoreCase",true));
            types = this.GetType(this.app, props);
            %Make Button structure
            buttons = props(contains(types, {'button'}) & ~contains(types, {'radiobutton'}));
            bTags = this.GetTag(this.app, buttons);
            this.Buttons = cell2struct(cellfun(@(x)(this.app.(x)), buttons, 'UniformOutput',false, 'ErrorHandler', @errorFuncNaN), bTags);
            props = props(~contains(types, {'button'}) | contains(types, {'radiobutton'})); types = this.GetType(this.app, props);
            % Cache GUI metadata so settings can be read quickly each trial
            this.appProps = props;
            this.appPropsTypes = types;
            this.appPropsTags = this.GetTag(this.app, props);

            tempSetting_Struct = this.readSettingsFromApp();
            this.makeTrialStructures(tempSetting_Struct);
            this.LevelStruct = this.ManyLevels(this.LevelStruct);
            this.Setting_Struct = tempSetting_Struct;
            %Get the settings label from the setting structure, to label the data.
            this.SetIdx = 1;
            [this.SetStr, this.Include] = this.structureSettings(this.Setting_Struct);
        end
        function Tags = GetTag(this, App, Props)
            n = numel(Props);
            Tags = cell(1, n);
            for i = 1:n
                if Props{i} == "ArduinoInfo"
                    Tags{i} = 'Arduino';
                    %continue
                end
                try
                    Tags{i} = App.(Props{i}).Tag;
                catch err
                    Tags{i} = 'null';
                end
            end
            % Tags = cellfun(@(x) App.(x).Tag, Props, 'UniformOutput', false);
        end
        function Types = GetType(this, App, Props)
            %Types = cellfun(@(x) App.(x).Type, Props, 'UniformOutput', false);
            n = numel(Props);
            Types = cell(1, n);
            for i = 1:n
                if Props{i} == "ArduinoInfo"
                    Types{i} = 'Arduino';
                    %continue
                end
                try
                    Types{i} = App.(Props{i}).Type;
                catch err
                    Types{i} = 'null';
                end
            end
        end

        function Settings = readSettingsFromApp(this)
            % Read all GUI settings into a struct using cached metadata.
            props = this.appProps;
            types = this.appPropsTypes;
            tags  = this.appPropsTags;

            if isempty(props) || isempty(tags)
                Settings = struct();
                this.dropdowns = struct();
                return
            end

            n = numel(props);
            vals = cell(1, n);
            ddMask = false(1, n);

            for i = 1:n
                p = props{i};
                t = types{i};
                try
                    if contains(t, 'dropdown', 'IgnoreCase', true)
                        ddMask(i) = true;
                        vals{i} = find(matches(this.app.(p).Items, this.app.(p).Value), 1);
                    elseif contains(t, 'check', 'IgnoreCase', true)
                        vals{i} = logical(this.app.(p).Value);
                    else
                        v = this.app.(p).Value;
                        nv = str2double(v);
                        if ~isnan(nv)
                            vals{i} = nv;
                        else
                            vals{i} = v;
                        end
                    end
                catch
                    % Non-standard property (best-effort fallback)
                    try
                        vals{i} = this.app.(p);
                    catch
                        vals{i} = [];
                    end
                end
            end

            % vals/tags are row vectors; build struct across dimension 2.
            Settings = cell2struct(vals, tags, 2);

            % Optional convenience struct of only dropdown indices
            if any(ddMask)
                this.dropdowns = cell2struct(vals(ddMask), tags(ddMask), 2);
            else
                this.dropdowns = struct();
            end
        end

        function makeTrialStructures(this, Settings)
            names = fieldnames(Settings);

            this.StimulusStruct  = appendStruct(this.StimulusStruct,  PullOut(Settings, names, 'Stimulus_'));
            this.Box            = appendStruct(this.Box,            PullOut(Settings, names, 'Box_'));
            this.ReadyCueStruct = appendStruct(this.ReadyCueStruct, PullOut(Settings, names, 'ReadyCue_'));
            this.LevelStruct    = appendStruct(this.LevelStruct,    PullOut(Settings, names, 'Level_'));
            this.Temp_Settings  = appendStruct(this.Temp_Settings,  PullOut(Settings, names, '_Temp'));

            function OUT = PullOut(IN, allNames, chr)
                if strcmp(chr, '_Temp')
                    inter = allNames(endsWith(allNames, chr));
                else
                    inter = allNames(startsWith(allNames, chr));
                end

                if isempty(inter)
                    OUT = struct();
                    return
                end

                vals = cellfun(@(x) IN.(x), inter, "UniformOutput", false);

                % Normalize scalar grayscale -> RGB triplets
                cidx = contains(inter, "color", "IgnoreCase", true);
                vals(cidx) = cellfun(@normColor, vals(cidx), "UniformOutput", false);

                OUT = cell2struct(vals, erase(inter, chr));
            end

            function c = normColor(c)
                if isnumeric(c) && isscalar(c)
                    c = repmat(c, 1, 3);
                end
            end
        end

        function OUT = ManyLevels(~, In)
            OUT = In;

            HardLevs = bb_parseNumList(In.HardLvList);

            EasyLevs = bb_parseNumList(In.EasyLvList);

            LEVELS = {EasyLevs HardLevs; In.EasyLvProb In.HardLvProb};

            reps_per_level = zeros(1, size(LEVELS, 2));
            total_count = 0;
            for k = 1:size(LEVELS, 2)
                levs = LEVELS{1, k};
                levs = levs(:)';
                if isempty(levs)
                    continue
                end
                reps_per_level(k) = max(0, ceil((LEVELS{2, k} * 100) / numel(levs)));
                total_count = total_count + numel(levs) * reps_per_level(k);
            end

            PossibleLevels = zeros(1, total_count);
            idx = 1;
            for k = 1:size(LEVELS, 2)
                levs = LEVELS{1, k};
                levs = levs(:)';
                p = reps_per_level(k);
                if isempty(levs) || p == 0
                    continue
                end
                for l = levs
                    PossibleLevels(idx:(idx + p - 1)) = l;
                    idx = idx + p;
                end
            end

            if idx > 1
                PossibleLevels = PossibleLevels(1:(idx - 1));
            else
                % Fallback if probabilities are 0 or lists are empty
                PossibleLevels = [EasyLevs(:)' HardLevs(:)'];
                if isempty(PossibleLevels)
                    PossibleLevels = 1;
                end
            end

            OUT.PossibleLevels = PossibleLevels;
            OUT.ChooseLevel = @() OUT.PossibleLevels(randi(numel(OUT.PossibleLevels)));
        end

        %set hardware (arduino) parameters
        function ConfigureBox(this)
            arguments
                this
            end
            this.message_handle.Text = 'Connecting Arduino. . .';
            tic
            try
                % https://docs.arduino.cc/learn/microcontrollers/digital-pins
                switch this.Setting_Struct.Box_Input_type
                    case 6 %Rotating Wheel
                        try % Behavior Arduino:
                            disp('- - - Connecting to Behavior Arduino - - -')
                            [~, comsnum, ~] = arduinoServer('ArduinoInfo', this.app.ArduinoInfo, 'desiredIdentity', this.app.Arduino_Com.Value, 'FindExact', true);
                        catch err
                            [comsnum, ID] = arduinoServer('desiredIdentity', 'Wheel', 'FindFirst', true);
                            this.app.Arduino_Com.Value = ID;
                            this.app.LoadComputerSpecifics();
                        end
                        this.a = BehaviorBoxSerialInput(comsnum, 115200, 'Wheel');
                        this.Box.KeyboardInput = 0;
                        pause(2)
                        this.a.SetupReward("Which", "Right", "DurationRight", this.Box.Rrewardtime);
                        disp('- - - Success - - -')
                        try % Timekeeper Arduino
                            disp('- - - Connecting to Timestamp Arduino - - -')
                            [~, comsnum, ~] = arduinoServer('ArduinoInfo', this.app.ArduinoInfo, 'desiredIdentity', 'Time', 'FindExact', true);
                            this.Time = BehaviorBoxSerialTime(comsnum, 115200);
                            disp('- - - Success - - -')
                        catch err
                        end
                    case 8 %Keyboard, used if no arduino connected
                        this.Box.KeyboardInput = 1;
                        return
                end
                toc
            catch err
                this.Box.use_wheel = 0;
                this.Box.KeyboardInput = 1;
                this.Setting_Struct.Box_Input_type = 8;
                this.a = [];
            end
            this.message_handle.Text = 'Done';
        end
        %Prepare the window and stimulus
        function SetupBeforeLoop(this)
            this.GuiHandles.MsgBox.String = "";
            this.GuiHandles.NotesText.String = "";
            this.GuiHandles.NotesText.String = sprintf(string(datetime("today"))+" Behavior Notes:\n");
            if ~any([this.app.Animate_Go.Value this.app.Animate_Show.Value this.app.Animate_Flash.Value this.app.Animate_Rec.Value]) % Don't show finish line for animation
                this.app.Stimulus_FinishLine.Value = true;
                this.Setting_Struct.Stimulus_FinishLine = true;
                this.StimulusStruct.FinishLine = true;
            else
                this.app.Stimulus_FinishLine.Value = false;
                this.Setting_Struct.Stimulus_FinishLine = false;
                this.StimulusStruct.FinishLine = false;
            end
            this.setGuiNumbers(this.GUI_numbers); %update gui
            this.Data_Object = this.createSessionDataObject_();
            DATE = sprintf("BBTrialLog_%s.txt", datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            diaryname = fullfile(this.Data_Object.filedir, DATE);
            this.textdiary = diaryname;
            diary(diaryname)
            this.Data_Object.TrainingNow = 1;
            %create stimulus depending on input device
            [this.Stimulus_Object] = BehaviorBoxVisualStimulus(this.StimulusStruct); drawnow;
            this.Data_Object.StimType = erase(this.app.Stimulus_type.Value, ' ');
            this.graphFig = this.app.PerformanceTab.Children.Children;
            clo(this.graphFig);
            this.Data_Object.Axes = this.Data_Object.CreateDailyGraphs(this.graphFig);
            this.Data_Object.SB = this.Setting_Struct.Data_Sbin; %Make these names match
            this.Data_Object.BB = this.Setting_Struct.Data_Lbin*this.Setting_Struct.Data_Sbin;
            this.Data_Object.current_data_struct = this.Data_Object.new_init_data_struct();
            [this.Level] = this.Setting_Struct.Starting_opacity;
            rng('shuffle');
            [this.fig, this.LStimAx, this.RStimAx, this.FLAx, ~] = this.Stimulus_Object.setUpFigure();
            if ~any([this.app.Animate_Go.Value this.app.Animate_Show.Value this.app.Animate_Flash.Value this.app.Animate_Rec.Value]) % Don't show finish line for animation
                this.ReadyCue('Create')
                if isempty(this.ReadyCueAx) || ~isgraphics(this.ReadyCueAx)
                    this.ReadyCueAx = findobj(this.fig, 'Type', 'axes', 'Tag', 'ReadyCue');
                    if ~isempty(this.ReadyCueAx)
                        this.ReadyCueAx = this.ReadyCueAx(1);
                    end
                end
                this.ReadyCueStruct.Ax = this.ReadyCueAx;
                this.StimulusStruct.ReadyCue = this.ReadyCueStruct;
            end
            % this.toggleButtonsOnOff(this.Buttons,0); % Turn off all buttons
            fprintf("- - - - -\n");
            txt = "Start trial Mouse "+this.Setting_Struct.Subject+" at "+string(datetime('now'));
            set(this.message_handle,'Text',txt);
            fprintf(txt+"\n");
            this.resetSessionState_();
            this.initializeEyeTrackForSession_();
            this.resetTimekeeperForSession_();
            this.setSessionStartTime_();
            try
                set(this.message_handle, 'Text', "Preparing timestamp log ...");
                this.TimeScanImageFileIndex = 1;
                this.beginTimeSegment_("setup", 0);
            catch
            end
            % Send Start Acquisition signal to ScanImage
            try
                set(this.message_handle, 'Text', "Starting acquisition (ScanImage)...");
                this.a.Acquisition('Start');
                this.logTimeEvent_("acq_start", struct('trial', 0, 'scanImageFile', this.TimeScanImageFileIndex));
                this.logTimeEvent_("screen_on", struct('trial', 0, 'scanImageFile', this.TimeScanImageFileIndex));
                pause(5) % Let the mouse react to the screen turning on
            catch
            end
        end
        %Do some things before each trial
        function BeforeTrial(this)
            if ~isempty(this.EyeTrack) && isobject(this.EyeTrack)
                try
                    this.EyeTrack.markTrial(this.i);
                    this.EyeTrack.pollAvailable(this.i);
                catch
                end
            end
            this.fig.Color = this.ReadyCueStruct.Color;
            set(this.FF, 'Value', 0) %Turn off FF button
            this.UpdateSettings()
            this.CheckTemp();
            %Update GUI window numbers
            this.updateGUIbeforeIteration();
            %Pick next reward drop size, if variable
            try
                LastScore = this.Data_Object.current_data_struct.CodedChoice(end);
            catch
                LastScore = 1;
            end
            try
                this.a.TimeStamp('Off')
            end
            this.isLeftTrial = this.PickSideForCorrect(this.isLeftTrial, this.SideBias); %Pick if isLeftTrial
            %Pick next difficulty level, if variable
            if this.Setting_Struct.EasyTrials
                [this.Level] = this.PickDifficultyLevel();
            else
                this.Level = this.Setting_Struct.Starting_opacity;
            end
            if isvalid(this.fig)
                [this.StimHistory{this.i,1},this.StimHistory{this.i,2}] = this.Stimulus_Object.DisplayOnScreen(this.isLeftTrial, this.Level); %Plot new stimulus as hidden objects, record positions and angles of the segments
            else
                [this.fig, this.LStimAx, this.RStimAx, this.FLAx] = this.Stimulus_Object.setUpFigure();
                [this.StimHistory{this.i,1},this.StimHistory{this.i,2}] = this.Stimulus_Object.DisplayOnScreen(this.isLeftTrial, this.Level); %Plot new stimulus as hidden objects, record positions and angles of the segments
            end
            this.fig = this.Stimulus_Object.fig;
            %Update GUI window numbers
            this.updateGUIbeforeIteration(); %Update again, in case the level changed
            [this.fig.Children.findobj('Type','Line').Visible] = deal(0);
            drawnow
            this.ReadyCue(true)
        end
        function CheckTemp(this)
            if ~this.Temp_Active
                if this.tempSettingLogical_("PerformanceThreshold", false) || this.tempSettingLogical_("TrialNumber", false)
                    this.Temp_Active = true;
                    this.Temp_iStart = true;
                    this.Temp_CorrectStart = this.currentCorrectCount_();
                    this.Temp_TrialStart = this.currentScoreCount_();
                end
            end
            if this.Temp_Active && this.tempSettingLogical_("TempOff", false)
                this.endTempMode_();
                return
            end
            if this.Temp_Active
                this.Temp_Old_Settings = this.Setting_Struct;
                this.Setting_Struct = copytoStruct(this.Setting_Struct, this.Temp_Settings);
                if this.Temp_iStart
                    this.Temp_iStart = false;
                    this.Temp_Countdown = this.tempSettingNumeric_("TrialCount", 0);
                end

                if this.tempSettingLogical_("PerformanceThreshold", false)
                    threshold = this.tempThreshold_("PerfThresh");
                    performance = this.currentLevelOnePerformance_();
                    if ~isnan(threshold) && ~isnan(performance) && performance >= threshold
                        this.endTempMode_();
                    else
                        this.setTempLabel_("Lv 1 performance: " + this.formatPercent_(performance) + " / " + this.formatPercent_(threshold));
                    end
                    return
                end

                correctSinceStart = this.currentCorrectCount_() - this.Temp_CorrectStart;
                this.Temp_Countdown = this.tempSettingNumeric_("TrialCount", 0) - correctSinceStart;
                this.setTempLabel_(this.Temp_Countdown + " Correct Trials Remaining");
                if this.Temp_Countdown <= 0
                    threshold = this.tempThreshold_("TrialCountThreshold");
                    performance = this.tempPeriodPerformance_();
                    if isnan(threshold) || threshold <= 0 || (~isnan(performance) && performance >= threshold)
                        this.endTempMode_();
                    else
                        this.setTempLabel_((this.Temp_Countdown*-1) + " Extra trials, Poor performance");
                    end
                end
            end
        end

        function endTempMode_(this)
            this.Temp_Active = false;
            this.Temp_iStart = false;
            if ~isempty(fieldnames(this.Temp_Old_Settings))
                this.Setting_Struct = this.Temp_Old_Settings;
            end
            this.setTempLabel_("_ Trials Remaining");
            try
                this.app.TempOff_Temp.Value = 1;
            catch
            end
        end

        function setTempLabel_(this, text)
            try
                this.app.TrialsRemainingLabel.Text = text;
            catch
            end
        end

        function tf = tempSettingLogical_(this, name, defaultValue)
            tf = defaultValue;
            if isfield(this.Temp_Settings, name) && ~isempty(this.Temp_Settings.(name))
                tf = logical(this.Temp_Settings.(name));
            end
        end

        function value = tempSettingNumeric_(this, name, defaultValue)
            value = defaultValue;
            if isfield(this.Temp_Settings, name) && ~isempty(this.Temp_Settings.(name))
                value = this.Temp_Settings.(name);
                if ischar(value) || isstring(value)
                    value = str2double(value);
                elseif iscell(value)
                    value = str2double(string(value{1}));
                end
                value = double(value);
            end
        end

        function threshold = tempThreshold_(this, name)
            threshold = this.tempSettingNumeric_(name, NaN);
            if isnan(threshold)
                return
            end
            if threshold > 1
                threshold = threshold / 100;
            end
            threshold = min(max(threshold, 0), 1);
        end

        function count = currentScoreCount_(this)
            count = numel(this.currentScoreVector_());
        end

        function count = currentCorrectCount_(this)
            scores = this.currentScoreVector_();
            count = sum(scores == 1);
        end

        function performance = tempPeriodPerformance_(this)
            scores = this.currentScoreVector_();
            startIdx = min(max(this.Temp_TrialStart, 0), numel(scores));
            scores = scores((startIdx+1):end);
            scores = scores(scores ~= 2);
            if isempty(scores)
                performance = NaN;
            else
                performance = mean(scores == 1);
            end
        end

        function performance = currentLevelOnePerformance_(this)
            scores = this.currentScoreVector_();
            levels = this.currentLevelVector_();
            if isempty(scores)
                performance = NaN;
                return
            end
            rows = scores ~= 2;
            if numel(levels) == numel(scores)
                rows = rows & levels == 1;
            end
            if ~any(rows)
                performance = NaN;
            else
                performance = mean(scores(rows) == 1);
            end
        end

        function scores = currentScoreVector_(this)
            scores = [];
            try
                data = this.Data_Object.current_data_struct;
                if isstruct(data) && isfield(data, "Score")
                    scores = double(data.Score(:)');
                elseif istable(data) && any(strcmp(data.Properties.VariableNames, "Score"))
                    scores = double(data.Score(:)');
                end
            catch
            end
        end

        function levels = currentLevelVector_(this)
            levels = [];
            try
                data = this.Data_Object.current_data_struct;
                if isstruct(data) && isfield(data, "Level")
                    levels = double(data.Level(:)');
                elseif istable(data) && any(strcmp(data.Properties.VariableNames, "Level"))
                    levels = double(data.Level(:)');
                end
            catch
            end
        end

        function text = formatPercent_(~, value)
            if isnan(value)
                text = "n/a";
            else
                text = sprintf("%.1f%%", 100*value);
            end
        end
        %update GUI numbers before each trial
        function updateGUIbeforeIteration(this)
            %add local variables to Gui Numbers
            this.GUI_numbers.trial_no = this.i;
            this.GUI_numbers.choices = this.i- this.timeout_counter;
            this.GUI_numbers.difficulty = this.Level;
            try %Will fail before first trial is begun bc this.start_time is empty
                this.GUI_numbers.time = string(datetime("now") - this.start_time);
            catch
            end
            %update Gui window
            this.setGuiNumbers(this.GUI_numbers);
        end
        %Pick difficulty level if variable:
        function current_difficulty = PickDifficultyLevel(this)
            current_difficulty = this.LevelStruct.ChooseLevel();
        end
        %Update all the settings if the button is ticked
        function UpdateSettings(this)
            tempSetting_Struct = this.readSettingsFromApp();

            if isequaln(tempSetting_Struct, this.Setting_Struct)
                return
            end

            updatelist = {};
            names = fieldnames(tempSetting_Struct);
            changed = false(size(names));

            for k = 1:numel(names)
                x = names{k};
                if ~isfield(this.Setting_Struct, x) || ~isequaln(tempSetting_Struct.(x), this.Setting_Struct.(x))
                    changed(k) = true;
                    try
                        updatelist{end+1} = " " + x + " - " + string(this.Setting_Struct.(x)) + " to " + string(tempSetting_Struct.(x));
                    catch
                        updatelist{end+1} = " " + x;
                    end
                end
            end

            msg = "Trial " + this.i + " Updating:\n" + join([updatelist{:}], "\n") + "\n";
            fprintf(msg) %Print this to the Message window

            changedNames = string(names(changed));

            this.Old_Setting_Struct{end+1} = this.Setting_Struct;

            % Only rebuild derived structs when relevant settings changed
            needsStim  = any(startsWith(changedNames, "Stimulus_"));
            needsBox   = any(startsWith(changedNames, "Box_"));
            needsReady = any(startsWith(changedNames, "ReadyCue_"));
            needsLevel = any(startsWith(changedNames, "Level_"));
            needsTemp  = any(endsWith(changedNames, "_Temp")) | any(contains(changedNames, "_Temp"));

            if needsStim || needsBox || needsReady || needsLevel || needsTemp
                this.makeTrialStructures(tempSetting_Struct);

                if needsLevel
                    this.LevelStruct = this.ManyLevels(this.LevelStruct);
                end

                if needsStim
                    try
                        this.Stimulus_Object = this.Stimulus_Object.updateProps(this.StimulusStruct);
                        this.fig = this.Stimulus_Object.fig;
                    catch
                    end
                end
            end

            this.Setting_Struct = tempSetting_Struct;
            this.SetIdx = this.SetIdx + 1;
            this.SetUpdate{end+1} = this.i;
            [this.SetStr(end+1), this.Include(end+1)] = this.structureSettings(tempSetting_Struct);

            [this.Level] = this.Setting_Struct.Starting_opacity;
        end
        %Choose if Left or Right will be correct
        function isLeftTrial = PickSideForCorrect(this, isLeftTrial, ~)
            repeat_wrong = false;
            if isfield(this.Setting_Struct, 'Repeat_wrong') && ~isempty(this.Setting_Struct.Repeat_wrong)
                repeat_wrong = logical(this.Setting_Struct.Repeat_wrong);
            end
            switch this.StimulusStruct.side
                case 2 %all left
                    isLeftTrial = 1;
                case 3 %all right
                    isLeftTrial = 0;
                case 4 % Keyboard / Manual Mode
                    isLeftTrial = this.pickManualTrialSide_();
                case 5 % Repeat Wrong basic mode
                    isLeftTrial = this.pickRepeatWrongSide_(isLeftTrial);
                otherwise % Random, with optional global repeat-wrong checkbox.
                    if repeat_wrong && this.i > 1
                        isLeftTrial = this.pickRepeatWrongSide_(isLeftTrial);
                    else
                        isLeftTrial = this.randomTrialSide_();
                    end
            end
            this.setCurrentSide_(isLeftTrial);
        end
        function isLeftTrial = randomTrialSide_(~)
            isLeftTrial = randi([0 1]);
        end
        function isLeftTrial = pickRepeatWrongSide_(this, isLeftTrial)
            if this.lastScoreWasWrong_()
                isLeftTrial = double(logical(isLeftTrial));
            else
                isLeftTrial = this.randomTrialSide_();
            end
        end
        function isLeftTrial = pickManualTrialSide_(this)
            text = 'Press L for Left, R for Right, ? for Random or S to correct Side-Bias:';
            set(this.message_handle,'Text',text);
            fprintf([text '\n'])
            prompt = 'L, R, ? or S:   ';
            keypress = 0;
            isLeftTrial = 0;
            while keypress==0
                pause(0.1); drawnow;
                currkey = input(prompt,"s");
                switch true
                    case strcmp(currkey, 'l') || strcmp(currkey, 'L')
                        text = 'Starting Left trial...';
                        fprintf([text '\n'])
                        set(this.message_handle,'Text',text);
                        isLeftTrial = 1;
                        keypress = 1;
                    case strcmp(currkey, 'r') || strcmp(currkey, 'R')
                        text = 'Starting Right trial...';
                        fprintf([text '\n'])
                        set(this.message_handle,'Text',text);
                        isLeftTrial = 0;
                        keypress = 1;
                    case strcmp(currkey, 'slash') || strcmp(currkey, '?')
                        text = 'Making random choice';
                        fprintf([text '\n'])
                        set(this.message_handle,'Text',text);
                        isLeftTrial = this.randomTrialSide_();
                        keypress = 1;
                    case strcmp(currkey, 's') || strcmp(currkey, 'S')
                        keypress = 1;
                        SB = this.currentResponseSideBias_();
                        if SB == 0 || this.i <= 1
                            text = 'Making random choice...';
                            fprintf([text '\n'])
                            set(this.message_handle,'Text',text);
                            isLeftTrial = this.randomTrialSide_();
                        else
                            [isLeftTrial, side, bias] = this.correctSideForBias_(SB);
                            text = ['Correcting Side-Bias (' num2str(SB) ', ' bias ') with ' side ' trial...'];
                            fprintf([text '\n'])
                            set(this.message_handle,'Text',text);
                        end
                    otherwise
                        text = 'Please only press one of the indicated keys...';
                        fprintf([text '\n'])
                        set(this.message_handle,'Text',text);
                end
            end
        end
        function [isLeftTrial, side, bias] = correctSideForBias_(~, SB)
            if SB > 0
                isLeftTrial = 0;
                side = 'Right trial';
                bias = 'Left bias';
            else
                isLeftTrial = 1;
                side = 'Left trial';
                bias = 'Right bias';
            end
        end
        function tf = lastScoreWasWrong_(this)
            scores = this.currentDataVector_("Score");
            tf = ~isempty(scores) && scores(end) == 0;
        end
        function SB = currentResponseSideBias_(this)
            choices = this.currentDataVector_("CodedChoice");
            choices = choices(choices >= 1 & choices <= 4);
            if isempty(choices)
                SB = 0;
                return
            end
            windowSize = min(20, numel(choices));
            choices = choices((end-windowSize+1):end);
            left_total = sum(choices == 1 | choices == 3);
            right_total = sum(choices == 2 | choices == 4);
            total = left_total + right_total;
            if total == 0
                SB = 0;
            else
                SB = ((left_total - right_total) / total) * 0.5;
            end
        end
        function values = currentDataVector_(this, fieldName)
            values = [];
            try
                fieldName = char(fieldName);
                if isstruct(this.Data_Object) && isfield(this.Data_Object, 'current_data_struct')
                    data = this.Data_Object.current_data_struct;
                elseif isobject(this.Data_Object) && isprop(this.Data_Object, 'current_data_struct')
                    data = this.Data_Object.current_data_struct;
                else
                    return
                end
                if isstruct(data) && isfield(data, fieldName)
                    values = double(data.(fieldName)(:)');
                elseif istable(data) && any(strcmp(data.Properties.VariableNames, fieldName))
                    values = double(data.(fieldName)(:)');
                end
            catch
                values = [];
            end
        end
        function setCurrentSide_(this, isLeftTrial)
            if isLeftTrial %Set properties
                this.current_side = 'left';
            else
                this.current_side = 'right';
            end
        end
        function WaitForInput(this)
            if this.i == 1
                if ~this.Setting_Struct.One_ScanImage_File
                    this.a.Acquisition('End')
                    this.logTimeEvent_("acq_end", struct('trial', 0, 'scanImageFile', this.TimeScanImageFileIndex));
                    pause(0.1)
                end
                try
                    this.storeCurrentTimeSegment_();
                    if ~isempty(this.timestamps_record)
                        this.appendSessionFrameAlignedSegment_(this.timestamps_record{end});
                    end
                catch
                end
            end
            this.TrialStartTime = 0;
            set(this.message_handle,'Text','Waiting for Trial initialization');
            this.t1 = datetime("now"); t2 = this.t1; %In case of crash
            this.a.DispOutput = false;
            this.a.Reset();
            trialStartTimer = [];
            % Display stimulus
            try
                set(this.message_handle, 'Text', "Preparing trial timestamp log ...");
                this.beginTimeSegment_("trial", this.i);
                this.logTrialStartEvent_();
            catch
            end
            try % Send Next File signal to ScanImage
                if ~this.Setting_Struct.One_ScanImage_File
                    this.TimeScanImageFileIndex = this.TimeScanImageFileIndex + 1;
                    set(this.message_handle, 'Text', "Next file (ScanImage)...");
                    this.a.Acquisition('Next');
                    pause(0.2); % The nextfile acquisition signal has a builtin 200 ms delay
                    this.logTimeEvent_("acq_nextfile", struct('trial', this.i, 'scanImageFile', this.TimeScanImageFileIndex));
                end
            catch
            end
            switch true
                case ~isempty(this.a) && this.Box.Input_type==6 %Wheel 2.0, wait for the mouse to hold the wheel still for the interval to start a new trial
                    if this.i ~=1
                        this.ReadyCue(true);
                        if isempty(this.FLAx) || any(~isgraphics(this.FLAx))
                            this.FLAx = [ ...
                                findobj(this.fig, 'Type', 'Polygon', 'Tag', 'FinishLine'); ...
                                findobj(this.fig, 'Type', 'Patch', 'Tag', 'FinishLineTri') ...
                                ];
                        end
                        if ~isempty(this.FLAx)
                            set(this.FLAx, 'Visible', true);
                        end
                        drawnow
                    else
                        drawnow
                    end
                    this.beginHoldStillInterval_();
                    if this.i ~=1
                        timelimit = this.Setting_Struct.HoldStill;
                        holdStillThresh = this.getStructNumericValue_(this.Setting_Struct, "Hold_Still_Thresh", 0);
                        trialStartTimer = tic;
                        holdStillTimer = tic;
                        while toc(holdStillTimer)<=timelimit
                            this.message_handle.Text = "Keep the wheel still for "+num2str(round(timelimit - toc(holdStillTimer),1))+" seconds."; drawnow limitrate
                            holdStillWheel = this.a.ReadWheel();
                            if BehaviorBoxWheel.holdStillThresholdExceeded(holdStillWheel, holdStillThresh)
                                this.CurrentRawWheel = double(holdStillWheel);
                                this.CurrentDelta = double(holdStillWheel);
                                this.recordScreenEventPoint_("Hold Still interval reset", "ResetToZero", true);
                                if ~isempty(this.FLAx) && all(isgraphics(this.FLAx))
                                    this.Flash(this.StimulusStruct, this.Box, this.FLAx, 'Wheel');
                                end
                                this.a.Reset();
                                holdStillTimer = tic;
                            end
                            if get(this.stop_handle, 'Value')
                                this.message_handle.Text = 'Ending session...';
                                break;
                            end
                            if get(this.FF, 'Value')
                                set(this.message_handle, 'Text','Skipping interval...')
                                set(this.FF, 'Value', 0)
                                drawnow
                                break;
                            end
                        end
                        t2 = toc(holdStillTimer);
                        this.ReadyCue(true);
                    end
                otherwise % Keyboard inputthis.Box.KeyboardInput==1
                    drawnow
                    this.beginHoldStillInterval_();
                    if this.i ~= 1
                        trialStartTimer = tic;
                    end
                    InterTMalInterv = this.Setting_Struct.IntertrialMalSec;
                    text = 'Initialize: Press L for Left, R for Right, C or M for Middle:'; set(this.message_handle,'Text',text); fprintf([text '\n'])
                    prompt = 'L, R, or M/C:   ';
                    keypress = 0;
                    while keypress==0
                        Mal = 0;
                        currkey = input(prompt,"s");
                        t2 = clock;
                        switch true
                            case any(currkey == ["L","l"])
                                text = 'Left choice...'; fprintf([text '\n']); set(this.message_handle,'Text',text);
                                Mal = 1;
                            case any(currkey == ["R","r"])
                                text = 'Right choice...'; fprintf([text '\n']); set(this.message_handle,'Text',text);
                                Mal = 1;
                            case any(currkey == ["C","c", "M", "m", ""])
                                text = 'Middle choice'; fprintf([text '\n']); set(this.message_handle,'Text',text);
                                keypress = 1;
                            otherwise
                                text = 'Please only press one of the indicated keys...'; fprintf([text '\n']); set(this.message_handle,'Text',text);
                        end
                        pause(0.1); drawnow;
                        if Mal
                            this.ReadyCueAx.Children.Visible=0;
                            this.fig.Color = 'k';
                            text = 'Only choose Middle to start trial, malingering timeout...'; fprintf([text '\n']); set(this.message_handle,'Text',text);
                            timerStart = tic;
                            while 1
                                pause(0.1); drawnow;
                                if get(this.FF, 'Value')
                                    set(this.message_handle, 'Text','Skipping interval...')
                                    set(this.FF, 'Value', 0)
                                    drawnow
                                    break;
                                end
                                if get(this.stop_handle, 'Value')
                                    set(this.message_handle, 'Text','Ending session...')
                                    drawnow
                                    break;
                                end
                                if toc(timerStart) > InterTMalInterv %End when mouse has not poked L or R for the interval
                                    this.ReadyCue(true)
                                    set(this.message_handle,'Text','Waiting for Trial initialization');
                                    break
                                end
                            end
                            text = 'Initialize: Press L for Left, R for Right, C or M for Middle:'; set(this.message_handle,'Text',text); fprintf([text '\n'])
                        end
                        if get(this.stop_handle, 'Value')
                            this.message_handle.Text ='Ending session...';
                            break;
                        end
                    end
            end
            if this.i ~= 1 && ~get(this.stop_handle,'Value') && ~isempty(trialStartTimer)
                this.TrialStartTime = toc(trialStartTimer);
            elseif get(this.stop_handle, 'Value')
                this.TrialStartTime = 0;
            end
        end
        function WaitForInputAndGiveReward(this, options)
            arguments
                this
                options.Test logical = false
            end
            if get(this.stop_handle, 'Value')
                return;
            end
            % Default values
            keyboardInput = this.Box.KeyboardInput;
            inputType = this.Box.Input_type;
            this.WhatDecision = 'time out';
            this.DrinkTime = 0;
            % Optimized background and ready cue handling
            this.setVisibleChildren(this.fig.Children, true);
            this.logTimeEvent_("stimulus_on", struct('trial', this.i, 'side', this.trialSideName_(), 'level', this.Level));
            Lines = [findobj('Tag', 'Contour') ; findobj('Tag', 'Distractor')];
            this.setWheelDisplayPhase_("response");
            stimulusOnTimer = tic;
            % Ignore input for a defined duration
            startTime = tic;
            % Moved the file handling to wait for input function
            try % Stimulus On timestamp
                set(this.message_handle, 'Text', "Stimulus on timestamp...");
                this.a.TimeStamp('On');
            catch
            end
            %this.flashStimulus(); % Do not flash when imaging
            this.Data_Object.addStimEvent(this.isLeftTrial);  % Record stimulus event
            if this.Setting_Struct.Input_ignored
                this.CurrentRawWheel = 0;
                this.CurrentDelta = 0;
                this.CurrentStimColor = this.colorScalar_(this.StimulusStruct.LineColor);
                this.recordScreenEventPoint_("Input Ignored interval", "ResetToZero", true);
                this.recordScreenEventPoint_("Flash - input ignore interval", "ResetToZero", true);
                this.FlashNew(this.StimulusStruct, this.Box,  Lines, 'NewStim')
                this.recordScreenEventPoint_("Flash over - input ignore interval", "ResetToZero", true);
                set(this.message_handle, 'Text', sprintf('Input ignored for %s sec...', num2str(this.Setting_Struct.Pokes_ignored_time)));
                pause(this.Setting_Struct.Pokes_ignored_time)
                this.recordScreenEventPoint_("Ignore interval over", "ResetToZero", true);
            end
            for rep = 1:this.Setting_Struct.Stimulus_RepFlashInitial
                this.CurrentRawWheel = 0;
                this.CurrentDelta = 0;
                this.CurrentStimColor = this.colorScalar_(this.StimulusStruct.LineColor);
                this.recordScreenEventPoint_("Flash", "ResetToZero", true);
                this.FlashNew(this.StimulusStruct, this.Box, Lines, 'Correct_Confirmation')
                this.recordScreenEventPoint_("Flash over", "ResetToZero", true);
            end
            % Enhanced decision-making loop based on inputType
            set(this.message_handle, 'Text', sprintf('Waiting for %s choice...', this.current_side));
            responseOffset = toc(stimulusOnTimer);
            if ~keyboardInput && inputType == 6
                [this.WhatDecision, this.ResponseTime] = this.readLeverLoopAnalogWheel(responseOffset);
            else
                [this.WhatDecision, this.ResponseTime] = this.readKeyboardInput(this.stop_handle, this.message_handle, this.isLeftTrial, responseOffset);
            end
            % Retry for only correct answers if necessary
            this.handleOnlyCorrectMode();
            this.logChoiceEvent_();
            % Minimize redundant flash draws by handling decision directly
            this.processAfterDecision(keyboardInput, inputType);
            % Toggle timestamp
            try % Stimulus Off timestamp
                set(this.message_handle, 'Text', "Stimulus off timestamp...");
                this.a.TimeStamp('Off');
            catch
            end
        end
        function setVisibleChildren(this, children, isVisible)
            OBJ = children.findobj('Type','Line');
            set(OBJ, 'Visible', isVisible)
            set(this.ReadyCueAx, 'Visible', ~isVisible)
            drawnow
            % for obj = children'
            %     obj.Visible = isVisible;
            % end
        end
        function flashStimulus(this)
            % Check for stimulus flash based on settings, reducing redundancy
            if this.StimulusStruct.FlashStim
                lines = findobj(this.fig.Children, 'Type', 'Line');
                this.FlashNew(this.StimulusStruct, this.Box,  lines, "NewStim");
            end
        end
        function handleOnlyCorrectMode(this)
            % Handle retries in 'Only Correct' mode
            if this.Box.KeyboardInput && this.Setting_Struct.OnlyCorrect && contains(this.WhatDecision , 'wrong', 'IgnoreCase', true)
                [this.WhatDecision, this.ResponseTime] = this.readKeyboardInput(this.stop_handle, this.message_handle, this.isLeftTrial, this.ResponseTime);
                if contains(this.WhatDecision, 'correct', 'IgnoreCase', true) && ~contains(this.WhatDecision, 'OC', 'IgnoreCase', true)
                    this.WhatDecision = string(this.WhatDecision) + " OC";
                end
            end
        end
        function processAfterDecision(this, keyboardInput, inputType)
            % Based on the decision, process reward, penalty, or trial continuation
            this.setDistractorColor();
            % Handle actions based on decision correctness
            if contains(this.WhatDecision, 'correct', 'IgnoreCase', true)
                this.a.DispOutput = true;
                this.processCorrectDecision(keyboardInput, inputType);
                this.a.DispOutput = false;
            else
                this.processWrongDecision(keyboardInput, inputType);
            end
        end
        function setDistractorColor(this)
            d = this.fig.Children.findobj('Tag', 'Distractor');
            DIM = this.StimulusStruct.DimColor;
            set(d, 'Color', DIM)
            drawnow
            this.logTimeEvent_("distractors_dimmed", struct('trial', this.i, 'side', this.trialSideName_(), 'level', this.Level));
        end
        function processCorrectDecision(this, keyboardInput, inputType)
            % Handle reward and post-correct responses
            set(this.message_handle, 'Text', 'Giving Reward...');
            tic;

            this.GiveRewardAndFlash();
            % Wait until the mouse calms down after the reward
            % if ~keyboardInput && inputType == 6
            % NO WAY TO READ SPEED UNTIL I ADD A NEW FCN TO BBSERIAL
            % while abs(this.Box.encoder.readSpeed) > this.Setting_Struct.Hold_Still_Thresh
            %     pause(0.5); drawnow;
            % end
            % end

            this.DrinkTime = toc;

            % Optionally persist the visual stimulus
            this.handlePersistStimulus(true);
            this.hideAllChildren();
        end
        function processWrongDecision(this, keyboardInput, inputType)
            % Handle wrong decision and possible air puff penalty
            set(this.message_handle, 'Text', [this.WhatDecision, ' - Penalty...']);

            % Wait until the mouse calms down during penalty
            % I need to write a new fcn for this, no way to read speed yet
            % if ~keyboardInput && inputType == 6
            %     while abs(this.Box.encoder.readSpeed) > this.Setting_Struct.Hold_Still_Thresh
            %         pause(0.5); drawnow;
            %     end
            % end

            % Optionally persist the incorrect visual stimulus
            if this.StimulusStruct.PersistIncorrect && ~get(this.stop_handle, 'Value')
                this.handlePersistStimulus(false);
            end
            this.hideAllChildren();
        end
        function handlePersistStimulus(this, isCorrect)
            % Flash and persist the stimulus based on correctness
            if isCorrect
                persistingTime = this.StimulusStruct.PersistCorrectInterv;
            else
                persistingTime = this.StimulusStruct.PersistIncorrectInterv;
            end

            if persistingTime > 0
                set(this.message_handle, 'Text', ['Persisting stimulus for ', num2str(persistingTime), ' sec...']);
                this.performTimedPause(persistingTime);
            end
        end
        function performTimedPause(this, duration)
            starttime = tic;
            while toc(starttime) <= duration
                % Update GUI and handle button interruptions
                pause(0.01); drawnow limitrate;
                if get(this.FF, 'Value')
                    set(this.message_handle, 'Text', 'Skipping timed pause...');
                    set(this.FF, 'Value', 0);
                    break;
                elseif get(this.stop_handle, 'Value')
                    set(this.message_handle, 'Text', 'Ending session...');
                    break;
                end
            end
        end
        function hideAllChildren(this)
            % Hide all children elements within the current figure
            set(this.ReadyCueAx, 'Visible', true)
            set(this.FLAx, 'Visible', false)
            drawnow
            this.logTimeEvent_("stimulus_off", struct('trial', this.i, 'side', this.trialSideName_(), 'level', this.Level));
        end
        function [WhatDecision, response_time] = readLeverLoopAnalogWheel(this, initial_elapsed_s)
            % REVISED v4:
            %   1) Uses hgtransform stimulus translation if available (moves objects, not axes)
            %   2) Non-blocking stall blink after 5 seconds of no wheel movement
            %   3) Draw scheduling (avoids drawnow limitrate hard 20 Hz cap)
            if nargin < 2 || isempty(initial_elapsed_s)
                initial_elapsed_s = 0;
            end

            event = -1;
            delta = 0;
            this.wheelchoice = cell(1,1e6);
            this.wheelchoicetime = cell(1,1e6);

            % ---- Timeouts ----
            timeout_value = this.Box.Timeout_after_time;
            if isempty(timeout_value)
                timeout_value = 0;
            end

            % ---- Wheel scale ----
            threshold = this.Setting_Struct.TurnMag;
            StimDistance = 0.3;
            k = StimDistance/threshold; % multiply is faster than divide in loop

            % ---- Motion bounds (legacy normalized figure units) ----
            axR = this.RStimAx;
            axL = this.LStimAx;
            pos1i = axR.Position;
            if numel([axR axL]) > 1
                pos2i = axL.Position;
            end
            thresh = abs(pos1i(1)/2);

            if this.Setting_Struct.RoundUp
                RoundUp = (this.Setting_Struct.RoundUpVal/100); %Default is 75 --> 0.75
                thresh = RoundUp*thresh;
            end

            % ---- Reset encoder at loop start ----
            this.a.Reset();

            % if this.app.Animate_MimicTrial.Value
            %     this.SimulateTrial()
            % end

            % ---- Preallocate trace buffers (fast, grows in chunks) ----
            cap = 200000;
            wheelchoice = zeros(1,cap,'single');
            wheelchoicetime = zeros(1,cap,'single');
            I = 0;

            % ---- Prefer hgtransform motion if available ----
            useXform = false;
            gR = [];
            gL = [];
            scaleR = 1;
            scaleL = 1;
            try
                if ~isempty(this.Stimulus_Object) && ismethod(this.Stimulus_Object,'getWheelMotionTargets')
                    [gR, gL, scaleR, scaleL] = this.Stimulus_Object.getWheelMotionTargets();
                    useXform = ~isempty(gR) && ~isempty(gL) && all(isgraphics([gR gL]));
                end
            catch
                useXform = false;
            end

            % ---- Draw scheduling ----
            drawHz = 60;
            if isfield(this.Box,'GraphicsUpdateHz') && ~isempty(this.Box.GraphicsUpdateHz)
                drawHz = double(this.Box.GraphicsUpdateHz);
            else
                % Heuristic: integrated / software renderers get a lower target
                try
                    ri = rendererinfo;
                    dev = lower(string(ri.RendererDevice));
                    if contains(dev,"swiftshader") || contains(dev,"microsoft basic") || contains(dev,"gdi generic")
                        drawHz = 20;
                    elseif contains(dev,"intel") && ~contains(dev,["nvidia","amd","radeon"])
                        drawHz = 30;
                    end
                catch
                end
            end
            drawHz = max(10, min(drawHz, 240));
            drawInterval = 1/drawHz;
            tLastDraw = -Inf;

            % ---- Stall -> blink (non-blocking) ----
            stallSec = 5;
            stallTol = 0; % pulses
            lastDist = NaN;
            tLastMove = 0;
            didStallBlink = false;
            blinkActive = false;
            blinkT0 = 0;
            blinkDur = 0.10;

            Lines = [findobj('Tag', 'Contour') ; findobj('Tag', 'Distractor')];
            baseColor = this.StimulusStruct.LineColor;
            dimColor  = this.StimulusStruct.DimColor;
            pendingScreenEvent = "";
            this.CurrentStimColor = this.colorScalar_(baseColor);

            prevDelta = NaN;

            % =========================
            % Phase 1: free choice loop
            % =========================
            tLoop = tic;
            while (timeout_value == 0 | toc(tLoop) <= timeout_value) % do NOT replace | with || or the expression is changed.
                % Fast read if available
                if ismethod(this.a,'ReadWheel')
                    dist = this.a.ReadWheel();
                else
                    dist = str2double(this.a.SerialRead);
                end
                if isnan(dist)
                    continue
                end
                tNow = toc(tLoop);

                % Stall detection (reset on movement)
                if isnan(lastDist) || abs(dist - lastDist) > stallTol
                    lastDist = dist;
                    tLastMove = tNow;
                    didStallBlink = false;
                    if blinkActive
                        if isempty(Lines) || any(~isgraphics(Lines))
                            Lines = [findobj('Tag','Contour') ; findobj('Tag','Distractor')];
                        end
                        try
                            [Lines(:).Color] = deal(baseColor);
                        catch
                            set(Lines,'Color',baseColor);
                        end
                        blinkActive = false;
                        pendingScreenEvent = "stallblink_end";
                        this.CurrentStimColor = this.colorScalar_(baseColor);
                    end
                elseif ~blinkActive && (tNow - tLastMove) >= stallSec
                    if isempty(Lines) || any(~isgraphics(Lines))
                        Lines = [findobj('Tag','Contour') ; findobj('Tag','Distractor')];
                    end
                    try
                        [Lines(:).Color] = deal(dimColor);
                    catch
                        set(Lines,'Color',dimColor);
                    end
                    blinkActive = true;
                    blinkT0 = tNow;
                    didStallBlink = true;
                    pendingScreenEvent = "stallblink_start";
                    this.CurrentStimColor = this.colorScalar_(dimColor);
                end

                if blinkActive && (tNow - blinkT0) >= blinkDur
                    if isempty(Lines) || any(~isgraphics(Lines))
                        Lines = [findobj('Tag','Contour') ; findobj('Tag','Distractor')];
                    end
                    try
                        [Lines(:).Color] = deal(baseColor);
                    catch
                        set(Lines,'Color',baseColor);
                    end
                    blinkActive = false;
                    tLastMove = tNow;
                    pendingScreenEvent = "stallblink_end";
                    this.CurrentStimColor = this.colorScalar_(baseColor);
                end

                % dist -> delta
                delta = dist * k;

                % Clamp to bounds (legacy semantics)
                if abs(delta) > thresh
                    delta = sign(delta) * thresh;
                end
                if this.isLeftTrial & delta < -thresh
                    delta = -thresh;
                elseif ~this.isLeftTrial & delta > thresh
                    delta = thresh;
                end
                this.CurrentRawWheel = double(dist);
                this.CurrentDelta = double(delta);

                % Trace
                I = I+1;
                if I > cap
                    newCap = cap + 200000;
                    wheelchoice(1,newCap) = single(0);
                    wheelchoicetime(1,newCap) = single(0);
                    cap = newCap;
                end
                wheelchoice(I) = single(delta);
                wheelchoicetime(I) = single(tNow);

                % Apply motion only when delta changes
                if isnan(prevDelta) || abs(delta - prevDelta) > 1e-7
                    if useXform
                        txR = double(delta) * scaleR;
                        txL = double(delta) * scaleL;
                        gR.Matrix = makehgtform('translate', [txR 0 0]);
                        gL.Matrix = makehgtform('translate', [txL 0 0]);
                    else
                        pos1 = pos1i + ([double(delta) 0 0 0]);
                        axR.Position = pos1;
                        if exist('pos2i','var')
                            pos2 = pos2i + ([double(delta) 0 0 0]);
                            axL.Position = pos2;
                        end
                    end
                    prevDelta = delta;
                end

                % Render/UI pump at target Hz (avoid 20 Hz cap of drawnow limitrate)
                if (tNow - tLastDraw) >= drawInterval || strlength(pendingScreenEvent) > 0
                    drawnow %nocallbacks
                    if strlength(pendingScreenEvent) > 0
                        this.recordScreenEventPoint_(pendingScreenEvent);
                    else
                        this.recordWheelDisplayState_();
                    end
                    pendingScreenEvent = "";
                    tLastDraw = tNow;
                end
                %drawnow

                % Decision logic
                if this.isLeftTrial & delta <= -thresh
                    event = 2; % right
                    break
                elseif ~this.isLeftTrial & delta >= thresh
                    event = 1;
                    break
                end
                if double(abs(delta)) >= double(thresh) %If a choice is made: !!! Add code to round up the correct choice but not accept an incorrect choice until it is fully made. Accept the correct choice early but wait for a full incorrect choice.
                    if sign(delta) > 0
                        event = 1; % left
                        break
                    elseif sign(delta) < 0
                        event = 2; % right
                        break
                    end
                end
                if get(this.Skip, 'Value')
                    set(this.Skip, 'Value', 0) %Turn the button off
                    break
                end
            end
            drawnow
            if strlength(pendingScreenEvent) > 0
                this.recordScreenEventPoint_(pendingScreenEvent);
            else
                this.recordWheelDisplayState_();
            end

            choiceElapsed = toc(tLoop);
            response_time = initial_elapsed_s + choiceElapsed;

            % Round-up decision if timed out but close
            if event == -1 & abs(delta) >= thresh
                if sign(delta) > 0
                    event = 1;
                elseif sign(delta) < 0
                    event = 2;
                end
            end

            switch event
                case -1
                    WhatDecision = 'time out';
                case 1
                    if this.isLeftTrial == 1
                        WhatDecision = 'left correct';
                    else
                        WhatDecision = 'left wrong';
                    end
                case 2
                    if this.isLeftTrial == 0
                        WhatDecision = 'right correct';
                    else
                        WhatDecision = 'right wrong';
                    end
            end

            % ===========================================
            % Phase 2: OnlyCorrect "undo wrong" correction
            % ===========================================
            if contains(WhatDecision,'wrong') && isfield(this.Setting_Struct,'OnlyCorrect') && this.Setting_Struct.OnlyCorrect
                Old_response_time = choiceElapsed;

                % Reset OC state
                event = -1;
                prevDelta = NaN;
                lastDist = NaN;
                tLastMove = 0;
                didStallBlink = false;
                blinkActive = false;
                blinkT0 = 0;
                tLastDraw = -Inf;
                pendingScreenEvent = "";
                this.CurrentStimColor = this.colorScalar_(baseColor);

                % Acceptance thresholds (match legacy 0.24/0.26 with a ratio)
                accept = 0.96 * thresh;

                tLoopOC = tic;
                while (timeout_value == 0 | toc(tLoopOC) < timeout_value)
                    if ismethod(this.a,'ReadWheel')
                        dist = this.a.ReadWheel();
                    else
                        dist = str2double(this.a.SerialRead);
                    end
                    if isnan(dist)
                        continue
                    end
                    tNowOC = toc(tLoopOC);
                    tNowTotal = Old_response_time + tNowOC;

                    % Stall detection (same as phase 1)
                    if isnan(lastDist) || abs(dist - lastDist) > stallTol
                        lastDist = dist;
                        tLastMove = tNowOC;
                        didStallBlink = false;
                        if blinkActive
                            if isempty(Lines) || any(~isgraphics(Lines))
                                Lines = [findobj('Tag','Contour') ; findobj('Tag','Distractor')];
                            end
                            try
                                Lines.Color = baseColor;
                            catch
                                set(Lines,'Color',baseColor);
                            end
                            blinkActive = false;
                            pendingScreenEvent = "stallblink_end";
                            this.CurrentStimColor = this.colorScalar_(baseColor);
                        end
                    elseif ~didStallBlink && (tNowOC - tLastMove) >= stallSec
                        if isempty(Lines) || any(~isgraphics(Lines))
                            Lines = [findobj('Tag','Contour') ; findobj('Tag','Distractor')];
                        end
                        try
                            Lines.Color = dimColor;
                        catch
                            set(Lines,'Color',dimColor);
                        end
                        blinkActive = true;
                        blinkT0 = tNowOC;
                        didStallBlink = true;
                        pendingScreenEvent = "stallblink_start";
                        this.CurrentStimColor = this.colorScalar_(dimColor);
                    end
                    if blinkActive && (tNowOC - blinkT0) >= blinkDur
                        if isempty(Lines) || any(~isgraphics(Lines))
                            Lines = [findobj('Tag','Contour') ; findobj('Tag','Distractor')];
                        end
                        try
                            Lines.Color = baseColor;
                        catch
                            set(Lines,'Color',baseColor);
                        end
                        blinkActive = false;
                        pendingScreenEvent = "stallblink_end";
                        this.CurrentStimColor = this.colorScalar_(baseColor);
                    end

                    delta = dist * k;
                    if abs(delta) > thresh
                        delta = sign(delta) * thresh;
                    end
                    this.CurrentRawWheel = double(dist);
                    this.CurrentDelta = double(delta);

                    I = I+1;
                    if I > cap
                        newCap = cap + 200000;
                        wheelchoice(1,newCap) = single(0);
                        wheelchoicetime(1,newCap) = single(0);
                        cap = newCap;
                    end
                    wheelchoice(I) = single(delta);
                    wheelchoicetime(I) = single(tNowTotal);

                    if isnan(prevDelta) || abs(delta - prevDelta) > 1e-7
                        if useXform
                            txR = double(delta) * scaleR;
                            txL = double(delta) * scaleL;
                            gR.Matrix = makehgtform('translate', [txR 0 0]);
                            gL.Matrix = makehgtform('translate', [txL 0 0]);
                        else
                            pos1 = pos1i + ([double(delta) 0 0 0]);
                            axR.Position = pos1;
                            if exist('pos2i','var')
                                pos2 = pos2i + ([double(delta) 0 0 0]);
                                axL.Position = pos2;
                            end
                        end
                        prevDelta = delta;
                    end

                    if (tNowOC - tLastDraw) >= drawInterval || strlength(pendingScreenEvent) > 0
                        drawnow nocallbacks
                        if strlength(pendingScreenEvent) > 0
                            this.recordScreenEventPoint_(pendingScreenEvent);
                        else
                            this.recordWheelDisplayState_();
                        end
                        pendingScreenEvent = "";
                        tLastDraw = tNowOC;
                    end

                    % Legacy OC logic expressed in delta-space
                    if this.isLeftTrial
                        % Wrong side overshoot: reset
                        if delta <= -thresh
                            this.a.Reset();
                        end
                        % Accept only a corrective LEFT movement (delta positive)
                        if delta >= accept
                            event = 1; % left
                            break
                        end
                    else
                        if delta >= thresh
                            this.a.Reset();
                        end
                        if delta <= -accept
                            event = 2; % right
                            break
                        end
                    end

                    if get(this.Skip,'Value')
                        set(this.Skip,'Value',0)
                        break
                    end
                end
                drawnow
                if strlength(pendingScreenEvent) > 0
                    this.recordScreenEventPoint_(pendingScreenEvent);
                else
                    this.recordWheelDisplayState_();
                end

                response_time = initial_elapsed_s + Old_response_time + toc(tLoopOC);
                if event == -1 %If the mouse was close to picking a side, round up their choice:
                    if abs(delta) >= thresh
                        if sign(delta) > 0
                            event = 1;
                        elseif sign(delta) < 0
                            event = 2;
                        end
                    end
                end
                %translate response to decision
                switch event
                    case -1
                        WhatDecision = 'time out';
                    case 1
                        if this.isLeftTrial == 1
                            WhatDecision = 'left correct OC';
                        else
                            WhatDecision = 'left wrong';
                        end
                    case 2
                        if this.isLeftTrial == 0
                            WhatDecision = 'right correct OC';
                        else
                            WhatDecision = 'right wrong';
                        end
                end
            end


            % Ensure we exit with baseline stimulus color (avoid leaving it dimmed)
            try
                if ~isempty(Lines) && all(isgraphics(Lines))
                    Lines.Color = baseColor;
                end
            catch
            end

            % Publish trace
            if I == 0
                this.wheelchoice = [];
                this.wheelchoicetime = [];
            else
                this.wheelchoice = double(wheelchoice(1:I));
                this.wheelchoicetime = double(wheelchoicetime(1:I));
            end
        end
        function FlashNew(this, Stim, Box, Lines, whatdecision, OneWay, OnFirstDraw)
            arguments
                this
                Stim % from Setting structure
                Box
                Lines = findobj('Tag', 'Contour')
                whatdecision = "time out"
                OneWay logical = false
                OnFirstDraw = []
            end
            if isempty(Lines)
                return
            end
            if ~Stim.FlashStim
                return
            end
            switch 1
                case contains(whatdecision, 'wrong')
                    Reps = Stim.RepFlashAfterW;
                case contains(whatdecision, 'correct') || contains(whatdecision, 'OC')
                    Reps = Stim.RepFlashAfterC;
            end
            if contains(whatdecision, {'wrong', 'correct'}) && Reps == 0
                return
            end
            start_color = Stim.LineColor;
            flash_color = Stim.FlashColor;
            dark_color = Stim.DimColor;
            background_color = Stim.BackgroundColor;
            Steps = Stim.FreqAnimation;
            if whatdecision == "time out"
                this.BasicFlash("Lines",Lines, "NewColor", Stim.BackgroundColor, "steps", Steps)
            elseif whatdecision == "Mal" %Wheel hold still interval
                this.BasicFlash("Lines",Lines, "NewColor", Stim.BackgroundColor, "steps", Steps)
            elseif whatdecision == "NewStim" %L or R poke during intertrial
                this.BasicFlash("Lines",Lines, "NewColor", Stim.BackgroundColor, "steps", Steps)
            elseif whatdecision == "center" %Center poke during trial
                this.BasicFlash("Lines",Lines, "NewColor", Stim.BackgroundColor, "steps", Steps)
            elseif whatdecision == "Correct_Confirmation"
                this.BasicFlash("Lines",Lines, "NewColor", dark_color, "steps", Steps, "OnFirstDraw", OnFirstDraw)
            else
                d = findobj('Tag', 'Distractor');
                if isempty(d)
                    d = struct();
                end
                switch 1
                    case contains(whatdecision, 'wrong')
                        Reps = Stim.RepFlashAfterW;
                        if Reps > 0
                            this.BasicFlash("Lines",Lines, "NewColor", Stim.BackgroundColor, "steps", Steps)
                        end
                    case contains(whatdecision, 'correct') || contains(whatdecision, 'OC')
                        Reps = Stim.RepFlashAfterC;
                        OneWay = true;
                        if Reps > 0
                            this.BasicFlash("Lines",Lines, "NewColor", flash_color, "steps", Steps)
                        end
                end
            end
        end
        function BasicFlash(this, vars)
            arguments
                this
                vars.Lines = findobj('Tag','Contour')
                vars.NewColor double
                vars.steps double
                vars.OneWay logical = false
                vars.Interruptor = []
                vars.OnFirstDraw = []
            end
            if vars.steps == 1
                return
            end
            obj = vars.Lines;
            NewColor = vars.NewColor;
            steps = vars.steps;
            OneWay = vars.OneWay;
            if OneWay
                STEPS = 1:1:steps;
            else
                STEPS = [1:1:steps steps-1:-1:1];
            end
            loggedFirstDraw = false;
            % This blinks the Obj to the NewColor and back, over a total of
            % 2*steps increments
            if obj(1).Type == "scatter"
                start_color = [obj(1).MarkerFaceColor];
                COLOR_PROP = 'MarkerFaceColor';
            elseif obj(1).Type == "polygon"
                start_color = [obj(1).FaceColor];
            elseif obj(1).Type == "line" ||  obj(1).Type == "constantline"
                start_color = [obj(1).Color];
                COLOR_PROP = 'Color';
            elseif obj(1).Type == "rectangle"
                start_color = [obj(1).FaceColor];
                COLOR_PROP = 'FaceColor';
            else
                return %prevent an error crash
            end
            mat = interp1( [1 ; steps], [start_color ; NewColor], STEPS);
            for i = mat'
                set(obj, COLOR_PROP, i);  drawnow
                if ~loggedFirstDraw && ~isempty(vars.OnFirstDraw)
                    vars.OnFirstDraw();
                    loggedFirstDraw = true;
                end
                if ~isempty(vars.Interruptor) && vars.Interruptor() %This is all very slow and will be sped up later
                    set(obj, COLOR_PROP, start_color)
                    break
                end
            end
        end
        function FlashNew_FromNose(this, Stim, Box, Lines, whatdecision, OneWay)
            arguments
                this
                Stim = this.StimulusStruct % from Setting structure
                Box = this.Box
                Lines = findobj(this.fig.Children, 'Tag', 'Contour')
                whatdecision = "time out"
                OneWay logical = false
            end
            if isempty(Lines) || ~Stim.FlashStim
                return
            end
            start_color = Stim.LineColor;
            flash_color = Stim.FlashColor;
            dark_color = Stim.DimColor;
            background_color = Stim.BackgroundColor;
            Steps = Stim.FreqAnimation;
            if whatdecision == "WaitForInput" % New name - Flash Dim
                this.BasicFlashCosine("Lines",Lines, "NewColor", flash_color, "steps", Steps, "Interruptor", @(x)~this.a.ReadNone())
            elseif whatdecision == "Flash_Contour" % New name - Flash Bright
                this.BasicFlashCosine("Lines",Lines, "NewColor", flash_color, "steps", Steps, "Interruptor", @(x)this.a.ReadMiddle())
            elseif whatdecision == "Dim_Distractors" % Make Dim color
                this.BasicFlashCosine("Lines",Lines, "NewColor", dark_color, "steps", Steps, "OneWay", true)
            elseif whatdecision == "Make_Background" % Make Background color
                this.BasicFlashCosine("Lines",Lines, "NewColor", background_color, "steps", Steps, "OneWay", OneWay)
            elseif whatdecision == "Make_Bright" % Make start color
                this.BasicFlashCosine("Lines",Lines, "NewColor", start_color, "steps", Steps, "OneWay", true)
            else
                switch 1
                    case contains(whatdecision, 'wrong')
                        Reps = Stim.RepFlashAfterW;
                        if Reps > 0
                            this.BasicFlashCosine("Lines",Lines, "NewColor", Stim.BackgroundColor, "steps", Steps)
                        end
                    case contains(whatdecision, 'correct') || contains(whatdecision, 'OC')
                        Reps = Stim.RepFlashAfterC;
                        if Reps > 0
                            this.BasicFlashCosine("Lines",Lines, "NewColor", flash_color, "steps", Steps)
                        end
                end
            end
        end
        function BasicFlashCosine(this, vars)
            arguments
                this
                vars.Lines = findobj(this.fig.Children, 'Tag','Contour')
                vars.NewColor
                vars.steps
                vars.OneWay logical = false
                vars.Interruptor = [];
            end
            if vars.steps == 1
                return
            end
            obj = vars.Lines;
            NewColor = vars.NewColor;
            steps = vars.steps;
            OneWay = vars.OneWay;
            if OneWay
                X = linspace(0,pi, steps);
            else
                X = linspace(0,2*pi, 2*steps-1);
            end
            % This blinks the Obj to the NewColor and back, over a total of
            % 2*steps increments
            if obj(1).Type == "scatter"
                start_color = [obj(1).MarkerFaceColor];
                COLOR_PROP = 'MarkerFaceColor';
            elseif obj(1).Type == "polygon"
                start_color = [obj(1).FaceColor];
            elseif obj(1).Type == "line"
                start_color = [obj(1).Color];
                COLOR_PROP = 'Color';
            else
                return %prevent an error crash
            end
            % Calculations for Cosine function:
            % A cosine oscillates from 1 to -1 and 1, some adjustments must be made:
            Range = start_color(1) - NewColor(1); % Maximum - Minimum of cosine oscillation
            Amplitude = Range/2; % Half of the Range
            Offset = (start_color(1) + NewColor(1))/2; % Vertical Shift
            y = Amplitude * cos(X) + Offset; % Cosine smoothed oscillation between start and new color
            mat = repmat(y,3,1); % Expand to RGB values
            for C = mat
                set(obj, COLOR_PROP, C); drawnow
                %pause(0.01)
                if ~isempty(vars.Interruptor) && vars.Interruptor() %This is all very slow and will be sped up later
                    set(obj, COLOR_PROP, start_color)
                    break
                end
            end
        end
        %open reward valves
        function GiveRewardAndFlash(this)
            %Get reward valve, pulse number and time:
            if contains(this.WhatDecision, 'OC', 'IgnoreCase', true)
                PulseNum = this.Box.OCPulse;
            elseif contains(this.WhatDecision, 'correct', 'IgnoreCase', true)
                PulseNum = this.Box.RightPulse;
            else
                return
            end
            PulseNum = max(0, round(double(PulseNum)));
            lines = findobj(this.fig.Children, 'Tag', 'Contour');
            for pulseIdx = 1:PulseNum
                if pulseIdx > 1
                    pause(this.Box.SecBwPulse)
                end
                this.logRewardEvent_(pulseIdx);
                this.setWheelDisplayPhase_("reward");
                this.a.GiveReward();
                this.RewardPulses = this.RewardPulses + 1;
                this.FlashNew(this.StimulusStruct, this.Box,  lines, "Correct_Confirmation", false, @() this.logRewardFlashEvent_(pulseIdx));
            end
        end
        %Use this function instead of pausing, so that buttons are checked and settings are updated during the pause
        function UpdatePause(this, interval)
            starttime = tic;
            while toc(starttime) <= interval
                pause(0.01);
                drawnow limitrate;  % Reduce the frequency of GUI updates
                if this.Pause.Value
                    set(this.message_handle,'Text','Paused, click pause button again to continue...');
                    % o = findobj(this.fig.Children);
                    % [o(:).Visible] = deal(0);
                    [this.fig.Children.Visible] = deal(0);  % Direct access to children
                    this.fig.Color = this.ReadyCueStruct.Color;% Clear stim and turn the screen black to tell the mouse the time to drink water is now over. This should help mice not associate an air puff with the correct/rewarded stimulus, and instead associate an air puff with the black screen.
                    while get(this.Pause, 'Value')
                        pause(0.01);
                        drawnow limitrate;  % Reduce the frequency of GUI updates
                    end
                    this.fig.Color = this.StimulusStruct.BackgroundColor;
                end
                %check if stop pressed
                if this.stop_handle.Value || this.FF.Value
                    %abort
                    break;
                end
            end
        end
        %Update data structure, update graphs, do intertrial time
        function AfterTrial(this)
            decision = this.WhatDecision;
            settingStruct = this.Setting_Struct;
            switch true
                case contains(decision,'correct')
                    interval = 'Intertrial interval';
                    interval_time = settingStruct.Intertrial_time;
                case contains(decision,'wrong')
                    interval = 'Penalty interval';
                    interval_time = settingStruct.Penalty_time;
                case contains(decision, 'malinger', 'IgnoreCase', true)
                    interval = 'Only poke center to begin a trial, Penalty interval';
                    interval_time = settingStruct.Penalty_time;
                case contains(decision,'time out')
                    interval = 'Time out, proceed to next trial';
                    interval_time = 0.5;
                    this.timeout_counter = this.timeout_counter + 1;
                otherwise
                    interval = 'Unknown decision'; % Handle unexpected decision types
                    interval_time = 0;
            end
            %Update data & Plot, update GUI numbers
            this.UpdateData();
            this.updateMessageText(decision, interval, interval_time);
            this.ReadyCue(true)
            this.setWheelDisplayPhase_("intertrial");
            this.logTimeEvent_("trial_end", struct( ...
                'trial', this.i, ...
                'side', this.trialSideName_(), ...
                'level', this.Level, ...
                'decision', this.WhatDecision, ...
                'correct', this.choiceWasCorrect_(), ...
                'responseTime', this.ResponseTime));
            if this.Temp_Active
                this.Setting_Struct = this.Temp_Old_Settings;
            end
            if ~this.Setting_Struct.One_ScanImage_File
                this.a.Acquisition('End')
                this.logTimeEvent_("acq_end", struct('trial', this.i, 'scanImageFile', this.TimeScanImageFileIndex));
            end
            this.storeCurrentTimeSegment_();
            this.buildCurrentTrialFrameAlignedRecord_();
            if get(this.stop_handle, 'Value')
                return
            end
            %Wait for interval
            this.UpdatePause(interval_time)
            this.updateMessageBox();
        end
        function updateMessageBox(this)
            try
                % Read the content of the diary file
                diaryContent = fileread(this.textdiary);
                % Update the GUI text box with the latest content
                this.GuiHandles.MsgBox.String = diaryContent;
            catch err
                % Handle any error that occurs while reading the file
                this.unwrapError(err);
            end
        end
        function updateMessageText(this, decision, interval, interval_time)
            if contains(decision, 'time out')
                set(this.message_handle, 'Text', interval);
            else
                set(this.message_handle, 'Text', interval + " (" + num2str(interval_time) + " sec)");
            end
        end
        %Update the data object
        function UpdateData(this)
            %Save these records, which will be eventually moved to the Data
            % Names of data structure fields:
            % structOrder = {
            %         'TimeStamp',
            %         'Score',
            %         'Level',
            %         'isLeftTrial',
            %         'CodedChoice',
            %         'RewardPulses',
            %         'InterTMal',
            %         'DuringTMal',
            %         'TrialStartTime',
            %         'ResponseTime',
            %         'DrinkTime',
            %         'SetIdx'
            %         'isTraining',
            %         'SideBias',
            %         'BetweenTrialTime',
            %         'SetStr',
            %         'SetUpdate',
            %         'Settings',
            %         'RewardTime',
            %         'WhatDecision'};
            %New
            this.Data_Object.AddData( ...
                this.Level, ...
                this.isLeftTrial, ...
                this.WhatDecision, ...
                this.RewardPulses, ...
                this.InterTMal, ...
                this.DuringTMal, ...
                this.TrialStartTime, ...
                this.ResponseTime, ...
                this.DrinkTime, ...
                this.BetweenTrialTime, ...
                this.SideBias, ...
                this.SetIdx, ...
                this.SetStr(end))

            this.wheelchoice_record{this.i,1} = this.WhatDecision;
            this.wheelchoice_record{this.i,2} = this.wheelchoice;
            this.wheelchoice_record{this.i,3} = this.wheelchoicetime;

            this.RewardPulses = 0;
            this.InterTMal = 0;
            this.DuringTMal = 0;
            this.TrialStartTime = 0;
            this.ResponseTime = 0;
            this.DrinkTime = 0;
            this.BetweenTrialTime = 0;
            this.wheelchoice = cell(1,1e6);
            this.wheelchoicetime = cell(1,1e6);
            %Plot graphs
            if isvalid(this.graphFig)
                this.Data_Object.PlotNewData();
            else
                this.graphFig = figure("Name", "Graphs", "MenuBar","none");
                this.Data_Object.Axes = this.Data_Object.CreateGraphs(this.graphFig);
                this.Data_Object.PlotData();
            end
            %update Gui window
            this.setGuiNumbers(this.GUI_numbers);
        end
        %save data when done, give unique name for stimulus, input, etc.
        function SaveAllData(this, options)
            arguments
                this
                options.Activity = "Training"
                options.PosRecord = [];
                options.TimeLog = []
                options.MapLog = []
                options.MapMeta = struct()
                options.TimestampRecord = []
            end
            fakeNames = {'w', 'W'};
            if any(strcmp(num2str(this.Setting_Struct.Subject), fakeNames)) || any(strcmp(this.Setting_Struct.Strain, fakeNames)) %do not save if I use a fake name for fake data
                return
            end
            D = string(datetime(this.Data_Object.start_time, "Format", "yyMMdd_HHmmss"));
            if options.Activity == "Training"
                stim = erase(this.app.Stimulus_type.Value, ' ');
            else
                stim = 'Animate';
            end
            input = this.app.Box_Input_type.Value;
            Sub = this.Setting_Struct.Subject;
            Str = this.Data_Object.Str;
            saveasname = join([D Sub Str stim input],'_');
            savefolder = this.normalizeSaveFolder_(this.Data_Object.filedir);
            set(this.message_handle,'Text', 'Saving data as: '+saveasname+'.mat');
            Settings = this.combineSettingsForSave_();
            Notes = this.GuiHandles.NotesText.String;
            if options.Activity == "Training"
                [newData] = this.Data_Object.current_data_struct;
                names = fieldnames(newData);
                for n = names(structfun(@isrow, newData) & structfun(@length, newData) > 1)' %Make sure everything is saved as a column
                    newData.(n{:}) = newData.(n{:})';
                end
                FullTrials = this.committedTrialCountForSave_(newData);
                for n = names(structfun(@length, newData) > FullTrials)'
                    newData.(n{:}) = newData.(n{:})(1:FullTrials);
                end
                newData.SetUpdate = this.SetUpdate;
                nonEmptyRows = any(~cellfun(@isempty, this.StimHistory'))';
                newData.StimHist = this.StimHistory(nonEmptyRows,:);
                rmv = {'GUI_numbers', 'encoder'};
                for r = rmv
                    try
                        Settings = rmfield(Settings, r);
                    catch
                    end
                end
                newData.Settings = Settings;
                if this.Box.Input_type == 6
                    newData.wheel_record = this.wheelchoice_record;
                    newData.wheel_record(any(cellfun(@isempty, newData.wheel_record)'),:) = [];
                    timeSegments = this.timestamps_record;
                    if ~isempty(timeSegments)
                        timeSegments = timeSegments(~cellfun(@isempty, timeSegments));
                    end
                    timeSegments = this.annotateTimestampSegmentsForSave_(timeSegments, FullTrials);
                    newData.TimestampRecord = timeSegments;
                    if ~isempty(this.Time) && isobject(this.Time)
                        newData.WheelDisplayRecord = this.annotateWheelDisplayRecordForSave_(this.WheelDisplayRecord, FullTrials);
                        newData.FrameAlignedRecord = this.FrameAlignedRecord;
                    end
                    [newData.EyeTrackingRecord, newData.EyeTrackingMeta] = this.eyeTrackSaveOutputs_();

                end
                if isscalar(this.SetUpdate) % Settings never changed during the session.
                    newData.SetStr = this.SetStr;
                    newData.Include = repmat(this.Include, size(newData.TimeStamp));
                    newData.SetIdx = repmat(this.SetIdx, size(newData.TimeStamp));
                elseif numel(this.SetUpdate) > 1
                    try
                        Ts = this.Include;
                        newData.SetStr =  this.SetStr;
                        Idcs = unique([cell2mat(this.SetUpdate) length(newData.TimeStamp)]);
                        [~, ~, newData.SetIdx] = histcounts(1:length(newData.TimeStamp), Idcs);
                        newData.Include = Ts(newData.SetIdx);
                    catch
                    end
                end
                newData.Weight = this.Setting_Struct.Weight;
                f = [];
                try
                    if ~isempty(this.graphFig) && isvalid(this.graphFig)
                        f = figure("MenuBar","none","Visible","off");
                        copyobj(this.graphFig.Children, f)
                        f.Children.Title.String = string(this.Data_Object.Inp)+" "+this.formatSubjectLabel_(this.Data_Object.Sub);
                    end
                catch
                    f = [];
                end
                try
                    try
                        saveFile = fullfile(savefolder, char(saveasname + ".mat"));
                        save(saveFile, 'Settings', 'newData', 'Notes')
                        if ~isempty(f) && isvalid(f)
                            this.saveFigure(f, savefolder, saveasname)
                        end
                        dispstring = 'Data saved as: '+saveasname;
                        fprintf(dispstring+'\n');
                        set(this.message_handle,'Text',dispstring);
                    catch err
                        this.unwrapError(err)
                        [file,path] = uiputfile(pwd , 'Choose folder to save training data' , saveasname);
                        if isequal(file, 0) || isequal(path, 0)
                            set(this.message_handle,'Text', 'Save canceled.');
                            return
                        end
                        save(fullfile(path, file),  'Settings', 'newData')
                        if ~isempty(f) && isvalid(f)
                            this.saveFigure(f, path, erase(string(file), '.mat'))
                        end
                    end
                catch err
                    save(fullfile(pwd, char(saveasname + ".mat")), 'Settings', 'newData', 'Notes')
                    this.unwrapError(err)
                end
                % f.MenuBar = 'figure';
                % f.Visible = 1;
                if ~isempty(f) && isvalid(f)
                    close(f)
                end
            elseif options.Activity == "Animate"
                Position_Record = options.PosRecord;
                TimeLog = options.TimeLog;
                MapLog = options.MapLog;
                MapMeta = options.MapMeta;
                TimestampRecord = options.TimestampRecord;
                saveFile = fullfile(savefolder, char(saveasname + ".mat"));
                try
                    save(saveFile, 'Settings', 'Position_Record', 'Notes', 'TimeLog', 'MapLog', 'MapMeta', 'TimestampRecord')
                catch err
                    this.unwrapError(err)
                    [file,path] = uiputfile(pwd , 'Choose folder to save animation data' , saveasname);
                    if isequal(file, 0) || isequal(path, 0)
                        set(this.message_handle,'Text', 'Save canceled.');
                        return
                    end
                    save(fullfile(path, file), 'Settings', 'Position_Record', 'Notes', 'TimeLog', 'MapLog', 'MapMeta', 'TimestampRecord')
                end
                dispstring = 'Data saved as: '+saveasname;
                fprintf(dispstring+'\n');
                set(this.message_handle,'Text',dispstring);
            end
        end
        function Settings = combineSettingsForSave_(this)
            Settings = this.Setting_Struct;
            if isempty(this.Old_Setting_Struct)
                return
            end
            try
                oldSettings = [this.Old_Setting_Struct{:}];
                Settings = [Settings oldSettings];
            catch
                try
                    oldSettings = cell2mat(this.Old_Setting_Struct);
                    Settings = [Settings oldSettings];
                catch
                    % Keep current settings only if legacy setting structs are incompatible.
                end
            end
        end
        function folder = normalizeSaveFolder_(~, filedir)
            if iscell(filedir)
                if isempty(filedir)
                    folder = "";
                else
                    folder = string(filedir{1});
                end
            elseif isstring(filedir)
                if isempty(filedir)
                    folder = "";
                else
                    folder = filedir(1);
                end
            elseif ischar(filedir)
                folder = string(filedir);
            else
                folder = string(filedir);
            end

            folder = strtrim(folder);
            if strlength(folder) == 0
                folder = string(pwd);
            end
            if ~isfolder(folder)
                mkdir(folder);
            end
            folder = char(folder);
        end
        function subLabel = formatSubjectLabel_(~, subIn)
            s = string(subIn);
            s = s(strlength(s) > 0);
            if isempty(s)
                subLabel = "";
            else
                subLabel = strjoin(s, ", ");
            end
        end
        function cleanUP(this)
            hasActiveTimeSegment = this.hasActiveTimeSegment_();
            activeSegmentTrial = this.TimeSegmentTrial;
            % Preserve any active trial/setup segment before cleanup resets the logger.
            if this.Setting_Struct.One_ScanImage_File
                try
                    this.storeCurrentTimeSegmentIfActive_();
                    hasActiveTimeSegment = false;
                catch
                end
            end
            % Send Stop Acquisition signal to ScanImage
            try
                set(this.message_handle, 'Text', "Stopping acquisition (ScanImage)...");
            catch
            end
            try
                this.a.Acquisition('End');
            catch
            end
            if this.Setting_Struct.One_ScanImage_File
                try
                    this.beginTimeSegment_("cleanup", NaN);
                    this.logTimeEvent_("acq_end", struct('trial', NaN, 'scanImageFile', this.TimeScanImageFileIndex));
                catch
                end
            elseif hasActiveTimeSegment
                try
                    this.logTimeEvent_("acq_end", struct('trial', activeSegmentTrial, 'scanImageFile', this.TimeScanImageFileIndex));
                catch
                end
            end
            if this.Setting_Struct.One_ScanImage_File || hasActiveTimeSegment
                try
                    this.storeCurrentTimeSegmentIfActive_();
                catch
                end
            end
            %switch on all buttons
            this.toggleButtonsOnOff(this.Buttons,1);
            this.stop_handle.Value = 0;%Turn off Stop button
            this.stopEyeTrackForSession_();
            %close stimulus if still open
            delete(findobj("Type", "figure", "Name", "Stimulus"))
            this.fig = [];
            this.ReadyCueAx = [];
            this.LStimAx = [];
            this.RStimAx = [];
            this.FLAx = [];
            this.Stimulus_Object = struct();
            disp_string = ['Stopped training Mouse ',num2str(this.Setting_Struct.Subject), ' at ',string(datetime("now"))];
            disp(disp_string);
            disp('- - - - -');
        end
        function ReadyCue(this, isVis)
            switch 1
                case islogical(isVis)
                    set(this.ReadyCueAx, 'Visible', isVis)
                case isVis == "Create"
                    oldRQ = findobj(this.fig, 'Type', 'axes', 'Tag', 'ReadyCue');
                    if ~isempty(oldRQ)
                        delete(oldRQ(isgraphics(oldRQ)));
                    end
                    RCAx = axes('Parent', this.fig, ...
                        'Position', [0 0 1 1], ...
                        'Color', 'k', ...
                        'Tag', 'ReadyCue', ...
                        'XColor', 'none', ...
                        'YColor', 'none', ...
                        'YTick', [], ...
                        'XTick', []);
                    this.ReadyCueAx = RCAx;
                    % Keep old layering intent (ReadyCue not top-most), but make it
                    % robust to any number of figure children.
                    try
                        ch = this.fig.Children;
                        iRQ = find(ch == RCAx, 1, 'first');
                        if ~isempty(iRQ)
                            others = ch([1:iRQ-1 iRQ+1:end]);
                            ins = min(3, numel(others) + 1);
                            newOrder = [others(1:ins-1); RCAx; others(ins:end)];
                            this.fig.Children = newOrder;
                        end
                    catch
                    end
                    % case ischar(isVis) %Letter color abbrev.
                    %     ax = findobj(this.ReadyCueAx, 'Type', 'Axes');
                    %     ax.Color = char(isVis);
                    %     [this.ReadyCueAx.Visible] = deal(1);
                    %     try
                    %         [this.ReadyCueAx.Children.Visible] = deal(0);
                    %     end
                    %     return
            end
            % Plot a circle in the center to show that a new trial is ready
            %Make the figure if this is the first call to readycue, or make a new one
            %if the window has been closed
            % if ~isempty(this.ReadyCueAx) & all(isvalid(this.ReadyCueAx))
            %     [this.ReadyCueAx.Visible] = deal(isVis);
            %     if this.Box.Input_type~=6
            %         [this.ReadyCueAx.Children.Visible] = deal(isVis);
            %     end
            % else %First time, make axis
            %     RQ_Ax = axes('Parent', this.fig, ...
            %         'color', this.ReadyCueStruct.Color, ...
            %         'Position', [0 0 1 1], ...
            %         'Xlim', [-10 10], ...
            %         'YLim', [-7 13], ...
            %         'XTick',[], 'YTick',[], ...
            %         'Tag', 'ReadyCue');
            %     hold(findobj(this.fig, 'Tag', 'ReadyCue'), 'on')
            %     this.ReadyCueAx = [findobj(this.fig, 'Tag', 'ReadyCue')];
            %     this.Flash(this.StimulusStruct, this.Box, findobj('Tag', 'ReadyCueDot'), 'NewStim')
            % end
        end
        function TestStimulus(this, options)
            arguments
                this
                options.SaveStimulus logical = 0
                options.AnimateMode logical = 0
                options.StimType char = 'Stimulus'
            end
            stimType = char(this.canonicalAnimateStyle_(options.StimType));
            tic
            this.app.ShowStim.Enable = 0; %Disable this when debugging...
            this.app.Stimulus_FinishLine.Value = true;
            this.getGUI();
            this.Setting_Struct.Stimulus_FinishLine = ~options.AnimateMode;
            this.StimulusStruct.FinishLine = ~options.AnimateMode;
            this.Stimulus_Object = BehaviorBoxVisualStimulus(this.StimulusStruct, Preview=1);
            this.Stimulus_Object = this.Stimulus_Object.updateProps(this.StimulusStruct);
            this.Stimulus_Object.DotSize = this.ReadyCueStruct.Size;
            if isempty([this.Stimulus_Object.LStimAx this.Stimulus_Object.RStimAx])
                [this.fig,this.LStimAx,this.RStimAx, ~] = this.Stimulus_Object.setUpFigure(); drawnow
                this.Stimulus_Object = this.Stimulus_Object.findfigs();
            end
            if options.AnimateMode
                switch this.app.Animate_Side.Value
                    case "Left"
                        this.isLeftTrial = true;
                    case "Random"
                        this.isLeftTrial = this.PickSideForCorrect(0, 0);
                    case "Right"
                        this.isLeftTrial = false;
                    otherwise
                end
                [~,~] = this.Stimulus_Object.DisplayOnScreen(this.isLeftTrial, ...
                    this.Setting_Struct.Starting_opacity, "AnimateMode", true, "StimType", stimType);
            else
                [~,~] = this.Stimulus_Object.DisplayOnScreen(this.PickSideForCorrect(0, 0), ...
                    this.Setting_Struct.Starting_opacity);
            end
            this.fig = this.Stimulus_Object.fig;
            if this.isMappingStyle_(stimType)
                set(this.fig.findobj('Tag','Spotlight'), 'Visible', false)
            else
                [this.fig.findobj('Tag','Spotlight').Visible] = deal(1);
            end
            toc
            drawnow
            if this.isMappingStyle_(stimType)
                try
                    this.app.Animate_XPosition.Value = min(max(double(this.app.Animate_XPosition.Value), 0), 1);
                    this.app.Animate_YPosition.Value = min(max(double(this.app.Animate_YPosition.Value), 0), 1);
                catch
                    this.app.Animate_XPosition.Value = 0.5;
                    this.app.Animate_YPosition.Value = 0.5;
                end
            elseif contains(stimType, "-Line")
                this.app.Animate_XPosition.Value = 0.5;
                this.app.Animate_YPosition.Value = 0.5;
                %this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Type', 'ConstantLine'), "NewStim")
            elseif contains(stimType, "Dot")
                this.app.Animate_XPosition.Value = 0.5;
                this.app.Animate_YPosition.Value = 0.5;
                %this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Tag', 'Dot'), "NewStim")
            else
                this.app.Animate_XPosition.Value = 0.25;
                this.app.Animate_YPosition.Value = 0.5;
                %this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Type', 'Line'), "NewStim")
            end
            if options.SaveStimulus
                name = "Stim-Lv-"+this.Setting_Struct.Starting_opacity;
                this.Data_Object = BehaviorBoxData( ...
                    Inv=this.app.Inv.Value, ...
                    Inp=this.app.Box_Input_type.Value, ...
                    Str=this.app.Strain.Value, ...
                    Sub={this.app.Subject.Value}, ...
                    find=1, ...
                    load=0);
                this.Data_Object.SaveManyFigures([],name)
            end
            this.app.ShowStim.Enable = 1;
        end
        function style = canonicalAnimateStyle_(~, styleIn)
            style = string(styleIn);
            switch style
                case "Sweeping Bar"
                    style = "Bar";
                case "Flash Stimulus"
                    style = "Stimulus";
                case {"Map-SweepVerticalLine", "Map-SweepOrientedLine"}
                    style = "Map-SweepLine";
                otherwise
            end
        end
        function tf = isMappingStyle_(this, styleIn)
            tf = startsWith(this.canonicalAnimateStyle_(styleIn), "Map-");
        end
        function previewMappingStimulus_(this, style)
            style = this.canonicalAnimateStyle_(style);
            opts = this.buildMappingOptions_(style);
            this.TestStimulus("AnimateMode", true, "StimType", char(style));
            if isempty(this.Stimulus_Object) || ~ismethod(this.Stimulus_Object, 'setupMappingScene')
                return
            end
            this.Stimulus_Object.setupMappingScene(char(style), ...
                "AngleDeg", opts.OrientedLineAngleDeg, ...
                "LoomVariant", opts.LoomVariant, ...
                "LoomLevel", opts.LoomLevel, ...
                "FixEnabled", opts.FixEnabled, ...
                "FixRadius", opts.FixRadius, ...
                "FixX", opts.FixX, ...
                "FixY", opts.FixY, ...
                "InitialVisible", true);
            this.fig = this.Stimulus_Object.fig;
            drawnow
        end
        function flashVisibleMappingObjects_(this)
            if isempty(this.Stimulus_Object) || ~ismethod(this.Stimulus_Object, 'getMappingTargets')
                return
            end
            targets = this.Stimulus_Object.getMappingTargets();
            h = [targets.MapContourLine; targets.MapRandomLine; targets.MapSweepLine];
            h = h(isgraphics(h));
            if isempty(h)
                return
            end
            h = h(arrayfun(@(obj) strcmp(obj.Visible, 'on'), h));
            if isempty(h)
                return
            end
            this.BasicFlash("Lines", h, "NewColor", this.StimulusStruct.FlashColor, ...
                "steps", max(2, this.StimulusStruct.FreqAnimation));
        end
        function opts = buildMappingOptions_(this, style)
            style = this.canonicalAnimateStyle_(style);
            opts = struct();
            opts.Style = style;
            opts.Mode = erase(style, "Map-");
            opts.SettlePauseSec = this.getAppNumericValue_("Map_SettlePauseSec", 5.0);
            opts.FlashDurationSec = this.getAppNumericValue_("Map_FlashDurationSec", 0.5);
            opts.InterFlashIntervalSec = this.getAppNumericValue_("Map_InterFlashIntervalSec", 2.0);
            opts.FlashCount = max(1, round(this.getAppNumericValue_("Map_FlashCount", 5)));
            opts.FlashXMin = this.getAppNumericValue_("Map_FlashXMin", -0.8);
            opts.FlashXMax = this.getAppNumericValue_("Map_FlashXMax", 0.8);
            opts.SweepXMin = this.getAppNumericValue_("Map_SweepXMin", -1.2);
            opts.SweepXMax = this.getAppNumericValue_("Map_SweepXMax", 1.2);
            opts.SweepSpeed = this.getAppNumericValue_("Map_SweepSpeed", max(0.2, this.getAppNumericValue_("Animate_Speed", 0.6)));
            opts.OrientedLineAngleDeg = this.getAppNumericValue_("Map_OrientedLineAngleDeg", this.getAppNumericValue_("Animate_LineAngle", 90));

            xSlider = this.getAppNumericValue_("Animate_XPosition", 0.5);
            ySlider = this.getAppNumericValue_("Animate_YPosition", 0.5);
            opts.LoomX = this.sliderToMapCoord_(xSlider);
            opts.LoomY = this.sliderToMapCoord_(ySlider);
            opts.LoomMinScale = this.getAppNumericValue_("Map_LoomMinScale", 0.5);
            opts.LoomMaxScale = this.getAppNumericValue_("Map_LoomMaxScale", 1.5);
            opts.LoomPeriodSec = this.getAppNumericValue_("Map_LoomPeriodSec", 2.0);
            opts.LoomVariant = string(this.getAppControlValue_("Map_LoomVariant", "Correct"));
            opts.LoomLevel = max(1, round(this.getAppNumericValue_("Starting_opacity_Temp", ...
                this.getStructNumericValue_(this.Setting_Struct, "Starting_opacity_Temp", ...
                this.getStructNumericValue_(this.Setting_Struct, "Starting_opacity", 1)))));

            opts.FixEnabled = this.getAppLogicalValue_("Fix_Enable", false);
            opts.FixX = this.getAppNumericValue_("Fix_X", this.sliderToMapCoord_(xSlider));
            opts.FixY = this.getAppNumericValue_("Fix_Y", this.sliderToMapCoord_(ySlider));
            opts.FixRadius = this.getAppNumericValue_("Fix_Radius", 0.03);
            opts.FixPeriodSec = this.getAppNumericValue_("Fix_PeriodSec", 2.0);
            opts.FixPeakThreshold = this.getAppNumericValue_("Fix_PeakThreshold", 0.98);
            opts.FixRewardCooldownSec = this.getAppNumericValue_("Fix_RewardCooldownSec", 2.0);
            opts.FixRewardSide = string(this.getAppControlValue_("Fix_RewardSide", "Right"));
            opts.FixRewardEnabled = this.getAppLogicalValue_("Fix_RewardEnable", this.getAppLogicalValue_("Animate_MimicTrial", false));
            opts.DrawHz = max(15, min(120, round(this.getAppNumericValue_("Map_DrawHz", 60))));
        end
        function value = getAppControlValue_(this, propName, defaultValue)
            value = defaultValue;
            name = char(propName);
            if ~isprop(this.app, name)
                return
            end
            try
                obj = this.app.(name);
                if isprop(obj, 'Value')
                    value = obj.Value;
                else
                    value = obj;
                end
            catch
                value = defaultValue;
            end
        end
        function value = getAppNumericValue_(this, propName, defaultValue)
            raw = this.getAppControlValue_(propName, defaultValue);
            value = str2double(string(raw));
            if isnan(value)
                value = defaultValue;
            end
        end
        function value = getAppLogicalValue_(this, propName, defaultValue)
            raw = this.getAppControlValue_(propName, defaultValue);
            try
                value = logical(raw);
            catch
                value = defaultValue;
            end
        end
        function value = getStructNumericValue_(~, dataStruct, fieldName, defaultValue)
            value = defaultValue;
            try
                if isstruct(dataStruct) && isfield(dataStruct, fieldName)
                    raw = dataStruct.(fieldName);
                    if iscell(raw)
                        raw = raw{1};
                    end
                    parsed = str2double(string(raw));
                    if ~isnan(parsed)
                        value = parsed;
                    end
                end
            catch
                value = defaultValue;
            end
        end
        function coord = sliderToMapCoord_(~, value)
            coord = 2 * (double(value) - 0.5);
        end
        function tf = mappingShouldAbort_(this)
            tf = false;
            try
                tf = tf || logical(this.stop_handle.Value);
            catch
            end
            try
                tf = tf || logical(this.app.Stop.Value);
            catch
            end
            try
                tf = tf || logical(this.app.Animate_End.Value);
            catch
            end
        end
        function matrix = makeMappingTransform_(~, x, y, angleDeg, scaleValue)
            if nargin < 5 || isempty(scaleValue)
                scaleValue = 1;
            end
            T = makehgtform('translate', [double(x) double(y) 0]);
            R = makehgtform('zrotate', deg2rad(double(angleDeg)));
            S = makehgtform('scale', [double(scaleValue) double(scaleValue) 1]);
            matrix = T * R * S;
        end
        function rows = appendMappingState_(this, rows, t0, modeName, extra)
            t_us = round(1e6 * toc(t0));
            row = this.makeMappingRow_(t_us, "State", modeName, extra);
            rows(end+1,1) = row;
        end
        function [rows, t_us] = appendMappingEvent_(this, rows, t0, modeName, eventName, extra)
            t_us = round(1e6 * toc(t0));
            fields = struct( ...
                'kind', "mapping", ...
                'mode', string(modeName), ...
                'trial', 0, ...
                'scanImageFile', this.TimeScanImageFileIndex, ...
                't_us', t_us);
            if nargin >= 6 && ~isempty(extra)
                f = fieldnames(extra);
                for iField = 1:numel(f)
                    fields.(f{iField}) = extra.(f{iField});
                end
            end
            try
                this.logTimeEvent_(string(eventName), fields);
            catch
            end
            row = this.makeMappingRow_(t_us, eventName, modeName, extra);
            rows(end+1,1) = row;
        end
        function value = encodeMappingValue_(~, raw)
            if islogical(raw)
                value = string(mat2str(raw));
            elseif isnumeric(raw)
                if isempty(raw)
                    value = "";
                elseif isscalar(raw)
                    value = string(raw);
                else
                    value = strjoin(string(raw(:))', ",");
                end
            else
                value = string(raw);
            end
            value = regexprep(value, '\s+', '_');
        end
        function row = makeMappingRow_(~, t_us, eventName, modeName, extra)
            row = struct( ...
                't_us', double(t_us), ...
                'event', string(eventName), ...
                'mode', string(modeName), ...
                'x', NaN, ...
                'y', NaN, ...
                'angleDeg', NaN, ...
                'scale', NaN, ...
                'brightness', NaN, ...
                'variant', "", ...
                'notes', "");
            if nargin < 5 || isempty(extra)
                return
            end
            fields = fieldnames(extra);
            extraNotes = strings(0,1);
            for iField = 1:numel(fields)
                fieldName = fields{iField};
                val = extra.(fieldName);
                switch fieldName
                    case 'x'
                        row.x = double(val);
                    case 'y'
                        row.y = double(val);
                    case 'angleDeg'
                        row.angleDeg = double(val);
                    case 'scale'
                        row.scale = double(val);
                    case 'brightness'
                        row.brightness = double(val);
                    case 'variant'
                        row.variant = string(val);
                    case 'notes'
                        row.notes = string(val);
                    otherwise
                        extraNotes(end+1,1) = string(fieldName) + "=" + string(val);
                end
            end
            if ~isempty(extraNotes)
                extraText = strjoin(extraNotes, " ");
                if strlength(row.notes) == 0
                    row.notes = extraText;
                else
                    row.notes = strjoin([row.notes extraText], " ");
                end
            end
        end
        function tableOut = mappingRowsToTable_(this, rows)
            if isempty(rows)
                tableOut = table('Size', [0 9], ...
                    'VariableTypes', {'double','string','string','double','double','double','double','double','string'}, ...
                    'VariableNames', {'t_us','event','mode','x','y','angleDeg','scale','brightness','variant'});
                tableOut = addvars(tableOut, strings(0,1), 'NewVariableNames', 'notes');
                return
            end
            tableOut = struct2table(rows);
        end
        function side = normalizeRewardSide_(~, inSide)
            side = upper(extractBefore(string(inSide), 2));
            if isempty(side)
                side = "R";
            end
            switch side
                case {"L","LEFT"}
                    side = "L";
                otherwise
                    side = "R";
            end
        end
        function out = boolToOnOff_(~, tf)
            if tf
                out = 'on';
            else
                out = 'off';
            end
        end
        function [rows, fixState, brightness] = updateFixationOverlay_(this, rows, t0, modeName, targets, fixState)
            brightness = NaN;
            if ~fixState.Enabled || isempty(targets.FixDotPatch) || ~isgraphics(targets.FixDotPatch)
                return
            end
            tSec = toc(t0);
            brightness = 0.5 * (1 + sin((2*pi*tSec / max(fixState.PeriodSec, eps)) - (pi/2)));
            targets.FixDotPatch.Visible = 'on';
            targets.FixDotPatch.FaceColor = brightness .* [1 1 1];
            if isnan(fixState.LastBrightness)
                fixState.LastBrightness = brightness;
            end
            t_us = round(1e6 * tSec);
            crossed = brightness >= fixState.PeakThreshold && fixState.LastBrightness < fixState.PeakThreshold;
            if crossed && fixState.RewardEnabled && (t_us - fixState.LastRewardUs) >= fixState.CooldownUs
                try
                    this.a.GiveReward("Side", char(fixState.RewardSide));
                catch
                end
                [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "RewardGiven", ...
                    struct('brightness', brightness, 'notes', "side="+fixState.RewardSide));
                fixState.LastRewardUs = t_us;
            end
            fixState.LastBrightness = brightness;
        end
        function [rows, fixState, aborted] = waitMappingInterval_(this, durationSec, rows, t0, modeName, targets, fixState, state)
            aborted = false;
            startWait = tic;
            lastSampleSec = -inf;
            while toc(startWait) < durationSec
                if this.mappingShouldAbort_()
                    aborted = true;
                    return
                end
                [rows, fixState, brightness] = this.updateFixationOverlay_(rows, t0, modeName, targets, fixState);
                tNowSec = toc(t0);
                if (tNowSec - lastSampleSec) >= (1 / max(fixState.DrawHz, 1))
                    stateNow = state;
                    stateNow.brightness = brightness;
                    rows = this.appendMappingState_(rows, t0, modeName, stateNow);
                    lastSampleSec = tNowSec;
                end
                drawnow
                pause(0.005);
            end
        end
        function [rows, fixState, aborted] = runMappingFlashContour_(this, rows, t0, modeName, targets, opts, fixState)
            aborted = false;
            xPositions = linspace(opts.FlashXMin, opts.FlashXMax, opts.FlashCount);
            for idx = 1:numel(xPositions)
                if this.mappingShouldAbort_()
                    aborted = true;
                    return
                end
                xPos = xPositions(idx);
                targets.MapGroup.Matrix = this.makeMappingTransform_(xPos, 0, 0, 1);
                targets.MapContourLine.Visible = 'on';
                [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "FlashOn", struct('x', xPos, 'y', 0));
                [rows, fixState, aborted] = this.waitMappingInterval_(opts.FlashDurationSec, rows, t0, modeName, targets, fixState, ...
                    struct('x', xPos, 'y', 0, 'scale', 1));
                if aborted
                    return
                end
                targets.MapContourLine.Visible = 'off';
                [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "FlashOff", struct('x', xPos, 'y', 0));
                [rows, fixState, aborted] = this.waitMappingInterval_(opts.InterFlashIntervalSec, rows, t0, modeName, targets, fixState, ...
                    struct('x', xPos, 'y', 0, 'scale', 1, 'notes', "hidden"));
                if aborted
                    return
                end
            end
        end
        function [rows, fixState, aborted] = runMappingSweep_(this, rows, t0, modeName, targets, opts, fixState, angleDeg)
            aborted = false;
            startOffset = opts.SweepXMin;
            endOffset = opts.SweepXMax;
            sweepSpeed = max(abs(opts.SweepSpeed), eps);
            directionSign = sign(endOffset - startOffset);
            if directionSign == 0
                directionSign = 1;
            end
            motionDir = [-sind(angleDeg) cosd(angleDeg)];
            [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "SweepStart", struct('angleDeg', angleDeg));
            sweepClock = tic;
            lastSampleSec = -inf;
            while true
                if this.mappingShouldAbort_()
                    aborted = true;
                    return
                end
                elapsed = toc(sweepClock);
                offset = startOffset + directionSign * sweepSpeed * elapsed;
                if directionSign > 0
                    offset = min(offset, endOffset);
                else
                    offset = max(offset, endOffset);
                end
                pos = motionDir .* offset;
                targets.MapSweepLine.Visible = 'on';
                targets.MapGroup.Matrix = this.makeMappingTransform_(pos(1), pos(2), angleDeg, 1);
                [rows, fixState, brightness] = this.updateFixationOverlay_(rows, t0, modeName, targets, fixState);
                tNowSec = toc(t0);
                if (tNowSec - lastSampleSec) >= (1 / max(fixState.DrawHz, 1))
                    rows = this.appendMappingState_(rows, t0, modeName, ...
                        struct('x', pos(1), 'y', pos(2), 'angleDeg', angleDeg, 'scale', 1, 'brightness', brightness));
                    lastSampleSec = tNowSec;
                end
                drawnow
                pause(0.005);
                if offset == endOffset
                    break
                end
            end
            [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "SweepEnd", struct('angleDeg', angleDeg));
        end
        function [rows, fixState, aborted] = runMappingLoom_(this, rows, t0, modeName, targets, opts, fixState)
            aborted = false;
            loomVariants = string(opts.LoomVariant);
            if any(strcmpi(loomVariants, "Alternate"))
                loomVariants = ["Correct"; "Incorrect"];
            end
            for idxVariant = 1:numel(loomVariants)
                variant = string(loomVariants(idxVariant));
                useRandom = strcmpi(variant, "Incorrect");
                targets.MapContourLine.Visible = this.boolToOnOff_(~useRandom);
                targets.MapRandomLine.Visible = this.boolToOnOff_(useRandom);
                [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "LoomStart", ...
                    struct('x', opts.LoomX, 'y', opts.LoomY, 'variant', variant));
                cycleClock = tic;
                lastSampleSec = -inf;
                peakLogged = false;
                while toc(cycleClock) < opts.LoomPeriodSec
                    if this.mappingShouldAbort_()
                        aborted = true;
                        return
                    end
                    cycleT = toc(cycleClock);
                    scaleNorm = 0.5 * (1 + sin((2*pi*cycleT / max(opts.LoomPeriodSec, eps)) - (pi/2)));
                    scaleNow = opts.LoomMinScale + (opts.LoomMaxScale - opts.LoomMinScale) * scaleNorm;
                    targets.MapGroup.Matrix = this.makeMappingTransform_(opts.LoomX, opts.LoomY, 0, scaleNow);
                    [rows, fixState, brightness] = this.updateFixationOverlay_(rows, t0, modeName, targets, fixState);
                    tNowSec = toc(t0);
                    if ~peakLogged && scaleNorm >= 0.98
                        [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "LoomPeak", ...
                            struct('x', opts.LoomX, 'y', opts.LoomY, 'scale', scaleNow, 'variant', variant));
                        peakLogged = true;
                    end
                    if (tNowSec - lastSampleSec) >= (1 / max(fixState.DrawHz, 1))
                        rows = this.appendMappingState_(rows, t0, modeName, ...
                            struct('x', opts.LoomX, 'y', opts.LoomY, 'scale', scaleNow, ...
                            'brightness', brightness, 'variant', variant));
                        lastSampleSec = tNowSec;
                    end
                    drawnow
                    pause(0.005);
                end
                [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "LoomEnd", ...
                    struct('x', opts.LoomX, 'y', opts.LoomY, 'variant', variant));
            end
        end
        function RunMappingStimulus(this, style, options)
            arguments
                this
                style
                options = struct()
            end
            style = this.canonicalAnimateStyle_(style);
            opts = this.buildMappingOptions_(style);
            modeName = erase(style, "Map-");
            if ~isempty(fieldnames(options))
                names = fieldnames(options);
                for iField = 1:numel(names)
                    opts.(names{iField}) = options.(names{iField});
                end
            end

            this.MappingAnimationLog = table();
            this.MappingMetadata = struct();
            this.StimulusStruct.FinishLine = false;
            this.Setting_Struct.Stimulus_FinishLine = false;
            this.Stimulus_Object = BehaviorBoxVisualStimulus(this.StimulusStruct, Preview=1);
            this.Stimulus_Object = this.Stimulus_Object.updateProps(this.StimulusStruct);
            [this.fig, this.LStimAx, this.RStimAx, this.FLAx, ~] = this.Stimulus_Object.setUpFigure();

            targets = this.Stimulus_Object.setupMappingScene(char(style), ...
                "AngleDeg", opts.OrientedLineAngleDeg, ...
                "LoomVariant", opts.LoomVariant, ...
                "LoomLevel", opts.LoomLevel, ...
                "FixEnabled", opts.FixEnabled, ...
                "FixRadius", opts.FixRadius, ...
                "FixX", opts.FixX, ...
                "FixY", opts.FixY, ...
                "InitialVisible", false);

            try
                set(this.fig.findobj('Tag', 'Spotlight'), 'Visible', false)
            catch
            end

            this.timestamps_record = cell(0,1);
            this.TimeSegmentKind = "";
            this.TimeSegmentTrial = NaN;
            this.TimeSegmentTic = [];
            this.TimeScanImageFileIndex = 1;
            try
                this.a.TimeStamp('Off');
            catch
            end
            try
                this.beginTimeSegment_("mapping", 0);
            catch
            end

            this.Data_Object.start_time = datetime("now");
            try
                set(this.message_handle, 'Text', "Starting acquisition (ScanImage)...");
            catch
            end
            try
                this.a.Acquisition('Start');
            catch
            end
            try
                this.logTimeEvent_("acq_start", struct('trial', 0, 'scanImageFile', this.TimeScanImageFileIndex));
            catch
            end
            t0 = this.TimeSegmentTic;
            if isempty(t0)
                t0 = tic;
            end
            rows = struct('t_us', {}, 'event', {}, 'mode', {}, 'x', {}, 'y', {}, ...
                'angleDeg', {}, 'scale', {}, 'brightness', {}, 'variant', {}, 'notes', {});
            sequenceTimestampOn = false;
            fixState = struct( ...
                'Enabled', logical(opts.FixEnabled), ...
                'RewardEnabled', logical(opts.FixRewardEnabled), ...
                'PeriodSec', double(opts.FixPeriodSec), ...
                'PeakThreshold', double(opts.FixPeakThreshold), ...
                'CooldownUs', double(opts.FixRewardCooldownSec) * 1e6, ...
                'LastBrightness', NaN, ...
                'LastRewardUs', -inf, ...
                'RewardSide', this.normalizeRewardSide_(opts.FixRewardSide), ...
                'DrawHz', double(opts.DrawHz));

            if ~isa(this.Data_Object, 'BehaviorBoxData')
                try
                    this.Data_Object = BehaviorBoxData( ...
                        Inv=this.app.Inv.Value, ...
                        Inp=this.app.Box_Input_type.Value, ...
                        Str=this.app.Strain.Value, ...
                        Sub={this.app.Subject.Value}, ...
                        find=1);
                catch
                end
            end
            [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "AcquisitionStart", struct());
            [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "DisplayOn", struct());
            [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "SettleStart", struct());
            [rows, fixState, aborted] = this.waitMappingInterval_(opts.SettlePauseSec, rows, t0, modeName, targets, fixState, struct('notes', "settle"));
            cycleIdx = 0;
            if ~aborted
                [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "SettleEnd", struct());
                try
                    this.a.TimeStamp('On');
                    sequenceTimestampOn = true;
                catch
                end
                [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "SequenceStart", struct());
                while ~this.mappingShouldAbort_()
                    cycleIdx = cycleIdx + 1;
                    [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "CycleStart", ...
                        struct('notes', "cycle="+string(cycleIdx), 'level', opts.LoomLevel));
                    switch style
                        case "Map-FlashContourX"
                            [rows, fixState, aborted] = this.runMappingFlashContour_(rows, t0, modeName, targets, opts, fixState);
                        case "Map-SweepLine"
                            [rows, fixState, aborted] = this.runMappingSweep_(rows, t0, modeName, targets, opts, fixState, opts.OrientedLineAngleDeg);
                        case "Map-LoomingStimulus"
                            [rows, fixState, aborted] = this.runMappingLoom_(rows, t0, modeName, targets, opts, fixState);
                        otherwise
                            aborted = true;
                    end
                    if aborted || this.mappingShouldAbort_()
                        break
                    end
                    [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "CycleEnd", struct('notes', "cycle="+string(cycleIdx)));
                end
            end

            if sequenceTimestampOn
                try
                    this.a.TimeStamp('Off');
                catch
                end
            end
            if aborted
                [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "SequenceEnd", struct('notes', "aborted"));
            else
                [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "SequenceEnd", struct('notes', "userStop"));
            end

            try
                if ismethod(this.Stimulus_Object, 'setupMappingScene')
                    this.Stimulus_Object.setupMappingScene(char(style), ...
                        "AngleDeg", opts.OrientedLineAngleDeg, ...
                        "LoomVariant", opts.LoomVariant, ...
                        "LoomLevel", opts.LoomLevel, ...
                        "FixEnabled", opts.FixEnabled, ...
                        "FixRadius", opts.FixRadius, ...
                        "FixX", opts.FixX, ...
                        "FixY", opts.FixY, ...
                        "InitialVisible", false);
                end
            catch
            end

            try
                this.a.Acquisition('End');
            catch
            end
            [rows, ~] = this.appendMappingEvent_(rows, t0, modeName, "AcquisitionEnd", struct());
            try
                this.logTimeEvent_("acq_end", struct('trial', 0, 'scanImageFile', this.TimeScanImageFileIndex, 't_us', round(1e6 * toc(t0))));
            catch
            end
            try
                this.storeCurrentTimeSegment_();
            catch
            end

            this.MappingAnimationLog = this.mappingRowsToTable_(rows);
            this.MappingMetadata = struct( ...
                'Style', style, ...
                'Mode', modeName, ...
                'TimeOrigin', "tic after beginTimeSegment_('mapping', 0)", ...
                'EventFormat', "BehaviorBoxSerialTime raw lines + parsed frame/signal/annotation rows", ...
                'CoordinateSystem', struct('XLim', [-1 1], 'YLim', [-1 1], 'Units', 'normalized'), ...
                'Options', opts, ...
                'StartedAt', this.Data_Object.start_time);

            timeLog = string.empty(0,1);
            timestampRecord = this.timestamps_record;
            try
                if ~isempty(timestampRecord)
                    timestampRecord = timestampRecord(~cellfun(@isempty, timestampRecord));
                    if ~isempty(timestampRecord)
                        rawCells = cellfun(@(seg) seg.raw, timestampRecord, 'UniformOutput', false);
                        timeLog = vertcat(rawCells{:});
                    end
                end
                if isempty(timeLog) && ~isempty(this.Time) && isobject(this.Time) && isprop(this.Time, 'Log')
                    timeLog = this.Time.Log;
                elseif isempty(timeLog) && isstruct(this.Time) && isfield(this.Time, 'Log')
                    timeLog = this.Time.Log;
                end
            catch
            end
            this.SaveAllData("Activity", "Animate", "PosRecord", [], ...
                "TimeLog", timeLog, "MapLog", this.MappingAnimationLog, ...
                "MapMeta", this.MappingMetadata, "TimestampRecord", timestampRecord);

            try
                close(this.fig)
            catch
            end
        end
        function AnimateReward(this)
            COUNT = 0;
            while ~this.app.Auto_Stop.Value
                this.a.GiveReward()
                COUNT = COUNT + 1;
                this.app.Auto_Msg.Text = COUNT+" Reward(s) given";
                pause(this.app.Auto_Freq.Value)
            end
        end
        function AnimateStimulus(this, options)
            arguments
                this
                options.Mode char = 'Create'
                options.Value double = 0
            end
            STYLE = this.canonicalAnimateStyle_(this.app.Animate_Style.Value);
            try
                if any(matches(this.app.Animate_Style.Items, STYLE))
                    this.app.Animate_Style.Value = STYLE;
                end
            catch
            end
            if options.Mode == "Show"
                if this.isMappingStyle_(STYLE)
                    this.getGUI();
                    this.previewMappingStimulus_(STYLE);
                else
                    this.getGUI();
                    this.TestStimulus("AnimateMode",true, "StimType", char(STYLE));
                end
                return
            end
            if options.Mode == "Go"
                if this.isMappingStyle_(STYLE)
                    this.getGUI();
                    this.RunMappingStimulus(STYLE);
                else
                    this.SetupBeforeAnimation("StartAcquisition", true);
                    this.TestStimulus("AnimateMode",true, "StimType", char(STYLE));
                    this.MoveStimuli();
                end
                return
            end
            if options.Mode == "Rec"
                this.SetupBeforeAnimation();
                this.RecordStimuli();
                return
            end
            if isempty(this.fig) || ~isgraphics(this.fig)
                if this.isMappingStyle_(STYLE)
                    this.getGUI();
                    this.previewMappingStimulus_(STYLE);
                else
                    this.getGUI();
                    this.TestStimulus("AnimateMode",true, "StimType", char(STYLE));
                end
            end
            if options.Mode == "XMove"
                if this.isMappingStyle_(STYLE)
                    this.previewMappingStimulus_(STYLE);
                    return
                end
                switch STYLE
                    case "Dot"
                        VAL = -0.5+options.Value;
                        AX = this.fig.Children(1);
                        AX.Position(1) = VAL;
                    case "X-Line"
                        VAL = -0.5+options.Value;
                        AX = this.fig.Children(1);
                        AX.Position(1) = VAL;
                    case "Y-Line"
                        % Do Nothing
                    otherwise % Bar or Stimulus
                        VAL = -0.25+options.Value;
                        AX = this.Stimulus_Object.LStimAx;
                        BX = this.Stimulus_Object.RStimAx;
                        AX.Position(1) = VAL;
                        BX.Position(1) = 0.5+VAL;
                end
            end
            if options.Mode == "YMove"
                if this.isMappingStyle_(STYLE)
                    this.previewMappingStimulus_(STYLE);
                    return
                end
                switch STYLE
                    case "Dot"
                        VAL = -0.5+options.Value;
                        AX = this.fig.Children(1);
                        AX.Position(2) = VAL;
                    case "X-Line"
                        % Do Nothing
                    case "Y-Line"
                        VAL = -0.5+options.Value;
                        AX = this.fig.Children(1);
                        AX.Position(2) = VAL;
                    otherwise % Bar or Stimulus
                        VAL = -0.5+options.Value;
                        AX = this.Stimulus_Object.LStimAx;
                        BX = this.Stimulus_Object.RStimAx;
                        AX.Position(2) = VAL;
                        BX.Position(2) = 0.5+VAL;
                end
            end
            if options.Mode == "Flash"
                if this.isMappingStyle_(STYLE)
                    this.flashVisibleMappingObjects_();
                elseif contains(STYLE, "-Line")
                    this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Type', 'ConstantLine'), "NewStim")
                elseif contains(STYLE, "Dot")
                    this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Tag', 'Dot'), "NewStim")
                else % Bar or Stimulus
                    this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Type', 'Line'), "NewStim")
                end
            end
        end
        function MoveStimuli(this, options)
            arguments
                this
                options.Type = 'normal';
                options.Record logical = false; % Make sure to turn this off after
            end
            set(this.fig, 'Renderer', 'OpenGL'); % openGL is the default but this may help
            style = this.canonicalAnimateStyle_(this.app.Animate_Style.Value);
            if options.Record
                folderName = 'RecordedFrames';
                if ~exist(folderName, 'dir') % Check if the folder exists in the current working directory
                    mkdir(folderName);
                    disp(['Folder "', folderName, '" created.']);
                else
                    disp(['Saving images to folder: "', folderName, '".']);
                end
            end
            Center = 0;
            switch style
                case "Dot"
                    AX = this.fig.Children(1);
                    BX.Position(1) = NaN;
                    maxPosition = 0.74; % Maximum x-axis position to move to
                    minPosition = -0.25; % Maximum x-axis position to move to
                    X_or_Y = 1;
                    % Make the Trial Stim at Indicated Level (Temp Settings Panel)
                    [~,~] = this.Stimulus_Object.DisplayOnScreen(this.app.Animate_Side.Value == "Left", ...
                        this.Temp_Settings.Starting_opacity, "NoDelete", true, "StartHidden", true);
                    %Handle for correct axis
                    CORRECTAX = this.fig.findobj('-regexp','Tag','Correct');
                    INCORRECTAX = this.fig.findobj('-regexp','Tag','Incorrect');
                    set(this.fig.findobj('-regexp','Tag','Spotlight'), 'Visible', false)
                    CORRECTAX.Position(1) = 0.25;
                    INCORRECTAX.Position(1) = 0.25;
                    DOT = AX.Children(1);
                    % Set Dot to Background color
                    DOT.FaceColor = this.StimulusStruct.BackgroundColor;
                    Flash_Steps = this.StimulusStruct.FreqAnimation;
                    %COLORS = repmat(linspace(0, 1, Flash_Steps),3,1);
                    COLORS = repmat(cos(linspace(pi/2, 0, Flash_Steps)),3,1);
                case "X-Line"
                    AX = this.fig.Children(1);
                    BX.Position(1) = NaN;
                    maxPosition = 0.5; % Maximum x-axis position to move to
                    minPosition = -0.5; % Maximum x-axis position to move to
                    X_or_Y = 1;
                case "Y-Line"
                    AX = this.fig.Children(1);
                    BX.Position(1) = NaN;
                    maxPosition = 0.5; % Maximum x-axis position to move to
                    minPosition = -0.5; % Maximum x-axis position to move to
                    X_or_Y = 2;
                case "Bar"
                    AX = this.Stimulus_Object.LStimAx;
                    BX = this.Stimulus_Object.RStimAx;
                    maxPosition = 0.74; % Maximum x-axis position to move to
                    minPosition = -0.25; % Maximum x-axis position to move to
                    X_or_Y = 1;
                    Center = 0.25;
                case "Stimulus"
                    AX = this.Stimulus_Object.LStimAx;
                    BX = this.Stimulus_Object.RStimAx;
                    maxPosition = 0.74; % Maximum x-axis position to move to
                    minPosition = -0.25; % Maximum x-axis position to move to
                    X_or_Y = 1;
                    Center = 0.25;
            end

            % Movement parameters
            stepSize = this.app.Animate_Speed.Value; % Adjust step size based on speed value

            if this.app.Animate_Side.Value == "Left"
                direction = -1;
            elseif this.app.Animate_Side.Value == "Right"
                direction = 1;
            end

            this.Data_Object.start_time = datetime("now");
            Pos_Record = zeros(2000,2);

            tic % Begin time recording
            try
                this.a.TimeStamp('On'); % 300 milisec builtin pause
            catch
            end
            one_drop_only = true;

            % Continuous loop for movement, stops when condition met or manually interrupted
            I = 1;
            Pos_Record(I,1) = toc;
            Pos_Record(I,2) = AX.Position(X_or_Y); % Record initial position
            if style ~= "Dot"
                % All other stimuli translate across the screen and the timestamp is
                % matched to their position
                while all([~this.app.Animate_End.Value ~this.app.Stop.Value])
                    try
                        % Send Next File signal to ScanImage
                        set(this.message_handle, 'Text', "Next file (ScanImage)...");
                        this.a.Acquisition('Next');
                    catch
                    end
                    % Update positions for axes
                    AX.Position(X_or_Y) = AX.Position(X_or_Y) + direction * stepSize;
                    %BX.Position(X_or_Y) = BX.Position(X_or_Y) + direction * stepSize;
                    if ~one_drop_only && AX.Position(X_or_Y) > (Center-0.01) && AX.Position(X_or_Y) < (Center+0.01)
                        if this.app.Animate_MimicTrial.Value
                            this.a.GiveReward()
                            one_drop_only = true;
                        end
                    end
                    % Check boundaries and reset position
                    if AX.Position(X_or_Y) > maxPosition
                        AX.Position(X_or_Y) = minPosition;
                        one_drop_only = false;
                    elseif AX.Position(X_or_Y) < minPosition
                        AX.Position(X_or_Y) = maxPosition;
                        one_drop_only = false;
                    end
                    drawnow;
                    I = I+1;
                    Pos_Record(I,1) = toc;
                    Pos_Record(I,2) = AX.Position(X_or_Y);
                end
            elseif style == "Dot"
                % The Dot mode oscillates brighter and dimmer and shows a Lv 20 stimulus
                % when at maximum brightness, and the timestamp is matched to the
                % brightness
                while all([~this.app.Animate_End.Value ~this.app.Stop.Value])
                    try
                        % Send Next File signal to ScanImage
                        set(this.message_handle, 'Text', "Next file (ScanImage)...");
                        this.a.Acquisition('Next');
                    catch
                    end
                    % Update positions for axes
                    for C = COLORS
                        set(DOT, 'FaceColor', C)
                        drawnow
                        pause(stepSize);
                        I = I+1;
                        Pos_Record(I,1) = toc;
                        Pos_Record(I,2) = C(1);
                    end
                    set(DOT, 'Visible',false)
                    I = I+1;
                    Pos_Record(I,1) = toc;
                    Pos_Record(I,2) = 2;
                    pause(0.5)
                    if this.app.Animate_OnlyIncorrectButton.Value
                        set(INCORRECTAX.Children, 'Visible',true)
                    else
                        set(CORRECTAX.Children, 'Visible',true)
                    end
                    I = I+1;
                    Pos_Record(I,1) = toc;
                    Pos_Record(I,2) = 3;
                    pause(0.5)
                    drawnow
                    pause(stepSize);
                    I = I+1;
                    Pos_Record(I,1) = toc;
                    Pos_Record(I,2) = 4;
                    if this.app.Animate_MimicTrial.Value
                        try
                            this.a.GiveReward()
                        catch
                        end
                    end
                    if this.app.Animate_OnlyIncorrectButton.Value
                        set(INCORRECTAX.Children, 'Visible',false)
                    else
                        set(CORRECTAX.Children, 'Visible',false)
                    end
                    I = I+1;
                    Pos_Record(I,1) = toc;
                    Pos_Record(I,2) = 5;
                    pause(0.5)
                    set(DOT, 'Visible',true)
                    I = I+1;
                    Pos_Record(I,1) = toc;
                    Pos_Record(I,2) = 6;
                    drawnow
                    pause(stepSize);
                    I = I+1;
                    Pos_Record(I,1) = toc;
                    Pos_Record(I,2) = 7;
                    for C = flip(COLORS,2) % Reverse order, fade the dot out
                        set(DOT, 'FaceColor', C)
                        drawnow
                        pause(stepSize);
                        I = I+1;
                        Pos_Record(I,1) = toc;
                        Pos_Record(I,2) = C(1);
                    end
                end
            end
            try
                set(this.message_handle, 'Text', "Ending acquisition (ScanImage)...");
                this.a.Acquisition('End');
            catch
            end
            close(this.fig)
            %Remove empty rows from Pos_Record
            Pos_Record = Pos_Record(~(Pos_Record(:,1) == 0 & Pos_Record(:,2) == 0), :);
            this.SaveAllData("Activity", "Animate", "PosRecord", Pos_Record);

            try
                this.a.TimeStamp('Off'); % 300 milisec builtin pause
            end
        end
        function RecordStimuli(this, options)
            arguments
                this
                options.Type = 'normal';
                options.Record logical = true; % Make sure to turn this off
            end
            % With mouse 303743 no settings were saved, so the defaults will be X-Line,
            % and the stimulus will loop through the saved timestamps
            STYLE = 'X-Line';
            DataToRec = this.Data_Object.loadedData(:,7);
            this.TestStimulus("AnimateMode",true, "StimType", STYLE);
            set(this.fig, 'Renderer', 'OpenGL'); % openGL is the default but this may help
            folderName = fullfile(this.Data_Object.filedir{:},'RecordedFrames');
            if ~exist(folderName, 'dir') % Check if the folder exists in the current working directory
                mkdir(folderName);
                disp(['Folder "', folderName, '" created.']);
            else
                disp(['Saving images to folder: "', folderName, '".']);
            end
            Center = 0;
            switch STYLE
                case "Dot"
                    AX = this.fig.Children(1);
                    BX.Position(1) = NaN;
                    maxPosition = 0.74; % Maximum x-axis position to move to
                    minPosition = -0.25; % Maximum x-axis position to move to
                    X_or_Y = 1;
                case "X-Line"
                    AX = this.fig.Children(1);
                    BX.Position(1) = NaN;
                    maxPosition = 0.5; % Maximum x-axis position to move to
                    minPosition = -0.5; % Maximum x-axis position to move to
                    X_or_Y = 1;
                case "Y-Line"
                    AX = this.fig.Children(1);
                    BX.Position(1) = NaN;
                    maxPosition = 0.5; % Maximum x-axis position to move to
                    minPosition = -0.5; % Maximum x-axis position to move to
                    X_or_Y = 2;
                case "Bar"
                    AX = this.Stimulus_Object.LStimAx;
                    BX = this.Stimulus_Object.RStimAx;
                    maxPosition = 0.74; % Maximum x-axis position to move to
                    minPosition = -0.25; % Maximum x-axis position to move to
                    X_or_Y = 1;
                    Center = 0.25;
                case "Stimulus"
                    AX = this.Stimulus_Object.LStimAx;
                    BX = this.Stimulus_Object.RStimAx;
                    maxPosition = 0.74; % Maximum x-axis position to move to
                    minPosition = -0.25; % Maximum x-axis position to move to
                    X_or_Y = 1;
                    Center = 0.25;
            end
            % Movement parameters
            %stepSize = this.app.Animate_Speed.Value; % Adjust step size based on speed value
            %if this.app.Animate_Side.Value == "Left"
            %    direction = -1;
            %elseif this.app.Animate_Side.Value == "Right"
            %    direction = 1;
            %end
            this.fig.InvertHardcopy = "off";
            axis off
            % fileName = sprintf('Frame%04d.tiff', 0);
            % fullFilePath = fullfile(folderName, fileName);
            % print(this.fig, '-dtiff', fullFilePath)
            I = 1;
            while all([~this.app.Animate_End.Value ~this.app.Stop.Value])
                % Update positions for axes
                AX.Position(X_or_Y) = AX.Position(X_or_Y) + direction * stepSize;
                BX.Position(X_or_Y) = BX.Position(X_or_Y) + direction * stepSize;
                Pos = AX.Position(X_or_Y);
                %fileName = sprintf('Frame-Pos%+05.2f-Frame%04d.tiff', Pos, i);
                fileName = sprintf('Frame-%04d-Pos%+05.2f.tiff', I, Pos);
                fullFilePath = fullfile(folderName, fileName);
                if ~exist(fullFilePath, 'file')
                    print(this.fig, '-dtiff', fullFilePath)
                else
                    break
                end
                % Check boundaries and reset position
                if AX.Position(X_or_Y) > maxPosition
                    AX.Position(X_or_Y) = minPosition;
                elseif AX.Position(X_or_Y) < minPosition
                    AX.Position(X_or_Y) = maxPosition;
                end
                drawnow;
                I = I+1;
            end
            close(this.fig)
        end
        function SimulateTrial(this)
            arguments
                this
            end
            AX = this.Stimulus_Object.LStimAx;
            BX = this.Stimulus_Object.RStimAx;
            if this.isLeftTrial
                direction = 1;
            else
                direction = -1;
            end
            Center = 0.25;

            X_or_Y = 1;

            % Movement parameters
            stepSize = this.app.Animate_Speed.Value; % Adjust step size based on speed value

            this.a.SwitchMode("Which","Speed")
            pause(0.2)
            while 1
                % Wait until the mouse spins the wheel in the right
                % direction at a high enough speed
                if abs(str2double(this.a.Reading)) >= 200
                    break
                end
                pause(0.01)
            end
            this.a.SwitchMode("Which","Position")
            while ~this.app.Stop.Value
                % Update positions for axes
                AX.Position(X_or_Y) = AX.Position(X_or_Y) + direction * stepSize;
                BX.Position(X_or_Y) = BX.Position(X_or_Y) + direction * stepSize;
                drawnow;
                if AX.Position(X_or_Y) > (Center-0.01) && AX.Position(X_or_Y) < (Center+0.01)
                    AX.Position(X_or_Y) = Center;
                    drawnow;
                    this.a.GiveReward()
                    break
                end
            end
        end
        function SaveMoveData(this, options)
            arguments
                this
                options.What = 'all'
            end
        end
        function interrupted = CheckForInterruptions(this)
            interrupted = false;
            if get(this.FF, 'Value')
                set(this.message_handle, 'Text', 'Skipping interval...');
                set(this.FF, 'Value', 0);
                interrupted = true;
            elseif get(this.stop_handle, 'Value')
                set(this.message_handle, 'Text', 'Ending session...');
                interrupted = true;
            end
            drawnow;
        end
    end
    methods (Access = private)
        function dataObject = createSessionDataObject_(this)
            dataObject = BehaviorBoxData( ...
                Inv=this.app.Inv.Value, ...
                Inp=this.app.Box_Input_type.Value, ...
                Str=this.app.Strain.Value, ...
                Sub={this.app.Subject.Value}, ...
                find=1);
            if ~isa(dataObject, 'BehaviorBoxData')
                error('BehaviorBoxWheel:InvalidDataObject', ...
                    'BehaviorBoxData setup did not return a BehaviorBoxData object.');
            end
        end

        function SetupBeforeAnimation(this, options)
            arguments
                this
                options.StartAcquisition logical = false
            end
            this.setAnimationFinishLine_(false);
            this.setGuiNumbers(this.GUI_numbers);
            this.Data_Object = this.createSessionDataObject_();
            this.Data_Object.StimType = 'Animate';
            this.Data_Object.SB = this.Setting_Struct.Data_Sbin;
            this.Data_Object.BB = this.Setting_Struct.Data_Lbin*this.Setting_Struct.Data_Sbin;
            this.Data_Object.current_data_struct = this.Data_Object.new_init_data_struct();
            this.Level = this.Setting_Struct.Starting_opacity;
            this.resetSessionState_();
            this.initializeEyeTrackForSession_();
            this.resetTimekeeperForSession_();
            this.setSessionStartTime_();
            this.TimeScanImageFileIndex = 1;
            rng('shuffle');
            if options.StartAcquisition
                try
                    set(this.message_handle, 'Text', "Starting acquisition (ScanImage)...");
                    this.a.Acquisition('Start');
                catch
                end
            end
        end

        function setAnimationFinishLine_(this, showFinishLine)
            try
                this.app.Stimulus_FinishLine.Value = logical(showFinishLine);
            catch
            end
            this.Setting_Struct.Stimulus_FinishLine = logical(showFinishLine);
            this.StimulusStruct.FinishLine = logical(showFinishLine);
        end

        function resetSessionState_(this)
            this.i = 0;
            this.timeout_counter = 0;
            this.Temp_Active = false;
            this.Temp_iStart = false;
            this.Temp_CorrectStart = 0;
            this.Temp_TrialStart = 0;
            this.Old_Setting_Struct = {};
            this.SetUpdate = {0};
            this.SetIdx = 1;
            [this.SetStr, this.Include] = this.structureSettings(this.Setting_Struct);
            this.StimHistory = cell(400,2);
            this.wheelchoice = cell(1,1e6);
            this.wheelchoicetime = cell(1,1e6);
            this.timestamps = cell(1,1e6);
            this.wheelchoice_record = cell(400,3);
            this.timestamps_record = cell(0,1);
            this.TimeSegmentKind = "";
            this.TimeSegmentTrial = NaN;
            this.TimeSegmentTic = [];
            this.TimeScanImageFileIndex = 0;
            this.WheelDisplayRecord = this.emptyWheelDisplayRecord_();
            this.FrameAlignedRecord = this.emptyFrameAlignedRecord_();
            this.CurrentTrialFrameAlignedRecord = this.emptyFrameAlignedRecord_();
            this.CurrentWheelPhase = "intertrial";
            this.CurrentRawWheel = 0;
            this.CurrentDelta = 0;
            this.CurrentStimColor = NaN;
            this.hold_still_start = [];
        end

        function initializeEyeTrackForSession_(this)
            try
                if ~isempty(this.EyeTrack) && isobject(this.EyeTrack)
                    delete(this.EyeTrack);
                end
            catch
            end
            this.EyeTrack = [];
            try
                eyeTrack = BehaviorBoxEyeTrack.tryCreateFromEnvironment();
                if ~isempty(eyeTrack) && isobject(eyeTrack)
                    this.EyeTrack = eyeTrack;
                end
            catch
                this.EyeTrack = [];
            end
        end

        function stopEyeTrackForSession_(this)
            if isempty(this.EyeTrack) || ~isobject(this.EyeTrack)
                return
            end
            try
                this.EyeTrack.markTrial(NaN);
            catch
            end
            try
                this.EyeTrack.stop();
            catch
            end
        end

        function resetTimekeeperForSession_(this)
            try
                this.a.TimeStamp('Off')
            catch
            end
            try
                if ~isempty(this.Time) && isobject(this.Time) && ~isempty(this.Time.Ard)
                    write(this.Time.Ard, '0', "char");
                    pause(0.05)
                end
            catch
            end
        end

        function setSessionStartTime_(this)
            this.TrainStartWallClock = datetime("now");
            this.TrainStartTime = tic;
            if ~isempty(this.Time) && isobject(this.Time)
                try
                    this.Time.TrainStartTime = this.TrainStartTime;
                    this.Time.TrainStartWallClock = this.TrainStartWallClock;
                catch
                end
            end
            if ~isempty(this.EyeTrack) && isobject(this.EyeTrack)
                try
                    this.EyeTrack.setSessionClock(this.TrainStartTime, this.TrainStartWallClock);
                    this.EyeTrack.markTrial(0);
                    this.EyeTrack.start();
                catch
                end
            end
            this.start_time = this.TrainStartWallClock;
            this.Data_Object.GetStartTime;
        end

        function beginTimeSegment_(this, kind, trialNumber)
            if isempty(this.Time) || ~isobject(this.Time)
                return
            end
            this.Time.Reset();
            pause(0.1)
            this.TimeSegmentKind = string(kind);
            this.TimeSegmentTrial = double(trialNumber);
            this.TimeSegmentTic = tic;
        end

        function storeCurrentTimeSegment_(this)
            if isempty(this.Time) || ~isobject(this.Time)
                return
            end

            try
                rawLog = this.Time.RawLog;
                parsedLog = this.Time.ParsedLog;
            catch
                rawLog = this.Time.Log;
                parsedLog = table();
            end

            if isempty(rawLog) && (isempty(parsedLog) || height(parsedLog) == 0)
                this.clearCurrentTimeSegmentState_();
                return
            end

            segment = struct();
            segment.trial = this.TimeSegmentTrial;
            segment.kind = this.TimeSegmentKind;
            segment.scanImageFile = this.TimeScanImageFileIndex;
            segment.raw = rawLog;
            segment.parsed = parsedLog;

            this.timestamps_record{end+1,1} = segment;
            this.clearCurrentTimeSegmentState_();
        end

        function storeCurrentTimeSegmentIfActive_(this)
            if ~this.hasActiveTimeSegment_()
                return
            end
            this.storeCurrentTimeSegment_();
        end

        function tf = hasActiveTimeSegment_(this)
            tf = strlength(this.TimeSegmentKind) > 0 || ...
                (~isempty(this.TimeSegmentTrial) && any(~isnan(this.TimeSegmentTrial)));
        end

        function clearCurrentTimeSegmentState_(this)
            this.TimeSegmentKind = "";
            this.TimeSegmentTrial = NaN;
            this.TimeSegmentTic = [];
        end

        function [eyeTrackingRecord, eyeTrackingMeta] = eyeTrackSaveOutputs_(this)
            eyeTrackingRecord = BehaviorBoxEyeTrack.emptyRecordTable();
            eyeTrackingMeta = BehaviorBoxEyeTrack.emptyMeta();
            if isempty(this.EyeTrack) || ~isobject(this.EyeTrack)
                return
            end
            try
                eyeTrackingRecord = this.EyeTrack.getRecord();
            catch
                eyeTrackingRecord = BehaviorBoxEyeTrack.emptyRecordTable();
            end
            try
                eyeTrackingMeta = this.EyeTrack.getMeta();
            catch
                eyeTrackingMeta = BehaviorBoxEyeTrack.emptyMeta();
            end
        end

        function committedTrials = committedTrialCountForSave_(~, newData)
            committedTrials = 0;
            if isfield(newData, 'Score') && ~isempty(newData.Score)
                committedTrials = numel(newData.Score);
            elseif isfield(newData, 'TimeStamp') && ~isempty(newData.TimeStamp)
                committedTrials = numel(newData.TimeStamp);
            end
        end

        function wheelDisplayRecord = annotateWheelDisplayRecordForSave_(this, wheelDisplayRecord, committedTrials)
            if isempty(wheelDisplayRecord) || ~istable(wheelDisplayRecord)
                wheelDisplayRecord = this.emptyWheelDisplayRecord_();
            end

            trialCommitted = false(height(wheelDisplayRecord), 1);
            trialStatus = repmat("session", height(wheelDisplayRecord), 1);
            if height(wheelDisplayRecord) > 0
                validRows = ~isnan(wheelDisplayRecord.trial) & wheelDisplayRecord.trial > 0;
                trialCommitted(validRows) = wheelDisplayRecord.trial(validRows) <= committedTrials;
                trialStatus(validRows & trialCommitted) = "committed";
                trialStatus(validRows & ~trialCommitted) = "in_progress";
            end

            wheelDisplayRecord.trialCommitted = trialCommitted;
            wheelDisplayRecord.trialStatus = trialStatus;
        end

        function timeSegments = annotateTimestampSegmentsForSave_(this, timeSegments, committedTrials)
            if isempty(timeSegments)
                return
            end

            for iSeg = 1:numel(timeSegments)
                segment = timeSegments{iSeg};
                if isempty(segment) || ~isstruct(segment)
                    continue
                end

                segKind = "";
                if isfield(segment, 'kind')
                    segKind = string(segment.kind);
                end

                segTrial = NaN;
                if isfield(segment, 'trial') && ~isempty(segment.trial)
                    segTrial = double(segment.trial);
                    if numel(segTrial) > 1
                        segTrial = segTrial(1);
                    end
                end

                [trialCommitted, trialStatus] = this.timeSegmentSaveStatus_(segKind, segTrial, committedTrials);
                segment.trialCommitted = logical(trialCommitted);
                segment.trialStatus = string(trialStatus);

                if isfield(segment, 'parsed') && istable(segment.parsed)
                    parsed = segment.parsed;
                    parsed.trialCommitted = repmat(logical(trialCommitted), height(parsed), 1);
                    parsed.trialStatus = repmat(string(trialStatus), height(parsed), 1);
                    segment.parsed = parsed;
                end

                timeSegments{iSeg} = segment;
            end
        end

        function [trialCommitted, trialStatus] = timeSegmentSaveStatus_(~, segKind, segTrial, committedTrials)
            if strcmpi(char(segKind), 'trial')
                if ~isnan(segTrial) && segTrial > 0 && segTrial <= committedTrials
                    trialCommitted = true;
                    trialStatus = "committed";
                else
                    trialCommitted = false;
                    trialStatus = "in_progress";
                end
            else
                trialCommitted = false;
                trialStatus = "session";
            end
        end

        function logTimeEvent_(this, eventName, fields)
            arguments
                this
                eventName string
                fields struct = struct()
            end
            if isempty(this.Time) || ~isobject(this.Time)
                return
            end
            if ~isfield(fields, 't_us') || isempty(fields.t_us)
                fields.t_us = this.currentTimeMicros_();
            end
            this.Time.LogEvent(eventName, fields);
        end

        function logTrialStartEvent_(this)
            fields = struct( ...
                'trial', this.i, ...
                'side', this.trialSideName_(), ...
                'level', this.Level, ...
                'scanImageFile', this.TimeScanImageFileIndex);
            this.logTimeEvent_("trial_start", fields);
        end

        function logChoiceEvent_(this)
            fields = struct( ...
                'trial', this.i, ...
                'side', this.trialSideName_(), ...
                'level', this.Level, ...
                'decision', this.WhatDecision, ...
                'trialStartTime', this.TrialStartTime, ...
                'responseTime', this.ResponseTime, ...
                'correct', this.choiceWasCorrect_());
            this.logTimeEvent_(this.choiceEventName_(), fields);
        end

        function logRewardEvent_(this, rewardPulse)
            fields = struct( ...
                'trial', this.i, ...
                'side', this.trialSideName_(), ...
                'rewardPulse', rewardPulse, ...
                'correct', this.choiceWasCorrect_(), ...
                'responseTime', this.ResponseTime);
            this.logTimeEvent_("reward_" + rewardPulse, fields);
        end

        function logRewardFlashEvent_(this, rewardPulse)
            fields = struct( ...
                'trial', this.i, ...
                'side', this.trialSideName_(), ...
                'rewardPulse', rewardPulse, ...
                'correct', this.choiceWasCorrect_(), ...
                'responseTime', this.ResponseTime);
            this.logTimeEvent_("reward_flash_" + rewardPulse, fields);
        end

        function t_us = currentTimeMicros_(this)
            t_us = NaN;
            if ~isempty(this.TrainStartTime)
                try
                    t_us = round(toc(this.TrainStartTime) * 1e6);
                    return
                catch
                end
            end
            if isempty(this.TimeSegmentTic)
                return
            end
            try
                t_us = round(toc(this.TimeSegmentTic) * 1e6);
            catch
            end
        end

        function beginWheelDisplayTrial_(this)
            if isempty(this.Time) || ~isobject(this.Time)
                return
            end
            this.ensureWheelDisplayTables_();
            this.CurrentTrialFrameAlignedRecord = this.emptyFrameAlignedRecord_();
            this.hold_still_start = tic;
            this.CurrentWheelPhase = "hold_still";
            this.CurrentRawWheel = 0;
            this.CurrentDelta = 0;
            this.CurrentStimColor = this.colorScalar_(this.StimulusStruct.LineColor);
            this.recordWheelDisplayState_("Force", true);
        end

        function beginHoldStillInterval_(this)
            this.logTimeEvent_("hold_still_start", struct( ...
                'trial', this.i, ...
                'side', this.trialSideName_(), ...
                'level', this.Level));
            this.beginWheelDisplayTrial_();
        end

        function setWheelDisplayPhase_(this, phaseName)
            if isempty(this.Time) || ~isobject(this.Time)
                return
            end
            this.CurrentWheelPhase = string(phaseName);
            if isnan(this.CurrentStimColor)
                this.CurrentStimColor = this.colorScalar_(this.StimulusStruct.LineColor);
            end
            this.recordWheelDisplayState_("Force", true);
        end

        function recordWheelDisplayState_(this, options)
            arguments
                this
                options.ScreenEvent string = ""
                options.Force logical = false
            end
            if isempty(this.Time) || ~isobject(this.Time)
                return
            end
            this.ensureWheelDisplayTables_();

            row = table( ...
                double(this.i), ...
                this.currentTimeMicros_(), ...
                string(this.CurrentWheelPhase), ...
                this.currentHoldStillSeconds_(), ...
                double(this.CurrentRawWheel), ...
                double(this.CurrentDelta), ...
                double(this.CurrentStimColor), ...
                string(options.ScreenEvent), ...
                this.numericOrNaN_(this.Level), ...
                logical(this.isLeftTrial), ...
                'VariableNames', {'trial','t_us','phase','tTrial','rawWheel','delta','StimColor','screenEvent','level','isLeftTrial'});

            if ~options.Force && height(this.WheelDisplayRecord) > 0
                prev = this.WheelDisplayRecord(end,:);
                changed = ~strcmp(prev.phase, row.phase) || ...
                    ~isequaln(prev.rawWheel, row.rawWheel) || ...
                    ~isequaln(prev.delta, row.delta) || ...
                    ~isequaln(prev.StimColor, row.StimColor) || ...
                    ~isequaln(prev.level, row.level) || ...
                    ~isequaln(prev.isLeftTrial, row.isLeftTrial) || ...
                    ~strcmp(prev.screenEvent, row.screenEvent);
                if ~changed
                    return
                end
            end

            this.WheelDisplayRecord = [this.WheelDisplayRecord; row];
        end

        function recordScreenEventPoint_(this, eventName, options)
            arguments
                this
                eventName string
                options.ResetToZero logical = false
            end
            if isempty(this.Time) || ~isobject(this.Time)
                return
            end
            this.recordWheelDisplayState_("ScreenEvent", string(eventName), "Force", true);
            if options.ResetToZero
                this.CurrentRawWheel = 0;
                this.CurrentDelta = 0;
            end
            this.recordWheelDisplayState_("Force", true);
        end

        function buildCurrentTrialFrameAlignedRecord_(this)
            this.ensureWheelDisplayTables_();
            this.CurrentTrialFrameAlignedRecord = this.emptyFrameAlignedRecord_();
            if isempty(this.Time) || ~isobject(this.Time)
                return
            end
            if isempty(this.timestamps_record)
                return
            end

            segment = this.timestamps_record{end};
            if isempty(segment) || ~isstruct(segment) || ~isfield(segment, 'parsed')
                return
            end
            if ~isfield(segment, 'trial') || double(segment.trial) ~= double(this.i)
                return
            end

            parsed = segment.parsed;
            if isempty(parsed) || height(parsed) == 0
                return
            end
            frameRows = parsed(parsed.kind == "frame", :);
            if isempty(frameRows) || height(frameRows) == 0
                return
            end

            trialRows = this.WheelDisplayRecord(this.WheelDisplayRecord.trial == double(this.i), :);
            if isempty(trialRows) || height(trialRows) == 0
                return
            end

            holdIdx = find(parsed.event == "hold_still_start", 1, 'first');
            holdStillUs = NaN;
            if ~isempty(holdIdx)
                holdStillUs = double(parsed.t_us(holdIdx));
            end

            displayUs = NaN(height(trialRows), 1);
            if ismember('t_us', trialRows.Properties.VariableNames)
                displayUs = double(trialRows.t_us);
            end
            if all(isnan(displayUs)) && ~isnan(holdStillUs)
                displayUs = holdStillUs + (1e6 .* double(trialRows.tTrial));
            end
            displayEventMask = trialRows.screenEvent ~= "" & ~isnan(displayUs);
            displayEventTimes = double(displayUs(displayEventMask));
            displayEventNames = string(trialRows.screenEvent(displayEventMask));

            parsedEventMask = parsed.kind ~= "frame" & parsed.event ~= "" & ~isnan(parsed.t_us);
            parsedEventTimes = double(parsed.t_us(parsedEventMask));
            parsedEventNames = this.frameAlignedEventLabel_(string(parsed.event(parsedEventMask)));

            rows = this.emptyFrameAlignedRecord_();
            finalDecision = string(this.WhatDecision);
            finalCorrect = double(this.choiceWasCorrect_());
            prevFrameUs = -Inf;
            frameArduinoUs = NaN(height(frameRows), 1);
            if ismember('t_arduino_us', frameRows.Properties.VariableNames)
                frameArduinoUs = double(frameRows.t_arduino_us);
            end
            framePcReceiveUs = NaN(height(frameRows), 1);
            if ismember('t_pc_receive_us', frameRows.Properties.VariableNames)
                framePcReceiveUs = double(frameRows.t_pc_receive_us);
            end
            frameCount = height(frameRows);
            for iFrame = 1:frameCount
                frameUs = double(frameRows.t_us(iFrame));
                sourceIdx = find(displayUs <= frameUs, 1, 'last');
                if isempty(sourceIdx)
                    sourceIdx = 1;
                end
                sourceRow = trialRows(sourceIdx, :);
                frameScreenEvent = "";
                eventUpperUs = frameUs;
                if iFrame == frameCount
                    eventUpperUs = Inf;
                end
                displayEventIdx = find( ...
                    displayEventTimes <= eventUpperUs & ...
                    displayEventTimes > prevFrameUs);
                parsedEventIdx = find( ...
                    parsedEventTimes <= eventUpperUs & ...
                    parsedEventTimes > prevFrameUs);
                if ~isempty(displayEventIdx) || ~isempty(parsedEventIdx)
                    mergedEventTimes = [displayEventTimes(displayEventIdx); parsedEventTimes(parsedEventIdx)];
                    mergedEventNames = [displayEventNames(displayEventIdx); parsedEventNames(parsedEventIdx)];
                    mergedEventOrder = (1:numel(mergedEventTimes))';
                    [~, sortIdx] = sortrows([mergedEventTimes(:), mergedEventOrder], [1 2]);
                    mergedEventNames = this.dedupeFrameAlignedEventNames_(mergedEventNames(sortIdx));
                    frameScreenEvent = strjoin(mergedEventNames, " | ");
                end

                frameTTrial = sourceRow.tTrial;
                if ~isnan(holdStillUs)
                    frameTTrial = (frameUs - holdStillUs) / 1e6;
                end

                row = table( ...
                    double(this.i), ...
                    double(frameRows.frame(iFrame)), ...
                    frameUs, ...
                    double(frameArduinoUs(iFrame)), ...
                    double(framePcReceiveUs(iFrame)), ...
                    string(sourceRow.phase), ...
                    double(frameTTrial), ...
                    double(sourceRow.rawWheel), ...
                    double(sourceRow.delta), ...
                    double(sourceRow.StimColor), ...
                    frameScreenEvent, ...
                    double(sourceRow.level), ...
                    logical(sourceRow.isLeftTrial), ...
                    "", ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    0, ...
                    NaN, ...
                    false, ...
                    'VariableNames', {'trial','frame','t_us','t_arduino_us','t_pc_receive_us','phase','tTrial','rawWheel','delta','StimColor','screenEvent','level','isLeftTrial','decision','correct','eye_x','eye_y','eye_diameter_px','eye_confidence','eye_valid_points','eye_latency_ms','eye_sample_count','eye_dt_us','eye_isValid'});
                rows = [rows; row];
                prevFrameUs = frameUs;
            end

            if isempty(rows) || height(rows) == 0
                return
            end
            rows.decision(:) = finalDecision;
            rows.correct(:) = finalCorrect;
            this.CurrentTrialFrameAlignedRecord = rows;
            this.FrameAlignedRecord = [this.FrameAlignedRecord; rows];
        end

        function appendSessionFrameAlignedSegment_(this, segment)
            this.ensureWheelDisplayTables_();
            if isempty(this.Time) || ~isobject(this.Time)
                return
            end
            if isempty(segment) || ~isstruct(segment) || ~isfield(segment, 'parsed')
                return
            end

            segmentKind = "";
            if isfield(segment, 'kind')
                segmentKind = string(segment.kind);
            end
            if segmentKind == "trial"
                return
            end

            parsed = segment.parsed;
            if isempty(parsed) || height(parsed) == 0
                return
            end
            frameRows = parsed(parsed.kind == "frame", :);
            if isempty(frameRows) || height(frameRows) == 0
                return
            end

            parsedEventMask = parsed.kind ~= "frame" & parsed.event ~= "" & ~isnan(parsed.t_us);
            parsedEventTimes = double(parsed.t_us(parsedEventMask));
            parsedEventNames = this.frameAlignedEventLabel_(string(parsed.event(parsedEventMask)));

            segmentTrial = NaN;
            if isfield(segment, 'trial') && ~isempty(segment.trial)
                segmentTrial = double(segment.trial);
            end
            if isnan(segmentTrial)
                segmentTrial = 0;
            end

            segmentStartUs = NaN;
            if ~isempty(parsedEventTimes)
                segmentStartUs = parsedEventTimes(1);
            elseif height(frameRows) > 0
                segmentStartUs = double(frameRows.t_us(1));
            end

            rows = this.emptyFrameAlignedRecord_();
            prevFrameUs = -Inf;
            frameArduinoUs = NaN(height(frameRows), 1);
            if ismember('t_arduino_us', frameRows.Properties.VariableNames)
                frameArduinoUs = double(frameRows.t_arduino_us);
            end
            framePcReceiveUs = NaN(height(frameRows), 1);
            if ismember('t_pc_receive_us', frameRows.Properties.VariableNames)
                framePcReceiveUs = double(frameRows.t_pc_receive_us);
            end
            frameCount = height(frameRows);
            for iFrame = 1:frameCount
                frameUs = double(frameRows.t_us(iFrame));
                frameScreenEvent = "";
                eventUpperUs = frameUs;
                if iFrame == frameCount
                    eventUpperUs = Inf;
                end
                parsedEventIdx = find( ...
                    parsedEventTimes <= eventUpperUs & ...
                    parsedEventTimes > prevFrameUs);
                if ~isempty(parsedEventIdx)
                    mergedEventNames = this.dedupeFrameAlignedEventNames_(parsedEventNames(parsedEventIdx));
                    frameScreenEvent = strjoin(mergedEventNames, " | ");
                end

                frameTTrial = NaN;
                if ~isnan(segmentStartUs)
                    frameTTrial = (frameUs - segmentStartUs) / 1e6;
                end

                row = table( ...
                    double(segmentTrial), ...
                    double(frameRows.frame(iFrame)), ...
                    frameUs, ...
                    double(frameArduinoUs(iFrame)), ...
                    double(framePcReceiveUs(iFrame)), ...
                    segmentKind, ...
                    double(frameTTrial), ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    frameScreenEvent, ...
                    NaN, ...
                    false, ...
                    "", ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    NaN, ...
                    0, ...
                    NaN, ...
                    false, ...
                    'VariableNames', {'trial','frame','t_us','t_arduino_us','t_pc_receive_us','phase','tTrial','rawWheel','delta','StimColor','screenEvent','level','isLeftTrial','decision','correct','eye_x','eye_y','eye_diameter_px','eye_confidence','eye_valid_points','eye_latency_ms','eye_sample_count','eye_dt_us','eye_isValid'});
                rows = [rows; row];
                prevFrameUs = frameUs;
            end

            if isempty(rows) || height(rows) == 0
                return
            end
            this.FrameAlignedRecord = [this.FrameAlignedRecord; rows];
        end

        function ensureWheelDisplayTables_(this)
            if isempty(this.WheelDisplayRecord) || ~istable(this.WheelDisplayRecord)
                this.WheelDisplayRecord = this.emptyWheelDisplayRecord_();
            end
            if isempty(this.FrameAlignedRecord) || ~istable(this.FrameAlignedRecord)
                this.FrameAlignedRecord = this.emptyFrameAlignedRecord_();
            end
            if isempty(this.CurrentTrialFrameAlignedRecord) || ~istable(this.CurrentTrialFrameAlignedRecord)
                this.CurrentTrialFrameAlignedRecord = this.emptyFrameAlignedRecord_();
            end
        end

        function tTrial = currentHoldStillSeconds_(this)
            tTrial = NaN;
            if isempty(this.hold_still_start)
                return
            end
            try
                tTrial = toc(this.hold_still_start);
            catch
            end
        end

        function value = colorScalar_(this, colorValue)
            value = NaN;
            try
                colorValue = double(colorValue);
                if isempty(colorValue)
                    return
                end
                value = colorValue(1);
            catch
            end
        end

        function value = numericOrNaN_(this, numericValue)
            value = NaN;
            try
                if isempty(numericValue)
                    return
                end
                value = double(numericValue);
                if numel(value) > 1
                    value = value(1);
                end
            catch
            end
        end

        function tbl = emptyWheelDisplayRecord_(this)
            tbl = table( ...
                'Size', [0 10], ...
                'VariableTypes', {'double','double','string','double','double','double','double','string','double','logical'}, ...
                'VariableNames', {'trial','t_us','phase','tTrial','rawWheel','delta','StimColor','screenEvent','level','isLeftTrial'});
        end

        function tbl = emptyFrameAlignedRecord_(this)
            tbl = table( ...
                'Size', [0 24], ...
                'VariableTypes', {'double','double','double','double','double','string','double','double','double','double','string','double','logical','string','double','double','double','double','double','double','double','double','double','logical'}, ...
                'VariableNames', {'trial','frame','t_us','t_arduino_us','t_pc_receive_us','phase','tTrial','rawWheel','delta','StimColor','screenEvent','level','isLeftTrial','decision','correct','eye_x','eye_y','eye_diameter_px','eye_confidence','eye_valid_points','eye_latency_ms','eye_sample_count','eye_dt_us','eye_isValid'});
        end

        function eventNames = frameAlignedEventLabel_(this, eventNames)
            eventNames = string(eventNames);
            eventNames(eventNames == "screen_on" | eventNames == "acq_start") = "Screen On";
            eventNames(eventNames == "stim_on" | eventNames == "stimulus_on") = "Stimulus On";
            eventNames(eventNames == "stim_off" | eventNames == "stimulus_off") = "Stimulus off";
            eventNames(eventNames == "distractors_dimmed") = "Distractors Dimmed";
            rewardFlashMask = startsWith(eventNames, "reward_flash_");
            if any(rewardFlashMask)
                rewardFlashPulse = extractAfter(eventNames(rewardFlashMask), "reward_flash_");
                eventNames(rewardFlashMask) = "Reward Flash " + rewardFlashPulse;
            end
        end

        function eventNames = dedupeFrameAlignedEventNames_(this, eventNames)
            eventNames = string(eventNames);
            if isempty(eventNames)
                return
            end
            keepMask = false(size(eventNames));
            seen = strings(0, 1);
            for idx = 1:numel(eventNames)
                key = lower(strtrim(eventNames(idx)));
                if any(seen == key)
                    continue
                end
                seen(end+1,1) = key; %#ok<AGROW>
                keepMask(idx) = true;
            end
            eventNames = eventNames(keepMask);
        end

        function side = trialSideName_(this)
            if this.isLeftTrial
                side = "left";
            else
                side = "right";
            end
        end

        function correct = choiceWasCorrect_(this)
            decision = lower(string(this.WhatDecision));
            if contains(decision, 'correct')
                correct = 1;
            elseif contains(decision, 'wrong') || contains(decision, 'time out')
                correct = 0;
            else
                correct = NaN;
            end
        end

        function eventName = choiceEventName_(this)
            decision = lower(string(this.WhatDecision));
            if contains(decision, 'time out')
                eventName = "choice_timeout";
                return
            end

            if contains(decision, 'left')
                side = "left";
            elseif contains(decision, 'right')
                side = "right";
            else
                side = "unknown";
            end

            if contains(decision, 'correct') && contains(decision, 'oc')
                outcome = "correct_oc";
            elseif contains(decision, 'correct')
                outcome = "correct";
            elseif contains(decision, 'wrong')
                outcome = "wrong";
            else
                outcome = "unknown";
            end

            eventName = "choice_" + side + "_" + outcome;
        end
    end
    %STATIC FUNCTIONS====
    methods(Static = true)
        function tf = holdStillThresholdExceeded(rawWheel, threshold)
            if nargin < 2 || isempty(threshold) || isnan(threshold)
                threshold = 0;
            end
            if nargin < 1 || isempty(rawWheel) || isnan(rawWheel)
                tf = false;
                return
            end
            tf = abs(double(rawWheel)) > max(double(threshold), 0);
        end
        %toggle GUI buttons active/inactive
        function toggleButtonsOnOff(Buttons, on)
            ON = logical(on);
            for b = struct2cell(Buttons)'
                if b{:}.Type == "uistatebutton"
                    continue
                else
                    b{:}.Enable = ON;
                end
            end
            Buttons.Auto_Go.Value = false;
            Buttons.Auto_Go.Enable = ON;
            Buttons.Auto_Stop.Value = false;
            Buttons.Auto_Stop.Enable = false;
            Buttons.Animate_Go.Value = false;
            Buttons.Animate_Go.Enable = ON;
            Buttons.Animate_End.Value = false;
            Buttons.Animate_End.Enable = false;
            Buttons.Animate_Show.Value = false;
            Buttons.Animate_Show.Enable = ON;
        end
        %set GUI settings and numbers from save or when starting new
        function setGuiNumbers(GUI_numbers)
            %trial no, choices, diff
            names = fieldnames(GUI_numbers);
            names(contains(names, 'handle', IgnoreCase=true)) = [];
            for n = names'
                GUI_numbers.handle.(n{:}).Text = num2str(GUI_numbers.(n{:}));
            end
        end
        function [WhatDecision, response_time] = readKeyboardInput(stop_handle, message_handle, isLeftTrial, initial_elapsed_s)
            if nargin < 4 || isempty(initial_elapsed_s)
                initial_elapsed_s = 0;
            end
            text = 'Respond: Press L for Left, R for Right, C or M for Middle:'; set(message_handle,'Text',text); fprintf([text '\n']); drawnow
            prompt = 'L, R, or M/C:   ';
            keypress = 0; t1 = datetime("now");
            while keypress==0
                pause(0.01); drawnow;
                currkey = input(prompt,"s");
                response_time = initial_elapsed_s + seconds(datetime("now") - t1);
                switch true
                    case strcmp(currkey, 'l') || strcmp(currkey, 'L')
                        text = 'Left choice...'; fprintf([text '\n']); set(message_handle,'Text',text); drawnow
                        event = 1;
                        keypress = 1;
                    case strcmp(currkey, 'r') || strcmp(currkey, 'R')
                        text = 'Right choice...'; fprintf([text '\n']); set(message_handle,'Text',text); drawnow
                        event = 2;
                        keypress = 1;
                    case strcmp(currkey, 'C') || strcmp(currkey, 'c') || strcmp(currkey, 'M') || strcmp(currkey, 'm')
                        text = 'Middle choice'; fprintf([text '\n']); set(message_handle,'Text',text); drawnow
                    otherwise
                        text = 'Please only press one of the indicated keys...'; fprintf([text '\n']); set(message_handle,'Text',text); drawnow
                end
                pause(0.01); drawnow;
                if stop_handle.Value
                    set(message_handle, 'Text','Ending session...'); drawnow
                    event = -1;
                    drawnow
                    break;
                end
            end
            switch event
                case -1
                    WhatDecision = 'time out';
                    response_time = 0;
                case 1
                    %-1 is for trainingstrials always correct
                    if isLeftTrial==1
                        WhatDecision = 'left correct';
                    else
                        WhatDecision = 'left wrong';
                    end
                case 2
                    if isLeftTrial==0
                        WhatDecision = 'right correct';
                    else
                        WhatDecision = 'right wrong';
                    end
            end
        end
        %read the lever (digital read)
        function [Set, T] = structureSettings(Settings)
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
                    case 5
                        SetStr = strcat(SetStr, 'aRn');
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
            if isfield(Settings, 'TrainingChoices') & Settings.TrainingChoices ~=3 %BBPractice, would show two correct stimuli. I was using this to get rid of side biases, by showing the mice that both sides reward water always.
                switch Settings.TrainingChoices
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
                if Settings.TrainingChoices ~=3
                    Include = 0;
                end
            end
            if isfield(Settings, 'Repeat_wrong') & Settings.Repeat_wrong
                SetStr = strcat(SetStr, 'rw');
                Include = 0;
            end
            %Airpuff?
            if isfield(Settings, 'Box_Air_Puff_Penalty') & Settings.Box_Air_Puff_Penalty
                SetStr = strcat(SetStr, 'A');
            end
            Set = SetStr;
            T = Include;
        end
        function Flash(Stim, Box, Lines, whatdecision)
            arguments
                Stim % from Setting structure
                Box
                Lines = findobj('Tag', 'Contour')
                whatdecision = "time out"
            end
            drawnow
            if ~Stim.FlashStim
                return
            end
            if isempty(Lines)
                return
            end
            Lines = Lines(isgraphics(Lines));
            if isempty(Lines)
                return
            end
            switch 1
                case contains(whatdecision, 'wrong')
                    Reps = Stim.RepFlashAfterW;
                case contains(whatdecision, 'correct')
                    Reps = Stim.RepFlashAfterC;
            end
            if contains(whatdecision, {'wrong', 'correct'}) && Reps == 0
                return
            end
            start_color = Stim.LineColor;
            flash_color = Stim.FlashColor;
            dark_color = Stim.DimColor;
            %[Stim.fig.findobj('Type','Line').Visible] = deal(0); drawnow
            if whatdecision == "time out"
                Reps = Stim.RepFlashInitial;
                Freq = Stim.FreqFlashInitial;
                SimpleFlash(Stim.LineColor)
            elseif whatdecision == "Mal" | whatdecision == "Wheel" %Wheel hold still interval
                Reps = 1;
                Freq = 3;
                RQFlash()
            elseif whatdecision == "NewStim" %L or R poke during intertrial
                Reps = Stim.RepFlashInitial;
                Freq = Stim.FreqFlashInitial;
                RQFlash()
            elseif whatdecision == "center" %Center poke during trial
                Reps = 1;
                Freq = Stim.FreqFlashInitial;
                RQFlash()
            else
                Freq = Stim.FreqAnimation;
                d = findobj('Tag', 'Distractor');
                if isempty(d)
                    d = struct();
                end
                switch 1
                    case contains(whatdecision, 'wrong')
                        Reps = Stim.RepFlashAfterW;
                        if Reps > 0
                            WrongFlash()
                        end
                    case contains(whatdecision, 'correct')
                        Reps = Stim.RepFlashAfterC;
                        if Reps > 0
                            CorrectFlash()
                        end
                end
            end
            function RQFlash()
                if Lines(1).Type == "scatter" %Nose
                    r = 1 ;
                    for StimRep = 1:Reps
                        [Lines.MarkerFaceColor] = deal(flash_color); drawnow
                        pause(1/Freq/6)
                        [Lines.MarkerFaceColor] = deal(start_color); drawnow
                        if StimRep < r
                            pause(1/Freq/2)
                        end
                    end
                elseif any(strcmpi(string(Lines(1).Type), ["polygon","patch"])) %Wheel finish line
                    for StimRep = 1:Reps
                        [Lines.FaceColor] = deal(flash_color); drawnow
                        pause(1/Freq/6)
                        [Lines.FaceColor] = deal(start_color); drawnow
                    end
                else %line
                    for StimRep = 1:Reps
                        [Lines(:).Color] = deal(Stim.BackgroundColor); [Lines(:).Visible] = deal(1); drawnow
                        pause(1/Freq/5)
                        [Lines(:).Color] = deal(dark_color); drawnow
                        pause(1/Freq/10)
                        [Lines(:).Color] = deal(start_color); drawnow
                        pause(1/Freq/10)
                        [Lines(:).Color] = deal(flash_color); drawnow
                        pause(1/Freq/5)
                        [Lines(:).Color] = deal(start_color); drawnow
                        if StimRep < Reps
                            pause(1/Freq/10)
                        end
                    end
                end
            end
            function CorrectFlash
                [Lines(:).Color] = deal(Stim.BackgroundColor);
                pause(1/Freq/5)
                for StimRep = 1:Reps
                    [Lines(:).Color] = deal(dark_color); drawnow
                    pause(1/Freq/10)
                    [Lines(:).Color] = deal(start_color);
                    try
                        [d.Color] = deal(Stim.DimColor); drawnow
                    catch
                    end
                    pause(1/Freq/10)
                    [Lines(:).Color] = deal(flash_color);
                    try
                        [d.Color] = deal(Stim.DimColor);
                    catch
                    end
                    drawnow
                    pause(1/Freq/5)
                    [Lines(:).Color] = deal(start_color); drawnow
                    if StimRep < Reps
                        pause(1/Freq/10)
                    end
                end
            end
            function SimpleFlash(~)
                [Lines.Color] = deal(Stim.LineColor);
                [d.Color] = deal(Stim.BackgroundColor); drawnow
                pause(1/Freq/8)
                Reps = 1;
                for StimRep = 1:Reps
                    [Lines.Color] = deal(Stim.BackgroundColor);
                    [d.Color] = deal(Stim.BackgroundColor); drawnow
                    pause(1/Freq/8)
                    [Lines.Color] = deal(Stim.DimColor);
                    [d.Color] = deal(Stim.DimColor); drawnow
                    pause(1/Freq/8)
                    [Lines(:).Color] = deal(Stim.BrightColor);
                    [d.Color] = deal(Stim.LineColor); drawnow
                    pause(1/Freq/2)
                    [Lines.Color] = deal(Stim.LineColor);
                    [d.Color] = deal(Stim.DimColor); drawnow
                    pause(1/Freq/2)
                end
            end
            function WrongFlash
                [Lines.Color] = deal(flash_color);
                %[d.Color] = deal(Stim.BackgroundColor); drawnow
                pause(1/Freq/2)
                [Lines.Color] = deal(start_color);
                [d.Color] = deal(dark_color); drawnow
                pause(1/Freq/2)
                for StimRep = 1:Reps
                    [Lines.Color] = deal(Stim.BackgroundColor); drawnow
                    pause(1/Freq/2)
                    [Lines.Color] = deal(start_color); drawnow
                    % pause(1/Freq/10)
                    % [Lines.Color] = deal(flash_color); drawnow
                    pause(1/Freq/2)
                end
                [Lines.Color] = deal(Stim.LineColor);
            end
        end
        function saveFigure(fig, folder, name)
            name = erase(name, '.mat');
            figure_property = struct;

            % Reset export Settings:
            figure_property.units = 'inches';
            figure_property.format = 'pdf';
            figure_property.Width= 11; % Figure width on canvas
            figure_property.Height= 8.5; % Figure height on canvas

            % Figure properties setup
            chosen_figure = fig;
            set(chosen_figure, 'PaperUnits', figure_property.units);
            set(chosen_figure, 'PaperPositionMode', 'auto');
            set(chosen_figure, 'PaperSize', [figure_property.Width figure_property.Height]); % Canvas Size
            set(chosen_figure, 'Units', figure_property.units);

            % Apply rendering and resolution options directly to exportgraphics
            output_file = fullfile(folder, name + ".pdf");
            exportgraphics(chosen_figure, output_file, ...
                'ContentType', 'vector', ...
                'Resolution', 600, ...
                'BackgroundColor', 'w');
        end
        function unwrapError(err)
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
    end
end
