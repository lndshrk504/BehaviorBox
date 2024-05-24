#!/usr/bin/env bash
# A fresh install of Matlab has a non-functional graphics driver. Use this script to rename that driver to break it and use the system graphics driver.
cd /usr/local/MATLAB/R2024a/sys/os/glnxa64/
sudo mv libstdc++.so.6 libstdc++.so.6.distlink

