classdef BehaviorBoxEyeTrack < handle
    % BehaviorBox eye-tracking helper for deferred receiver-backed ingest.
    % WBS Apr - 22 - 2026

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
        ReceiverUrl string = ""
        ReceiverTimeoutSeconds double = 5
        BridgeDir string = ""
        PythonExecutable string = ""
        ModelName string = "DLC_PupilTracking_YangLab_resnet_50_iteration-0_shuffle-1"
        PointNames string = string.empty(0,1)
        PlaceholderLiveSubscriber logical = false
        IsConnected logical = false
        IsReady logical = false
        SessionActive logical = false
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
        StartTimerOnStart logical = false
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
        AlignmentTimeColumn string = "t_receive_us"
        SessionId string = ""
        SessionKind string = ""
        SessionLabel string = ""
        SessionOutputDir string = ""
        ActiveSegmentId string = ""
        ActiveSegmentKind string = ""
        ActiveSegmentTrial double = NaN
        ActiveSegmentMode string = ""
        SessionManifest struct = struct('session_id', "", 'segments', struct.empty(0,1))
        ClientAdapter struct = struct()
    end

    properties (Access = private)
        ImportedSegmentIds string = string.empty(0,1)
        ImportedSegmentTables cell = {}
        ImportedSegmentMeta cell = {}
        StartupWarningIssued logical = false
        RuntimeWarningIssued logical = false
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
                options.StartTimerOnStart logical = false
                options.BridgeAdapter struct = struct()
                options.ReceiverUrl string = ""
                options.ReceiverTimeoutSeconds double = 5
                options.ClientAdapter struct = struct()
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
            this.ClientAdapter = options.ClientAdapter;
            if isempty(fieldnames(this.ClientAdapter)) && ~isempty(fieldnames(this.BridgeAdapter))
                if isfield(this.BridgeAdapter, 'health') || isfield(this.BridgeAdapter, 'manifest')
                    this.ClientAdapter = this.BridgeAdapter;
                end
            end

            if strlength(strtrim(options.Address)) > 0
                [host, port, address] = BehaviorBoxEyeTrack.parseAddress(options.Address);
                this.Address = address;
                this.SourceHost = host;
                this.SourcePort = port;
            else
                address = BehaviorBoxEyeTrack.defaultSourceAddress_();
                [host, port, address] = BehaviorBoxEyeTrack.parseAddress(address);
                this.Address = address;
                this.SourceHost = string(options.SourceHost);
                if strlength(strtrim(this.SourceHost)) == 0
                    this.SourceHost = host;
                end
                this.SourcePort = double(options.SourcePort);
                if ~isfinite(this.SourcePort)
                    this.SourcePort = port;
                end
            end

            if strlength(strtrim(options.SourceMode)) > 0
                this.SourceMode = string(options.SourceMode);
            else
                this.SourceMode = BehaviorBoxEyeTrack.inferSourceMode_(this.SourceHost);
            end

            receiverUrl = string(options.ReceiverUrl);
            if strlength(strtrim(receiverUrl)) == 0
                receiverUrl = BehaviorBoxEyeTrack.defaultReceiverUrl_();
            end
            this.ReceiverUrl = receiverUrl;
            this.ReceiverTimeoutSeconds = double(options.ReceiverTimeoutSeconds);
        end

        function tf = connect(this)
            tf = false;
            try
                payload = this.requestJson_("GET", "/health", struct());
                this.applyHealthPayload_(payload);
                this.IsConnected = true;
                this.LastErrorMessage = "";
                tf = true;
            catch err
                this.IsConnected = false;
                try
                    this.LastErrorMessage = string(getReport(err, 'extended', 'hyperlinks', 'off'));
                catch
                    this.LastErrorMessage = string(err.message);
                end
                this.warnStartupUnavailable_(this.LastErrorMessage);
            end
        end

        function tf = start(this)
            tf = this.connect();
            if ~tf
                return
            end
            try
                this.ensureSessionConfigured_();
                payload = struct( ...
                    'session_id', char(this.SessionId), ...
                    'session_kind', char(this.SessionKind), ...
                    'session_label', char(this.SessionLabel), ...
                    'output_dir', char(this.SessionOutputDir), ...
                    'session_start_unix_ns', this.sessionStartUnixNs_(), ...
                    'source_address', char(this.Address), ...
                    'model_name', char(this.ModelName), ...
                    'point_names', {cellstr(this.PointNames)});
                response = this.requestJson_("POST", "/session/start", payload);
                this.SessionActive = true;
                this.SubscriberStartWallClock = datetime("now");
                if isstruct(response) && isfield(response, 'point_names')
                    this.PointNames = BehaviorBoxEyeTrack.readStringArrayField_(response, 'point_names');
                    this.PointNames = this.PointNames(:);
                    this.ParsedLog = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
                end
                if isstruct(response) && isfield(response, 'model_name')
                    this.ModelName = bbCoerceStringArray(response.model_name);
                    this.ModelName = this.ModelName(1);
                end
                this.LastErrorMessage = "";
            catch err
                tf = false;
                try
                    this.LastErrorMessage = string(getReport(err, 'extended', 'hyperlinks', 'off'));
                catch
                    this.LastErrorMessage = string(err.message);
                end
                this.warnStartupUnavailable_(this.LastErrorMessage);
            end
        end

        function stop(this)
            if ~this.SessionActive || strlength(this.SessionId) == 0
                this.SessionActive = false;
                this.SubscriberStopWallClock = datetime("now");
                return
            end
            try
                this.requestJson_("POST", "/session/stop", struct('session_id', char(this.SessionId)));
            catch err
                this.LastErrorMessage = string(err.message);
                this.warnRuntimeFailure_(err.message);
            end
            this.SessionActive = false;
            this.ActiveSegmentId = "";
            this.ActiveSegmentKind = "";
            this.ActiveSegmentTrial = NaN;
            this.ActiveSegmentMode = "";
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

        function configureSession(this, options)
            arguments
                this
                options.SessionId string = ""
                options.SessionKind string = "session"
                options.SessionLabel string = ""
                options.OutputDir string = ""
            end
            if strlength(strtrim(options.SessionId)) > 0
                this.SessionId = string(options.SessionId);
            end
            this.SessionKind = string(options.SessionKind);
            if strlength(strtrim(options.SessionLabel)) > 0
                this.SessionLabel = string(options.SessionLabel);
            end
            if strlength(strtrim(options.OutputDir)) > 0
                this.SessionOutputDir = string(options.OutputDir);
            end
        end

        function markTrial(this, trialNumber)
            this.CurrentTrial = double(trialNumber);
            tUs = this.currentTrainMicros_();
            if ~isfinite(tUs)
                tUs = 0;
            end
            this.TrialBoundaryUs(end+1,1) = double(tUs);
            this.TrialBoundaryValues(end+1,1) = double(trialNumber);
        end

        function tf = beginSegment(this, options)
            arguments
                this
                options.SegmentId string = ""
                options.SegmentKind string = "segment"
                options.TrialNumber double = NaN
                options.Mode string = ""
                options.ScanImageFile double = NaN
            end
            tf = false;
            if ~this.SessionActive || strlength(this.SessionId) == 0
                return
            end
            try
                segmentId = string(options.SegmentId);
                if strlength(strtrim(segmentId)) == 0
                    segmentId = this.defaultSegmentId_(string(options.SegmentKind), double(options.TrialNumber));
                end
                payload = struct( ...
                    'session_id', char(this.SessionId), ...
                    'segment_id', char(segmentId), ...
                    'segment_kind', char(string(options.SegmentKind)), ...
                    'trial_number', double(options.TrialNumber), ...
                    'mode', char(string(options.Mode)), ...
                    'scan_image_file', double(options.ScanImageFile));
                this.requestJson_("POST", "/segment/open", payload);
                this.ActiveSegmentId = segmentId;
                this.ActiveSegmentKind = string(options.SegmentKind);
                this.ActiveSegmentTrial = double(options.TrialNumber);
                this.ActiveSegmentMode = string(options.Mode);
                tf = true;
            catch err
                this.LastErrorMessage = string(err.message);
                this.warnRuntimeFailure_(err.message);
            end
        end

        function meta = closeSegment(this, options)
            arguments
                this
                options.Partial logical = false
            end
            meta = struct();
            if ~this.SessionActive || strlength(this.SessionId) == 0
                return
            end
            try
                payload = struct( ...
                    'session_id', char(this.SessionId), ...
                    'partial', logical(options.Partial));
                meta = this.requestJson_("POST", "/segment/close", payload);
                this.ActiveSegmentId = "";
                this.ActiveSegmentKind = "";
                this.ActiveSegmentTrial = NaN;
                this.ActiveSegmentMode = "";
            catch err
                this.LastErrorMessage = string(err.message);
                this.warnRuntimeFailure_(err.message);
            end
        end

        function [segmentTables, segmentMeta] = importClosedSegments(this)
            segmentTables = {};
            segmentMeta = {};
            if strlength(this.SessionId) == 0
                return
            end
            try
                manifestPayload = this.requestJson_("GET", "/manifest", struct('session_id', char(this.SessionId)));
                entries = this.manifestEntries_(manifestPayload);
                if isempty(entries)
                    return
                end
                this.SessionManifest = manifestPayload;
                for idx = 1:numel(entries)
                    entry = entries(idx);
                    segmentId = this.entryString_(entry, "segment_id");
                    if strlength(segmentId) == 0 || any(this.ImportedSegmentIds == segmentId)
                        continue
                    end
                    if ~this.entryLogical_(entry, "closed", true)
                        continue
                    end
                    tableRows = this.readSegmentCsv_(entry);
                    [tableRows, meta] = this.normalizeImportedSegment_(tableRows, entry);
                    this.appendImportedSegment_(segmentId, tableRows, meta);
                    segmentTables{end+1,1} = tableRows; %#ok<AGROW>
                    segmentMeta{end+1,1} = meta; %#ok<AGROW>
                end
                this.updateStatusFromImported_();
            catch err
                this.LastErrorMessage = string(err.message);
                this.warnRuntimeFailure_(err.message);
            end
        end

        function [segmentTables, segmentMeta] = finalizeSession(this)
            segmentTables = {};
            segmentMeta = {};
            if ~this.SessionActive || strlength(this.SessionId) == 0
                return
            end
            try
                this.requestJson_("POST", "/session/finalize", struct('session_id', char(this.SessionId), 'partial', false));
            catch err
                this.LastErrorMessage = string(err.message);
                this.warnRuntimeFailure_(err.message);
            end
            [segmentTables, segmentMeta] = this.importClosedSegments();
        end

        function count = pollAvailable(~, varargin) %#ok<INUSD>
            count = 0;
        end

        function count = finalDrain(this)
            [segmentTables, ~] = this.finalizeSession();
            count = 0;
            for idx = 1:numel(segmentTables)
                if istable(segmentTables{idx})
                    count = count + height(segmentTables{idx});
                end
            end
        end

        function rows = processReading(this, newReading, trialNumber)
            arguments
                this
                newReading
                trialNumber double = NaN
            end
            rows = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
            try
                decoded = jsondecode(char(string(newReading)));
                payloads = BehaviorBoxEyeTrack.payloadCellArray_(decoded);
                rowStructs = struct.empty(0,1);
                for idx = 1:numel(payloads)
                    payload = payloads{idx};
                    if ~isstruct(payload)
                        continue
                    end
                    messageType = this.readStringField_(payload, 'message_type', "sample");
                    this.updatePointNamesFromPayload_(payload);
                    this.updateMetadataFromPayload_(payload, messageType);
                    if messageType == "metadata"
                        this.MetadataMessagesReceived = this.MetadataMessagesReceived + 1;
                        continue
                    end
                    rowStruct = this.rowStructFromPayload_(payload, double(trialNumber));
                    rowStructs(end+1,1) = rowStruct; %#ok<AGROW>
                end
                if isempty(rowStructs)
                    return
                end
                rows = struct2table(rowStructs);
                rows = rows(:, cellstr(BehaviorBoxEyeTrack.recordVariableNames(this.PointNames)));
                testMeta = struct( ...
                    'segment_id', "manual_segment_" + string(numel(this.ImportedSegmentIds) + 1), ...
                    'segment_kind', "manual", ...
                    'trial_number', double(trialNumber), ...
                    'mode', "", ...
                    'scan_image_file', NaN, ...
                    'csv_path', "", ...
                    'metadata_path', "", ...
                    'row_count', height(rows), ...
                    'receive_start_unix_ns', NaN, ...
                    'receive_end_unix_ns', NaN, ...
                    't_receive_start_us', this.columnFirstNumeric_(rows, "t_receive_us"), ...
                    't_receive_end_us', this.columnLastNumeric_(rows, "t_receive_us"), ...
                    'closed', true, ...
                    'partial', false, ...
                    'point_names', {cellstr(this.PointNames)});
                this.appendImportedSegmentForTest(rows, testMeta);
            catch err
                this.LastErrorMessage = string(err.message);
                this.warnRuntimeFailure_(err.message);
            end
        end

        function appendImportedSegmentForTest(this, segmentTable, segmentMeta)
            if nargin < 3 || isempty(segmentMeta)
                segmentMeta = struct();
            end
            if ~isstruct(segmentMeta)
                error('BehaviorBoxEyeTrack:InvalidSegmentMeta', ...
                    'appendImportedSegmentForTest expects segmentMeta to be a struct.');
            end
            segmentId = this.entryString_(segmentMeta, "segment_id");
            if strlength(segmentId) == 0
                segmentId = "manual_segment_" + string(numel(this.ImportedSegmentIds) + 1);
                segmentMeta.segment_id = segmentId;
            end
            [segmentTable, segmentMeta] = this.normalizeImportedSegment_(segmentTable, segmentMeta);
            this.appendImportedSegment_(segmentId, segmentTable, segmentMeta);
            this.updateStatusFromImported_();
        end

        function record = getRecord(this)
            record = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
            if isempty(this.ImportedSegmentTables)
                this.ParsedLog = record;
                return
            end
            record = vertcat(this.ImportedSegmentTables{:});
            if ismember("t_us", string(record.Properties.VariableNames))
                record.AlignmentOrder = transpose(1:height(record));
                if ismember("frame_id", string(record.Properties.VariableNames))
                    record = sortrows(record, {'t_us', 'frame_id', 'AlignmentOrder'});
                else
                    record = sortrows(record, {'t_us', 'AlignmentOrder'});
                end
                record.AlignmentOrder = [];
            end
            this.ParsedLog = record;
            if height(record) > 0
                try
                    this.LatestSample = table2struct(record(end, :), 'ToScalar', true);
                catch
                end
            end
        end

        function meta = getMeta(this)
            record = this.getRecord();
            meta = BehaviorBoxEyeTrack.emptyMeta();
            meta.Address = this.Address;
            meta.SourceMode = this.SourceMode;
            meta.SourceHost = this.SourceHost;
            meta.SourcePort = this.SourcePort;
            meta.ReceiverUrl = this.ReceiverUrl;
            meta.BridgeDir = this.BridgeDir;
            meta.BridgeAvailable = false;
            meta.ModelName = this.ModelName;
            meta.PointNames = this.PointNames;
            meta.PointCount = numel(this.PointNames);
            meta.PlaceholderLiveSubscriber = false;
            meta.IsConnected = this.IsConnected;
            meta.IsReady = this.IsReady;
            meta.PythonExecutable = this.PythonExecutable;
            meta.SessionClockSource = "behavior_receive_time_unix_ns - session_start_unix_ns";
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
            meta.TimerRunning = false;
            meta.LatestSampleStatus = "";
            if isfield(this.LatestSample, 'sample_status')
                meta.LatestSampleStatus = string(this.LatestSample.sample_status);
            end
            meta.RecordVariableNames = string(record.Properties.VariableNames);
            meta.StreamMetadata = this.StreamMetadata;
            meta.CsvPath = this.firstImportedPath_("csv_path");
            meta.MetadataPath = this.firstImportedPath_("metadata_path");
            meta.SchemaVersion = this.readMetadataNumeric_("schema_version", NaN);
            meta.TrialBoundaryUs = this.TrialBoundaryUs;
            meta.TrialBoundaryValues = this.TrialBoundaryValues;
            meta.SessionId = this.SessionId;
            meta.SessionKind = this.SessionKind;
            meta.SessionLabel = this.SessionLabel;
            meta.SessionOutputDir = this.SessionOutputDir;
            meta.AlignmentTimeColumn = this.AlignmentTimeColumn;
            meta.SegmentCount = numel(this.ImportedSegmentMeta);
            meta.ImportedSegmentIds = this.ImportedSegmentIds;
            meta.ImportedChunkFiles = this.importedChunkFiles_();
        end

        function segmentTables = getSegmentTables(this)
            segmentTables = this.ImportedSegmentTables;
        end

        function segmentMeta = getSegmentMeta(this)
            segmentMeta = this.ImportedSegmentMeta;
        end

        function Reset(this)
            this.Log = string.empty(0,1);
            this.RawLog = string.empty(0,1);
            this.ParsedLog = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
            this.LatestSample = struct();
            this.CurrentTrial = NaN;
            this.IsConnected = false;
            this.IsReady = false;
            this.SessionActive = false;
            this.LastReceiveWallClock = NaT;
            this.LastSampleReceiveWallClock = NaT;
            this.SubscriberStartWallClock = NaT;
            this.SubscriberStopWallClock = NaT;
            this.ReadyWallClock = NaT;
            this.MessagesReceived = 0;
            this.SamplesReceived = 0;
            this.MetadataMessagesReceived = 0;
            this.MissingFrameCount = 0;
            this.FrameIdGapCount = 0;
            this.StaleEventCount = 0;
            this.LastFrameId = NaN;
            this.ReadySampleFrameId = NaN;
            this.LastErrorMessage = "";
            this.StreamMetadata = struct();
            this.TrialBoundaryUs = double.empty(0,1);
            this.TrialBoundaryValues = double.empty(0,1);
            this.SessionId = "";
            this.SessionKind = "";
            this.SessionLabel = "";
            this.SessionOutputDir = "";
            this.ActiveSegmentId = "";
            this.ActiveSegmentKind = "";
            this.ActiveSegmentTrial = NaN;
            this.ActiveSegmentMode = "";
            this.SessionManifest = struct('session_id', "", 'segments', struct.empty(0,1));
            this.ImportedSegmentIds = string.empty(0,1);
            this.ImportedSegmentTables = {};
            this.ImportedSegmentMeta = {};
            this.StartupWarningIssued = false;
            this.RuntimeWarningIssued = false;
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
                'ReceiverUrl', "", ...
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
                'TrialBoundaryValues', double.empty(0,1), ...
                'SessionId', "", ...
                'SessionKind', "", ...
                'SessionLabel', "", ...
                'SessionOutputDir', "", ...
                'AlignmentTimeColumn', "t_receive_us", ...
                'SegmentCount', 0, ...
                'ImportedSegmentIds', string.empty(0,1), ...
                'ImportedChunkFiles', string.empty(0,1));
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
            if ~ismember(options.TimeColumn, string(out.Properties.VariableNames))
                return
            end
            eyeTimeColumn = options.EyeTimeColumn;
            if ~ismember(eyeTimeColumn, string(eyeRecord.Properties.VariableNames))
                if ismember("t_us", string(eyeRecord.Properties.VariableNames))
                    eyeTimeColumn = "t_us";
                else
                    return
                end
            end

            eyeRecord = sortrows(eyeRecord, char(eyeTimeColumn));
            eyeT = double(eyeRecord.(char(eyeTimeColumn)));
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
                    out = BehaviorBoxEyeTrack.copyRepresentativeEyeSample_(out, rowIdx, eyeRecord(previousIdx, :), tNow, eyeTimeColumn);
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
                    out = BehaviorBoxEyeTrack.copyEyeIntervalSummary_(out, rowIdx, eyeRecord(intervalIdx, :), eyeTimeColumn);
                end
            end
        end

        function [isFound, config] = discoverSource()
            address = BehaviorBoxEyeTrack.defaultSourceAddress_();
            receiverUrl = BehaviorBoxEyeTrack.defaultReceiverUrl_();
            [host, port, address] = BehaviorBoxEyeTrack.parseAddress(address);
            config = struct( ...
                'Address', address, ...
                'ReceiverUrl', receiverUrl, ...
                'SourceMode', BehaviorBoxEyeTrack.inferSourceMode_(host), ...
                'SourceHost', host, ...
                'SourcePort', port, ...
                'BridgeDir', "", ...
                'ModelName', "DLC_PupilTracking_YangLab_resnet_50_iteration-0_shuffle-1", ...
                'PointNames', BehaviorBoxEyeTrack.defaultPointNames());
            isFound = BehaviorBoxEyeTrack.probeReceiverUrl_(receiverUrl);
        end

        function obj = tryCreateFromEnvironment()
            obj = [];
            [isFound, config] = BehaviorBoxEyeTrack.discoverSource();
            if ~isFound
                return
            end
            obj = BehaviorBoxEyeTrack( ...
                Address=config.Address, ...
                ReceiverUrl=config.ReceiverUrl, ...
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
        function ensureSessionConfigured_(this)
            if strlength(strtrim(this.SessionId)) == 0
                this.SessionId = this.defaultSessionId_();
            end
            if strlength(strtrim(this.SessionKind)) == 0
                this.SessionKind = "session";
            end
            if strlength(strtrim(this.SessionLabel)) == 0
                this.SessionLabel = this.SessionId;
            end
            if strlength(strtrim(this.SessionOutputDir)) == 0
                this.SessionOutputDir = fullfile(tempdir, char(this.SessionId));
            end
        end

        function payload = requestJson_(this, method, route, body)
            if nargin < 4
                body = struct();
            end
            if this.usingClientAdapter_()
                payload = this.requestViaAdapter_(method, route, body);
                return
            end

            import matlab.net.*
            import matlab.net.http.*
            uri = URI(char(this.ReceiverUrl + route));
            if strcmpi(method, "GET")
                fields = fieldnames(body);
                if ~isempty(fields)
                    queryParams = matlab.net.QueryParameter.empty;
                    for idx = 1:numel(fields)
                        value = body.(fields{idx});
                        if isstring(value) || ischar(value)
                            queryValue = string(value);
                        elseif isnumeric(value) || islogical(value)
                            queryValue = string(value);
                        else
                            queryValue = string(jsonencode(value));
                        end
                        queryParams(end+1) = matlab.net.QueryParameter(fields{idx}, queryValue); %#ok<AGROW>
                    end
                    uri.Query = queryParams;
                end
                request = RequestMessage('GET');
            else
                headers = HeaderField('Content-Type', 'application/json');
                request = RequestMessage(char(upper(string(method))), headers, jsonencode(body));
            end
            options = HTTPOptions('ConnectTimeout', this.ReceiverTimeoutSeconds);
            response = request.send(uri, options);
            if response.StatusCode ~= StatusCode.OK
                error('BehaviorBoxEyeTrack:ReceiverHttpError', ...
                    'Receiver request failed with status %s', char(string(response.StatusLine)));
            end
            payload = response.Body.Data;
            if ischar(payload) || isstring(payload)
                payload = jsondecode(char(string(payload)));
            end
        end

        function payload = requestViaAdapter_(this, method, route, body)
            payload = struct();
            method = upper(string(method));
            route = string(route);
            fnName = "";
            switch method + " " + route
                case "GET /health"
                    fnName = "health";
                case "GET /manifest"
                    fnName = "manifest";
                case "POST /session/start"
                    fnName = "session_start";
                case "POST /session/finalize"
                    fnName = "session_finalize";
                case "POST /session/stop"
                    fnName = "session_stop";
                case "POST /segment/open"
                    fnName = "segment_open";
                case "POST /segment/close"
                    fnName = "segment_close";
            end
            if strlength(fnName) == 0 || ~isfield(this.ClientAdapter, char(fnName))
                error('BehaviorBoxEyeTrack:ClientAdapterMissingMethod', ...
                    'ClientAdapter does not implement %s %s.', char(method), char(route));
            end
            payload = feval(this.ClientAdapter.(char(fnName)), body);
        end

        function tf = usingClientAdapter_(this)
            tf = isstruct(this.ClientAdapter) && ~isempty(fieldnames(this.ClientAdapter));
        end

        function applyHealthPayload_(this, payload)
            if ~isstruct(payload)
                return
            end
            if isfield(payload, 'model_name')
                this.ModelName = bbCoerceStringArray(payload.model_name);
                this.ModelName = this.ModelName(1);
            end
            if isfield(payload, 'point_names')
                this.PointNames = BehaviorBoxEyeTrack.readStringArrayField_(payload, 'point_names');
                this.PointNames = this.PointNames(:);
                this.ParsedLog = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
            end
            if isfield(payload, 'messages_received')
                this.MessagesReceived = double(payload.messages_received);
            end
            if isfield(payload, 'samples_received')
                this.SamplesReceived = double(payload.samples_received);
            end
            if isfield(payload, 'metadata_messages_received')
                this.MetadataMessagesReceived = double(payload.metadata_messages_received);
            end
            if isfield(payload, 'frame_gap_count')
                this.FrameIdGapCount = double(payload.frame_gap_count);
            end
            if isfield(payload, 'missing_frame_count')
                this.MissingFrameCount = double(payload.missing_frame_count);
            end
            if isfield(payload, 'last_frame_id')
                this.LastFrameId = double(payload.last_frame_id);
            end
            if isfield(payload, 'last_error_message')
                this.LastErrorMessage = bbCoerceStringArray(payload.last_error_message);
                this.LastErrorMessage = this.LastErrorMessage(1);
            end
            if isfield(payload, 'stream_metadata') && isstruct(payload.stream_metadata)
                this.StreamMetadata = payload.stream_metadata;
            end
            this.IsReady = this.SamplesReceived > 0 || ~isempty(this.ImportedSegmentTables);
        end

        function [tableRows, meta] = normalizeImportedSegment_(this, tableRows, metaIn)
            if nargin < 3 || isempty(metaIn)
                metaIn = struct();
            end
            if isfield(metaIn, 'point_names')
                pointNames = BehaviorBoxEyeTrack.readStringArrayField_(metaIn, 'point_names');
                pointNames = pointNames(:);
                pointNames = pointNames(strlength(pointNames) > 0);
                if ~isempty(pointNames)
                    this.PointNames = pointNames;
                end
            end
            tableRows = this.normalizeRecordTable_(tableRows);
            meta = struct();
            meta.segment_id = this.entryString_(metaIn, "segment_id");
            meta.segment_kind = this.entryString_(metaIn, "segment_kind");
            meta.trial_number = this.entryNumeric_(metaIn, "trial_number", NaN);
            meta.mode = this.entryString_(metaIn, "mode");
            meta.scan_image_file = this.entryNumeric_(metaIn, "scan_image_file", NaN);
            meta.csv_path = this.entryString_(metaIn, "csv_path");
            meta.metadata_path = this.entryString_(metaIn, "metadata_path");
            meta.row_count = height(tableRows);
            meta.receive_start_unix_ns = this.entryNumeric_(metaIn, "receive_start_unix_ns", NaN);
            meta.receive_end_unix_ns = this.entryNumeric_(metaIn, "receive_end_unix_ns", NaN);
            meta.t_receive_start_us = this.entryNumeric_(metaIn, "t_receive_start_us", this.columnFirstNumeric_(tableRows, "t_receive_us"));
            meta.t_receive_end_us = this.entryNumeric_(metaIn, "t_receive_end_us", this.columnLastNumeric_(tableRows, "t_receive_us"));
            meta.closed = this.entryLogical_(metaIn, "closed", true);
            meta.partial = this.entryLogical_(metaIn, "partial", false);
            meta.point_names = cellstr(this.PointNames);
        end

        function tableRows = normalizeRecordTable_(this, tableRows)
            if isempty(tableRows) || ~istable(tableRows)
                tableRows = BehaviorBoxEyeTrack.emptyRecordTable(this.PointNames);
                return
            end
            variableNames = BehaviorBoxEyeTrack.recordVariableNames(this.PointNames);
            stringFields = ["capture_time_unix_ns", "publish_time_unix_ns", "sample_status"];
            logicalFields = "is_valid";
            for idx = 1:numel(variableNames)
                varName = variableNames(idx);
                if ~ismember(varName, string(tableRows.Properties.VariableNames))
                    tableRows.(char(varName)) = BehaviorBoxEyeTrack.defaultColumnValue_(varName, height(tableRows));
                end
            end
            tableRows = tableRows(:, cellstr(variableNames));
            for idx = 1:numel(variableNames)
                varName = variableNames(idx);
                if any(varName == stringFields)
                    tableRows.(char(varName)) = string(tableRows.(char(varName)));
                elseif any(varName == logicalFields)
                    tableRows.(char(varName)) = logical(tableRows.(char(varName)));
                else
                    tableRows.(char(varName)) = double(tableRows.(char(varName)));
                end
            end
        end

        function tableRows = readSegmentCsv_(this, entry)
            csvPath = this.entryString_(entry, "csv_path");
            if strlength(csvPath) == 0 || exist(csvPath, 'file') ~= 2
                error('BehaviorBoxEyeTrack:MissingSegmentCsv', ...
                    'Could not find eye-track chunk CSV: %s', char(csvPath));
            end
            opts = detectImportOptions(char(csvPath), 'TextType', 'string');
            stringFields = ["capture_time_unix_ns", "publish_time_unix_ns", "sample_status"];
            for idx = 1:numel(stringFields)
                varName = stringFields(idx);
                if ismember(varName, string(opts.VariableNames))
                    opts = setvartype(opts, char(varName), 'string');
                end
            end
            if ismember("is_valid", string(opts.VariableNames))
                opts = setvartype(opts, 'is_valid', 'logical');
            end
            tableRows = readtable(char(csvPath), opts);
        end

        function appendImportedSegment_(this, segmentId, tableRows, meta)
            if any(this.ImportedSegmentIds == segmentId)
                return
            end
            this.ImportedSegmentIds(end+1,1) = string(segmentId);
            this.ImportedSegmentTables{end+1,1} = tableRows;
            this.ImportedSegmentMeta{end+1,1} = meta;
        end

        function updateStatusFromImported_(this)
            record = this.getRecord();
            this.SamplesReceived = height(record);
            this.MessagesReceived = this.SamplesReceived + this.MetadataMessagesReceived;
            this.IsReady = height(record) > 0;
            if this.IsReady
                this.ReadyWallClock = datetime("now");
            end
            if height(record) > 0
                this.LastReceiveWallClock = datetime("now");
                this.LastSampleReceiveWallClock = this.LastReceiveWallClock;
                if ismember("frame_id", string(record.Properties.VariableNames))
                    frameIds = double(record.frame_id);
                    frameIds = frameIds(isfinite(frameIds));
                    if ~isempty(frameIds)
                        this.LastFrameId = frameIds(end);
                        this.ReadySampleFrameId = frameIds(1);
                    end
                end
                this.LatestSample = table2struct(record(end, :), 'ToScalar', true);
            end
        end

        function rowStruct = rowStructFromPayload_(this, payload, trialOverride)
            this.updateMetadataFromPayload_(payload, this.readStringField_(payload, 'message_type', "sample"));
            names = BehaviorBoxEyeTrack.recordVariableNames(this.PointNames);
            rowStruct = struct();
            for idx = 1:numel(names)
                rowStruct.(char(names(idx))) = BehaviorBoxEyeTrack.defaultValueForRecordVariable_(names(idx));
            end
            tReceiveUs = this.currentTrainMicros_();
            if ~isfinite(tReceiveUs)
                tReceiveUs = 0;
            end
            if isnan(trialOverride)
                trialValue = this.CurrentTrial;
                if ~isfinite(trialValue)
                    trialValue = 0;
                end
            else
                trialValue = trialOverride;
            end
            rowStruct.trial = double(trialValue);
            rowStruct.t_us = double(tReceiveUs);
            rowStruct.t_receive_us = double(tReceiveUs);
            rowStruct.frame_id = this.readNumericField_(payload, 'frame_id');
            rowStruct.capture_time_unix_s = this.readNumericField_(payload, 'capture_time_unix_s');
            rowStruct.capture_time_unix_ns = this.readIntegerTextField_(payload, 'capture_time_unix_ns');
            rowStruct.publish_time_unix_s = this.readNumericField_(payload, 'publish_time_unix_s');
            rowStruct.publish_time_unix_ns = this.readIntegerTextField_(payload, 'publish_time_unix_ns');
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
            rowStruct.sample_status = this.readStringField_(payload, 'sample_status', "ok");
            rowStruct.is_valid = this.sampleIsValid_(payload, rowStruct.sample_status);
            [points, ~] = this.pointsFromPayload_(payload);
            pointColumns = BehaviorBoxEyeTrack.pointColumnNames(this.PointNames);
            for iPoint = 1:numel(this.PointNames)
                colBase = (iPoint - 1) * 3;
                rowStruct.(char(pointColumns(colBase + 1))) = double(points(iPoint, 1));
                rowStruct.(char(pointColumns(colBase + 2))) = double(points(iPoint, 2));
                rowStruct.(char(pointColumns(colBase + 3))) = double(points(iPoint, 3));
            end
        end

        function updatePointNamesFromPayload_(this, payload)
            if ~isstruct(payload) || ~isfield(payload, 'point_names')
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
                    "model_preset"
                    "model_type"
                    "point_names"
                    "point_count"
                    "camera_serial"
                    "camera_model"
                    "pose_coordinate_frame"];
                fields = intersect(fields, cellstr(staticFields), 'stable');
            end
            for idx = 1:numel(fields)
                fieldName = fields{idx};
                if strcmp(fieldName, 'points')
                    continue
                end
                this.StreamMetadata.(fieldName) = payload.(fieldName);
            end
            if isfield(this.StreamMetadata, 'model_preset')
                this.ModelName = string(this.StreamMetadata.model_preset);
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

        function value = readIntegerTextField_(~, payload, fieldName)
            value = "";
            if ~isstruct(payload) || ~isfield(payload, fieldName)
                return
            end
            raw = payload.(fieldName);
            if isempty(raw)
                return
            end
            if isstring(raw) || ischar(raw)
                value = string(raw);
            elseif isnumeric(raw) && isscalar(raw) && isfinite(raw)
                value = string(sprintf('%.0f', double(raw)));
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

        function text = firstImportedPath_(this, fieldName)
            text = "";
            for idx = 1:numel(this.ImportedSegmentMeta)
                meta = this.ImportedSegmentMeta{idx};
                if isstruct(meta) && isfield(meta, fieldName)
                    raw = meta.(fieldName);
                    if iscell(raw)
                        text = bbCoerceStringArray(raw(:));
                    else
                        text = bbCoerceStringArray(raw);
                    end
                    if strlength(text) > 0
                        text = text(1);
                        return
                    end
                end
            end
        end

        function files = importedChunkFiles_(this)
            files = string.empty(0,1);
            for idx = 1:numel(this.ImportedSegmentMeta)
                meta = this.ImportedSegmentMeta{idx};
                if isstruct(meta) && isfield(meta, 'csv_path')
                    raw = meta.csv_path;
                    if iscell(raw)
                        values = bbCoerceStringArray(raw(:));
                        files(end+1,1) = values(1); %#ok<AGROW>
                    else
                        files(end+1,1) = bbCoerceStringArray(raw); %#ok<AGROW>
                    end
                end
            end
        end

        function value = entryString_(~, entry, fieldName)
            value = "";
            if isstruct(entry) && isfield(entry, fieldName)
                raw = entry.(fieldName);
                if iscell(raw)
                    value = bbCoerceStringArray(raw(:));
                else
                    value = bbCoerceStringArray(raw);
                end
                if ~isempty(value)
                    value = value(1);
                end
            end
        end

        function value = entryNumeric_(~, entry, fieldName, defaultValue)
            value = defaultValue;
            if isstruct(entry) && isfield(entry, fieldName)
                raw = entry.(fieldName);
                try
                    numeric = double(raw);
                    if ~isempty(numeric)
                        value = numeric(1);
                    end
                catch
                    value = defaultValue;
                end
            end
        end

        function tf = entryLogical_(~, entry, fieldName, defaultValue)
            tf = logical(defaultValue);
            if isstruct(entry) && isfield(entry, fieldName)
                try
                    tf = logical(entry.(fieldName));
                    if numel(tf) > 1
                        tf = tf(1);
                    end
                catch
                    tf = logical(defaultValue);
                end
            end
        end

        function entries = manifestEntries_(~, payload)
            entries = struct.empty(0,1);
            if isempty(payload) || ~isstruct(payload) || ~isfield(payload, 'segments')
                return
            end
            raw = payload.segments;
            if isempty(raw)
                return
            end
            if isstruct(raw)
                entries = raw(:);
            elseif iscell(raw)
                tmp = struct.empty(0,1);
                for idx = 1:numel(raw)
                    if isstruct(raw{idx})
                        tmp(end+1,1) = raw{idx}; %#ok<AGROW>
                    end
                end
                entries = tmp;
            end
        end

        function sessionId = defaultSessionId_(this)
            stamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
            if ~isempty(this.TrainStartWallClock) && ~isnat(this.TrainStartWallClock)
                stamp = string(datetime(this.TrainStartWallClock, "Format", "yyyyMMdd_HHmmss"));
            end
            sessionId = "eye_" + stamp;
        end

        function segmentId = defaultSegmentId_(~, segmentKind, trialNumber)
            if isfinite(trialNumber)
                segmentId = lower(string(segmentKind)) + "_trial_" + string(trialNumber);
            else
                segmentId = lower(string(segmentKind)) + "_" + string(datetime("now", "Format", "HHmmssSSS"));
            end
        end

        function tNs = sessionStartUnixNs_(this)
            if ~isempty(this.TrainStartWallClock) && ~isnat(this.TrainStartWallClock)
                tNs = int64(round(posixtime(this.TrainStartWallClock) * 1e9));
            else
                tNs = int64(round(posixtime(datetime("now")) * 1e9));
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
                tUs = NaN;
            end
        end

        function value = columnFirstNumeric_(~, tbl, varName)
            value = NaN;
            if isempty(tbl) || ~istable(tbl) || ~ismember(varName, string(tbl.Properties.VariableNames)) || height(tbl) == 0
                return
            end
            try
                values = double(tbl.(char(varName)));
                if ~isempty(values)
                    value = values(1);
                end
            catch
                value = NaN;
            end
        end

        function value = columnLastNumeric_(~, tbl, varName)
            value = NaN;
            if isempty(tbl) || ~istable(tbl) || ~ismember(varName, string(tbl.Properties.VariableNames)) || height(tbl) == 0
                return
            end
            try
                values = double(tbl.(char(varName)));
                if ~isempty(values)
                    value = values(end);
                end
            catch
                value = NaN;
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
            names = bbCoerceStringArray(raw);
            names = names(:);
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

        function value = defaultColumnValue_(name, nRows)
            name = string(name);
            if any(name == ["capture_time_unix_ns", "publish_time_unix_ns", "sample_status"])
                value = strings(nRows, 1);
            elseif name == "is_valid"
                value = false(nRows, 1);
            else
                value = NaN(nRows, 1);
            end
        end

        function options = parseAlignmentOptions_(varargin)
            parser = inputParser;
            parser.addParameter('Mode', 'previous');
            parser.addParameter('TimeColumn', 't_us');
            parser.addParameter('EyeTimeColumn', 't_receive_us');
            parser.addParameter('IntervalDirection', 'previous');
            parser.addParameter('SessionEndUs', Inf);
            parser.parse(varargin{:});

            options = struct();
            options.Mode = lower(string(parser.Results.Mode));
            options.TimeColumn = string(parser.Results.TimeColumn);
            options.EyeTimeColumn = string(parser.Results.EyeTimeColumn);
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

        function out = copyRepresentativeEyeSample_(out, rowIdx, sample, targetT, eyeTimeColumn)
            out.eye_frame_id(rowIdx) = sample.frame_id;
            out.eye_t_us(rowIdx) = sample.(char(eyeTimeColumn));
            out.eye_dt_us(rowIdx) = targetT - sample.(char(eyeTimeColumn));
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

        function out = copyEyeIntervalSummary_(out, rowIdx, interval, eyeTimeColumn)
            if isempty(interval) || height(interval) == 0
                return
            end
            out.eye_frame_id_first(rowIdx) = interval.frame_id(1);
            out.eye_frame_id_last(rowIdx) = interval.frame_id(end);
            out.eye_t_us_first(rowIdx) = interval.(char(eyeTimeColumn))(1);
            out.eye_t_us_last(rowIdx) = interval.(char(eyeTimeColumn))(end);
            out.eye_center_x_mean(rowIdx) = mean(interval.center_x, 'omitnan');
            out.eye_center_y_mean(rowIdx) = mean(interval.center_y, 'omitnan');
            out.eye_center_x_median(rowIdx) = median(interval.center_x, 'omitnan');
            out.eye_center_y_median(rowIdx) = median(interval.center_y, 'omitnan');
            out.eye_diameter_px_mean(rowIdx) = mean(interval.diameter_px, 'omitnan');
            out.eye_confidence_mean_interval(rowIdx) = mean(interval.confidence_mean, 'omitnan');
            out.eye_valid_fraction(rowIdx) = mean(double(interval.is_valid), 'omitnan');
        end

        function sourceMode = inferSourceMode_(host)
            host = lower(strtrim(string(host)));
            if any(host == ["localhost", "127.0.0.1"])
                sourceMode = "localhost";
            else
                sourceMode = "remote";
            end
        end

        function tf = probeReceiverUrl_(receiverUrl)
            tf = false;
            try
                payload = webread(char(receiverUrl + "/health"), weboptions('Timeout', 0.5));
                if isstruct(payload) && isfield(payload, 'ok')
                    tf = logical(payload.ok);
                else
                    tf = true;
                end
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

        function receiverUrl = defaultReceiverUrl_()
            receiverUrl = BehaviorBoxEyeTrack.getOptionalEnv_("BB_EYETRACK_RECEIVER_URL", "http://127.0.0.1:8765");
        end

        function address = defaultSourceAddress_()
            address = BehaviorBoxEyeTrack.getOptionalEnv_("BB_EYETRACK_ZMQ_ADDRESS", "tcp://127.0.0.1:5555");
        end
    end
end
