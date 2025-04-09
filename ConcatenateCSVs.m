function ConcatenateCSVs(baseDir)
    arguments
        baseDir char = '/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Microscope/Images/2025-03-06-Female-Shank-Gcamp-Stimulus-Animations' 
    end
    FILELIST = GetCSVs(baseDir);
    Paths = cellfun(@(path) split(path, '/'), FILELIST, 'UniformOutput', false);
    SGs = cellfun(@(path) path{9,:}, Paths, 'UniformOutput', false);
    StimGroups = unique(SGs)';

    % Read all CSV files into a cell array of tables
    tables = cellfun(@(path) readtable(path), FILELIST, 'UniformOutput', false);


    for G = StimGroups
        WG = contains(FILELIST, [G{:} '/']);
        these = FILELIST(WG);
        Tree = split(these{1}, '/');
        Tree{10} = [ G{:} '_All_F.csv'];
        Num_neurons = sum(cellfun(@(x) size(x, 1), tables(WG), 'UniformOutput', true));
        Save_Path = cell2mat(join(Tree(1:10), '/'));
        Fs = vertcat(tables{WG});

    % Label each row in the csv with a total neuron number and the plane it came from\
    % e.g. Neuron_0001_plane_01
        writetable(Fs, Save_Path, "Delimiter",',')


    end






end

function file_list = GetCSVs(baseDir)
    % Get the list of all .csv files 3 levels deep from baseDir
    file_list = searchCSVFiles(baseDir, 0, 5);
end

% Helper function to search CSV files
    function csvFiles = searchCSVFiles(currentDir, currentLevel, maxLevel)
    if currentLevel > maxLevel
        csvFiles = {};
        return;
    end
    
    % List contents of the current directory
    listing = dir(currentDir);
    csvFiles = {};
    
    % Loop over the directory contents
    for i = 1:length(listing)
        if listing(i).isdir
            if ~contains(listing(i).name, '.')
                % Recurse into directory
                nextDir = fullfile(currentDir, listing(i).name);
                csvFiles = [csvFiles; searchCSVFiles(nextDir, currentLevel + 1, maxLevel)];
            end
        elseif contains(listing(i).name, '.csv')
            % Find CSV files
            csvFiles{end+1} = fullfile(currentDir, listing(i).name);
        end
    end
end