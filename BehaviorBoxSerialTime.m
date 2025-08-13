classdef BehaviorBoxSerialTime < handle
    %
    % WBS May - 27 - 2025
    %
    % ScanImage frame clocks are recorded by an Arduino, Timekeeper.ino
    % This program logs frame timestamps in a property called TimestampLog.
    %
    properties
        Ard = {}
        Reading % char for NosePoke and integer for Wheel
        DispOutput logical = false % This helps to debug
        Log string = {}
    end

    methods
        function this = BehaviorBoxSerialTime(port, baudRate)
            arguments
                port char = 'COM4'
                baudRate double = 115200
            end
            try
                %port = '/dev/ttyACM1';
                this.Ard = serialport(port, baudRate, ...
                    "Timeout", 0.5);
                this.Ard.InputBufferSize = 1048576; % 1048576 is 1 MB
                configureTerminator(this.Ard,"CR/LF");
                configureCallback(this.Ard, "terminator", @this.SerialRead);
            catch err
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
            if src.BytesAvailable == 0
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
            writeline(this.Ard, 'W')
            pause(1); % Pause for a moment to allow data to be loaded into the buffer
            while this.Ard.NumBytesAvailable > 0
                data = readline(this.Ard);
                disp(data);
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
            this.Ard = [];
            disp('Timestamp Serial port is closed');
        end
    end
end