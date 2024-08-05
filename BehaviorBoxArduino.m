classdef BehaviorBoxArduino < handle
% This is a class for using an Arduino as a serial device by receiving
% and sending text strings between the arduino and the computer.
    properties
        port
        baudRate
        bytesAvailable
        serialObj
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
                obj.serialObj = serialport(obj.port, obj.baudRate);
            end
        end
        
        function connect(obj)
            fopen(obj.serialObj);
            disp('Serial port is open');
        end
        
        function disconnect(obj)
            fclose(obj.serialObj);
            disp('Serial port is closed');
        end
        
        function data = readData(obj)
            if obj.serialObj.BytesAvailable
                switch obj.ExperimentMode
                    case 'Wheel'
                        % Perform data reading for 'Wheel' mode
                        % Here is an example, please change the code
                        % according to your experiment.
                        data = fread(obj.serialObj, obj.serialObj.BytesAvailable);
                    case 'Nose'
                        % Perform data reading for 'Nose' mode
                        % Here is an example, please change the code
                        % according to your experiment.
                        data = fread(obj.serialObj, obj.serialObj.BytesAvailable);
                end
            else
                data = [];
                disp('No data available');
            end
        end
        
        function delete(obj)
            obj.disconnect();
            delete(obj.serialObj);
        end
    end
end
