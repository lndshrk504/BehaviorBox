classdef BehaviorBoxEyeTrack < handle
    % BehaviorBox eye-tracking log helper.
    % WBS Apr - 15 - 2026

    properties
        DispOutput logical = false
        Log string = string.empty(0,1)
        RawLog string = string.empty(0,1)
        ParsedLog table = table()
        LatestSample struct = struct()
        TrainStartTime = []
        TrainStartWallClock = NaT
        CurrentTrial double = NaN
        Address string = ""
        SourceMode string = ""
        SourceHost string = ""
        SourcePort double = NaN
        BridgeDir string = ""
        PythonExecutable string = ""
        ModelName string = "DLC_PupilTracking_YangLab_resnet_50_iteration-0_shuffle-1"
        PointNames string = string.empty(0,1)
        PlaceholderLiveSubscriber logical = false
        IsConnected logical = false
        LastReceiveWallClock = NaT
        SubscriberStartWallClock = NaT
        SubscriberStopWallClock = NaT
        PollPeriodSeconds double = 0.02
        PollTimeoutMs double = 10
        RcvHighWaterMark double = 1
        StartTimerOnStart logical = true
        MessagesReceived double = 0
        LastErrorMessage string = ""
        BridgeAdapter struct = struct()
        BridgeModule = []
        SubscriberHandle = []
        PollTimer = []
    end

    methods
        function this = BehaviorBoxEyeTrack(options)
            arguments
                options.Address string = ""
                options.SourceMode string = ""
                options.SourceHost string = ""
                options.SourcePort double = NaN
                options.BridgeDir string = ""
                options.PythonExecutable string = ""
                options.ModelName string = "DLC_PupilTracking_YangLab_resnet_50_iteration-0_shuffle-1"
                options.PointNames string = BehaviorBoxEyeTrack.defaultPointNames()
                options.PollPeriodSeconds double = 0.02
                options.PollTimeoutMs double = 10
                options.RcvHighWaterMark double = 1
                options.StartTimerOnStart logical = true
                options.BridgeAdapter struct = struct()
            end

            this.ParsedLog = BehaviorBoxEyeTrack.emptyRecordTable();
            this.PointNames = string(options.PointNames(:));
            this.ModelName = string(options.ModelName);
            this.BridgeDir = string(options.BridgeDir);
            this.PythonExecutable = string(options.PythonExecutable);
            this.PollPeriodSeconds = double(options.PollPeriodSeconds);
            this.PollTimeoutMs = double(options.PollTimeoutMs);
            this.RcvHighWaterMark = double(options.RcvHighWaterMark);
            this.StartTimerOnStart = logical(options.StartTimerOnStart);
            this.BridgeAdapter = options.BridgeAdapter;

            if strlength(strtrim(options.Address)) > 0
                [host, port, address] = BehaviorBoxEyeTrack.parseAddress(options.Address);
                this.Address = address;
                this.SourceHost = host;
                this.SourcePort = port;
            else
                this.Address = "";
                this.SourceHost = string(options.SourceHost);
                this.SourcePort = double(options.SourcePort);
            end

            if strlength(strtrim(options.SourceMode)) > 0
                this.SourceMode = string(options.SourceMode);
            else
                this.SourceMode = BehaviorBoxEyeTrack.inferSourceMode_(this.SourceHost);
            end
        end

        function tf = connect(this)
            tf = this.IsConnected;
            if tf
                return
            end
            try
                this.prepareBridge_();
                this.openSubscriber_();
                this.IsConnected = true;
                this.LastErrorMessage = "";
                this.SubscriberStartWallClock = datetime("now");
                tf = true;
            catch err
                this.IsConnected = false;
                this.LastErrorMessage = string(err.message);
                tf = false;
            end
        end

        function tf = start(this)
            tf = this.connect();
            if ~tf
                return
            end
            if this.StartTimerOnStart
                this.startPollTimer_();
            end
        end

        function stop(this)
            this.stopPollTimer_();
            this.closeSubscriber_();
            this.IsConnected = false;
            this.SubscriberStopWallClock = datetime("now");
        end

        function close(this)
            this.stop();
        end

        function delete(this)
            this.close();
        end

        function setSessionClock(this, trainStartTime, trainStartWallClock)
            this.TrainStartTime = trainStartTime;
            this.TrainStartWallClock = trainStartWallClock;
        end

        function markTrial(this, trialNumber)
            this.CurrentTrial = double(trialNumber);
        end

        function count = pollAvailable(this, trialNumber)
            arguments
                this
                trialNumber double = NaN
            end
            if ~isnan(trialNumber)
                this.markTrial(trialNumber);
            end
            count = 0;
            if ~this.IsConnected
                if ~this.connect()
                    return
                end
            end
            try
                rawMessage = this.recvLatestJson_();
                if strlength(strtrim(rawMessage)) == 0
                    return
                end
                this.processReading(rawMessage, this.CurrentTrial);
                this.MessagesReceived = this.MessagesReceived + 1;
                count = 1;
            catch err
                this.LastErrorMessage = string(err.message);
                this.stop();
            end
        end

        function row = processReading(this, newReading, trialNumber)
            arguments
                this
                newReading
                trialNumber double = NaN
            end

            if ~isnan(trialNumber)
                this.markTrial(trialNumber);
            end

            line = strtrim(string(newReading));
            if strlength(line) == 0
                row = BehaviorBoxEyeTrack.emptyRecordTable();
                return
            end

            this.RawLog(end+1,1) = line;
            this.Log = this.RawLog;
            receiveTUs = this.currentTrainMicros_();
            this.LastReceiveWallClock = datetime("now");

            [row, latestSample] = this.parseLogLine_(line, receiveTUs, this.CurrentTrial);
            this.LatestSample = latestSample;
            this.ParsedLog = [this.ParsedLog; row];

            if this.DispOutput
                disp(line);
            end
        end

        function record = getRecord(this)
            record = this.ParsedLog;
        end

        function meta = getMeta(this)
            meta = BehaviorBoxEyeTrack.emptyMeta();
            meta.Address = this.Address;
            meta.SourceMode = this.SourceMode;
            meta.SourceHost = this.SourceHost;
            meta.SourcePort = this.SourcePort;
            meta.BridgeDir = this.BridgeDir;
            meta.BridgeAvailable = isfolder(char(this.BridgeDir));
            meta.ModelName = this.ModelName;
            meta.PointNames = this.PointNames;
            meta.PointCount = numel(this.PointNames);
            meta.PlaceholderLiveSubscriber = this.PlaceholderLiveSubscriber;
            meta.IsConnected = this.IsConnected;
            meta.PythonExecutable = this.PythonExecutable;
            meta.SessionClockSource = "BehaviorBoxWheel.TrainStartTime";
            meta.SessionStartWallClock = this.TrainStartWallClock;
            meta.LastReceiveWallClock = this.LastReceiveWallClock;
            meta.SubscriberStartWallClock = this.SubscriberStartWallClock;
            meta.SubscriberStopWallClock = this.SubscriberStopWallClock;
            meta.PollPeriodSeconds = this.PollPeriodSeconds;
            meta.SampleCount = height(this.ParsedLog);
            meta.MessagesReceived = this.MessagesReceived;
            meta.LastErrorMessage = this.LastErrorMessage;
            meta.TimerRunning = this.timerRunning_();
            meta.RecordVariableNames = string(this.ParsedLog.Properties.VariableNames);
            if ~isempty(this.LatestSample)
                meta.LatestSampleStatus = string(this.LatestSample.sampleStatus);
            end
        end

        function Reset(this)
            this.Log = string.empty(0,1);
            this.RawLog = string.empty(0,1);
            this.ParsedLog = BehaviorBoxEyeTrack.emptyRecordTable();
            this.LatestSample = struct();
            this.CurrentTrial = NaN;
            this.LastReceiveWallClock = NaT;
            this.MessagesReceived = 0;
            this.LastErrorMessage = "";
        end
    end

    methods (Static)
        function tbl = emptyRecordTable()
            tbl = table( ...
                'Size', [0 22], ...
                'VariableTypes', { ...
                    'double', 'double', 'double', 'double', 'double', 'string', ...
                    'double', 'string', 'string', 'double', 'double', 'double', ...
                    'double', 'double', 'double', 'double', 'double', 'double', ...
                    'double', 'logical', 'string', 'cell'}, ...
                'VariableNames', { ...
                    'trial', 't_us', 't_pc_receive_us', 'frame_id', ...
                    'capture_time_unix_s', 'capture_time_unix_ns', ...
                    'publish_time_unix_s', 'publish_time_unix_ns', ...
                    'source', 'x', 'y', 'diameter_px', 'diameter_h_px', ...
                    'diameter_v_px', 'confidence', 'valid_points', ...
                    'camera_fps', 'inference_fps', 'latency_ms', ...
                    'isValid', 'sampleStatus', 'points_xyp'});
        end

        function meta = emptyMeta()
            meta = struct( ...
                'Address', "", ...
                'SourceMode', "", ...
                'SourceHost', "", ...
                'SourcePort', NaN, ...
                'BridgeDir', "", ...
                'BridgeAvailable', false, ...
                'ModelName', "", ...
                'PointNames', string.empty(0,1), ...
                'PointCount', 0, ...
                'PlaceholderLiveSubscriber', false, ...
                'IsConnected', false, ...
                'PythonExecutable', "", ...
                'SessionClockSource', "", ...
                'SessionStartWallClock', NaT, ...
                'LastReceiveWallClock', NaT, ...
                'SubscriberStartWallClock', NaT, ...
                'SubscriberStopWallClock', NaT, ...
                'PollPeriodSeconds', NaN, ...
                'SampleCount', 0, ...
                'MessagesReceived', 0, ...
                'LastErrorMessage', "", ...
                'TimerRunning', false, ...
                'LatestSampleStatus', "", ...
                'RecordVariableNames', string.empty(0,1));
        end

        function pointNames = defaultPointNames()
            pointNames = [ ...
                "Lpupil"
                "LDpupil"
                "Dpupil"
                "DRpupil"
                "Rpupil"
                "RVupil"
                "Vpupil"
                "VLpupil"];
        end

        function [isFound, config] = discoverSource()
            address = string(getenv("BB_EYETRACK_ZMQ_ADDRESS"));
            if strlength(strtrim(address)) == 0
                address = "tcp://127.0.0.1:5555";
            end

            [host, port, address] = BehaviorBoxEyeTrack.parseAddress(address);
            bridgeDir = BehaviorBoxEyeTrack.findBridgeDir_();

            config = struct( ...
                'Address', address, ...
                'SourceMode', BehaviorBoxEyeTrack.inferSourceMode_(host), ...
                'SourceHost', host, ...
                'SourcePort', port, ...
                'BridgeDir', bridgeDir, ...
                'ModelName', "DLC_PupilTracking_YangLab_resnet_50_iteration-0_shuffle-1", ...
                'PointNames', BehaviorBoxEyeTrack.defaultPointNames());

            isFound = BehaviorBoxEyeTrack.probeTcpAddress_(host, port);
        end

        function obj = tryCreateFromEnvironment()
            obj = [];
            [isFound, config] = BehaviorBoxEyeTrack.discoverSource();
            if ~isFound
                return
            end
            obj = BehaviorBoxEyeTrack( ...
                Address=config.Address, ...
                SourceMode=config.SourceMode, ...
                SourceHost=config.SourceHost, ...
                SourcePort=config.SourcePort, ...
                BridgeDir=config.BridgeDir, ...
                ModelName=config.ModelName, ...
                PointNames=config.PointNames);
        end

        function [host, port, address] = parseAddress(addressIn)
            address = strtrim(string(addressIn));
            tokens = regexp(char(address), '^tcp://([^:]+):(\d+)$', 'tokens', 'once');
            if isempty(tokens)
                error('BehaviorBoxEyeTrack:InvalidAddress', ...
                    'Expected tcp://host:port eye-track address, got: %s', char(address));
            end
            host = string(tokens{1});
            port = str2double(tokens{2});
        end
    end

    methods (Access = private)
        function prepareBridge_(this)
            if this.usingBridgeAdapter_()
                return
            end

            if strlength(strtrim(this.BridgeDir)) == 0
                this.BridgeDir = BehaviorBoxEyeTrack.findBridgeDir_();
            end
            if strlength(strtrim(this.BridgeDir)) == 0 || ~isfolder(char(this.BridgeDir))
                error('BehaviorBoxEyeTrack:BridgeDirMissing', ...
                    'Could not find EyeTrack MATLAB bridge directory.');
            end

            if strlength(strtrim(this.PythonExecutable)) == 0
                this.PythonExecutable = BehaviorBoxEyeTrack.resolvePythonExecutable_();
            end

            pe = pyenv;
            if pe.Status == "Loaded"
                if string(pe.Executable) ~= this.PythonExecutable
                    error('BehaviorBoxEyeTrack:PythonAlreadyLoaded', ...
                        ['MATLAB already loaded a different Python interpreter: %s. ' ...
                         'Restart MATLAB or terminate(pyenv) first.'], char(pe.Executable));
                end
            else
                pyenv(Version=char(this.PythonExecutable), ExecutionMode="OutOfProcess");
            end

            pyPath = string(cell(py.sys.path));
            if ~any(pyPath == this.BridgeDir)
                py.sys.path.insert(int32(0), char(this.BridgeDir));
            end

            bridge = py.importlib.import_module("matlab_zmq_bridge");
            this.BridgeModule = py.importlib.reload(bridge);
        end

        function openSubscriber_(this)
            this.closeSubscriber_();
            if this.usingBridgeAdapter_()
                this.SubscriberHandle = this.BridgeAdapter.open_subscriber(this.Address, this.RcvHighWaterMark);
            else
                this.SubscriberHandle = this.BridgeModule.open_subscriber(this.Address, int32(this.RcvHighWaterMark));
            end
        end

        function closeSubscriber_(this)
            if isempty(this.SubscriberHandle)
                return
            end
            try
                if this.usingBridgeAdapter_()
                    this.BridgeAdapter.close_socket(this.SubscriberHandle);
                elseif ~isempty(this.BridgeModule)
                    this.BridgeModule.close_socket(this.SubscriberHandle);
                end
            catch
            end
            this.SubscriberHandle = [];
        end

        function startPollTimer_(this)
            if isempty(this.PollTimer) || ~isvalid(this.PollTimer)
                this.PollTimer = timer( ...
                    'ExecutionMode', 'fixedSpacing', ...
                    'BusyMode', 'drop', ...
                    'Period', this.PollPeriodSeconds, ...
                    'TimerFcn', @(~,~) this.pollAvailable());
            end
            if strcmpi(this.PollTimer.Running, 'off')
                start(this.PollTimer);
            end
        end

        function stopPollTimer_(this)
            if isempty(this.PollTimer)
                return
            end
            try
                if isvalid(this.PollTimer)
                    stop(this.PollTimer);
                    delete(this.PollTimer);
                end
            catch
            end
            this.PollTimer = [];
        end

        function rawMessage = recvLatestJson_(this)
            rawMessage = "";
            if isempty(this.SubscriberHandle)
                return
            end
            if this.usingBridgeAdapter_()
                raw = this.BridgeAdapter.recv_latest_json(this.SubscriberHandle, this.PollTimeoutMs);
            else
                raw = this.BridgeModule.recv_latest_json(this.SubscriberHandle, int32(this.PollTimeoutMs));
            end
            try
                rawMessage = string(raw);
            catch
                rawMessage = string(char(raw));
            end
        end

        function tf = usingBridgeAdapter_(this)
            tf = isstruct(this.BridgeAdapter) && ...
                isfield(this.BridgeAdapter, 'open_subscriber') && ...
                isfield(this.BridgeAdapter, 'recv_latest_json') && ...
                isfield(this.BridgeAdapter, 'close_socket');
        end

        function tf = timerRunning_(this)
            tf = false;
            if isempty(this.PollTimer)
                return
            end
            try
                tf = isvalid(this.PollTimer) && strcmpi(this.PollTimer.Running, 'on');
            catch
                tf = false;
            end
        end

        function tUs = currentTrainMicros_(this)
            tUs = NaN;
            if isempty(this.TrainStartTime)
                return
            end
            try
                tUs = round(toc(this.TrainStartTime) * 1e6);
            catch
            end
        end

        function [row, latestSample] = parseLogLine_(this, line, receiveTUs, trialNumber)
            payload = struct();
            sampleStatus = "ok";
            try
                payload = jsondecode(char(line));
            catch
                sampleStatus = "invalid_json";
            end

            pointsXyp = this.emptyPointsMatrix_();
            if sampleStatus ~= "invalid_json"
                [pointsXyp, pointStatus] = this.pointsMatrixFromPayload_(payload);
                if pointStatus ~= "ok"
                    sampleStatus = pointStatus;
                end
            end

            row = BehaviorBoxEyeTrack.recordRow_( ...
                double(trialNumber), ...
                double(receiveTUs), ...
                double(receiveTUs), ...
                this.readNumericField_(payload, 'frame_id'), ...
                this.readNumericField_(payload, 'capture_time_unix_s'), ...
                this.readIntegerTextField_(line, 'capture_time_unix_ns'), ...
                this.readNumericField_(payload, 'publish_time_unix_s'), ...
                this.readIntegerTextField_(line, 'publish_time_unix_ns'), ...
                this.readStringField_(payload, 'source', ""), ...
                this.readNumericField_(payload, 'center_x'), ...
                this.readNumericField_(payload, 'center_y'), ...
                this.readNumericField_(payload, 'diameter_px'), ...
                this.readNumericField_(payload, 'diameter_h_px'), ...
                this.readNumericField_(payload, 'diameter_v_px'), ...
                this.readNumericField_(payload, 'confidence_mean'), ...
                this.readNumericField_(payload, 'valid_points'), ...
                this.readNumericField_(payload, 'camera_fps'), ...
                this.readNumericField_(payload, 'inference_fps'), ...
                this.readNumericField_(payload, 'latency_ms'), ...
                this.sampleIsValid_(payload, sampleStatus), ...
                sampleStatus, ...
                pointsXyp);

            latestSample = table2struct(row, 'ToScalar', true);
        end

        function [pointsXyp, sampleStatus] = pointsMatrixFromPayload_(this, payload)
            pointsXyp = this.emptyPointsMatrix_();
            sampleStatus = "missing_points";

            if ~isstruct(payload) || ~isfield(payload, 'points') || ~isstruct(payload.points)
                return
            end

            pointsPayload = payload.points;
            filled = false(numel(this.PointNames), 1);
            for iPoint = 1:numel(this.PointNames)
                name = char(this.PointNames(iPoint));
                if ~isfield(pointsPayload, name)
                    continue
                end
                values = double(pointsPayload.(name));
                if numel(values) < 3
                    continue
                end
                pointsXyp(iPoint, :) = reshape(values(1:3), 1, 3);
                filled(iPoint) = true;
            end

            if all(filled)
                sampleStatus = "ok";
            elseif any(filled)
                sampleStatus = "partial_points";
            end
        end

        function tf = sampleIsValid_(this, payload, sampleStatus)
            tf = false;
            if sampleStatus == "invalid_json"
                return
            end
            validPoints = this.readNumericField_(payload, 'valid_points');
            x = this.readNumericField_(payload, 'center_x');
            y = this.readNumericField_(payload, 'center_y');
            tf = validPoints > 0 && ~isnan(x) && ~isnan(y);
        end

        function pointsXyp = emptyPointsMatrix_(this)
            pointsXyp = nan(numel(this.PointNames), 3);
        end

        function value = readNumericField_(~, payload, fieldName)
            value = NaN;
            if ~isstruct(payload) || ~isfield(payload, fieldName)
                return
            end
            raw = payload.(fieldName);
            if ischar(raw) || isstring(raw)
                value = str2double(string(raw));
            elseif isnumeric(raw) || islogical(raw)
                value = double(raw);
            end
            if isempty(value) || ~isscalar(value) || ~isfinite(value)
                if isscalar(value) && isnan(value)
                    return
                end
                value = NaN;
            end
        end

        function value = readStringField_(~, payload, fieldName, defaultValue)
            value = string(defaultValue);
            if ~isstruct(payload) || ~isfield(payload, fieldName)
                return
            end
            value = string(payload.(fieldName));
        end

        function value = readIntegerTextField_(~, line, fieldName)
            value = "";
            pattern = '"' + string(fieldName) + '"\s*:\s*([0-9]+)';
            tokens = regexp(char(line), char(pattern), 'tokens', 'once');
            if isempty(tokens)
                return
            end
            value = string(tokens{1});
        end
    end

    methods (Static, Access = private)
        function row = recordRow_(trial, tUs, tPcReceiveUs, frameId, captureTimeS, captureTimeNs, ...
                publishTimeS, publishTimeNs, source, x, y, diameterPx, diameterHPx, ...
                diameterVPx, confidence, validPoints, cameraFps, inferenceFps, latencyMs, ...
                isValid, sampleStatus, pointsXyp)
            row = table( ...
                double(trial), ...
                double(tUs), ...
                double(tPcReceiveUs), ...
                double(frameId), ...
                double(captureTimeS), ...
                string(captureTimeNs), ...
                double(publishTimeS), ...
                string(publishTimeNs), ...
                string(source), ...
                double(x), ...
                double(y), ...
                double(diameterPx), ...
                double(diameterHPx), ...
                double(diameterVPx), ...
                double(confidence), ...
                double(validPoints), ...
                double(cameraFps), ...
                double(inferenceFps), ...
                double(latencyMs), ...
                logical(isValid), ...
                string(sampleStatus), ...
                {double(pointsXyp)}, ...
                'VariableNames', { ...
                    'trial', 't_us', 't_pc_receive_us', 'frame_id', ...
                    'capture_time_unix_s', 'capture_time_unix_ns', ...
                    'publish_time_unix_s', 'publish_time_unix_ns', ...
                    'source', 'x', 'y', 'diameter_px', 'diameter_h_px', ...
                    'diameter_v_px', 'confidence', 'valid_points', ...
                    'camera_fps', 'inference_fps', 'latency_ms', ...
                    'isValid', 'sampleStatus', 'points_xyp'});
        end

        function pythonExe = resolvePythonExecutable_()
            override = BehaviorBoxEyeTrack.getOptionalEnv_("BB_EYETRACK_PYTHON", "");
            if strlength(override) > 0
                if ~isfile(override)
                    error('BehaviorBoxEyeTrack:PythonMissing', ...
                        'BB_EYETRACK_PYTHON points to a missing file: %s', char(override));
                end
                pythonExe = override;
                return
            end

            condaPrefix = BehaviorBoxEyeTrack.getOptionalEnv_("CONDA_PREFIX", "");
            if strlength(condaPrefix) > 0
                candidate = BehaviorBoxEyeTrack.pythonInEnv_(condaPrefix);
                if isfile(candidate)
                    pythonExe = candidate;
                    return
                end
            end

            homeDir = BehaviorBoxEyeTrack.getOptionalEnv_("HOME", "");
            if strlength(homeDir) == 0 && ispc
                homeDir = BehaviorBoxEyeTrack.getOptionalEnv_("USERPROFILE", "");
            end

            candidateRoots = strings(0,1);
            if strlength(homeDir) > 0
                candidateRoots = [ ...
                    fullfile(homeDir, "miniforge3", "envs", "dlclivegui")
                    fullfile(homeDir, "mambaforge", "envs", "dlclivegui")
                    fullfile(homeDir, "miniconda3", "envs", "dlclivegui")
                    fullfile(homeDir, "anaconda3", "envs", "dlclivegui")];
            end

            for idx = 1:numel(candidateRoots)
                candidate = BehaviorBoxEyeTrack.pythonInEnv_(candidateRoots(idx));
                if isfile(candidate)
                    pythonExe = candidate;
                    return
                end
            end

            error('BehaviorBoxEyeTrack:PythonNotFound', ...
                ['Could not find Python for the dlclivegui environment. ' ...
                 'Set BB_EYETRACK_PYTHON to the full path of the environment''s Python executable.']);
        end

        function sourceMode = inferSourceMode_(host)
            host = lower(strtrim(string(host)));
            if any(host == ["localhost", "127.0.0.1"])
                sourceMode = "localhost";
            else
                sourceMode = "remote";
            end
        end

        function bridgeDir = findBridgeDir_()
            repoRoot = fileparts(mfilename("fullpath"));
            candidates = [ ...
                fullfile(repoRoot, "EyeTrack", "DeepLabCut", "ToMatlab")
                fullfile(repoRoot, "DLC", "ToMatlab")];
            bridgeDir = "";
            for candidate = candidates'
                if isfolder(candidate)
                    bridgeDir = string(candidate);
                    return
                end
            end
        end

        function tf = probeTcpAddress_(host, port)
            tf = false;
            if strlength(strtrim(host)) == 0 || isnan(port)
                return
            end
            try
                tcpclient(char(host), port, "Timeout", 0.2);
                tf = true;
            catch
                tf = false;
            end
        end

        function value = getOptionalEnv_(name, fallback)
            value = string(getenv(name));
            if strlength(strtrim(value)) == 0
                value = string(fallback);
            end
        end

        function candidate = pythonInEnv_(envRoot)
            if ispc
                candidate = fullfile(envRoot, "python.exe");
            else
                candidate = fullfile(envRoot, "bin", "python");
            end
        end
    end
end
