function matches = TextSearchFcn(type, searchString, options)
    % FINDSTRINGINTEXTFILESPARALLEL searches for occurrences of a string in text files.
    % This function searches for a specified search string within .txt files
    % located in the directory obtained from GetFilePath and its subdirectories.
    % If the search string is found, it reports the filename and line number.
    % Parallel processing is utilized for faster execution.

    % Validate inputs
    arguments
        type string
        searchString (1,:) char
        options = struct()
    end

    % Obtain the start directory using GetFilePath
    startDirectory = GetFilePath(type, options);

    % Ensure the startDirectory is valid
    if ~isfolder(startDirectory)
        error("The specified path is not a valid folder.");
    end

    % Get a list of all .txt files in the directory and subdirectories
    textFileList = dir(fullfile(startDirectory, '**', '*.txt'));
    numFiles = length(textFileList);
    
    % Preallocate a struct for better performance
    matches = struct('file', {}, 'line', {});
    
    % Parallel processing setup for performance
    parfor fileIndex = 1:numFiles
        % Individual file data
        filePath = fullfile(textFileList(fileIndex).folder, textFileList(fileIndex).name);
        
        % Open the file safely
        fileID = fopen(filePath, 'r');
        
        if fileID == -1
            fprintf('Could not open file: %s\n', filePath);
            continue;
        end
        
        % Read file lines
        fileContent = textscan(fileID, '%s', 'Delimiter', '\n', 'Whitespace', '');
        fclose(fileID);
        
        % Search each line for the search string
        matchIndices = cellfun(@(line) contains(line, searchString), fileContent{1});
        matchedLines = find(matchIndices);
        
        if ~isempty(matchedLines)
            localMatches = arrayfun(@(line) struct('file', filePath, 'line', line), matchedLines, 'UniformOutput', false);
            matches = [matches; localMatches];  %#ok<AGROW>
        end
    end
end
