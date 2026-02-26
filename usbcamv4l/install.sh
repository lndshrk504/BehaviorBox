#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
LINK_FILE="${ROOT_DIR}/usbcamv4l"
CTL_LINK_FILE="${ROOT_DIR}/usbcamctl"
INSTALL_DIR="/usr/local/bin"
INSTALL_NAME="cam"
CTL_INSTALL_NAME="camctl"

mkdir -p "${BUILD_DIR}"

if [[ ! -f "${ROOT_DIR}/CMakeLists.txt" ]]; then
  echo "CMakeLists.txt not found in ${ROOT_DIR}" >&2
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required. Install dependencies with ./deps_install.sh" >&2
  exit 1
fi

cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${BUILD_DIR}" -j

ln -sf "build/usbcamv4l" "${LINK_FILE}"
ln -sf "build/usbcamctl" "${CTL_LINK_FILE}"

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "Root access is required to install into ${INSTALL_DIR}. Run as root or install sudo." >&2
    exit 1
  fi
fi

${SUDO} install -d "${INSTALL_DIR}"
${SUDO} install -m 0755 "${BUILD_DIR}/usbcamv4l" "${INSTALL_DIR}/${INSTALL_NAME}"
${SUDO} install -m 0755 "${BUILD_DIR}/usbcamctl" "${INSTALL_DIR}/${CTL_INSTALL_NAME}"

echo "Built: ${BUILD_DIR}/usbcamv4l"
echo "Launch with: ${LINK_FILE}"
echo "Control with: ${CTL_LINK_FILE} status"
echo "Installed: ${INSTALL_DIR}/${INSTALL_NAME}"
echo "Installed: ${INSTALL_DIR}/${CTL_INSTALL_NAME}"
