function Out = ProcessDFF(InPath, options)
    
    arguments
        InPath char = '/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Data/Will/Wheel/gcamp/3145992/F_tables/'
        options.PlotSave logical = false
        options.Type char = 'Scaled'
    end

    Files = dir(InPath);
    Files = Files(contains({Files.name}, '.csv'));
    Out = cell(size(Files));
    FC = 0;
    for file = Files'
        FC = FC+1;
        tic
        T_path = fullfile(file.folder, file.name);
        T = table2array(readtable(T_path));
% Divide all values by maximum in all of T
        if options.Type == "Scaled"
            ScaledT = T./max(T, [], "all");
        else
            % Zscore the table based on all values
            ScaledT = zscore(T, 1, 'all');
        end
        Centered = Sort(ScaledT);
        Num_Neu = size(T,1);
        Y_Idx = 0;
        Z_Table = T;

% % Test
% f = figure();
% I = imagesc(sortedT);
% I = imagesc(centerSortedT);

% % Divide each row by its own max (not recommended)
%         for n = 1:Num_Neu
%             F = T(n,:);
%             DF = F/max(F);
%             ZF = zscore(F);
%             Z_Table(n,:) = ZF;
%             %        line((1:numel(ZF)), Y_Idx+ZF, "Parent", Ax)
%             Y_Idx = Y_Idx+1;
%         end

        Out{FC} = Centered;
        if options.PlotSave
            f = figure();
            H = heatmap(Z_Table, "GridVisible", false, "Parent", f, "Colormap", hsv, "InnerPosition",[0 0 1 1]);
            Save_Path = strrep(T_path, '.csv','.fig');
            savefig(Save_Path)
            close(f)
        end
        toc
    end

end

function Out = Sort(In, options)
    arguments
        In
        options.Type char = 'center'
    end

% Sort T rows by their max value
        % Find the maximum value of each row
        [maxValues, ~] = max(In, [], 2);

        % Get sorting order based on maximum values
        [~, sortOrder] = sort(maxValues, 'descend');

        % Sort the rows of A based on the order of max values
        sortedT = In(sortOrder, :);

        if options.Type ~= "center"
            Out = sortedT;
            return
        end

        % Calculate the center index
        n = size(sortedT, 1);
        centerIndex = ceil(n / 2);

        % Create an index array for alternating sorting around the center
        sortedIndices = zeros(n, 1);
        sortedIndices(centerIndex) = 1;

        % Alternating indices around the center
        left = centerIndex - 1;
        right = centerIndex + 1;

        for i = 2:n
            if mod(i, 2) == 0
                sortedIndices(right) = i;
                right = right + 1;
            else
                sortedIndices(left) = i;
                left = left - 1;
            end
        end

        % Reorder sorted array by alternating center-out pattern
        centerSortedT = sortedT(sortedIndices, :);

        Out = centerSortedT;
end