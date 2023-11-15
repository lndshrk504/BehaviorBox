function EyeTrack
% WBS 11 - 15 - 2023
% From ChatGPT so take with a grain of salt... 
imaqreset
imaqmex('feature','-limitPhysicalMemoryUsage',false);

% Acquire img:
cam = webcam(2); % Connect to the camera
frame = snapshot(cam); % Take a picture
%imshow(frame); % Display the picture

% Detect from img:
grayFrame = rgb2gray(frame); % Detect from bw image
eyeDetector = vision.CascadeObjectDetector('RightEye'); % Pre-trained detector
bbox = step(eyeDetector, grayFrame); % Detect eyes

detectedImg = insertObjectAnnotation(frame, 'rectangle', bbox, 'Eye'); % Annotate detected eyes onto the color image
imshow(detectedImg);
tracker = vision.PointTracker('MaxBidirectionalError', 2);
initialize(tracker, bbox(1:2), filteredFrame);
while true
    frame = snapshot(cam);
    grayFrame = rgb2gray(frame);
    [points, validity] = step(tracker, grayFrame)
    out = insertMarker(frame, points(validity, :), '+');
    imshow(out);
end

end