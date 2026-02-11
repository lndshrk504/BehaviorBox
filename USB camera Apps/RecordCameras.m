function RecordCameras(Opts)
arguments
    Opts.Which double = 1
end
%  Make sure you have the Image Acquisition Toolbox installed.
output = ver;
if ~any(contains({output.Name}, 'Image Acquisition Toolbox'))
    fprintf('Please install Image Acquisition Toolbox for dual camera view')
    return
end
% Make sure the cameras are free and have plenty of memory
%imaqreset
imaqmex('feature','-limitPhysicalMemoryUsage',false)
% Find cameras and remove system items
if isunix && ismac
    CamInfo = imaqhwinfo("macvideo");
elseif isunix
    CamInfo = imaqhwinfo("linuxvideo");
else
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
        if isunix && ismac
            vid = videoinput("macvideo", id, res{w});
        elseif isunix
            vid = videoinput("linuxvideo", id, res{w});
        else
            vid = videoinput("winvideo", id, res{w});
        end
        vid.LoggingMode = "disk";
        vid.DiskLogger = VideoWriter(string(datetime("now","Format","uuuu-MM-dd"))+"Video.mp4", "MPEG-4");
        start(vid)
        for iFrame = 1:150
            frames = getdata(obj,2);
            writeVideo(videoFile, frames);
        end
    catch err
        unwrapErr(err)
    end
end
end