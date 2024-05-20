#!/bin/bash

xfce4-terminal -e "bash -c 'export JAVA_TOOL_OPTIONS="-Djogl.disable.openglarbcontext=1"; matlab -nosplash -nodesktop -r "BehaviorBox_App"'; exec bash"

xfce-terminal -e "bash -c 'export JAVA_TOOL_OPTIONS="-Djogl.disable.openglarbcontext=1"; matlab -nosplash -nodesktop -r "viewDualCameras"'; exec bash"

sleep 30 

xfce4-terminal -e "bash -c 'export JAVA_TOOL_OPTIONS="-Djogl.disable.openglarbcontext=1"; matlab -nosplash -nodesktop -r "BehaviorBox_App"'; exec bash"

