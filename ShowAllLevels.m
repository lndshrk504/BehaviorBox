function ShowAllLevels
%This fx plots each difficulty level (1 to 20) and copies the 2 stimulus objects to a tiledlayout.


% copied from https://www.mathworks.com/matlabcentral/answers/477222-copy-a-figure-to-a-subplot-including-all-elements
% close all
% fig1 = figure(1);
% ax = axes('parent',fig1);
% h=plot(ax,rand(1,10));
% xlabel(ax,'x');
% ylabel(ax,'y');
% title(ax,'source');
% fig2 = figure(2);
% ax1 = subplot(2,2,1,'parent',fig2);
% ax2 = subplot(2,2,2,'parent',fig2);
% ax3 = subplot(2,2,3,'parent',fig2);
% ax4 = subplot(2,2,4,'parent',fig2);
% axcp = copyobj(ax, fig2);
% set(axcp,'Position',get(ax1,'position'));
% delete(ax1);
tic
StimSettings = struct();
StimSettings.Stimulus_type = 11;
StimSettings.Input_type = 3;
StimSettings.Stimulussize_y = 900;
StimSettings.Stimulussize_x = 900;
StimSettings.Stimulusposition_x = 0;
StimSettings.Stimulusposition_y = 0;
StimSettings.SpotlightToggle = 1;
StimSettings.Spotlight = 0;
StimSettings.BetweenSpotlight = 0;
StimSettings.LineShade = 0.7;
StimSettings.Background = 0;
StimSettings.SegLength = 13;
StimSettings.SegThick = 5;
StimSettings.SegSpacing = 13;
StimSettings.Orientation = 0;
StimSettings.FinishLine = 0;
isLeftTrial = 0;
AllOpacity = 1:20;
fig = figure(); clf
fig.Visible = 'off';
fig.MenuBar = 'none';
T = tiledlayout(4,10, 'parent', fig, 'TileSpacing', 'none', 'Padding', 'tight');
fig100 = figure(100); clf
fig100.Visible = 'off';
StimObj = BehaviorBoxVisualStimulus(StimSettings);
count = 1;
for i = 1:2:40
    opacity = AllOpacity(count);
    set(groot,'CurrentFigure',fig);
    a1 = nexttile; axis off
    a2 = nexttile; axis off
    clf(100)
    StimObj.DisplayOnScreen(isLeftTrial, opacity)
    copythis1 = fig100.Children(1);
    copythis2 = fig100.Children(2);
    axcp1 = copyobj(copythis1, fig);
    axcp2 = copyobj(copythis2, fig);
    set(axcp1,'Position',get(a1,'position'));
    set(axcp2,'Position',get(a2,'position'));
%     close(100)
    count = count + 1;
end
close(100)
fig.Visible = 'on';
fig.Color = repmat(StimSettings.Background,1,3);
toc
end