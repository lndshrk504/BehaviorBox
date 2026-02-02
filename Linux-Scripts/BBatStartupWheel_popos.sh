#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Override these via environment variables if needed.
REPO_DIR="${REPO_DIR:-$SCRIPT_DIR}"
MATLAB_ENTRYPOINT="${MATLAB_ENTRYPOINT:-BehaviorBox_App Wheel}"
STARTUP_DELAY_SECONDS="${STARTUP_DELAY_SECONDS:-0}"
JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Djogl.disable.openglarbcontext=1}"
MATLAB_BIN="${MATLAB_BIN:-matlab}"

if [[ "$STARTUP_DELAY_SECONDS" != "0" ]]; then
  sleep "$STARTUP_DELAY_SECONDS"
fi

repo_q="$(printf %q "$REPO_DIR")"
java_q="$(printf %q "$JAVA_TOOL_OPTIONS")"
entry_q="$(printf %q "$MATLAB_ENTRYPOINT")"
matlab_q="$(printf %q "$MATLAB_BIN")"
run_cmd="[[ -f ~/.bashrc ]] && source ~/.bashrc; cd $repo_q; export JAVA_TOOL_OPTIONS=$java_q; $matlab_q -nosplash -nodesktop -r $entry_q"

# Pop!_OS defaults to GNOME; prefer gnome-terminal, but fall back gracefully.
if command -v gnome-terminal >/dev/null 2>&1; then
  gnome-terminal -- bash -lc "$run_cmd; exec bash"
elif command -v x-terminal-emulator >/dev/null 2>&1; then
  x-terminal-emulator -e bash -lc "$run_cmd; exec bash"
else
  bash -lc "$run_cmd"
fi
