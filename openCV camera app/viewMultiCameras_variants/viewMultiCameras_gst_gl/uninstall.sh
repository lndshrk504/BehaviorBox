#!/usr/bin/env bash
set -euo pipefail
BIN="${HOME}/.local/bin/viewMultiCameras_gst_gl"
if [[ -f "${BIN}" ]]; then rm -f "${BIN}"; echo "Removed: ${BIN}"; else echo "Not found: ${BIN}"; fi
