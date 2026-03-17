#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: BashrcSetup.sh

Copies Linux-Scripts/.bashrc to ~/.bashrc.
If ~/.bashrc already exists, it is moved to the next numbered backup:
  ~/.bashrc.bak01
  ~/.bashrc.bak02
  ...
EOF
}

if [[ $# -gt 0 ]]; then
  case "$1" in
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
fi

if [[ "$EUID" -eq 0 ]]; then
  echo "Please run this script as a normal user (do NOT use sudo ./BashrcSetup.sh)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BASHRC="$SCRIPT_DIR/.bashrc"
TARGET_BASHRC="$HOME/.bashrc"

if [[ ! -f "$SOURCE_BASHRC" ]]; then
  echo "Error: source bashrc not found at $SOURCE_BASHRC." >&2
  exit 1
fi

if [[ -e "$TARGET_BASHRC" || -L "$TARGET_BASHRC" ]]; then
  backup_index=1
  while :; do
    backup_path="${TARGET_BASHRC}.bak$(printf '%02d' "$backup_index")"
    if [[ ! -e "$backup_path" && ! -L "$backup_path" ]]; then
      break
    fi
    ((backup_index++))
  done

  mv -- "$TARGET_BASHRC" "$backup_path"
  echo "Backed up existing ~/.bashrc to $backup_path."
fi

cp -- "$SOURCE_BASHRC" "$TARGET_BASHRC"
echo "Copied $SOURCE_BASHRC to $TARGET_BASHRC."
