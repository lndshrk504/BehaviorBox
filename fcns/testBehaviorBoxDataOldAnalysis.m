scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(scriptDir);
cd(repoRoot);
run('startup.m');

wheelCfg = struct( ...
    'Inv', localEnvOrDefault("BB_OLD_WHEEL_INV", "Will"), ...
    'Inp', localEnvOrDefault("BB_OLD_WHEEL_INP", "Wheel"), ...
    'Sub', localEnvOrDefault("BB_OLD_WHEEL_SUB", "2332101"), ...
    'ExpectRescuedFallback', false);

noseCfg = struct( ...
    'Inv', localEnvOrDefault("BB_OLD_NOSE_INV", "Will"), ...
    'Inp', localEnvOrDefault("BB_OLD_NOSE_INP", "NosePoke"), ...
    'Sub', localEnvOrDefault("BB_OLD_NOSE_SUB", "2333021"), ...
    'ExpectRescuedFallback', true);

fprintf("Old Wheel analysis smoke test: Inv=%s Inp=%s Sub=%s\n", wheelCfg.Inv, wheelCfg.Inp, wheelCfg.Sub);
localRunOldAnalysis(wheelCfg);

fprintf("Old Nose analysis smoke test: Inv=%s Inp=%s Sub=%s\n", noseCfg.Inv, noseCfg.Inp, noseCfg.Sub);
localRunOldAnalysis(noseCfg);

fprintf("BEHAVIORBOX_DATA_OLD_ANALYSIS_OK\n");

function localRunOldAnalysis(cfg)
BBData = BehaviorBoxData( ...
    'Inv', char(cfg.Inv), ...
    'Inp', char(cfg.Inp), ...
    'Sub', {char(cfg.Sub)}, ...
    'find', 0, ...
    'analyze', 1, ...
    'plot', 0);

assert(isstruct(BBData.AnalyzedData), 'BehaviorBoxData.AnalyzedData should be a struct after analysis.');
assert(~isempty(BBData.AnalyzedData.DayMM), 'BehaviorBoxData.AnalyzedData.DayMM is empty.');

f = figure('Visible', 'off');
ax = axes('Parent', f);
BBData.PlotLevelGroupsByDay('InComposite', true, 'Ax', ax);
close(f);

out = BBData.plotLvByDayOneAxis('Sc', 1, 'LevDay', 1);
localClosePlotOutput(out);

sampleDayBin = BBData.AnalyzedData.DayMM{1}.dayBin{1};
sampleMean = BBData.GetDayBinScalar(sampleDayBin, 'mean');
assert(isnumeric(sampleMean) && isscalar(sampleMean), 'GetDayBinScalar should return a numeric scalar.');

if cfg.ExpectRescuedFallback
    [includeBySetting, setStrBySetting] = BBData.GetRescuedSettingsFallback(struct('SetIdx', [0; 3]), [], {});
    assert(isequal(includeBySetting, [1; 1; 1]), 'Rescued settings fallback should mark all settings as included.');
    assert(all(strcmp(setStrBySetting, 'rescued-missing-settings')), ...
        'Rescued settings fallback should use rescued-missing-settings labels.');
end
end

function localClosePlotOutput(out)
if isempty(out)
    close all
    return
end
if iscell(out)
    out = out{1};
end
try
    parentFigure = ancestor(out, 'figure');
    if ~isempty(parentFigure) && isvalid(parentFigure)
        close(parentFigure);
        return
    end
catch
end
close all
end

function value = localEnvOrDefault(envName, defaultValue)
value = string(getenv(envName));
if strlength(strtrim(value)) == 0
    value = string(defaultValue);
else
    value = strtrim(value);
end
end
