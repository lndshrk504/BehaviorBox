function Out = GetDFF(InPath, options)
arguments
    InPath char = '/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Data/Will/Wheel/gcamp/3145992/F_tables/'
    options.PlotSave logical = false
end

    Files = dir(InPath);
    Files = Files(contains({Files.name}, '.csv'));
    Out = cell(size(Files));
    FC = 0;
    for file = Files'
        FC = FC+1;
        tic
        T_path = fullfile(file.folder, file.name);
        Save_Path = strrep(T_path, '.csv','.fig');
        T = table2array(readtable(T_path));
        Num_Neu = size(T,1);
        Y_Idx = 0;
        Z_Table = T;
        for n = 1:Num_Neu
            F = T(n,:);
            DF = F/max(F);
           %ZF = zscore(F);
            Z_Table(n,:) = DF;
            %        line((1:numel(ZF)), Y_Idx+ZF, "Parent", Ax)
            Y_Idx = Y_Idx+1;
        end
        Out{FC} = Z_Table;
        if options.PlotSave
            f = figure();
            H = heatmap(Z_Table, "GridVisible", false, "Parent", f, "Colormap", hsv, "InnerPosition",[0 0 1 1]);
            savefig(Save_Path)
            close(f)
        end
        toc
    end

end