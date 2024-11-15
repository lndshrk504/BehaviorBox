#!/bin/bash

# Define the directory where your Git repository is located
REPO_DIR="~/Desktop/BehaviorBox"
LOG_DIR="$REPO_DIR/Logs"
LOG_FILE="$LOG_DIR/update_log.txt"

# Ensure the Logs directory exists
mkdir -p "$LOG_DIR"

touch "$LOG_FILE"
# Function to log the current date and time
log_date() {
    echo "Repo update attempt on: $(date)" >> "$LOG_FILE"
}

# Change to the specified directory
if cd "$REPO_DIR"; then
    echo "Switched to directory: $REPO_DIR"
    log_date
else
    echo "Error: Cannot switch to directory: $REPO_DIR" | tee -a "$LOG_FILE"
    exit 1
fi

# Pull the latest changes from the remote repository
git_output=$(git pull 2>&1)
if echo "$git_output" | grep -q "Already up to date\|Updating"; then
    echo "Success: Successfully pulled the latest changes on $(date)." | tee -a "$LOG_FILE"
else
    echo "Error: Git pull failed. Details: $git_output" | tee -a "$LOG_FILE"
    exit 1
fi