classdef BehaviorBoxSerialInput < handle
    % WBS 10 - 10 - 2024
    % The NosePoke uses an Arduino programmed with Photogate.ino.
    % The Wheel uses an Arduino programmed with Rotary.ino.
    %
    % =======================
    % Key changes:
    %   1) Cached parsed readings so your hot loops can read properties
    %      directly (no per-iteration str2double / strcmp on long strings):
    %         - ReadingChar   : Nose tokens ('L','M','R','-')
    %         - ReadingDouble : Wheel numeric value (double)
    %   2) Robust parsing: ignore non-data serial lines (Arduino debug prints)
    %      so they can't poison Reading.
    %   3) Use serialport's NumBytesAvailable (not legacy BytesAvailable).

    properties
        Ard = serialport().empty

        % Mode
        Input_type char = 'NosePoke'  % 'Wheel' or 'NosePoke'
        UseCallback logical = true

        % Debug (printing to MATLAB console is very slow)
        DispOutput logical = true

        % Cached readings (fast path)
        ReadingChar char = '-'        % Nose tokens
        ReadingDouble double = 0      % Wheel numeric value

        % Back-compat / debugging (last raw line, as string)
        Reading string = ""

        % Hardware/box params (kept from original)
        use_wheel logical = false
        KeyboardInput logical = false
        Two_ports logical = false
        Left = 'D4'
        Middle = 'D5'
        Right = 'D6'
        ValveL = 'D7'
        ValveR = 'D8'
        Timestamp = 'D9'
        Lrewardtime double = 0.05
        Rrewardtime double = 0.05
        Pulse double = 1
        SecBwPulse double = 0.2

        % Parsing behavior
        IgnoreNonData logical = true

        % Serial receive buffer for byte-based callback parsing
        RxBuffer char = ''

        % Serial debug logging
        Debug_SerialLogMode string = "memory"
        DebugWorkflow string = ""
        DebugSessionSaveFolder string = ""
        DebugMaxHistoryRows double = 500
        DebugMaxHistoryMinutes double = 10
        DebugHistory table = table( ...
            'Size', [0 9], ...
            'VariableTypes', repmat({'string'}, 1, 9), ...
            'VariableNames', {'timestamp', 'direction', 'port', 'commandName', 'rawValue', 'eventType', 'status', 'matchKey', 'details'})
        DebugHistoryTime double = zeros(0,1)
        DebugLogFile string = ""
    end

    methods
        function this = BehaviorBoxSerialInput(port, baudRate, Input_type)
            arguments
                port char = 'COM4'
                baudRate double = 115200
                Input_type char = 'NosePoke'
            end
            this.Input_type = Input_type;

            try
                this.Ard = serialport(port, baudRate, "Timeout", 2);
                configureTerminator(this.Ard, "LF");
                flush(this.Ard);
                if this.UseCallback
                    % Byte callback is robust to mixed line endings and partial lines.
                    configureCallback(this.Ard, "byte", 1, @(src, evt) this.SerialReadCallback(src, evt));
                else
                    configureCallback(this.Ard, "off");
                end
            catch err
                disp('Serial connection failed.')
            end
            if strcmpi(this.Input_type, 'Wheel')
                this.DispOutput = true;
                this.ReadingChar = '0';
                this.ReadingDouble = 0;
                this.Reading = "0";
            else
                this.DispOutput = true;
                this.ReadingChar = '-';
                this.ReadingDouble = 0;
                this.Reading = "-";
            end
        end

        function configureDebugLogging(this, opts)
            arguments
                this
                opts.Mode = "memory"
                opts.Workflow = ""
                opts.SessionSaveFolder = ""
                opts.MaxHistoryRows double = 500
                opts.MaxHistoryMinutes double = 10
            end
            this.Debug_SerialLogMode = BehaviorBoxSerialDebug.normalizeMode(opts.Mode);
            this.DebugWorkflow = string(opts.Workflow);
            this.DebugSessionSaveFolder = string(opts.SessionSaveFolder);
            this.DebugMaxHistoryRows = double(opts.MaxHistoryRows);
            this.DebugMaxHistoryMinutes = double(opts.MaxHistoryMinutes);
            this.DebugLogFile = "";
        end

        function setDebugSessionSaveFolder(this, folder)
            this.DebugSessionSaveFolder = string(folder);
            this.DebugLogFile = "";
        end

        function flushDebugFailureArtifact(this, failureContext)
            arguments
                this
                failureContext struct = struct()
            end
            if BehaviorBoxSerialDebug.normalizeMode(this.Debug_SerialLogMode) ~= "failure"
                return
            end
            try
                [jsonFile, csvFile] = BehaviorBoxSerialDebug.failureArtifactPaths(this.DebugSessionSaveFolder, class(this));
                metadata = this.buildFailureMetadata_(failureContext);
                BehaviorBoxSerialDebug.writeJson(jsonFile, metadata);
                BehaviorBoxSerialDebug.writeCsv(csvFile, this.DebugHistory);
            catch err
                warning('BehaviorBoxSerialInput:DebugFlushFailed', ...
                    'Failed to write serial debug failure artifact: %s', err.message);
            end
        end

        function SerialReadCallback(this, src, evt)
            % Wrapper for serial callback (callbacks should not rely on outputs).
            try
                this.SerialRead(src, evt);
            catch err
                this.appendDebugEvent_("", "", "error", "parse_error", "", ...
                    "SerialReadCallback:" + string(err.message), "parser");
                % Keep callback alive even if one parse event fails.
            end
        end

        function out = SerialRead(this, varargin)
            % Callback or polling read. Updates cached readings.
            src = this.Ard;
            if nargin >= 2 && ~isempty(varargin{1})
                src = varargin{1};
            end

            out = this.readingForOutput();
            try
                nBytes = src.NumBytesAvailable;
            catch
                return
            end
            if nBytes == 0
                return
            end

            rawChars = read(src, nBytes, "char");
            this.consumeRawChars(rawChars);

            if this.DispOutput
                trimChars = regexprep(rawChars, '\r\n|\r|\n', '');
                disp(trimChars);
            end
            out = this.readingForOutput();
        end

        function consumeRawChars(this, rawChars)
            % Parse incoming stream into newline-delimited records.
            if isempty(rawChars)
                return
            end
            this.RxBuffer = [this.RxBuffer, char(rawChars)];

            while true
                lfIdx = find(this.RxBuffer == char(10), 1, 'first');
                if isempty(lfIdx)
                    break
                end

                line = this.RxBuffer(1:lfIdx-1);
                this.RxBuffer = this.RxBuffer(lfIdx+1:end);

                if ~isempty(line) && line(end) == char(13)
                    line(end) = [];
                end

                this.appendDebugEvent_("", string(line), "raw line receive", "ok", "", "", "rx");
                this.processReading(string(line));
            end
        end

        function out = readingForOutput(this)
            % Legacy behavior: return a char-like token (NosePoke) or numeric
            % string (Wheel) so older code using str2double(this.a.SerialRead)
            % continues to work.
            if strcmpi(this.Input_type, 'Wheel')
                out = char(string(this.ReadingDouble));
            else
                out = this.ReadingChar;
            end
        end

        function processReading(this, newReading)
            % Parse and cache. Ignore non-data lines when IgnoreNonData=true.
            if isempty(newReading)
                return
            end
            this.Reading = string(newReading);

            if strcmpi(this.Input_type, 'Wheel')
                % Expect a number per line. Ignore any non-numeric debug text.
                v = sscanf(strtrim(char(newReading)), '%f', 1);
                if isempty(v)
                    if ~this.IgnoreNonData
                        this.ReadingDouble = NaN;
                    end
                    this.appendDebugEvent_("WheelReading", newReading, "parsed event", "unmatched", "", ...
                        "ignored non-numeric wheel line", "parser");
                    return
                end
                this.ReadingDouble = double(v);
                this.ReadingChar = '0'; % not used, but keep defined
                this.appendDebugEvent_("WheelReading", string(this.ReadingDouble), "parsed event", "ok", "", "", "parser");
            else
                % Expect single-character tokens: L/M/R/-
                s = strtrim(char(newReading));
                if numel(s) ~= 1
                    if ~this.IgnoreNonData && ~isempty(s)
                        this.ReadingChar = s(1);
                    end
                    this.appendDebugEvent_("NoseToken", newReading, "parsed event", "unmatched", "", ...
                        "ignored multi-character nose line", "parser");
                    return
                end
                if any(s == ['L','M','R','-'])
                    this.ReadingChar = s;
                    this.appendDebugEvent_("NoseToken", string(s), "parsed event", "ok", "", "", "parser");
                else
                    this.appendDebugEvent_("NoseToken", string(s), "parsed event", "unmatched", "", ...
                        "unknown nose token", "parser");
                end
            end
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

        function UpdateProps(this, BoxStruct)
            arguments
                this
                BoxStruct = struct
            end
            for f = fieldnames(BoxStruct)'
                this.(f{:}) = BoxStruct.(f{:});
            end
        end

        function SetupReward(this, opts)
            arguments
                this
                opts.DurationRight = this.Rrewardtime
                opts.DurationLeft = this.Lrewardtime
                opts.Which = "Right"
            end
            this.DispOutput = true;

            which = upper(strtrim(string(opts.Which)));
            sendRight = any(which == ["RIGHT","R","BOTH"]);
            sendLeft  = any(which == ["LEFT","L","BOTH"]);

            durationRight = strtrim(char(string(opts.DurationRight)));
            durationLeft  = strtrim(char(string(opts.DurationLeft)));

            if sendRight
                this.sendSerialBytes(['s', durationRight, char(10)]);
            end
            if sendLeft
                this.sendSerialBytes(['S', durationLeft, char(10)]);
            end

            this.Rrewardtime = str2double(string(opts.DurationRight));
            this.Lrewardtime = str2double(string(opts.DurationLeft));
            pause(0.1);
            if ~this.UseCallback
                this.SerialRead();
            end
            this.DispOutput = false;
        end

        function GiveReward(this, opts)
            arguments
                this
                opts.Side = 'R'
            end
            if strcmpi(this.Input_type, 'Wheel')
                this.DispOutput = true;
            end

            % side = upper(strtrim(string(opts.Side)));
            % if any(side == ["RIGHT","R"])
            %     this.sendSerialBytes('R');
            % elseif any(side == ["LEFT","L"])
            %     this.sendSerialBytes('L');
            % else
            %     error('GiveReward:InvalidSide', 'opts.Side must be R/L or Right/Left');
            % end

            this.sendSerialBytes(char(opts.Side));

            if ~this.UseCallback
                pause(0.05);
                this.SerialRead();
            end
            if strcmpi(this.Input_type, 'Wheel')
                this.DispOutput = false;
            end
        end

        function sendSerialBytes(this, payload)
            % Send raw bytes to serial device (robust across MATLAB versions).
            if isempty(this.Ard)
                error('BehaviorBoxSerialInput:NoSerial', 'Serial device is not initialized.');
            end

            bytes = uint8(payload);
            if isempty(bytes)
                return
            end
            writeline(this.Ard, payload);
            this.appendDebugEvent_(this.commandNameForPayload_(payload), string(payload), "command send", "ok", "", "", "tx");
        end

        function TimeStamp(this, Type)
            arguments
                this
                Type char = 'On'
            end
            try
                switch Type
                    case 'On'
                        write(this.Ard, "T", "char");
                        this.appendDebugEvent_("TimestampOn", "T", "command send", "ok", "", "", "tx");
                    case 'Off'
                        write(this.Ard, 't', "char");
                        this.appendDebugEvent_("TimestampOff", "t", "command send", "ok", "", "", "tx");
                end
            catch
            end
            pause(0.3);
        end

        % function result = processReading(~, newReading)
        %     result = char(newReading);
        %     % if strcmp(this.Input_type, 'Wheel')
        %     %     %result = str2double(newReading);
        %     %     result = char(newReading);
        %     % else
        %     %     result = char(newReading);
        %     % end
        % end
       
        % ---------- Fast getters (use these in tight loops) ----------
        function v = ReadWheel(this)
            v = this.ReadingDouble;
        end

        function LeftRead = ReadLeft(this)
            reading = this.ReadingChar; % cached single-char token
            LeftRead = (reading == 'L');
        end

        function RightRead = ReadRight(this)
            reading = this.ReadingChar; % cached single-char token
            RightRead = (reading == 'R');
        end

        function MiddleRead = ReadMiddle(this)
            reading = this.ReadingChar; % cached single-char token
            MiddleRead = (reading == 'M');
        end

        function NoneRead = ReadNone(this)
            reading = this.ReadingChar; % cached single-char token
            NoneRead = (reading ~= '-');
            % To match behavior this one is flipped, because it is only
            % used for the flashing while waiting for input
        end

        function Acquisition(this, Type)
            % Sends a char over serial; Arduino pulses a pin.
            arguments
                this
                Type char = 'Next'
            end
            try
                switch Type
                    case 'Start'
                        write(this.Ard, 'I', "char");
                        this.appendDebugEvent_("AcquisitionStart", "I", "command send", "ok", "", "", "tx");
                    case 'Next'
                        write(this.Ard, 'N', "char");
                        this.appendDebugEvent_("AcquisitionNext", "N", "command send", "ok", "", "", "tx");
                    case 'End'
                        write(this.Ard, 'i', "char");
                        this.appendDebugEvent_("AcquisitionEnd", "i", "command send", "ok", "", "", "tx");
                end
            catch
            end
        end

        function SwitchMode(this)
            write(this.Ard, 'M', "char");
            this.appendDebugEvent_("SwitchMode", "M", "command send", "ok", "", "", "tx");
            this.ReadingDouble = 0;
            this.Reading = "0";
        end
        
        function Reset(this)
            % Assign neutral value + tell Arduino (Wheel) to reset encoder.
            if strcmpi(this.Input_type, 'Wheel')
                this.ReadingDouble = 0;
                this.Reading = "0";
                this.ReadingChar = '0';
                try
                    flush(this.Ard);
                catch
                end
                try
                    write(this.Ard, '0', 'char');
                    this.appendDebugEvent_("ResetWheel", "0", "command send", "ok", "", "", "tx");
                catch
                end
            else
                this.ReadingChar = '-';
                this.Reading = "-";
            end
        end

        function delete(this)
            % Ensure the serial port is released immediately.
            % Important: callbacks can create reference cycles (serialport -> callback -> this)
            % that keep the port busy unless the serialport itself is deleted.
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
            disp('Behavior Serial port is closed');
        end
    end

    methods (Access = private)
        function appendDebugEvent_(this, commandName, rawValue, eventType, status, matchKey, details, direction)
            timestampDt = datetime('now', 'TimeZone', 'local');
            row = BehaviorBoxSerialDebug.makeRow( ...
                BehaviorBoxSerialDebug.formatTimestamp(timestampDt), ...
                string(direction), ...
                this.currentPort_(), ...
                string(commandName), ...
                string(rawValue), ...
                string(eventType), ...
                string(status), ...
                string(matchKey), ...
                string(details));

            this.DebugHistory = [this.DebugHistory; row];
            this.DebugHistoryTime(end+1, 1) = posixtime(timestampDt);
            this.trimDebugHistory_();

            if BehaviorBoxSerialDebug.normalizeMode(this.Debug_SerialLogMode) == "file"
                try
                    if strlength(this.DebugLogFile) == 0
                        [this.DebugLogFile, ~] = BehaviorBoxSerialDebug.continuousCsvPath(this.DebugSessionSaveFolder, class(this));
                    end
                    BehaviorBoxSerialDebug.appendCsvRow(this.DebugLogFile, row);
                catch err
                    warning('BehaviorBoxSerialInput:DebugLogWriteFailed', ...
                        'Failed to append serial debug row: %s', err.message);
                    this.Debug_SerialLogMode = "memory";
                    this.DebugLogFile = "";
                end
            end
        end

        function trimDebugHistory_(this)
            if isempty(this.DebugHistoryTime)
                return
            end

            maxRows = max(1, round(this.DebugMaxHistoryRows));
            while height(this.DebugHistory) > maxRows
                this.DebugHistory(1, :) = [];
                this.DebugHistoryTime(1, :) = [];
            end

            cutoff = posixtime(datetime('now', 'TimeZone', 'local') - minutes(this.DebugMaxHistoryMinutes));
            while ~isempty(this.DebugHistoryTime) && this.DebugHistoryTime(1) < cutoff
                this.DebugHistory(1, :) = [];
                this.DebugHistoryTime(1, :) = [];
            end
        end

        function portName = currentPort_(this)
            portName = "";
            try
                if ~isempty(this.Ard)
                    portName = string(this.Ard.Port);
                end
            catch
                portName = "";
            end
        end

        function metadata = buildFailureMetadata_(this, failureContext)
            failureContext = this.normalizeFailureContext_(failureContext);
            metadata = struct( ...
                'SchemaVersion', 'v1', ...
                'GeneratedAt', char(BehaviorBoxSerialDebug.formatTimestamp(datetime('now', 'TimeZone', 'local'))), ...
                'Workflow', char(this.DebugWorkflow), ...
                'FailureIdentifier', char(failureContext.FailureIdentifier), ...
                'FailureMessage', char(failureContext.FailureMessage), ...
                'SessionSaveFolder', char(this.DebugSessionSaveFolder), ...
                'LogMode', char(BehaviorBoxSerialDebug.normalizeMode(this.Debug_SerialLogMode)), ...
                'MaxHistoryRows', double(this.DebugMaxHistoryRows), ...
                'MaxHistoryMinutes', double(this.DebugMaxHistoryMinutes), ...
                'EventRowCount', double(height(this.DebugHistory)), ...
                'ClassName', class(this), ...
                'FailureSource', char(failureContext.FailureSource), ...
                'TopStackFrame', char(failureContext.TopStackFrame));
        end

        function failureContext = normalizeFailureContext_(~, failureContext)
            defaults = struct( ...
                'FailureIdentifier', "BehaviorBox:UnknownFailure", ...
                'FailureMessage', "Unknown failure", ...
                'FailureSource', "Fallback", ...
                'TopStackFrame', "");
            for f = string(fieldnames(defaults))'
                if ~isfield(failureContext, f) || isempty(failureContext.(f))
                    failureContext.(f) = defaults.(f);
                else
                    failureContext.(f) = string(failureContext.(f));
                end
            end
        end

        function commandName = commandNameForPayload_(~, payload)
            payload = char(payload);
            if isempty(payload)
                commandName = "";
                return
            end
            switch payload(1)
                case 'W'
                    commandName = "Who";
                case 's'
                    commandName = "SetupRewardRight";
                case 'S'
                    commandName = "SetupRewardLeft";
                case 'R'
                    commandName = "GiveRewardRight";
                case 'L'
                    commandName = "GiveRewardLeft";
                case 'T'
                    commandName = "TimestampOn";
                case 't'
                    commandName = "TimestampOff";
                case 'I'
                    commandName = "AcquisitionStart";
                case 'N'
                    commandName = "AcquisitionNext";
                case 'i'
                    commandName = "AcquisitionEnd";
                case 'M'
                    commandName = "SwitchMode";
                case '0'
                    commandName = "ResetWheel";
                otherwise
                    commandName = "SerialCommand";
            end
        end
    end
end
