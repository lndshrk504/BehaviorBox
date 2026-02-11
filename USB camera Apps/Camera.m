function [outputArg1,outputArg2] = Camera()
%CAMERA Summary of this function goes here
%   This is a function to open a GUI window, select an available camera and
%   then display the video feed. Additionally, it will record that video
%   feed.
imaqreset
imaqmex('feature','-limitPhysicalMemoryUsage',false)
% Find cameras and remove system items
if isunix && ismac
    CamInfo = imaqhwinfo("macvideo");
else
    CamInfo = imaqhwinfo("linuxvideo");
end
INFO = CamInfo.DeviceInfo;
IDS = CamInfo.DeviceIDs;
List = struct2cell(INFO);
IDS = IDS(~cellfun(@(x) contains(x(end), '0x0'), List(end,:,:)));
if isempty(IDS)
    return
end

Hs = createGUI();
Hs.popup.String = {CamInfo.DeviceInfo.DeviceName};

end

function Out = createGUI()
Out = struct();

% Create the figure
f = figure('Visible','on', ...
    'ToolBar','none', ...
    'MenuBar','none');

% Create push buttons
btn1 = uicontrol('Style', 'pushbutton', 'String', 'Record',...
    'Position', [50, 0, 100, 25]);

% Create dropdown menu
popup = uicontrol('Style', 'popup',...
    'String', {'Option 1','Option 2','Option 3'},...
    'Position', [175 0 200 25]);

% Initialize the UI.
% Change units to normalized so components resize automatically.
f.Units = 'normalized';
btn1.Units = 'normalized';
popup.Units = 'normalized';

% Make the UI visible.
f.Visible = 'on';

Out.f = f;
Out.btn1 = btn1;
Out.popup = popup;

end
    