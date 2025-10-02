classdef BehaviorBoxSerialInput < handle
    % WBS 10 - 10 - 2024
    % The NosePoke uses an Arduino programmed with Photogate.ino.
    % The Wheel uses an Arduino programmed with Rotary-Encoder-Arduino.ino.
    properties
        Ard = {}
        Reading % char for NosePoke and integer for Wheel
        DispOutput logical = true % This helps to debug
        use_wheel logical = false
        KeyboardInput logical = false
        Input_type % either 'Wheel' or 'NosePoke'
        Two_ports logical
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
                %port = '/dev/ttyACM1';
                this.Ard = serialport(port, baudRate, ...
                    "Timeout", 2);
                configureTerminator(this.Ard,"CR/LF");
                configureCallback(this.Ard, "terminator", @this.SerialRead);
            catch err
                disp('Serial connection failed.')
            end
            if this.Input_type == "Wheel"
                this.DispOutput = true;
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

        function SetupReward(this, opts)
            arguments
                this
                opts.DurationRight string = this.Rrewardtime;
                opts.DurationLeft string = this.Lrewardtime;
                opts.Which string = "Right"
            end
            this.DispOutput = true;
            % if this.Input_type == "Wheel"
            %     this.DispOutput = true;
            % end
            if ismember(opts.Which, ["Right", "Both"])
                %write(this.Ard, "s", "char");
                writeline(this.Ard, "s"+opts.DurationRight);
                %write(this.Ard, opts.DurationRight, "string");
            end
            if ismember(opts.Which, ["Left", "Both"])
                %write(this.Ard, "S", "char");
                writeline(this.Ard, "S"+opts.DurationLeft);
                %write(this.Ard, opts.DurationLeft, "string");
            end
            % Update properties
            this.Rrewardtime = str2double(opts.DurationRight);
            this.Lrewardtime = str2double(opts.DurationLeft);
            pause(0.1)
            % % this.DispOutput = false;
            
            % if this.Input_type == "Wheel"
            %     pause(0.1)
            %     this.DispOutput = false;
            % end
        end

        function GiveReward(this, opts)
            arguments
                this
                opts.Side char = 'R'
            end
            if this.Input_type == "Wheel"
                this.DispOutput = true;
            end
            write(this.Ard, opts.Side, "char");
            if this.Input_type == "Wheel"
                this.DispOutput = false;
            end
        end

        function TimeStamp(this, Type)
            arguments
                this
                Type char = 'On'
            end
            try % will fail if no arduino...
                switch Type
                    case 'On'
                        write(this.Ard, "T", "char");
                    case 'Off'
                        write(this.Ard, 't', "char");
                    otherwise
                        % nothing
                end
            end
            pause(0.3);
        end

        function result = processReading(~, newReading)
            result = char(newReading);
            % if strcmp(this.Input_type, 'Wheel')
            %     %result = str2double(newReading);
            %     result = char(newReading);
            % else
            %     result = char(newReading);
            % end
        end

        function LeftRead = ReadLeft(this)
            reading = this.Reading; % Read the value once
            LeftRead = strcmp(reading, 'L');
        end

        function RightRead = ReadRight(this)
            reading = this.Reading; % Read the value once
            RightRead = strcmp(reading, 'R');
        end

        function MiddleRead = ReadMiddle(this)
            reading = this.Reading; % Read the value once
            MiddleRead = strcmp(reading, 'M');
        end

        function NoneRead = ReadNone(this)
            reading = this.Reading; % Read the value once
            NoneRead = ~strcmp(reading, '-');
            % To match behavior this one is flipped, because it is only
            % used for the flashing while waiting for input
        end

        function Acquisition(this, Type)
% This sends a character over the serial to the Arduino, which will raise
% the indicated pin to high for 200 milliseconds
            arguments
                this
                Type char = 'Next'
            end
            try % will fail if no arduino...
                switch Type
                    case 'Start'
                        write(this.Ard, 'I', "char");
                    case 'Next'
                        write(this.Ard, 'N', "char");
                    case 'End'
                        write(this.Ard, 'i', "char");
                    otherwise
                        % nothing
                end
            end
        end

        function SwitchMode(this, options)
            arguments
                this
                options.Which = 'Position'
            end
            write(this.Ard, 'M', "char");
            this.Reading = "0";
        end
        
        function Reset(this)
            %Assign neutral value to property
            switch true
                case strcmp(this.Input_type, 'Wheel')
                    this.Reading = '0';
                    write(this.Ard, '0', 'char')
                    pause(0.01)
                case strcmp(this.Input_type, 'NosePoke')
                    this.Reading = '-';
            end
        end

        function delete(this)
            this.Ard = [];
            disp('Behavior Serial port is closed');
        end
    end
end