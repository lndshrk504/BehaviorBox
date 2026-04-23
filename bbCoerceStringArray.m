function out = bbCoerceStringArray(raw)
out = "";
if isempty(raw)
    return
end
if isstring(raw)
    out = raw(:);
    return
end
if ischar(raw)
    out = string({raw});
    return
end
if iscell(raw)
    values = strings(numel(raw), 1);
    for idx = 1:numel(raw)
        value = bbCoerceStringArray(raw{idx});
        if isempty(value)
            values(idx) = "";
        else
            values(idx) = value(1);
        end
    end
    out = values;
    return
end
if isnumeric(raw) || islogical(raw)
    out = string(raw);
    return
end
try
    out = string(raw);
catch
    try
        out = string(char(raw));
    catch
        try
            out = string(jsonencode(raw));
        catch
            out = "";
        end
    end
end
