function filepath = GetFilePath(type, options)
% GETFILEPATH Generate a consistent filepath based on type and options
%   This function returns a file path depending on the input `type` for
%   organized management of directories.
%
%   INPUT:
%     type    - String indicating the type of path ('Computer', 'Data').
%     options - Struct for future additional configurations (Unused currently).
%
%   OUTPUT:
%     filepath - String containing the generated file path.
%
%   Example:
%     path = GetFilePath("Computer");

    arguments
        type string
        options struct = struct()
    end

    filepath = '';
    try
        switch type
            case "Computer"
                filepath = ComputerData();
            case "Data"
                filepath = AnimalData();
            otherwise
                error("GetFilePath:InvalidType", "Unsupported path type specified.");
        end
    catch err
        fprintf('Error occurred in GetFilePath: %s\n', err.message);
    end
end

function F = ComputerData()
    % COMPUTERDATA Fetches the standard directory path for 'Computer' data
    F = '';
    if ispc
        F = fullfile(getenv('USERPROFILE'), 'Desktop', 'BehaviorBox');
    elseif ismac
        F = fullfile(getenv('HOME'), 'Desktop', 'BehaviorBox');
    elseif isunix
        F = fullfile(getenv('HOME'), 'Desktop', 'BehaviorBox');
    else
        error('GetFilePath:PlatformError', 'Unsupported Operating System.');
    end
end

function F = AnimalData()
    % ANIMALDATA Fetches the directory path for 'Animal' data
    F = '';
    switch true
        case ispc
            F = 'D:\Dropbox @RU Dropbox\William Snyder\Gilbert Lab\BehaviorBoxData\Data\';
        case ismac
            F = '/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Gilbert Lab/BehaviorBoxData/Data/';
        case isunix
            F = fullfile(getenv('HOME'), 'Dropbox (Dropbox @RU)', 'Gilbert Lab', 'BehaviorBoxData', 'Data');
        otherwise
            error('GetFilePath:PlatformError', 'Unsupported Operating System.');
    end
end
