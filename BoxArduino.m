classdef BoxArduino < handle
    properties
        port
        baudRate
        bytesAvailable
        serialObj
        ExperimentMode % either 'Wheel' or 'Nose'
    end
    
    methods
        function obj = BoxArduino(port, baudRate)
            if ~(strcmp(ExperimentMode, 'Wheel') || strcmp(ExperimentMode, 'Nose'))
                error('Invalid Experiment Mode. It should be either ''Wheel'' or ''Nose''.')
            end

            obj.port = port;
            obj.baudRate = baudRate;
            obj.ExperimentMode = ExperimentMode;
            obj.serialObj = serial(obj.port, 'BaudRate', obj.baudRate);
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
