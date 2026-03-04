classdef BehaviorBoxSerialTime < handle
    %
    % WBS May - 27 - 2025
    %
    % ScanImage frame clocks are recorded by an Arduino (Timekeeper.ino).
    %
    % =======================
    % REVISED (speed-first)
    % =======================
    % Key changes:
    %   - Store timestamps in numeric arrays (uint64/uint32) instead of a
    %     growing string array (Log), which is costly for long imaging runs.
    %   - Parse lines without regex; ignore non-data banner lines.
    %
    % NOTE: Provided as *_Revised for diff/merge. In MATLAB, class name and
    % file name must match; to run it, merge changes into the original file.

    properties
        Ard = serialport.empty
        DispOutput logical = false % This helps to debug
        Log string = {}
        % Last raw line (debug)
        Reading string = ""
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
            newReading = readline(src);
            Reading = this.processReading(newReading);
            % Display the output if DispOutput is true
            if this.DispOutput
                disp(Reading);
            end
            this.Reading = Reading;
        end

        function result = processReading(this, newReading)
        % This stores the value of newReading in this.TimestampLog
        % and returns the value of newReading
            arguments
                this
                newReading string
            end
            result = newReading;
            if ~isempty(newReading)
                this.Log(end+1,1) = newReading;
            end

        end
        
        function Reset(this)
            % Set the timestamp log to empty
            this.Log = {};
            % and the reading to 0
            this.Reading = [];
            % Reset the Arduino
            % writeline(this.Ard, '0', 'char')
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
            this.Ard = serialport.empty;
            disp('Timestamp Serial port is closed');
        end
    end
end