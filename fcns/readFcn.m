function [data,variables,done] = readFcn(filename,variables)
%Use this reading function to read all behavior files in parallel
data = cell(1,7);
t = load(filename);
tree = split(filename, filesep);
data{1} = tree{end}; %filename
data{2} = str2double(tree{end}(1:6)); %Date of session
data{6} = char(tree{end-1}); %name of the subfolder, Mouse's name
if isfield(t, 'Position_Record')
    data{7} = t.Position_Record;
    return
end
% if data{2} == 241025 % For debugging certain days
%     1;
% end
try
    names = fieldnames(t.newData)';
    if any(contains(names, 'wheel_record'))
        data{5} = t.newData.wheel_record;
    end
    b = fieldnames(t);
    if any(contains(b, "StimHist"))
        data{4} = t.StimHist;
    elseif isfield(t.newData,'StimHist')
        data{4} = t.newData.StimHist;
    end
    %Make sure everything is a row vector in newData
    for n = names(structfun(@isrow, t.newData) & structfun(@numel, t.newData)>1)
        t.newData.(n{:}) = t.newData.(n{:})';
    end
    %Make sure every vector is the same length in newData
    omits = ["wheel_record" "SetStr" "SetUpdate" "Settings" "Include" "StimHist" "RewardTime" "WhatDecision" "LevelGroups" "Text"];
    %names = names(~contains(names, omits));
    total = numel(t.newData.Score);
    for n = names(structfun(@numel, t.newData)>total)
        if any(n{:}==omits)
            continue
        end
        t.newData.(n{:}) = t.newData.(n{:})(1:total);
    end
    if ~contains(filename, 'XXXXXX')
        total = numel(t.newData.TimeStamp);
        for n = names(structfun(@numel, t.newData)>total)
            if any(n{:}==omits) || isempty(t.newData.(n{:}))
                continue
            end
            t.newData.(n{:}) = t.newData.(n{:})(1:total);
        end
    elseif contains(filename, 'XXXXXX') % If a data was "rescued" by reconstructing it from a figure, put XXXXXX in its filename
        total = numel(t.newData.Score);
        for n = names(structfun(@numel, t.newData)<total)
            if any(n{:}==omits)
                continue
            end
            t.newData.(n{:}) = nan(size(t.newData.Score));
        end
        t.newData.SetIdx = ones(size(t.newData.Score));
    end
    data{3} = t.newData; %Get newData
% Add code to check stimulus for Decoy correct answers?
catch err
    %disp("stop")
    %disp("stop")
end
done = true;
end