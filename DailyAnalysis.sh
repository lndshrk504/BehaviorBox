#!/usr/bin/env bash
cd ~/Desktop/BehaviorBox
# Append a separator for clarity
echo "-------------------------------------" >> matlab_output.log
# Write the current date and time to the log file
echo "Log Date: $(date '+%Y-%m-%d %H:%M:%S')" >> matlab_output.log
# Append a separator for clarity
echo "-------------------------------------" >> matlab_output.log
# Run the MATLAB script and append its output to the log file
matlab -nodisplay -nosplash -r "run('GroupAnalysis.m'); exit;" >> matlab_output.log 2>&1