#!/bin/bash
set -euo pipefail

DRY_RUN=false
VERBOSE=true
QUIET=false

usage() {
  cat <<'EOF'
Usage: BashrcSetup.sh

Copies shared bash files into your home directory.
- Linux-Scripts/.bashrc -> ~/.bashrc
- Linux-Scripts/.bash_aliases -> ~/.bash_aliases
- Linux-Scripts/.bash_local_CUDA -> ~/.bash_local when an NVIDIA GPU is detected
- Linux-Scripts/.bash_local_nogpu -> ~/.bash_local when no NVIDIA GPU is detected

Options:
  -n, --dry-run    Show actions without making any file changes.
  -q, --quiet      Suppress verbose-only output (dry-run warnings still shown).
  -v, --verbose    Show detailed execution flow.
  -h, --help       Show this help text.

Existing target files are backed up to the next available numbered backup:
  ~/.bashrc.bak01
  ~/.bashrc.bak02
  ...
  ~/.bash_aliases.bak01
  ~/.bash_aliases.bak02
  ...
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -q|--quiet)
      QUIET=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      QUIET=false
      shift
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
  echo "Please run this script as a normal user (do NOT use sudo ./BashrcSetup.sh)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BASHRC="$SCRIPT_DIR/.bashrc"
TARGET_BASHRC="$HOME/.bashrc"
SOURCE_BASH_ALIASES="$SCRIPT_DIR/.bash_aliases"
TARGET_BASH_ALIASES="$HOME/.bash_aliases"
SOURCE_BASH_LOCAL_CUDA="$SCRIPT_DIR/.bash_local_CUDA"
SOURCE_BASH_LOCAL_NOGPU="$SCRIPT_DIR/.bash_local_nogpu"
TARGET_BASH_LOCAL="$HOME/.bash_local"

if [[ ! -f "$SOURCE_BASHRC" ]]; then
  echo "Error: source bashrc not found at $SOURCE_BASHRC." >&2
  exit 1
fi

if [[ ! -f "$SOURCE_BASH_ALIASES" ]]; then
  echo "Error: source aliases file not found at $SOURCE_BASH_ALIASES." >&2
  exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[dry-run] No files will be modified."
fi

log_info() {
  local message="$1"
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[verbose] $message"
  fi
}

if [[ "$VERBOSE" == "true" && "$QUIET" != "true" ]]; then
  log_info "Verbose mode enabled."
  log_info "SCRIPT_DIR=$SCRIPT_DIR"
  log_info "Sources: $SOURCE_BASHRC, $SOURCE_BASH_ALIASES, $SOURCE_BASH_LOCAL_CUDA, $SOURCE_BASH_LOCAL_NOGPU"
  log_info "Targets: $TARGET_BASHRC, $TARGET_BASH_ALIASES, $TARGET_BASH_LOCAL"
fi

get_next_backup_path() {
  local target="$1"
  local backup_index=1
  local backup_path

  while :; do
    backup_path="${target}.bak$(printf '%02d' "$backup_index")"
    if [[ ! -e "$backup_path" ]]; then
      printf '%s\n' "$backup_path"
      return 0
    fi
    ((backup_index++))
  done
}

backup_if_exists() {
  local target="$1"

  if [[ ! -e "$target" ]]; then
    return
  fi

  local backup_path
  backup_path="$(get_next_backup_path "$target")"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Would back up existing $target to $backup_path."
    return
  fi

  mv -- "$target" "$backup_path"
  echo "Backed up existing $target to $backup_path."
}

has_nvidia_gpu() {
  log_info "Checking for NVIDIA GPU via lspci."
  if command -v lspci >/dev/null 2>&1; then
    if lspci 2>/dev/null | grep -qiE 'nvidia'; then
      log_info "NVIDIA detected in lspci output."
      return 0
    fi
    log_info "No NVIDIA device found in lspci output."
  else
    log_info "lspci not available."
  fi

  log_info "Checking for NVIDIA GPU via nvidia-smi."
  if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi -L >/dev/null 2>&1; then
      log_info "nvidia-smi -L succeeded."
      return 0
    fi
    log_info "nvidia-smi present but no GPU list available."
  else
    log_info "nvidia-smi not available."
  fi

  log_info "No NVIDIA GPU detected."
  return 1
}

copy_file() {
  local source="$1"
  local target="$2"

  if [[ ! -f "$source" ]]; then
    echo "Error: source file not found at $source." >&2
    exit 1
  fi

  backup_if_exists "$target"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Would copy $source to $target."
    return
  fi

  cp -- "$source" "$target"
  echo "Copied $source to $target."
}

copy_file "$SOURCE_BASHRC" "$TARGET_BASHRC"
copy_file "$SOURCE_BASH_ALIASES" "$TARGET_BASH_ALIASES"

if has_nvidia_gpu; then
  if [[ -f "$SOURCE_BASH_LOCAL_CUDA" ]]; then
    echo "NVIDIA GPU detected."
    copy_file "$SOURCE_BASH_LOCAL_CUDA" "$TARGET_BASH_LOCAL"
  else
    echo "Warning: NVIDIA GPU detected but $SOURCE_BASH_LOCAL_CUDA was not found. Skipping ~/.bash_local copy." >&2
  fi
else
  echo "No NVIDIA GPU detected."
  if [[ -f "$SOURCE_BASH_LOCAL_NOGPU" ]]; then
    echo "Copying non-GPU local shell settings."
    copy_file "$SOURCE_BASH_LOCAL_NOGPU" "$TARGET_BASH_LOCAL"
  else
    echo "Warning: No NVIDIA GPU detected but $SOURCE_BASH_LOCAL_NOGPU was not found. Skipping ~/.bash_local copy." >&2
  fi
fi
