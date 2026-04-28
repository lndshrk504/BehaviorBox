function [data,variables,done] = readFcn(filename,variables)
%Use this reading function to read all behavior files in parallel
if contains(filename, '2471951')
    1;
end
data = cell(1,8);
tree = split(filename, filesep);
data{1} = tree{end}; %filename
data{2} = str2double(tree{end}(1:6)); %Date of session
data{6} = char(tree{end-1}); %name of the subfolder, Mouse's name
try
    t = load(filename);
catch err
    data{5} = struct('ReadError', err.message);
    done = true;
    return
end
data{5} = collectReadExtras_(t);
if isfield(t, 'Position_Record')
    data{7} = t.Position_Record;
end
if isfield(t, 'Settings')
    data{8} = t.Settings;
end
if ~isfield(t, 'newData')
    [legacyNewData, legacyExtras] = legacyNewDataFromLoadedStruct_(t);
    if isempty(fieldnames(legacyNewData))
        done = true;
        return
    end
    t.newData = legacyNewData;
    data{5}.LegacyNewData = legacyExtras;
end

% if data{2} == 241025 % For debugging certain days
%     1;
% end
try
    t.newData = canonicalizeHistoricalNewDataFields_(t.newData, t);
    originalNewData = t.newData;
    [t.newData, data{5}] = moveSessionNewDataFieldsToExtras_(t.newData, data{5});
    names = fieldnames(t.newData)';
    if isfield(t, 'StimHist')
        data{4} = t.StimHist;
    elseif isfield(t.newData,'StimHist')
        data{4} = t.newData.StimHist;
    end
    %Make sure everything is a row vector in newData
    rowMask = structfun(@(x) ~istable(x) && isrow(x), t.newData);
    numelMask = structfun(@numel, t.newData) > 1;
    for n = names(rowMask & numelMask)
        t.newData.(n{:}) = t.newData.(n{:})';
    end
    %Make sure every vector is the same length in newData
    omits = ["wheel_record" "SetStr" "SetUpdate" "Settings" "Include" "StimHist" "RewardTime" "WhatDecision" "LevelGroups" "Text"];
    %names = names(~contains(names, omits));
    total = numel(t.newData.Score);
    for n = names(structfun(@numel, t.newData)>total)
        fieldName = n{:};
        fieldValue = t.newData.(fieldName);
        % Session-wide tables are additive metadata, not trial-aligned vectors.
        if any(fieldName==omits) || istable(fieldValue)
            continue
        end
        t.newData.(fieldName) = fieldValue(1:total);
    end
    if ~contains(filename, 'XXXXXX')
        total = numel(t.newData.TimeStamp);
        for n = names(structfun(@numel, t.newData)>total)
            fieldName = n{:};
            fieldValue = t.newData.(fieldName);
            if any(fieldName==omits) || isempty(fieldValue) || istable(fieldValue)
                continue
            end
            t.newData.(fieldName) = fieldValue(1:total);
        end
    elseif contains(filename, 'XXXXXX') % If a data was "rescued" by reconstructing it from a figure, put XXXXXX in its filename
        total = numel(t.newData.Score);
        for n = names(structfun(@numel, t.newData)<total)
            fieldName = n{:};
            fieldValue = t.newData.(fieldName);
            if any(fieldName==omits) || istable(fieldValue)
                continue
            end
            t.newData.(fieldName) = nan(size(t.newData.Score));
        end
        t.newData.SetIdx = ones(size(t.newData.Score));
    end
    if ~isfield(t.newData, 'wheel_record')
        t.newData.wheel_record = [];
    end
    if isfield(t.newData, 'Weight')
        if isnumeric(t.newData.Weight)
            %do nothing, it should be double
        elseif ischar(t.newData.Weight)
            t.newData.Weight = str2double(t.newData.Weight);
        end
    else
        t.newData.Weight = [];
    end
    data{5} = preserveChangedNewDataFields_(data{5}, originalNewData, t.newData);
    data{3} = t.newData; %Get newData
% Add code to check stimulus for Decoy correct answers?
catch err
    unwrapErr(err)
    1;
    %disp("stop")
    %disp("stop")
end
done = true;
end

function [newData, extras] = moveSessionNewDataFieldsToExtras_(newData, extras)
sessionFields = [
    "TtimestampRecord"
    "TimestampRecord"
    "EyeTrackingRecord"
    "EyeTrackingMeta"
    "EyeTrackRecord"
    "EyeTrackSegmentMeta"
    "WheelDisplayRecord"
    "FrameAlignedRecord"
    "EyeAlignedRecord"];

moved = struct();
for i = 1:numel(sessionFields)
    fieldName = char(sessionFields(i));
    if isfield(newData, fieldName)
        moved.(fieldName) = newData.(fieldName);
        newData = rmfield(newData, fieldName);
    end
end

if isempty(fieldnames(moved))
    return
end

if isfield(extras, 'NewDataSessionFields') && isstruct(extras.NewDataSessionFields)
    sessionExtras = extras.NewDataSessionFields;
else
    sessionExtras = struct();
end

movedNames = fieldnames(moved);
for i = 1:numel(movedNames)
    fieldName = movedNames{i};
    sessionExtras.(fieldName) = moved.(fieldName);
end
extras.NewDataSessionFields = sessionExtras;
end

function [newData, extras] = legacyNewDataFromLoadedStruct_(loadedStruct)
newData = struct();
extras = struct('Source', "", 'RowCount', 0, 'TrialCount', 0);

if isfield(loadedStruct, 'RepairedBehaviorData')
    legacyMatrix = loadedStruct.RepairedBehaviorData;
    extras.Source = "RepairedBehaviorData";
elseif isfield(loadedStruct, 'data')
    legacyMatrix = loadedStruct.data;
    extras.Source = "data";
else
    return
end

if ~isnumeric(legacyMatrix) || isempty(legacyMatrix)
    return
end

supportedRows = [5 6 7 9 13];
if ~ismember(size(legacyMatrix, 1), supportedRows) && ismember(size(legacyMatrix, 2), supportedRows)
    legacyMatrix = legacyMatrix';
end

nRows = size(legacyMatrix, 1);
nTrials = size(legacyMatrix, 2);
extras.RowCount = nRows;
extras.TrialCount = nTrials;

if nRows >= 5 && any(legacyMatrix(5,:) == -1)
    legacyMatrix(:, legacyMatrix(5,:) == -1) = [];
    nTrials = size(legacyMatrix, 2);
    extras.TrialCount = nTrials;
end
if nRows >= 4 && all(legacyMatrix(1,:) - legacyMatrix(4,:) < 1)
    legacyMatrix(4,:) = 0;
end

switch nRows
    case 5
        names = {'TimeStamp', 'Score', 'Level', 'ResponseTime', 'RewardPulses'};
    case 6
        names = {'TimeStamp', 'Score', 'Level', 'ResponseTime', 'RewardPulses', 'RewardTime'};
    case 7
        names = {'TimeStamp', 'Score', 'Level', 'ResponseTime', 'isLeftTrial', 'RewardPulses', 'RewardTime'};
    case 9
        names = {'TimeStamp', 'Score', 'Level', 'ResponseTime', 'isLeftTrial', 'CodedChoice', 'RewardPulses', 'InterTMal', 'DuringTMal'};
    case 13
        names = {'TimeStamp', 'Score', 'Level', 'isLeftTrial', 'CodedChoice', 'RewardPulses', 'InterTMal', 'DuringTMal', 'TrialStartTime', 'ResponseTime', 'DrinkTime', 'SetIdx', 'isTraining'};
    otherwise
        return
end

for i = 1:numel(names)
    newData.(names{i}) = double(legacyMatrix(i,:))';
end

newData = fillMissingBehaviorFields_(newData, loadedStruct);
end

function newData = fillMissingBehaviorFields_(newData, loadedStruct)
if ~isfield(newData, 'Score') || ~isfield(newData, 'Level')
    newData = struct();
    return
end

newData.Score = newData.Score(:);
newData.Level = newData.Level(:);
nTrials = numel(newData.Score);

if nTrials == 0 || numel(newData.Level) ~= nTrials
    newData = struct();
    return
end

if all(newData.Level < 1 & newData.Level >= 0)
    newData.Level = double(newData.Level * 10);
end
newData.Score(newData.Score == 0.8) = 1;
newData.Score(newData.Score == 0.5) = 0;
newData.Score(newData.Score == 0.2) = 2;

numericDefaults = {
    'TimeStamp', zeros(nTrials, 1)
    'isLeftTrial', zeros(nTrials, 1)
    'CodedChoice', zeros(nTrials, 1)
    'SetIdx', ones(nTrials, 1)
    'RewardPulses', zeros(nTrials, 1)
    'InterTMal', zeros(nTrials, 1)
    'DuringTMal', zeros(nTrials, 1)
    'TrialStartTime', zeros(nTrials, 1)
    'ResponseTime', zeros(nTrials, 1)
    'DrinkTime', zeros(nTrials, 1)
    'isTraining', true(nTrials, 1)
    'SideBias', zeros(nTrials, 1)
    'BetweenTrialTime', zeros(nTrials, 1)
    'RewardTime', zeros(nTrials, 1)
    'WhatDecision', zeros(nTrials, 1)
    'LevelGroups', ones(nTrials, 1)
    'Include', ones(nTrials, 1)
    };

for i = 1:size(numericDefaults, 1)
    fieldName = numericDefaults{i, 1};
    if ~isfield(newData, fieldName) || isempty(newData.(fieldName))
        newData.(fieldName) = numericDefaults{i, 2};
    else
        newData.(fieldName) = newData.(fieldName)(:);
    end
end

if ~isfield(newData, 'SetStr') || isempty(newData.SetStr)
    newData.SetStr = "legacy";
end
if ~isfield(newData, 'SetUpdate') || isempty(newData.SetUpdate)
    newData.SetUpdate = {1};
end
if isfield(loadedStruct, 'Settings') && isstruct(loadedStruct.Settings)
    newData.Settings = loadedStruct.Settings;
else
    newData.Settings = struct();
end
if ~isfield(newData, 'StimHist') || isempty(newData.StimHist)
    newData.StimHist = cell(nTrials, 2);
end
if ~isfield(newData, 'Weight')
    newData.Weight = [];
end
end

function extras = collectReadExtras_(loadedStruct)
extras = struct();
extraFields = setdiff(fieldnames(loadedStruct), {'Settings', 'newData', 'StimHist', 'Position_Record'});
for i = 1:numel(extraFields)
    fieldName = extraFields{i};
    extras.(fieldName) = loadedStruct.(fieldName);
end
end

function extras = preserveChangedNewDataFields_(extras, originalNewData, normalizedNewData)
rawChanged = struct();
rawNames = fieldnames(originalNewData);
sharedNames = intersect(rawNames, fieldnames(normalizedNewData), 'stable');
movedSessionNames = string.empty(0, 1);
if isfield(extras, 'NewDataSessionFields') && isstruct(extras.NewDataSessionFields)
    movedSessionNames = string(fieldnames(extras.NewDataSessionFields));
end

for i = 1:numel(sharedNames)
    fieldName = sharedNames{i};
    try
        sameValue = isequaln(originalNewData.(fieldName), normalizedNewData.(fieldName));
    catch
        sameValue = false;
    end
    if ~sameValue
        rawChanged.(fieldName) = originalNewData.(fieldName);
    end
end

removedNames = setdiff(rawNames, fieldnames(normalizedNewData), 'stable');
for i = 1:numel(removedNames)
    fieldName = removedNames{i};
    if any(movedSessionNames == string(fieldName))
        continue
    end
    rawChanged.(fieldName) = originalNewData.(fieldName);
end

if ~isempty(fieldnames(rawChanged))
    extras.OriginalNewDataFields = rawChanged;
end
end

function newData = canonicalizeHistoricalNewDataFields_(newData, loadedStruct)
if isfield(newData, 'BetweenTrialtime') && ~isfield(newData, 'BetweenTrialTime')
    newData.BetweenTrialTime = newData.BetweenTrialtime;
end
if isfield(newData, 'trialstarttime') && ~isfield(newData, 'TrialStartTime')
    newData.TrialStartTime = newData.trialstarttime;
end
if isfield(newData, 'sideBias') && ~isfield(newData, 'SideBias')
    newData.SideBias = newData.sideBias;
end
if isfield(newData, 'SetUpdateRec') && ~isfield(newData, 'SetUpdate')
    newData.SetUpdate = newData.SetUpdateRec;
end
if ~isfield(newData, 'wheel_record') && isfield(loadedStruct, 'wheel_record')
    newData.wheel_record = loadedStruct.wheel_record;
end
if ~isfield(newData, 'TrialNum')
    if isfield(newData, 'TimeStamp') && ~isempty(newData.TimeStamp)
        newData.TrialNum = (1:numel(newData.TimeStamp))';
    elseif isfield(newData, 'Score') && ~isempty(newData.Score)
        newData.TrialNum = (1:numel(newData.Score))';
    else
        newData.TrialNum = [];
    end
end
end
