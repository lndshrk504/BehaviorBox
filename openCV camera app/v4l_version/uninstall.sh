#!/usr/bin/env bash
set -euo pipefail
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/usbcamv4l"
if [[ -f "${BIN}" ]]; then rm -f "${BIN}"; echo "Removed: ${BIN}"; else echo "Not found: ${BIN}"; fi
