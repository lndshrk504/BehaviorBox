repoRoot = fileparts(mfilename('fullpath'));
cd(repoRoot);

addpath(repoRoot, '-begin');
addpath(fullfile(repoRoot, 'fcns'), '-begin');

format short g
format compact

clear repoRoot
