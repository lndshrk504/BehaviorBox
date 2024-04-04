% From ChatGPT on 5/16/23 - Will Snyder
function recordVideo(opt)
arguments
    opt.Record logical = true
end
%  Make sure you have the Image Acquisition Toolbox installed.
output = ver;
if ~any(contains({output.Name}, 'Image Acquisition Toolbox'))
    fprintf('Please install Image Acquisition Toolbox for dual camera view')
    return
end
% Make sure the cameras are free and have plenty of memory
imaqreset
imaqmex('feature','-limitPhysicalMemoryUsage',false)
% Find cameras and remove system items
if isunix && ~ismac
    CamInfo = imaqhwinfo('linuxvideo');
elseif ispc
    CamInfo = imaqhwinfo('winvideo');
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
            vid = videoinput('linuxvideo', id, res{w});
        elseif ispc
            vid = videoinput('winvideo', id, res{w});
        end
        preview(vid)
        if opt.Record
            DATE = string(datetime('now','TimeZone','local','Format','yy-MM-dd-HH:mm:ss'));
            filename = 'outputVideo'+DATE+'.avi';
            % set(vid, 'FramesPerTrigger', Inf);
            % set(vid, 'ReturnedColorspace', 'rgb');
            % vid.FrameGrabInterval = 1;
            vid.LoggingMode = "disk";
            vid.FramesPerTrigger = inf;
            VW = VideoWriter("newfile.avi","Uncompressed AVI");
            open(VW)
            vid.DiskLogger = VW;
            start(vid)       % Close the AVI file
            stop(vid);
            close(VW)
        end
    catch err
        unwrapErr(err)
    end
end
end