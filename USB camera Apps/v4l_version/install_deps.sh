#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script currently supports Debian/Ubuntu (apt-get)." >&2
  exit 1
fi

APT_PKGS=(
  build-essential
  cmake
  pkg-config
  libx11-dev
  libegl1-mesa-dev
  libgles2-mesa-dev
  libdrm-dev
  libturbojpeg0-dev
  libavcodec-dev
  libavutil-dev
)

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  SUDO="sudo"
fi

echo "Installing dependencies: ${APT_PKGS[*]}"
${SUDO} apt-get update
${SUDO} apt-get install -y "${APT_PKGS[@]}"

echo "Dependency installation complete."
