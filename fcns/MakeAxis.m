function Out = MakeAxis(options)
    arguments
        options.Ax = [];
        options.m = [];
        options.n = [];
    end
    if isempty(options.Ax) %Make new fig and axis if not supplied
        f = figure;
        if any(isempty([options.m options.n]))
            t = tiledlayout('flow','TileSpacing','none', 'Padding','tight', 'Parent',f);
        else %They both must not be empty
            t = tiledlayout(options.m, options.n,'TileSpacing','none', 'Padding','tight', 'Parent',f);
        end
        Out = f;
    else
        Ax = options.Ax;
        Out = Ax;
    end
    Ax.YTick = [];
    Ax.XTick = [];
end