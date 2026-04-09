repoRoot = fileparts(fileparts(mfilename('fullpath')));
cd(repoRoot);

memoryRoot = string(tempname);
fileRoot = string(tempname);
failureRoot = string(tempname);
mkdir(memoryRoot);
mkdir(fileRoot);
mkdir(failureRoot);

cleanupMemory = onCleanup(@() localCleanup(memoryRoot));
cleanupFile = onCleanup(@() localCleanup(fileRoot));
cleanupFailure = onCleanup(@() localCleanup(failureRoot));

inputMemory = BehaviorBoxSerialInput('COM_DOES_NOT_EXIST', 115200, 'NosePoke');
cleanupInputMemory = onCleanup(@() delete(inputMemory));
inputMemory.configureDebugLogging(Mode="memory", Workflow="Nose", SessionSaveFolder=memoryRoot);
inputMemory.consumeRawChars(sprintf('L\n'));
assert(height(inputMemory.DebugHistory) >= 2, 'Expected in-memory serial history rows for input serial.');
assert(~isfolder(fullfile(memoryRoot, 'Debug')), 'Memory mode should not create a Debug folder.');

inputFile = BehaviorBoxSerialInput('COM_DOES_NOT_EXIST', 115200, 'NosePoke');
cleanupInputFile = onCleanup(@() delete(inputFile));
inputFile.configureDebugLogging(Mode="file", Workflow="Nose", SessionSaveFolder=fileRoot);
inputFile.consumeRawChars(sprintf('R\n'));
fileCsv = dir(fullfile(fileRoot, 'Debug', 'serial_txrx_BehaviorBoxSerialInput_*.csv'));
assert(~isempty(fileCsv), 'File mode should create a live serial CSV file.');
fileCsvText = fileread(fullfile(fileCsv(1).folder, fileCsv(1).name));
assert(contains(fileCsvText, BehaviorBoxSerialDebug.csvHeaderLine()), 'Live serial CSV should contain the canonical header.');
assert(contains(fileCsvText, 'raw line receive'), 'Live serial CSV should include the raw receive event.');
assert(contains(fileCsvText, 'parsed event'), 'Live serial CSV should include the parser event.');

timeFailure = BehaviorBoxSerialTime('COM_DOES_NOT_EXIST', 115200);
cleanupTimeFailure = onCleanup(@() delete(timeFailure));
timeFailure.configureDebugLogging(Mode="failure", Workflow="Wheel", SessionSaveFolder=failureRoot);
timeFailure.processReading("123,F 5");
failureContext = struct( ...
    'FailureIdentifier', "BehaviorBox:TopLevelCatch", ...
    'FailureMessage', "forced test failure", ...
    'FailureSource', "AppCatch", ...
    'TopStackFrame', "testSerialDebugLogging.m:1");
timeFailure.flushDebugFailureArtifact(failureContext);

failureJson = dir(fullfile(failureRoot, 'Debug', 'serial_failure_BehaviorBoxSerialTime_*.json'));
failureCsv = dir(fullfile(failureRoot, 'Debug', 'serial_failure_BehaviorBoxSerialTime_*.csv'));
assert(~isempty(failureJson), 'Failure mode should write a JSON metadata file.');
assert(~isempty(failureCsv), 'Failure mode should write a CSV history file.');

failureMeta = jsondecode(fileread(fullfile(failureJson(1).folder, failureJson(1).name)));
assert(strcmp(failureMeta.LogMode, 'failure'), 'Failure metadata should record LogMode=failure.');
assert(strcmp(failureMeta.FailureIdentifier, 'BehaviorBox:TopLevelCatch'), 'Failure metadata should preserve FailureIdentifier.');
assert(strcmp(failureMeta.FailureSource, 'AppCatch'), 'Failure metadata should preserve FailureSource.');
assert(strcmp(failureMeta.TopStackFrame, 'testSerialDebugLogging.m:1'), 'Failure metadata should preserve TopStackFrame.');
assert(failureMeta.EventRowCount >= 2, 'Failure artifact should include the recent serial history.');

failureCsvText = fileread(fullfile(failureCsv(1).folder, failureCsv(1).name));
assert(contains(failureCsvText, BehaviorBoxSerialDebug.csvHeaderLine()), 'Failure CSV should contain the canonical header.');
assert(contains(failureCsvText, 'parsed event'), 'Failure CSV should contain parsed-event rows.');

fprintf('BEHAVIORBOX_SERIAL_DEBUG_OK\n');

function localCleanup(targetDir)
if isfolder(targetDir)
    rmdir(targetDir, 's');
end
end
