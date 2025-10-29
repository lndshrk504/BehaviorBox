% Searching manually for the last trial of level 1 for each mouse, after
% which their lv1 performance was consistent
% Use this to get all the above threshold trials at level 1

find(All_F.AnalyzedData.LevelMM{N}.bMM{1}>0.8)'


% For Sub 2: 2618914   
N = 2;
% finished on day
ENDDAY = 20 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_F.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 4294
total = total + find(All_F.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 164

% For Sub 3: 2471952   
N = 3;
% finished on day
ENDDAY = 7 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_F.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 895
total = total + find(All_F.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 180


% For Sub 4: 2471953
N = 4;
% finished on day
ENDDAY = 11 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_F.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 1441
total = total + find(All_F.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 127


% For Sub 5: 2618912
N = 5;
% finished on day
ENDDAY = 7 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_F.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 1982
total = total + find(All_F.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 93


% For Sub 6: 2618913
N = 6;
% finished on day
ENDDAY = 10 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_F.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 2139
total = total + find(All_F.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 18


% For Sub 7: 3142551
N = 7;
% finished on day
ENDDAY = 3 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_F.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 1441
total = total + find(All_F.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 133


% For Sub 8: 3142552
N = 8;
% finished on day
ENDDAY = 4 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_F.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 409
total = total + find(All_F.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 31


% For Sub 9: 3142553
N = 9;
% finished on day
ENDDAY = 5 ;
total = 0;
for DAY = 1:(ENDDAY-1)
    total = total + numel(All_F.AnalyzedData.DayMM{1,N}.dayBin{DAY,:}.Responses{1,1});
end
total % = 314
total = total + find(All_F.AnalyzedData.DayMM{1,N}.dayBin{ENDDAY,:}.bMM{1,1}>=0.8)
total = total + 144