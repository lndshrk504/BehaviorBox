classdef BehaviorBoxNose < handle
    %BehaviorBox Super class
    % WBS 2 . 21 . 2025
    %====================================================================
    %Super Class for BehaviorBox Ver 1.4
    %This Class is called by the GUI BehaviorBox via RunTraining()and runs the Training
    %loop, reads levers, gives rewards, plots data, etc. It stores data in the BehaviorBoxData.
    %Air Puff penalty code is being added
    %It interacts with class BehaviorBoxVisualStimulusTraining.m to create the
    %visual stimuli.
    %This is a superclass to BehaviorBoxSub1/2.
    %THIS FILE IS PART OF A SET OF FILES CONTAINING (ALL NEEDED):
    %BehaviorBox_App.mlapp
    %BehaviorBoxData.m
    %BehaviorBoxSuper.m
    %BehaviorBoxWheel.m
    %BehaviorBoxNose.m
    %BehaviorBoxVisualGratingObject.m
    %BehaviorBoxVisualStimulus.m
    %BehaviorBoxVisualStimulusTraining.m
    %====================================================================
    properties (SetAccess = public)
        fig; %The figure window that shows the stimulus
        figpos;
        ReadyCueAx;
        LStimAx; %Axis that contains the left stimulus plot
        RStimAx; %Axis that contains the left stimulus plot
        FLAx; %Axis that contains the 2 finish line triangles
        graphFig;
        timerFig;
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
        Temp_iStart = 0;
        Temp_Active = 0;
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
        a; %The arduino
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
        wheelchoice = []; %Use the one in BBData
        wheelchoicetime = [];
        wheelchoice_record = cell(400,3); %All wheel choice processes with what_decision
        %Timers during each trial:
        start_time; %Clock time at initiation of first trial
        t1; %Used to record times between different functions
        BetweenTrialTime = 0; %Manual mode: time to use keyboard to pick trial, also to watch the mouse and wait for them to calm down between trials
        TrialStartTime = 0; %Time for mouse to respond to ready cue and begin the next trial
        ResponseTime = 0; %Time for mouse to answer
        DrinkTime = 0; %Time mouse spent drinking reward
        timers = struct();
        %SoundObjs: (only created if sounds is used)
        Sound_Object = struct();
        Sound_Struct = struct(); %This is only used to make the sounds, which are not used anymore since mice are trained concurrently.
        textdiary
        textdiary_pos = 0;
    end
    methods
        function this = BehaviorBoxNose(GUI_handles, app)
            this.app = app;
            this.GuiHandles = GUI_handles;
            try
                this.stop_handle.Value = 0;
                this.getGUI();
            catch err
                this.unwrapError(err)
            end
            try
                this.Data_Object = BehaviorBoxData( ...
                    Inv=this.app.Inv.Value, ...
                    Inp=this.app.Box_Input_type.Value, ...
                    Str=this.app.Strain.Value, ...
                    Sub={this.app.Subject.Value}, ...
                    find=1); % Set up data storage object
            catch
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
                    % Uncomment these when needing to time the trial
                    % profile on
                    this.BeforeTrial();
                    this.WaitForInput();
                    this.WaitForInputAndGiveReward();
                    this.AfterTrial();
                    this.app.TabGroup.SelectedTab = this.app.TabGroup.Children(5);
                    pause(0.1);
                    errorc = 0;
                    % Uncomment these when needing to time the trial
                    % profile viewer
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
                PossibleLevels = PossibleLevels(1:idx-1);
            else
                PossibleLevels = [EasyLevs HardLevs];
                if isempty(PossibleLevels)
                    PossibleLevels = 1;
                end
            end
            OUT.PossibleLevels = PossibleLevels;
            OUT.ChooseLevel = @()OUT.PossibleLevels(randi(numel(OUT.PossibleLevels)));
        end
        %set hardware (arduino) parameters
        function ConfigureBox(this)
            arguments
                this
            end
            this.message_handle.Text = 'Connecting to Arduino. . .';
            tic
            try 
                % https://docs.arduino.cc/learn/microcontrollers/digital-pins
                switch this.Setting_Struct.Box_Input_type
                    case 3 %Three Pokes
                        % if ispc
                        %     comsnum = "COM"+this.app.Arduino_Com.Value;
                        % elseif ismac
                        %     comsnum = "/dev/tty.usbmodem"+this.app.Arduino_Com.Value;
                        % elseif isunix
                        %     comsnum = "/dev/tty"+this.app.Arduino_Com.Value;
                        % end
                        try
                            [~, comsnum, ~] = arduinoServer('ArduinoInfo', this.app.ArduinoInfo, 'desiredIdentity', this.app.Arduino_Com.Value, 'FindExact', true);
                        catch err
                            [~, comsnum, ID] = arduinoServer('desiredIdentity', 'Nose', 'FindFirst', true);
                            this.app.Arduino_Com.Value = ID;
                            this.app.LoadComputerSpecifics();
                        end
                        this.a = BehaviorBoxSerialInput(comsnum, 115200, 'NosePoke');
                        pause(2)
                        this.a.SetupReward("Which", "Both", "DurationLeft", this.Box.Lrewardtime, "DurationRight", this.Box.Rrewardtime);
                        this.Box.ardunioReadDigital = 1;
                        this.Box.KeyboardInput = false;
                    case 8 %Keyboard, used if no arduino connected
                        this.Box.ardunioReadDigital = 0;
                        this.Box.KeyboardInput = 1;
                        this.a = [];
                end
                toc
            catch
                this.Box.ardunioReadDigital = 0;
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
            this.setGuiNumbers(this.GUI_numbers); %update gui
            this.Data_Object = this.createSessionDataObject_();
            DATE = sprintf("BBTrialLog_%s.txt", datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            diaryname = fullfile(this.Data_Object.filedir, DATE);
            this.textdiary = diaryname;
            this.textdiary_pos = 0;
            diary(diaryname)
            this.Data_Object.TrainingNow = 1;
            %create stimulus depending on input device
            [this.Stimulus_Object] = BehaviorBoxVisualStimulus(this.StimulusStruct); drawnow;
            this.Data_Object.StimType = erase(this.app.Stimulus_type.Value, ' ');
            this.graphFig = this.app.PerformanceTab.Children.Children;
            this.timerFig = this.app.TimersTab.Children.Children;
            clo(this.graphFig);
            clo(this.timerFig);
            Ax_G = this.Data_Object.CreateDailyGraphs(this.graphFig);
            Ax_T = this.Data_Object.CreateAllTimeGraphs(this.timerFig);
            this.Data_Object.Axes = appendStruct(Ax_T, Ax_G);
            this.Data_Object.SB = this.Setting_Struct.Data_Sbin; %Make these names match
            this.Data_Object.BB = this.Setting_Struct.Data_Lbin*this.Setting_Struct.Data_Sbin;
            this.Data_Object.current_data_struct = this.Data_Object.new_init_data_struct();
            this.setSessionStartTime_();
            [this.Level] = this.Setting_Struct.Starting_opacity;
            rng('shuffle');
            [this.fig, this.LStimAx, this.RStimAx, this.FLAx, ~] = this.Stimulus_Object.setUpFigure();
            this.ReadyCue(1)
            this.ReadyCueStruct.Ax = this.ReadyCueAx;
            this.StimulusStruct.ReadyCue = this.ReadyCueStruct;
            this.toggleButtonsOnOff(this.Buttons,0); % Turn off all buttons
            fprintf("- - - - -\n");
            txt = "Start trial Mouse "+this.Setting_Struct.Subject+" at "+string(datetime('now'));
            set(this.message_handle,'Text',txt);
            fprintf(txt+"\n");
            this.resetSessionState_();
        end
        %Do some things before each trial
        function BeforeTrial(this)
            switch this.Setting_Struct.Box_Input_type
                case 3 %Nose
                    this.fig.Color = this.StimulusStruct.BackgroundColor;
                case 6 %Wheel
                    this.fig.Color = this.ReadyCueStruct.Color;
                otherwise
            end
            set(this.FF, 'Value', 0) %Turn off FF button
            this.UpdateSettings()
            this.CheckTemp();
            %Update GUI window numbers
            this.updateGUIbeforeIteration();
            this.WhatDecision = 'time out';
            try
                LastScore = this.Data_Object.current_data_struct.CodedChoice(end);
            catch
                LastScore = 1;
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
            %Update GUI window numbers
            this.updateGUIbeforeIteration(); %Update again, in case the level changed
            stim_objs = [ ...
                findobj(this.fig, 'Tag', 'Contour'); ...
                findobj(this.fig, 'Tag', 'Distractor'); ...
                findobj(this.fig, 'Tag', 'Spotlight'); ...
                findobj(this.fig, 'Tag', 'Dot') ...
                ];
            stim_objs = stim_objs(isgraphics(stim_objs));
            if ~isempty(stim_objs)
                set(stim_objs, 'Visible', 0);
            end
            drawnow
            this.ReadyCue(1)
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
        function [current_difficulty] = PickDifficultyLevel(this)
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
            this.TrialStartTime = 0;
            set(this.message_handle, 'Text', 'Waiting for Trial initialization');
            startTime = datetime("now");
            if ~this.Setting_Struct.SkipWaitForInput
                if this.Box.ardunioReadDigital == 1
                    this.WaitForInputArduino();
                else
                    this.WaitForInputKeyboard();
                end
            else
                while this.a.ReadLeft() || this.a.ReadRight()
                    pause(0.5)
                end
            end

            if ~get(this.stop_handle, 'Value')
                this.TrialStartTime = seconds(datetime("now") - startTime);
            end

            if this.i == 1
                try
                    hasStartTime = ~isempty(this.start_time) && ~isempty(this.Data_Object.start_time);
                catch
                    hasStartTime = false;
                end
                if ~hasStartTime
                    this.setSessionStartTime_();
                end
            end
        end
        function WaitForInputArduino(this)
            this.ReadyCueAx.Children.MarkerFaceColor = this.StimulusStruct.LineColor;
            while (this.a.ReadLeft() || this.a.ReadRight())
                pause(0.1)
            end
            while ~get(this.stop_handle, 'Value')
                pause(0.01);
                if this.Setting_Struct.IntertrialMalCancel && (this.a.ReadLeft() || this.a.ReadRight())
                    this.HandleIntertrialMalingering();
                end

                if this.Middle_StableChoice_StartTrial(true)
                    break;
                end
            end
        end
        function stable = Middle_StableChoice_StartTrial(this, checkDelay)
            % Check if the sensor value remains stable for 1 second
            if checkDelay
                delayTime = this.getDelaySetting_('Input_Delay_Start', 'Input_Delay_Respond');
            else
                delayTime = 0;
            end
            STABLE = true;
            % Ensure the value remains 1 for the specified duration
            t_hold = tic;
            while toc(t_hold) < delayTime
                pause(0.01); % check in small intervals
                if ~this.a.ReadNone()
                    STABLE = false;
                    break;
                elseif this.a.ReadLeft()
                    STABLE = false;
                    break;
                elseif this.a.ReadRight()
                    STABLE = false;
                    break;
                elseif this.a.ReadMiddle()
                    this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'ReadyCueDot'), "WaitForInput")
                end
            end
            stable = STABLE && this.a.ReadMiddle();
        end
        function WaitForInputKeyboard(this)
            InterTMalInterv = this.Setting_Struct.IntertrialMalSec;
            prompt = 'Initialize: Press L for Left, R for Right, C or M for Middle: ';
            set(this.message_handle, 'Text', prompt);
            fprintf([prompt '\n']);

            while true
                currkey = input('L, R, or M/C: ', 's');

                switch lower(currkey)
                    case {'l', 'r'}
                        this.HandleKeyboardMalingering(InterTMalInterv);
                    case {'c', 'm', ''}
                        return;
                    otherwise
                        disp('Please only press one of the indicated keys...');
                end

                if get(this.stop_handle, 'Value')
                    this.message_handle.Text = 'Ending session...';
                    break;
                end
            end
        end
        function HandleIntertrialMalingering(this)
            %this.ReadyCueAx.Children.MarkerFaceColor = this.StimulusStruct.BackgroundColor;
            %drawnow;
            timerStart = datetime("now");
            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'ReadyCueDot'), "Make_Background", true);

            while true
                time = this.Setting_Struct.IntertrialMalSec - seconds(datetime("now") - timerStart);
                txt = sprintf("Do not poke L or R! Intertrial Malingering timeout: %.1f sec...", time);
                set(this.message_handle, 'Text', txt);

                if this.a.ReadLeft() || this.a.ReadRight()
                    timerStart = datetime("now");
                end

                if this.CheckForInterruptions()
                    break;
                end

                if seconds(datetime("now") - timerStart) > this.Setting_Struct.IntertrialMalSec
                    this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'ReadyCueDot'), "Make_StartColor");
                    %this.ReadyCueAx.Children.MarkerFaceColor = this.StimulusStruct.LineColor;
                    set(this.message_handle, 'Text', 'Waiting for Trial initialization');
                    drawnow;
                    break;
                end

                pause(0.1);
            end
        end
        function HandleKeyboardMalingering(this, InterTMalInterv)
            this.ReadyCueAx.Children.Visible = 0;
            this.fig.Color = 'k';
            text = 'Only choose Middle to start trial, malingering timeout...';
            fprintf([text '\n']);
            set(this.message_handle, 'Text', text);
            t_start = tic;

            while true
                pause(0.1);
                drawnow;

                if this.CheckForInterruptions()
                    break;
                end

                if toc(t_start) > InterTMalInterv
                    this.ReadyCue(1);
                    set(this.message_handle, 'Text', 'Waiting for Trial initialization');
                    break;
                end
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
        %wait loop while lever is read and open valves if correct
        function WaitForInputAndGiveReward(this)
            if get(this.stop_handle, 'Value')
                return;
            end

            this.setupStimulus();
            this.processIgnoredInput();
            this.displayChoicePrompt();
            this.recordStimulusEvent();

            this.WhatDecision = this.getDecision();
            %this.handleIncorrectDecision();
            this.processDecision();
        end
        function setupStimulus(this)
            this.ResponseTime = 0;
            this.WhatDecision = 'time out';
            this.DrinkTime = 0;
            % Restore only task stimulus objects (not wheel finish line/UI overlays).
            stim_vis = [ ...
                findobj(this.fig, 'Tag', 'Contour'); ...
                findobj(this.fig, 'Tag', 'Distractor'); ...
                findobj(this.fig, 'Tag', 'Spotlight'); ...
                findobj(this.fig, 'Tag', 'Dot') ...
                ];
            stim_vis = stim_vis(isgraphics(stim_vis));
            if ~isempty(stim_vis)
                set(stim_vis, 'Visible', 1);
            end

            % Start each trial from background for line-based stimuli.
            stim_lines = [ ...
                findobj(this.fig, 'Type', 'Line', 'Tag', 'Contour'); ...
                findobj(this.fig, 'Type', 'Line', 'Tag', 'Distractor'); ...
                findobj(this.fig, 'Type', 'ConstantLine', 'Tag', 'Contour'); ...
                findobj(this.fig, 'Type', 'ConstantLine', 'Tag', 'Distractor') ...
                ];
            if ~isempty(stim_lines)
                set(stim_lines, 'Color', this.StimulusStruct.BackgroundColor, 'Visible', 1);
            end
            this.fig.Color = this.StimulusStruct.BackgroundColor;
            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'ReadyCueDot'), "Make_Background", true);
            this.ReadyCue(0);
            this.FlashNew(this.StimulusStruct, this.Box, stim_lines, "Make_StartColor");
        end
        function processIgnoredInput(this)
            if ~(this.Box.ardunioReadDigital && this.Setting_Struct.Input_ignored)
                return
            end
            t_ignore = tic;
            while toc(t_ignore) <= this.Setting_Struct.Pokes_ignored_time
                if get(this.stop_handle, 'Value')
                    break
                end
                if this.Setting_Struct.ConfirmChoice
                    this.confirmCorrectChoice();
                end
                if this.a.ReadMiddle()
                    this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'Line'), "NewStim");
                    % Restart the ignore interval when center is re-triggered.
                    t_ignore = tic;
                end
                this.updateInputIgnoredMessage(t_ignore);
                drawnow;
            end
        end
        function confirmCorrectChoice(this)
            if this.Left_StableChoice_DuringTrial(true) && this.isLeftTrial
                this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), "Flash_Contour");
            elseif this.Right_StableChoice_DuringTrial(true) && ~this.isLeftTrial
                this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), "Flash_Contour");
            end
        end
        function updateInputIgnoredMessage(this, t_ignore)
            time = max(this.Setting_Struct.Pokes_ignored_time - toc(t_ignore), 0);
            txt = sprintf("Ignoring input for %.1f sec...", round(time, 1));
            set(this.message_handle, 'Text', txt);
        end
        function displayChoicePrompt(this)
            set(this.message_handle, 'Text', sprintf('Waiting for %s choice...', this.current_side));
        end
        function recordStimulusEvent(this)
            this.Data_Object.addStimEvent(this.isLeftTrial);
        end
        function decision = getDecision(this)
            if ~isempty(this.a) && any(this.Box.Input_type == [1, 2, 3, 5])
                [decision, this.ResponseTime] = this.readLeverLoopDigital();
            else
                [decision, this.ResponseTime] = this.readKeyboardInput(this.stop_handle, this.message_handle, this.isLeftTrial);
            end
            if this.Setting_Struct.OnlyCorrect && contains(decision, 'wrong', 'IgnoreCase', true)
                set(this.message_handle, 'Text', sprintf('Reanswer... Waiting for %s choice...', this.current_side));
                [decision, this.ResponseTime] = readLeverLoopDigital_OnlyCorrect(this);
            end
        end
        % function handleIncorrectDecision(this)
        %     if this.Setting_Struct.OnlyCorrect && contains(this.WhatDecision, 'wrong', 'IgnoreCase', true)
        %         set(this.message_handle, 'Text', sprintf('Reanswer... Waiting for %s choice...', this.current_side));
        %         this.WhatDecision = this.getDecision();
        %     end
        % end
        function processDecision(this)
            switch true
                case contains(this.WhatDecision, 'OC', 'IgnoreCase', true)
                    this.handleOnlyCorrect();
                case contains(this.WhatDecision, 'correct', 'IgnoreCase', true)
                    this.handleCorrectDecision();
                case contains(this.WhatDecision, 'wrong', 'IgnoreCase', true)
                    this.handleWrongDecision();
            end
        end
        function handleCorrectDecision(this)
            set(this.message_handle, 'Text', 'Giving Reward...');
            tic;
            this.GiveRewardAndFlash();
            this.DrinkTime = toc;
            this.persistCorrectStimulus();
            this.hideStimulus();
        end
        function persistCorrectStimulus(this)
            thisInt = this.StimulusStruct.PersistCorrectInterv;
            %set(this.message_handle, 'Text', sprintf('Persisting correct stimulus for %.1f sec...', thisInt));
            tic
            while toc < thisInt
                % Too much flashing
                pause(0.5)
                set(this.message_handle, 'Text', sprintf('Persisting correct stimulus for %.1f sec...', max(thisInt-toc,0)));
                %this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), this.WhatDecision);
            end
        end
        function handleWrongDecision(this)
            set(this.message_handle, 'Text', sprintf('%s - Penalty...', this.WhatDecision));
            %this.pauseForDrinking();

            if ~get(this.stop_handle, 'Value') && this.StimulusStruct.PersistIncorrect
                this.persistIncorrectStimulus();
                this.hideStimulus();
            else
                this.hideStimulus();
                this.fig.Color = 'k';
            end
        end
        function persistIncorrectStimulus(this)
            %set(this.message_handle,'Text','Persisting correct stimulus...');
            thisInt = this.StimulusStruct.PersistIncorrectInterv;
            tic
            while toc < thisInt
                % Too much flashing
                pause(0.5)
                set(this.message_handle, 'Text', sprintf('Persisting correct stimulus for %.1f sec...', max(thisInt-toc,0)));
                %this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), this.WhatDecision);
            end
        end
        function handleOnlyCorrect(this)
            set(this.message_handle,'Text','Reanswer, Giving small Reward...');
            tic
            this.GiveRewardAndFlash();
            this.pauseForDrinking();
            this.DrinkTime = toc;
            this.persistCorrectStimulus();
            this.hideStimulus();
            % Preserve the OC label so saved data records the corrected OC response.
        end
        function pauseForDrinking(this)
            if ~this.a.KeyboardInput && this.Box.Input_type == 3
                while this.a.ReadLeft() || this.a.ReadRight() % Pause while the mouse is standing there
                    pause(0.5); drawnow;
                end
            end
        end
        function hideStimulus(this)
            o = findobj(this.fig.Children);
        %Fade all to background color, the turn visible off
            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'Line'), "Make_Background", true)
            [o(:).Visible] = deal(0);
        end
        function pauseMessage(this)
            set(this.message_handle, 'Text', 'Paused, click pause button again to continue...');
            o = findobj(this.fig.Children);
            [o(:).Visible] = deal(0);
            this.fig.Color = this.ReadyCueStruct.Color; % Clear stim and turn screen black to indicate pause
            while get(this.Pause, 'Value')
                pause(0.1); drawnow;
            end
            this.fig.Color = this.StimulusStruct.BackgroundColor;
        end
        %read the lever (digital read)
        function [WhatDecision, response_time] = readLeverLoopDigital(this)
            [WhatDecision, response_time] = this.readLeverLoopDigitalCore(false);
        end
        function stable = Left_StableChoice_DuringTrial(this, checkDelay)
            % Check if the sensor value remains stable for 1 second
            if checkDelay
                delayTime = this.getDelaySetting_('Input_Delay_Respond');
            else
                delayTime = 0;
            end
            STABLE = true;
            % Ensure the value remains 1 for the specified duration
            t_hold = tic;
            while toc(t_hold) < delayTime
                pause(0.01); % Pause is needed otherwise Arduino callback won't update
                if ~this.a.ReadNone()
                    stable = false;
                    return;
                elseif this.a.ReadRight()
                    stable = false;
                    return;
                elseif this.a.ReadMiddle()
                    stable = false;
                    return;
                elseif this.a.ReadLeft()
                    if this.isLeftTrial && this.Setting_Struct.ConfirmChoice
                        this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), "Flash_Contour")
                    end
                end
            end
            %toc
            stable = STABLE && this.a.ReadLeft;
        end
        function stable = Right_StableChoice_DuringTrial(this, checkDelay)
            % Check if the sensor value remains stable for 1 second
            if checkDelay
                delayTime = this.getDelaySetting_('Input_Delay_Respond');
            else
                delayTime = 0;
            end
            STABLE = true;
            % Ensure the value remains 1 for the specified duration
            t_hold = tic;
            while toc(t_hold) < delayTime
                pause(0.01); % Pause is needed otherwise Arduino callback won't update
                if ~this.a.ReadNone()
                    stable = false;
                    return;
                elseif this.a.ReadLeft()
                    stable = false;
                    return;
                elseif this.a.ReadMiddle()
                    stable = false;
                    return;
                elseif this.a.ReadRight()
                    if ~this.isLeftTrial && this.Setting_Struct.ConfirmChoice
                        this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), "Flash_Contour")
                    end
                end
            end
            %toc
            stable = STABLE && this.a.ReadRight;
        end
        %read the lever (digital read)
        function [WhatDecision, response_time] = readLeverLoopDigital_OnlyCorrect(this)
            [WhatDecision, response_time] = this.readLeverLoopDigitalCore(true);
        end
        function [WhatDecision, response_time] = readLeverLoopDigitalCore(this, only_correct_mode)
            response_time = 0;
            this.DuringTMal = 0;
            event = -1;
            try
                timeout_value = this.Box.Timeout_after_time;
                skip_handle = this.Skip;
                stop_handle = this.stop_handle;
                arduino = this.a;
                stim = this.StimulusStruct;
                box = this.Box;
                % Yield to serial callbacks without adding a fixed 10 ms
                % response-latency floor to every digital read.
                loop_pause = 0;
                middle_flash_interval = 0.05;
                contour_flash_interval = 0.05;
                is_left_trial = this.isLeftTrial;
                confirm_choice = isfield(this.Setting_Struct, 'ConfirmChoice') && logical(this.Setting_Struct.ConfirmChoice);
                delay_time = this.getDelaySetting_('Input_Delay_Respond');
                has_cached_nose_token = false;
                try
                    has_cached_nose_token = isprop(arduino, 'ReadingChar');
                catch
                end

                accept_left = true;
                accept_right = true;
                if only_correct_mode
                    accept_left = logical(is_left_trial);
                    accept_right = ~accept_left;
                end

                all_lines = findobj(this.fig.Children, 'Type', 'Line');
                distractor_lines = findobj(this.fig.Children, 'Tag', 'Distractor');
                contour_lines = findobj(this.fig.Children, 'Tag', 'Contour');

                candidate_side = '';
                candidate_t0 = NaN;
                prev_middle = false;
                last_middle_flash_t = -Inf;
                last_contour_flash_t = -Inf;

                % Stall reminder: if no nose input for stallSec, briefly dim stimulus.
                stallSec = 5;
                stallBlinkDur = 0.10;
                tLastInput = 0;
                stallBlinkActive = false;
                stallBlinkT0 = 0;
                stall_lines = this.getStallBlinkLines_([contour_lines; distractor_lines]);
                stallBaseColor = stim.LineColor;
                stallDimColor = stim.DimColor;

                t_loop = tic;
                while true
                    t_now = toc(t_loop);
                    if timeout_value ~= 0 && t_now >= timeout_value
                        break;
                    end
                    if skip_handle.Value
                        skip_handle.Value = 0;
                        response_time = t_now;
                        break;
                    elseif stop_handle.Value
                        response_time = t_now;
                        break;
                    end

                    if has_cached_nose_token
                        token = arduino.ReadingChar;
                        if isempty(token)
                            token = '-';
                        else
                            token = token(1);
                        end
                    else
                        token = this.currentNoseToken_();
                    end

                    % Non-blocking stall blink while no sensor is active.
                    if token ~= '-'
                        tLastInput = t_now;
                        if stallBlinkActive
                            stall_lines = this.getStallBlinkLines_(stall_lines);
                            this.setLinesColorSafe_(stall_lines, stallBaseColor);
                            stallBlinkActive = false;
                        end
                    elseif ~stallBlinkActive && (t_now - tLastInput) >= stallSec
                        stall_lines = this.getStallBlinkLines_(stall_lines);
                        this.setLinesColorSafe_(stall_lines, stallDimColor);
                        stallBlinkActive = true;
                        stallBlinkT0 = t_now;
                    end
                    if stallBlinkActive && (t_now - stallBlinkT0) >= stallBlinkDur
                        stall_lines = this.getStallBlinkLines_(stall_lines);
                        this.setLinesColorSafe_(stall_lines, stallBaseColor);
                        stallBlinkActive = false;
                        tLastInput = t_now;
                    end

                    if token == 'M'
                        this.DuringTMal = this.DuringTMal + 1;
                        if (~prev_middle) || ((t_now - last_middle_flash_t) >= middle_flash_interval)
                            if isempty(all_lines) || any(~isgraphics(all_lines))
                                all_lines = findobj(this.fig.Children, 'Type', 'Line');
                            end
                            this.FlashNew(stim, box, all_lines, "Make_Background", false);
                            last_middle_flash_t = t_now;
                        end
                        candidate_side = '';
                        candidate_t0 = NaN;
                        last_contour_flash_t = -Inf;
                        prev_middle = true;
                        pause(loop_pause);
                        continue;
                    end
                    prev_middle = false;

                    if token == 'L' || token == 'R'
                        if isempty(candidate_side) || candidate_side ~= token
                            candidate_side = token;
                            candidate_t0 = max(0, t_now - loop_pause);
                            last_contour_flash_t = -Inf;
                        end

                        if confirm_choice
                            is_correct_candidate = ...
                                ((candidate_side == 'L') && (is_left_trial == 1 || is_left_trial == -1)) || ...
                                ((candidate_side == 'R') && (is_left_trial == 0 || is_left_trial == -1));
                            if is_correct_candidate && ((t_now - last_contour_flash_t) >= contour_flash_interval)
                                if isempty(contour_lines) || any(~isgraphics(contour_lines))
                                    contour_lines = findobj(this.fig.Children, 'Tag', 'Contour');
                                end
                                this.FlashNew(stim, box, contour_lines, "Flash_Contour");
                                last_contour_flash_t = t_now;
                            end
                        end

                        if ~isnan(candidate_t0) && (t_now - candidate_t0) >= delay_time
                            if candidate_side == 'L' && accept_left
                                event = 1;
                                response_time = t_now;
                                break;
                            elseif candidate_side == 'R' && accept_right
                                event = 2;
                                response_time = t_now;
                                break;
                            else
                                candidate_side = '';
                                candidate_t0 = NaN;
                                last_contour_flash_t = -Inf;
                            end
                        end
                    else
                        candidate_side = '';
                        candidate_t0 = NaN;
                        last_contour_flash_t = -Inf;
                    end
                    pause(loop_pause);
                end

                % Never leave the stimulus dimmed after loop exit.
                if stallBlinkActive
                    stall_lines = this.getStallBlinkLines_(stall_lines);
                    this.setLinesColorSafe_(stall_lines, stallBaseColor);
                end

                should_dim_distractors = true;
                if ~only_correct_mode && isfield(this.Setting_Struct, 'OnlyCorrect') && logical(this.Setting_Struct.OnlyCorrect)
                    is_wrong_initial = false;
                    if event == 1
                        is_wrong_initial = ~(is_left_trial == 1 || is_left_trial == -1);
                    elseif event == 2
                        is_wrong_initial = ~(is_left_trial == 0 || is_left_trial == -1);
                    end
                    if is_wrong_initial
                        should_dim_distractors = false;
                    end
                end

                if should_dim_distractors
                    try
                        if isempty(distractor_lines) || any(~isgraphics(distractor_lines))
                            distractor_lines = findobj(this.fig.Children, "Tag", "Distractor");
                        end
                        this.FlashNew(stim, box, distractor_lines, "Make_Dim")
                        if ~isempty(distractor_lines) && all(isgraphics(distractor_lines))
                            [distractor_lines.Color] = deal(stim.DimColor);
                        end
                    catch
                    end
                end
            catch err
                this.unwrapError(err);
            end

            switch event
                case -1
                    WhatDecision = 'time out';
                    response_time = 0;
                case 1
                    if this.isLeftTrial == 1 || this.isLeftTrial == -1
                        if only_correct_mode
                            WhatDecision = 'left correct OC';
                        else
                            WhatDecision = 'left correct';
                        end
                    else
                        WhatDecision = 'left wrong';
                    end
                case 2
                    if this.isLeftTrial == 0 || this.isLeftTrial == -1
                        if only_correct_mode
                            WhatDecision = 'right correct OC';
                        else
                            WhatDecision = 'right correct';
                        end
                    else
                        WhatDecision = 'right wrong';
                    end
            end
        end
        function token = currentNoseToken_(this)
            token = '-';
            try
                if isprop(this.a, 'ReadingChar')
                    rc = this.a.ReadingChar;
                    if ~isempty(rc)
                        token = char(rc(1));
                    end
                    return
                end
            catch
            end
            try
                if this.a.ReadMiddle()
                    token = 'M';
                elseif this.a.ReadLeft()
                    token = 'L';
                elseif this.a.ReadRight()
                    token = 'R';
                else
                    token = '-';
                end
            catch
            end
        end
        function delay = getDelaySetting_(this, primaryField, fallbackField)
            arguments
                this
                primaryField (1,:) char
                fallbackField (1,:) char = ''
            end
            delay = 0;
            try
                if isfield(this.Setting_Struct, primaryField) && ~isempty(this.Setting_Struct.(primaryField))
                    delay = double(this.Setting_Struct.(primaryField));
                elseif ~isempty(fallbackField) && isfield(this.Setting_Struct, fallbackField) && ~isempty(this.Setting_Struct.(fallbackField))
                    delay = double(this.Setting_Struct.(fallbackField));
                end
            catch
                delay = 0;
            end
            if ~isfinite(delay) || delay < 0
                delay = 0;
            end
        end
        function lines = getStallBlinkLines_(this, lines)
            if nargin < 2 || isempty(lines)
                lines = gobjects(0);
            end
            try
                lines = lines(isgraphics(lines));
            catch
                lines = gobjects(0);
            end
            if isempty(lines)
                lines = [findobj(this.fig.Children, 'Tag', 'Contour'); findobj(this.fig.Children, 'Tag', 'Distractor')];
                lines = lines(isgraphics(lines));
            end
            if isempty(lines)
                lines = findobj(this.fig.Children, 'Type', 'Line');
                lines = lines(isgraphics(lines));
            end
        end
        function setLinesColorSafe_(~, lines, color)
            if isempty(lines)
                return
            end
            c = color;
            if isnumeric(c) && isscalar(c)
                c = repmat(c, 1, 3);
            end
            try
                [lines(:).Color] = deal(c);
            catch
                try
                    set(lines, 'Color', c);
                catch
                end
            end
        end
        function waitForCorrectSensorAndStallBlink_(this, WaitCorrect)
            stallSec = 5;
            stallBlinkDur = 0.10;
            tWait = tic;
            tLastTrigger = 0;
            blinkActive = false;
            blinkT0 = 0;
            baseColor = this.StimulusStruct.LineColor;
            dimColor = this.StimulusStruct.DimColor;

            % During reward waiting, distractor should remain dim the whole time.
            distractor_lines = findobj(this.fig.Children, 'Tag', 'Distractor');
            distractor_lines = distractor_lines(isgraphics(distractor_lines));
            this.setLinesColorSafe_(distractor_lines, dimColor);

            while contains(this.WhatDecision, 'correct', 'IgnoreCase', true) && ~WaitCorrect()
                tNow = toc(tWait);
                if ~blinkActive && (tNow - tLastTrigger) >= stallSec
                    contour_lines = findobj(this.fig.Children, 'Tag', 'Contour');
                    contour_lines = contour_lines(isgraphics(contour_lines));
                    distractor_lines = findobj(this.fig.Children, 'Tag', 'Distractor');
                    distractor_lines = distractor_lines(isgraphics(distractor_lines));
                    if isempty(contour_lines) && isempty(distractor_lines)
                        all_lines = this.getStallBlinkLines_();
                        this.setLinesColorSafe_(all_lines, dimColor);
                    else
                        % Reward idle flash: contour blinks; distractor stays dim.
                        this.setLinesColorSafe_(contour_lines, dimColor);
                        this.setLinesColorSafe_(distractor_lines, dimColor);
                    end
                    blinkActive = true;
                    blinkT0 = tNow;
                elseif blinkActive && (tNow - blinkT0) >= stallBlinkDur
                    contour_lines = findobj(this.fig.Children, 'Tag', 'Contour');
                    contour_lines = contour_lines(isgraphics(contour_lines));
                    distractor_lines = findobj(this.fig.Children, 'Tag', 'Distractor');
                    distractor_lines = distractor_lines(isgraphics(distractor_lines));
                    if isempty(contour_lines) && isempty(distractor_lines)
                        all_lines = this.getStallBlinkLines_();
                        this.setLinesColorSafe_(all_lines, baseColor);
                    else
                        this.setLinesColorSafe_(contour_lines, baseColor);
                        % Keep distractor dim after reward-wait idle blink.
                        this.setLinesColorSafe_(distractor_lines, dimColor);
                    end
                    blinkActive = false;
                    tLastTrigger = tNow;
                end

                pause(0.05); drawnow;
                if get(this.stop_handle, 'Value') || get(this.app.FastForward, 'Value')
                    break
                end
            end

            if blinkActive
                contour_lines = findobj(this.fig.Children, 'Tag', 'Contour');
                contour_lines = contour_lines(isgraphics(contour_lines));
                distractor_lines = findobj(this.fig.Children, 'Tag', 'Distractor');
                distractor_lines = distractor_lines(isgraphics(distractor_lines));
                if isempty(contour_lines) && isempty(distractor_lines)
                    all_lines = this.getStallBlinkLines_();
                    this.setLinesColorSafe_(all_lines, baseColor);
                else
                    this.setLinesColorSafe_(contour_lines, baseColor);
                    this.setLinesColorSafe_(distractor_lines, dimColor);
                end
            end
        end
        function FlashNew(this, Stim, Box, Lines, whatdecision, OneWay)
            arguments
                this
                Stim = this.StimulusStruct % from Setting structure
                Box = this.Box
                Lines = findobj(this.fig, 'Tag', 'Contour')
                whatdecision = "time out"
                OneWay logical = false
            end
            if isempty(Lines)
                return
            end
            is_make_action = any(strcmpi(string(whatdecision), ["Make_Dim", "Make_Background", "Make_StartColor", "Make_FlashColor"]));
            if ~Stim.FlashStim && ~is_make_action
                return
            end
            start_color = Stim.LineColor;
            flash_color = Stim.FlashColor;
            dark_color = Stim.DimColor;
            background_color = Stim.BackgroundColor;
            Steps = max(1, round(double(Stim.FreqAnimation)));
            if ~Stim.FlashStim && is_make_action
                Steps = 1;
            end
            if whatdecision == "WaitForInput" % Interrupt flash if mouse stops selecting center
                this.BasicFlashCosine("Lines",Lines, "NewColor", flash_color, "steps", Steps, "Interruptor", @(x)~this.a.ReadNone())
            elseif whatdecision == "Flash_Contour" % Interrupt flash if mouse stops selecting correct side
                this.BasicFlashCosine("Lines",Lines, "NewColor", flash_color, "steps", Steps, "Interruptor", @(x)this.a.ReadMiddle())
            elseif whatdecision == "Make_Dim"
                this.BasicFlashCosine("Lines",Lines, "NewColor", dark_color, "steps", Steps, "OneWay", true)
            elseif whatdecision == "Make_Background"
                this.BasicFlashCosine("Lines",Lines, "NewColor", background_color, "steps", Steps, "OneWay", OneWay)
            elseif whatdecision == "Make_StartColor"
                this.BasicFlashCosine("Lines",Lines, "NewColor", start_color, "steps", Steps, "OneWay", true)
            elseif whatdecision == "Make_FlashColor"
                this.BasicFlashCosine("Lines",Lines, "NewColor", flash_color, "steps", Steps, "OneWay", true)
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
            obj = vars.Lines;
            obj = obj(isgraphics(obj));
            if isempty(obj)
                return
            end
            NewColor = vars.NewColor;
            steps = vars.steps;
            OneWay = vars.OneWay;
            % This blinks the Obj to the NewColor and back, over a total of
            % 2*steps increments
            if obj(1).Type == "scatter"
                start_color = [obj(1).MarkerFaceColor];
                COLOR_PROP = 'MarkerFaceColor';
            elseif any(obj(1).Type == ["polygon", "patch"])
                start_color = [obj(1).FaceColor];
                COLOR_PROP = 'FaceColor';
            elseif any(obj(1).Type == ["line", "constantline"])
                start_color = [obj(1).Color];
                COLOR_PROP = 'Color';
            elseif obj(1).Type == "rectangle"
                start_color = [obj(1).FaceColor];
                COLOR_PROP = 'FaceColor';
            else
                return %prevent an error crash
            end
            start_color = normalizeRGB_(start_color);
            NewColor = normalizeRGB_(NewColor);
            if steps <= 1
                set(obj, COLOR_PROP, NewColor);
                drawnow;
                return
            end
            if OneWay
                ST = 1:steps;
            else
                ST = [1:steps steps-1:-1:1];
            end
            mat = interp1([1 ; steps], [start_color ; NewColor], ST);
            for i_step = 1:size(mat, 1)
                C = mat(i_step, :);
                C = max(0, min(1, C));
                set(obj, COLOR_PROP, C); drawnow
                %pause(0.01)
                if ~isempty(vars.Interruptor) && vars.Interruptor() %This is all very slow and will be sped up later
                    set(obj, COLOR_PROP, start_color)
                    break
                end
            end

            function c = normalizeRGB_(c)
                c = double(c);
                c = c(:)';
                if isempty(c)
                    c = [0 0 0];
                elseif isscalar(c)
                    c = [c c c];
                elseif numel(c) < 3
                    c = [c repmat(c(end), 1, 3 - numel(c))];
                elseif numel(c) > 3
                    c = c(1:3);
                end
                if any(c > 1)
                    c = c / 255;
                end
                c = max(0, min(1, c));
            end
        end
        %open reward valves
        function GiveRewardAndFlash(this)
            if isempty(this.a) || this.a.KeyboardInput == true
                return
            end
            %Get reward valve, pulse number and time:
            switch this.Box.Input_type
                case 3 %Nose
                    decision = string(this.WhatDecision);
                    switch true
                        case contains(decision, 'OC', 'IgnoreCase', true) && contains(decision, 'left', 'IgnoreCase', true)
                            PulseNum = this.Box.OCPulse;
                            WaitCorrect = @()this.a.ReadLeft();
                            REWARD = @()this.a.GiveReward("Side",'L');
                        case contains(decision, 'OC', 'IgnoreCase', true) && contains(decision, 'right', 'IgnoreCase', true)
                            PulseNum = this.Box.OCPulse;
                            WaitCorrect = @()this.a.ReadRight();
                            REWARD = @()this.a.GiveReward("Side",'R');
                        case contains(decision, 'left correct', 'IgnoreCase', true)
                            PulseNum = this.Box.LeftPulse;
                            WaitCorrect = @()this.a.ReadLeft();
                            REWARD = @()this.a.GiveReward("Side",'L');
                        case contains(decision, 'right correct', 'IgnoreCase', true)
                            PulseNum = this.Box.RightPulse;
                            WaitCorrect = @()this.a.ReadRight();
                            REWARD = @()this.a.GiveReward("Side",'R');
                        case contains(decision, 'wrong', 'IgnoreCase', true)
                            if this.Box.Air_Puff_Penalty
                                PulseNum = this.Box.AirPuffPulses;
                            else
                                return
                            end
                    end
                case 6 % Wheel
                    switch true
                        case contains(this.WhatDecision, 'correct', 'IgnoreCase', true)
                            PulseNum = this.Box.RightPulse;
                        case contains(this.WhatDecision, 'wrong', 'IgnoreCase', true)
                            return %No air puff for wheel
                    end
                otherwise %Keyboard, any input method I haven't used before
                    return
            end
            PulseNum = max(0, round(double(PulseNum)));
            if PulseNum == 0
                return
            end
            % Wait for reward-port nosepoke with periodic stall reminder blink.
            this.waitForCorrectSensorAndStallBlink_(WaitCorrect)
            for P = 1:PulseNum
                if P > 1
                    pause(this.Box.SecBwPulse)
                    this.waitForCorrectSensorAndStallBlink_(WaitCorrect)
                end
                REWARD()
                this.RewardPulses = this.RewardPulses + 1;
                this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Tag', 'Contour'),  this.WhatDecision);
            end
        end
        %Use this function instead of pausing, so that buttons are checked and settings are updated during the pause
        function UpdatePause(this, interval)
            starttime = datetime("now");
            tic
            while toc < interval
                pause(0.5); drawnow;
                set(this.message_handle, 'Text', sprintf('Interval for %.1f sec...', max(interval-toc,0)));
                if this.Pause.Value
                    set(this.message_handle,'Text','Paused, click pause button again to continue...');
                    o = findobj(this.fig.Children);
                    [o(:).Visible] = deal(0);
                    this.fig.Color = this.ReadyCueStruct.Color;% Clear stim and turn the screen black to tell the mouse the time to drink water is now over. This should help mice not associate an air puff with the correct/rewarded stimulus, and instead associate an air puff with the black screen.
                    while get(this.Pause, 'Value')
                        pause(0.1); drawnow;
                    end
                    this.fig.Color = this.StimulusStruct.BackgroundColor;
                end
                %check if stop pressed
                if get(this.stop_handle, 'Value') || get(this.FF, 'Value')
                    %abort
                    break;
                end
            end
        end
        %Update data structure, update graphs, do intertrial time
        function AfterTrial(this)
            switch true
                case contains(this.WhatDecision,'correct')
                    interval = 'Intertrial interval';
                    interval_time = this.Setting_Struct.Intertrial_time;
                case contains(this.WhatDecision,'wrong')
                    interval = 'Penalty interval';
                    interval_time = this.Setting_Struct.Penalty_time;
                case contains(this.WhatDecision , 'malinger', 'IgnoreCase', true)
                    interval = 'Only poke center to begin a trial, Penalty interval';
                    interval_time = this.Setting_Struct.Penalty_time;
                case contains(this.WhatDecision,'time out')
                    interval = 'Time out, proceed to next trial';
                    interval_time = 0.5;
                    this.timeout_counter = this.timeout_counter+1;
            end
            %Update data & Plot, update GUI numbers
            this.UpdateData();
            if contains(this.WhatDecision,'time out')
                set(this.message_handle,'Text',interval);
            else
                set(this.message_handle,'Text',interval+" ("+num2str(interval_time)+" sec)");
            end
            if get(this.stop_handle, 'Value')
                return
            end
            this.updateMessageBox();
            %Wait for interval
            this.UpdatePause(interval_time);
            if ~isempty(this.a) && ~this.a.KeyboardInput
                switch this.Box.Input_type
                    case 3 % Nose
                        this.ReadyCue(1)
                        this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'ReadyCueDot'), "Make_StartColor");
                end
            end
            if this.Temp_Active
                this.Setting_Struct = this.Temp_Old_Settings;
            end
        end
        function updateMessageBox(this)
            try
                fid = fopen(this.textdiary, 'r');
                if fid < 0
                    return
                end
                cleanupObj = onCleanup(@()fclose(fid));
                fseek(fid, 0, 'eof');
                file_end = ftell(fid);
                if file_end < this.textdiary_pos
                    this.textdiary_pos = 0;
                    this.GuiHandles.MsgBox.String = '';
                end
                if file_end == this.textdiary_pos
                    return
                end
                fseek(fid, this.textdiary_pos, 'bof');
                new_chars = fread(fid, [1, file_end - this.textdiary_pos], '*char');
                this.textdiary_pos = file_end;
                if isempty(new_chars)
                    return
                end

                old_text = this.GuiHandles.MsgBox.String;
                if ischar(old_text)
                    old_text = string(cellstr(old_text));
                elseif iscell(old_text)
                    old_text = string(old_text);
                elseif ~isstring(old_text)
                    old_text = string(old_text);
                end
                if isempty(old_text)
                    old_text = "";
                elseif numel(old_text) > 1
                    old_text = strjoin(old_text, newline);
                end
                this.GuiHandles.MsgBox.String = char(old_text + string(new_chars));
            catch err
                this.unwrapError(err);
                if exist(this.textdiary, 'file') == 2
                    delete(this.textdiary)
                end
                diary(this.textdiary)
                this.textdiary_pos = 0;
                this.GuiHandles.MsgBox.String = '';
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

            this.RewardPulses = 0;
            this.InterTMal = 0;
            this.DuringTMal = 0;
            this.TrialStartTime = 0;
            this.ResponseTime = 0;
            this.DrinkTime = 0;
            this.BetweenTrialTime = 0;
            this.wheelchoice = [];
            this.wheelchoicetime = [];
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
% Make sure Weight is a field and Text is not
% in the saved newData structure
            arguments
                this
                options.RescueData = false
            end
            fakeNames = {'w', 'W'};
            
            % Abort saving if using fake names for testing
            if any(strcmp(num2str(this.Setting_Struct.Subject), fakeNames)) || ...
            any(strcmp(this.Setting_Struct.Strain, fakeNames))
                disp('[SaveAllData] Fake data detected, skipping save.');
                return
            end

            % Generate save name and folder based on platform
            timestamp = string(datetime(this.Data_Object.start_time, 'Format', 'yyMMdd_HHmmss'));
            stim = erase(this.app.Stimulus_type.Value, ' ');
            input = this.app.Box_Input_type.Value;
            Sub = this.Setting_Struct.Subject;
            Str = this.Data_Object.Str;
            saveasname = join([timestamp, Sub, Str, stim, input], '_');
            savefolder = this.normalizeSaveFolder_(this.Data_Object.filedir);
            set(this.message_handle,'Text', 'Saving data as: '+saveasname+'.mat');

            % Construct data to save
            [newData] = this.Data_Object.current_data_struct;
            newData = this.ensureColumns(newData);

            % Align data structure lengths
            newData = this.alignDataLengths(newData);

            Settings = this.combineSettingsForSave_();
            newData.SetUpdate = this.SetUpdate;
            newData.StimHist = this.filterNonEmptyRows(this.StimHistory);
            newData = this.setDataIndexes(newData, Settings);

            newData.Weight = this.Setting_Struct.Weight;
            Notes = this.GuiHandles.NotesText.String;
            f = [];
            if ~options.RescueData
                try
                    if ~isempty(this.graphFig) && isvalid(this.graphFig)
                        f = figure("MenuBar","none","Visible","off");
                        copyobj(this.graphFig.Children, f)
                        f.Children.Title.String = string(this.Data_Object.Inp)+" "+this.formatSubjectLabel_(this.Data_Object.Sub);
                    end
                catch
                    f = [];
                end
            end
            try
                save(fullfile(savefolder, saveasname) + ".mat", 'Settings', 'newData', 'Notes');
                if ~options.RescueData && ~isempty(f) && isvalid(f)
                    this.saveFigure(f, savefolder, saveasname)
                    f.MenuBar = 'figure';
                end
                dispstring = "Data saved as: "+saveasname+"\n";
                fprintf(dispstring);
                set(this.message_handle,'Text',dispstring);
            catch err
                % Use dialog to select save location if any error occurs
                this.handleSaveError(err, saveasname, Settings, newData, Notes);
            end
            %f.Visible = 1;
            this.setMessage(this.message_handle, 'Data saved successfully.', saveasname);
        end
        function newData = ensureColumns(~, newData)
            names = fieldnames(newData);
            for n = names(structfun(@isrow, newData) & structfun(@length, newData) > 1)'
                newData.(n{:}) = newData.(n{:})';
            end
        end
        function newData = alignDataLengths(~, newData)
            if isempty(newData.TimeStamp)
                return
            end
            FullTrials = numel(newData.TimeStamp);
            fields = fieldnames(newData);
            for n = fields(structfun(@length, newData) > FullTrials)'
                newData.(n{:}) = newData.(n{:})(1:FullTrials);
            end
        end
        function StimHist = filterNonEmptyRows(~, StimHistory)
% This is not working correctly. Only 1 trial's stim is being saved
            nonEmptyRows = any(~cellfun(@isempty, StimHistory'));
            StimHist = StimHistory(nonEmptyRows, :);
        end
        function newData = setDataIndexes(this, newData, Settings)
            [~, newData.Include] = this.getTimeline(newData);
            newData.SetStr = this.SetStr;
            newData.Settings = this.removeUnwantedFields(Settings);
        end
        function [Ts, Include] = getTimeline(this, newData)
        % This fcn causes errors. How necessary is it? All trials are
        % Included, so a vector labelling each trial is unnecessary
            Ts = this.Include;
            nTrials = numel(newData.TimeStamp);
            if nTrials == 0
                Include = [];
                return
            end

            Idcs = unique([this.normalizeSetUpdate_(this.SetUpdate), nTrials]);
            Idcs = Idcs(isfinite(Idcs) & Idcs >= 0);
            if isempty(Idcs)
                Include = ones(nTrials, 1);
                return
            end
            if Idcs(1) ~= 0
                Idcs = [0 Idcs];
            end
            if numel(Idcs) == 1
                Include = ones(nTrials, 1);
                return
            end

            try
                [~, ~, newData.SetIdx] = histcounts(1:nTrials, Idcs);
            catch
                [~, ~, newData.SetIdx] = histcounts(1:length(newData.Score), Idcs);
            end
            try
                Include = Ts(newData.SetIdx);
            catch
                Include = ones(size(newData.SetIdx));
            end
        end
        function Settings = removeUnwantedFields(~, Settings)
            toRemove = {'GUI_numbers', 'encoder'};
            for r = toRemove
                if isfield(Settings, r)
                    Settings = rmfield(Settings, r);
                end
            end
        end
        function handleSaveError(this, err, saveasname, Settings, newData, Notes)
            this.unwrapError(err);
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
            [file, path] = uiputfile(pwd, 'Choose folder to save training data', saveasname);
            if isequal(file, 0) || isequal(path, 0)
                set(this.message_handle,'Text', 'Save canceled.');
                return
            end
            save(fullfile(path, file), 'Settings', 'newData', 'Notes');
            if ~isempty(f) && isvalid(f)
                this.saveFigure(f, path, erase(string(file), '.mat'));
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
        function setUpdate = normalizeSetUpdate_(~, setUpdateIn)
            if isempty(setUpdateIn)
                setUpdate = 0;
            elseif iscell(setUpdateIn)
                try
                    setUpdate = cell2mat(setUpdateIn);
                catch
                    try
                        setUpdate = [setUpdateIn{:}];
                    catch
                        setUpdate = 0;
                    end
                end
            else
                setUpdate = double(setUpdateIn);
            end
            setUpdate = setUpdate(:)';
            setUpdate = setUpdate(~isnan(setUpdate));
            if isempty(setUpdate)
                setUpdate = 0;
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
        function setMessage(~, message_handle, message, saveasname)
            msg = message+" "+saveasname;
            set(message_handle, 'Text', msg);
            disp(msg);
        end
%when done, clean up
        function cleanUP(this)
            %switch on all buttons
            this.toggleButtonsOnOff(this.Buttons,1);
            this.stop_handle.Value = 0;%Turn off Stop button
            %close stimulus if still open
            delete(findobj("Type", "figure", "Name", "Stimulus"))
            this.fig = [];
            this.ReadyCueAx = [];
            this.LStimAx = [];
            this.RStimAx = [];
            this.FLAx = [];
            this.Stimulus_Object = struct();
            disp_string = ['Stopped training Mouse ',num2str(this.Setting_Struct.Subject), ' at ',datestr(now)];
            disp(disp_string);
            disp('- - - - -');
        end
        function ReadyCue(this, isVis)
            %isVis is 1 or 0
            switch 1
                case numel(isVis) == 3 %RGB triplet
                    set(this.ReadyCueAx, 'Color', isVis, 'Visible', 1);
                    return
                case any(int8(isVis) == [0 1]) || islogical(isVis)%Logical off or on
                    isVis = logical(isVis);
                case ischar(isVis) %Letter color abbrev.
                    ax = findobj(this.ReadyCueAx, 'Type', 'Axes');
                    set(ax, 'Color', char(isVis), 'Visible', 1);
                    try
                        [this.ReadyCueAx.Children.Visible] = deal(0);
                    catch
                    end
                    return
            end
            % Plot a circle in the center to show that a new trial is ready
            %Make the figure if this is the first call to readycue, or make a new one
            %if the window has been closed
            if ~isempty(this.ReadyCueAx) && all(isvalid(this.ReadyCueAx))
                set(this.ReadyCueAx, 'Visible', isVis);
                set(this.ReadyCueAx.Children, 'Visible', isVis);
            else %First time, make axis
                switch this.Box.Input_type
                    case 6 % Wheel is different
                        RQ_Ax = axes('Parent', this.fig, ...
                            'color', this.ReadyCueStruct.Color, ...
                            'Position', [0 0 1 1], ...
                            'Xlim', [-10 10], ...
                            'YLim', [-7 13], ...
                            'XTick',[], 'YTick',[], ...
                            'Tag', 'ReadyCue');
                        hold(findobj(this.fig, 'Tag', 'ReadyCue'), 'on')
                        this.ReadyCueAx = [findobj(this.fig, 'Tag', 'ReadyCue')];
                    otherwise
                        RQ_Ax = axes('Parent', this.fig, ...
                            'color', this.StimulusStruct.BackgroundColor, ...
                            'Position', [0 0 1 1], ...
                            'Xlim', [-10 10], ...
                            'YLim', [-7 13], ...
                            'XTick',[], 'YTick',[], ...
                            'Tag', 'ReadyCue');
                        hold(findobj(this.fig, 'Tag', 'ReadyCue'), 'on')
                        Dot = scatter(0,0,this.ReadyCueStruct.Size*1000, ...
                            'LineWidth', 10000, ...
                            'Marker', 'o', ...
                            'MarkerFaceColor', this.ReadyCueStruct.Color, ...
                            'MarkerEdgeColor', 'none', ...
                            'Parent', RQ_Ax, ...
                            'Tag', 'ReadyCueDot');
                        this.ReadyCueAx = [findobj(this.fig, 'Tag', 'ReadyCue')];
                end
            end
        end
        function TestBox(this)
            this.getGUI();
            set(this.message_handle,'Text','Trigger the Left Sensor');
            while ~this.a.ReadLeft
                pause(0.1);
                %just wait until the sensor is triggered
            end
            set(this.message_handle,'Text','Trigger the Right Sensor');
            while ~this.a.ReadRight
                pause(0.1);
                %just wait until the sensor is triggered
            end
            set(this.message_handle,'Text','Trigger the Middle Sensor');
            while ~this.a.ReadMiddle
                pause(0.1);
                %just wait until the sensor is triggered
            end
            this.cleanUP();
            set(this.message_handle,'Text','Did the sensors work?');
        end
        function TestStimulus(this, options)
            arguments
                this
                options.SaveStimulus logical = 0
            end
            tic
            this.app.ShowStim.Enable = 0; %Set to 1 when debugging...
            this.getGUI();
            this.Stimulus_Object = BehaviorBoxVisualStimulus(this.StimulusStruct, Preview=1);
            this.Stimulus_Object = this.Stimulus_Object.updateProps(this.StimulusStruct);
            if isempty([this.Stimulus_Object.LStimAx this.Stimulus_Object.RStimAx])
                [this.fig,this.LStimAx,this.RStimAx, ~] = this.Stimulus_Object.setUpFigure(); drawnow
                this.Stimulus_Object = this.Stimulus_Object.findfigs();
            end
            [~,~] = this.Stimulus_Object.DisplayOnScreen(this.PickSideForCorrect(0, 0), this.Setting_Struct.Starting_opacity);
            this.fig = this.Stimulus_Object.fig;
            [this.fig.findobj('Tag','Spotlight').Visible] = deal(1);
            set(this.fig.findobj('Type','Line'), 'Color', this.StimulusStruct.BackgroundColor)
            toc
            %pause(0.1)
            drawnow
            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'line'), "Make_StartColor")
            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'line'), "Make_Background")
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
                error('BehaviorBoxNose:InvalidDataObject', ...
                    'BehaviorBoxData setup did not return a BehaviorBoxData object.');
            end
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
            this.wheelchoice = [];
            this.wheelchoicetime = [];
            this.wheelchoice_record = cell(400,3);
        end
        function setSessionStartTime_(this)
            this.start_time = datetime("now");
            this.Data_Object.GetStartTime;
        end
    end
    %STATIC FUNCTIONS====
    methods(Static = true)
        %toggle GUI buttons active/inactive
        function toggleButtonsOnOff(Buttons, on)
            for b = struct2cell(Buttons)'
                if b{:}.Type == "uistatebutton"
                    continue
                else
                    b{:}.Enable = on;
                end
            end
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
        %open reward valves
        function [WhatDecision, response_time] = readKeyboardInput(stop_handle, message_handle, isLeftTrial)
            text = 'Respond: Press L for Left, R for Right, C or M for Middle:';
            set(message_handle,'Text',text); 
            fprintf([text '\n']); 
            drawnow
            prompt = 'L, R, or M/C:   ';
            keypress = 0; t1 = tic;
            while keypress==0
                pause(0.1); drawnow;
                currkey = input(prompt,"s");
                response_time = toc(t1);
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
                pause(0.1); drawnow;
                if stop_handle.Value
                    set(message_handle, 'String','Ending session...'); drawnow
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
        function saveFigure(fig, folder, name)
            % Remove .mat extension if present and prepare the file name
            name = erase(name, '.mat');
            
            % Prepare figure properties for exporting
            figureOpts = struct(...
                'Units', 'inches', ...
                'Format', 'pdf', ...
                'Preview', 'none', ...
                'Width', 11, ...            % Width in inches
                'Height', 8.5, ...          % Height in inches
                'FixedLineWidth', 1, ...
                'ScaledLineWidth', 'auto', ...
                'LineMode', 'none', ...
                'LineWidthMin', 0.1, ...
                'FontName', 'Helvetica', ...
                'FontWeight', 'auto', ...
                'FontAngle', 'auto', ...
                'FontEncoding', 'latin1', ...
                'Renderer', 'painters', ...
                'Resolution', 600, ...
                'LineStyleMap', 'none', ...
                'ApplyStyle', 0, ...
                'Bounds', 'tight', ...
                'LockAxes', 'off', ...
                'LockAxesTicks', 'off', ...
                'ShowUI', 'off', ...
                'SeparateText', 'off', ...
                'Color', 'rgb', ...
                'Background', 'w' ...
            );
            
            % Configure the figure according to the defined properties
            set(fig, ...
                'PaperUnits', figureOpts.Units, ...
                'PaperPositionMode', 'auto', ...
                'PaperSize', [figureOpts.Width figureOpts.Height], ...
                'Units', figureOpts.Units);
            outputFilePath = fullfile(folder, name+".pdf");
            exportgraphics(fig, outputFilePath, ...
                'ContentType', 'vector', ...
                'BackgroundColor', figureOpts.Background, ...
                'Resolution', figureOpts.Resolution);
        end
        function unwrapError(err)
            % Unwraps and prints the details of an error object
            disp(['Error message: ' err.message]); % Print the error message
            errFields = fields(err);
            for i = 1:numel(errFields)
                if ~matches(errFields{i}, 'stack')
                    if ~isempty(err.(errFields{i}))
                        disp([errFields{i} ': ' err.(errFields{i})])
                    end
                elseif matches(errFields{i}, 'stack')
                    for L = numel(err.stack):-1:1
                        disp(['In function ' err.stack(L).name ', line ' num2str(err.stack(L).line)])
                    end
                end
            end
        end
    end
end
