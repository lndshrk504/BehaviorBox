#!/bin/bash

xfce4-terminal -e "bash -c 'export JAVA_TOOL_OPTIONS="-Djogl.disable.openglarbcontext=1"; matlab -nosplash -nodesktop -r "BehaviorBox_App"'"

xfce4-terminal -e "bash -c 'export JAVA_TOOL_OPTIONS="-Djogl.disable.openglarbcontext=1"; matlab -nosplash -nodesktop -r "viewDualCameras"'"

sleep 30 

xfce4-terminal -e "bash -c 'export JAVA_TOOL_OPTIONS="-Djogl.disable.openglarbcontext=1"; matlab -nosplash -nodesktop -r "BehaviorBox_App"'"

