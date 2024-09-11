classdef BehaviorBoxNose < handle
    %BehaviorBoxNose Class definition with other methods omitted for brevity...

    properties
        % Define necessary properties here...
    end

    methods
        % Constructor, other methods...

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

            if this.Box.Input_type == 6
                this.clearPolygonColors();
            end

            this.processDecision();
        end

        function setupStimulus(this)
            this.ResponseTime = 0;
            this.WhatDecision = 'time out';
            this.DrinkTime = 0;

            o = {this.fig.Children.Children}; % Hide ReadyCue and set background
            validObjs = o(~cellfun(@isempty, o));
            for x = validObjs
                set([x{:}], 'Visible', 1);
            end
            this.fig.Color = this.StimulusStruct.BackgroundColor;
            set(this.fig.findobj('Type', 'line'), 'Color', this.StimulusStruct.LineColor);
            drawnow;
            this.ReadyCue(0);
            drawnow;
        end

        function processIgnoredInput(this)
            tic;
            while this.Setting_Struct.Input_ignored && toc <= this.Setting_Struct.Pokes_ignored_time
                if this.Setting_Struct.ConfirmChoice
                    this.confirmCorrectChoice();
                end
                if this.a.ReadMiddle()
                    this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'Line'), 'NewStim');
                    tic; % Restart the timer to avoid skipping confirmation period
                end
                this.updateInputIgnoredMessage();
                drawnow;
            end
        end

        function confirmCorrectChoice(this)
            if this.a.ReadLeft() && this.isLeftTrial
                this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), 'Correct_Confirmation');
            elseif this.a.ReadRight() && ~this.isLeftTrial
                this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), 'Correct_Confirmation');
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

        function clearPolygonColors(this)
            p = findobj('Type', 'Polygon');
            [p.FaceColor] = deal(this.StimulusStruct.BackgroundColor);
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

            if ~this.Box.KeyboardInput && this.Box.Input_type == 3
                while this.a.ReadLeft() || this.a.ReadRight() % Pause while the mouse is drinking their reward
                    pause(0.5); drawnow;
                end
            end

            this.DrinkTime = toc;
            this.persistCorrectStimulus();
            this.hideStimulus();
        end

        function persistCorrectStimulus(this)
            if this.StimulusStruct.PersistCorrectInterv > 0
                thisInt = this.StimulusStruct.PersistCorrectInterv;
            else
                thisInt = 0;
            end
            set(this.message_handle, 'Text', sprintf('Persisting correct stimulus for %.1f sec...', thisInt));
            drawnow;

            if this.Box.KeyboardInput == 1
                return;
            end

            if this.Box.Input_type == 3 % Nose
                DIST = this.fig.Children(contains({this.fig.Children.Tag}, "Correct")).Children.findobj('Tag', 'Contour');
                tic
                while toc <= thisInt
                    this.FlashNew(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Tag', 'Contour'), 'Correct_Confirmation');
                end
            elseif this.Box.Input_type == 6 % Wheel
                this.updatePause(thisInt);
            end
        end

        function handleWrongDecision(this)
            set(this.message_handle, 'Text', sprintf('%s - Penalty...', this.WhatDecision));
            this.pauseForDrinking();

            if ~get(this.stop_handle, 'Value') && this.StimulusStruct.PersistIncorrect
                this.persistIncorrectStimulus();
            else
                this.hideStimulus();
                this.fig.Color = 'k';
            end
        end

        function persistIncorrectStimulus(this)
            set(this.message_handle,'Text','Persisting correct stimulus...');
            if this.Box.Input_type == 3 % Nose
                thisInt = this.StimulusStruct.PersistIncorrectInterv;
                DIST = this.fig.Children(contains({this.fig.Children.Tag}, "Correct")).Children.findobj('Tag', 'Distractor');
                set(DIST, "Color", this.StimulusStruct.LineColor)
                tic
                while toc <= thisInt
                    this.Flash(this.StimulusStruct, this.Box, DIST, 'Correct_Confirmation')
                end
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
            if ~this.Box.KeyboardInput && this.Box.Input_type == 3
                while this.a.ReadLeft() || this.a.ReadRight() % Pause while the mouse is standing there
                    pause(0.5); drawnow;
                end
            end
        end

        function hideStimulus(this)
            o = findobj(this.fig.Children);
            [o(:).Visible] = deal(0);
        end

        function updatePause(this, interval)
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
    end
end

function [WhatDecision, response_time] = readLeverLoopDigital(this)
    response_time = 0;
    this.DuringTMal = 0;
    event = -1;
    try
        % Reset lick sensor and initialize timers
        this.ResetSensor();
        timeout_value = this.Box.Timeout_after_time;
        response_timer = clock;
        timeout_timer = clock;
        
        % Main loop to wait for actions
        while timeout_value == 0 || etime(clock, timeout_timer) < timeout_value
            pause(0.1); drawnow;
            
            % Check for skip or stop conditions
            if get(this.Skip, 'Value')
                this.Skip.Value = 0; 
                break;
            elseif get(this.stop_handle, 'Value')
                break; 
            end
            
            % Handle middle reading for inter-trial malingering
            if this.a.ReadMiddle()
                this.Flash(this.StimulusStruct, this.Box, findobj(this.fig.Children, 'Type', 'Line'), 'center');
                this.DuringTMal = this.DuringTMal + 1;
            end
            
            % Check for left or right decisions
            if this.a.ReadLeft()
                event = 1; % Left Choice
                break;
            elseif this.a.ReadRight()
                event = 2; % Right Choice
                break;
            end
        end
        
        % Update visual elements after reading
        a = this.fig.findobj("Type", "Axes");
        a = a(contains({a.Tag}, 'Correct'));
        % Update the distractor color to dim
        try
            d = a.findobj("Tag", "Distractor");
            [d.Color] = deal(this.StimulusStruct.DimColor);
        catch
            % Ignore errors related to finding and updating distractors
        end
        
        response_time = etime(clock, response_timer);
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
