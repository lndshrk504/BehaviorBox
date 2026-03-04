function [devicesInfo, COM, ID] = arduinoServer(opts)
    arguments
        opts.FindAll logical = true
        opts.ArduinoInfo struct = struct()
        opts.desiredIdentity = ''
        opts.FindFirst logical = false
        opts.FindExact logical = false %#ok<INUSD>
    end
    % arduinoServer  Discover Arduino serial ports and their self-reported Box IDs.
    %
    % This function is intentionally discovery-only:
    %   - Opens each candidate port briefly
    %   - Reads startup text
    %   - Extracts lines containing 'Box ID'
    %   - Closes the port reliably (even on errors)
    %
    % Outputs:
    %   devicesInfo.Arduinos(i).Port     : serial port path/name (char)
    %   devicesInfo.Arduinos(i).Identity : identity string (string)
    %   COM / ID : first match for opts.desiredIdentity (empty if none)

    COM = [];
    ID  = [];

    % ---------------------------------------
    % Fast path: reuse already-discovered list
    % ---------------------------------------
    if isstruct(opts.ArduinoInfo) && ~isempty(fieldnames(opts.ArduinoInfo)) && isfield(opts.ArduinoInfo, 'Arduinos')
        Ards = opts.ArduinoInfo.Arduinos;
        if ~isempty(Ards) && isfield(Ards, 'Identity') && isfield(Ards, 'Port')
            IDs = string({Ards.Identity});
            Ports = string({Ards.Port});

            idx = find(contains(IDs, opts.desiredIdentity), 1, 'first');
            if ~isempty(idx)
                ID = IDs(idx);
                port = Ports(idx);
                if ~startsWith(port, "/dev/") && (isunix || ismac)
                    port = "/dev/tty" + port;
                end
                COM = port;
            end

            devicesInfo = opts.ArduinoInfo;

            % Ensure COM is char for downstream constructors with `port char` validation
            if isstring(COM) && numel(COM) == 1
                COM = char(COM);
            end
            return
        end
    end

    % ------------------------
    % Enumerate candidate ports
    % ------------------------
    COM = [];
    ID  = [];

    serialPortInfo = serialportlist; % list available serial ports

    % Platform-specific filtering (keep it conservative)
    switch true
        case ismac
            serialPortInfo = serialPortInfo(contains(serialPortInfo, '/dev/tty', IgnoreCase=true));
            serialPortInfo(contains(serialPortInfo, 'debug-console', IgnoreCase=true)) = [];
            serialPortInfo(contains(serialPortInfo, 'Beats', IgnoreCase=true)) = [];
            serialPortInfo(contains(serialPortInfo, 'Beoplay', IgnoreCase=true)) = [];
        case isunix
            serialPortInfo = serialPortInfo(contains(serialPortInfo, 'ACM')); % typical Arduino CDC-ACM ports
        case ispc
            serialPortInfo(contains(serialPortInfo, {'COM1', 'COM3'}, IgnoreCase=true)) = [];
        otherwise
    end

    maxPorts = length(serialPortInfo);

    devicesInfo = struct();
    devicesInfo.Tag = 'Arduino';
    devicesInfo.Type = opts.desiredIdentity;
    devicesInfo.Value = opts.desiredIdentity;

    Ards_Info(maxPorts).Port = '';
    Ards_Info(maxPorts).Identity = '';
    deviceCount = 0;

    for i = 1:maxPorts
        deviceCount = deviceCount + 1;
        Ards_Info(deviceCount).Port = char(serialPortInfo(i));
        Ards_Info(deviceCount).Identity = "";

        device = [];
        cleanupDevice = [];

        try
            device = serialport(serialPortInfo(i), 115200, "Timeout", 0.5); % baud rate must match Arduino sketch
            cleanupDevice = onCleanup(@() bbSafeCloseSerial(device));
            configureTerminator(device, "CR/LF");

            % Read bytes in chunks so we never block on an incomplete terminator.
            rawText = "";
            readStart = tic;
            lastRx = tic;
            sawData = false;

            maxReadTime = 3;      % seconds
            idleStopTime = 0.1;   % stop once serial has been quiet after data arrives
            pollInterval = 0.02;

            while toc(readStart) < maxReadTime
                nBytes = device.NumBytesAvailable;
                if nBytes > 0
                    sawData = true;
                    rawText = rawText + string(read(device, nBytes, "char"));
                    lastRx = tic;
                elseif sawData && toc(lastRx) >= idleStopTime
                    break
                else
                    pause(pollInterval)
                end
            end

            Data = strings(0,1);
            if strlength(rawText) > 0
                Data = strip(splitlines(rawText));
                Data(Data == "") = [];
            end

            idLines = Data(contains(Data, "Box ID"));
            if ~isempty(idLines)
                Identity = erase(idLines(1), "Box ID: ");
            else
                Identity = "";
            end

            Ards_Info(deviceCount).Identity = Identity;
            fprintf('Found device: %s on port: %s\n', Ards_Info(deviceCount).Identity, Ards_Info(deviceCount).Port);

            if opts.FindFirst && contains(Identity, opts.desiredIdentity)
                COM = Ards_Info(deviceCount).Port;
                ID = Identity;
                devicesInfo.Arduinos = Ards_Info(1:deviceCount);
                devicesInfo.Value = ID;
                cleanupDevice = []; % close now
                return
            end
        catch
            Ards_Info(deviceCount).Identity = "Busy";
            fprintf('Port %s is not available...\n', serialPortInfo(i));
        end

        cleanupDevice = []; % close now (onCleanup executes here)
    end

    devicesInfo.Arduinos = Ards_Info(1:deviceCount);

    if opts.desiredIdentity == ""
        devicesInfo.Value = "";
        return
    end

    % ------------------------
    % Select the desired device
    % ------------------------
    for i = 1:deviceCount
        if contains(Ards_Info(i).Identity, opts.desiredIdentity)
            COM = Ards_Info(i).Port;
            ID = Ards_Info(i).Identity;
            fprintf('Selecting device: %s on port: %s\n', Ards_Info(i).Identity, Ards_Info(i).Port);
            break;
        end
    end

    devicesInfo.Value = ID;

    if isempty(COM)
        disp('Desired device was not found.');
    end

    % Ensure COM is char for downstream constructors with `port char` validation
    if isstring(COM) && numel(COM) == 1
        COM = char(COM);
    end
end

function bbSafeCloseSerial(device)
    % Best-effort teardown for a serialport object.
    try
        if isempty(device)
            return
        end
    catch
        return
    end

    try
        configureCallback(device, "off");
    catch
    end
    try
        flush(device);
    catch
    end
    try
        delete(device);
    catch
    end
end
