#!/usr/bin/env bash
set -euo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/viewMultiCameras_v4l2_dmabuf_egl"
if [[ -f "${BIN}" ]]; then rm -f "${BIN}"; echo "Removed: ${BIN}"; else echo "Not found: ${BIN}"; fi
