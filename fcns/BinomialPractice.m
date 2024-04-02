function [Ax] = BinomialPractice(O)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
arguments
    O.Method char = 'C'
    O.TotalTrials double = 10:10:100
end
tic
Ax = MakeAxis("NoTick",false);
%Ax = f.findobj('Type','Axes')
for Max = O.TotalTrials
    if ~isempty(Ax.Children)
        Ax = nexttile;
    end
    hold(Ax,"on")
    yline(0.05, "Parent",Ax)
    yline(0.01, "Parent",Ax)
    yline(0.001, "Parent",Ax)
    correct = 0:1:Max;
    if O.Method == "P"
        y = binopdf(correct, Max, 0.5);
    else
        y = 1 - binocdf(correct, Max, 0.5);
    end
    TEXT = text(correct./Max, y, string(correct), "HorizontalAlignment","center", "VerticalAlignment","top", "HitTest","off");
    grid on;
    if O.Method == "P"
        Ax.YLim = [0 0.25];
    else
        TEXT = text(correct./Max, y, string(round(correct./Max, 2)), "HorizontalAlignment","center", "VerticalAlignment","bottom", "Color",'r', "HitTest","off");
        Ax.YScale = "log";
        Ax.YLim = [1e-15 1];
    end
    scatter(correct./Max,y, "Parent",Ax);
end
toc
end