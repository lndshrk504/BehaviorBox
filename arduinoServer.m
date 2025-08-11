function selectedDevice = arduinoServer(desiredIdentity)
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
    serialPortInfo = serialPortInfo(contains(serialPortInfo, 'ACM')); % get Arduinos only

    % Preallocate the devicesInfo structure array with maximum possible size
    maxPorts = length(serialPortInfo);
    devicesInfo(maxPorts).Port = '';
    devicesInfo(maxPorts).Identity = '';

    % Initialize an index to keep track of actual devices found
    deviceCount = 0;

    % Iterate through each serial port
    for i = 1:maxPorts
        try
            % Create serial port object
            device = serialport(serialPortInfo(i), 115200); % Modify the baud rate if required
            configureTerminator(device, "CR/LF")
            
            % Define a cleanup function to close the port eventually
            finishup = onCleanup(@() delete(device));
            pause(1)

            Data = string;
            while device.NumBytesAvailable > 0
                Data(end+1,1) = strip(readline(device));
            end
            % Pause to allow time for connection; some devices may require a brief wait
            pause(1);

            % Send the identification character 'W'
            writeline(device, 'W');

            % Read the response from the serial device
            pause(1); % Add a pause if the response takes time

            while device.NumBytesAvailable > 0
                Data(end+1,1) = strip(readline(device));
            end
            response = Data;

            % Increment the device count
            deviceCount = deviceCount + 1;

            % Store the port and identity in the preallocated array
            devicesInfo(deviceCount).Port = serialPortInfo(i);
            Identity = response(contains(response, 'Box ID'));

            devicesInfo(deviceCount).Identity = strtrim(response); % Trim the response for consistency

            % Disconnect the device as we are only identifying at this stage
            clear('device');
        catch
            % If an error occurs, such as a timeout, skip this device
            fprintf('Error with port %s. Skipping.\n', serialPortInfo(i));
        end
    end

    % Retain only the populated entries in devicesInfo
    devicesInfo = devicesInfo(1:deviceCount);

    % Find and connect to the desired device
    selectedDevice = [];
    for i = 1:deviceCount
        if strcmp(devicesInfo(i).Identity, desiredIdentity)
            selectedDevice = serialport(devicesInfo(i).Port, 115200); % Reconnect to the desired device
            fprintf('Connected to device: %s on port: %s\n', devicesInfo(i).Identity, devicesInfo(i).Port);
            break;
        end
    end

    % Check if the desired device was not found
    if isempty(selectedDevice)
        disp('Desired device was not found.');
    end
end