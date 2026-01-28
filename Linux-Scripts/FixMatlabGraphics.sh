#!/usr/bin/env bash
# A fresh install of Matlab has a non-functional graphics driver on Xubuntu. 
# Use this script to rename included libraries to break them
# so that Matlab falls back to system libraries which work correctly.
echo "Fixing Matlab graphics driver..."
cd /usr/local/MATLAB/R2024a/sys/os/glnxa64/
sudo mv libstdc++.so.6 libstdc++.so.6.bak
sudo mv libquadmath.so.0 libquadmath.so.0.bak
sudo mv libgfortran.so.5 libgfortran.so.5.bak
echo "Matlab graphics driver fixed. You may need to restart Matlab for the changes to take effect."

