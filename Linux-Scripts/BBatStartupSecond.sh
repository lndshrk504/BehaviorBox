#!/bin/bash

cd ~/Desktop/BehaviorBox

sleep 20
xfce4-terminal -e "bash -c 'matlab -nosplash -nodesktop -r "BehaviorBox_App"'; exec bash"
