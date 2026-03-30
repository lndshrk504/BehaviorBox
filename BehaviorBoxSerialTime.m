classdef BehaviorBoxSerialTime < handle
    %
    % WBS Mar - 10 - 2026
    %
    % ScanImage frame clocks are recorded by an Arduino (Timekeeper.ino).
    %
    
    properties
        Ard %= serialport().empty
        DispOutput logical = false % This helps to debug
        Log string = string.empty(0,1)
        RawLog string = string.empty(0,1)
        ParsedLog table = table( ...
            'Size', [0 10], ...
            'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'string', 'double', 'string', 'double', 'double'}, ...
            'VariableNames', {'kind', 't_us', 't_arduino_us', 't_pc_receive_us', 'frame', 'event', 'trial', 'side', 'correct', 'rewardPulse'})
        % Last raw line (debug)
        Reading string = ""
        TrainStartTime = []
        TrainStartWallClock = NaT
        SegmentHardwareAnchorArduinoUs double = NaN
        SegmentHardwareAnchorPcUs double = NaN
    end

    methods
        function this = BehaviorBoxSerialTime(port, baudRate)
            arguments
                port char = 'COM4'
                baudRate double = 115200
            end
            try
                this.Ard = serialport(port, baudRate, "Timeout", 0.5);
                this.Ard.InputBufferSize = 1048576; % 1 MB
                configureTerminator(this.Ard, "CR/LF");
                configureCallback(this.Ard, "terminator", @this.SerialRead);
            catch
                disp('Serial connection failed.')
            end
        end

        function Reading = SerialRead(this, src, ~)
            % Used for Callback that reads when a line is sent to serial
            arguments
                this
                src = this.Ard
                ~
            end
            try
                if src.NumBytesAvailable == 0
                    Reading = this.Reading;
                    return
                end
            catch
                Reading = this.Reading;
                return
            end
            % Read data from the serial port
            newReading = strtrim(string(readline(src)));
            Reading = this.processReading(newReading);
            % Display the output if DispOutput is true
            if this.DispOutput
                disp(Reading);
            end
            this.Reading = Reading;
        end

        function result = processReading(this, newReading)
        % Store the raw line and parse it into a structured table row.
            arguments
                this
                newReading string
            end
            result = newReading;
            if strlength(strtrim(newReading)) > 0
                this.appendLogLine_(newReading);
            end
        end

        function LogEvent(this, eventName, fields)
            arguments
                this
                eventName string
                fields struct = struct()
            end
            if ~isfield(fields, 't_us') || isempty(fields.t_us) || any(isnan(double(fields.t_us)))
                fields.t_us = this.currentTrainMicros_();
            end
            line = BehaviorBoxSerialTime.formatEventLine_(eventName, fields);
            this.appendLogLine_(line);
        end
        
        function Reset(this)
            % Reset the in-memory raw and parsed logs for the current segment.
            this.Log = string.empty(0,1);
            this.RawLog = string.empty(0,1);
            this.ParsedLog = BehaviorBoxSerialTime.emptyParsedLog_();
            this.Reading = "";
            this.SegmentHardwareAnchorArduinoUs = NaN;
            this.SegmentHardwareAnchorPcUs = NaN;
        end

        function Who(this)
            this.DispOutput = true;
            writeline(this.Ard, 'W');
            pause(1); % Pause for a moment to allow data to be loaded into the buffer
            while this.Ard.NumBytesAvailable > 0
                disp(readline(this.Ard));
            end
            this.DispOutput = false;
        end

        function response = CheckFrame(this, timeoutSeconds)
            arguments
                this
                timeoutSeconds double = 1
            end
            if isempty(this.Ard)
                error('BehaviorBoxSerialTime:NotConnected', ...
                    'Timestamp serial port is not connected.');
            end
            startCount = numel(this.RawLog);
            write(this.Ard, 'F', "char");
            response = "";
            tStart = tic;
            while toc(tStart) < timeoutSeconds
                drawnow limitrate
                if numel(this.RawLog) > startCount
                    newLines = this.RawLog(startCount+1:end);
                    idx = find(contains(newLines, "Debug Frame count:"), 1, 'last');
                    if ~isempty(idx)
                        response = newLines(idx);
                        disp(response);
                        return
                    end
                end
                pause(0.02)
            end
            warning('BehaviorBoxSerialTime:CheckFrameTimeout', ...
                'No frame-count response was received within %.2f seconds.', timeoutSeconds);
        end

        function UpdateProps(this, BoxStruct)
            arguments
                this
                BoxStruct = struct
            end
            for f = fieldnames(BoxStruct)'
                this.(f{:}) = BoxStruct.(f{:});
            end
        end

        function delete(this)
            % Ensure the serial port is released immediately.
            % Serial callbacks can keep objects alive unless we tear down the
            % underlying serialport explicitly.
            try
                if ~isempty(this.Ard)
                    try
                        configureCallback(this.Ard, "off");
                    catch
                    end
                    try
                        flush(this.Ard);
                    catch
                    end
                    try
                        delete(this.Ard);
                    catch
                    end
                end
            catch
            end
            this.Ard = serialport().empty;
            disp('Timestamp Serial port is closed');
        end
    end

    methods (Access = private)
        function t_us = currentTrainMicros_(this)
            t_us = NaN;
            if isempty(this.TrainStartTime)
                return
            end
            try
                t_us = round(toc(this.TrainStartTime) * 1e6);
            catch
            end
        end

        function appendLogLine_(this, line)
            line = strtrim(string(line));
            if strlength(line) == 0
                return
            end

            this.RawLog(end+1,1) = line;
            this.Log = this.RawLog;
            receiveT_us = this.currentTrainMicros_();
            this.ParsedLog = [this.ParsedLog; this.parseLogLine_(line, receiveT_us)];
        end

        function t_us = hybridHardwareMicros_(this, arduinoT_us, pcReceiveT_us)
            t_us = pcReceiveT_us;
            if isnan(arduinoT_us)
                return
            end
            if isnan(this.SegmentHardwareAnchorArduinoUs) || isnan(this.SegmentHardwareAnchorPcUs)
                this.SegmentHardwareAnchorArduinoUs = double(arduinoT_us);
                this.SegmentHardwareAnchorPcUs = double(pcReceiveT_us);
                t_us = double(pcReceiveT_us);
                return
            end
            t_us = round(this.SegmentHardwareAnchorPcUs + (double(arduinoT_us) - this.SegmentHardwareAnchorArduinoUs));
        end

        function row = parseLogLine_(this, line, receiveT_us)
            line = strtrim(string(line));
            txt = char(line);

            frameTokens = regexp(txt, '^(\d+),\s*F\s+(\d+)$', 'tokens', 'once');
            if ~isempty(frameTokens)
                arduinoT_us = str2double(frameTokens{1});
                canonicalT_us = this.hybridHardwareMicros_(arduinoT_us, receiveT_us);
                row = BehaviorBoxSerialTime.parsedRow_( ...
                    "frame", canonicalT_us, arduinoT_us, receiveT_us, str2double(frameTokens{2}), "", NaN, "", NaN, NaN);
                return
            end

            stimTokens = regexp(txt, '^S\s+(On|Off)\s+(\d+)$', 'tokens', 'once');
            if ~isempty(stimTokens)
                if strcmpi(stimTokens{1}, 'On')
                    eventName = "stim_on";
                else
                    eventName = "stim_off";
                end
                arduinoT_us = str2double(stimTokens{2});
                canonicalT_us = this.hybridHardwareMicros_(arduinoT_us, receiveT_us);
                row = BehaviorBoxSerialTime.parsedRow_( ...
                    "signal", canonicalT_us, arduinoT_us, receiveT_us, NaN, eventName, NaN, "", NaN, NaN);
                return
            end

            tokenPairs = regexp(txt, '([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)', 'tokens');
            if isempty(tokenPairs)
                row = BehaviorBoxSerialTime.parsedRow_("raw", receiveT_us, NaN, receiveT_us, NaN, "", NaN, "", NaN, NaN);
                return
            end

            tokenMap = struct();
            for iToken = 1:numel(tokenPairs)
                tokenMap.(tokenPairs{iToken}{1}) = string(tokenPairs{iToken}{2});
            end

            kind = BehaviorBoxSerialTime.readStringField_(tokenMap, 'kind', "annotation");
            eventName = BehaviorBoxSerialTime.readStringField_(tokenMap, 'event', "");
            t_us = BehaviorBoxSerialTime.readNumericField_(tokenMap, 't_us');
            if isnan(t_us)
                t_us = receiveT_us;
            end
            frame = BehaviorBoxSerialTime.readNumericField_(tokenMap, 'frame');
            trial = BehaviorBoxSerialTime.readNumericField_(tokenMap, 'trial');
            side = BehaviorBoxSerialTime.readStringField_(tokenMap, 'side', "");
            correct = BehaviorBoxSerialTime.readNumericField_(tokenMap, 'correct');
            rewardPulse = BehaviorBoxSerialTime.readNumericField_(tokenMap, 'rewardPulse');

            row = BehaviorBoxSerialTime.parsedRow_(kind, t_us, NaN, receiveT_us, frame, eventName, trial, side, correct, rewardPulse);
        end
    end

    methods (Static, Access = private)
        function tbl = emptyParsedLog_()
            tbl = table( ...
                'Size', [0 10], ...
                'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'string', 'double', 'string', 'double', 'double'}, ...
                'VariableNames', {'kind', 't_us', 't_arduino_us', 't_pc_receive_us', 'frame', 'event', 'trial', 'side', 'correct', 'rewardPulse'});
        end

        function row = parsedRow_(kind, t_us, t_arduino_us, t_pc_receive_us, frame, eventName, trial, side, correct, rewardPulse)
            row = table( ...
                string(kind), ...
                double(t_us), ...
                double(t_arduino_us), ...
                double(t_pc_receive_us), ...
                double(frame), ...
                string(eventName), ...
                double(trial), ...
                string(side), ...
                double(correct), ...
                double(rewardPulse), ...
                'VariableNames', {'kind', 't_us', 't_arduino_us', 't_pc_receive_us', 'frame', 'event', 'trial', 'side', 'correct', 'rewardPulse'});
        end

        function value = readNumericField_(tokenMap, fieldName)
            value = NaN;
            if ~isfield(tokenMap, fieldName)
                return
            end
            value = str2double(tokenMap.(fieldName));
        end

        function value = readStringField_(tokenMap, fieldName, defaultValue)
            value = string(defaultValue);
            if ~isfield(tokenMap, fieldName)
                return
            end
            value = string(tokenMap.(fieldName));
        end

        function line = formatEventLine_(eventName, fields)
            if ~isfield(fields, 'kind') || isempty(fields.kind)
                fields.kind = "annotation";
            end

            tokens = [
                "kind=" + BehaviorBoxSerialTime.encodeValue_(fields.kind)
                "event=" + BehaviorBoxSerialTime.encodeValue_(eventName)
            ];

            preferredOrder = ["t_us", "trial", "side", "correct", "rewardPulse", "frame", ...
                "level", "choice", "decision", "trialStartTime", "responseTime", ...
                "rewardPulses", "scanImageFile"];
            fieldNames = string(fieldnames(fields));
            fieldNames = fieldNames(fieldNames ~= "kind");

            orderedNames = string.empty(0,1);
            for name = preferredOrder
                if any(fieldNames == name)
                    orderedNames(end+1,1) = name; %#ok<AGROW>
                end
            end
            remainingNames = sort(fieldNames(~ismember(fieldNames, orderedNames)));
            orderedNames = [orderedNames; remainingNames(:)];

            for name = orderedNames'
                tokens(end+1,1) = name + "=" + BehaviorBoxSerialTime.encodeValue_(fields.(name)); %#ok<AGROW>
            end

            line = strjoin(tokens, " ");
        end

        function token = encodeValue_(value)
            if isstring(value) || ischar(value)
                token = regexprep(strtrim(string(value)), '\s+', '_');
            elseif islogical(value)
                token = string(double(value));
            elseif isnumeric(value)
                if isempty(value) || (isscalar(value) && isnan(value))
                    token = "nan";
                elseif isscalar(value)
                    token = string(value);
                else
                    token = regexprep(mat2str(value), '\s+', '');
                end
            else
                token = regexprep(strtrim(string(value)), '\s+', '_');
            end
        end
    end
end
