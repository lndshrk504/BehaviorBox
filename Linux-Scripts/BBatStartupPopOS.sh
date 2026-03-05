#!/bin/bash

# Pop!_OS Startup Applications command:
# bash -lc 'sleep 20; bash "$HOME/Desktop/BehaviorBox/Linux-Scripts/BBatStartupPopOS.sh"'

# This function opens 3 terminal windows and launches 2 BB instances and opens the cameras
# Pop!_OS GNOME version

cd ~/Desktop/BehaviorBox

gnome-terminal -- bash -lc 'source ~/.bashrc; /usr/local/bin/matlab -nosplash -nodesktop -r "BehaviorBox_App Wheel"; exec bash' &
sleep 45
gnome-terminal -- bash -lc 'source ~/.bashrc; /usr/local/bin/matlab -nosplash -nodesktop -r "BehaviorBox_App Wheel"; exec bash' &
sleep 20
gnome-terminal -- bash -lc 'source ~/.bashrc; cam -f -w; exec bash' &
