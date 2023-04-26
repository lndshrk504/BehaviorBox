function result = cellfunp(func, c, varargin)
% Parallel version of cellfun that uses parfor inside
% from https://www.mathworks.com/matlabcentral/answers/1467-is-cellfun-multithreaded-or-does-it-do-the-operation-one-cell-at-a-time

p = inputParser;
addParameter(p, 'UniformOutput', 0, @isscalar);
parse(p, varargin{:});


result = cell(size(c));

parfor i = 1:numel(c)
    result{i} = func(c{i});
end

if p.Results.UniformOutput % uniform
    result = cell2mat(result);
end
end