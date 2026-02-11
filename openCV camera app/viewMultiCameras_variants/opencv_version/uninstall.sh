#!/usr/bin/env bash
set -euo pipefail
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_BIN="${BIN_DIR}/usbcams"
OLD_BIN="${BIN_DIR}/viewMultiCameras_opencv_sdl"

if [[ -f "${NEW_BIN}" ]]; then
  rm -f "${NEW_BIN}"
  echo "Removed: ${NEW_BIN}"
else
  echo "Not found: ${NEW_BIN}"
fi

if [[ -f "${OLD_BIN}" ]]; then
  rm -f "${OLD_BIN}"
  echo "Removed legacy binary: ${OLD_BIN}"
fi
