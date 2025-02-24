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
                    % Uncomment these when needing to time the trial
                    % profile on
                    this.BeforeTrial();
                    this.WaitForInput();
                    this.WaitForInputAndGiveReward();
                    this.AfterTrial();
                    pause(0.01);
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
            skiptypes = {'buttongroup', 'figure', 'label', 'panel', 'annotationpane', 'axes', 'tab', 'uigridlayout'};
            types = this.GetType(this.app, props); %cellfun(@(x) this.app.(x).Type, props, 'UniformOutput', false); %Get their types
            props = props(~contains(types, skiptypes, "IgnoreCase",true));
            types = this.GetType(this.app, props);
            %Make Button structure
            buttons = props(contains(types, {'button'}) & ~contains(types, {'radiobutton'}));
            bTags = this.GetTag(this.app, buttons);
            % Out = struct();
            % for B = buttons'
            %     name = B{:};
            %     try
            %         Out.(name) = this.app.(name);
            %     catch err
            %         unwrapErr(err)
            %     end
            % end
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
        function Types = GetTag(this, App, Props)
            Types = cellfun(@(x) App.(x).Tag, Props, 'UniformOutput', false);
        end
        function Types = GetType(this, App, Props)
            %Types = cellfun(@(x) App.(x).Type, Props, 'UniformOutput', false);
            n = numel(Props);
            Types = cell(1, n);
            for i = 1:n
                try
                    Types{i} = App.(Props{i}).Type;
                catch err
                    1;
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
            this.message_handle.Text = 'Connecting to Arduino. . .';
            tic
            try
                % https://docs.arduino.cc/learn/microcontrollers/digital-pins
                switch this.Setting_Struct.Box_Input_type
                    case 3 %Three Pokes
                        if ispc
                            comsnum = "COM"+this.app.Arduino_Com.Value;
                        elseif ismac
                            comsnum = "/dev/tty.usbmodem"+this.app.Arduino_Com.Value;
                        elseif isunix
                            comsnum = "/dev/tty"+this.app.Arduino_Com.Value;
                        end
                        this.a = BehaviorBoxSerial(comsnum, 115200, 'NosePoke');
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
            [this.fig, this.LStimAx, this.RStimAx, this.FLAx, ~] = this.Stimulus_Object.setUpFigure();
            this.ReadyCue(1)
            this.ReadyCueStruct.Ax = this.ReadyCueAx;
            this.StimulusStruct.ReadyCue = this.ReadyCueStruct;
            this.toggleButtonsOnOff(this.Buttons,0); % Turn off all buttons
            fprintf("- - - - -\n");
            txt = "Start trial Mouse "+this.Setting_Struct.Subject+" at "+string(datetime('now'));
            set(this.message_handle,'Text',txt);
            fprintf(txt+"\n");
            this.i = 0;
            this.timeout_counter = 0;
            this.Temp_Active = false;
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
            if this.Setting_Struct.Repeat_wrong==1 && any(LastScore == [3 4]) %If repeat wrong and they got it wrong
                this.Level = this.Setting_Struct.Starting_opacity;
                if isvalid(this.fig)
                    this.StimHistory(this.i,:) = this.StimHistory(this.i-1,:); %Use the same stimulus from last time
                    %[this.StimHistory{this.i,1},this.StimHistory{this.i,2}] = this.Stimulus_Object.DisplayOnScreen(this.isLeftTrial, this.Level); %Plot new stimulus as hidden objects, record positions and angles of the segments
                else
                    [this.fig, this.LStimAx, this.RStimAx, this.FLAx] = this.Stimulus_Object.setUpFigure();
                    this.StimHistory(this.i,:) = this.StimHistory(this.i-1,:); %Use the same stimulus from last time
                    %[this.StimHistory{this.i,1},this.StimHistory{this.i,2}] = this.Stimulus_Object.DisplayOnScreen(this.isLeftTrial, this.Level); %Plot new stimulus as hidden objects, record positions and angles of the segments
                end
            else %If correct or no repeat wrong
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
            end
            %Update GUI window numbers
            this.updateGUIbeforeIteration(); %Update again, in case the level changed
            [this.fig.Children.findobj('Type','Line').Visible] = deal(0);
            drawnow
            this.ReadyCue(1)
        end
        function CheckTemp(this)
            % Temp_Settings = struct();
            % Temp_Old_Settings = struct();
            % Temp_Countdown = 0;
            % Temp_iStart = 0;
            % Temp_Active = 0;
            %Manually turning on:
            if ~this.Temp_Active
                if this.Temp_Settings.PerformanceThreshold || this.Temp_Settings.TrialNumber
                    this.Temp_Active = true;
                    this.Temp_iStart = true;
                end
            end
            %Manually Turning Off:
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
                this.Temp_Countdown = this.Temp_Settings.TrialCount - sum(this.Data_Object.current_data_struct.Score);
                this.app.TrialsRemainingLabel.Text = this.Temp_Countdown+" Correct Trials Remaining";
                if this.i <= 1
                    return
                end
                try
                    % sMM = this.Data_Object.AnalyzedData.DayMM{:}{8,1}{:}(end);
                    sMM = this.Data_Object.AnalyzedData.DayMM{1}{8,1}{:}(end);
                    if this.Temp_Countdown <= 0 && sMM >= this.Temp_Settings.TrialCountThreshold/100
                        this.Temp_Active = false;
                        this.Setting_Struct = this.Temp_Old_Settings;
                        this.app.TrialsRemainingLabel.Text = "_ Trials Remaining";
                        this.app.TempOff_Temp.Value = 1;
                    elseif this.Temp_Countdown <= 0
                        this.app.TrialsRemainingLabel.Text = (this.Temp_Countdown*-1)+" Extra trials, Poor performance";
                    end
                catch err % This fails because of a problem with the way an incomplete bin is handled after the 11th trial
                    unwrapErr(err)
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
            current_difficulty = this.LevelStruct.ChooseLevel();
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
                        % Add 0.5 bc values oscillate -0.5 to 0.5
                        choice = [0 1];
                        isLeftTrial = choice(randperm(2,1));
                        try
                            SB_Ratio = 0.5+this.Data_Object.AnalyzedData.TrialData.SB.Stimulus{:}(end);
                        catch
                            return
                        end
                        if SB_Ratio > 0.7 % too many Left
                            isLeftTrial = 0;
                        elseif SB_Ratio < 0.3 % too many Right
                            isLeftTrial = 1;
                        end
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
                end
            end
            % Check if Responses show side bias, correct that
            if this.i>1
                Resp_Ratio = 0.5+this.Data_Object.AnalyzedData.TrialData.SB.Responses{:}(end);
                if Resp_Ratio >= 0.72
                    isLeftTrial = 0;
                    this.Setting_Struct.Repeat_wrong = 1;
                    this.app.Repeat_wrong.Value = 1;
                elseif Resp_Ratio <= 0.28
                    isLeftTrial = 1;
                    this.Setting_Struct.Repeat_wrong = 1;
                    this.app.Repeat_wrong.Value = 1;
                else
                    this.Setting_Struct.Repeat_wrong = 0;
                    this.app.Repeat_wrong.Value = 0;
                end
            end
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

            if this.Box.ardunioReadDigital == 1
                this.WaitForInputArduino();
            else
                this.WaitForInputKeyboard();
            end

            if ~get(this.stop_handle, 'Value')
                this.TrialStartTime = seconds(datetime("now") - startTime);
            end

            if this.i == 1
                this.start_time = datetime("now");
                this.Data_Object.GetStartTime;
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
                delayTime = this.Setting_Struct.Input_Delay_Respond;
            else
                delayTime = 0;
            end
            STABLE = true;
            % Ensure the value remains 1 for the specified duration
            tic
            while toc < delayTime
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
                    this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'ReadyCueDot'), "Make_Bright");
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
            timerStart = clock;

            while true
                pause(0.1);
                drawnow;

                if this.CheckForInterruptions()
                    break;
                end

                if etime(clock, timerStart) > InterTMalInterv
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
            this.handleIncorrectDecision();
            this.processDecision();
        end
        function setupStimulus(this)
            this.ResponseTime = 0;
            this.WhatDecision = 'time out';
            this.DrinkTime = 0;
% Make stimulus line elements background color
            set(findobj(this.fig.Children, 'Type','line'), 'Color', this.StimulusStruct.BackgroundColor)
            o = {this.fig.Children.Children}; % Hide ReadyCue and set background
            validObjs = o(~cellfun(@isempty, o));
            for x = validObjs
                set([x{:}], 'Visible', 1);
            end
            this.fig.Color = this.StimulusStruct.BackgroundColor;
            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'ReadyCueDot'), "Make_Background", true);
            this.ReadyCue(0);
            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'line'), "Make_Bright");
        end
        function processIgnoredInput(this)
            tic;
            while this.Box.ardunioReadDigital && this.Setting_Struct.Input_ignored && toc <= this.Setting_Struct.Pokes_ignored_time
                if this.Setting_Struct.ConfirmChoice
                    this.confirmCorrectChoice();
                end
                if this.a.ReadMiddle()
                    this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'Line'), "NewStim");
                    tic; % Restart the timer to avoid skipping confirmation period
                end
                this.updateInputIgnoredMessage();
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
        function updateInputIgnoredMessage(this)
            time = this.Setting_Struct.Pokes_ignored_time - toc;
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
        end
        function handleIncorrectDecision(this)
            if this.Setting_Struct.OnlyCorrect && contains(this.WhatDecision, 'wrong', 'IgnoreCase', true)
                set(this.message_handle, 'Text', sprintf('Reanswer... Waiting for %s choice...', this.current_side));
                this.WhatDecision = this.getDecision();
            end
        end
        function processDecision(this)
            switch true
                case contains(this.WhatDecision, 'correct', 'IgnoreCase', true)
                    this.handleCorrectDecision();
                case contains(this.WhatDecision, 'wrong', 'IgnoreCase', true)
                    this.handleWrongDecision();
                case contains(this.WhatDecision, 'OC', 'IgnoreCase', true)
                    this.handleOnlyCorrect();
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
            set(this.message_handle, 'Text', sprintf('Persisting correct stimulus for %.1f sec...', thisInt));
            tic
            while toc <= thisInt
                this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), "Flash_Contour");
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
            set(this.message_handle,'Text','Persisting correct stimulus...');
            thisInt = this.StimulusStruct.PersistIncorrectInterv;
            tic
            while toc <= thisInt
                this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), "Flash_Contour");
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
            % Change the WhatDecision back to the actual incorrect
            % choice so that it is recorded correctly
            if this.isLeftTrial
                this.WhatDecision = "right wrong";
            else
                this.WhatDecision = "left wrong";
            end
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
            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Distractor'), "Make_Background", true)
            [o(:).Visible] = deal(0);
        end
        function updatePause(this, interval)
            % This fcn is unused, UpdatePause (capital U) is the function
            % used... why? eliminate?)
            starttime = clock;
            while etime(clock, starttime) < interval
                pause(0.1); drawnow;
                if this.Pause.Value
                    this.pauseMessage();
                    continue;
                end
                if get(this.stop_handle, 'Value') || get(this.FF, 'Value')
                    break;
                end
            end
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
            response_time = 0;
            this.DuringTMal = 0;
            event = -1;
            try
                timeout_value = this.Box.Timeout_after_time;
                response_timer_start = datetime("now");
                % Main loop to wait for actions
                tic
                while timeout_value == 0 || toc < timeout_value
                    pause(0.01); % Pause is needed otherwise Arduino callback won't update
                    % Check for skip or stop conditions
                    if get(this.Skip, 'Value')
                        this.Skip.Value = 0;
                        break;
                    elseif get(this.stop_handle, 'Value')
                        break;
                    end
                    % Handle middle reading for inter-trial malingering
                    if this.a.ReadMiddle()
                        this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'Line'), "Make_Background", false);
                        this.DuringTMal = this.DuringTMal + 1;
                    end
                    % Check for left or right decisions with stability
                    if this.Left_StableChoice_DuringTrial(true)  % With delay
                        event = 1; % Left Choice
                        response_time = datetime("now");
                        break;
                    elseif this.Right_StableChoice_DuringTrial(true)  % With delay
                        event = 2; % Right Choice
                        response_time = datetime("now");
                        break;
                    end
                end
                % Fade all distractor color to dim
                try
                    d = findobj(this.fig.Children, "Tag", "Distractor");
                    this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Distractor'), "Dim_Distractors")
                    [d.Color] = deal(this.StimulusStruct.DimColor);
                catch % Ignore errors related to finding and updating distractors
                end
                response_time = seconds(response_time-response_timer_start);
            catch err
                this.unwrapError(err);
            end
            % Translate event to decision enum
            switch event
                case -1
                    WhatDecision = 'time out';
                    response_time = 0;
                case 1
                    if this.isLeftTrial == 1 || this.isLeftTrial == -1
                        WhatDecision = 'left correct';
                    else
                        WhatDecision = 'left wrong';
                    end
                case 2
                    if this.isLeftTrial == 0 || this.isLeftTrial == -1
                        WhatDecision = 'right correct';
                    else
                        WhatDecision = 'right wrong';
                    end
            end
        end
        function stable = Left_StableChoice_DuringTrial(this, checkDelay)
            % Check if the sensor value remains stable for 1 second
            if checkDelay
                delayTime = this.Setting_Struct.Input_Delay_Respond;
            else
                delayTime = 0;
            end
            STABLE = true;
            % Ensure the value remains 1 for the specified duration
            tic
            while toc < delayTime
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
                    if this.isLeftTrial
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
                delayTime = this.Setting_Struct.Input_Delay_Respond;
            else
                delayTime = 0;
            end
            STABLE = true;
            % Ensure the value remains 1 for the specified duration
            tic
            while toc < delayTime
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
                    if ~this.isLeftTrial
                        this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), "Flash_Contour")
                    end
                end
            end
            %toc
            stable = STABLE && this.a.ReadRight;
        end
        %read the lever (digital read)
        function [WhatDecision, response_time] = readLeverLoopDigital_OnlyCorrect(this)
            response_time = 0;
            this.DuringTMal = 0;
            event = -1;
            try
                timeout_value = this.Box.Timeout_after_time;
                response_timer_start = datetime("now");
                % Main loop to wait for actions
                tic
                while timeout_value == 0 || toc < timeout_value
                    pause(0.01); % Pause is needed otherwise Arduino callback won't update
                    % Check for skip or stop conditions
                    if get(this.Skip, 'Value')
                        this.Skip.Value = 0;
                        break;
                    elseif get(this.stop_handle, 'Value')
                        break;
                    end
                    % Handle middle reading for inter-trial malingering
                    if this.a.ReadMiddle()
                        this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'Line'), "Make_Background", false);
                        this.DuringTMal = this.DuringTMal + 1;
                    end
                    % Check for left or right decisions with stability
                    if this.Left_StableChoice_DuringTrial(true)  % With delay
                        if this.isLeftTrial
                            event = 3;
                            response_time = datetime("now");
                            break;
                        else
                            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'Line'), "Make_Background", false);
                        end
                    elseif this.Right_StableChoice_DuringTrial(true)  % With delay
                        if ~this.isLeftTrial
                            event = 3;
                            response_time = datetime("now");
                            break;
                        else
                            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'Line'), "Make_Background", false);
                        end
                    end
                end
                % Fade all distractor color to dim
                try
                    d = findobj(this.fig.Children, "Tag", "Distractor");
                    this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Distractor'), "Dim_Distractors")
                    [d.Color] = deal(this.StimulusStruct.DimColor);
                catch % Ignore errors related to finding and updating distractors
                end
                response_time = seconds(response_time-response_timer_start);
            catch err
                this.unwrapError(err);
            end
            % Translate event to decision enum
            switch event
                case -1
                    WhatDecision = 'time out';
                    response_time = 0;
                case 1
                    if this.isLeftTrial == 1 || this.isLeftTrial == -1
                        WhatDecision = 'left correct';
                    else
                        WhatDecision = 'left wrong';
                    end
                case 2
                    if this.isLeftTrial == 0 || this.isLeftTrial == -1
                        WhatDecision = 'right correct';
                    else
                        WhatDecision = 'right wrong';
                    end
                case 3 % Only_Correct Setting active, mouse got it wrong but gets second chance
                    WhatDecision = 'OC';
            end
        end
        function FlashNew(this, Stim, Box, Lines, whatdecision, OneWay)
            arguments
                this
                Stim % from Setting structure
                Box
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
            if whatdecision == "WaitForInput" % New name - Flash Dim
                Steps = Stim.FreqFlashInitial;
                this.BasicFlashCosine("Lines",Lines, "NewColor", flash_color, "steps", Steps, "Interruptor", @(x)~this.a.ReadNone())
            elseif whatdecision == "Flash_Contour" % New name - Flash Bright
                Steps = Stim.FreqFlashInitial;
                this.BasicFlashCosine("Lines",Lines, "NewColor", flash_color, "steps", Steps, "Interruptor", @(x)this.a.ReadMiddle())
            elseif whatdecision == "Dim_Distractors" % Make Dim color
                Steps = Stim.FreqFlashInitial;
                this.BasicFlashCosine("Lines",Lines, "NewColor", dark_color, "steps", Steps, "OneWay", true)
            elseif whatdecision == "Make_Background" % Make Background color
                Steps = Stim.FreqFlashInitial;
                this.BasicFlashCosine("Lines",Lines, "NewColor", background_color, "steps", Steps, "OneWay", OneWay)
            elseif whatdecision == "Make_Bright" % Make start color
                Steps = 100;
                this.BasicFlashCosine("Lines",Lines, "NewColor", start_color, "steps", Steps, "OneWay", true)
            else
                Steps = Stim.FreqFlashAfter;
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
            if this.a.KeyboardInput == true
                return
            end
            %Get reward valve, pulse number and time:
            switch this.Box.Input_type
                case 3 %Nose
                    switch true
                        case contains(this.WhatDecision, 'left correct', 'IgnoreCase', true)
                            PulseNum = this.Box.LeftPulse;
                            WaitCorrect = @(x)this.a.ReadLeft();
                            REWARD = @(x)this.a.GiveReward("Side",'L');
                        case contains(this.WhatDecision, 'right correct', 'IgnoreCase', true)
                            PulseNum = this.Box.RightPulse;
                            WaitCorrect = @(x)this.a.ReadRight();
                            REWARD = @(x)this.a.GiveReward("Side",'R');
                        case contains(this.WhatDecision, 'wrong', 'IgnoreCase', true)
                            if this.Box.Air_Puff_Penalty
                                PulseNum = this.Box.AirPuffPulses;
                            else
                                return
                            end
                        case contains(this.WhatDecision, 'OC', 'IgnoreCase', true)
                            if this.isLeftTrial
                                PulseNum = this.Box.OCPulse;
                            else
                                PulseNum = this.Box.OCPulse;
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
            while contains(this.WhatDecision, 'correct', 'IgnoreCase', true) && ~WaitCorrect() %Wait for NosePoke Don't dispense the reward unless the mouse is waiting for it! Wait indefinitely between pulses for them to learn to collect all the water
                pause(0.2); drawnow;
                if get(this.Buttons.Stop, 'Value') || get(this.Buttons.FastForward, 'Value')
                    break
                end
            end
            REWARD()
            PulseNum = PulseNum-1;
            % then flash
            this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Tag', 'Contour'),  this.WhatDecision);
            for P = 1:PulseNum
                if P <= PulseNum
                    pause(this.Box.SecBwPulse)
                    while contains(this.WhatDecision, 'correct', 'IgnoreCase', true) && ~WaitCorrect() %Wait for NosePoke Don't dispense the reward unless the mouse is waiting for it! Wait indefinitely between pulses for them to learn to collect all the water
                        pause(0.2); drawnow;
                        if get(this.Buttons.Stop, 'Value') || get(this.Buttons.FastForward, 'Value')
                            break
                        end
                    end
                end
                REWARD()
                this.FlashNew(this.StimulusStruct, this.Box,  findobj(this.fig.Children, 'Tag', 'Contour'),  this.WhatDecision);
            end
        end
        %Use this function instead of pausing, so that buttons are checked and settings are updated during the pause
        function UpdatePause(this, interval)
            starttime = clock;
            while etime(clock, starttime) < interval
                pause(0.1); drawnow;
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
            if ~this.a.KeyboardInput
                switch this.Box.Input_type
                    case 3 % Nose
                        this.ReadyCue(1)
                        this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'ReadyCueDot'), "Make_Bright");
                end
            end
            %Wait for interval
            this.UpdatePause(interval_time);
            this.updateMessageBox();
            if this.Temp_Active
                this.Setting_Struct = this.Temp_Old_Settings;
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
                delete(this.textdiary)
                diary(this.textdiary)
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
            
            if ispc
                savefolder = fullfile([this.Data_Object.filedir{:}, filesep]);
            elseif ismac || isunix
                savefolder = fullfile([this.Data_Object.filedir{:}, filesep]);
            end
            set(this.message_handle,'Text', 'Saving data as: '+saveasname+'.mat');

            % Construct data to save
            [newData] = this.Data_Object.current_data_struct;
            newData = this.ensureColumns(newData);

            % Align data structure lengths
            newData = this.alignDataLengths(newData);

            Settings = [this.Setting_Struct cell2mat(this.Old_Setting_Struct)];
            newData.SetUpdate = this.SetUpdate;
            newData.StimHist = this.filterNonEmptyRows(this.StimHistory);
            newData = this.setDataIndexes(newData, Settings);

            newData.Weight = this.Setting_Struct.Weight;
            Notes = this.GuiHandles.NotesText.String;
            if ~options.RescueData
                f = figure("MenuBar","none","Visible","off");
                copyobj(this.graphFig.Children, f)
                f.Children.Title.String = string(this.Data_Object.Inp)+" "+cell2mat(this.Data_Object.Sub);
            end
            try
                save(fullfile(savefolder, saveasname) + ".mat", 'Settings', 'newData', 'Notes');
                if ~options.RescueData
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
            Idcs = unique([cell2mat(this.SetUpdate), length(newData.TimeStamp)]);
            if Idcs == 0
                Include = 1;
                return
            end
            try
                [~, ~, newData.SetIdx] = histcounts(1:length(newData.TimeStamp), Idcs);
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
            f = figure("MenuBar","none","Visible","off");
            copyobj(this.graphFig.Children, f)
            f.Children.Title.String = string(this.Data_Object.Inp)+" "+cell2mat(this.Data_Object.Sub);
            [file, path] = uiputfile(pwd, 'Choose folder to save training data', saveasname);
            save(fullfile(path, file), 'Settings', 'newData', 'Notes');
            this.saveFigure(f, savefolder, saveasname);
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
            this.getGUI();
            this.Stimulus_Object = BehaviorBoxVisualStimulus(this.StimulusStruct, Preview=1);
            this.Stimulus_Object = this.Stimulus_Object.updateProps(this.StimulusStruct);
            this.Data_Object = BehaviorBoxData( ...
                Inv=this.app.Inv.Value, ...
                Inp=this.app.Box_Input_type.Value, ...
                Str=this.app.Strain.Value, ...
                Sub={this.app.Subject.Value}, ...
                find=1, ...
                load=0);
            if isempty([this.Stimulus_Object.LStimAx this.Stimulus_Object.RStimAx])
                [this.fig,this.LStimAx,this.RStimAx, ~] = this.Stimulus_Object.setUpFigure(); drawnow
                this.Stimulus_Object = this.Stimulus_Object.findfigs();
            end
            [~,~] = this.Stimulus_Object.DisplayOnScreen(this.PickSideForCorrect(0, 0), this.Setting_Struct.Starting_opacity);
            this.fig = this.Stimulus_Object.fig;
            [this.fig.findobj(this.fig.Children, 'Tag','Spotlight').Visible] = deal(1);
            toc
            pause(0.1)
            this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'line'), "Make_Bright")
            if options.SaveStimulus
                name = "Stim-Lv-"+this.Setting_Struct.Starting_opacity;
                this.Data_Object.SaveManyFigures([],name)
            end
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
            keypress = 0; t1 = clock;
            while keypress==0
                pause(0.1); drawnow;
                currkey = input(prompt,"s");
                response_time = etime(clock, t1);
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