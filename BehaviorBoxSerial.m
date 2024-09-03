classdef BehaviorBoxSerial < handle
% This is a class for using an Arduino as a serial device by receiving
% and sending text between the arduino and the computer.
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
            function this = BehaviorBoxSerial(port, baudRate, Input_type)
                arguments
                    port char = 'COM4'
                    baudRate double = 9600
                    Input_type char = 'NosePoke'
                end
                this.Input_type = Input_type;
                this.Ard = serialport(port, baudRate, ...
                    "Timeout", 0.1);
                configureTerminator(this.Ard,"CR/LF");
                configureCallback(this.Ard, "terminator", @this.SerialRead);
                this.Reset();
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
% This function sets up the reward parameters for the Arduino.
% The Arduino will be in reward setup mode until the next
% command is sent.
% Send "S" for Left Reward
% Send "s" for Right Reward
% Give reward as a number larger than "0.001"
                arguments
                    this
                    opts.DurationRight string = this.Rrewardtime;
                    opts.DurationLeft string = this.Lrewardtime;
                    opts.Which string = "Right"
                end
                if ismember(opts.Which, ["Right", "Both"])
                    write(this.Ard, "s", "char");
                    writeline(this.Ard, opts.DurationRight);
                    %write(this.Ard, opts.DurationRight, "string");
                end
                if ismember(opts.Which, ["Left", "Both"])
                    write(this.Ard, "S", "char");
                    writeline(this.Ard, opts.DurationLeft);
                    %write(this.Ard, opts.DurationLeft, "string");
                end
                % Update properties
                this.Rrewardtime = opts.DurationRight;
                this.Lrewardtime = opts.DurationLeft;
            end

            function GiveReward(this, opts)
                arguments
                    this
                    opts.Side string = "R"
                end
                write(this.Ard, opts.Side, "char");
            end
    
            function Reading = SerialRead(this, src, ~)
                % Used for Callback that reads when a line is sent to serial
                arguments
                    this
                    src = this.Ard
                    ~
                end
                if this.Ard.BytesAvailable == 0
                    Reading = this.Reading;
                    return
                end
                %Reading = str2num(read(src, src.BytesAvailable, 'string')); % Use this syntax if there are multiple lines in the buffer waiting to be read, shouldn't need to use this if the callback is working 
                switch true
                    case strcmp(this.Input_type, 'Wheel')
                        Reading = str2double(readline(src)); % Returns an integer for the angle, e.g. -104
                    case strcmp(this.Input_type, 'NosePoke')
                        Reading = readline(src); % Returns a character, e.g. 'L' 'R' 'M' or '-"
                end
                this.Reading = Reading;
                if this.DispOutput
                    disp(Reading);
                end
            end
    
            function LeftRead = ReadLeft(this)
                LeftRead = strcmpi(this.SerialRead(), "L");
            end
            
            function RightRead = ReadRight(this)
                RightRead = strcmpi(this.SerialRead(), "R");
            end
            
            function MiddleRead = ReadMiddle(this)
                MiddleRead = strcmpi(this.SerialRead(), "M");
            end
            
            function NoneRead = ReadNone(this)
                NoneRead = ~strcmpi(this.SerialRead(), "-");
                % To match behavior this one is flipped, because it is only
                % used for the flashing while waiting for input
            end
    
            function Reset(this)
                %Assign neutral value to property
                switch true
                    case strcmp(this.Input_type, 'Wheel')
                        Reading = 0;
                        write(this.Ard, 'Reset', 'char')
                    case strcmp(this.Input_type, 'NosePoke')
                        Reading = '-';
                end
                this.Reading = Reading;
            end
    
            function delete(this)
                this.Ard = [];
                delete(this.Ard);
                disp('Serial port is closed');
            end
        end
end