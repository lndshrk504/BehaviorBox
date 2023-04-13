function PlotOldData
dbstop if error
evalin('base', 'clc')
if nargin == 0 %Supply empty variables
    Input = {'Wheel'};
    Investigator = 'Will'; %Put the relevant mice in this folder
    WhichStrain = {'16p'}; %Must be chars in cells % 8/15/22 On my mac at home Matlab and my whole computer crashed when I did all the mice (6500 files). I think from not deleting all of the intermediate variables...
    WhichMice = {'all'}; %Must be chars in cells
end
bigT1 = clock;
[allData] = GetFiles(Input, Investigator, WhichStrain, WhichMice);
[TimeCell] = PlotEachSession(allData);
clf(1)
bigT = etime(clock, bigT1);
BigT = mean(TimeCell(TimeCell~=0));
disp(['Total time: ' num2str(bigT) ', Average subject time: ' num2str(BigT) '.'])
end
function [allData] = GetFiles(Input, Investigator, WhichStrain, WhichMice)
    %Get all of the files in the Investigator / Input folder, subjects do not matter
    current = mfilename('fullpath'); %Get the training data filepath
    [thispath,~,~] = fileparts(current);
    Inv = dir(thispath);
    whichInv = contains({Inv.name}, Investigator,IgnoreCase=1);
    Inv = Inv(whichInv);
    invPath = [Inv.folder filesep Inv.name filesep '**/*.mat'];
    files = dir(invPath);
    skipnames = {'settings', 'statistics', 'cage(#)'};
    files(contains( {files.name}, skipnames, IgnoreCase=true)) = [];
    files = files(contains({files.folder}, Input));
    if ~contains(WhichMice, 'all') && ~isempty(WhichMice)
        files = files(contains({files.folder}', WhichMice));
    end
    zerosList = [];
    loadedfiles = cell(size(files));
    count = 1;
    allData = cell(numel(files),6);
    for f = files'
        a = matfile([f.folder filesep f.name]);
        b = whos(a);
        tree = split(f.folder, filesep);
        allData{count, 1} = tree{end};
        allData{count, 2} = str2double(f.name(1:6));
        try
            allData{count, 3} = a.newData;
        end
        if any(contains({b.name}, "StimHist"))
            allData{count, 4} = a.StimHist;
        end
        if any(contains(fieldnames(allData{count, 3}), 'wheel_record'))
            allData{count, 5} = allData{count, 3}.wheel_record;
        end
        allData{count, end} = a.Properties.Source;
        count = count+1;
    end
end

function [TimeCell] = PlotEachSession(Session)
sc = 0;
fig = figure("Visible","off", "MenuBar","none");
Axes = CreateGraphs(fig);
TimeCell = zeros(size(Session,1),1);
    for s = Session'
        T1 = clock;
        clearGraphs(Axes)
        try
            sc = sc+1;
%             if sc == 23
%                 disp('Stop!')
%                 disp('Stop!')
%             end
            [Data, Names] = cleanData([s{3}]);
            plotTimerHists(Axes, Data)
            plotTrialHistory(Axes.TrialHistory, Data)
            plotBinnedPerformance(Axes.BinnedPerf, Data)
            plotSideBias(Axes.SideBias, Data)
            plotLevelPerf(Axes.LevelCount, Data)
            if ~isempty(s{4})
                %Plot the stimulus histories
                PlotStimHistory(s{4}, s{5})
            end
            name = string(s{2}) + ' - ' + string(s{1});
            t = split(name, '_');
            fig.Children.Title.String = join(t, ' - ');
            %saveFigure(fig, s{2}.folder, name)
        catch err
           unwrapErr(err) 
        end
        TimeCell(sc) = etime(clock, T1);
    end
end
function s = CreateGraphs(P)
%Create the TiledLayout in the Panel for all of the graphs...
    r = 3; c = 4;
    TL = tiledlayout(P, r, c, ...
        'Padding','tight', ...
        'TileSpacing','tight');
% Create Binned Perf
    BP = nexttile(TL, [1 4]);
    BP.Tag = 'Axes_BinnedPerf';
    title(BP, 'Binned Performance')
    BP.Toolbar.Visible = 'off';
    BP.TickLabelInterpreter = 'none';
    BP.YLim = [0 1];
    BP.TickLength = [0 0];
    BP.YTick = [0 0.5 0.75 1];
    BP.YTickLabelRotation = 90;
    BP.YTickLabel = {''; '50%'; '75%'; ''};
    BP.YGrid = 'on';
    BP.XTick = [];
    BP.NextPlot = 'add';
    BP.Box = 'on';
    BP.BoxStyle = 'full';
    BP.PickableParts = 'none';
% Create TH
    TH = nexttile(TL, [1 2]);
    TH.Tag = 'Axes_TrialHistory';
    title(TH, 'Trial History')
    TH.Toolbar.Visible = 'off';
    TH.YLim = [0 1];
    TH.TickLength = [0 0];
    TH.YTick = [0.2 0.5 0.8];
    TH.YTickLabelRotation = 0;
    TH.YTickLabel = {'T'; 'W'; 'C'};
    TH.XTick = [];
    TH.NextPlot = 'add';
    TH.Box = 'on';
    TH.BoxStyle = 'full';
    TH.HitTest = 'off';
    TH.PickableParts = 'none';
% Create LP
    LP = nexttile(TL, [1 2]);
    LP.Tag = 'Axes_LevelCount';
    title(LP, 'Level Performance')
    LP.Toolbar.Visible = 'off';
    LP.YLim = [0 1];
    LP.XTick = [];
    LP.YTick = [0 0.1 0.5 0.75 1];
    LP.YTickLabelRotation = 90;
    LP.YTickLabel = {''; '#'; '50%'; '75%'; ''};
    LP.YGrid = 'on';
    LP.TickDir = 'none';
    LP.NextPlot = 'add';
    LP.Box = 'on';
    LP.BoxStyle = 'full';
    LP.PickableParts = 'none';
% Create SB
    SB = nexttile(TL, [1 1]);
    SB.Tag = 'Axes_SideBias';
    title(SB, 'Side Bias History')
    SB.Toolbar.Visible = 'off';
    SB.YLim = [0 1];
    SB.TickLength = [0 0];
    SB.XTick = [];
    SB.YTick = [];
    SB.NextPlot = 'add';
    SB.Box = 'on';
    SB.BoxStyle = 'full';
    SB.PickableParts = 'none';
% Create axes6
    ST = nexttile(TL, [1 1]);
    ST.Tag = 'Axes_TimeToStart';
    title(ST, 'Time to Start')
    ST.Toolbar.Visible = 'off';
    ST.TickLength = [0 0];
    ST.XTick = [];
    ST.YTick = [];
    ST.NextPlot = 'add';
    ST.Box = 'on';
    ST.BoxStyle = 'full';
    ST.PickableParts = 'none';
% Create axes7
    RT = nexttile(TL, [1 1]);
    RT.Tag = 'Axes_ResponseTime';
    title(RT, 'Response Time')
    RT.Toolbar.Visible = 'off';
    RT.TickLength = [0 0];
    RT.XTick = [];
    RT.YTick = [];
    RT.NextPlot = 'add';
    RT.Box = 'on';
    RT.BoxStyle = 'full';
    RT.PickableParts = 'none';
% Create axes8
    DT = nexttile(TL, [1 1]);
    DT.Tag = 'Axes_DrinkTime';
    title(DT, 'Drink Dwell Time')
    DT.Toolbar.Visible = 'off';
    DT.TickLength = [0 0];
    DT.XTick = [];
    DT.YTick = [];
    DT.NextPlot = 'add';
    DT.Box = 'on';
    DT.BoxStyle = 'full';
    DT.PickableParts = 'none';            
%Make Structure
    s = struct();
    for c = TL.Children'
        s.(erase(c.Tag, 'Axes_')) = c;
    end
end
function clearGraphs(Axes)
    structfun(@cla, Axes)
end
function [NewData, Names] = cleanData(Data)
try
    Names = fieldnames(Data);
    sID = structfun(@isstruct, Data);
    NewData = rmfield(Data, Names(sID)); %Remove settings field
    Names = fieldnames(NewData); %make sure every field is a COLUMN not a row
    S = Names(structfun(@isrow, NewData))';
    for s = S
        NewData.(s{:}) = NewData.(s{:})';
    end
    NewData.Level = round(NewData.Level);
    %Create bins
    BB = 20;
    SB = 10;
    try
        [~, NewData.LevelGroups] = findgroups(round(NewData.Level(NewData.Score ~= 2)'));
    catch
        NewData.LevelGroups = findgroups(round(NewData.Level'));
    end
    Names = ['TrialNum' ; 'SmallBin' ; 'BigBin' ; fieldnames(NewData)];
    NewData.TrialNum = zeros(size(NewData.Level));
    NewData.SmallBin = zeros(size(NewData.Level));
    NewData.BigBin = zeros(size(NewData.Level));
    for Lev = NewData.LevelGroups
        rows = NewData.Level == Lev & NewData.Score ~= 2;
        m = sum(rows);
        if m==0
            continue
        end
        [~, ~, NewData.SmallBin(rows)] = histcounts((1:m)', [1:SB:m inf]); %Small Bin
        [~, ~, NewData.BigBin(rows)] = histcounts((1:m)', [1:BB:m inf]); %Large Bin
    end
    rows = NewData.Score ~= 2;
    NewData.TrialNum(rows) = (1:sum(rows))';
    NewData = orderfields(NewData, Names);
catch err
    unwrapErr(err)
end
end

function plotTimerHists(A, Data)
%Nothing is calculated, raw data is plotted
    f = fieldnames(A);
    f = flip(f(contains(f, 'Time')));
    if isrow(Data.TrialStartTime)
        D = [Data.TrialStartTime', Data.ResponseTime', Data.DrinkTime'];
    else
        D = [Data.TrialStartTime, Data.ResponseTime, Data.DrinkTime];
    end
    c = 0;
    for a = f'
        c = c+1;
        h = bar(1:numel(Data.Score), D(:,c), 1, ...
            'Parent', A.(a{:}), ...
            'FaceColor', 'flat', ...
            'EdgeColor', 'none');
        switch a{:} %Different colors for each graph
            case "ResponseTime"
                Correct = find(Data.Score == 1);
                Wrong = find(Data.Score == 0);
                [h.CData(Correct,:)] = repmat([0 1 0], numel(Correct), 1);
                [h.CData(Wrong,:)] = repmat([1 0 0], numel(Wrong), 1);
        end
    end
    [A.XLimitMethod] = deal("tight");
end
function plotTrialHistory(Ax, Data)
hold(Ax, 'on')
[LRT, plotScore] = CalculateTH(Data.isLeftTrial, Data.Score);
colors = {[0 1 1], [1 1 0], [1 1 1]};
Shape_code = {'o', 's', '^', 'd', 'p', 'h', 'x', 'v', '+'};
    b = bar(1:numel(Data.isLeftTrial), 1, 'Parent', Ax, 'FaceColor', 'flat', 'EdgeColor', 'None');
    for s = 1:3
        if isempty(LRT{s})
            continue
        end
        [b.CData(LRT{s},:)] = repmat(colors{s}, numel(LRT{s}), 1);
    end
    hs = scatter(1:numel(Data.isLeftTrial), plotScore, 5, [.5 0 0], 'filled', 'Parent', Ax);
    Ax.XLimitMethod = "tight";
end
function [LRT, plotScore] = CalculateTH(isLeftTrial, Score)
LRT = {find(isLeftTrial == 1 & Score ~=2), find(~isLeftTrial == 1 & Score ~=2), find(Score==2)};
plotScore = Score;
plotScore(plotScore==1) = 0.8;
plotScore(plotScore==0) = 0.5;
plotScore(plotScore==2) = 0.2;
end
function plotBinnedPerformance(Ax, Data)
hold(Ax, 'on')
Shape_code = {'o', 's', '^', 'd', 'p', 'h', 'x', 'v', '+'};
if sum(Data.Score~=2)==0
    return
end
try
    [SortData] = CalculateBP(Data);
    halfFull = sum(SortData(:,[4 5 6])')<20; %Find which rows were not full bins
    SortData = [SortData(~halfFull,:) ; SortData(halfFull,:)]; %Put the empty bins last
    [m,~] = size(SortData);
    [~, Levels] = findgroups(SortData(:,1)');
    total = 1:m;
    for L = Levels
        fullrows = SortData(:,1) == L & 20==sum(SortData(:,[4 5 6]),2);
        halffullrows = SortData(:,1) == L & 20>sum(SortData(:,[4 5 6]),2);
        Perf = errorbar( total(fullrows) , SortData(fullrows,2) , SortData(fullrows,3) , 'Parent', Ax);
        Perf.MarkerFaceColor = "auto";
        Perf.MarkerEdgeColor = "auto";
        Perf.LineStyle = 'none';
        Perf.Marker = Shape_code{L};
        Perf.MarkerSize = 9;
        Perf2 = scatter( total(halffullrows) , SortData(halffullrows,2) , 'Parent', Ax);
        Perf2.Marker = Shape_code{L};
        Perf2.MarkerFaceColor = "auto";
        Perf2.MarkerFaceColor = 'flat';
        Perf.SeriesIndex = L;
        Perf2.SeriesIndex = L;
    end
    Ax.YLim = [-0.05 1.2];
    Ax.XLim = [0.5 size(SortData,1)+0.5];
    text(total, 0.03*ones(size(total)), num2cell(round(SortData(:,8)',2)), ...
        'Parent',Ax, ...
        'HorizontalAlignment','center')
    text(total, SortData(:,2), Data.SetStr(SortData(:,10)'), ...
        'Parent',Ax, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','Top')
    text(total, SortData(:,2), num2cell(SortData(:,2)*100), ...
        'Parent',Ax, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','Bottom')
catch err
    unwrapErr(err)
end
end
function [SortData] = CalculateBP(Data)
try
    SortData = [];
    DayData = [];
    for Lev = Data.LevelGroups
        rows = Data.Level == Lev & Data.Score ~= 2;
        m = sum(rows);
        if m==0
            continue
        end
        levelTbl = [ Data.SmallBin(rows) Data.BigBin(rows) (1:m)' Data.Score(rows) Data.CodedChoice(rows) Data.TimeStamp(rows) Data.SetIdx(rows)]; %Makes array from table
        Sides = getSideBias( levelTbl(:,2), levelTbl(:,5) );
        trialIdcs = accumarray(levelTbl(:,2), levelTbl(:,3), [], @(x)x(end));
        timeStamps = accumarray(levelTbl(:,2), levelTbl(:,6), [], @(x)x(end));
        SetIdcs = accumarray(levelTbl(:,2), levelTbl(:,7), [], @mode); %Get the mode of the SetIdx for each large bin
        Perf = binnedAVG( levelTbl(:,[1 2]), levelTbl(:,4));
        [m,~] = size(Perf);
        LevData = [repmat(Lev, size(Perf,1), 1) Perf(1:m, :) Sides(1:m, :) trialIdcs(1:m, :) timeStamps(1:m, :) SetIdcs]; % (1:m, :) term trims off incomplete bins and timeouts.
        DayData = [DayData ; LevData];
    end
    SortData = sortrows(DayData, 8);
catch err %Keeps breaking because not all fields of Data are rows or columns
    unwrapErr(err)
end
end

function [Out] = getSideBias(Idx, whatDecision)
switch nargin
    case 1 %only side choice data supplied, make ID vector to match the input
        whatDecision = Idx;
        Idx = ones(size(whatDecision));
end
    [~, I] = findgroups(Idx');
    Out = zeros(size(I',1),4);
    LeftCorrect = accumarray(Idx, whatDecision==1, [], @sum);
    LeftTotal = accumarray(Idx, sum(whatDecision==[1 3],2), [], @sum);
    RightCorrect = accumarray(Idx, whatDecision==2, [], @sum);
    RightTotal = accumarray(Idx, sum(whatDecision==[2 4],2), [], @sum);
    T = accumarray(Idx, sum(whatDecision==[5 6],2), [], @sum);
    SB = (RightCorrect./RightTotal)*(0.5)-(LeftCorrect./LeftTotal)*(0.5);
    for i = find(isnan(SB'))
        if RightCorrect(i) == 0
            SB(i) = 0.5;
        elseif LeftCorrect(i) == 0
            SB(i) = -0.5;
        end
    end
    Out(:,1:3) = [LeftTotal T RightTotal];
    Out(:,4) = SB;
end
function [Out] = binnedAVG(index, data)
    binSize = 2;
    try
        [~, ~, b] = histcounts( 1:max(index(:,1)), [1:binSize:max(index(:,1)) inf]);
        %If incomplete last bin, split in half for std?
        AVG = accumarray(index(:,2), data, [], @mean);
        STD = accumarray(b', accumarray(index(:,1), data, [], @mean), [], @std);
        Out = [AVG STD];
    catch
        Out = [0 0];
    end
end

function plotSideBias(Ax, D)
hold(Ax, 'on')
try
    if sum(D.Score~=2)==0
        return
    end
    SBt = CalculateSB(D);
    Shape_code = {'o', 's', '^', 'd', 'p', 'h', 'x', 'v', '+'};
    yline(Ax, 0.5, '-',"Color",[0.4 0.4 0.4])
    lc = 0;
    for SBl = SBt
        try
        lc = lc+1;
        s = scatter(SBl{:}(2,:), 0.5+SBl{:}(1,:), 'Parent', Ax); %Adding 0.5 makes 0 right bias and 1 left bias
        [s.CDataMode] = deal('auto');
        [s.MarkerFaceColor] = deal('flat');
        [s.MarkerEdgeColor] = deal('flat');
        [s.Marker] = deal(Shape_code(D.LevelGroups(lc)));
        [s.CDataMode] = deal('auto');
        end
    end
    Ax.YLim = [-0.05 1.05];
    Ax.XLimitMethod = "tight";
    Ax.YGrid = 'on';
catch err
    unwrapErr(err)
end
end
function SBt = CalculateSB(D)
try
    [~,Levels] = findgroups(D.Level');
    SBt = cell(1, numel(Levels));
    lc = 0;
    for L = Levels
        lc = lc + 1;
        SBl = zeros(2, sum(D.TrialNum~=0 & D.Level==L));
        LS = D.CodedChoice(D.Level == L);
        LS = LS(LS ~= 5 & LS ~= 6);
        SBl(2,:) = D.TrialNum(D.Level==L & D.TrialNum~=0)';
        tn = 1:numel(LS);
        if isempty(tn)
            continue
        end
        for t = tn
            if t >= 21 %After 20 trials use the last 20
                dat = t-19:t;
            else %Before that use every trial but correct the extreme value for the short interval
                dat = 1:t;
            end
            LeftCorrect = sum(LS(dat)==1);
            LeftWrong = sum(LS(dat)==3);
            LeftTotal = LeftWrong + LeftCorrect;
            RightCorrect = sum(LS(dat)==2);
            RightWrong = sum(LS(dat)==4);
            RightTotal = RightWrong + RightCorrect;
            Lside = sum(D.isLeftTrial(dat))/length(D.isLeftTrial(dat));
            Rside = sum(~D.isLeftTrial(dat))/length(D.isLeftTrial(dat));
            SB = (RightWrong/RightTotal)*(0.5)-(LeftWrong/LeftTotal)*(0.5);
            %SB = (RightWrong/RightTotal)*(LeftCorrect/LeftTotal)*(0.5)-(LeftWrong/LeftTotal)*(RightCorrect/RightTotal)*(0.5);
            if isnan(SB) %If they have neglected a side for the whole set of 20, give maximum bias.
                if LeftTotal == LeftCorrect || RightTotal == RightCorrect
                    SB = 0;
                elseif LeftTotal == 0
                    SB = 0.5;
                elseif RightTotal == 0
                    SB = -0.5;
                end
%             elseif abs(SB) == 0.5
%                 if sign(SB) > 0 %positive 1 if SB is positive
%                     SB = (RightWrong - LeftWrong)/(LeftTotal + RightTotal);
%                 else %negative 1 if SB is neg
%                     SB = (RightWrong - LeftWrong)/(LeftTotal + RightTotal);
%                 end
            end
            if t < 21 %Correct for short interval
                SB = SB*(t/10);
            end
            SBl(1,t) = SB;
        end
        SBt{lc} = SBl;
    end
catch err
    unwrapErr(err)
end
end

function plotLevelPerf(Ax, D)
hold(Ax, 'on')
    if sum(D.Score~=2)==0
        return
    end
    try
        Shape_code = {'o', 's', '^', 'd', 'p', 'h', 'x', 'v', '+'}; 
        [lvls, Avgs, txt] = CalculateLP(D.Level, D.Score);
        for l = D.LevelGroups
            try
            w = D.LevelGroups == l;
            s = scatter(find(w), Avgs(w), 'Parent', Ax);
            s.Marker = Shape_code{l};
            end
        end
        s.MarkerFaceColor = "auto";
        s.MarkerFaceColor = 'flat';
        Ax.YLim = [0 1.05];
        Ax.XLim = [min(D.Level)-1 max(D.Level)+1];
        text(lvls, 0.1*ones(size(lvls')), txt, ...
            'Parent', Ax, ...
            'HorizontalAlignment','center')
    catch err
        unwrapErr(err)
    end
end
function [lvls, Avgs, txt] = CalculateLP(Lev, Score)
    try
        Avgs = accumarray(Lev(Score~=2), Score(Score~=2), [], @mean); %This might need to be binned to get a good STD
    catch
        Avgs = accumarray(Lev(Score~=2)', Score(Score~=2)', [], @mean); %This might need to be binned to get a good STD
    end
    txt = num2cell(groupcounts(Lev(Score~=2))');
    [~,lvls] = findgroups(Lev(Score~=2));
end

function PlotStimHistory(Stim, Wheel)
%Make all of the wheel records the same length, normalize to length of 1
%Find correct and incorrect trials
%plot is some type of flip book?
%Or plot to HTML? PDF would be intense.
end

function saveFigure(fig, folder, name)
figure_property = struct; %Reset export Settings:
figure_property.units = 'inches';
figure_property.format = 'pdf';
figure_property.Preview= 'none';
figure_property.Width= '11'; % Figure width on canvas
figure_property.Height= '8.5'; % Figure height on canvas
figure_property.Units= 'inches';
figure_property.Color= 'rgb';
figure_property.Background= 'w';
%         figure_property.FixedfontSize= '9';
%         figure_property.ScaledfontSize= 'auto';
%         figure_property.FontMode= 'scaled';
%         figure_property.FontSizeMin= '.5';
figure_property.FixedLineWidth= '1';
figure_property.ScaledLineWidth= 'auto';
figure_property.LineMode= 'none';
figure_property.LineWidthMin= '0.1';
figure_property.FontName= 'Helvetica';% Might want to change this to something that is available
figure_property.FontWeight= 'auto';
figure_property.FontAngle= 'auto';
figure_property.FontEncoding= 'latin1';
%         figure_property.PSLevel= '3';
figure_property.Renderer= 'painters';
figure_property.Resolution= '600';
figure_property.LineStyleMap= 'none';
figure_property.ApplyStyle= '0';
figure_property.Bounds= 'tight';
figure_property.LockAxes= 'off';
figure_property.LockAxesTicks= 'off';
figure_property.ShowUI= 'off';
figure_property.SeparateText= 'off';
chosen_figure=fig;
set(chosen_figure,'PaperUnits','inches');
set(chosen_figure,'PaperPositionMode','auto');
set(chosen_figure,'PaperSize',[str2double(figure_property.Width) str2double(figure_property.Height)]); % Canvas Size
set(chosen_figure,'Units','inches');
hgexport(fig, join([folder name+'.pdf'], filesep), figure_property); %Save as pdf
end
function unwrapErr(err)
%fprintf('Error at line %d \n', line_num.line)
errFields = fields(err);
for i = 1:numel(errFields)
    if ~matches(errFields{i}, 'stack')
        if ~isempty(err.(errFields{i}))
            disp([errFields{i} ': ' err.(errFields{i})])
        end
    elseif matches(errFields{i}, 'stack')
        for L = numel(err.stack):-1:1
            disp(['In fx ' err.stack(L).name ', line ' num2str(err.stack(L).line)])
        end
    end
end
end