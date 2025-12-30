#!/bin/bash

cd ~/Desktop/BehaviorBox

xfce4-terminal -e "bash -c 'matlab -nosplash -nodesktop -r "BehaviorBox_App"'; exec bash"

