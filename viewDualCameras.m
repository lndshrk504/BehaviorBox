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
    savedPositions = load(saveFile, 'positions');
    positions = savedPositions.positions;
else
    positions = {};
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

        % Create a figure window manually
        fig = figure('Name', sprintf('Camera ID: %d', id), 'NumberTitle', 'off', ...
                     'CloseRequestFcn', @(src,~) savePosition(src, saveFile, vid));

        % Create an axes for the preview
        ax = axes('Parent', fig);

        % Preview the video input inside the specified axes
        preview(vid, ax);

        % Set position if it was saved previously
        if id <= length(positions)
            set(previewWindow, 'Position', positions{idx});
        end

        % Add listener to save window position on close
        addlistener(previewWindow, 'CloseRequestFcn', @(src,~) savePosition(src, saveFile));

    catch err
        unwrapErr(err)
    end
end
end

function savePosition(src, saveFile, vid)
    % Save window position when closed
    position = get(src, 'Position');
    if isfile(saveFile)
        savedPositions = load(saveFile, 'positions');
        positions = savedPositions.positions;
    else
        positions = {};
    end
    positions{end+1} = position; %#ok<AGROW>
    save(saveFile, 'positions');
    
    % Clean up: stop and delete the video input object
    stop(vid);
    delete(vid);

    % Delete the figure
    delete(src); % Actually close the window
end