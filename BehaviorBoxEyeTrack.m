classdef BehaviorBoxEyeTrack < handle
    % BehaviorBox eye-tracking log helper for the DLCLive -> ZeroMQ stream.
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
        IsReady logical = false
        LastReceiveWallClock = NaT
        LastSampleReceiveWallClock = NaT
        SubscriberStartWallClock = NaT
        SubscriberStopWallClock = NaT
        ReadyWallClock = NaT
        PollPeriodSeconds double = 0.02
        PollTimeoutMs double = 10
        RcvHighWaterMark double = 10000
        WaitForReadySeconds double = 2
        StaleTimeoutSeconds double = 2
        MaxDrainMessages double = 10000
        ChunkSize double = 5000
        StartTimerOnStart logical = true
        MessagesReceived double = 0
        SamplesReceived double = 0
        MetadataMessagesReceived double = 0
        MissingFrameCount double = 0
        FrameIdGapCount double = 0
        StaleEventCount double = 0
        LastFrameId double = NaN
        ReadySampleFrameId double = NaN
        LastErrorMessage string = ""
        BridgeAdapter struct = struct()
        BridgeModule = []
        SubscriberHandle = []
        PollTimer = []
        StreamMetadata struct = struct()
        TrialBoundaryUs double = double.empty(0,1)
        TrialBoundaryValues double = double.empty(0,1)
    end

    properties (Access = private)
        RecordChunks cell = {}
        CurrentRows = struct.empty(0,1)
        CurrentChunkCount double = 0
        StartupWarningIssued logical = false
        NotReadyWarningIssued logical = false
        RuntimeWarningIssued logical = false
        FrameGapWarningIssued logical = false
        StaleActive logical = false
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
                options.RcvHighWaterMark double = 10000
                options.WaitForReadySeconds double = 2
                options.StaleTimeoutSeconds double = 2
                options.MaxDrainMessages double = 10000
                options.ChunkSize double = 5000
                options.StartTimerOnStart logical = true
                options.BridgeAdapter struct = struct()
            end

            this.PointNames = string(options.PointNames(:));
            this.ParsedLog = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
            this.ModelName = string(options.ModelName);
            this.BridgeDir = string(options.BridgeDir);
            this.PythonExecutable = string(options.PythonExecutable);
            this.PollPeriodSeconds = double(options.PollPeriodSeconds);
            this.PollTimeoutMs = double(options.PollTimeoutMs);
            this.RcvHighWaterMark = double(options.RcvHighWaterMark);
            this.WaitForReadySeconds = double(options.WaitForReadySeconds);
            this.StaleTimeoutSeconds = double(options.StaleTimeoutSeconds);
            this.MaxDrainMessages = double(options.MaxDrainMessages);
            this.ChunkSize = double(options.ChunkSize);
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
                this.warnStartupUnavailable_(err.message);
            end
        end

        function tf = start(this)
            tf = this.connect();
            if ~tf
                return
            end

            this.waitForReady_();
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
            tUs = this.currentTrainMicros_();
            if isnan(tUs)
                if isempty(this.TrialBoundaryUs)
                    tUs = 0;
                else
                    tUs = this.TrialBoundaryUs(end);
                end
            end
            this.TrialBoundaryUs(end+1,1) = double(tUs);
            this.TrialBoundaryValues(end+1,1) = double(trialNumber);
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
            if ~this.IsConnected && ~this.connect()
                return
            end

            try
                count = this.drainAvailable_([], this.PollTimeoutMs);
                this.checkStale_();
            catch err
                this.LastErrorMessage = string(err.message);
                this.warnRuntimeFailure_(err.message);
            end
        end

        function count = finalDrain(this)
            count = 0;
            if ~this.IsConnected
                return
            end
            try
                count = this.drainAvailable_(NaN, this.PollTimeoutMs);
                this.checkStale_();
            catch err
                this.LastErrorMessage = string(err.message);
                this.warnRuntimeFailure_(err.message);
            end
        end

        function rows = processReading(this, newReading, trialNumber)
            arguments
                this
                newReading
                trialNumber double = NaN
            end

            if ~isnan(trialNumber)
                this.markTrial(trialNumber);
            end

            try
                rows = this.processRawJson_(string(newReading), []);
                this.checkStale_();
            catch err
                this.LastErrorMessage = string(err.message);
                this.warnRuntimeFailure_(err.message);
                rows = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
            end
        end

        function record = getRecord(this)
            record = this.recordFromChunks_();
            this.ParsedLog = record;
        end

        function meta = getMeta(this)
            record = this.getRecord();
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
            meta.IsReady = this.IsReady;
            meta.PythonExecutable = this.PythonExecutable;
            meta.SessionClockSource = "capture_time_unix_ns - BehaviorBoxWheel.TrainStartWallClock";
            meta.SessionStartWallClock = this.TrainStartWallClock;
            meta.LastReceiveWallClock = this.LastReceiveWallClock;
            meta.LastSampleReceiveWallClock = this.LastSampleReceiveWallClock;
            meta.SubscriberStartWallClock = this.SubscriberStartWallClock;
            meta.SubscriberStopWallClock = this.SubscriberStopWallClock;
            meta.ReadyWallClock = this.ReadyWallClock;
            meta.ReadySampleFrameId = this.ReadySampleFrameId;
            meta.PollPeriodSeconds = this.PollPeriodSeconds;
            meta.PollTimeoutMs = this.PollTimeoutMs;
            meta.RcvHighWaterMark = this.RcvHighWaterMark;
            meta.WaitForReadySeconds = this.WaitForReadySeconds;
            meta.StaleTimeoutSeconds = this.StaleTimeoutSeconds;
            meta.MaxDrainMessages = this.MaxDrainMessages;
            meta.ChunkSize = this.ChunkSize;
            meta.SampleCount = height(record);
            meta.MessagesReceived = this.MessagesReceived;
            meta.SamplesReceived = this.SamplesReceived;
            meta.MetadataMessagesReceived = this.MetadataMessagesReceived;
            meta.MissingFrameCount = this.MissingFrameCount;
            meta.FrameIdGapCount = this.FrameIdGapCount;
            meta.StaleEventCount = this.StaleEventCount;
            meta.LastFrameId = this.LastFrameId;
            meta.LastErrorMessage = this.LastErrorMessage;
            meta.TimerRunning = this.timerRunning_();
            meta.LatestSampleStatus = "";
            if ~isempty(this.LatestSample) && isfield(this.LatestSample, 'sample_status')
                meta.LatestSampleStatus = string(this.LatestSample.sample_status);
            end
            meta.RecordVariableNames = string(record.Properties.VariableNames);
            meta.StreamMetadata = this.StreamMetadata;
            meta.CsvPath = this.readMetadataString_("csv_path", "");
            meta.MetadataPath = this.readMetadataString_("metadata_path", "");
            meta.SchemaVersion = this.readMetadataNumeric_("schema_version", NaN);
            meta.TrialBoundaryUs = this.TrialBoundaryUs;
            meta.TrialBoundaryValues = this.TrialBoundaryValues;
        end

        function Reset(this)
            this.Log = string.empty(0,1);
            this.RawLog = string.empty(0,1);
            this.ParsedLog = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
            this.LatestSample = struct();
            this.CurrentTrial = NaN;
            this.LastReceiveWallClock = NaT;
            this.LastSampleReceiveWallClock = NaT;
            this.ReadyWallClock = NaT;
            this.MessagesReceived = 0;
            this.SamplesReceived = 0;
            this.MetadataMessagesReceived = 0;
            this.MissingFrameCount = 0;
            this.FrameIdGapCount = 0;
            this.StaleEventCount = 0;
            this.LastFrameId = NaN;
            this.ReadySampleFrameId = NaN;
            this.IsReady = false;
            this.LastErrorMessage = "";
            this.StreamMetadata = struct();
            this.TrialBoundaryUs = double.empty(0,1);
            this.TrialBoundaryValues = double.empty(0,1);
            this.RecordChunks = {};
            this.CurrentRows = struct.empty(0,1);
            this.CurrentChunkCount = 0;
            this.NotReadyWarningIssued = false;
            this.RuntimeWarningIssued = false;
            this.FrameGapWarningIssued = false;
            this.StaleActive = false;
        end
    end

    methods (Static)
        function tbl = emptyRecordTable(pointNames)
            if nargin < 1
                pointNames = BehaviorBoxEyeTrack.defaultPointNames();
            end
            variableNames = BehaviorBoxEyeTrack.recordVariableNames(pointNames);
            variableTypes = BehaviorBoxEyeTrack.recordVariableTypes(pointNames);
            tbl = table('Size', [0 numel(variableNames)], ...
                'VariableTypes', cellstr(variableTypes), ...
                'VariableNames', cellstr(variableNames));
        end

        function names = recordVariableNames(pointNames)
            if nargin < 1
                pointNames = BehaviorBoxEyeTrack.defaultPointNames();
            end
            baseNames = [ ...
                "trial"
                "t_us"
                "t_receive_us"
                "frame_id"
                "capture_time_unix_s"
                "capture_time_unix_ns"
                "publish_time_unix_s"
                "publish_time_unix_ns"
                "center_x"
                "center_y"
                "diameter_px"
                "diameter_h_px"
                "diameter_v_px"
                "confidence_mean"
                "valid_points"
                "camera_fps"
                "inference_fps"
                "latency_ms"
                "is_valid"
                "sample_status"];
            pointColumns = BehaviorBoxEyeTrack.pointColumnNames(pointNames);
            names = [baseNames; pointColumns(:)];
        end

        function types = recordVariableTypes(pointNames)
            if nargin < 1
                pointNames = BehaviorBoxEyeTrack.defaultPointNames();
            end
            baseTypes = [ ...
                "double"
                "double"
                "double"
                "double"
                "double"
                "string"
                "double"
                "string"
                "double"
                "double"
                "double"
                "double"
                "double"
                "double"
                "double"
                "double"
                "double"
                "double"
                "logical"
                "string"];
            pointTypes = repmat("double", numel(BehaviorBoxEyeTrack.pointColumnNames(pointNames)), 1);
            types = [baseTypes; pointTypes(:)];
        end

        function pointColumns = pointColumnNames(pointNames)
            pointNames = string(pointNames(:));
            pointColumns = strings(numel(pointNames) * 3, 1);
            outIdx = 0;
            for idx = 1:numel(pointNames)
                base = matlab.lang.makeValidName(char(pointNames(idx)));
                outIdx = outIdx + 1;
                pointColumns(outIdx) = string(base) + "_x";
                outIdx = outIdx + 1;
                pointColumns(outIdx) = string(base) + "_y";
                outIdx = outIdx + 1;
                pointColumns(outIdx) = string(base) + "_likelihood";
            end
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
                'IsReady', false, ...
                'PythonExecutable', "", ...
                'SessionClockSource', "", ...
                'SessionStartWallClock', NaT, ...
                'LastReceiveWallClock', NaT, ...
                'LastSampleReceiveWallClock', NaT, ...
                'SubscriberStartWallClock', NaT, ...
                'SubscriberStopWallClock', NaT, ...
                'ReadyWallClock', NaT, ...
                'ReadySampleFrameId', NaN, ...
                'PollPeriodSeconds', NaN, ...
                'PollTimeoutMs', NaN, ...
                'RcvHighWaterMark', NaN, ...
                'WaitForReadySeconds', NaN, ...
                'StaleTimeoutSeconds', NaN, ...
                'MaxDrainMessages', NaN, ...
                'ChunkSize', NaN, ...
                'SampleCount', 0, ...
                'MessagesReceived', 0, ...
                'SamplesReceived', 0, ...
                'MetadataMessagesReceived', 0, ...
                'MissingFrameCount', 0, ...
                'FrameIdGapCount', 0, ...
                'StaleEventCount', 0, ...
                'LastFrameId', NaN, ...
                'LastErrorMessage', "", ...
                'TimerRunning', false, ...
                'LatestSampleStatus', "", ...
                'RecordVariableNames', string.empty(0,1), ...
                'StreamMetadata', struct(), ...
                'CsvPath', "", ...
                'MetadataPath', "", ...
                'SchemaVersion', NaN, ...
                'TrialBoundaryUs', double.empty(0,1), ...
                'TrialBoundaryValues', double.empty(0,1));
        end

        function pointNames = defaultPointNames()
            pointNames = [ ...
                "Lpupil"
                "LDpupil"
                "Dpupil"
                "DRpupil"
                "Rpupil"
                "RVpupil"
                "Vpupil"
                "VLpupil"];
        end

        function out = alignEyeSamplesToTable(eyeRecord, targetTable, varargin)
            options = BehaviorBoxEyeTrack.parseAlignmentOptions_(varargin{:});
            out = targetTable;
            out = BehaviorBoxEyeTrack.ensureEyeAlignmentColumns_(out);
            if isempty(out) || height(out) == 0 || isempty(eyeRecord) || height(eyeRecord) == 0
                return
            end
            if ~ismember(options.TimeColumn, string(out.Properties.VariableNames)) || ...
                    ~ismember("t_us", string(eyeRecord.Properties.VariableNames))
                return
            end

            eyeRecord = sortrows(eyeRecord, "t_us");
            eyeT = double(eyeRecord.t_us);
            keep = isfinite(eyeT);
            eyeRecord = eyeRecord(keep, :);
            eyeT = eyeT(keep);
            if isempty(eyeT)
                return
            end

            targetT = double(out.(char(options.TimeColumn)));
            for rowIdx = 1:height(out)
                tNow = targetT(rowIdx);
                if ~isfinite(tNow)
                    continue
                end

                previousIdx = find(eyeT <= tNow, 1, "last");
                if ~isempty(previousIdx)
                    out = BehaviorBoxEyeTrack.copyRepresentativeEyeSample_(out, rowIdx, eyeRecord(previousIdx, :), tNow);
                end

                if options.IntervalDirection == "next"
                    tStart = tNow;
                    if rowIdx < numel(targetT) && isfinite(targetT(rowIdx + 1))
                        tEnd = targetT(rowIdx + 1);
                    else
                        tEnd = options.SessionEndUs;
                    end
                    intervalMask = eyeT >= tStart & eyeT < tEnd;
                else
                    if rowIdx > 1 && isfinite(targetT(rowIdx - 1))
                        tStart = targetT(rowIdx - 1);
                    else
                        tStart = -Inf;
                    end
                    tEnd = tNow;
                    intervalMask = eyeT > tStart & eyeT <= tEnd;
                end

                intervalIdx = find(intervalMask);
                out.eye_sample_count(rowIdx) = numel(intervalIdx);
                if options.Mode == "interval_summary"
                    out = BehaviorBoxEyeTrack.copyEyeIntervalSummary_(out, rowIdx, eyeRecord(intervalIdx, :));
                end
            end
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
        function count = drainAvailable_(this, trialOverride, timeoutMs)
            rawMessage = this.recvAllJson_(timeoutMs);
            count = 0;
            if strlength(strtrim(rawMessage)) == 0
                return
            end
            rows = this.processRawJson_(rawMessage, trialOverride);
            count = height(rows);
        end

        function rows = processRawJson_(this, rawMessage, trialOverride)
            rawMessage = strtrim(string(rawMessage));
            rows = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
            if strlength(rawMessage) == 0 || rawMessage == "[]"
                return
            end

            decoded = jsondecode(char(rawMessage));
            payloads = BehaviorBoxEyeTrack.payloadCellArray_(decoded);
            for idx = 1:numel(payloads)
                payload = payloads{idx};
                this.MessagesReceived = this.MessagesReceived + 1;
                this.LastReceiveWallClock = datetime("now");
                rawLine = jsonencode(payload);
                this.RawLog(end+1,1) = string(rawLine);
                this.Log = this.RawLog;

                if this.DispOutput
                    disp(rawLine);
                end

                [row, didAppend] = this.processPayload_(payload, string(rawLine), trialOverride);
                if didAppend
                    rows = [rows; row]; %#ok<AGROW>
                end
            end
            if height(rows) > 0
                this.ParsedLog = this.recordFromChunks_();
            end
        end

        function [row, didAppend] = processPayload_(this, payload, rawLine, trialOverride)
            row = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
            didAppend = false;
            messageType = this.readStringField_(payload, 'message_type', "sample");

            this.updatePointNamesFromPayload_(payload);
            this.updateMetadataFromPayload_(payload, messageType);

            if messageType == "metadata"
                this.MetadataMessagesReceived = this.MetadataMessagesReceived + 1;
                return
            end

            [points, pointsPresent] = this.pointsFromPayload_(payload);
            status = this.readStringField_(payload, 'sample_status', "");
            if strlength(status) == 0
                if all(pointsPresent)
                    status = "ok";
                elseif any(pointsPresent)
                    status = "partial_points";
                else
                    status = "missing_points";
                end
            end

            receiveTUs = this.currentTrainMicros_();
            captureTUs = this.captureTimeUs_(payload, rawLine);
            if isnan(captureTUs)
                tUs = receiveTUs;
            else
                tUs = captureTUs;
            end
            trial = this.assignTrial_(tUs, trialOverride);

            rowStruct = this.rowStructFromPayload_(payload, rawLine, points, trial, tUs, receiveTUs, status, pointsPresent);
            this.appendRowStruct_(rowStruct);
            this.LatestSample = rowStruct;
            this.SamplesReceived = this.SamplesReceived + 1;
            this.LastSampleReceiveWallClock = datetime("now");
            this.updateReadiness_(rowStruct, pointsPresent);
            this.updateFrameGap_(rowStruct.frame_id);

            row = struct2table(rowStruct, 'AsArray', true);
            row = row(:, cellstr(BehaviorBoxEyeTrack.recordVariableNames(this.PointNames)));
            didAppend = true;
        end

        function rowStruct = rowStructFromPayload_(this, payload, rawLine, points, trial, tUs, receiveTUs, status, pointsPresent)
            names = BehaviorBoxEyeTrack.recordVariableNames(this.PointNames);
            rowStruct = struct();
            for idx = 1:numel(names)
                rowStruct.(char(names(idx))) = BehaviorBoxEyeTrack.defaultValueForRecordVariable_(names(idx));
            end

            rowStruct.trial = double(trial);
            rowStruct.t_us = double(tUs);
            rowStruct.t_receive_us = double(receiveTUs);
            rowStruct.frame_id = this.readNumericField_(payload, 'frame_id');
            rowStruct.capture_time_unix_s = this.readNumericField_(payload, 'capture_time_unix_s');
            rowStruct.capture_time_unix_ns = this.readIntegerTextField_(rawLine, payload, 'capture_time_unix_ns');
            rowStruct.publish_time_unix_s = this.readNumericField_(payload, 'publish_time_unix_s');
            rowStruct.publish_time_unix_ns = this.readIntegerTextField_(rawLine, payload, 'publish_time_unix_ns');
            rowStruct.center_x = this.readNumericField_(payload, 'center_x');
            rowStruct.center_y = this.readNumericField_(payload, 'center_y');
            rowStruct.diameter_px = this.readNumericField_(payload, 'diameter_px');
            rowStruct.diameter_h_px = this.readNumericField_(payload, 'diameter_h_px');
            rowStruct.diameter_v_px = this.readNumericField_(payload, 'diameter_v_px');
            rowStruct.confidence_mean = this.readNumericField_(payload, 'confidence_mean');
            rowStruct.valid_points = this.readNumericField_(payload, 'valid_points');
            rowStruct.camera_fps = this.readNumericField_(payload, 'camera_fps');
            rowStruct.inference_fps = this.readNumericField_(payload, 'inference_fps');
            rowStruct.latency_ms = this.readNumericField_(payload, 'latency_ms');
            rowStruct.is_valid = this.sampleIsValid_(payload, status);
            rowStruct.sample_status = string(status);

            pointColumns = BehaviorBoxEyeTrack.pointColumnNames(this.PointNames);
            for iPoint = 1:numel(this.PointNames)
                colBase = (iPoint - 1) * 3;
                rowStruct.(char(pointColumns(colBase + 1))) = double(points(iPoint, 1));
                rowStruct.(char(pointColumns(colBase + 2))) = double(points(iPoint, 2));
                rowStruct.(char(pointColumns(colBase + 3))) = double(points(iPoint, 3));
            end

            if ~all(pointsPresent)
                rowStruct.is_valid = rowStruct.is_valid && any(pointsPresent);
            end
        end

        function appendRowStruct_(this, rowStruct)
            this.CurrentChunkCount = this.CurrentChunkCount + 1;
            if this.CurrentChunkCount == 1
                this.CurrentRows = rowStruct;
            else
                this.CurrentRows(this.CurrentChunkCount, 1) = rowStruct;
            end
            if this.CurrentChunkCount >= this.ChunkSize
                this.flushCurrentChunk_();
            end
        end

        function flushCurrentChunk_(this)
            if this.CurrentChunkCount == 0
                return
            end
            this.RecordChunks{end+1,1} = this.CurrentRows(:);
            this.CurrentRows = struct.empty(0,1);
            this.CurrentChunkCount = 0;
        end

        function record = recordFromChunks_(this)
            rows = [];
            for idx = 1:numel(this.RecordChunks)
                if isempty(rows)
                    rows = this.RecordChunks{idx}(:);
                else
                    rows = [rows; this.RecordChunks{idx}(:)]; %#ok<AGROW>
                end
            end
            if this.CurrentChunkCount > 0
                if isempty(rows)
                    rows = this.CurrentRows(:);
                else
                    rows = [rows; this.CurrentRows(:)];
                end
            end
            if isempty(rows)
                record = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
                return
            end
            record = struct2table(rows);
            record = record(:, cellstr(BehaviorBoxEyeTrack.recordVariableNames(this.PointNames)));
        end

        function updatePointNamesFromPayload_(this, payload)
            if this.SamplesReceived > 0 || ~isstruct(payload) || ~isfield(payload, 'point_names')
                return
            end
            names = BehaviorBoxEyeTrack.readStringArrayField_(payload, 'point_names');
            if isempty(names)
                return
            end
            this.PointNames = names(:);
            this.ParsedLog = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
        end

        function updateMetadataFromPayload_(this, payload, messageType)
            if ~isstruct(payload)
                return
            end
            fields = fieldnames(payload);
            if string(messageType) ~= "metadata"
                staticFields = [ ...
                    "schema_version"
                    "source"
                    "address"
                    "csv_path"
                    "metadata_path"
                    "model_preset"
                    "model_type"
                    "point_names"
                    "point_count"
                    "pcutoff"
                    "pose_coordinate_frame"
                    "camera_serial"
                    "camera_model"
                    "sensor_roi_x"
                    "sensor_roi_y"
                    "sensor_roi_width"
                    "sensor_roi_height"
                    "crop_x1"
                    "crop_x2"
                    "crop_y1"
                    "crop_y2"];
                fields = intersect(fields, cellstr(staticFields), 'stable');
            end
            for idx = 1:numel(fields)
                fieldName = fields{idx};
                if strcmp(fieldName, 'points')
                    continue
                end
                this.StreamMetadata.(fieldName) = payload.(fieldName);
            end
        end

        function [points, pointsPresent] = pointsFromPayload_(this, payload)
            points = nan(numel(this.PointNames), 3);
            pointsPresent = false(numel(this.PointNames), 1);
            if ~isstruct(payload) || ~isfield(payload, 'points') || ~isstruct(payload.points)
                return
            end

            pointsPayload = payload.points;
            for iPoint = 1:numel(this.PointNames)
                name = char(this.PointNames(iPoint));
                if ~isfield(pointsPayload, name)
                    continue
                end
                values = double(pointsPayload.(name));
                if numel(values) < 3
                    continue
                end
                points(iPoint, :) = reshape(values(1:3), 1, 3);
                pointsPresent(iPoint) = true;
            end
        end

        function updateReadiness_(this, rowStruct, pointsPresent)
            status = string(rowStruct.sample_status);
            readyStatus = any(status == ["ok", "partial_points"]);
            readyNames = all(pointsPresent);
            if ~this.IsReady && readyStatus && readyNames
                this.IsReady = true;
                this.ReadyWallClock = datetime("now");
                this.ReadySampleFrameId = double(rowStruct.frame_id);
                this.StaleActive = false;
            end
        end

        function updateFrameGap_(this, frameId)
            frameId = double(frameId);
            if isnan(frameId)
                return
            end
            if ~isnan(this.LastFrameId) && frameId > this.LastFrameId + 1
                missing = frameId - this.LastFrameId - 1;
                this.MissingFrameCount = this.MissingFrameCount + missing;
                this.FrameIdGapCount = this.FrameIdGapCount + 1;
                if ~this.FrameGapWarningIssued
                    warning('BehaviorBoxEyeTrack:FrameIdGap', ...
                        ['Eye tracking observed a FLIR frame_id gap. This can be normal when ' ...
                         'camera acquisition outruns DLC inference; MissingFrameCount will track it.']);
                    this.FrameGapWarningIssued = true;
                end
            end
            this.LastFrameId = frameId;
        end

        function checkStale_(this)
            if ~this.IsReady || isnat(this.LastSampleReceiveWallClock)
                return
            end
            elapsed = seconds(datetime("now") - this.LastSampleReceiveWallClock);
            if elapsed >= this.StaleTimeoutSeconds
                if ~this.StaleActive
                    this.StaleEventCount = this.StaleEventCount + 1;
                    warning('BehaviorBoxEyeTrack:StaleStream', ...
                        'No eye tracking sample has been received for %.1f seconds.', elapsed);
                    this.StaleActive = true;
                end
            else
                this.StaleActive = false;
            end
        end

        function waitForReady_(this)
            if this.IsReady
                return
            end
            startTic = tic;
            while ~this.IsReady && toc(startTic) < this.WaitForReadySeconds
                this.drainAvailable_([], 50);
                if ~this.IsReady
                    pause(0.02);
                end
            end
            if ~this.IsReady && ~this.NotReadyWarningIssued
                warning('BehaviorBoxEyeTrack:NotReady', ...
                    ['Eye tracking subscriber opened, but no ready sample arrived within %.1f seconds. ' ...
                     'The behavior session can continue; eye tracking will become ready after a valid sample.'], ...
                    this.WaitForReadySeconds);
                this.NotReadyWarningIssued = true;
            end
        end

        function tUs = captureTimeUs_(this, payload, rawLine)
            tUs = NaN;
            if isempty(this.TrainStartWallClock) || isnat(this.TrainStartWallClock)
                return
            end
            sessionStartUnixUs = round(posixtime(this.TrainStartWallClock) * 1e6);
            captureNs = this.readIntegerTextField_(rawLine, payload, 'capture_time_unix_ns');
            if strlength(captureNs) > 0
                captureUnixUs = floor(str2double(captureNs) / 1000);
            else
                captureTimeS = this.readNumericField_(payload, 'capture_time_unix_s');
                if isnan(captureTimeS)
                    return
                end
                captureUnixUs = round(captureTimeS * 1e6);
            end
            tUs = double(captureUnixUs - sessionStartUnixUs);
        end

        function trial = assignTrial_(this, tUs, trialOverride)
            if ~isempty(trialOverride)
                trial = double(trialOverride);
                return
            end
            if isempty(this.TrialBoundaryUs)
                if isnan(this.CurrentTrial)
                    trial = 0;
                else
                    trial = this.CurrentTrial;
                end
                return
            end
            if isnan(tUs)
                trial = this.TrialBoundaryValues(end);
                return
            end
            idx = find(this.TrialBoundaryUs <= tUs, 1, "last");
            if isempty(idx)
                trial = 0;
            else
                trial = this.TrialBoundaryValues(idx);
            end
        end

        function tf = sampleIsValid_(this, payload, sampleStatus)
            tf = false;
            if ~any(string(sampleStatus) == ["ok", "partial_points"])
                return
            end
            validPoints = this.readNumericField_(payload, 'valid_points');
            x = this.readNumericField_(payload, 'center_x');
            y = this.readNumericField_(payload, 'center_y');
            tf = validPoints > 0 && ~isnan(x) && ~isnan(y);
        end

        function value = readNumericField_(~, payload, fieldName)
            value = NaN;
            if ~isstruct(payload) || ~isfield(payload, fieldName)
                return
            end
            raw = payload.(fieldName);
            if isempty(raw)
                return
            end
            if ischar(raw) || isstring(raw)
                value = str2double(string(raw));
            elseif isnumeric(raw) || islogical(raw)
                value = double(raw);
            end
            if isempty(value) || ~isscalar(value) || (~isfinite(value) && ~isnan(value))
                value = NaN;
            end
        end

        function value = readStringField_(~, payload, fieldName, defaultValue)
            value = string(defaultValue);
            if ~isstruct(payload) || ~isfield(payload, fieldName)
                return
            end
            raw = payload.(fieldName);
            if isempty(raw)
                return
            end
            value = string(raw);
        end

        function value = readIntegerTextField_(~, line, payload, fieldName)
            value = "";
            pattern = '"' + string(fieldName) + '"\s*:\s*("?[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?"?)';
            tokens = regexp(char(line), char(pattern), 'tokens', 'once');
            if ~isempty(tokens)
                token = erase(string(tokens{1}), '"');
                if contains(token, ".") || contains(lower(token), "e")
                    parsed = str2double(token);
                    if isfinite(parsed)
                        value = string(sprintf('%.0f', parsed));
                    end
                else
                    value = token;
                end
                return
            end
            if isstruct(payload) && isfield(payload, fieldName)
                raw = payload.(fieldName);
                if isnumeric(raw) && isscalar(raw) && isfinite(raw)
                    value = string(sprintf('%.0f', double(raw)));
                elseif ischar(raw) || isstring(raw)
                    value = string(raw);
                end
            end
        end

        function value = readMetadataString_(this, fieldName, defaultValue)
            value = string(defaultValue);
            if isstruct(this.StreamMetadata) && isfield(this.StreamMetadata, fieldName)
                value = string(this.StreamMetadata.(fieldName));
            end
        end

        function value = readMetadataNumeric_(this, fieldName, defaultValue)
            value = defaultValue;
            if isstruct(this.StreamMetadata) && isfield(this.StreamMetadata, fieldName)
                raw = this.StreamMetadata.(fieldName);
                if isnumeric(raw) && isscalar(raw)
                    value = double(raw);
                elseif ischar(raw) || isstring(raw)
                    parsed = str2double(string(raw));
                    if ~isnan(parsed)
                        value = parsed;
                    end
                end
            end
        end

        function rawMessage = recvAllJson_(this, timeoutMs)
            rawMessage = "";
            if isempty(this.SubscriberHandle)
                return
            end
            if this.usingBridgeAdapter_()
                if isfield(this.BridgeAdapter, 'recv_all_json')
                    raw = this.BridgeAdapter.recv_all_json(this.SubscriberHandle, timeoutMs, this.MaxDrainMessages);
                else
                    raw = this.BridgeAdapter.recv_latest_json(this.SubscriberHandle, timeoutMs);
                end
            else
                raw = this.BridgeModule.recv_all_json(this.SubscriberHandle, int32(timeoutMs), int32(this.MaxDrainMessages));
            end
            try
                rawMessage = string(raw);
            catch
                rawMessage = string(char(raw));
            end
        end

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

            pyPath = string(cell(py.sys.path()));
            if ~any(pyPath == this.BridgeDir)
                py.sys.path().insert(int32(0), char(this.BridgeDir));
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

        function tf = usingBridgeAdapter_(this)
            tf = isstruct(this.BridgeAdapter) && ...
                isfield(this.BridgeAdapter, 'open_subscriber') && ...
                isfield(this.BridgeAdapter, 'close_socket') && ...
                (isfield(this.BridgeAdapter, 'recv_all_json') || isfield(this.BridgeAdapter, 'recv_latest_json'));
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

        function warnStartupUnavailable_(this, messageText)
            if this.StartupWarningIssued
                return
            end
            warning('BehaviorBoxEyeTrack:StartupUnavailable', ...
                'Eye tracking startup unavailable: %s', char(string(messageText)));
            this.StartupWarningIssued = true;
        end

        function warnRuntimeFailure_(this, messageText)
            if this.RuntimeWarningIssued
                return
            end
            warning('BehaviorBoxEyeTrack:RuntimeFailure', ...
                'Eye tracking runtime failure: %s', char(string(messageText)));
            this.RuntimeWarningIssued = true;
        end
    end

    methods (Static, Access = private)
        function payloads = payloadCellArray_(decoded)
            if isempty(decoded)
                payloads = {};
            elseif isstruct(decoded)
                payloads = cell(numel(decoded), 1);
                for idx = 1:numel(decoded)
                    payloads{idx} = decoded(idx);
                end
            elseif iscell(decoded)
                payloads = decoded(:);
            else
                payloads = {decoded};
            end
        end

        function names = readStringArrayField_(payload, fieldName)
            names = string.empty(0,1);
            if ~isstruct(payload) || ~isfield(payload, fieldName)
                return
            end
            raw = payload.(fieldName);
            if isempty(raw)
                return
            end
            if iscell(raw)
                names = string(raw(:));
            elseif isstring(raw)
                names = raw(:);
            elseif ischar(raw)
                names = string({raw});
            else
                names = string(raw(:));
            end
        end

        function value = defaultValueForRecordVariable_(name)
            name = string(name);
            stringFields = [ ...
                "capture_time_unix_ns"
                "publish_time_unix_ns"
                "sample_status"];
            logicalFields = "is_valid";
            if any(name == stringFields)
                value = "";
            elseif any(name == logicalFields)
                value = false;
            else
                value = NaN;
            end
        end

        function options = parseAlignmentOptions_(varargin)
            parser = inputParser;
            parser.addParameter('Mode', 'previous');
            parser.addParameter('TimeColumn', 't_us');
            parser.addParameter('IntervalDirection', 'previous');
            parser.addParameter('SessionEndUs', Inf);
            parser.parse(varargin{:});

            options = struct();
            options.Mode = lower(string(parser.Results.Mode));
            options.TimeColumn = string(parser.Results.TimeColumn);
            options.IntervalDirection = lower(string(parser.Results.IntervalDirection));
            options.SessionEndUs = double(parser.Results.SessionEndUs);
            if ~any(options.Mode == ["previous", "interval_summary"])
                error('BehaviorBoxEyeTrack:InvalidAlignmentMode', ...
                    'Alignment mode must be previous or interval_summary.');
            end
            if ~any(options.IntervalDirection == ["previous", "next"])
                error('BehaviorBoxEyeTrack:InvalidIntervalDirection', ...
                    'IntervalDirection must be previous or next.');
            end
        end

        function out = ensureEyeAlignmentColumns_(out)
            n = height(out);
            specs = {
                'eye_frame_id', NaN(n,1)
                'eye_t_us', NaN(n,1)
                'eye_dt_us', NaN(n,1)
                'eye_center_x', NaN(n,1)
                'eye_center_y', NaN(n,1)
                'eye_diameter_px', NaN(n,1)
                'eye_diameter_h_px', NaN(n,1)
                'eye_diameter_v_px', NaN(n,1)
                'eye_confidence_mean', NaN(n,1)
                'eye_valid_points', NaN(n,1)
                'eye_latency_ms', NaN(n,1)
                'eye_sample_count', zeros(n,1)
                'eye_is_valid', false(n,1)
                'eye_sample_status', strings(n,1)
                'eye_frame_id_first', NaN(n,1)
                'eye_frame_id_last', NaN(n,1)
                'eye_t_us_first', NaN(n,1)
                'eye_t_us_last', NaN(n,1)
                'eye_center_x_mean', NaN(n,1)
                'eye_center_y_mean', NaN(n,1)
                'eye_center_x_median', NaN(n,1)
                'eye_center_y_median', NaN(n,1)
                'eye_diameter_px_mean', NaN(n,1)
                'eye_confidence_mean_interval', NaN(n,1)
                'eye_valid_fraction', NaN(n,1)
            };
            for idx = 1:size(specs, 1)
                name = specs{idx, 1};
                if ~ismember(name, out.Properties.VariableNames)
                    out.(name) = specs{idx, 2};
                end
            end
        end

        function out = copyRepresentativeEyeSample_(out, rowIdx, sample, targetT)
            out.eye_frame_id(rowIdx) = sample.frame_id;
            out.eye_t_us(rowIdx) = sample.t_us;
            out.eye_dt_us(rowIdx) = targetT - sample.t_us;
            out.eye_center_x(rowIdx) = sample.center_x;
            out.eye_center_y(rowIdx) = sample.center_y;
            out.eye_diameter_px(rowIdx) = sample.diameter_px;
            out.eye_diameter_h_px(rowIdx) = sample.diameter_h_px;
            out.eye_diameter_v_px(rowIdx) = sample.diameter_v_px;
            out.eye_confidence_mean(rowIdx) = sample.confidence_mean;
            out.eye_valid_points(rowIdx) = sample.valid_points;
            out.eye_latency_ms(rowIdx) = sample.latency_ms;
            out.eye_is_valid(rowIdx) = sample.is_valid;
            out.eye_sample_status(rowIdx) = sample.sample_status;
        end

        function out = copyEyeIntervalSummary_(out, rowIdx, interval)
            if isempty(interval) || height(interval) == 0
                return
            end
            out.eye_frame_id_first(rowIdx) = interval.frame_id(1);
            out.eye_frame_id_last(rowIdx) = interval.frame_id(end);
            out.eye_t_us_first(rowIdx) = interval.t_us(1);
            out.eye_t_us_last(rowIdx) = interval.t_us(end);
            out.eye_center_x_mean(rowIdx) = mean(interval.center_x, 'omitnan');
            out.eye_center_y_mean(rowIdx) = mean(interval.center_y, 'omitnan');
            out.eye_center_x_median(rowIdx) = median(interval.center_x, 'omitnan');
            out.eye_center_y_median(rowIdx) = median(interval.center_y, 'omitnan');
            out.eye_diameter_px_mean(rowIdx) = mean(interval.diameter_px, 'omitnan');
            out.eye_confidence_mean_interval(rowIdx) = mean(interval.confidence_mean, 'omitnan');
            out.eye_valid_fraction(rowIdx) = mean(double(interval.is_valid), 'omitnan');
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
