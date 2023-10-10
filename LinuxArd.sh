#!/bin/bash
#
#
# Install Arduino IDE, Git, etc.
sudo apt update
sudo ubuntu-drivers install 
sudo apt install -y git vim-nox neofetch arduino v4l-utils ffmpeg
sudo apt update && sudo apt autoremove -y
# Add the current user to the dialout group to access the Arduino without root privileges
sudo usermod -a -G dialout $USER

# Define the repository location
REPO_PATH="/home/$USER/Dropbox (Dropbox @RU)/Git/bb"
CLONE_DIR="/home/$USER/Desktop/BehaviorBox"

# Check if the intended clone directory exists and contains a .git subdirectory
if [ -d "$CLONE_DIR/.git" ]; then
    echo "Repository already cloned at $CLONE_DIR."
else
    git clone "$REPO_PATH" "$CLONE_DIR"
fi

cd $CLONE_DIR
rm ~/.bashrc
ln -s $PWD/.bashrc ~/.bashrc

# Display a message to inform the user to log out and back in
echo "Installation complete. Please log out and log back in for group changes to take effect."

# Exit the script
exit 0
