#!/bin/bash

# XFCE Sessions and Startup command: bash -lc 'sleep 20; bash "$HOME/Desktop/BehaviorBox/Linux-Scripts/BBatStartupNoseXFCE.sh"'

# This function opens 3 terminal windows and launches 2 BB instances and opens the cameras
# XFCE Xubuntu, not for Pop_OS!

cd ~/Desktop/BehaviorBox

xfce4-terminal -x bash -lc 'source ~/.bashrc; /usr/local/bin/matlab -nosplash -nodesktop -r "BehaviorBox_App Nose"; exec bash' &
sleep 45
xfce4-terminal -x bash -lc 'source ~/.bashrc; /usr/local/bin/matlab -nosplash -nodesktop -r "BehaviorBox_App Nose"; exec bash' &
sleep 20
xfce4-terminal -x bash -lc 'source ~/.bashrc; cam -f -w; exec bash' &
