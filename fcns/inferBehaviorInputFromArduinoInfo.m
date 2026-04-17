function [inputValue, matchedIdentity] = inferBehaviorInputFromArduinoInfo(devicesInfo)
arguments
    devicesInfo struct = struct()
end

inputValue = "";
matchedIdentity = "";

if ~isstruct(devicesInfo) || ~isfield(devicesInfo, 'Arduinos') || isempty(devicesInfo.Arduinos)
    return
end

try
    identities = string({devicesInfo.Arduinos.Identity});
catch
    identities = string.empty(1, 0);
end

identities = strip(identities(:));
identities(identities == "") = [];
if isempty(identities)
    return
end

isNose = contains(identities, "Nose", IgnoreCase=true);
isWheel = contains(identities, "Wheel", IgnoreCase=true);

hasNose = any(isNose);
hasWheel = any(isWheel);
if hasNose && ~hasWheel
    inputValue = "NosePoke";
    matchedIdentity = identities(find(isNose, 1, 'first'));
    return
end

if hasWheel && ~hasNose
    inputValue = "Wheel";
    matchedIdentity = identities(find(isWheel, 1, 'first'));
end
end
