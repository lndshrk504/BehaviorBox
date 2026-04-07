scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
cd(repoRoot);
run('startup.m');

tempDataRoot = tempname;
mkdir(tempDataRoot);

shadowDir = tempname;
mkdir(shadowDir);

cfg = struct( ...
    'Inv', localEnvOrDefault("BB_DEBUG_INV", "Will"), ...
    'Inp', localEnvOrDefault("BB_DEBUG_INP", "Wheel"), ...
    'Str', localEnvOrDefault("BB_DEBUG_STR", "New"), ...
    'Sub', localEnvOrDefault("BB_DEBUG_SUB", "9999999"), ...
    'Filename', localEnvOrDefault("BB_DEBUG_FILENAME", "behaviorbox_save_validation"));

fprintf("BehaviorBoxData deferred-save smoke test config: Inv=%s Inp=%s Str=%s Sub=%s Filename=%s\n", ...
    cfg.Inv, cfg.Inp, cfg.Str, cfg.Sub, cfg.Filename);

bb = BehaviorBoxData( ...
    'Inv', 'Will', ...
    'Inp', 'w', ...
    'Str', 'w', ...
    'Sub', {'w'}, ...
    'find', 1, ...
    'analyze', 0);

localWriteShadowGetFilePath(shadowDir, tempDataRoot);
addpath(shadowDir, '-begin');
cleanupShadow = onCleanup(@() rmpath(shadowDir));
cleanupData = onCleanup(@() localSafeRmdir(tempDataRoot));
cleanupShadowDir = onCleanup(@() localSafeRmdir(shadowDir));
rehash;
clear GetFilePath

bb.Inv = char(cfg.Inv);
bb.Inp = char(cfg.Inp);
bb.Str = char(cfg.Str);
bb.Sub = {char(cfg.Sub)};
bb.Settings = struct('ValidationOnly', true);

[candidateFolder, fds] = bb.GetFiles();
expectedFolder = fullfile(tempDataRoot, char(cfg.Inv), char(cfg.Inp), char(cfg.Str), char(cfg.Sub));
expectedFile = fullfile(expectedFolder, char(cfg.Filename + ".mat"));

assert(isempty(fds), 'Expected no datastore for a missing subject folder.');
assert(strcmp(char(string(candidateFolder)), expectedFolder), ...
    'BehaviorBoxData.GetFiles did not preserve the candidate save path.');
assert(~isfolder(expectedFolder), ...
    'BehaviorBoxData lookup should not create a missing subject folder before save.');

bb.filedir = candidateFolder;
bb.SaveAllData(cfg.Filename);

assert(isfolder(expectedFolder), ...
    'BehaviorBoxData.SaveAllData should create the missing subject folder at save time.');
assert(isfile(expectedFile), ...
    'BehaviorBoxData.SaveAllData did not create the expected .mat file.');

saved = load(expectedFile, 'Settings', 'newData', 'Notes');
assert(isfield(saved, 'Settings'), 'Saved file is missing Settings.');
assert(isfield(saved, 'newData'), 'Saved file is missing newData.');
assert(isfield(saved, 'Notes'), 'Saved file is missing Notes.');

fprintf("Deferred-save folder created: %s\n", expectedFolder);
fprintf("Deferred-save file created: %s\n", expectedFile);
fprintf("BEHAVIORBOX_DATA_DEFERRED_SAVE_MKDIR_OK\n");

function localWriteShadowGetFilePath(shadowDir, tempDataRoot)
shadowPath = fullfile(shadowDir, 'GetFilePath.m');
fid = fopen(shadowPath, 'w');
assert(fid > 0, 'Failed to create shadow GetFilePath.m');
cleanupFile = onCleanup(@() fclose(fid));
fprintf(fid, ['function filepath = GetFilePath(type, options)\n' ...
    'arguments\n type string\n options struct = struct()\n end\n' ...
    'switch type\n case "Data"\n filepath = ''%s'';\n otherwise\n' ...
    ' error(''GetFilePath:ValidationOnly'', ''Validation shadow only supports Data.'');\n' ...
    'end\n' ...
    'end\n'], strrep(tempDataRoot, '''', ''''''));
end

function value = localEnvOrDefault(envName, defaultValue)
value = string(getenv(envName));
if strlength(strtrim(value)) == 0
    value = string(defaultValue);
else
    value = strtrim(value);
end
end

function localSafeRmdir(targetDir)
if isfolder(targetDir)
    try
        rmdir(targetDir, 's');
    catch
    end
end
end
