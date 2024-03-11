% ChatGPT 4 wrote this code

x = linspace(0,2*pi,100);
y = sin(x);
h = plot(x,y,'k','LineWidth',2, 'Color',[0.6, 0.6, 0.6]); % save the handle to the line

flashLine(h)

function flashLine(varargin)
    h = varargin{1}; % get the line handle
    steps = 100; % number of steps in transition
    pause_time = 0.5/steps; % time to pause between each step

    start_color = [0.6, 0.6, 0.6]; % starting color
    end_color = [0.2, 0.2, 0.2]; % ending color
    
    for i = 1:steps
        color = start_color + (end_color - start_color) * (i/steps); % new color value
        set(h, 'Color', color); % set the color of the line
        drawnow; % refresh the figure window
        pause(0.001);
    end 

    for i = steps:-1:1
        color = start_color + (end_color - start_color) * (i/steps); % new color value
        set(h, 'Color', color); % set the color of the line
        drawnow; % refresh the figure window
        pause(0.001);
    end 
end
