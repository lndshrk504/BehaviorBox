#!/bin/bash

# Check for necessary commands
command -v gst-launch-1.0 >/dev/null 2>&1 || { echo >&2 "GStreamer is not installed. Aborting."; exit 1; }

# Define the number of cameras
NUM_CAMERAS=4

# Loop through each camera and create a GStreamer pipeline
for ((i=0; i<$NUM_CAMERAS; i++)); do
    if [ -e "/dev/video${i}" ]; then
        gst-launch-1.0 v4l2src device="/dev/video${i}" ! videoconvert ! 'video/x-raw, format=(string)I420' ! nvvidconv ! 'video/x-raw(memory:NVMM), format=(string)I420' ! nveglglessink -e &
        sleep 1  # Slight delay for smoother initialization
    else
        echo "Camera /dev/video${i} is not connected or busy."
    fi
done

# Keep the script running so user can view the feeds
echo "Displaying video feeds. Press Ctrl+C to exit."
wait

