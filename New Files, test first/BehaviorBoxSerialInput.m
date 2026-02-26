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

        function SerialReadCallback(this, src, evt)
            % Wrapper for serial callback (callbacks should not rely on outputs).
            try
                this.SerialRead(src, evt);
            catch
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
                    return
                end
                this.ReadingDouble = double(v);
                this.ReadingChar = '0'; % not used, but keep defined
            else
                % Expect single-character tokens: L/M/R/-
                s = strtrim(char(newReading));
                if numel(s) ~= 1
                    if ~this.IgnoreNonData && ~isempty(s)
                        this.ReadingChar = s(1);
                    end
                    return
                end
                if any(s == ['L','M','R','-'])
                    this.ReadingChar = s;
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

            side = upper(strtrim(string(opts.Side)));
            if any(side == ["RIGHT","R"])
                this.sendSerialBytes('R');
            elseif any(side == ["LEFT","L"])
                this.sendSerialBytes('L');
            else
                error('GiveReward:InvalidSide', 'opts.Side must be R/L or Right/Left');
            end

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
                    case 'Off'
                        write(this.Ard, 't', "char");
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
                    case 'Next'
                        write(this.Ard, 'N', "char");
                    case 'End'
                        write(this.Ard, 'i', "char");
                end
            catch
            end
        end

        function SwitchMode(this)
            write(this.Ard, 'M', "char");
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
                catch
                end
            else
                this.ReadingChar = '-';
                this.Reading = "-";
            end
        end

        function delete(this)
            try
                configureCallback(this.Ard, "off");
            catch
            end
            this.Ard = serialport().empty;
            disp('Behavior Serial port is closed');
        end
    end
end
