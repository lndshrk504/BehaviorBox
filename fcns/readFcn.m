function [data,variables,done] = readFcn(filename,variables)
%Use this reading function to read all behavior files in parallel
if contains(filename, '2471951')
    1;
end
data = cell(1,8);
t = load(filename);
tree = split(filename, filesep);
data{1} = tree{end}; %filename
data{2} = str2double(tree{end}(1:6)); %Date of session
data{6} = char(tree{end-1}); %name of the subfolder, Mouse's name
data{5} = collectReadExtras_(t);
if isfield(t, 'Position_Record')
    data{7} = t.Position_Record;
end
if isfield(t, 'Settings')
    data{8} = t.Settings;
end
if ~isfield(t, 'newData')
    done = true;
    return
end

% if data{2} == 241025 % For debugging certain days
%     1;
% end
try
    t.newData = canonicalizeHistoricalNewDataFields_(t.newData, t);
    originalNewData = t.newData;
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
    if isfield(t.newData, 'TtimestampRecord') && ~isfield(t.newData, 'TimestampRecord')
        t.newData.TimestampRecord = t.newData.TtimestampRecord;
    end
    if ~isfield(t.newData, 'TimestampRecord')
        t.newData.TimestampRecord = [];
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
