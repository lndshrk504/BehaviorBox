#!/bin/bash

# Function to check if a program exists
check_program() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 could not be found."
        exit 1
    fi
}

check_program v4l2-ctl
check_program ffplay

# Get list of connected cameras
cams=($(v4l2-ctl --list-devices | grep -Eo "/dev/video[0-9]+"))

# If no cameras were found, exit
if [ ${#cams[@]} -eq 0 ]; then
    echo "No USB cameras found."
    exit 0
fi

# Loop through the cameras and open a live feed for each
for cam in "${cams[@]}"; do
    echo "Opening live feed for $cam..."
    ffplay -f v4l2 -i "$cam" &
    sleep 1 # slight delay to avoid potential overlaps in opening multiple feeds
done

echo "Press [q] inside a video window to close it."

