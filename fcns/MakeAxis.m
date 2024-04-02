function Out = MakeAxis(options)
% This function creates a tiledlayout with 1 axis and returns the handle
% for that axis
    arguments
        options.Ax = [];
        options.m = [];
        options.n = [];
        options.NoTick logical = true
        options.FigOrAx char = 'Ax'
    end
    if isempty(options.Ax) %Make new fig and axis if not supplied
        f = figure;
        if any(isempty([options.m options.n]))
            t = tiledlayout('flow','TileSpacing','none', 'Padding','tight', 'Parent',f);
        else %They both must not be empty
            t = tiledlayout(options.m, options.n,'TileSpacing','none', 'Padding','tight', 'Parent',f);
        end
        Ax = nexttile(t);
    else
        Ax = options.Ax;
    end
    if options.NoTick
        Ax.YTick = [];
        Ax.XTick = [];
    end
    hold(Ax,"on")
    if options.FigOrAx == "Ax"
        Out = Ax;
    else
        Out = Ax.Parent.Parent;
    end
end