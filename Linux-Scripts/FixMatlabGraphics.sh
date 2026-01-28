#!/usr/bin/env bash
# A fresh install of Matlab has a non-functional graphics driver on Xubuntu. 
# Use this script to rename included libraries to break them
# so that Matlab falls back to system libraries which work correctly.

MATLAB_RELEASE="${1:-}"
if [[ -z "$MATLAB_RELEASE" || "$MATLAB_RELEASE" == "-h" || "$MATLAB_RELEASE" == "--help" ]]; then
  echo "Usage: $(basename "$0") <MATLAB_RELEASE>  (e.g. R2025b)" >&2
  exit 1
fi

MATLAB_GLIB_DIR="/usr/local/MATLAB/${MATLAB_RELEASE}/sys/os/glnxa64/"

echo "Fixing Matlab graphics driver (${MATLAB_RELEASE})..."
if ! cd "$MATLAB_GLIB_DIR"; then
  echo "Error: Cannot switch to directory: $MATLAB_GLIB_DIR" >&2
  exit 1
fi
sudo mv libstdc++.so.6 libstdc++.so.6.bak
sudo mv libquadmath.so.0 libquadmath.so.0.bak
sudo mv libgfortran.so.5 libgfortran.so.5.bak
echo "Matlab graphics driver fixed. You may need to restart Matlab for the changes to take effect."
