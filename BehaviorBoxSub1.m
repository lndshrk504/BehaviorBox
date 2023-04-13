classdef BehaviorBoxSub1 < BehaviorBoxSuper
% 9/12/22 this entire object class is phased out and resorbed into BBSuper. 
% There is no distinction between Trials and Training besides the settings used, which are used to label the data points.

    %BehaviorBox Sub class 1 (Contour Task)
    %====================================================================
    %Sub Class 1 for BehaviorBox Ver1.4
    %This Class is called by the GUI BehaviorBox via RunTrials() and runs
    %the main Trial loop, reads levers, gives rewards,
    %plots data, adjust difficulty depending on performance, etc.
    %It stores data in the BehaviorBoxData.m file/object which is uses to
    %calculate averages, performances, etc.
    %It interacts with class BehaviorBoxVisualStimulus.m to create the
    %visual stimuli.
    %This class inherits from BehaviorBoxSuper from which it overrides some functions with added functionality.
    %Meyer 2015/3
    %THIS FILE IS PART OF A SET OF FILES CONTAINING (ALL NEEDED):
    %BehaviorBox.fig
    %BehaviorBox.m
    %BehaviorBoxData.m
    %BehaviorBoxSub1.m
    %BehaviorBoxSub2.m
    %BehaviorBoxSuper.m
    %BehaviorBoxVisualGratingObject.m
    %BehaviorBoxVisualStimulus.m
    %BehaviorBoxVisualStimulusTraining.m
    %====================================================================
    properties (SetAccess = protected)
%         All are CREATED BY SUPEROBJECT to make easier:
% %Structures of variables:
%         Data_Object;
%         Variable_Struct;
%         Setting_Struct;
%         Old_Setting_Struct; %After the settings are updated, the older ones are stored here for plotting
%         Updated_when;
% %Variables for running training loop:
%         a; %The arduino, easier to find when not buried in variable structure
%         counter_for_alternate;
%         current_side;
%         current_difficulty;
%         duringTrialMalPuffs = 0; %How many airpuffs did the mouse get when they picked the wrong stimulus during the trial?
%         isCorrect = 1;
%         isLeftTrial;
%         is_training; %Set during setup, if 1 run BBSuper loop, if 0 run BBSub1 loop %Use this for the new NosePoke settings.
%         intertrialMalPuffs = 0; %How many times did the mouse go to try and suck water from the Left/Right reward port during the intertrial period instead of starting a new trial?
%         message_handle;
%         response_time;
%         Reward_pulse_count;
%         Side_bias;
%         stop_handle;
%         Stimulus_Object;
%         start_time;
%         timeout_counter;
%         update_handle;
%         variable_counter;
%         WhatDecision;
% %SoundObjs:
%         Sound_start_Object;
%         Sound_start_Left;
%         Sound_start_Right;
%         Sound_wrong_Object;
%         Sound_correct_Object;
%         Sound_cue_Object;
    end
    methods
        %constructor
        function this = BehaviorBoxSub1(GUI_handles, app)
            %call the constructor of the super group to initialize supergroup
            this = this@BehaviorBoxSuper(GUI_handles, app); %BBSuper sets up all the variables and grabs all of the settings
            this.isTraining = 0; %(Overwrites value of 1 from BBSuper)
        end
        % INTERFACE====
        function  RunTrials(this)
            %overwrite DoLoop from super class
            try
                this.DoLoop();
            catch err
                this.unwrapError(err)
                %Save just the data matrix to the pwd
                switch this.Setting_Struct.Stimulus_type
                    case 1
                        str_stim='ContourCrude';
                    case 2
                        str_stim='ContourFine';
                    case 3
                        str_stim='SquarevsOFine';
                    case 4
                        str_stim='SquarevsOCrude';
                    case 5
                        str_stim='unknown';
                    case 6
                        str_stim='XvsO';
                    case 7
                        str_stim='TwoTasksContour';
                    case 8
                        str_stim='CuedImages';
                    case 9
                        str_stim='DistractContour';
                    case 10
                        str_stim='Grating';
                    case 11
                        str_stim='ContourDensity';
                    case 12
                        str_stim='Practice';
                end
                %Input Type?
                switch this.Setting_Struct.Input_type
                    case 1
                        str_input = 'OneLever';
                    case 2
                        str_input = 'TwoLevers';
                    case 3
                        str_input = 'NosePoke';
                    case 4
                        str_input = 'Ball';
                    case 5
                        str_input = 'LickPort';
                    case 6
                        str_input = 'Wheel';
                    case 7
                        str_input = 'GoNoGo';
                end
                try
                    saveasname = [datestr(this.Data_Object.start_time,'yymmdd_HHMMSS_'),num2str(this.Setting_Struct.Subject),'_',this.Setting_Struct.Strain,'_',str_stim,str_input, '.mat'];
                    newData = this.Data_Object.getDataToSave();
                    Settings = [this.Setting_Struct cell2mat(this.Old_Setting_Struct)];
                    newData.SetUpdate = this.SetUpdate;
                    rmv = {'GUI_numbers', 'encoder'};
                    Settings = rmfield(Settings, rmv);
                    newData.Settings = Settings;
                    if this.Setting_Struct.Input_type == 6
                        newData.wheel_record = this.wheelchoice_record;
                        newData.wheel_record(any(cellfun(@isempty, newData.wheel_record)'),:) = [];
                    end
                    [file,path] = uiputfile(pwd , 'Choose folder to save training data' , saveasname);
                    save([path file],  'Settings', 'newData')
                    exportapp(this.app.figure1, [path file '.jpg'])
                catch
                    [file,path] = uiputfile(pwd , 'Choose folder to save training data' , saveasname);
                    save([path file], 'newData')
                end
                this.cleanUP();
            end
        end
        %MEMBER FUNCTIONS====
        %overrides super function DoLoop
        function DoLoop(this) 
        %=====MAIN LOOP===========================
            disp('- - - - -');
            %LOCAL VARIABLES
            rng('shuffle');
            this.SetupTrialSettings();
            this.SetupBeforeLoop();
            if this.Setting_Struct.Ext_trigger %wait for external trigger
                set(this.message_handle,'String','Waiting for trigger to start..');
                while ~this.a.readDigitalPin(this.Setting_Struct.TriggerPin)
                    if this.checkAbort(stop_handle,this.Setting_Struct.GuiHandles.text1)==1
                        close(figure(100))
                        break;
                    end
                end
            end
%RUN trial loop
            for i =  1:this.Setting_Struct.Max_trial_num
                try
                    this.i = i;
                    %check if stop pressed
                    if this.stop_handle.Value
                        this.message_handle.String = 'Ending session...'; close(figure(100)); break; %end
                    end
                    this.BeforeTrial() %Get this.isLeftTrial, this.Reward_pulse_count, this.current_difficulty
                    this.WaitForInput(this); %if the mouse does anything but a center poke, immediately end the trial
                    [this.WhatDecision, this.ResponseTime] = this.WaitForInputAndGiveReward();
                    this.AfterTrial()
                catch err
                    this.unwrapError(err)
                end
            end %END loop            
            this.SaveAllData(this);
            %clean up
            this.cleanUP();
        end  %=====END OF MAIN LOOP===========================
        function [performanceAdjust_counter_raise,performanceAdjust_counter_lower, current_opacity, temp_current_opacity] = adjustDifficulty(this, performanceAdjust_counter_raise, performanceAdjust_counter_lower, current_opacity, temp_current_opacity, upperperformance, lowerperformance, stdthreshold)
            %adjust opacity on performance if needed
            if this.Setting_Struct.DiffAdjustMethod==1
                %if need to raise difficulty is true
                if this.Setting_Struct.Raise_bg_with_perf ==1 && current_opacity == temp_current_opacity 
                    %if counter reaches threshold
                    if  performanceAdjust_counter_raise > this.Setting_Struct.RaiseDiffAfterBins-1
                        %if the mean of the performance is higher than
                        %threshold, adjust
                        [prevMeanresponse,prevStdresponse] = this.Data_Object.WhatWasPrevMeanResponse(this.Setting_Struct.RaiseDiffAfterBins,this.Setting_Struct.sub_bin_size)
                        % Current opacity only rises 1 step above start
                        if current_opacity <= str2double(this.Setting_Struct.GuiHandles.edit2.String)
                            if prevMeanresponse >= upperperformance && prevStdresponse <= stdthreshold && prevMeanresponse ~=-1
                                current_opacity = current_opacity+0.1;
                                temp_current_opacity = current_opacity;
                                if current_opacity > 1
                                    current_opacity = 1;
                                end
                                %reset counter to 0, so you wait at least the number of
                                %bins you average over before you do the next check
                                performanceAdjust_counter_raise = 0;
                                performanceAdjust_counter_lower = 0;
                                this.Data_Object.data_struct.Bin_RightWrongOnly = [];
                            end
                        end
                    end
                    %inc counter
                    performanceAdjust_counter_raise = performanceAdjust_counter_raise +1;
                end
                %if need to lower difficulty
                if this.Setting_Struct.Raise_bg_with_perf ==1 && current_opacity == temp_current_opacity
                    if  performanceAdjust_counter_lower > this.Setting_Struct.LowerDiffAfterBins-1
                        [prevMeanresponse,prevStdresponse] = this.Data_Object.WhatWasPrevMeanResponse(this.Setting_Struct.LowerDiffAfterBins,this.Setting_Struct.sub_bin_size)
                        %Current opacity can only fall 2 steps from start
                        if current_opacity > str2double(this.Setting_Struct.GuiHandles.edit2.String)-0.2
                            if prevMeanresponse <= lowerperformance && prevMeanresponse ~=-1
                                current_opacity = current_opacity-0.1;
                                temp_current_opacity = current_opacity;
                                if current_opacity <0.1
                                    current_opacity = 0.1;
                                    temp_current_opacity = 0.1;
                                end
                                performanceAdjust_counter_lower = 0;
                                performanceAdjust_counter_raise = 0;
                                this.Data_Object.data_struct.Bin_RightWrongOnly = [];
                            %else %Reset the counter even if the difficulty level didn't change to keep changes at incriments of 50
                                %performanceAdjust_counter_raise = 0;
                            end
                        end
                    end
                    %increase counter by one
                    performanceAdjust_counter_lower = performanceAdjust_counter_lower+1;
                end
            end
            %step up difficulty if needed
            if this.Setting_Struct.DiffAdjustMethod==2
                %if the number of trials per step has been reached,
                %increase difficulty
                if mod(this.Setting_Struct.GUI_numbers.choices, this.Setting_Struct.StepUpAfter) == 0
                    current_opacity = current_opacity+0.1;
                    %if larger than 1, start over
                    if current_opacity >1
                        current_opacity = this.Setting_Struct.Starting_opacity;
                    end
                end
            end
            if this.Setting_Struct.DiffAdjustMethod==3
                %randomize difficulty if needed
                %pick random number between the upper and lower range
                %get range of all difficulties as integer
                num_increments =  floor(((this.Setting_Struct.RandomMax*10) -  (this.Setting_Struct.RandomMin*11))/(this.Setting_Struct.RandomStep*10))+2;
                %now get a random number within the range
                % rand_opacity  = floor(rand()*5*10)/10;
                rand_opacity  = floor(rand()*num_increments*10/10);
                %add that to min
                current_opacity = ((round(rand_opacity*(this.Setting_Struct.RandomStep*10)))/10) +this.Setting_Struct.RandomMin;
                if current_opacity >this.Setting_Struct.RandomMax
                    current_opacity = this.Setting_Struct.RandomMax;
                end
            end
        end
        function [Current_Stim_Object] = PresentAllStimulusAspects(this, current_opacity, isLeftTrial, Target_Offset)
            % show cue and play cue sound, if using cued stimulus
%             if this.Setting_Struct.IsCueTrial && this.Setting_Struct.CueOrNot && ~this.Setting_Struct.ErrorSoundOnly
%                 play(this.Sound_cue_Object);
%                 this.ShowCue(this.current_difficulty);
%                 stop(this.Sound_cue_Object);
%             end
            if this.Setting_Struct.Stimulus_type ~= 11 && this.Setting_Struct.Stimulus_type ~= 12 %Everything but contour density
                Current_Stim_Object = this.Variable_Struct(1,1).List_of_stims(int8((current_opacity*10)+isLeftTrial*12));
            elseif this.Setting_Struct.Stimulus_type == 11 || this.Setting_Struct.Stimulus_type == 12 %Contour density 
                Current_Stim_Object = this.Variable_Struct(1,1).List_of_stims(int8(current_opacity*10));
            end
            %display stimulus
            Current_Stim_Object.DisplayOnScreen(1, this.isLeftTrial, this.isCorrect, this.Setting_Struct);
            %add stim on to Stim events
            this.Data_Object.addStimEvent(isLeftTrial);
            if this.Setting_Struct.FlashStim %Flash
                this.Flash(this, this.Setting_Struct.RepFlash, 0)
            end
        end
        end
%STATIC FUNCTIONS====
    methods(Static = true)
        function [WhatDecision] = readLeverLoopDigitalGoNoGo(a, LeverA, LeverB, LeverC, timeout_value, readHigh, stop_handle, message_handle, checkAbortHandle, isLeftTrial)
%returns -1 in case of timeout, 1 in case of LeverA, 2 for B and 3 for C
            start_time = clock;
            event = -1;
            if readHigh == 1
                threshold_read = 1;
            else
                threshold_read = 0;
            end
            while etime(clock, start_time)<timeout_value
                 if checkAbortHandle(stop_handle,message_handle)==1
                    break;
                end
                if a.readDigitalPin(LeverB) == threshold_read
                    if isLeftTrial == 1 %isLeftTrial is used as Go/No-Go
                        event = 1;
                    else
                        event = 2;
                    end
                    break
                end
            end
            switch event
                case -1
                    WhatDecision = 'time out';
                case 1
                    WhatDecision = 'Go, Correct';
                case 2
                    WhatDecision = 'Go, Incorrect';
            end
        end
        function [WhatDecision] = readLeverLoopAnalog(a, LeverA, LeverB, LeverC, encoder, timeout_value, readMultiplied, stop_handle, message_handle, checkAbortHandle, isLeftTrial)
            %returns -1 in case of timeout, 1 in case of LeverA, 2 for B
            %and 3 for C,
            start_time = clock;
            event = -1;
            encStat = isobject(encoder);
            if encStat
                threshold_read = 1 * readMultiplied;
            end
            %run loop that reads until timeout
            while etime(clock, start_time)<timeout_value
                %check if stop pressed
                if checkAbortHandle(stop_handle,message_handle)==1
                    %abort
                    close(figure(100))
                    break;
                end
                enc =  encoder.readCount/100;
                if enc <= -threshold_read
                    %beam A broken
                    event = 1;
                    break
                elseif enc >= threshold_read
                    %beam B broken
                    event = 2;
                    break
                end
            end
            %translate response to decision
            switch event
                case -1
                    WhatDecision = 'time out';
                case 1
                    %-1 is for trainingstrials always correct
                    if isLeftTrial == 1 || isLeftTrial == -1
                        WhatDecision = 'left correct';
                    else
                        WhatDecision = 'left wrong';
                    end
                case 2
                    if isLeftTrial == 0 || isLeftTrial == -1
                        WhatDecision = 'right correct';
                    else
                        WhatDecision = 'right wrong';
                    end
                case 3
                    set(message_handle,'String','Center Poke');
                    WhatDecision = 'center poke';
            end
        end
        function [WhatDecision] = readLeverLoopDigitalOnlyCorrect(a, LeverA, LeverB, LeverC, timeout_value, readHigh, stop_handle, message_handle, checkAbortHandle, isLeftTrial)
%returns -1 in case of timeout, 1 in case of LeverA, 2 for B and 3 for C
            start_time = clock;
            event = -1;
            if readHigh == 1
                threshold_read = 1;
            else
                threshold_read = 0;
            end
            while etime(clock, start_time)<timeout_value
                if checkAbortHandle(stop_handle,message_handle)==1
                    close(figure(100))
                    break;
                end
                if a.readDigitalPin(LeverA) == threshold_read & isLeftTrial %LeverA is left
                    %beam A broken
                    event = 1;
                    break
                elseif a.readDigitalPin(LeverB) == threshold_read  & ~isLeftTrial %LeverB is right
                    %beam B broken
                    event = 2;
                    break
                end
            end
            switch event
%-1 is for trainingstrials, always correct
                case -1
                    WhatDecision = 'time out';
                case 1
                    if isLeftTrial ==1 ||isLeftTrial == -1
                        WhatDecision = 'left correct';
                    else
                        WhatDecision = 'left wrong';
                    end
                case 2
                    if isLeftTrial ==0 ||isLeftTrial == -1
                        WhatDecision = 'right correct';
                    else
                        WhatDecision = 'right wrong';
                    end
                case 3
                    set(message_handle,'String','Center Poke');
                    WhatDecision = 'center poke';
            end
        end
        function [WhatDecision] = readLeverLoopAnalogOnlyCorrect(a, LeverA, LeverB, LeverC, encoder, timeout_value, readMultiplied, stop_handle, message_handle, checkAbortHandle, isLeftTrial)
            %returns -1 in case of timeout, 1 in case of LeverA, 2 for B
            %and 3 for C,
            start_time = clock;
            event = -1;
            encStat = isobject(encoder);
            if encStat
                threshold_read = 1 * readMultiplied;
            end
            %run loop that reads until timeout
            while etime(clock, start_time)<timeout_value
                %check if stop pressed
                if checkAbortHandle(stop_handle,message_handle)==1
                    %abort
                    close(figure(100))
                    break;
                end
                enc =  encoder.readCount/100;
                if enc <= -threshold_read
                    %beam A broken
                    event = 1;
                    break
                elseif enc >= threshold_read
                    %beam B broken
                    event = 2;
                    break
                end
            end
            %translate response to decision
            switch event
                case -1
                    WhatDecision = 'time out';
                case 1
                    %-1 is for trainingstrials always correct
                    if isLeftTrial == 1 || isLeftTrial == -1
                        WhatDecision = 'left correct';
                    else
                        WhatDecision = 'left wrong';
                    end
                case 2
                    if isLeftTrial == 0 || isLeftTrial == -1
                        WhatDecision = 'right correct';
                    else
                        WhatDecision = 'right wrong';
                    end
                case 3
                    set(message_handle,'String','Center Poke');
                    WhatDecision = 'center poke';
            end
        end
    end
end