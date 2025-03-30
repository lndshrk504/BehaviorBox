function OUT = PullOut(IN, chr)
names = fieldnames(IN);
inter = names(contains(names, chr));
vals = cellfun(@(x)IN.(x), inter, "UniformOutput",false);
CIDX = contains(inter, "color", IgnoreCase=true);
vals(CIDX) = cellfun(@(x)repmat(x,1,3), vals(CIDX), "UniformOutput",false);
OUT = cell2struct(vals, erase(inter, chr));
end