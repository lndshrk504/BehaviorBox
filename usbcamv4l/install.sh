#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
LINK_FILE="${ROOT_DIR}/usbcamv4l"
CTL_LINK_FILE="${ROOT_DIR}/usbcamctl"

mkdir -p "${BUILD_DIR}"

if [[ ! -f "${ROOT_DIR}/CMakeLists.txt" ]]; then
  echo "CMakeLists.txt not found in ${ROOT_DIR}" >&2
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required. Install dependencies with ./install_deps.sh" >&2
  exit 1
fi

cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${BUILD_DIR}" -j

ln -sf "build/usbcamv4l" "${LINK_FILE}"
ln -sf "build/usbcamctl" "${CTL_LINK_FILE}"
echo "Built: ${BUILD_DIR}/usbcamv4l"
echo "Launch with: ${LINK_FILE}"
echo "Control with: ${CTL_LINK_FILE} status"
