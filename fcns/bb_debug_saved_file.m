function report = bb_debug_saved_file(matFile, options)
%BB_DEBUG_SAVED_FILE Summarize the integrity of a saved BehaviorBox file.
%
%   report = bb_debug_saved_file(matFile)
%   report = bb_debug_saved_file(matFile, Display=false)
%
% This helper is intended for read-only debugging of saved wheel-session
% files. It summarizes committed trials, additive wheel/timestamp outputs,
% and common integrity markers such as whether cleanup is session-level and
% whether trial segments contain trial_end events.

arguments
    matFile
    options.Display logical = true
end

matFile = string(matFile);
if ~isscalar(matFile) || strlength(matFile) == 0
    error("bb_debug_saved_file:InvalidInput", "matFile must be a non-empty text scalar.");
end
if ~isfile(matFile)
    error("bb_debug_saved_file:FileNotFound", "Saved file not found: %s", matFile);
end

loaded = load(char(matFile));

report = struct();
report.File = matFile;
report.TopLevelFields = string(fieldnames(loaded))';
report.HasNewData = isfield(loaded, 'newData') && isstruct(loaded.newData);
report.NewDataFields = string.empty(1, 0);
report.CommittedTrialCount = 0;
report.HasWheelDisplayRecord = false;
report.WheelDisplayColumns = string.empty(1, 0);
report.WheelDisplayRowCount = 0;
report.WheelDisplayStartedTrials = [];
report.WheelDisplayStartedTrialCount = 0;
report.WheelDisplayMaxTrial = NaN;
report.WheelDisplayHasStatusColumns = false;
report.WheelDisplayStatusCounts = table();
report.HasFrameAlignedRecord = false;
report.FrameAlignedRowCount = 0;
report.HasTimestampRecord = false;
report.TimestampRecordSource = "";
report.TimestampSegmentCount = 0;
report.TimestampTrialSegmentCount = 0;
report.TimestampMaxTrial = NaN;
report.TimestampCleanupIsSessionLevel = true;
report.TimestampHasStatusFields = false;
report.TimestampParsedHasStatusColumns = false;
report.TimestampMissingTrialEndTrials = [];
report.TimestampSegmentSummary = table();

newData = struct();
if report.HasNewData
    newData = loaded.newData;
    report.NewDataFields = string(fieldnames(newData))';
    report.CommittedTrialCount = localCommittedTrialCount(newData);

    if isfield(newData, 'WheelDisplayRecord') && istable(newData.WheelDisplayRecord)
        wheelTbl = newData.WheelDisplayRecord;
        report.HasWheelDisplayRecord = true;
        report.WheelDisplayColumns = string(wheelTbl.Properties.VariableNames);
        report.WheelDisplayRowCount = height(wheelTbl);

        validRows = localWheelTrialMask(wheelTbl);
        startedTrials = unique(double(wheelTbl.trial(validRows)), 'stable');
        report.WheelDisplayStartedTrials = startedTrials(:)';
        report.WheelDisplayStartedTrialCount = numel(startedTrials);
        report.WheelDisplayMaxTrial = localMaxOrNaN(startedTrials);

        report.WheelDisplayHasStatusColumns = all(ismember(["trialCommitted", "trialStatus"], report.WheelDisplayColumns));
        if report.WheelDisplayHasStatusColumns
            report.WheelDisplayStatusCounts = localStatusCountTable(string(wheelTbl.trialStatus));
        end
    end

    if isfield(newData, 'FrameAlignedRecord') && istable(newData.FrameAlignedRecord)
        report.HasFrameAlignedRecord = true;
        report.FrameAlignedRowCount = height(newData.FrameAlignedRecord);
    end
end

timestampRecord = {};
if isfield(newData, 'TimestampRecord')
    timestampRecord = newData.TimestampRecord;
    report.TimestampRecordSource = "newData";
elseif isfield(loaded, 'TimestampRecord')
    timestampRecord = loaded.TimestampRecord;
    report.TimestampRecordSource = "top_level";
end

segments = localNormalizeSegments(timestampRecord);
if ~isempty(segments)
    report.HasTimestampRecord = true;
    report.TimestampSegmentCount = numel(segments);
    report.TimestampSegmentSummary = localTimestampSummary(segments);

    summaryTbl = report.TimestampSegmentSummary;
    trialRows = summaryTbl(summaryTbl.kind == "trial", :);
    cleanupRows = summaryTbl(summaryTbl.kind == "cleanup", :);

    report.TimestampTrialSegmentCount = height(trialRows);
    report.TimestampMaxTrial = localMaxOrNaN(trialRows.trial);
    report.TimestampCleanupIsSessionLevel = isempty(cleanupRows) || all(isnan(cleanupRows.trial) | cleanupRows.trial <= 0);
    report.TimestampHasStatusFields = all(summaryTbl.hasStatusField);
    parsedRows = summaryTbl.parsedRowCount > 0;
    report.TimestampParsedHasStatusColumns = ~any(parsedRows) || all(summaryTbl.parsedHasStatusColumns(parsedRows));
    report.TimestampMissingTrialEndTrials = trialRows.trial(~trialRows.hasTrialEnd & ~isnan(trialRows.trial))';
end

if options.Display
    localPrintReport(report);
end

end

function count = localCommittedTrialCount(newData)
count = 0;
if isfield(newData, 'Score') && ~isempty(newData.Score)
    count = numel(newData.Score);
elseif isfield(newData, 'TimeStamp') && ~isempty(newData.TimeStamp)
    count = numel(newData.TimeStamp);
end
end

function tf = localWheelTrialMask(wheelTbl)
tf = false(height(wheelTbl), 1);
if ~ismember('trial', wheelTbl.Properties.VariableNames)
    return
end
tf = ~isnan(wheelTbl.trial) & wheelTbl.trial > 0;
end

function value = localMaxOrNaN(values)
value = NaN;
if isempty(values)
    return
end
values = double(values);
values = values(~isnan(values));
if isempty(values)
    return
end
value = max(values);
end

function segments = localNormalizeSegments(timestampRecord)
segments = {};
if isempty(timestampRecord)
    return
end

if iscell(timestampRecord)
    segments = timestampRecord(~cellfun(@isempty, timestampRecord));
elseif isstruct(timestampRecord)
    segments = num2cell(timestampRecord(:));
end
end

function summaryTbl = localTimestampSummary(segments)
nSeg = numel(segments);
kind = strings(nSeg, 1);
trial = NaN(nSeg, 1);
scanImageFile = NaN(nSeg, 1);
rawRowCount = zeros(nSeg, 1);
parsedRowCount = zeros(nSeg, 1);
hasTrialEnd = false(nSeg, 1);
hasStatusField = false(nSeg, 1);
parsedHasStatusColumns = false(nSeg, 1);

for iSeg = 1:nSeg
    seg = segments{iSeg};
    if ~isstruct(seg)
        continue
    end

    if isfield(seg, 'kind')
        kind(iSeg) = string(seg.kind);
    end
    if isfield(seg, 'trial') && ~isempty(seg.trial)
        segTrial = double(seg.trial);
        if ~isempty(segTrial)
            trial(iSeg) = segTrial(1);
        end
    end
    if isfield(seg, 'scanImageFile') && ~isempty(seg.scanImageFile)
        segScanFile = double(seg.scanImageFile);
        if ~isempty(segScanFile)
            scanImageFile(iSeg) = segScanFile(1);
        end
    end
    if isfield(seg, 'raw') && ~isempty(seg.raw)
        rawRowCount(iSeg) = numel(seg.raw);
    end
    if isfield(seg, 'parsed') && istable(seg.parsed)
        parsedTbl = seg.parsed;
        parsedRowCount(iSeg) = height(parsedTbl);
        if ismember('event', parsedTbl.Properties.VariableNames)
            hasTrialEnd(iSeg) = any(string(parsedTbl.event) == "trial_end");
        end
        parsedHasStatusColumns(iSeg) = all(ismember(["trialCommitted", "trialStatus"], string(parsedTbl.Properties.VariableNames)));
    end
    hasStatusField(iSeg) = isfield(seg, 'trialCommitted') && isfield(seg, 'trialStatus');
end

summaryTbl = table( ...
    (1:nSeg)', ...
    kind, ...
    trial, ...
    scanImageFile, ...
    rawRowCount, ...
    parsedRowCount, ...
    hasTrialEnd, ...
    hasStatusField, ...
    parsedHasStatusColumns, ...
    'VariableNames', {'segmentIndex', 'kind', 'trial', 'scanImageFile', 'rawRowCount', 'parsedRowCount', 'hasTrialEnd', 'hasStatusField', 'parsedHasStatusColumns'});
end

function countsTbl = localStatusCountTable(statusValues)
countsTbl = table();
if isempty(statusValues)
    return
end

statusValues = string(statusValues);
statusValues(statusValues == "") = "<empty>";
[uniqueStatus, ~, groupIdx] = unique(statusValues, 'stable');
counts = accumarray(groupIdx, 1);
countsTbl = table(uniqueStatus, counts, 'VariableNames', {'status', 'count'});
end

function localPrintReport(report)
fprintf("Saved-file debug summary\n");
fprintf("  File: %s\n", report.File);

if ~report.HasNewData
    fprintf("  newData: absent\n");
else
    fprintf("  Committed trials: %d\n", report.CommittedTrialCount);
end

if report.HasWheelDisplayRecord
    fprintf("  WheelDisplayRecord: rows=%d startedTrials=%s maxTrial=%s\n", ...
        report.WheelDisplayRowCount, ...
        localFormatNumericList(report.WheelDisplayStartedTrials), ...
        localFormatScalar(report.WheelDisplayMaxTrial));
    fprintf("    Status columns present: %s\n", string(report.WheelDisplayHasStatusColumns));
    if ~isempty(report.WheelDisplayStatusCounts)
        fprintf("    Status counts: %s\n", localFormatStatusCounts(report.WheelDisplayStatusCounts));
    end
else
    fprintf("  WheelDisplayRecord: absent\n");
end

if report.HasFrameAlignedRecord
    fprintf("  FrameAlignedRecord: rows=%d\n", report.FrameAlignedRowCount);
else
    fprintf("  FrameAlignedRecord: absent\n");
end

if report.HasTimestampRecord
    fprintf("  TimestampRecord: source=%s segments=%d trialSegments=%d maxTrial=%s\n", ...
        report.TimestampRecordSource, ...
        report.TimestampSegmentCount, ...
        report.TimestampTrialSegmentCount, ...
        localFormatScalar(report.TimestampMaxTrial));
    fprintf("    Cleanup session-level: %s\n", string(report.TimestampCleanupIsSessionLevel));
    fprintf("    Segment status fields present: %s\n", string(report.TimestampHasStatusFields));
    fprintf("    Parsed status columns present: %s\n", string(report.TimestampParsedHasStatusColumns));
    fprintf("    Missing trial_end trials: %s\n", localFormatNumericList(report.TimestampMissingTrialEndTrials));
else
    fprintf("  TimestampRecord: absent\n");
end
end

function txt = localFormatNumericList(values)
if isempty(values)
    txt = "[]";
    return
end

values = double(values(:)');
if numel(values) > 20
    headVals = values(1:10);
    tailVals = values(end-4:end);
    headTxt = strjoin(string(arrayfun(@localFormatScalar, headVals, 'UniformOutput', false)), ", ");
    tailTxt = strjoin(string(arrayfun(@localFormatScalar, tailVals, 'UniformOutput', false)), ", ");
    txt = "[" + headTxt + ", ..., " + tailTxt + "]";
    return
end
parts = arrayfun(@localFormatScalar, values, 'UniformOutput', false);
txt = "[" + strjoin(string(parts), ", ") + "]";
end

function txt = localFormatScalar(value)
if isempty(value) || (isnumeric(value) && isnan(value))
    txt = "NaN";
    return
end
txt = string(value);
end

function txt = localFormatStatusCounts(countsTbl)
if isempty(countsTbl) || height(countsTbl) == 0
    txt = "[]";
    return
end

parts = strings(height(countsTbl), 1);
for iRow = 1:height(countsTbl)
    parts(iRow) = countsTbl.status(iRow) + "=" + string(countsTbl.count(iRow));
end
txt = "[" + strjoin(cellstr(parts), ", ") + "]";
end
