#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script requires apt-get (Xubuntu/Ubuntu/Debian)." >&2
  exit 1
fi

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "Please run as root or install sudo." >&2
    exit 1
  fi
fi

PACKAGES=(
  build-essential
  cmake
  pkg-config
  libsdl2-dev
  libopencv-dev
)

echo "Updating package index..."
${SUDO} apt-get update

echo "Installing dependencies..."
${SUDO} env DEBIAN_FRONTEND=noninteractive \
  apt-get install -y "${PACKAGES[@]}"

echo "Done. Dependencies installed:"
printf ' - %s\n' "${PACKAGES[@]}"
