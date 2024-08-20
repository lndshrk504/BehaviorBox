classdef BehaviorBoxSerial < handle
% This is a class for using an Arduino as a serial device by receiving
% and sending text between the arduino and the computer.
% The NosePoke uses an Arduino programmed with Photogate.ino.
% The Wheel uses an Arduino programmed with Rotary-Encoder-Arduino.ino.
        properties
            Ard = struct()
            Reading % char for NosePoke and integer for Wheel
            DispOutput logical = false
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
            Lrewardtime = 0.05
            Rrewardtime = 0.05
            Pulse = 1
            SecBwPulse = 0.2
        end
        
        methods
            function this = BehaviorBoxSerial(port, baudRate, Input_type)
                this.Input_type = Input_type;
                try
                    this.Ard = serialport(port, baudRate);
                    configureTerminator(this.Ard,"CR/LF");
                    configureCallback(this.Ard, "terminator", @this.SerialRead);
                    this.Reset();
                    this.SetupReward();
                    flush(this.Ard);
                catch
                    this.Ard = struct();
                end
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
% The arduino expects setup in this order:
% rightdur
% leftdur - only NosePoke
% Pulse
% BetweenPulse
                arguments
                    this
                    opts.DurationRight char = this.Rrewardtime;
                    opts.DurationLeft char = this.Lrewardtime;
                    opts.Pulse char = this.Pulse;
                    opts.SecBwPulse char = this.SecBwPulse;
                end
                % Switch mode to reward setup
                writeline(this.Ard, 'S')
                while ~this.Ard.BytesAvailable == 0
                    pause(0.01);
                end
                writeline(this.Ard, opts.DurationRight) % Duration of Right reward pulse
                this.Rrewardtime = opts.DurationRight;
                if this.Input_type == "NosePoke"
                    pause(0.01);
                    writeline(this.Ard, opts.DurationLeft) % Duration of Left reward pulse
                    this.Lrewardtime = opts.DurationLeft;
                end
                pause(0.01);
                writeline(this.Ard, opts.Pulse) % Number of reward pulses
                this.Pulse = opts.Pulse;
                pause(0.01);
                writeline(this.Ard, opts.SecBwPulse) % Seconds between reward pulses
                this.SecBwPulse = opts.SecBwPulse;
                pause(0.01);
            end

            function GiveReward(this, opts)
                arguments
                    this
                    opts.Side char = 'R'
                end
                write(this.Ard, uint8(opts.Side), "uint8");
                flush(this.Ard, "output"); % this is necessary to ensure that the data is sent immediately
% This is incredibly slow, because of the way that serial
% commmunication over USB works in MATLAB... Unacceptably slow for
% giving multiple pulses, so now arduino does pulsing
% https://www.reddit.com/r/arduino/comments/111udy/arduino_as_an_acquisition_device_with_matlab/
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
                NoneRead = strcmpi(this.SerialRead(), "-");
            end
    
            function Reset(this)
                write(this.Ard, 'Reset', 'char')
                %Assign neutral value to property
                switch true
                    case strcmp(this.Input_type, 'Wheel')
                        Reading = 0;
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