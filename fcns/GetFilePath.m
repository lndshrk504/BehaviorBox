function filepath = GetFilePath(type, options)
%To keep things consistent REUSE this any time a filepath is needed in the
%program.
% As of Fall 2024 Dropbox has changed the file tree, this needs to be
% considered
arguments
    type string
    options = struct()
end
filepath = '';
switch type
    case "Computer"
        filepath = ComputerData();
    case "Data"
        filepath = AnimalData();
end

%Static Functions:
    function F = ComputerData()
        F = '';
        if ispc
            F = fullfile(getenv('USERPROFILE'), 'Desktop', 'BehaviorBox');
        elseif ismac
            F = '/Users/willsnyder/Desktop/BehaviorBox/';
        elseif isunix
            F = fullfile(getenv('HOME'), 'Desktop', 'BehaviorBox');
        end

    end
    function F = AnimalData()
        F = '';
        switch 1
            case ispc
                F = 'D:\Dropbox @RU Dropbox\William Snyder\Gilbert Lab\BehaviorBoxData\Data\';
            case ismac
                F = '/Users/willsnyder/Dropbox @RU Dropbox/William Snyder/Gilbert Lab/BehaviorBoxData/Data/';
            case isunix
                F = fullfile(getenv('HOME'), 'Dropbox (Dropbox @RU)', 'Gilbert Lab', 'BehaviorBoxData', 'Data');
        end
    end

end

