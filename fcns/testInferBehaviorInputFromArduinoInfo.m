function testInferBehaviorInputFromArduinoInfo()
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'fcns'));

assertInference(struct(), "", "");
assertInference(localDevices_("Nose3"), "NosePoke", "Nose3");
assertInference(localDevices_("Nose3", "Time2"), "NosePoke", "Nose3");
assertInference(localDevices_("Wheel2"), "Wheel", "Wheel2");
assertInference(localDevices_("Wheel2", "Time2", "FakeRoscope"), "Wheel", "Wheel2");
assertInference(localDevices_("Nose3", "Wheel2"), "", "");
assertInference(localDevices_("Time2", "FakeRoscope"), "", "");

fprintf('testInferBehaviorInputFromArduinoInfo passed.\n');
end

function assertInference(devicesInfo, expectedInput, expectedIdentity)
[inputValue, matchedIdentity] = inferBehaviorInputFromArduinoInfo(devicesInfo);
assert(inputValue == string(expectedInput), 'Expected input %s, got %s.', string(expectedInput), inputValue);
assert(matchedIdentity == string(expectedIdentity), 'Expected identity %s, got %s.', string(expectedIdentity), matchedIdentity);
end

function devicesInfo = localDevices_(varargin)
devicesInfo = struct();
devicesInfo.Arduinos = repmat(struct('Port', '', 'Identity', ""), 1, nargin);
for idx = 1:nargin
    devicesInfo.Arduinos(idx).Port = sprintf('/dev/ttyACM%d', idx - 1);
    devicesInfo.Arduinos(idx).Identity = string(varargin{idx});
end
end
