function clo(h)
% CLO Clear children of graphics containers.
%
%   clo(h) deletes children of figures/panels/tabs/etc, and resets axes.
%   This is a small convenience wrapper used throughout BehaviorBox.
%
%   Safe behaviors:
%   - Accepts scalar handles, handle arrays, and cell arrays.
%   - Ignores invalid / non-graphics inputs.
%
% Repo patch

if nargin == 0 || isempty(h)
    return
end

% Allow cells of handles
if iscell(h)
    cellfun(@clo, h);
    return
end

% Handle arrays
if numel(h) > 1
    arrayfun(@clo, h);
    return
end

if ~isgraphics(h)
    return
end

try
    % Axes should be reset (clears plots, but keeps the axes object alive)
    if strcmpi(h.Type, 'axes') || isa(h, 'matlab.graphics.axis.Axes')
        cla(h, 'reset');
    else
        delete(allchild(h));
    end
catch
    % Best-effort cleanup for unusual graphics/container types
    try
        delete(allchild(h));
    catch
    end
end

end
