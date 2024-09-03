function unwrapErr(err)
    % Unwraps and prints the details of an error object
    disp(['Error message: ' err.message]); % Print the error message
    errFields = fields(err);
    for i = 1:numel(errFields)
        if ~matches(errFields{i}, 'stack')
            if ~isempty(err.(errFields{i}))
                disp([errFields{i} ': ' err.(errFields{i})])
            end
        elseif matches(errFields{i}, 'stack')
            for L = numel(err.stack):-1:1
                disp(['In function ' err.stack(L).name ', line ' num2str(err.stack(L).line)])
            end
        end
    end
end