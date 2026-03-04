function nums = bb_parseNumList(in)
% Parse GUI list values into a numeric row vector.
%
% Previous code accepted either numeric arrays or text parsed via str2num.
% This helper keeps that behavior while handling string/char/cell inputs.

if isnumeric(in)
    nums = in;
elseif isstring(in)
    if isscalar(in)
        txt = char(in);
    else
        txt = strjoin(cellstr(in(:)'), ' ');
    end
    nums = str2num(txt); %#ok<ST2NM>
elseif ischar(in)
    nums = str2num(in); %#ok<ST2NM>
elseif iscell(in)
    txt = strjoin(string(in(:)'), ' ');
    nums = str2num(txt); %#ok<ST2NM>
else
    nums = [];
end

nums = nums(:)';

end
