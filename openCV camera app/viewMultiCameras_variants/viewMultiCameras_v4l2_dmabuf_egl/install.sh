#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
PREFIX="${HOME}/.local"
BIN_DIR="${PREFIX}/bin"

mkdir -p "${BUILD_DIR}"
cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}"
cmake --build "${BUILD_DIR}" -j

mkdir -p "${BIN_DIR}"
install -m 0755 "${BUILD_DIR}/viewMultiCameras_v4l2_dmabuf_egl" "${BIN_DIR}/viewMultiCameras_v4l2_dmabuf_egl"
echo "Installed: ${BIN_DIR}/viewMultiCameras_v4l2_dmabuf_egl"
