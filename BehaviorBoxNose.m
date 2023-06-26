classdef BehaviorBoxNose < handle
    %BehaviorBox Super class
    % WBS 6 . 26 . 2023
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
        ReadyCueStruct = struct();
        StimulusStruct = struct();
        %Structures of variables:
        Stimulus_Object = struct();
        Data_Object = struct();
        Setting_Struct = struct();
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
        a; %The arduino
        %Variables for running training loop:
        i=0; %Trial Number
        trial; %All trial data that is added to data structure
        counter_for_alternate = 0;
        current_side;
        Level;
        PossibleLevels;
        RampCount=0;
        RampCorrectCount=0;
        RampWhichLevel;
        RampMax;
        RampMin;
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
    end
    methods
        %constructor
        function this = BehaviorBoxNose(GUI_handles, app)
            this.app = app;
            this.GuiHandles = GUI_handles;
            %dbstop if error
            try
                this.stop_handle.Value = 0;
                this.getGUI();
            catch err
                this.unwrapError(err)
            end
        end
        %INTERFACE====
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
        %MEMBER FUNCTIONS====
        %Run the loop
        function DoLoop(this)
            %=====MAIN LOOP===========================
            this.SetupBeforeLoop();
            %LOOP==== %run loop
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
                    pause(0.1); drawnow;
                    errorc = 0;
                catch err
                    this.unwrapError(err)
                    errorc = errorc + 1;
                end
            end %END loop
            %=====END LOOP============================
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
            this.stop_handle = this.app.stop; %Buttons
            this.Skip = this.app.skip;
            this.FF = this.app.ff;
            this.Pause = this.app.pause;
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
            props(props == "TextArea2") = [];
            skiptypes = {'buttongroup', 'figure', 'label', 'panel', 'annotationpane', 'axes', 'tab', 'uigridlayout'};
            types = GetType(this.app, props); %cellfun(@(x) this.app.(x).Type, props, 'UniformOutput', false); %Get their types
            props = props(~contains(types, skiptypes, "IgnoreCase",true));
            types = GetType(this.app, props);
            %Make Button structure
            buttons = props(contains(types, {'button'}));
            bTags = GetTag(this.app, buttons);
            this.Buttons = cell2struct(cellfun(@(x)(this.app.(x)), buttons, 'UniformOutput',false), bTags);
            props = props(~contains(types, {'button'})); types = GetType(this.app, props);
            this.appProps = props;
            this.appPropsTypes = types;
            Dropdowns = props(contains(types, {'dropdown'}));
            dTags = GetTag(this.app, Dropdowns);
            DropVals = cellfun(@(x)find(matches(this.app.(x).Items, this.app.(x).Value)), Dropdowns, 'UniformOutput',false);
            this.dropdowns = cell2struct(DropVals, dTags);
            props = props(~contains(types, {'dropdown'})); types = GetType(this.app, props);
            tempVal = cell(size(props));
            CIdx = contains(types, {'check'});
            Checkboxes = props(CIdx);
            cVals = cellfun(@(x)logical(this.app.(x).Value), Checkboxes, 'UniformOutput',false);
            tempVal(CIdx) = cVals;
            pTags = GetTag(this.app, props);
            tempVal(~CIdx) = cellfun(@(x)str2double(this.app.(x).Value), props(~CIdx), 'UniformOutput',false);
            ReDo = cellfun(@isnan, tempVal, 'UniformOutput',true);
            tempVal(ReDo) = cellfun(@(x)(this.app.(x).Value), props(ReDo), 'UniformOutput',false);
            tempSetting_Struct = cell2struct(tempVal, pTags);
            tempSetting_Struct = appendStruct(tempSetting_Struct, this.dropdowns);
            this.makeTrialStructures(tempSetting_Struct)
            this.Setting_Struct = tempSetting_Struct;
            %Get the settings label from the setting structure, to label the data.
            this.SetIdx = 1;
            [this.SetStr, this.Include] = this.structureSettings(this.Setting_Struct);
            function Types = GetType(App, Props)
                Types = cellfun(@(x) App.(x).Type, Props, 'UniformOutput', false);
            end
            function Types = GetTag(App, Props)
                Types = cellfun(@(x) App.(x).Tag, Props, 'UniformOutput', false);
            end
        end
        function makeTrialStructures(this, Settings)
            this.StimulusStruct = appendStruct(this.StimulusStruct, PullOut(Settings, 'Stimulus_'));
            this.Box = appendStruct(this.Box, PullOut(Settings, 'Box_'));
            this.ReadyCueStruct = appendStruct(this.ReadyCueStruct, PullOut(Settings, 'ReadyCue_'));
            function OUT = PullOut(IN, chr)
                Out = struct();
                names = fieldnames(IN);
                inter = names(contains(names, chr));
                vals = cellfun(@(x)IN.(x), inter, "UniformOutput",false);
                CIDX = contains(inter, "color", IgnoreCase=true);
                vals(CIDX) = cellfun(@(x)repmat(x,1,3), vals(CIDX), "UniformOutput",false);
                OUT = cell2struct(vals, erase(inter, chr));
            end
        end
        %set hardware (arduino) parameters
        function ConfigureArduino(this, options)
            arguments
                this
                options.Rebuild logical = false
            end
            tic
            % https://docs.arduino.cc/learn/microcontrollers/digital-pins
            if this.Setting_Struct.Box_Input_type == 8 %Skip all this if keyboard mode
                return
            end
            comsnum = "COM"+this.app.edit22.Value;
            this.Box.use_ball = 0; %All these are automatically off
            this.Box.use_wheel = 0;
            this.Box.ardunioReadDigital = 0;
            this.Box.KeyboardInput = 0;
            this.Box.readHigh = 0; % When unselected, NosePoke reads HIGH, when selected it reads LOW
            %set which lever is what and what the input setup is from
            this.Box.ResetPin        = 'D4';
            this.Box.TriggerPin      = 'D5';
            switch this.Setting_Struct.Box_Input_type
                case 3 %Three Pokes
                    if options.Rebuild
                        try
                            this.a = [];
                        end
                        this.a = arduino(comsnum,'Uno','Libraries',{}, 'ForceBuildOn',true);
                    else
                        this.a = arduino(comsnum,'Uno','Libraries',{});
                    end
                    configurePin(this.a, "D2", "Unset");
                    configurePin(this.a, "D3", "Unset");
                    configurePin(this.a, "D7", "Unset");
                    this.Box.ardunioReadDigital = 1;
                    this.Box.readHigh = 0;
                    if this.Box.readHigh %Voltage goes HIGH on choice
                        configurePin(this.a, "D2", "DigitalInput");
                        configurePin(this.a, "D3", "DigitalInput");
                        configurePin(this.a, "D7", "DigitalInput");
                    else %Voltage goes LOW on choice
                        configurePin(this.a, "D2", "Pullup");
                        configurePin(this.a, "D3", "Pullup");
                        configurePin(this.a, "D7", "Pullup");
                    end
                    %Set up box structure
                    this.Box.Left = 'D2';
                    this.Box.Middle = 'D3';
                    this.Box.Right = 'D7';
                    this.Box.ValveL = 'D6';
                    this.Box.ValveR = 'D8';
                    this.Box.AirPuff  = 'D11';
                    this.Box.readPin = @(PIN)this.a.readDigitalPin(PIN)==this.Box.readHigh;
                    this.Box.readL = @(x)this.Box.readPin(this.Box.Left);
                    this.Box.readR = @(x)this.Box.readPin(this.Box.Right);
                    this.Box.readM = @(x)this.Box.readPin(this.Box.Middle);
                case 5 %Lick ports
                    this.Box.ardunioReadDigital = 1;
                case 6 %Rotating Wheel
                    if options.Rebuild
                        try
                            this.a = [];
                        end
                        this.a = arduino(comsnum,'Uno','Libraries',{'RotaryEncoder'}, 'ForceBuildOn',true);
                    else
                        this.a = arduino(comsnum,'Uno','Libraries',{'RotaryEncoder'});
                    end
                    this.Box.encoder = rotaryEncoder(this.a,'D2','D3', 1024);
                    this.Box.Reward =  'D6';
                    this.Box.use_wheel = 1;
                case 8 %Keyboard, used if no arduino connected
                    this.Box.KeyboardInput = 1;
                    this.Box.readHigh = 1;
                    return
            end
            configurePin(this.a, "D4", "Unset"); %Reset pin
            configurePin(this.a, "D5", "Unset"); %Trigger pin
            configurePin(this.a, "D6", "Unset");
            configurePin(this.a, "D8", "Unset");
            configurePin(this.a, "D4", "DigitalOutput"); %Reset pin
            configurePin(this.a, "D5", "DigitalInput"); %Trigger pin
            configurePin(this.a, "D6", "DigitalOutput");
            configurePin(this.a, "D8", "DigitalOutput");
            toc
        end
        %Prepare the window and stimulus
        function SetupBeforeLoop(this)
            this.GuiHandles.MsgBox.String = "";
            this.GuiHandles.NotesText.String = "";
            this.GuiHandles.NotesText.String = sprintf(string(datetime("today"))+" Behavior Notes:\n");
            this.setGuiNumbers(this.GUI_numbers); %update gui
            try
                this.Data_Object = BehaviorBoxData( ...
                    Inv=this.app.Inv.Value, ...
                    Inp=this.app.Box_Input_type.Value, ...
                    Str=this.app.Strain.Value, ...
                    Sub={this.app.Subject.Value}, ...
                    find=1); % Set up data storage object
            end
            try
                diaryname = join([this.Data_Object.filedir "BBTrialOutput"+this.Data_Object.date+".txt"], filesep);
            catch
                diaryname = join([this.Data_Object.Sub "BBTrialOutput"+this.Data_Object.date+".txt"], filesep);
            end
            this.textdiary = diaryname;
            diary(diaryname)
            this.Data_Object.TrainingNow = 1;
            %create stimulus depending on input device
            [this.Stimulus_Object] = BehaviorBoxVisualStimulus(this.StimulusStruct); drawnow;
            this.Data_Object.StimType = erase(this.app.Stimulus_type.Value, ' ');
            clo(this.app.PerformanceTab);
            this.graphFig = this.app.PerformanceTab;
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
                    pause(0.1); drawnow;
                    if this.Box.readPin(this.Setting_Struct.TriggerPin) || get(this.stop_handle, 'Value') %check if abort button is pressed
                        break %abort
                    end
                end
            end
            [this.fig, this.LStimAx, this.RStimAx, this.FLAx, ~] = this.Stimulus_Object.setUpFigure();
            this.ReadyCue(1)
            this.ReadyCueStruct.Ax = this.ReadyCueAx;
            this.StimulusStruct.ReadyCue = this.ReadyCueStruct;
            if this.Box.Input_type == 6
                this.fig.Children = [this.fig.Children([2 3 1 4 5])];
                this.Box.use_wheel = 1;
            end
            this.toggleButtonsOnOff(this.Buttons,0); % Turn off all buttons
            fprintf("- - - - -\n");
            txt = "Start trial Mouse "+this.Setting_Struct.Subject+" at "+string(datetime('now'));
            set(this.message_handle,'Text',txt);
            fprintf(txt+"\n");
            this.i = 0;
            this.timeout_counter = 0;
            if this.Setting_Struct.Ramp
                this.RampCount = 1;
                this.RampCorrectCount = this.Setting_Struct.RampNum;
                this.RampMax = this.Setting_Struct.RampMaxLevel;
                this.RampMin = this.Setting_Struct.RampMinLevel;
                this.Level = this.Setting_Struct.RampMinLevel;
                this.RampWhichLevel = 1;
                this.app.DistractorsSpinner.Value = this.Level;
                if this.RampMax-this.RampMin <=4
                    this.PossibleLevels = this.RampMin:1:this.RampMax;
                elseif this.RampMax-this.RampMin <=5
                    this.PossibleLevels = unique([1 this.RampMin:2:this.RampMax this.RampMax]);
                elseif this.RampMax-this.RampMin <=6
                    this.PossibleLevels = unique([1 this.RampMin:3:this.RampMax this.RampMax]);
                end
            end
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
            %Update GUI window numbers
            this.updateGUIbeforeIteration();
            %Pick next reward drop size, if variable
            if this.Box.Variable_pulses
                Pulse_Min = this.Setting_Struct.Pulse_Min;
                Pulse_Max = this.Setting_Struct.PulseMax;
                range = Pulse_Min:1:Pulse_Max;
                this.RewardPulses = range(randperm(numel(range), 1));
            end
            try
                LastScore = this.Data_Object.current_data_struct.CodedChoice(end);
            catch
                LastScore = 1;
            end
            if this.Setting_Struct.Repeat_wrong==1 && any(LastScore == [3 4]) %If repeat wrong and they got it wrong
                if isvalid(this.fig)
                    %this.StimHistory(this.i,:) = this.StimHistory(this.i-1,:); %Use the same stimulus from last time
                    [this.StimHistory{this.i,1},this.StimHistory{this.i,2}] = this.Stimulus_Object.DisplayOnScreen(this.isLeftTrial, this.Level); %Plot new stimulus as hidden objects, record positions and angles of the segments
                else
                    [this.fig, this.LStimAx, this.RStimAx, this.FLAx] = this.Stimulus_Object.setUpFigure();
                    %this.StimHistory(this.i,:) = this.StimHistory(this.i-1,:); %Use the same stimulus from last time
                    [this.StimHistory{this.i,1},this.StimHistory{this.i,2}] = this.Stimulus_Object.DisplayOnScreen(this.isLeftTrial, this.Level); %Plot new stimulus as hidden objects, record positions and angles of the segments
                end
            else %If correct or no repeat wrong
                this.isLeftTrial = this.PickSideForCorrect(this.isLeftTrial, this.SideBias); %Pick if isLeftTrial
                %Pick next difficulty level, if variable
                if this.Setting_Struct.Ramp && this.Setting_Struct.EasyTrials
                    [this.Level] = this.PickDifficultyLevel();
                end
                if isvalid(this.fig)
                    [this.StimHistory{this.i,1},this.StimHistory{this.i,2}] = this.Stimulus_Object.DisplayOnScreen(this.isLeftTrial, this.Level); %Plot new stimulus as hidden objects, record positions and angles of the segments
                else
                    [this.fig, this.LStimAx, this.RStimAx, this.FLAx] = this.Stimulus_Object.setUpFigure();
                    [this.StimHistory{this.i,1},this.StimHistory{this.i,2}] = this.Stimulus_Object.DisplayOnScreen(this.isLeftTrial, this.Level); %Plot new stimulus as hidden objects, record positions and angles of the segments
                end
            end
            %Update GUI window numbers
            this.updateGUIbeforeIteration(); %Update again, in case the level changed
            [this.fig.Children.findobj('Type','Line').Visible] = deal(0);
            drawnow
            this.ReadyCue(1)
            %this.ReadyCueAx.Children.MarkerFaceColor = this.StimulusStruct.DimColor;
        end
        %update GUI numbers before each trial
        function updateGUIbeforeIteration(this)
            %add local variables to Gui Numbers
            this.GUI_numbers.trial_no = this.i;
            this.GUI_numbers.choices = this.i- this.timeout_counter;
            this.GUI_numbers.difficulty = this.Level;
            try %Will fail before first trial is begun bc this.start_time is empty
                this.GUI_numbers.time = [num2str(floor(etime(clock, this.start_time)/60)) ' min ' num2str(round((etime(clock, this.start_time)/60- floor(etime(clock, this.start_time)/60))*60)) ' sec'];
            catch
            end
            %update Gui window
            this.setGuiNumbers(this.GUI_numbers);
        end
        %Pick difficulty level if variable:
        function [current_difficulty] = PickDifficultyLevel(this)
            if this.Setting_Struct.Ramp
                if this.i == 1
                    current_difficulty = this.Setting_Struct.RampMinLevel;
                    return
                end
                try
                    LastScore = this.Data_Object.current_data_struct.CodedChoice(end);
                catch
                    LastScore = 0;
                end
                if any(LastScore == [1 2])
                    this.RampCount = this.RampCount+1;
                end
                if this.RampCount > this.RampCorrectCount
                    this.RampWhichLevel = this.RampWhichLevel+1;
                    this.RampCount = 1;
                    if this.RampWhichLevel > numel(this.PossibleLevels)
                        this.Setting_Struct.Ramp=0;
                        this.app.RampCheckBox.Value=0;
                    end
                end
                current_difficulty = this.PossibleLevels(this.RampWhichLevel);
                return
            end
            try
                initLev = this.Setting_Struct.Starting_opacity;
                list = split(split(this.Setting_Struct.prob_list, ';'), ',');
                if size(list,2) == 1
                    list = list';
                end
            %Move this to a new fcns and store it in this.PossibleLevels
                LPlist = cellfun(@str2num, list, 'UniformOutput', false);
                LPlist(:,1) = cellfun(@(x) x*100, LPlist(:,1), "UniformOutput", false);
                PossibleLvls = [];
                for l = LPlist'
                    Lv = l{2};
                    p = ceil(l{1}/numel(Lv));
                    for L = Lv
                        PossibleLvls = [PossibleLvls repmat(L, 1, p)];
                    end
                end
                CurrentLvLProb = 100 - sum([LPlist{:,1}]); %Probability for current Level
                PossibleLvls = [PossibleLvls repmat(initLev, 1, CurrentLvLProb)];
                WhichLevel = randperm(numel(PossibleLvls), 1);
                current_difficulty = PossibleLvls(WhichLevel);
            catch
                current_difficulty = this.Setting_Struct.Starting_opacity;
                return
            end
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
            this.Setting_Struct = tempSetting_Struct;
            this.SetIdx = this.SetIdx + 1;
            this.SetUpdate{end+1} = this.i;
            [this.SetStr(end+1), this.Include(end+1)] = this.structureSettings(tempSetting_Struct);
            this.Stimulus_Object = this.Stimulus_Object.updateProps(this.StimulusStruct);
            [this.Level] = this.Setting_Struct.Starting_opacity;
            if this.Setting_Struct.Ramp
                this.RampCount = 1;
                this.RampCorrectCount = this.Setting_Struct.RampNum;
                this.RampMax = this.Setting_Struct.RampMaxLevel;
                this.RampMin = this.Setting_Struct.RampMinLevel;
                this.Level = this.Setting_Struct.RampMinLevel;
                this.RampWhichLevel = 1;
                this.app.DistractorsSpinner.Value = this.Level;
                if this.RampMax-this.RampMin <=4
                    this.PossibleLevels = this.RampMin:1:this.RampMax;
                elseif this.RampMax-this.RampMin <=5
                    this.PossibleLevels = unique([1 this.RampMin:2:this.RampMax this.RampMax]);
                elseif this.RampMax-this.RampMin <=6
                    this.PossibleLevels = unique([1 this.RampMin:3:this.RampMax this.RampMax]);
                end
            end
        end
        %Choose if Left or Right will be correct
        function isLeftTrial = PickSideForCorrect(this, isLeftTrial, SB)
            % ATTENTION!!!
            % Do NOT double the & and | to && and || just because the Matlab error
            % warning says it will be "faster." Doubling them will change the logical
            % meaning of the phrase and will ruin how repeat wrong functions. Keeping
            % the boolean operators singular (& and | as opposed to && and ||) prevents
            % short circuiting and keeps the code from erroneourly engaging repeat
            % wrong. Use debug mode to check the outcomes of all of these commands to
            % ensure that repeat wrong can be disabled. WBS 3/11/2022
            %Also do NOT change the order of the if statements.
            if all(this.StimulusStruct.side ~= [2 3 8]) && this.i == 1 %%If not left/right only and first trial, no data structure exists yet.
                if this.StimulusStruct.side == 7 %Pseudo random
                    this.Setting_Struct.Repeat_wrong = 1;
                elseif this.StimulusStruct.side == 5 %Alternate random
                    range = this.Setting_Struct.MinRandAlt:this.Setting_Struct.MaxRandAlt;
                    this.Setting_Struct.Change_alternate = range(randperm(numel(range),1));
                    this.counter_for_alternate = 0;
                end
                choice = [0 1];
                isLeftTrial = choice(randperm(2,1));
            else
                switch this.StimulusStruct.side
                    case 1 %Random
                        choice = [0 1];
                        isLeftTrial = choice(randperm(2,1));
                    case 2 %all left
                        isLeftTrial = 1;
                    case 3 %all right
                        isLeftTrial = 0;
                    case 4 %alternate repeat
                        if this.GuiHandles.popupmenu5.Value == 7 %If Smart Random is active:
                            if this.counter_for_alternate == -1 %When starting Smart Random Alternate, counter is -1.
                                this.counter_for_alternate = 0;
                            elseif any(LastScore == [3 4])
                            else %To deactivate alternate random the mouse must get some number correct on the opposite side
                                this.counter_for_alternate = this.counter_for_alternate+1;
                                if this.counter_for_alternate >= this.Setting_Struct.Change_alternate %When the mouse has gotten enough correct trials in a row, check SB against threshold and switch sides.
                                    if abs(SB) < this.Setting_Struct.SideBiasInterval %If they have improved their SB ratio, turn off alt repeat:
                                        this.Old_Setting_Struct{end+1} = this.Setting_Struct; %Put this BEFORE the setting changes
                                        this.SetUpdate{end+1} = this.i; %This current trial is now random
                                        this.StimulusStruct.side = 7; %Switchback into smart random mode
                                        this.Setting_Struct.Repeat_wrong = 0; %And turn off repeat wrong
                                        choice = [0 1];
                                        isLeftTrial = choice(randperm(2,1));
                                        text = ['Side bias reduced, disabling alternate repeat. Current SB is ' num2str(SB) '.'];
                                        disp(text)
                                        set(this.message_handle,'Text',text);
                                    else
                                        isLeftTrial = ~isLeftTrial; %Opposite
                                        this.counter_for_alternate = 0;
                                        range = int8(this.Setting_Struct.MinRandAlt:1:this.Setting_Struct.MaxRandAlt);
                                        this.Setting_Struct.Change_alternate = range(randperm(numel(range),1));
                                        text = ['Switching side... Must get ' num2str(this.Setting_Struct.Change_alternate) ' ' this.current_side ' correct.'];
                                        disp(text)
                                        set(this.message_handle,'Text',text);
                                    end
                                end
                            end
                        else
                            if this.Setting_Struct.Repeat_wrong && any(LastScore == [3 4])
                                %do nothing if the last was wrong
                            else
                                this.counter_for_alternate = this.counter_for_alternate+1;
                                %if counter for change has been reached, change side
                                if this.counter_for_alternate >= this.Setting_Struct.Change_alternate
                                    isLeftTrial = ~isLeftTrial; %Opposite
                                    this.counter_for_alternate = 0;
                                end
                            end
                        end
                    case 5 %alternate random
                        if this.Setting_Struct.Repeat_wrong && any(LastScore == [3 4])
                            %do nothing if repeat wrong
                        else
                            this.counter_for_alternate = this.counter_for_alternate+1;
                            %if counter is larger than the random number, change side
                            if this.counter_for_alternate >= this.Setting_Struct.Change_alternate
                                isLeftTrial = ~isLeftTrial; %Opposite
                                range = int8(this.Setting_Struct.MinRandAlt:this.Setting_Struct.MaxRandAlt);
                                this.Setting_Struct.Change_alternate = range(randperm(numel(range),1));
                                this.counter_for_alternate = 0;
                                text = ['Switching side... Must get ' num2str(this.Setting_Struct.Change_alternate) ' ' this.current_side ' correct.'];
                                disp(text)
                                set(this.message_handle,'Text',text);
                            end
                        end
                    case 6 %Side-Bias Correction.
                        RAND = rand;
                        isLeftTrial = round(RAND+SB);
                    case 7 %Smart Random engages repeat wrong if there is a side bias.
                        if this.i < 20 && any(LastScore == [1 2]) %Last trial was correct (1 or 2) %But also if i<21 repeat wrong is on, so maybe this doesn't need to be here
                            choice = [0 1];
                            isLeftTrial = choice(randperm(2,1));
                        elseif this.i > 20
                            if this.i == 21
                                this.Old_Setting_Struct{end+1} = this.Setting_Struct; %Put this BEFORE the setting changes
                                this.SetUpdate{end+1} = this.i; %This current trial is no longer repeat wrong
                                this.Setting_Struct.Repeat_wrong = 0;
                            end
                            if abs(SB)>=this.Setting_Struct.SideBiasInterval && any(LastScore == [3 4])%If there's a side bias, start repeat wrong.
                                this.Old_Setting_Struct{end+1} = this.Setting_Struct; %Put this BEFORE the setting changes
                                this.SetUpdate{end+1} = this.i; %This current trial is repeat wrong
                                this.StimulusStruct.side = 4; %Switch into alternate random mode
                                this.Setting_Struct.Repeat_wrong = 1; %Turn on repeat wrong at least for the settings structure to be accurate later for plotting
                                this.counter_for_alternate = -1; %When choosing which side to start the alternate pattern on, set counter to -1
                                range = int8(this.Setting_Struct.MinRandAlt:1:this.Setting_Struct.MaxRandAlt);
                                this.Setting_Struct.Change_alternate = range(randperm(numel(range),1));
                                text = ['Activating alternate repeat wrong... Must get ' num2str(this.Setting_Struct.Change_alternate) ' ' this.current_side ' correct.'];
                                disp(text)
                                set(this.message_handle,'Text',text);
                            else
                                choice = [0 1];
                                isLeftTrial = choice(randperm(2,1));
                            end
                        end
                    case 8 % Keyboard / Manual Mode
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
                end
            end
            if isLeftTrial %Set properties
                this.current_side = 'left';
            else
                this.current_side = 'right';
            end
        end
        %Show Cue
        function ShowCue(this,current_opacity)
            %select stim by making new stimulus object
            %initialize by subracting 8 from the type, as id for
            %the cue is -2 for circle and -1 for contour and 0 is image
            set(this.message_handle,'Text','Showing Cue');
            %drawnow; %refresh gui
            Current_Cue_Object = BehaviorBoxVisualStimulus((this.Setting_Struct.Stimulus_type) -8 , 0, current_opacity ,this.Setting_Struct.Box_Input_type);
            %display stimulus
            Current_Cue_Object.DisplayOnScreen(1, 0, this.Setting_Struct.Stimulussize_y, this.Setting_Struct.Stimulussize_x, this.Setting_Struct.Stimulusposition_x, this.Setting_Struct.Stimulusposition_y, this.Setting_Struct.Orientation);
            %wait for cue time
            pause(this.Setting_Struct.CueDuration)
            %close stim
            Current_Cue_Object.DisplayOnScreen(0, 0, this.Setting_Struct.Stimulussize_y, this.Setting_Struct.Stimulussize_x, this.Setting_Struct.Stimulusposition_x, this.Setting_Struct.Stimulusposition_y, this.Setting_Struct.Orientation);
            %wait after cue
            pause(this.Setting_Struct.WaitAfterCue)
        end
        %loop function that reads lever
        function WaitForInput(this)
            this.TrialStartTime = 0;
            set(this.message_handle,'Text','Waiting for Trial initialization');
            this.t1 = clock; t2 = this.t1;%In case of crash
            switch 1
                case this.Box.Input_type==6 && this.i ~=1 %Wheel 2.0, wait for the mouse to hold the wheel still for the interval to start a new trial
                    this.ReadyCue('k');
                    fl = [this.FLAx.Children];
                    [fl.Visible] = deal(1);
                    this.fig.Color = this.StimulusStruct.BackgroundColor;
                    timelimit = this.Setting_Struct.HoldStill;
                    starttime = clock;
                    tic
                    E = toc;
                    while E<=timelimit
                        E = toc;
                        this.message_handle.Text = ['Keep the wheel still for ' num2str(round(timelimit - etime(clock, starttime),1)) ' seconds.']; drawnow
                        if abs(this.Box.encoder.readSpeed) > 0
                            starttime = clock;
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
                    t2 = clock;
                    this.ReadyCue(this.ReadyCueStruct.Color);
                case this.Box.ardunioReadDigital==1 %Nose and Lick are Digital
                    if this.Setting_Struct.Box_Input_type == [5]
                        this.ResetSensor(this)
                    end
                    t1 = datetime("now");
                    this.ReadyCueAx.Children.MarkerFaceColor = this.StimulusStruct.LineColor;
                    set(this.message_handle,'Text','Waiting for Trial initialization'); drawnow
                    event = 0;
                    tic
                    while this.Box.readL() | this.Box.readR()
                        pause(0.1); drawnow; %Wait for the mouse to notice the bright ready cue before blinking it
                        %Otherwise the ready cue immediately turns dim when it appears, and mice poke L/R to see the blink instead of recognizing the bright dot
                    end
                    while ~get(this.stop_handle, 'Value') %While the stop button has not been pressed
                        pause(0.1); drawnow; %Update the buttons
                        if this.Setting_Struct.IntertrialMalCancel && this.Box.readL() | this.Box.readR()
                            %this.ReadyCue('k') %Make the ReadyCue black
                            this.Flash(this.StimulusStruct, this.Box,  findobj('Tag', 'ReadyCueDot'), 'Mal')
                            this.ReadyCueAx.Children.MarkerFaceColor = this.StimulusStruct.DimColor; drawnow %Make the ReadyCue dim
                            this.message_handle.Text = ['Do not poke L or R for the Intertrial Malingering interval: ' num2str(this.Setting_Struct.IntertrialMalSec) ' sec...'];
                            timerStart = datetime("now");
                            while 1
                                time = this.Setting_Struct.IntertrialMalSec-seconds(datetime("now")-timerStart);
                                txt = "Do not poke L or R! Intertrial Malingering timeout: "+round(time,1)+" sec...";
                                set(this.message_handle,'Text',txt)
                                drawnow %Update the buttons
                                if this.Box.readL() | this.Box.readR() %if L or R poke then restart timerStart
                                    timerStart = datetime("now");
                                end
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
                                if seconds(datetime("now")-timerStart) > this.Setting_Struct.IntertrialMalSec %End when mouse has not poked L or R for the interval
                                    this.Flash(this.StimulusStruct, this.Box,  findobj('Tag', 'ReadyCueDot'), 'Mal')
                                    this.ReadyCueAx.Children.MarkerFaceColor = this.StimulusStruct.LineColor;
                                    set(this.message_handle,'Text','Waiting for Trial initialization'); drawnow
                                    break
                                end
                            end
                        end
                        %Immediately accept choice
                        if this.Box.readM()
                            event = 1;
                            break
                        end
                    end
                    t2 = clock;
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
                                    this.ReadyCue(1)
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
                this.start_time = clock;
                this.Data_Object.GetStartTime;
            end
        end
        %wait loop while lever is read and open valves if correct
        function WaitForInputAndGiveReward(this)
            this.ResponseTime = 0;
            this.WhatDecision = 'time out';
            this.DrinkTime = 0;
            if get(this.stop_handle, 'Value')
                return
            end
            o = {this.fig.Children.Children}; % Hide ReadyCue and set background
            o(cellfun(@isempty, o)) = [];
            for obj = o
                x = obj{:};
                [x.Visible] = deal(1);
            end
            this.fig.Color = this.StimulusStruct.BackgroundColor;
            Ls = this.fig.findobj('Type','line');
            [Ls(:).Color] = deal(this.StimulusStruct.DimColor);
            this.ReadyCue(0); drawnow
            while this.Box.readM()
                pause(0.2);drawnow;
            end
            [Ls(:).Color] = deal(this.StimulusStruct.LineColor); drawnow
            %ignore input if set
            t1 = datetime("now");
            while this.Setting_Struct.Input_ignored & seconds(datetime("now")-t1)<this.Setting_Struct.Pokes_ignored_time
                time = this.Setting_Struct.Pokes_ignored_time-seconds(datetime("now")-t1);
                txt = "Ignoring input for "+round(time,1)+" sec...";
                set(this.message_handle,'Text',txt)
                pause(0.05); drawnow;
            end
            this.Flash(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Type', 'Line'), 'NewStim'); % Make visible stimulus and flash if set
            set(this.message_handle,'Text',['Waiting for ',this.current_side,' choice...']);
            this.Data_Object.addStimEvent(this.isLeftTrial); %Add the timestamp for the trial
            switch 1
                case any(this.Box.Input_type == [1 2 3 5]) %NosePoke
                    [this.WhatDecision, this.ResponseTime] = this.readLeverLoopDigital(this);
                case this.Box.Input_type == 6 %Wheel (new)
                    [this.WhatDecision, this.ResponseTime] = this.readLeverLoopAnalogWheel(this);
                otherwise
                    [this.WhatDecision, this.ResponseTime] = this.readKeyboardInput(this.stop_handle, this.message_handle, this.isLeftTrial);
            end
            if this.Box.Input_type == 6
                p = findobj('Type', 'Polygon');
                [p.FaceColor] = deal(this.StimulusStruct.BackgroundColor);
            end
            switch true
                case contains({this.WhatDecision} , 'correct', 'IgnoreCase', true)
                    set(this.message_handle,'Text','Giving Reward...');
                    t1 = clock; t2 = clock;
                    this.GiveReward(this.a, this.Box, this.Buttons, this.WhatDecision); %give reward
                    if this.Box.Input_type == 3
                        while this.Box.readL() | this.Box.readR() %Pause while the mouse is standing there and drinking their reward
                            pause(0.1);drawnow;
                        end
                    end
                    t2 = clock;
                    this.DrinkTime = etime(t2,t1);
                    %Flash
                    this.Flash(this.StimulusStruct, this.Box,  findobj('Tag', 'Contour'),  this.WhatDecision);
                    if this.StimulusStruct.PersistCorrectInterv > 0
                        thisInt = (this.StimulusStruct.PersistCorrectInterv);
                    else
                        thisInt = 0;
                    end
                    set(this.message_handle, 'Text',['Persisting correct stimulus for ' num2str(thisInt)  ' (sec)...']); drawnow
                    if this.Box.Input_type == 3 %Nose
                        this.UpdatePause(thisInt)
                    elseif this.Box.Input_type == 6 %Wheel
                        timerStart = clock;
                        while 1
                            drawnow %unless drawnow is here the button statuses will not update...
                            if etime(clock, timerStart) > thisInt
                                break
                            end
                            if get(this.FF, 'Value')
                                set(this.message_handle, 'Text','Skipping persist interval...'); drawnow
                                break;
                            end
                            if get(this.stop_handle, 'Value')
                                set(this.message_handle, 'Text','Ending session...'); drawnow
                                break;
                            end
                        end
                    end
                    o = findobj(this.fig.Children);
                    [o(:).Visible] = deal(0);
                case contains({this.WhatDecision} , 'wrong', 'IgnoreCase', true)
                    set(this.message_handle,'Text',[this.WhatDecision,' - Penalty...']);
                    while this.Box.readL() | this.Box.readR() %Pause while the mouse is standing there
                        pause(0.1);drawnow;
                    end
                    %Flash
                    this.Flash(this.StimulusStruct, this.Box,  findobj('Tag', 'Contour'), this.WhatDecision);
                    if ~get(this.stop_handle, 'Value') && this.StimulusStruct.PersistIncorrect
                        set(this.message_handle,'Text','Persisting correct stimulus...');
                        this.UpdatePause(this.StimulusStruct.PersistIncorrectInterv)
                    else
                    end
                    o = findobj(this.fig.Children);
                    [o(:).Visible] = deal(0);
                    this.fig.Color = 'k';
            end
        end
        %Use this function instead of pausing, so that buttons are checked and settings are updated during the pause
        function UpdatePause(this, interval)
            starttime = clock;
            while etime(clock, starttime) < interval
                pause(0.05); drawnow;
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
            switch this.Box.Input_type
                case 3 % Nose
                    this.ReadyCue(1)
                    this.ReadyCueAx.findobj('Type','scatter').MarkerFaceColor = deal(this.StimulusStruct.DimColor); drawnow;
                    while this.Box.readL() | this.Box.readR() %Pause while the mouse is standing there and drinking their water reward
                        pause(0.1); drawnow;
                    end
                    % o = findobj(this.fig.Children);
                    % [o(:).Visible] = deal(0);
                case 6 % Wheel
                    this.ReadyCue(1)
            end
            %Wait for interval
            this.UpdatePause(interval_time)
            this.GuiHandles.MsgBox.String = fileread(this.textdiary);
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

            %Wheel stuff, only save this if its a wheel trial
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
        function SaveAllData(this)
            fakeNames = {'w', 'W'};
            if any(strcmp(num2str(this.Setting_Struct.Subject), fakeNames)) || any(strcmp(this.Setting_Struct.Strain, fakeNames)) %do not save if I use a fake name for fake data
                return
            end
            D = string(datetime(this.Data_Object.start_time, "Format", "yyMMdd_HHmmss"));
            stim = erase(this.app.Stimulus_type.Value, ' ');
            input = this.app.Box_Input_type.Value;
            Sub = this.Setting_Struct.Subject;
            Str = this.Data_Object.Str;
            saveasname = join([D Sub Str stim input],'_');
            savefolder = [this.Data_Object.filedir filesep];
            set(this.message_handle,'Text', 'Saving data as: '+saveasname+'.mat');
            [newData] = this.Data_Object.current_data_struct;
            names = fieldnames(newData);
            for n = names(structfun(@isrow, newData) & structfun(@length, newData) > 1)' %Make sure everything is saved as a column
                newData.(n{:}) = newData.(n{:})';
            end
            FullTrials = numel(newData.TimeStamp);
            for n = names(structfun(@length, newData) > FullTrials)'
                newData.(n{:}) = newData.(n{:})(1:FullTrials);
            end
            Settings = [this.Setting_Struct cell2mat(this.Old_Setting_Struct)];
            newData.SetUpdate = this.SetUpdate;
            nonEmptyRows = any(~cellfun(@isempty, this.StimHistory'))';
            newData.StimHist = this.StimHistory(nonEmptyRows,:);
            rmv = {'GUI_numbers', 'encoder'};
            for r = rmv
                try
                    Settings = rmfield(Settings, r);
                end
            end
            newData.Settings = Settings;
            if this.Box.Input_type == 6
                newData.wheel_record = this.wheelchoice_record;
                newData.wheel_record(any(cellfun(@isempty, newData.wheel_record)'),:) = [];
            end
            if numel(this.SetUpdate) == 1 % Settings never changed during the session.
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
                end
            end
            newData.Weight = this.Setting_Struct.Weight;
            Notes = this.GuiHandles.NotesText.String;
            try
                try
                    save(savefolder+saveasname+".mat", 'Settings', 'newData', 'Notes')
                    f = figure("MenuBar","none","Visible","off");
                    copyobj(this.graphFig.Children, f)
                    this.saveFigure(f, savefolder, saveasname)
                    dispstring = 'Data saved as: '+saveasname;
                    fprintf([dispstring+'\n']);
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
            f.MenuBar = 'figure';
            f.Visible = 1;
        end
        %when done, clean up
        function cleanUP(this)
            %switch on all buttons
            this.toggleButtonsOnOff(this.Buttons,1);
            this.stop_handle.Value = 0;%Turn off Stop button
            %close stimulus if still open
            delete(findobj("Type", "figure", "Name", "Stimulus"))
            disp_string = ['Stopped training Mouse ',num2str(this.Setting_Struct.Subject), ' at ',datestr(now)];
            disp(disp_string);
            disp('- - - - -');
        end
        function ReadyCue(this, isVis)
            %isVis is 1 or 0
            switch 1
                case numel(isVis) == 3 %RGB triplet
                    this.ReadyCueAx.Color = isVis;
                    [this.ReadyCueAx.Visible] = deal(1);
                    return
                case any(int8(isVis) == [0 1]) || islogical(isVis)%Logical off or on
                    isVis = logical(isVis);
                case ischar(isVis) %Letter color abbrev.
                    ax = findobj(this.ReadyCueAx, 'Type', 'Axes');
                    ax.Color = char(isVis);
                    [this.ReadyCueAx.Visible] = deal(1);
                    try
                        [this.ReadyCueAx.Children.Visible] = deal(0);
                    end
                    return
            end
            % Plot a circle in the center to show that a new trial is ready
            %Make the figure if this is the first call to readycue, or make a new one
            %if the window has been closed
            if ~isempty(this.ReadyCueAx) & all(isvalid(this.ReadyCueAx))
                [this.ReadyCueAx.Visible] = deal(isVis);
                [this.ReadyCueAx.Children.Visible] = deal(isVis);
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
                %                 if this.Box.Input_type~=6
                %                     this.Flash(this.StimulusStruct, this.Box,  findobj('Tag', 'ReadyCueDot'), 'NewStim')
                %                 end
            end
            %drawnow
        end
        function TextBox(this)
            this.getGUI();
            set(this.message_handle,'Text','Trigger the Left Sensor');
            while ~this.Box.readL()
                pause(0.05); drawnow;
                %just wait until the sensor is triggered
            end
            set(this.message_handle,'Text','Trigger the Right Sensor');
            while ~this.Box.readR()
                pause(0.05); drawnow;
                %just wait until the sensor is triggered
            end
            set(this.message_handle,'Text','Trigger the Middle Sensor');
            while ~this.Box.readM()
                pause(0.05); drawnow;
                %just wait until the sensor is triggered
            end
            this.cleanUP();
            set(this.message_handle,'Text','Did the sensors work?');
        end
        function TestStimulus(this)
            tic
            %this.app.Preview.Enable = 0; %Disable this when debugging...
            this.getGUI();
            this.Stimulus_Object = BehaviorBoxVisualStimulus(this.StimulusStruct, Preview=1);
            this.Stimulus_Object = this.Stimulus_Object.updateProps(this.StimulusStruct);
            if isempty([this.Stimulus_Object.LStimAx this.Stimulus_Object.RStimAx])
                [this.fig,this.LStimAx,this.RStimAx, ~] = this.Stimulus_Object.setUpFigure(); drawnow
                this.Stimulus_Object = this.Stimulus_Object.findfigs();
            end
            [~,~] = this.Stimulus_Object.DisplayOnScreen(this.PickSideForCorrect(0, 0), this.Setting_Struct.Starting_opacity);
            this.fig = this.Stimulus_Object.fig;
            [this.fig.findobj('Tag','Spotlight').Visible] = deal(1)
            toc
            pause(0.1)
            this.Flash(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Type', 'Line'), "NewStim")
            this.app.Preview.Enable = 1;
        end
    end
    %STATIC FUNCTIONS====
    methods(Static = true)
        function Types = GetType(App, Props)
            Types = cellfun(@(x) App.(x).Type, Props, 'UniformOutput', false);
        end
        function Types = GetTag(App, Props)
            Types = cellfun(@(x) App.(x).Tag, Props, 'UniformOutput', false);
        end
        %toggle GUI buttons active/inactive
        function toggleButtonsOnOff(Buttons, on)
            for b = struct2cell(Buttons)'
                if b{:}.Type == "uistatebutton"
                    continue
                else
                    b{:}.Enable = on;
                end
            end
            %             B = findobj(Buttons, 'Type', 'uibutton');
            %             [B.Enable] = deal(on);
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
        function GiveReward(A, Box, Buttons, whatdecision)
            %Get reward valve, pulse number and time:
            switch Box.Input_type
                case 3 %Nose
                    switch true
                        case contains(whatdecision, 'left correct', 'IgnoreCase', true)
                            CorrectLever = Box.Left; %Left
                            OtherLever = Box.Right; %Right
                            PulseNum = Box.LeftPulse;
                            Valve = Box.ValveR; %Left
                            Time = Box.Lrewardtime; %Left
                        case contains(whatdecision, 'right correct', 'IgnoreCase', true)
                            CorrectLever = Box.Right; %Right
                            OtherLever = Box.Left; %Left
                            PulseNum = Box.RightPulse;
                            Valve = Box.ValveL; %Right
                            Time = Box.Rrewardtime; %Right
                        case contains(whatdecision, 'wrong', 'IgnoreCase', true)
                            if Box.Air_Puff_Penalty
                                PulseNum = Box.AirPuffPulses;
                                Valve = Box.AirPuff;
                                Time = Box.AirPuffTime;
                            else
                                return
                            end
                    end
                    % Don't dispense the reward unless the mouse is waiting for it!
                    while contains(whatdecision, 'correct', 'IgnoreCase', true) && Box.readPin(CorrectLever)
                        pause(0.1); drawnow;
                        if get(Buttons.Stop, 'Value') || get(Buttons.FastForward, 'Value')
                            break
                        end
                    end
                case 6 % Wheel
                    switch true
                        case contains(whatdecision, 'correct', 'IgnoreCase', true)
                            PulseNum = Box.RightPulse;
                            Valve = Box.Reward; %Right
                            Time = Box.Rrewardtime; %Right
                        case contains(whatdecision, 'wrong', 'IgnoreCase', true)
                            return %No air puff for wheel
                    end
                otherwise %Keyboard, any input method I haven't used before
                    return
            end
            for i = 1:PulseNum
                A.writeDigitalPin(Valve,1)
                pause(Time);
                A.writeDigitalPin(Valve,0); drawnow
                if i < PulseNum
                    switch Box.Input_type
                        case 3 %Nose
                            pause(Box.SecBwPulse)
                            while contains(whatdecision, 'correct', 'IgnoreCase', true) && ~Box.readPin(CorrectLever) %Wait for NosePoke Don't dispense the reward unless the mouse is waiting for it! Wait indefinitely between pulses for them to learn to collect all the water
                                pause(0.2); drawnow;
                                if get(Buttons.Stop, 'Value') || get(Buttons.FastForward, 'Value')
                                    break
                                end
                            end
                        case 6 %wheel
                            bigTimer = [];
                            timer = clock;
                            while etime(clock, timer) < Box.SecBwPulse
                                pause(0.1); drawnow;
                                if get(Buttons.Stop, 'Value') || get(Buttons.FastForward, 'Value')
                                    break
                                end
                            end
                    end
                end
            end
        end
        function GiveOnePuff(this)
            this.a.writeDigitalPin(this.Box.AirPuff,1)
            pause(this.Box.AirPuffTime);
            this.a.writeDigitalPin(this.Box.AirPuff,0)
        end
        function [WhatDecision, response_time] = readKeyboardInput(stop_handle, message_handle, isLeftTrial)
            text = 'Respond: Press L for Left, R for Right, C or M for Middle:'; set(message_handle,'String',text); fprintf([text '\n']); drawnow
            prompt = 'L, R, or M/C:   ';
            keypress = 0; t1 = clock;
            while keypress==0
                pause(0.05); drawnow;
                currkey = input(prompt,"s");
                response_time = etime(clock, t1);
                switch true
                    case strcmp(currkey, 'l') || strcmp(currkey, 'L')
                        text = 'Left choice...'; fprintf([text '\n']); set(message_handle,'String',text); drawnow
                        event = 1;
                        keypress = 1;
                    case strcmp(currkey, 'r') || strcmp(currkey, 'R')
                        text = 'Right choice...'; fprintf([text '\n']); set(message_handle,'String',text); drawnow
                        event = 2;
                        keypress = 1;
                    case strcmp(currkey, 'C') || strcmp(currkey, 'c') || strcmp(currkey, 'M') || strcmp(currkey, 'm')
                        text = 'Middle choice'; fprintf([text '\n']); set(message_handle,'String',text); drawnow
                    otherwise
                        text = 'Please only press one of the indicated keys...'; fprintf([text '\n']); set(message_handle,'String',text); drawnow
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
        %read the lever (digital read)
        function [WhatDecision, response_time] = readLeverLoopDigital(this)
            response_time = 0;
            this.DuringTMal = 0;
            event = -1;
            try
                %Turn on/Reset lick sensor
                this.ResetSensor(this)
                timeout_value = this.Box.Timeout_after_time;
                InpDelay = this.Setting_Struct.Input_Delay_Respond;
                timeout_timer = clock;
                response_timer = clock;
                %run loop
                while timeout_value == 0 | etime(clock, timeout_timer)<timeout_value
                    pause(0.01);drawnow;
                    if get(this.Skip, 'Value') %this.Skip.Value
                        this.Skip.Value = 0; %Turn the button off
                        break
                    end
                    %check if stop pressed
                    if get(this.stop_handle, 'Value')
                        break %abort
                    end
                    if this.Box.readM()
                        this.Flash(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Type', 'Line'), 'center')
                        this.DuringTMal = this.DuringTMal + 1;
                    end
                    %Immediately accept the choice:
                    if this.Box.readL() %& this.isLeftTrial %LeverA is left
                        event = 1; %Left Choice
                        break
                    end
                    if this.Box.readR() %& ~this.isLeftTrial %LeverB is right
                        event = 2; %Right Choice
                        break
                    end
                end
                try
                    d = this.fig.findobj("Tag", "Distractor");
                    [d.Color] = deal(this.StimulusStruct.DimColor);
                end
                response_time = etime(clock, response_timer);
            catch err
                this.unwrapError(err)
            end
            %translate to decision enum
            switch event
                case -1
                    WhatDecision = 'time out';
                    response_time = 0;
                case 1
                    %-1 is for trainingstrials always correct
                    if this.isLeftTrial ==1 || this.isLeftTrial == -1
                        WhatDecision = 'left correct';
                    else
                        WhatDecision = 'left wrong';
                    end
                case 2
                    if this.isLeftTrial ==0 || this.isLeftTrial == -1
                        WhatDecision = 'right correct';
                    else
                        WhatDecision = 'right wrong';
                    end
            end
        end
        function [WhatDecision, response_time] = readLeverLoopAnalogWheel(this)
            event = -1;
            delta = 0;
            timeout_value = this.Box.Timeout_after_time;
            threshold = this.Setting_Struct.TurnMag;
            o = this.fig.findobj('Type', 'Axes');
            C = o(contains({o.Tag}, 'Correct'));
            W = o(contains({o.Tag}, 'Incorrect'));
            % A full revolution is about 4000 pulses 4400/360 = 12.22 pulses/degree 90 deg is ~1000 pulses
            StimDistance = 0.3;
            axes = [this.RStimAx this.LStimAx];
            pos1i = axes(1).Position;
            if numel(axes) > 1
                pos2i = axes(2).Position;
            end
            thresh = abs(pos1i(1)/2);
            RoundUp = (this.Setting_Struct.RoundUpVal/100); %Default is 75 --> 0.75
            this.ResetSensor(this)
            if this.Setting_Struct.RoundUp
                thresh = RoundUp*thresh;
            end
            timeout_timer = clock;
            response_timer = clock;
            while timeout_value == 0 | etime(clock, timeout_timer)<timeout_value % do NOT replace | with || or the expression is changed.
                dist = this.Box.encoder.readCount;
                delta = (dist/threshold)*StimDistance;
                if abs(delta)>thresh
                    if sign(delta)>0
                        delta =  thresh;
                    elseif sign(delta)<0
                        delta = -thresh;
                    end
                end
                if this.isLeftTrial & delta < -thresh*RoundUp
                    delta = -thresh*RoundUp;
                elseif ~this.isLeftTrial & delta > thresh*RoundUp
                    delta = thresh*RoundUp;
                end
                this.wheelchoice(end+1) = delta;
                this.wheelchoicetime(end+1) = etime(clock, response_timer);
                pos1 = pos1i + ([delta 0 0 0]);
                axes(1).Position = pos1;
                if numel(axes) > 1
                    pos2 = pos2i + ([delta 0 0 0]);
                    axes(2).Position = pos2;
                end
                drawnow
                if this.isLeftTrial & delta <= -thresh*RoundUp
                    event = 2;
                    break
                elseif ~this.isLeftTrial & delta >= thresh*RoundUp
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
                %                 if get(this.stop_handle, 'Value') %Don't check stop button, let the mouse finish their trial
                %                     break;
                %                 end
                if get(this.Skip, 'Value')
                    set(this.Skip, 'Value', 0) %Turn the button off
                    break
                end
            end
            response_time = etime(clock, response_timer);
            if event == -1 %If the mouse was close to picking a side, round up their choice:
                if abs(delta) >= thresh*RoundUp
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
        function ResetSensor(this)
            if this.Box.Input_type == 5
                this.a.writeDigitalPin(this.Setting_Struct.ResetPin, 0);
                this.a.writeDigitalPin(this.Setting_Struct.ResetPin, 1);
            elseif this.Box.use_wheel == 1
                this.Box.encoder.resetCount
            end
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
                Freq = Stim.FreqFlashAfter;
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
                if [Lines.Type] == "scatter"
                    r = 1 ;
                    for StimRep = 1:Reps
                        [Lines.MarkerFaceColor] = deal(flash_color); drawnow
                        pause(1/Freq/6)
                        [Lines.MarkerFaceColor] = deal(start_color); drawnow
                        if StimRep < r
                            pause(1/Freq/2)
                        end
                    end
                elseif [Lines(1).Type] == "polygon"
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
                    while Box.readL() || Box.readM()
                        pause(0.3); drawnow
                    end
                    [Lines(:).Color] = deal(dark_color); drawnow
                    pause(1/Freq/10)
                    [Lines(:).Color] = deal(start_color);
                    try
                        [d.Color] = deal(Stim.DimColor); drawnow
                    end
                    pause(1/Freq/10)
                    [Lines(:).Color] = deal(flash_color);
                    try
                        [d.Color] = deal(Stim.DimColor);
                    end
                    drawnow
                    pause(1/Freq/5)
                    [Lines(:).Color] = deal(start_color); drawnow
                    if StimRep < Reps
                        pause(1/Freq/10)
                    end
                end
            end
            function SimpleFlash(Color)
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
                    while Box.readL() || Box.readM()
                        pause(0.3); drawnow
                    end
                    [Lines.Color] = deal(Stim.BackgroundColor); drawnow
                    pause(1/Freq/2)
                    [Lines.Color] = deal(dark_color); drawnow
                    % pause(1/Freq/10)
                    % [Lines.Color] = deal(flash_color); drawnow
                    pause(1/Freq/2)
                end
                [Lines.Color] = deal(Stim.LineColor);
            end
        end
        function saveFigure(fig, folder, name)
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