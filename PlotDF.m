function PlotDF(InTable)
    T = readtable('/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Data/Will/Wheel/gcamp/3145992/F_tables/Linesweep-solid-y-line_All_F.csv');
    f = figure();
    Num_Neu = size(T,1);
    Y_Idx = 0;
    Z_Table = T;
    for n = 1:Num_Neu
        F = T{n,:};
        DF = F/max(F);
        ZF = zscore(F);
        Z_Table{n,:} = DF;
%        line((1:numel(ZF)), Y_Idx+ZF, "Parent", Ax)

        Y_Idx = Y_Idx+1;
    end
    H = heatmap(table2array(Z_Table), "GridVisible", false, "Parent", f, "Colormap", hsv, "InnerPosition",[0 0 1 1]);
    

end