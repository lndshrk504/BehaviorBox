%Written by GPT4o 10-9-24
% Use this to find mentions of errors in the text log from Mouse behavior data

% Specify the starting directory
startDir = 'C:\your\start\directory';

% Specify the search string
searchStr = 'your search string';

% Get a list of all .txt files in the directory and subdirectories
txtFiles = dir(fullfile(startDir, '**', '*.txt'));

% Loop over each file
for k = 1:length(txtFiles)
    % Construct the full file path
    filePath = fullfile(txtFiles(k).folder, txtFiles(k).name);
    
    % Open the file for reading
    fid = fopen(filePath, 'r');
    
    if fid == -1
        fprintf('Could not open file: %s\n', filePath);
        continue;
    end
    
    % Read the content of the file line by line
    lineNumber = 0;
    while ~feof(fid)
        line = fgetl(fid);
        lineNumber = lineNumber + 1;
        
        % Check if the line contains the search string
        if contains(line, searchStr)
            fprintf('Match found in file: %s on line %d\n', filePath, lineNumber);
        end
    end
    
    % Close the file
    fclose(fid);
end
