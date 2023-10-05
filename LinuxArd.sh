#!/bin/bash/
# Update etc.
sudo apt update
# Install Arduino IDE
sudo apt install -y arduino

# Add the current user to the dialout group to access the Arduino without root privileges
sudo usermod -a -G dialout $USER

# Display a message to inform the user to log out and back in
echo "Installation complete. Please log out and log back in for group changes to take effect."

# Exit the script
exit 0
