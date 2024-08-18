classdef BehaviorBoxSerial < handle
    % This is a class for using an Arduino as a serial device by receiving
    % and sending text strings between the arduino and the computer.
    % The NosePoke uses an Arduino programmed with Photogate.ino and
    % The Wheel uses an Arduino programmed with Rotary-Encoder-Arduino.ino
        properties
            Ard = {}
            Reading % char for NosePoke and integer for Wheel
            use_wheel logical = false
            KeyboardInput logical = false
            ResetPin = 'D4'
            TriggerPin = 'D5'
            Left = 'D2'
            Middle = 'D3'
            Timestamp = 'D9'
            Right = 'D7'
            ValveL = 'D6'
            ValveR = 'D8'
            Input_type % either 'Wheel' or 'NosePoke'
            Juice logical = true
            LeftPulse
            LeftPulse_Temp
            Lrewardtime = 0.05
            Lrewardtime_Temp
            OCPulse
            OCPulse_Temp
            PulseMax
            Pulse_Min
            RightPulse
            RightPulse_Temp
            Rrewardtime = 0.05
            Rrewardtime_Temp
            SecBwPulse
            Two_ports logical
        end
        
        methods
            function this = BehaviorBoxSerial(port, baudRate, Input_type)
                this.Input_type = Input_type;
                this.Ard = serialport(port, baudRate);
                configureTerminator(this.Ard,"CR/LF");
                flush(this.Ard);
                configureCallback(this.Ard, "terminator", @this.SerialRead);
                this.Reset();
                this.SetupReward();
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
                    opts.DurationRight char = this.Rrewardtime;
                    opts.DurationLeft char = this.Lrewardtime;
                end
                write(this.Ard, 'Setup', 'char')
                while ~this.Ard.BytesAvailable
                    pause(0.01);
                end
                write(this.Ard, opts.DurationRight, 'char') % Duration of Right reward pulse
                this.Rrewardtime = opts.DurationRight;
                if this.Input_type == "NosePoke"
                    this.Two_ports = true;
                    while ~this.Ard.BytesAvailable
                        pause(0.01);
                    end
                    write(this.Ard, opts.DurationLeft, 'char') % Duration of Left reward pulse
                    this.Lrewardtime = opts.DurationLeft;
                else
                    this.Two_ports = false;
                end
            end

            function GiveReward(this, opts)
                arguments
                    this
                    opts.Side char = 'Right'
                end
                writeline(this.Ard, opts.Side, 'char')
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
            end
    
            function LeftRead = ReadLeft(this)
                LeftRead = this.SerialRead() == "L";
            end
            
            function RightRead = ReadRight(this)
                RightRead = this.SerialRead() == "R";
            end
            
            function MiddleRead = ReadMiddle(this)
                MiddleRead = this.SerialRead() == "M";
            end
            
            function NoneRead = ReadNone(this)
                NoneRead = this.SerialRead() == "-";
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