#!/bin/bash
#
#
cd ~
# Add a few aliases
alias > ~/.bash_aliases
add_alias BB "matlab -nosplash -nodesktop -r "BehaviorBox_App""
add_alias l "ls -CAF"
add_alias Up "sudo apt update && sudo apt upgrade -y && sudo apt autoremove"

sudo ubuntu-drivers install -ysudo ubuntu-drivers install -y
# Install Arduino IDE, Git, etc.
sudo apt update
sudo apt install -y git vim-nox neofetch arduino

# Add the current user to the dialout group to access the Arduino without root privileges
sudo usermod -a -G dialout $USER

# Define the repository location
REPO_PATH="/home/$USER/Dropbox (Dropbox @RU)/Git/bb"

# Clone the repository
echo "Cloning repository from $REPO_PATH..."
git clone "$REPO_PATH" /home/$USER/Desktop/BehaviorBox

# Display a message to inform the user to log out and back in
echo "Installation complete. Please log out and log back in for group changes to take effect."

# Exit the script
exit 0
