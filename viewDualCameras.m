% From ChatGPT on 5/16/23 - Will Snyder
function viewDualCameras()
    sl = serialportlist("available");
    sl(contains(sl, '1')) = [];
    if numel(sl)>0
       %return
    end
    % Step 2: Make sure you have the Image Acquisition Toolbox installed.
    output = ver;
    if ~any(contains({output.Name}, 'Image Acquisition Toolbox'))
        fprintf('Please install Image Acquisition Toolbox for dual camera view')
        return
    end
    info = imaqhwinfo('linuxvideo');
    CAMS = webcamlist;
    for IDs = cell2mat(info.DeviceIDs)
        if numel(CAMS) < IDs
            return
        end
        try
            deviceID1 = 1;  % Adjust the device ID if needed
            % Step 3: Initialize the video input objects for both cameras.
            vid = videoinput('linuxvideo', IDs);
            % Step 4: Set the video resolution and format for both cameras. % WBS: This didn't work
            %vid1.VideoResolution = [640, 480];  % Adjust the resolution if needed
            %vid1.VideoFormat = 'YUY2_640x480';  % Adjust the format if needed
            %vid2.VideoResolution = [640, 480];  % Adjust the resolution if needed
            %vid2.VideoFormat = 'YUY2_640x480';  % Adjust the format if needed
        
            % Step 5: Show a preview of the camera:
            preview(vid)
        catch err
            unwrapErr(err)
        end
    end
end
