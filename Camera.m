function [outputArg1,outputArg2] = Camera()
%CAMERA Summary of this function goes here
%   This is a function to open a GUI window, select an available camera and
%   then display the video feed. Additionally, it will record that video
%   feed.
imaqreset
createGUI()
imaqmex('feature','-limitPhysicalMemoryUsage',false)


end

function createGUI()

% Create the figure
f = figure('Visible','off','Position',[360,500,450,325]);

% Create push buttons
btn1 = uicontrol('Style', 'pushbutton', 'String', 'Button 1',...
    'Position', [50, 200, 100, 70]);

btn2 = uicontrol('Style', 'pushbutton', 'String', 'Button 2',...
    'Position', [200, 200, 100, 70]);

btn3 = uicontrol('Style', 'pushbutton', 'String', 'Button 3',...
    'Position', [350, 200, 100, 70]);

% Create dropdown menu
popup = uicontrol('Style', 'popup',...
    'String', {'Option 1','Option 2','Option 3'},...
    'Position', [175 50 200 50]);

% Initialize the UI.
% Change units to normalized so components resize automatically.
f.Units = 'normalized';
btn1.Units = 'normalized';
btn2.Units = 'normalized';
btn3.Units = 'normalized';
popup.Units = 'normalized';

% Make the UI visible.
f.Visible = 'on';

end
    