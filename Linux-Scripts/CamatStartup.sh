#!/bin/bash

cd ~/Desktop/BehaviorBox

xfce4-terminal -e "bash -c 'matlab -nosplash -nodesktop -r "viewDualCameras"'; exec bash"
