function viewDualCameras
%  Make sure you have the Image Acquisition Toolbox installed.
output = ver;
if ~any(contains({output.Name}, 'Image Acquisition Toolbox'))
    fprintf('Please install Image Acquisition Toolbox for dual camera view')
    return
end

% File to save the window positions
saveFile = 'cameraPositions.mat';

% Attempt to load saved positions
if isfile(saveFile)
    savedPositions = load(saveFile, 'Positions');
    Positions = savedPositions.Positions;
else
    Positions = {};
end

% Make sure the cameras are free and have plenty of memory
imaqreset
imaqmex('feature','-limitPhysicalMemoryUsage',false)

% Find cameras and remove system items
if isunix && ~ismac
    CamInfo = imaqhwinfo("linuxvideo");
elseif ismac
    CamInfo = imaqhwinfo("macvideo");
elseif ispc
    CamInfo = imaqhwinfo("winvideo");
end
INFO = CamInfo.DeviceInfo;
IDS = CamInfo.DeviceIDs;
List = struct2cell(INFO);
IDS = IDS(~cellfun(@(x) contains(x(end), '0x0'), List(end,:,:)));
if isempty(IDS)
    return
end

% Loop through the IDs and add cameras
for id = cell2mat(IDS)
    info = INFO(id);
    res = info.SupportedFormats; RES = res';
    w = find(contains(res, 'YV12') & contains(res, '320x184'), 1, 'first');
    if isempty(w)
        w = find(contains(res, 'YV12') & contains(res, '320x'), 1, 'first');
    end
    try
        %  Initialize the video input object
        if isunix && ~ismac
            vid = videoinput("linuxvideo", id, res{w});
        elseif ismac
            vid = videoinput("macvideo", id, res{w});
        elseif ispc
            vid = videoinput("winvideo", id, res{w});
        end
        
        % Preview the video input
        previewWindow = preview(vid);
% The actual figure is 4 parent levels up:
        previewWindow.Parent.Parent.Parent.Parent.DeleteFcn = @(src,~) savePosition(src, saveFile);
        CamName = previewWindow.Parent.Parent.Parent.Parent.Name;
        % Set position if it was saved previously
        if any(contains(Positions.CameraName, CamName))
            W = contains(Positions.CameraName, CamName);
            previewWindow.Parent.Parent.Parent.Parent.Position = Positions.Position(W,:);
        end
    catch err
        unwrapErr(err)
    end
end
end

function savePosition(src, saveFile)
    % Save window position when closed
    if isfile(saveFile) % Find the row named for this camera and overwrite the position variable
        savedPositions = load(saveFile, 'Positions');
        Positions = savedPositions.Positions;
        if any(contains(Positions.CameraName, src.Name)) % Overwrite that position
            W = contains(Positions.CameraName, src.Name);
            Positions.Position(W,:) = src.Position;
        else % Add a new row
            Positions = [Positions ; {src.Name, src.Position}];
        end
    else % Remake the variable
        Positions = table('Size', [0 2], 'VariableTypes', {'string', 'double'}, 'VariableNames', {'CameraName','Position'});
        Positions = [Positions ; {src.Name, src.Position}];
    end
    save(saveFile, 'Positions');
    delete(src); % Actually close the window
end