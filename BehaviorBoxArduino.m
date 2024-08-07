classdef BehaviorBoxArduino < handle
% This is a class for using an Arduino as a serial device by receiving
% and sending text strings between the arduino and the computer.
    properties
        port string
        baudRate double
        Ard = {}
        ExperimentMode % either 'Wheel' or 'NosePoke'
    end
    
    methods
        function obj = BehaviorBoxArduino(port, baudRate, ExperimentMode)
            if ~(strcmp(ExperimentMode, 'Wheel') || strcmp(ExperimentMode, 'NosePoke'))
                error('Invalid Experiment Mode. It should be either ''Wheel'' or ''NosePoke''.')
            end

            obj.port = port;
            obj.baudRate = baudRate;
            obj.ExperimentMode = ExperimentMode;
            
            try
                obj.Ard = serialport(obj.port, obj.baudRate);
                obj.Ard
            end
        end
        
        function data = readData(obj)
            if obj.Ard.BytesAvailable
                switch obj.ExperimentMode
                    case 'Wheel'
                        % Perform data reading for 'Wheel' mode
                        % Here is an example, please change the code
                        % according to your experiment.
                        data = fread(obj.Ard, obj.Ard.BytesAvailable);
                    case 'NosePoke'
                        % Perform data reading for 'Nose' mode
                        % Here is an example, please change the code
                        % according to your experiment.
                        data = fread(obj.Ard, obj.Ard.BytesAvailable, "char");
                end
                flusj(obj.Ard)
            else
                data = [];
            end
        end
        
        function disconnect(obj)
            fclose(obj.Ard);
            disp('Serial port is closed');
        end
        
        function delete(obj)
            obj.disconnect();
            delete(obj.Ard);
        end
    end
end

% These are the old Arduino fcns, and their functionality will be merged into this class over time

% From NosePoke
% function ConfigureArduino(this, options)
% arguments
%     this
%     options.Rebuild logical = false
% end
% this.message_handle.Text = 'Connecting to Arduino. . .';
% tic
% try
%     % https://docs.arduino.cc/learn/microcontrollers/digital-pins
%     if this.Setting_Struct.Box_Input_type == 8 %Skip all this if keyboard mode
%         this.Box.ardunioReadDigital = 0;
%         return
%     end
%     if ispc
%         comsnum = "COM"+this.app.Arduino_Com.Value;
%     elseif ismac
%         comsnum = "/dev/tty"+this.app.Arduino_Com.Value;
%     elseif isunix
%         comsnum = "/dev/tty"+this.app.Arduino_Com.Value;
%     end
%     this.Box.use_ball = 0; %All these are automatically off
%     this.Box.use_wheel = 0;
%     this.Box.ardunioReadDigital = 0;
%     this.Box.KeyboardInput = 0;
%     this.Box.readHigh = 0; % When unselected, NosePoke reads HIGH, when selected it reads LOW
%     %set which lever is what and what the input setup is from
%     this.Box.ResetPin        = 'D4';
%     this.Box.TriggerPin      = 'D5';
%     switch this.Setting_Struct.Box_Input_type
%         case 3 %Three Pokes
%             if options.Rebuild
%                 try
%                     this.a = [];
%                 catch
%                 end
%                 this.a = arduino(comsnum,'Uno','Libraries',{}, 'ForceBuildOn',true);
%             else
%                 %this.a = BehaviorBoxArduino(comsnum, 9600, 'NosePoke');
%                 this.a = arduino(comsnum,'Uno','Libraries',{});
%             end
%             configurePin(this.a, "D2", "Unset");
%             configurePin(this.a, "D3", "Unset");
%             configurePin(this.a, "D7", "Unset");
%             this.Box.ardunioReadDigital = 1;
%             this.Box.readHigh = 0;
%             if this.Box.readHigh %Voltage goes HIGH on choice
%                 configurePin(this.a, "D2", "DigitalInput");
%                 configurePin(this.a, "D3", "DigitalInput");
%                 configurePin(this.a, "D7", "DigitalInput");
%             else %Voltage goes LOW on choice
%                 configurePin(this.a, "D2", "Pullup");
%                 configurePin(this.a, "D3", "Pullup");
%                 configurePin(this.a, "D7", "Pullup");
%             end
%             %Set up box structure
%             this.Box.Left = 'D2';
%             this.Box.Middle = 'D3';
%             this.Box.Right = 'D7';
%             this.Box.ValveL = 'D6';
%             this.Box.ValveR = 'D8';
%             this.Box.AirPuff  = 'D11';
%             this.Box.readPin = @(PIN)this.a.readDigitalPin(PIN)==this.Box.readHigh;
%             this.Box.readL = @(x)this.Box.readPin(this.Box.Left);
%             this.Box.readR = @(x)this.Box.readPin(this.Box.Right);
%             this.Box.readM = @(x)this.Box.readPin(this.Box.Middle);
%         case 8 %Keyboard, used if no arduino connected
%             this.Box.KeyboardInput = 1;
%             this.Box.readHigh = 1;
%             return
%     end
%     configurePin(this.a, "D4", "Unset"); %Reset pin
%     configurePin(this.a, "D5", "Unset"); %Trigger pin
%     configurePin(this.a, "D6", "Unset");
%     configurePin(this.a, "D8", "Unset");
%     configurePin(this.a, "D9", "Unset");
%     configurePin(this.a, "D4", "DigitalOutput"); %Reset pin
%     configurePin(this.a, "D5", "DigitalInput"); %Trigger pin
%     configurePin(this.a, "D6", "DigitalOutput");
%     configurePin(this.a, "D8", "DigitalOutput");
%     configurePin(this.a, "D9", "DigitalOutput");
%     toc
% catch
%     this.Box.use_ball = 0; %All these are automatically off
%     this.Box.use_wheel = 0;
%     this.Box.ardunioReadDigital = 0;
%     this.Box.KeyboardInput = 1;
%     this.Box.readHigh = 0; % When unselected, NosePoke reads HIGH, when selected it reads LOW
%     this.Setting_Struct.Box_Input_type = 8;
%     this.a = [];
% end
% this.message_handle.Text = 'Done';
% end

% From Wheel
% function ConfigureArduino(this, options)
% arguments
%     this
%     options.Rebuild logical = false
% end
% this.message_handle.Text = 'Connecting Arduino. . .';
% tic
% try
%     https://docs.arduino.cc/learn/microcontrollers/digital-pins
%     if this.Setting_Struct.Box_Input_type == 8 %Skip all this if keyboard mode
%         this.Box.ardunioReadDigital = 0;
%         return
%     end
%     if ispc
%         comsnum = "COM"+this.app.Arduino_Com.Value;
%     elseif ismac
%         comsnum = "COM"+this.app.Arduino_Com.Value;
%     elseif isunix
%         comsnum = "/dev/tty"+this.app.Arduino_Com.Value;
%     end
%     this.Box.use_ball = 0; %All these are automatically off
%     this.Box.use_wheel = 0;
%     this.Box.ardunioReadDigital = 0;
%     this.Box.KeyboardInput = 0;
%     this.Box.readHigh = 0; % When unselected, NosePoke reads HIGH, when selected it reads LOW
%     set which lever is what and what the input setup is from
%     this.Box.ResetPin        = 'D4';
%     this.Box.TriggerPin      = 'D5';
%     this.Box.Timestamp       = 'D9';
%     switch this.Setting_Struct.Box_Input_type
%         case 6 %Rotating Wheel
%             if options.Rebuild
%                 try
%                     this.a = [];
%                 catch
%                 end
%                 this.a = arduino(comsnum,'Uno','Libraries',{'RotaryEncoder'}, 'ForceBuildOn',true);
%             else
%                 this.a = arduino(comsnum,'Uno','Libraries',{'RotaryEncoder'});
%             end
%             this.Box.encoder = rotaryEncoder(this.a,'D2','D3', 1024);
%             this.Box.Reward =  'D6';
%             this.Box.use_wheel = 1;
%         case 8 %Keyboard, used if no arduino connected
%             this.Box.KeyboardInput = 1;
%             this.Box.readHigh = 1;
%             return
%     end
%     configurePin(this.a, "D4", "Unset"); %Reset pin
%     configurePin(this.a, "D5", "Unset"); %Trigger pin
%     configurePin(this.a, "D6", "Unset");
%     configurePin(this.a, "D8", "Unset");
%     configurePin(this.a, "D9", "Unset");
%     configurePin(this.a, "D4", "DigitalOutput"); %Reset pin
%     configurePin(this.a, "D5", "DigitalInput"); %Trigger pin
%     configurePin(this.a, "D6", "DigitalOutput");
%     configurePin(this.a, "D8", "DigitalOutput");
%     configurePin(this.a, "D9", "DigitalOutput");
%     toc
% catch err
%     this.Box.use_ball = 0; %All these are automatically off
%     this.Box.use_wheel = 0;
%     this.Box.ardunioReadDigital = 0;
%     this.Box.KeyboardInput = 1;
%     this.Box.readHigh = 0; % When unselected, NosePoke reads HIGH, when selected it reads LOW
%     this.Setting_Struct.Box_Input_type = 8;
%     this.a = [];
% end
% this.message_handle.Text = 'Done';
% end