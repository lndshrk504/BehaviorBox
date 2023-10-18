% From ChatGPT on 5/16/23 - Will Snyder
function viewDualCameras()
%  Make sure you have the Image Acquisition Toolbox installed.
    output = ver;
    if ~any(contains({output.Name}, 'Image Acquisition Toolbox'))
        fprintf('Please install Image Acquisition Toolbox for dual camera view')
        return
    end
    info = imaqhwinfo('linuxvideo');
    CAMS = webcamlist;
    if isempty(CAMS)
        return
    end
    for IDs = cell2mat(info.DeviceIDs)
        try
            %  Initialize the video input object
            vid = videoinput('linuxvideo', IDs, 'YV12_320x184');
            %  Show a preview of the camera:
            preview(vid)
        catch err
            unwrapErr(err)
        end
    end
end
