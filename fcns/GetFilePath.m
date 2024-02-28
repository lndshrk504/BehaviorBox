function filepath = GetFilePath(type, options)
%To keep things consistent REUSE this any time a filepath is needed in the
%program.
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
        elseif isunix
            F = fullfile(getenv('HOME'), 'Desktop', 'BehaviorBox');
        end

    end
    function F = AnimalData()
        F = '';
        switch 1
            case ispc
                F = 'C:\Users\Will\Dropbox (Dropbox @RU)\Gilbert Lab\BehaviorBoxData\Data\';
            case isunix
                F = fullfile(getenv('HOME'), 'Dropbox (Dropbox @RU)', 'Gilbert Lab', 'BehaviorBoxData', 'Data');
        end
    end

end

