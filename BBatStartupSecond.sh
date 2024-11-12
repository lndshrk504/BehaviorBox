#!/bin/bash
sleep 20
xfce4-terminal -e "bash -c 'export JAVA_TOOL_OPTIONS="-Djogl.disable.openglarbcontext=1"; matlab -nosplash -nodesktop -r "BehaviorBox_App"'; exec bash"