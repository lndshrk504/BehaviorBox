function [devicesInfo, COM, ID] = arduinoServer(opts)
    arguments
        opts.FindAll logical = true
        opts.ArduinoInfo struct = struct()
        opts.desiredIdentity = ''
        opts.FindFirst logical = false
        opts.FindExact logical = false
    end
    % arduinoServer Connects to a specific Arduino device based on its identity.
    %
    % selectedDevice = arduinoServer('desiredIdentity', desiredIdentity)
    %
    % Inputs:
    %   - desiredIdentity: A string representing the identity of the desired Arduino.
    %
    % Outputs:
    %   - selectedDevice: A serialport object for the desired Arduino device.
    %     If no matching device is found, returns an empty array.
    
    if size(fields(opts.ArduinoInfo),1) > 0
        Ards = opts.ArduinoInfo.Arduinos;
        IDs = [Ards.Identity];
        W_Ard = contains(IDs, opts.desiredIdentity);
        ID = IDs(W_Ard);
        Ports = [Ards.Port];
        COM = "/dev/tty"+Ports(W_Ard);
        devicesInfo = opts.ArduinoInfo;
        return
    end

    COM = [];
    ID = [];
    serialPortInfo = serialportlist; % List available serial ports on your system
    
    % if ispc
    %     comsnum = "COM"+this.app.Arduino_Com.Value;
    % elseif ismac
    %     comsnum = "/dev/tty.usbmodem"+this.app.Arduino_Com.Value;
    % elseif isunix
    %     comsnum = "/dev/tty"+this.app.Arduino_Com.Value;
    % end
    switch true
        case ismac
            sl = sl(contains(sl, '/dev/tty', IgnoreCase=true));
            sl(contains(sl, 'debug-console', IgnoreCase=true)) = [];
            sl(contains(sl, 'Beats', IgnoreCase=true)) = [];
            sl(contains(sl, 'Beoplay', IgnoreCase=true)) = [];
        case isunix
            serialPortInfo = serialPortInfo(contains(serialPortInfo, 'ACM')); % get Arduinos only
        case ispc
            sl(contains(sl, {'COM1', 'COM3'}, IgnoreCase=true)) = [];
        otherwise
    end
    
    maxPorts = length(serialPortInfo); % Preallocate the devicesInfo structure array with maximum possible size

    devicesInfo.Tag = 'Arduino';
    devicesInfo.Type = opts.desiredIdentity;
    devicesInfo.Value = opts.desiredIdentity;
    Ards_Info(maxPorts).Port = '';
    Ards_Info(maxPorts).Identity = '';
    Ards_Info(maxPorts).Device = {};
    devicesInfo.Arduinos = Ards_Info;
    deviceCount = 0; % Initialize an index to keep track of actual devices found
    
    for i = 1:maxPorts % Iterate through each serial port
        try
            deviceCount = deviceCount + 1; % Increment the device count
            Ards_Info(deviceCount).Port = erase(serialPortInfo(i), '/dev/tty'); % Store the port and identity in the preallocated array
    
            % Create serial port object
            Ards_Info(deviceCount).Device = serialport(serialPortInfo(i), 115200); % Modify the baud rate if required
            configureTerminator(Ards_Info(deviceCount).Device, "CR/LF")
            device = Ards_Info(deviceCount).Device;
    
            pause(2)
    
            Data = string;
            while device.NumBytesAvailable > 0
                Data(end+1,1) = strip(readline(device));
            end
            response = Data;
    
            % Store the port and identity in the preallocated array
            Identity = response(contains(response, 'Box ID'));
            Identity = erase(Identity, 'Box ID: '); % Trim the response for consistency
            Ards_Info(deviceCount).Identity = Identity;
            fprintf('Found device: %s on port: %s\n', Ards_Info(i).Identity, Ards_Info(i).Port);
            if opts.FindFirst && contains(Identity, opts.desiredIdentity)
                COM = serialPortInfo(i);
                ID = Identity;
                return
            end
            delete(device)
        catch % If an error occurs, such as a timeout, skip this device
            Ards_Info(deviceCount).Identity = 'Busy';
            fprintf('Port %s is not available...\n', serialPortInfo(i));
        end
    end
    [Ards_Info(:).Device] = deal([]);
    devicesInfo.Arduinos = Ards_Info;
    
    % Retain only the populated entries in devicesInfo
    Ards_Info = Ards_Info(1:deviceCount);
    opts.ArduinoInfo = Ards_Info;
    if opts.desiredIdentity == ""
        return
    end

    % Find and connect to the desired device
    for i = 1:deviceCount
        if contains(Ards_Info(i).Identity, opts.desiredIdentity)
            %selectedDevice = serialport("/dev/tty"+devicesInfo(i).Port, 115200); % Reconnect to the desired device
            COM = "/dev/tty"+Ards_Info(i).Port;
            ID = Ards_Info(i).Identity;
            fprintf('Selecting device: %s on port: %s\n', Ards_Info(i).Identity, Ards_Info(i).Port);
            break;
        end
    end
    devicesInfo.Value = ID;
    
    % Check if the desired device was not found
    if isempty(COM)
        disp('Desired device was not found.');
    end
end