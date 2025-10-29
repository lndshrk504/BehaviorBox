% Wheel (only 16p males)
% W = BehaviorBoxData(Inv='Will', Inp='Wheel', Sub={'251742'}, BB=20, SB=10);
% W.GroupData



%X = BehaviorBoxData(Inv='Will', Inp='NosePoke', Sub={'1234568'}, BB=20, SB=10);

%X = BehaviorBoxData(Inv='Will', Inp='NosePoke', Sub={'2822464'}, BB=20, SB=10);

%Sh = BehaviorBoxData(Inv='Will', Inp='NosePoke', Sub={'shank'}, BB=20, SB=10);



% Females, nose
All_F = BehaviorBoxDataNew(Inv='Will', Inp='NosePoke', Sub={'- F -'}, BB=20, SB=10);
F_Last_Completed = BehaviorBoxDataNew(Inv='Will', Inp='NosePoke', Sub={'314255'}, BB=20, SB=10);
F_Last_Completed.GroupData( ...
    "Composite",false, ...
    'LevGroup',false, ...
    'History',false, ...
    'Stim',false, ...
    'LevelProgress',true, ...
    'LevelProgressIndividual',true, ...
    'Save',true, ...
    'FileName','314255-Lev-1-6-10-15-20')
All_M = BehaviorBoxDataNew(Inv='Will', Inp='NosePoke', Sub={'- M -'}, BB=20, SB=10);
All_M.GroupData( ...
    "Composite",false, ...
    'LevGroup',false, ...
    'History',false, ...
    'Stim',false, ...
    'LevelProgress',true, ...
    'LevelProgressIndividual',true, ...
    'Save',true, ...
    'FileName','')
M = BehaviorBoxDataNew(Inv='Will', Inp='NosePoke', Sub={'314256', '316904'}, BB=20, SB=10);
F.GroupData( ...
    "Composite",false, ...
    'LevGroup',false, ...
    'History',false, ...
    'Stim',false, ...
    'LevelProgress',true, ...
    'LevelProgressIndividual',true, ...
    'Save',true, ...
    'FileName','314255-Lev-1-6-10-15-20')
% Males, nose
M.GroupData( ...
    "Composite",false, ...
    'LevGroup',false, ...
    'History',false, ...
    'Stim',false, ...
    'LevelProgress',true, ...
    'LevelProgressIndividual',true, ...
    'Save',true, ...
    'FileName','314256-316904')



All_M = BehaviorBoxDataNew(Inv='Will', Inp='NosePoke', Sub={'- M -'}, BB=20, SB=10);
% Searching manually for the last trial of level 1 for each mouse, after
% which their lv1 performance was consistent
% For Sub 1: 2471942
% finished on day 10
total = 0;
for DAY = 1:9
    total = total + numel(All_M.AnalyzedData.DayMM{1,1}.dayBin{DAY,:}.Responses{1,1});
end
total = total + find(All_M.AnalyzedData.DayMM{1,1}.dayBin{10,:}.bMM{1,1}>=0.82, 1, "first")
% = 1164

% For Sub 2: 2471943
% finished on day 9
total = 0;
for DAY = 1:8
    total = total + numel(All_M.AnalyzedData.DayMM{1,2}.dayBin{DAY,:}.Responses{1,1});
end
% total is 1137
find(All_M.AnalyzedData.DayMM{1,2}.dayBin{9,:}.bMM{1,1}>=0.8, 1, "first")
total = total + 198
% = 1335

% For Sub 3: 2822461
% finished on day 10
total = 0;
for DAY = 1:9
    total = total + numel(All_M.AnalyzedData.DayMM{1,3}.dayBin{DAY,:}.Responses{1,1});
end
% total is 1154
find(All_M.AnalyzedData.DayMM{1,3}.dayBin{10,:}.bMM{1,1}>=0.8, 1, "first")
total = total + 23
% = 1177

% For Sub 4: 2822464
% finished on day 10
total = 0;
for DAY = 1:9
    total = total + numel(All_M.AnalyzedData.DayMM{1,4}.dayBin{DAY,:}.Responses{1,1});
end
total % = 1010
% all of day 10 was above threshold so use the last trial from day 9
total = total + find(All_M.AnalyzedData.DayMM{1,4}.dayBin{10,:}.bMM{1,1}>=0.82, 1, "first")

% For Sub 5: 3142561
% finished on day 25
total = 0;
for DAY = 1:24
    total = total + numel(All_M.AnalyzedData.DayMM{1,5}.dayBin{DAY,:}.Responses{1,1});
end
total % = 2251
total = total + find(All_M.AnalyzedData.DayMM{1,5}.dayBin{25,:}.bMM{1,1}>=0.82, 1, "first")

% For Sub 6: 3142562
N = 6;
% finished on day
ENDDAY = 12 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_M.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 1026
total = total + find(All_M.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.82, 1, "first")
total = total + 37

% For Sub 7: 3169042
N = 7;
% finished on day
ENDDAY = 16 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_M.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 1957
total = total + find(All_M.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.82, 1, "first")
total = total + 37

% For Sub 8: 2471941
N = 8;
% finished on day
ENDDAY = 9 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_M.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 927
total = total + find(All_M.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 111

% For Sub 9: 2822462
N = 9;
% finished on day
ENDDAY = 15 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_M.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 1595
total = total + find(All_M.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 37

% For Sub 10: 2822463
N = 10;
% finished on day
ENDDAY = 10 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_M.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 1092
total = total + find(All_M.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 48

% For Sub 11: 3142563
N = 11;
% finished on day
ENDDAY = 15 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_M.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 1026
total = total + find(All_M.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 37

% For Sub 12: 3169041   
N = 12;
% finished on day
ENDDAY = 9 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_M.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 1026
total = total + find(All_M.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 37