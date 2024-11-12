#!/bin/bash

xfce-terminal -e "bash -c 'export JAVA_TOOL_OPTIONS="-Djogl.disable.openglarbcontext=1"; matlab -nosplash -nodesktop -r "viewDualCameras"'; exec bash"