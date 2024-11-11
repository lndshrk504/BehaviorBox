function [newData, DataStruct] = RescueDataFromAGraph(f)
arguments
    f = gcf
end
RescueData = struct();
FN = split(f.FileName, filesep);
if ispc
    Inp = FN{6};
    Str = FN{7};
    Sub = FN(8);
elseif ismac
    Inp = FN{8};
    Str = FN{9};
    Sub = FN(10);
end
DataStruct = BehaviorBoxData("Inp",Inp, "Str", Str, "Sub", Sub, "find", true);
newData = DataStruct.current_data_struct;
BigBin = 20;
SmallBin = 10;
%Take Data from All Level Performance, the SmallBin line
AllLP = f.Children.Children(1).Children(3);
SrcData = AllLP.Children;
LScore = cell(numel(SrcData)/2,1);
tNum = cell(numel(SrcData)/2,1);
Level = cell(numel(SrcData)/2,1);
for o = 2:2:numel(SrcData)
    Lev = SrcData(o).SeriesIndex;
    d = SrcData(o).YData;
    XVals = SrcData(o).XData;
    dScore = NaN(size(XVals));
    dScore(1) = 0.5;
    for t = 2:numel(d)
        switch 1
            case d(t)>d(t-1) %MovMean going up, they got this trial right
                dScore(t) = 1;
            case d(t)<d(t-1) %MovMean going down, they got this trial wrong
                dScore(t) = 0;
            case d(t)==d(t-1) %MovMean isn't changing so this trial is the same as the (t-Bin)th trial, which is being replaced by this trial in the current bin...
                dScore(t) = dScore(t-SmallBin);
        end
    end
    if SrcData(o).YData == movmean(dScore,[SmallBin-1 0], "Endpoints","shrink")
        LScore{Lev} = dScore(2:end)';
        tNum{Lev} = XVals(2:end)';
        Level{Lev} = Lev*ones(size(dScore(2:end)'));
    else
        fprintf("Didn't work for Level "+Lev+"\n")
    end
end
RescueData.Score = cell2mat(LScore);
RescueData.Level = cell2mat(Level);
RescueData.TrialNum = cell2mat(tNum);
[~, idx]=sort(RescueData.TrialNum);
RescueData=structfun(@(x) x(idx), RescueData, 'UniformOutput', false);
RF = fieldnames(RescueData);
nDF = fieldnames(newData);
for Fname = nDF(matches(nDF, RF))'
    thename = Fname{:};
    newData.(thename) = RescueData.(thename);
end
DataStruct.current_data_struct = newData; % Must load into the object to use the object's clean fcn
DataStruct.current_data_struct = DataStruct.CleanData();
newData = DataStruct.current_data_struct;
newData.Include = ones(size(newData.TrialNum));
DataStruct.current_data_struct = newData;
end