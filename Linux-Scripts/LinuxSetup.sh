#!/bin/bash
#
#
# Install Arduino IDE, Git, etc.
sudo apt update
sudo ubuntu-drivers install 
sudo apt install -y git vim-nox neofetch arduino v4l-utils ffmpeg
sudo apt update && sudo apt autoremove -y

# Configure global Git settings (will be the same on all machines)
git config --global user.name "Will Snyder"
git config --global user.email "wsnyder+${HOSTNAME}@rockefeller.edu"
git config --global init.defaultBranch main
git config --global core.editor "vim"
# Example extra options you might want:
# git config --global pull.rebase false
git config --global color.ui auto

# Add the current user to the dialout group to access the Arduino without root privileges
sudo usermod -a -G dialout $USER

# Define the repository location
REPO_PATH="$HOME/Dropbox (Dropbox @RU)/Git/bb"
CLONE_DIR="$HOME/Desktop/BehaviorBox"

# Check if the intended clone directory exists and contains a .git subdirectory
if [ -d "$CLONE_DIR/.git" ]; then
    echo "Repository already cloned at $CLONE_DIR."
else
    git clone "$REPO_PATH" "$CLONE_DIR"
fi

cd $CLONE_DIR
mv ~/.bashrc ~/.bashrc.backup
ln -s $PWD/.bashrc ~/.bashrc

# Display a message to inform the user to log out and back in
echo "Installation complete. Please log out and log back in for group changes to take effect."

# Exit the script
exit 0
