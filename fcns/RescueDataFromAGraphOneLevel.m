function newData = RescueDataFromAGraphOneLevel(f)
RescueData = struct();
FN = split(f.FileName, filesep);
Inp = FN{6};
Str = FN{7};
Sub = FN(8);
DataStruct = BehaviorBoxData("Inp",Inp, "Str", Str, "Sub", Sub, "find", true);
newData = DataStruct.current_data_struct;
BigBin = 20;
SmallBin = 10;
%Take Data from All Level Performance small Bin Line plot
AllLP = f.Children.Children(1);
SrcLine = AllLP.Children(3).Children(2);
LScore = SrcLine.YData;
tNum = numel(SrcLine.XData);
Level = AllLP.Children(3).Children(2).SeriesIndex;
for o = LScore
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
                dScore(t) = dScore(t-BigBin);
        end
    end
    if SrcData(o).YData == movmean(dScore,[BigBin-1 0], "Endpoints","shrink")
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
DataStruct.current_data_struct = newData;
newData = DataStruct.CleanData();
newData.Include = ones(size(newData.TrialNum));
end