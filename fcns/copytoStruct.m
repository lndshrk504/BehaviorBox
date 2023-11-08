function [a] = copytoStruct(a,b)
%Copy Structure copies the values of matching fieldnames from b to a
aNames = fieldnames(a);
bNames = fieldnames(b);
which = aNames(matches(aNames, bNames));
for w = which'
    a.(w{:}) = b.(w{:});
end
end