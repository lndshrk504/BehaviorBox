#!/bin/bash
xfce4-terminal -e "bash -c 'matlab -nosplash -nodesktop -r "BehaviorBox_App"'"
xfce4-terminal -e "bash -c 'cam; exec bash'"
sleep 120
xfce4-terminal -e "bash -c 'matlab -nosplash -nodesktop -r "BehaviorBox_App"'"
