function unwrapErr(err)
    % Unwraps and prints the details of an error object
    fprintf(2, 'Error: %s\n', err.message);
    for k = 1:length(err.stack)
        fprintf(2, 'In %s at line %d\n', err.stack(k).name, err.stack(k).line);
    end
end