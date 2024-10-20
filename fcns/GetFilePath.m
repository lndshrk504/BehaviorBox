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
        case "Archive"
            filepath = ArchiveData();

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
PREFIX = '';
if ispc
    PREFIX = getenv('USERPROFILE');
elseif isunix
    PREFIX = getenv('HOME');
else
    error('GetFilePath:PlatformError', 'Unsupported Operating System.');
end
F = fullfile(PREFIX, 'Desktop', 'BehaviorBox');
end

function F = AnimalData()
% ANIMALDATA Fetches the directory path for 'Animal' data
F = '';
PREFIX = '';
FOLDER = '';
switch true
    case ispc
        PREFIX = 'D:';
        FOLDER = 'Dropbox (Dropbox @RU)';
    case ismac
        PREFIX = getenv('HOME');
        FOLDER = 'Dropbox @RU Dropbox';
    case isunix
        PREFIX = getenv('HOME');
        FOLDER = 'Dropbox (Dropbox @RU)';
    otherwise
        error('GetFilePath:PlatformError', 'Unsupported Operating System.');
end
F = fullfile(PREFIX, FOLDER, 'William Snyder', 'Data');
end

function F = ArchiveData()
% ANIMALDATA Fetches the directory path for 'Animal' data
F = '';
PREFIX = '';
FOLDER = '';
switch true
    case ispc
        PREFIX = 'D:';
        FOLDER = 'Dropbox (Dropbox @RU)';
    case ismac
        PREFIX = getenv('HOME');
        FOLDER = 'Dropbox @RU Dropbox';
    case isunix
        PREFIX = getenv('HOME');
        FOLDER = 'Dropbox (Dropbox @RU)';
    otherwise
        error('GetFilePath:PlatformError', 'Unsupported Operating System.');
end
F = fullfile(PREFIX, FOLDER, 'William Snyder', {'Archive', 'Data'});
end
