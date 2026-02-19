classdef BehaviorBoxWheel < handle
    %BehaviorBox Super class
    % WBS 10 . 10 . 2024
    %=================================================0===================
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
        SetIdx = {};
        SetStr = {};
        Include = {};
        GuiHandles = struct();
        app = struct();
        appProps; %cycle thru these 3 to update settings
        appPropsTypes;
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
        timestamps_record = cell(400,1); %All wheel choice processes with what_decision
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
            this.GuiHandles.MsgBox.String = fileread(this.textdiary);
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
            %Make Dropdown structure
            this.appProps = props;
            this.appPropsTypes = types;
            Dropdowns = props(contains(types, {'dropdown'}));
            dTags = this.GetTag(this.app, Dropdowns);
            DropVals = cellfun(@(x)find(matches(this.app.(x).Items, this.app.(x).Value)), Dropdowns, 'UniformOutput',false);
            this.dropdowns = cell2struct(DropVals, dTags);
            props = props(~contains(types, {'dropdown'})); types = this.GetType(this.app, props);
            %Make Checkbox structure
            setVals = cell(size(props));
            CIdx = contains(types, {'check'});
            Checkboxes = props(CIdx);
            cVals = cellfun(@(x)logical(this.app.(x).Value), Checkboxes, 'UniformOutput',false);
            setVals(CIdx) = cVals;
            pTags = this.GetTag(this.app, props);
            setVals(~CIdx) = cellfun(@(x)str2double(this.app.(x).Value), props(~CIdx), 'UniformOutput',false);
            ReDo = cellfun(@isnan, setVals, 'UniformOutput',true);
            setVals(ReDo) = cellfun(@(x)(this.app.(x).Value), props(ReDo), 'UniformOutput',false);
            tempSetting_Struct = cell2struct(setVals, pTags);
            tempSetting_Struct = appendStruct(tempSetting_Struct, this.dropdowns);
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
        function makeTrialStructures(this, Settings)
            this.StimulusStruct = appendStruct(this.StimulusStruct, PullOut(Settings, 'Stimulus_'));
            this.Box = appendStruct(this.Box, PullOut(Settings, 'Box_'));
            this.ReadyCueStruct = appendStruct(this.ReadyCueStruct, PullOut(Settings, 'ReadyCue_'));
            this.LevelStruct = appendStruct(this.LevelStruct, PullOut(Settings, 'Level_'));
            this.Temp_Settings = appendStruct(this.Temp_Settings, PullOut(Settings, '_Temp'));
            function OUT = PullOut(IN, chr)
                names = fieldnames(IN);
                inter = names(contains(names, chr));
                vals = cellfun(@(x)IN.(x), inter, "UniformOutput",false);
                CIDX = contains(inter, "color", IgnoreCase=true);
                vals(CIDX) = cellfun(@(x)repmat(x,1,3), vals(CIDX), "UniformOutput",false);
                OUT = cell2struct(vals, erase(inter, chr));
            end
        end
        function OUT = ManyLevels(~, In)
            OUT = In;
            if ~isnumeric(In.HardLvList)
                HardLevs = str2num(In.HardLvList); %#ok<ST2NM>
            else
                HardLevs = In.HardLvList;
            end
            if ~isnumeric(In.EasyLvList)
                EasyLevs = str2num(string(In.EasyLvList)); %#ok<ST2NM>
            else
                EasyLevs = In.EasyLvList;
            end
            LEVELS = {EasyLevs HardLevs; In.EasyLvProb In.HardLvProb};
            PossibleLevels = [];
            for L = LEVELS
                levs = L{1};
                p = ceil((L{2}*100)/numel(levs));
                for l = levs
                    PossibleLevels = [PossibleLevels repmat(l, 1, p)];
                end
            end
            OUT.PossibleLevels = PossibleLevels;
            OUT.ChooseLevel = @(x)OUT.PossibleLevels(randperm(numel(PossibleLevels), 1));
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
            try
                this.Data_Object = BehaviorBoxData( ...
                    Inv=this.app.Inv.Value, ...
                    Inp=this.app.Box_Input_type.Value, ...
                    Str=this.app.Strain.Value, ...
                    Sub={this.app.Subject.Value}, ...
                    find=1); % Set up data storage object
            catch
            end
            DATE = sprintf("BBTrialLog_%s.txt", datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            try
                diaryname = fullfile(this.Data_Object.filedir, DATE);
            catch
                diaryname = fullfile(this.Data_Object.Sub, DATE);
            end
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
            if this.Setting_Struct.Ext_trigger %wait for trigger to start experiment
                txt = "Waiting for trigger to start..";
                set(this.message_handle,'Text',txt, ...
                    'BackgroundColor','blue');
                fprintf(txt+"\n");
                while 1
                    pause(0.01); drawnow;
                    if this.Box.readPin(this.Setting_Struct.TriggerPin) || get(this.stop_handle, 'Value') %check if abort button is pressed
                        break %abort
                    end
                end
            end
            [this.fig, this.LStimAx, this.RStimAx, this.FLAx, ~] = this.Stimulus_Object.setUpFigure();
            if ~any([this.app.Animate_Go.Value this.app.Animate_Show.Value this.app.Animate_Flash.Value this.app.Animate_Rec.Value]) % Don't show finish line for animation
                this.ReadyCue('Create')
                this.ReadyCueAx = this.fig.Children(3);
                this.ReadyCueStruct.Ax = this.ReadyCueAx;
                this.StimulusStruct.ReadyCue = this.ReadyCueStruct;
            end
            % this.toggleButtonsOnOff(this.Buttons,0); % Turn off all buttons
            fprintf("- - - - -\n");
            txt = "Start trial Mouse "+this.Setting_Struct.Subject+" at "+string(datetime('now'));
            set(this.message_handle,'Text',txt);
            fprintf(txt+"\n");
            this.i = 0;
            this.timeout_counter = 0;
            this.Temp_Active = false;
            try
                this.a.TimeStamp('Off')
            catch
            end
            try % Clear timestamp log
                set(this.message_handle, 'Text', "Clearing timestamp log ...");
                this.Time.Reset();
                pause(0.1)
                this.Time.Log(end+1,1) = "Before Trial Loop";
            catch
            end
            % Send Start Acquisition signal to ScanImage
            try
                set(this.message_handle, 'Text', "Starting acquisition (ScanImage)...");
                this.a.Acquisition('Start');
                pause(2)
                this.message_handle.Text = 'Starting recording, Pausing 2 sec...';
            catch
            end
        end
        %Do some things before each trial
        function BeforeTrial(this)
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
            %Update GUI window numbers
            this.updateGUIbeforeIteration(); %Update again, in case the level changed
            [this.fig.Children.findobj('Type','Line').Visible] = deal(0);
            drawnow
            this.ReadyCue(true)
        end
        function CheckTemp(this)
            % Temp_Settings = struct();
            % Temp_Old_Settings = struct();
            % Temp_Countdown = 0;
            % Temp_iStart = 0;
            % Temp_Active = 0;
            if ~this.Temp_Active
                if this.Temp_Settings.PerformanceThreshold || this.Temp_Settings.TrialNumber
                    this.Temp_Active = true;
                    this.Temp_iStart = true;
                end
            end
            if this.Temp_Active && this.Temp_Settings.TempOff
                this.Temp_Active = false;
                this.Setting_Struct = this.Temp_Old_Settings;
                this.app.TrialsRemainingLabel.Text = "_ Trials Remaining";
                this.app.TempOff_Temp.Value = 1;
            end
            if this.Temp_Active
                this.Temp_Old_Settings = this.Setting_Struct;
                this.Setting_Struct = copytoStruct(this.Setting_Struct, this.Temp_Settings);
                if this.Temp_iStart
                    this.Temp_iStart = false;
                    this.Temp_Countdown = this.Temp_Settings.TrialCount;
                end
                this.Temp_Countdown = this.Temp_Countdown - 1;
                this.app.TrialsRemainingLabel.Text = this.Temp_Countdown+" Trials Remaining";
                if this.Temp_Countdown == 0
                    this.Temp_Active = false;
                    this.Setting_Struct = this.Temp_Old_Settings;
                    this.app.TrialsRemainingLabel.Text = "_ Trials Remaining";
                    this.app.TempOff_Temp.Value = 1;
                end
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
            PossibleLevels = this.LevelStruct.PossibleLevels;
            current_difficulty = PossibleLevels( randperm( numel(PossibleLevels), 1) );
        end
        %Update all the settings if the button is ticked
        function UpdateSettings(this)
            props = this.appProps;
            types = this.appPropsTypes;
            Dropdowns = props(contains(this.appPropsTypes, {'dropdown'}));
            dTags = this.GetTag(this.app, Dropdowns);
            DropVals = cellfun(@(x)find(matches(this.app.(x).Items, this.app.(x).Value)), Dropdowns, 'UniformOutput',false);
            this.dropdowns = cell2struct(DropVals, dTags);
            tempVal = cell(size(props));
            CIdx = contains(types, {'check'});
            Checkboxes = props(CIdx);
            cVals = cellfun(@(x)logical(this.app.(x).Value), Checkboxes, 'UniformOutput',false);
            tempVal(CIdx) = cVals;
            pTags = this.GetTag(this.app, props);
            tempVal(~CIdx) = cellfun(@(x)str2double(this.app.(x).Value), props(~CIdx), 'UniformOutput',false);
            ReDo = cellfun(@isnan, tempVal, 'UniformOutput',true);
            tempVal(ReDo) = cellfun(@(x)(this.app.(x).Value), props(ReDo), 'UniformOutput',false);
            tempSetting_Struct = cell2struct(tempVal, pTags);
            tempSetting_Struct = appendStruct(tempSetting_Struct, this.dropdowns);
            if isequal(tempSetting_Struct, this.Setting_Struct)
                return
            end
            updatelist = {};
            names = fieldnames(tempSetting_Struct);
            for n = names'
                x = n{:};
                if ~isequal(tempSetting_Struct.(x), this.Setting_Struct.(x))
                    try
                        updatelist{end+1} = " "+x+" - "+this.Setting_Struct.(x)+" to "+tempSetting_Struct.(x);
                    catch
                        updatelist{end+1} = " "+x;
                    end
                end
            end
            msg = "Trial "+this.i+" Updating:\n"+join([updatelist{:}],"\n")+"\n";
            fprintf(msg) %Print this to the Message window
            this.Old_Setting_Struct{end+1} = this.Setting_Struct;
            this.makeTrialStructures(tempSetting_Struct)
            this.LevelStruct = this.ManyLevels(this.LevelStruct);
            this.Setting_Struct = tempSetting_Struct;
            this.SetIdx = this.SetIdx + 1;
            this.SetUpdate{end+1} = this.i;
            [this.SetStr(end+1), this.Include(end+1)] = this.structureSettings(tempSetting_Struct);
            this.Stimulus_Object = this.Stimulus_Object.updateProps(this.StimulusStruct);
            [this.Level] = this.Setting_Struct.Starting_opacity;
        end
        %Choose if Left or Right will be correct
        function isLeftTrial = PickSideForCorrect(this, isLeftTrial, ~)
            % ATTENTION!!!
            % Do NOT double the & and | to && and || just because the Matlab error
            % warning says it will be "faster." Doubling them will change the logical
            % meaning of the phrase and will ruin how repeat wrong functions. Keeping
            % the boolean operators singular (& and | as opposed to && and ||) prevents
            % short circuiting and keeps the code from erroneourly engaging repeat
            % wrong. Use debug mode to check the outcomes of all of these commands to
            % ensure that repeat wrong can be disabled. WBS 3/11/2022
            %Also do NOT change the order of the if statements.
            if all(this.StimulusStruct.side ~= [2 3]) && this.i == 1 %%If not left/right only and first trial, no data structure exists yet.
                choice = [0 1];
                isLeftTrial = choice(randperm(2,1));
            elseif this.Setting_Struct.Repeat_wrong
                if isprop(this.Data_Object, 'current_data_struct') & this.Data_Object.current_data_struct.Score(end) == 0
                    return
                else
                    choice = [0 1];
                    isLeftTrial = choice(randperm(2,1));
                end
            else
                switch this.StimulusStruct.side
                    case 1 %Random
                        % Add 0.5 bc values oscillate -0.5 to 0.5
                        choice = [0 1];
                        isLeftTrial = choice(randperm(2,1));
                        % try
                        %     SB_Ratio = 0.5+this.Data_Object.AnalyzedData.TrialData.SB.Stimulus{:}(end);
                        %     Delta = this.Setting_Struct.Side_delta;
                        %     if SB_Ratio > 0.5+Delta % too many Left
                        %         isLeftTrial = 0;
                        %     elseif SB_Ratio < 0.5+Delta % too many Right
                        %         isLeftTrial = 1;
                        %     end
                        % catch
                        %     return
                        % end
                    case 2 %all left
                        isLeftTrial = 1;
                    case 3 %all right
                        isLeftTrial = 0;
                    case 4 % Keyboard / Manual Mode
                        text = 'Press L for Left, R for Right, ? for Random or S to correct Side-Bias:';
                        set(this.message_handle,'Text',text);
                        fprintf([text '\n'])
                        prompt = 'L, R, ? or S:   ';
                        keypress = 0;
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
                                    choice = [0 1];
                                    isLeftTrial = choice(randperm(2,1));
                                    keypress = 1;
                                case strcmp(currkey, 's') || strcmp(currkey, 'S')
                                    keypress = 1;
                                    [SB, ~, ~] = this.SideBias(this);
                                    if SB == 0 || this.i == 1
                                        text = 'Making random choice...';
                                        fprintf([text '\n'])
                                        set(this.message_handle,'Text',text);
                                        choice = [0 1];
                                        isLeftTrial = choice(randperm(2,1));
                                    else
                                        if SB>0
                                            isLeftTrial = 0;
                                            side = 'Right trial';
                                            bias = 'Left bias';
                                        else
                                            isLeftTrial = 1;
                                            side = 'Left trial';
                                            bias = 'Right bias';
                                        end
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
                    case 5 % Repeat Wrong basic mode
                        if this.Data_Object.current_data_struct.Score(end) == 0
                            return
                        else
                            choice = [0 1];
                            isLeftTrial = choice(randperm(2,1));
                        end
                end
            end
            % Check if Responses show side bias, correct that
            % if this.StimulusStruct.side == 1 & this.i>1 % Correction to Random setting only
            %     Resp_Ratio = 0.5+this.Data_Object.AnalyzedData.TrialData.SB.Responses{:}(end);
            %     Delta = this.Setting_Struct.Side_delta;
            %     if Resp_Ratio >= 0.5+Delta
            %         isLeftTrial = 0;
            %         this.Setting_Struct.Repeat_wrong = 1;
            %         this.app.Repeat_wrong.Value = 1;
            %     elseif Resp_Ratio <= 0.5+Delta
            %         isLeftTrial = 1;
            %         this.Setting_Struct.Repeat_wrong = 1;
            %         this.app.Repeat_wrong.Value = 1;
            %     else
            %         this.Setting_Struct.Repeat_wrong = 0;
            %         this.app.Repeat_wrong.Value = 0;
            %     end
            % end
            if isLeftTrial %Set properties
                this.current_side = 'left';
            else
                this.current_side = 'right';
            end
        end
        function WaitForInput(this)
            if this.i == 1
                % Stop acquisition and save those timestamps to the record
                this.a.Acquisition('End')
                this.timestamps_record{this.i} = this.Time.Log;
                pause(0.1)
            end
            this.TrialStartTime = 0;
            set(this.message_handle,'Text','Waiting for Trial initialization');
            this.t1 = datetime("now"); t2 = this.t1; %In case of crash
            this.a.DispOutput = false;
            this.a.Reset();
            % Display stimulus
            try % Clear timestamp log
                set(this.message_handle, 'Text', "Clearing timestamp log ...");
                this.Time.Reset();
                pause(0.1)
                this.Time.Log(end+1,1) = "Trial "+this.i+" "+this.current_side;
                this.Time.Log(end+1,1) = "Hold still";
            catch
            end
            try % Send Next File signal to ScanImage
                set(this.message_handle, 'Text', "Next file (ScanImage)...");
                this.a.Acquisition('Next');
            catch
            end
            pause(0.2); % The nextfile acquisition signal has a builtin 200 ms delay
            switch true
                case ~isempty(this.a) && this.Box.Input_type==6 %Wheel 2.0, wait for the mouse to hold the wheel still for the interval to start a new trial
                    if this.i ~=1
                        this.ReadyCue(true);
                        set(this.FLAx, 'Visible', true);
                        drawnow
                        timelimit = this.Setting_Struct.HoldStill;
                        tic;
                        while toc<=timelimit
                            this.message_handle.Text = "Keep the wheel still for "+num2str(round(timelimit - toc,1))+" seconds."; drawnow limitrate
                            if str2double(this.a.SerialRead) ~= 0
                                this.Flash(this.StimulusStruct, this.Box, findobj('Type', 'Polygon'), 'Wheel');
                                this.a.Reset();
                                tic;
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
                        t2 = toc;
                        this.ReadyCue(true);
                    end
                otherwise % Keyboard inputthis.Box.KeyboardInput==1
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
                            timerStart = clock;
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
                                if etime(clock, timerStart) > InterTMalInterv %End when mouse has not poked L or R for the interval
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
            if this.i ~= 1 && ~get(this.stop_handle,'Value')
                this.TrialStartTime = toc;
            elseif get(this.stop_handle, 'Value')
                this.TrialStartTime = 0;
            end
            if this.i == 1 %start the timer after the first trial has begun. Maybe this should be put somewhere else but I don't want the timer to start until the mouse begins the first trial so where else?
                this.start_time = datetime("now");
                this.Data_Object.GetStartTime;
            end
        end
        %wait loop while lever is read and open valves if correct
        % function WaitForInputAndGiveReward(this, options)
        %     arguments
        %         this
        %         options.Test logical = false
        %     end
        %
        %     keyboardInput = this.Box.KeyboardInput;
        %     inputType = this.Box.Input_type;
        %     this.ResponseTime = 0;
        %     this.WhatDecision = 'time out';
        %     this.DrinkTime = 0;
        %
        %     if get(this.stop_handle, 'Value')
        %         return
        %     end
        %     o = {this.fig.Children.Children}; % Hide ReadyCue and set background
        %     o(cellfun(@isempty, o)) = [];
        %     for obj = o
        %         x = obj{:};
        %         [x.Visible] = deal(1);
        %     end
        %     this.fig.Color = this.StimulusStruct.BackgroundColor;
        %     this.ReadyCue(0); drawnow
        %     %ignore input if set
        %     T1 = datetime("now");
        %     while this.Setting_Struct.Input_ignored & seconds(datetime("now")-T1)<=this.Setting_Struct.Pokes_ignored_time
        %         time = this.Setting_Struct.Pokes_ignored_time-seconds(datetime("now")-T1);
        %         txt = "Ignoring input for "+round(time,1)+" sec...";
        %         set(this.message_handle,'Text',txt)
        %         pause(0.01); drawnow;
        %     end
        %     this.Flash(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Type', 'Line'), 'NewStim'); % Make visible stimulus and flash if set
        %     set(this.message_handle,'Text',['Waiting for ',this.current_side,' choice...']);
        %     if ~options.Test
        %         this.Data_Object.addStimEvent(this.isLeftTrial); %Add the timestamp for the trial
        %     end
        %     this.Timestamp2p("State", true); %Turn on
        %     switch 1
        %         case ~keyboardInput && inputType == 6 %Wheel (new)
        %             [this.WhatDecision, this.ResponseTime] = this.readLeverLoopAnalogWheel();
        %         otherwise
        %             [this.WhatDecision, this.ResponseTime] = this.readKeyboardInput(this.stop_handle, this.message_handle, this.isLeftTrial);
        %     end
        %     if this.Setting_Struct.OnlyCorrect && contains({this.WhatDecision} , 'wrong', 'IgnoreCase', true)
        %         switch 1
        %             case ~keyboardInput && inputType == 6 %Wheel (new)
        %                 [this.WhatDecision, this.ResponseTime] = this.readLeverLoopAnalogWheel_OnlyCorrect(this);
        %             otherwise
        %                 [this.WhatDecision, this.ResponseTime] = this.readKeyboardInput(this.stop_handle, this.message_handle, this.isLeftTrial);
        %         end
        %     end
        %     this.Timestamp2p(); % Turn off
        %     pause(this.Setting_Struct.Input_Delay_Respond)
        %     try
        %         d = this.fig.Children.findobj('Tag', 'Distractor');
        %         [d.Color] = deal(this.StimulusStruct.DimColor);
        %     end
        %     switch true
        %         case contains({this.WhatDecision} , 'correct', 'IgnoreCase', true)
        %             set(this.message_handle,'Text','Giving Reward...');
        %             tic
        %             this.GiveRewardAndFlash();
        %             if ~this.Box.KeyboardInput
        %                 while abs(this.Box.encoder.readSpeed) > this.Setting_Struct.Hold_Still_Thresh %Pause while the mouse is standing there
        %                     pause(0.5);drawnow;
        %                 end
        %             end
        %             this.DrinkTime = toc;
        %             %Flash
        %             %this.Flash(this.StimulusStruct, this.Box,  findobj('Tag', 'Contour'),  this.WhatDecision);
        %             if this.StimulusStruct.PersistCorrectInterv > 0
        %                 thisInt = (this.StimulusStruct.PersistCorrectInterv);
        %             else
        %                 thisInt = 0;
        %             end
        %             set(this.message_handle, 'Text',['Persisting correct stimulus for ' num2str(thisInt)  ' (sec)...']); drawnow
        %             timerStart = clock;
        %             while 1
        %                 drawnow %unless drawnow is here the button statuses will not update...
        %                 if etime(clock, timerStart) > thisInt
        %                     break
        %                 end
        %                 if get(this.FF, 'Value')
        %                     set(this.message_handle, 'Text','Skipping persist interval...'); drawnow
        %                     break;
        %                 end
        %                 if get(this.stop_handle, 'Value')
        %                     set(this.message_handle, 'Text','Ending session...'); drawnow
        %                     break;
        %                 end
        %             end
        %             o = findobj(this.fig.Children);
        %             [o(:).Visible] = deal(0);
        %         case contains({this.WhatDecision} , 'wrong', 'IgnoreCase', true)
        %             set(this.message_handle,'Text',[this.WhatDecision,' - Penalty...']);
        %             if ~this.Box.KeyboardInput
        %                 while abs(this.Box.encoder.readSpeed) > this.Setting_Struct.Hold_Still_Thresh %Pause while the mouse is standing there
        %                     pause(0.5);drawnow;
        %                 end
        %             end
        %             %Flash
        %             this.Flash(this.StimulusStruct, this.Box,  findobj('Tag', 'Contour'), this.WhatDecision);
        %             if ~get(this.stop_handle, 'Value') && this.StimulusStruct.PersistIncorrect
        %                 set(this.message_handle,'Text','Persisting correct stimulus...');
        %                 this.UpdatePause(this.StimulusStruct.PersistIncorrectInterv)
        %             else
        %             end
        %             o = findobj(this.fig.Children);
        %             [o(:).Visible] = deal(0);
        %             this.fig.Color = 'k';
        %     end
        % end
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
            Lines = [findobj('Tag', 'Contour') ; findobj('Tag', 'Distractor')];
            drawnow
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
                this.FlashNew(this.StimulusStruct, this.Box,  Lines, 'NewStim')
                set(this.message_handle, 'Text', sprintf('Input ignored for %s sec...', num2str(this.Setting_Struct.Pokes_ignored_time)));
                pause(this.Setting_Struct.Pokes_ignored_time)
            end
            for rep = 1:this.Setting_Struct.Stimulus_RepFlashInitial
                this.FlashNew(this.StimulusStruct, this.Box, Lines, 'Correct_Confirmation')
            end
            % Enhanced decision-making loop based on inputType
            set(this.message_handle, 'Text', sprintf('Waiting for %s choice...', this.current_side));
            if ~keyboardInput && inputType == 6
                [this.WhatDecision, this.ResponseTime] = this.readLeverLoopAnalogWheel();
            else
                [this.WhatDecision, this.ResponseTime] = this.readKeyboardInput();
            end
            % Retry for only correct answers if necessary
            this.handleOnlyCorrectMode();
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
                [this.WhatDecision, this.ResponseTime] = this.readKeyboardInput();
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
        end
        function [WhatDecision, response_time] = readLeverLoopAnalogWheel(this)
            event = -1;
            delta = 0;
            this.wheelchoice = cell(1,1e6);
            this.wheelchoicetime = cell(1,1e6);
            timeout_value = this.Box.Timeout_after_time;
            if isempty(timeout_value)
                timeout_value = 0;
            end
            threshold = this.Setting_Struct.TurnMag;
            o = this.fig.findobj('Type', 'Axes');
            C = o(contains({o.Tag}, 'Correct'));
            W = o(contains({o.Tag}, 'Incorrect'));
            StimDistance = 0.3;
            axes = [this.RStimAx this.LStimAx];
            pos1i = axes(1).Position; % Axes1 (right) default position is [0.5 0 0.5 1]
            if numel(axes) > 1
                pos2i = axes(2).Position; % Axes2 (Left) default position is [0 0 0.5 1]
            end
            thresh = abs(pos1i(1)/2); % Should be 0.25 usually
            this.a.Reset();
            % pause(0.1)
            if this.Setting_Struct.RoundUp
                RoundUp = (this.Setting_Struct.RoundUpVal/100); %Default is 75 --> 0.75
                thresh = RoundUp*thresh;
            end
            if this.app.Animate_MimicTrial.Value
                this.SimulateTrial()
            end
            tic
            % ---------------- Stall / timers (IMPORTANT: no bare toc/tic) ----------------
            t1 = tic;
            tLoop  = tic;    % trial/response timer
            tStall = tic;    % "no-change" timer

            stallSec = 5;    % seconds without wheel change before flashing
            stallTol = 0;    % pulses tolerance; keep 0 if Rotary.ino outputs stable integers

            lastDist = NaN;
            didStallFlash = false;

            % Pre-cache handles once (avoid findobj inside tight loop)
            Lines = [this.fig.findobj('Tag','Contour'); this.fig.findobj('Tag','Distractor')];

            I = 0;
            while (timeout_value == 0 | toc(tLoop)<=timeout_value) && ~this.app.Animate_MimicTrial.Value% do NOT replace | with || or the expression is changed.
                dist = str2double(this.a.SerialRead);

                tNow = toc(tLoop);

                % --- Stall detection: reset stall timer on real movement
                if isnan(lastDist) || abs(dist - lastDist) > stallTol
                    lastDist = dist;
                    tStall = tic;
                    didStallFlash = false;
                elseif toc(tStall) >= stallSec % && ~didStallFlash
                    % Refresh Lines only when needed (in case graphics were recreated)
                    if isempty(Lines) || any(~isgraphics(Lines))
                        Lines = [this.fig.findobj('Tag','Contour'); this.fig.findobj('Tag','Distractor')];
                    end
                    this.Time.Log(end+1,1) = "Stall flash...";
                    for rep = 1:this.Setting_Struct.Stimulus_RepFlashInitial
                        this.FlashNew(this.StimulusStruct, this.Box, Lines, 'Correct_Confirmation')
                    end
                    this.Time.Log(end+1,1) = "Stall flash over";
                    didStallFlash = true;
                    % If you want repeated flashing every stallSec while stalled, uncomment:
                    tStall = tic;
                end

                delta = (dist/threshold)*StimDistance;  % A full revolution is about 4000 pulses 4400/360 = 12.22 pulses/degree 90 deg is ~1000 pulses
                if abs(delta)>thresh % Prevent stim from being pushed off screen
                    if sign(delta)>0
                        delta =  thresh;
                    elseif sign(delta)<0
                        delta = -thresh;
                    end
                end
                if this.isLeftTrial & delta < -thresh
                    delta = -thresh;
                elseif ~this.isLeftTrial & delta > thresh
                    delta = thresh;
                end
                I = I+1;
                this.wheelchoice{I} = delta;
                this.wheelchoicetime{I} = toc(tLoop);
                pos1 = pos1i + ([delta 0 0 0]);
                axes(1).Position = pos1;
                if numel(axes) > 1
                    pos2 = pos2i + ([delta 0 0 0]);
                    axes(2).Position = pos2;
                end
                %disp("Dist is "+dist+"; delta is "+delta); disp("R pos1 is is "+pos1(1)+"; L pos2 is "+pos2(1))
                drawnow  %limitrate nocallbacks
                
                if this.isLeftTrial & delta <= -thresh
                    event = 2;
                    break
                elseif ~this.isLeftTrial & delta >= thresh
                    event = 1;
                    break
                end
                if double(abs(delta)) >= double(thresh) %If a choice is made: !!! Add code to round up the correct choice but not accept an incorrect choice until it is fully made. Accept the correct choice early but wait for a full incorrect choice.
                    if sign(delta) > 0
                        event = 1;
                        break
                    elseif sign(delta) < 0
                        event = 2;
                        break
                    end
                end
                if get(this.Skip, 'Value')
                    set(this.Skip, 'Value', 0) %Turn the button off
                    break
                end
            end
            response_time = toc;
            this.Time.Log(end+1,1) = "Choice made";
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
            if contains(WhatDecision, 'wrong') && this.Setting_Struct.OnlyCorrect
                tic
                Old_response_time = response_time;
                delta = 0;
                stallSec_OC = stallSec;
                stallTol_OC = stallTol;

                tLoopOC  = tic;   % timeout applies to this phase (matches original intent)
                tStallOC = tic;

                lastDistOC = NaN;
                didStallFlashOC = false;

                while timeout_value == 0 | toc<timeout_value % do NOT replace | with || or the expression is changed.
                    dist = str2double(this.a.SerialRead);
                    tNowOC = toc(tLoopOC);

                    % --- Stall detection in OC phase
                    if isnan(lastDistOC) || abs(dist - lastDistOC) > stallTol_OC
                        lastDistOC = dist;
                        tStallOC = tic;
                        didStallFlashOC = false;
                    elseif toc(tStallOC) >= stallSec_OC % && ~didStallFlashOC
                        if isempty(Lines) || any(~isgraphics(Lines))
                            Lines = [findobj('Tag', 'Contour') ; findobj('Tag', 'Distractor')];
                        end
                        for rep = 1:this.Setting_Struct.Stimulus_RepFlashInitial
                            this.FlashNew(this.StimulusStruct, this.Box, Lines, 'Correct_Confirmation')
                        end
                        tStallOC = tic;
                        didStallFlashOC = true;
                    end
                    delta = (dist/threshold)*StimDistance; % A full revolution is about 4000 pulses 4400/360 = 12.22 pulses/degree 90 deg is ~1000 pulses
                    if abs(delta)>thresh % Prevent stim from being pushed off screen
                        if sign(delta)>0
                            delta =  thresh;
                        elseif sign(delta)<0
                            delta = -thresh;
                        end
                    end
                    I = I+1;
                    this.wheelchoice{I} = delta;
                    this.wheelchoicetime{I} = toc;
                    pos1 = pos1i + ([delta 0 0 0]);
                    axes(1).Position = pos1;
                    if numel(axes) > 1
                        pos2 = pos2i + ([delta 0 0 0]);
                        axes(2).Position = pos2;
                    end
                    %disp("Dist is "+dist+"; delta is "+delta); disp("R pos1 is is "+pos1(1)+"; L pos2 is "+pos2(1))
                    drawnow
                    if this.isLeftTrial & pos2(1)<=-0.25
                        this.a.Reset()
                    elseif ~this.isLeftTrial & pos1(1) >= 0.75
                        this.a.Reset()
                    end
                    if this.isLeftTrial & pos2(1) >= 0.24
                        event = 1;
                        break
                    elseif ~this.isLeftTrial & pos1(1) <= 0.26
                        event = 2;
                        break
                    end
                    % if double(abs(delta)) >= double(thresh) %If a choice is made: !!! Add code to round up the correct choice but not accept an incorrect choice until it is fully made. Accept the correct choice early but wait for a full incorrect choice.
                    %     if sign(delta) > 0
                    %         event = 1;
                    %         break
                    %     elseif sign(delta) < 0
                    %         event = 2;
                    %         break
                    %     end
                    % end
                    if get(this.Skip, 'Value')
                        set(this.Skip, 'Value', 0) %Turn the button off
                        break
                    end
                end
                response_time = Old_response_time + toc(tLoopOC);
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
            this.wheelchoice(cellfun('isempty',this.wheelchoice)) = [];
            this.wheelchoice = cell2mat(this.wheelchoice);
            this.wheelchoicetime(cellfun('isempty',this.wheelchoicetime)) = [];
            this.wheelchoicetime = cell2mat(this.wheelchoicetime);
        end
        function [WhatDecision, response_time] = readLeverLoopAnalogWheel_OnlyCorrect(this)
% Unused and has been merged into the main function: thtis.readLeverLoopAnalogWheel()
            event = -1;
            delta = 0;
            %this.wheelchoice = cell(1,1e6);
            timeout_value = this.Box.Timeout_after_time;
            threshold = this.Setting_Struct.TurnMag;
            o = this.fig.findobj('Type', 'Axes');
            C = o(contains({o.Tag}, 'Correct'));
            W = o(contains({o.Tag}, 'Incorrect'));
            StimDistance = 0.3;
            axes = [this.RStimAx this.LStimAx];
            pos1i = [0.5 0 0.5 1];% axes(1).Position; % Axes1 (right) default position is [0.5 0 0.5 1]
            if numel(axes) > 1
                pos2i = [0 0 0.5 1]; % axes(2).Position; % Axes2 (Left) default position is [0 0 0.5 1]
            end
            thresh = abs(0.5/2);
            if this.Setting_Struct.RoundUp
                RoundUp = (this.Setting_Struct.RoundUpVal/100); %Default is 75 --> 0.75
                thresh = RoundUp*thresh;
            end
            % if this.app.Animate_MimicTrial.Value
            %     this.SimulateTrial()
            % end
            I = 0;
            tic
            while timeout_value == 0 | toc<timeout_value % do NOT replace | with || or the expression is changed.
                dist = str2double(this.a.SerialRead);
                delta = (dist/threshold)*StimDistance; % A full revolution is about 4000 pulses 4400/360 = 12.22 pulses/degree 90 deg is ~1000 pulses
                if abs(delta)>thresh % Prevent stim from being pushed off screen
                    if sign(delta)>0
                        delta =  thresh;
                    elseif sign(delta)<0
                        delta = -thresh;
                    end
                end
                % if this.isLeftTrial & delta < -thresh
                %     delta = -thresh;
                % elseif ~this.isLeftTrial & delta > thresh
                %     delta = thresh;
                % end
                I = I+1;
                %this.wheelchoice{I} = delta;
                %this.wheelchoicetime{I} = toc;
                pos1 = pos1i + ([delta 0 0 0]);
                axes(1).Position = pos1;
                if numel(axes) > 1
                    pos2 = pos2i + ([delta 0 0 0]);
                    axes(2).Position = pos2;
                end
                %disp("Dist is "+dist+"; delta is "+delta); disp("R pos1 is is "+pos1(1)+"; L pos2 is "+pos2(1))
                drawnow
                if this.isLeftTrial & pos2(1)<=-0.25
                    this.a.Reset()
                elseif ~this.isLeftTrial & pos1(1) >= 0.75
                    this.a.Reset()
                end
                if this.isLeftTrial & pos2(1) >= 0.24
                    event = 1;
                    break
                elseif ~this.isLeftTrial & pos1(1) <= 0.26
                    event = 2;
                    break
                end
                % if double(abs(delta)) >= double(thresh) %If a choice is made: !!! Add code to round up the correct choice but not accept an incorrect choice until it is fully made. Accept the correct choice early but wait for a full incorrect choice.
                %     if sign(delta) > 0
                %         event = 1;
                %         break
                %     elseif sign(delta) < 0
                %         event = 2;
                %         break
                %     end
                % end
                if get(this.Skip, 'Value')
                    set(this.Skip, 'Value', 0) %Turn the button off
                    break
                end
            end
            %this.wheelchoice(cellfun('isempty',this.wheelchoice)) = [];
            %this.wheelchoice = cell2mat(this.wheelchoice);
            %this.wheelchoicetime(cellfun('isempty',this.wheelchoicetime)) = [];
            %this.wheelchoicetime = cell2mat(this.wheelchoicetime);
            response_time = toc;
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
        end
        function FlashNew(this, Stim, Box, Lines, whatdecision, OneWay)
            arguments
                this
                Stim % from Setting structure
                Box
                Lines = findobj('Tag', 'Contour')
                whatdecision = "time out"
                OneWay logical = false
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
                this.BasicFlash("Lines",Lines, "NewColor", dark_color, "steps", Steps)
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
                STEPS = 1:1:steps;
            else
                STEPS = [1:1:steps steps-1:-1:1];
            end
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
            if contains(this.WhatDecision, 'correct', 'IgnoreCase', true)
                PulseNum = this.Box.RightPulse;
            elseif contains(this.WhatDecision, 'OC', 'IgnoreCase', true)
                PulseNum = this.Box.OCPulse;
            else
                return
            end
            this.Time.Log(end+1,1) = "Reward";
            % Give first drop only once
            this.a.GiveReward();
            % then flash
            lines = findobj(this.fig.Children, 'Tag', 'Contour');
            this.FlashNew(this.StimulusStruct, this.Box,  lines, "Correct_Confirmation");
            for i = 2:PulseNum
                pause(this.Box.SecBwPulse)
                this.Time.Log(end+1,1) = "Reward";
                this.a.GiveReward();
                this.FlashNew(this.StimulusStruct, this.Box,  lines, "Correct_Confirmation");
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
            this.Time.Log(end+1,1) = "Stim off";
            this.ReadyCue(true)
            %Wait for interval
            this.UpdatePause(interval_time)
            this.updateMessageBox();
            if this.Temp_Active
                this.Setting_Struct = this.Temp_Old_Settings;
            end
            this.a.Acquisition('End')
            this.timestamps_record{(this.i+1)} = this.Time.Log; % +1 Offset to account for the frames that are recorded before trial 1 begins (setup period)
            if get(this.stop_handle, 'Value')
                return
            end
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
            if ispc
                saveasname = join([D Sub Str stim input],'_');
                savefolder = fullfile(cell2mat(this.Data_Object.filedir));
            elseif isunix
                saveasname = join([D Sub Str stim input],'_');
                savefolder = fullfile([cell2mat(this.Data_Object.filedir), filesep]);
            end
            set(this.message_handle,'Text', 'Saving data as: '+saveasname+'.mat');
            Settings = [this.Setting_Struct cell2mat(this.Old_Setting_Struct)];
            Notes = this.GuiHandles.NotesText.String;
            if options.Activity == "Training"
                [newData] = this.Data_Object.current_data_struct;
                names = fieldnames(newData);
                for n = names(structfun(@isrow, newData) & structfun(@length, newData) > 1)' %Make sure everything is saved as a column
                    newData.(n{:}) = newData.(n{:})';
                end
                FullTrials = numel(newData.TimeStamp);
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
                    this.timestamps_record(any(cellfun(@isempty, this.timestamps_record)'),:) = [];
                    newData.TtimestampRecord = this.timestamps_record;

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
                f = figure("MenuBar","none","Visible","off");
                copyobj(this.graphFig.Children, f)
                f.Children.Title.String = string(this.Data_Object.Inp)+" "+cell2mat(this.Data_Object.Sub);
                try
                    try
                        save(savefolder+saveasname+".mat", 'Settings', 'newData', 'Notes')
                        this.saveFigure(f, savefolder, saveasname)
                        dispstring = 'Data saved as: '+saveasname;
                        fprintf(dispstring+'\n');
                        set(this.message_handle,'Text',dispstring);
                    catch err
                        this.unwrapError(err)
                        [file,path] = uiputfile(pwd , 'Choose folder to save training data' , saveasname);
                        save([path file],  'Settings', 'newData')
                        this.saveFigure(this.graphFig, savefolder, saveasname)
                    end
                catch err
                    save(pwd+saveasname+".mat", 'Settings', 'newData', 'Notes')
                    this.unwrapError(err)
                end
                % f.MenuBar = 'figure';
                % f.Visible = 1;
                close(f)
            elseif options.Activity == "Animate"
                Position_Record = options.PosRecord;
                save(savefolder+saveasname+".mat", 'Settings', 'Position_Record', 'Notes')
                dispstring = 'Data saved as: '+saveasname;
                fprintf(dispstring+'\n');
                set(this.message_handle,'Text',dispstring);
            end
        end
        function cleanUP(this)
            % Send Stop Acquisition signal to ScanImage
            try
                set(this.message_handle, 'Text', "Stopping acquisition (ScanImage)...");
                this.a.Acquisition('End');
            catch
            end
            %switch on all buttons
            this.toggleButtonsOnOff(this.Buttons,1);
            this.stop_handle.Value = 0;%Turn off Stop button
            %close stimulus if still open
            delete(findobj("Type", "figure", "Name", "Stimulus"))
            disp_string = ['Stopped training Mouse ',num2str(this.Setting_Struct.Subject), ' at ',string(datetime("now"))];
            disp(disp_string);
            disp('- - - - -');
        end
        function ReadyCue(this, isVis)
            switch 1
                case islogical(isVis)
                    set(this.ReadyCueAx, 'Visible', isVis)
                case isVis == "Create"
                    RCAx = axes('Parent', this.fig, ...
                        'Position', [0 0 1 1], ...
                        'Color', 'k', ...
                        'Tag', 'ReadyCue', ...
                        'XColor', 'none', ...
                        'YColor', 'none', ...
                        'YTick', [], ...
                        'XTick', []);
                    this.fig.Children = [this.fig.Children([2 3 1 4 5])];
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
                    this.Setting_Struct.Starting_opacity, "AnimateMode", true, "StimType", options.StimType);
            else
                [~,~] = this.Stimulus_Object.DisplayOnScreen(this.PickSideForCorrect(0, 0), ...
                    this.Setting_Struct.Starting_opacity);
            end
            this.fig = this.Stimulus_Object.fig;
            [this.fig.findobj('Tag','Spotlight').Visible] = deal(1);
            toc
            drawnow
            if contains(options.StimType, "-Line")
                this.app.Animate_XPosition.Value = 0.5;
                this.app.Animate_YPosition.Value = 0.5;
                %this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Type', 'ConstantLine'), "NewStim")
            elseif contains(options.StimType, "Dot")
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
            this.SetupBeforeLoop();
            STYLE = this.app.Animate_Style.Value;
            if options.Mode == "Show"
%Remove everything that isn't the spotlights or the finish line
                this.TestStimulus("AnimateMode",true, "StimType", STYLE);
            end
            if options.Mode == "Go"
                this.TestStimulus("AnimateMode",true, "StimType", STYLE);
                this.MoveStimuli();
                return
            end
            if options.Mode == "Rec"
                this.RecordStimuli();
                return
            end
            if options.Mode == "XMove"
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
                if contains(this.app.Animate_Style.Value, "-Line")
                    this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Type', 'ConstantLine'), "NewStim")
                elseif contains(this.app.Animate_Style.Value, "Dot")
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
            switch this.app.Animate_Style.Value
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
            if this.app.Animate_Style.Value ~= "Dot"
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
                            this.a.GiveReward
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
            elseif this.app.Animate_Style.Value == "Dot"
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
                            this.a.GiveReward
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
                    this.a.GiveReward
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
    %STATIC FUNCTIONS====
    methods(Static = true)
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
        function [WhatDecision, response_time] = readKeyboardInput(stop_handle, message_handle, isLeftTrial)
            text = 'Respond: Press L for Left, R for Right, C or M for Middle:'; set(message_handle,'Text',text); fprintf([text '\n']); drawnow
            prompt = 'L, R, or M/C:   ';
            keypress = 0; t1 = datetime("now");
            while keypress==0
                pause(0.01); drawnow;
                currkey = input(prompt,"s");
                response_time = seconds(datetime("now") - t1);
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
                elseif Lines(1).Type == "polygon" %Wheel
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
