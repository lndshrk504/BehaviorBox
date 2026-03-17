#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: LinuxSetup.sh [options]

Options:
  -i, --install-packages      Enable apt package installation (disabled by default)
  --packages <pkg...>         Install only the specified apt packages (implies --install-packages)
  -h, --help                  Show this help

Notes:
  Git global configuration is handled by Linux-Scripts/GitSetup.sh
  .bashrc installation is handled by Linux-Scripts/BashrcSetup.sh

Examples:
  ./LinuxSetup.sh
  ./LinuxSetup.sh --install-packages
  ./LinuxSetup.sh --packages git vim-nox neofetch
EOF
}

INSTALL_PACKAGES=0
CUSTOM_PACKAGES=0
PACKAGES=()
DEFAULT_PACKAGES=(git vim-nox neofetch arduino v4l-utils ffmpeg)
CURRENT_USER="$(id -un)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--install-packages)
      INSTALL_PACKAGES=1
      shift
      ;;
    --packages)
      INSTALL_PACKAGES=1
      CUSTOM_PACKAGES=1
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

if [[ "$EUID" -eq 0 ]]; then
  echo "Please run this script as a normal user (do NOT use sudo ./LinuxSetup.sh)." >&2
  exit 1
fi

if [[ "$INSTALL_PACKAGES" -eq 1 ]]; then
  if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    PACKAGES=("${DEFAULT_PACKAGES[@]}")
  fi

  sudo apt update
  sudo apt install -y "${PACKAGES[@]}"
  sudo apt update
  sudo apt autoremove -y

  if [[ "$CUSTOM_PACKAGES" -eq 0 ]]; then
    if command -v brew >/dev/null 2>&1; then
      echo "Homebrew already installed; skipping."
    else
      sudo apt install -y curl build-essential
      echo "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
  else
    echo "Skipping Homebrew installation because --packages requested a custom apt package list."
  fi
else
  echo "Skipping apt package installation and Homebrew bootstrap (pass --install-packages to enable)."
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but not installed. Re-run with --install-packages or install git first." >&2
  exit 1
fi

sudo usermod -a -G dialout "$CURRENT_USER"

REPO_PATH="$HOME/Dropbox (Dropbox @RU)/Git/bb"
CLONE_DIR="$HOME/Desktop/BehaviorBox"

if [[ -d "$CLONE_DIR/.git" ]]; then
  echo "Repository already cloned at $CLONE_DIR."
else
  git clone "$REPO_PATH" "$CLONE_DIR"
fi

cd "$CLONE_DIR"

echo "Repository setup complete."
echo "Optional next steps:"
echo "  $CLONE_DIR/Linux-Scripts/GitSetup.sh --name \"Your Name\" --email \"you@example.com\""
echo "  $CLONE_DIR/Linux-Scripts/BashrcSetup.sh"
echo "Please log out and log back in for group changes to take effect."
