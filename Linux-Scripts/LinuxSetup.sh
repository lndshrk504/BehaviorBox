#!/bin/bash
#
#
# Usage/help
usage() {
  cat <<'EOF'
Usage: LinuxSetup.sh [options]

Options:
  -i, --install-packages      Enable apt package installation (disabled by default)
  --packages <pkg...>         Install only the specified packages (implies --install-packages)
  -h, --help                  Show this help

Examples:
  ./LinuxSetup.sh
  ./LinuxSetup.sh --install-packages
  ./LinuxSetup.sh --packages git vim-nox neofetch
EOF
}

INSTALL_PACKAGES=0
PACKAGES=()
DEFAULT_PACKAGES=(git vim-nox neofetch arduino v4l-utils ffmpeg)

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--install-packages)
      INSTALL_PACKAGES=1
      shift
      ;;
    --packages)
      INSTALL_PACKAGES=1
      PACKAGES=()
      shift
      while [[ $# -gt 0 && "$1" != -* ]]; do
        PACKAGES+=("$1")
        shift
      done
      if [[ ${#PACKAGES[@]} -eq 0 ]]; then
        echo "Error: --packages requires at least one package name." >&2
        usage >&2
        exit 1
      fi
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Prevent running the script as root; must be run as a normal user
if [ "$EUID" -eq 0 ]; then
  echo "Please run this script as a normal user (do NOT use sudo ./LinuxArd.sh)."
  exit 1
fi

# Install Arduino IDE, Git, etc.
if [[ "$INSTALL_PACKAGES" -eq 1 ]]; then
  if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    PACKAGES=("${DEFAULT_PACKAGES[@]}")
  fi

  sudo apt update
  #sudo ubuntu-drivers install
  sudo apt install -y "${PACKAGES[@]}"
  sudo apt update && sudo apt autoremove -y
else
  echo "Skipping apt package installation (pass --install-packages to enable)."
fi

if command -v brew >/dev/null 2>&1; then
  echo "Homebrew already installed; skipping."
else
  sudo apt install curl build-essential -y
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but not installed. Re-run with --install-packages or install git first." >&2
  exit 1
fi

# Configure global Git settings (will be the same on all machines)
git config --global user.name "Will Snyder"
git config --global user.email "wsnyder+${HOSTNAME}@rockefeller.edu"
git config --global init.defaultBranch main
git config --global core.editor "vim"
# Example extra options you might want:
git config --global pull.rebase false
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
ln -s "$PWD/Linux-Scripts/.bashrc" ~/.bashrc

# Display a message to inform the user to log out and back in
echo "Installation complete. Please log out and log back in for group changes to take effect."

# Exit the script
exit 0
