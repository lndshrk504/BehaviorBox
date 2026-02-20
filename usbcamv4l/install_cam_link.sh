#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN="${ROOT_DIR}/build/usbcamv4l"
GLOBAL_LINK="/usr/local/cam"

if [[ ! -x "${TARGET_BIN}" ]]; then
  echo "Compiled binary not found at ${TARGET_BIN}" >&2
  echo "Build first with: ./install.sh" >&2
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must run as root to write ${GLOBAL_LINK}" >&2
  echo "Run: sudo ${ROOT_DIR}/install_cam_link.sh" >&2
  exit 1
fi

if [[ -d "${GLOBAL_LINK}" && ! -L "${GLOBAL_LINK}" ]]; then
  echo "Refusing to overwrite directory: ${GLOBAL_LINK}" >&2
  exit 1
fi

ln -sfn "${TARGET_BIN}" "${GLOBAL_LINK}"
echo "Installed link: ${GLOBAL_LINK} -> ${TARGET_BIN}"
