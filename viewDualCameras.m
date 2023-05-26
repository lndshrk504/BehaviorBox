function viewDualCameras()
% From ChatGPT on 5/16/23 - Will Snyder
try
    delete(vid1);
end
try
    delete(vid2);
end
% Step 1: Connect your two USB video cameras to your computer.

% Step 2: Make sure you have the Image Acquisition Toolbox installed.
% Check by typing 'ver' in the Command Window.

% Step 3: Initialize the video input objects for both cameras.
info = imaqhwinfo;
try
    adaptorName1 = info.InstalledAdaptors{1};  % Adjust the index if needed
    deviceID1 = 1;  % Adjust the device ID if needed
    vid1 = videoinput(adaptorName1, deviceID1);
catch err
    unwrapErr(err)
end
try
    adaptorName2 = info.InstalledAdaptors{1};  % Adjust the index if needed
    deviceID2 = 2;  % Adjust the device ID if needed
    vid2 = videoinput(adaptorName2, deviceID2);
catch err
    unwrapErr(err)
end
% Step 4: Set the video resolution and format for both cameras. % WBS: This didn't work

%vid1.VideoResolution = [640, 480];  % Adjust the resolution if needed
%vid1.VideoFormat = 'YUY2_640x480';  % Adjust the format if needed
%vid2.VideoResolution = [640, 480];  % Adjust the resolution if needed
%vid2.VideoFormat = 'YUY2_640x480';  % Adjust the format if needed

% Step 5: Preview the video streams from both cameras.
try
    preview(vid1);
catch err
    unwrapErr(err)
end
try
    preview(vid2);
catch err
    unwrapErr(err)
end
% Step 6: Stop the preview when done.
% Close the preview windows manually or use closepreview.
end
