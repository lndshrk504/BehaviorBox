function unwrapErr(err)
%Is there an error? Send the err object over here and it will be unwrapped in the command window. Maybe too much info?
errFields = fields(err);
for i = 1:numel(errFields)
    if ~matches(errFields{i}, 'stack')
        if ~isempty(err.(errFields{i}))
            disp([errFields{i} ': ' err.(errFields{i})])
        end
    elseif matches(errFields{i}, 'stack')
        for L = numel(err.stack):-1:1
            disp(['In fx ' err.stack(L).name ', line ' num2str(err.stack(L).line)])
        end
    end
end
end