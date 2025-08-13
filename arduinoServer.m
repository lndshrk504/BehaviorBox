function [COM, ID] = arduinoServer(desiredIdentity, opts)
arguments 
    desiredIdentity = "Nose1"
    opts.FindFirst logical = true
end
    % arduinoServer Connects to a specific Arduino device based on its identity.
    % 
    % selectedDevice = arduinoServer(desiredIdentity)
    % 
    % Inputs:
    %   - desiredIdentity: A string representing the identity of the desired Arduino.
    %
    % Outputs:
    %   - selectedDevice: A serialport object for the desired Arduino device.
    %     If no matching device is found, returns an empty array.

    % List available serial ports on your system
    serialPortInfo = serialportlist;

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

    % Preallocate the devicesInfo structure array with maximum possible size
    maxPorts = length(serialPortInfo);
    devicesInfo(maxPorts).Port = '';
    devicesInfo(maxPorts).Identity = '';
    devicesInfo(maxPorts).Device = {};

    % Initialize an index to keep track of actual devices found
    deviceCount = 0;

    % Iterate through each serial port
    for i = 1:maxPorts
        try
            % Increment the device count
            deviceCount = deviceCount + 1;
            % Store the port and identity in the preallocated array
            devicesInfo(deviceCount).Port = erase(serialPortInfo(i), '/dev/tty');

            % Create serial port object
            devicesInfo(deviceCount).Device = serialport(serialPortInfo(i), 115200); % Modify the baud rate if required
            configureTerminator(devicesInfo(deviceCount).Device, "CR/LF")
            device = devicesInfo(deviceCount).Device;

            pause(2)

            Data = string;
            while device.NumBytesAvailable > 0
                Data(end+1,1) = strip(readline(device));
            end
            response = Data;

            % Store the port and identity in the preallocated array
            Identity = response(contains(response, 'Box ID'));
            Identity = erase(Identity, 'Box ID: '); % Trim the response for consistency
            devicesInfo(deviceCount).Identity = Identity;
            fprintf('Found device: %s on port: %s\n', devicesInfo(i).Identity, devicesInfo(i).Port);
            if opts.FindFirst && contains(Identity, desiredIdentity)
                COM = serialPortInfo(i);
                ID = Identity;
                return
            end
        catch
            % If an error occurs, such as a timeout, skip this device
            devicesInfo(deviceCount).Identity = 'Busy';
            fprintf('Port %s is not available...\n', serialPortInfo(i));
        end
    end

    % Retain only the populated entries in devicesInfo
    devicesInfo = devicesInfo(1:deviceCount);

    % Find and connect to the desired device
    COM = [];
    for i = 1:deviceCount
        if contains(devicesInfo(i).Identity, desiredIdentity)
            [devicesInfo(:).Device] = deal([]);
            %selectedDevice = serialport("/dev/tty"+devicesInfo(i).Port, 115200); % Reconnect to the desired device
            COM = "/dev/tty"+devicesInfo(i).Port; % Reconnect to the desired device
            ID = devicesInfo(i).Identity;
            fprintf('Selecting device: %s on port: %s\n', devicesInfo(i).Identity, devicesInfo(i).Port);
            break;
        end
    end

    % Check if the desired device was not found
    if isempty(COM)
        disp('Desired device was not found.');
    end
end