#!/bin/bash/
#
#
cd ~

# Install Arduino IDE
sudo apt update
sudo apt install -y arduino

# Add the current user to the dialout group to access the Arduino without root privileges
sudo usermod -a -G dialout $USER

# Install Git
echo "Installing Git..."
sudo apt update
sudo apt install -y git

# Define the repository location
REPO_PATH="/home/$USER/your_mounted_directory/repo_name.git"

# Clone the repository
echo "Cloning repository from $REPO_PATH..."
git clone "$REPO_PATH"

# Display a message to inform the user to log out and back in
echo "Installation complete. Please log out and log back in for group changes to take effect."

# Exit the script
exit 0
