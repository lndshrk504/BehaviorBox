#!/usr/bin/env bash
set -euo pipefail

# Override these via environment variables if needed.
REPO_DIR="${REPO_DIR:-$HOME/Desktop/BehaviorBox}"
MATLAB_BIN="${MATLAB_BIN:-matlab}"
STARTUP_MODE="${1:-${STARTUP_MODE:-all}}"
JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-}"

launch_matlab_terminal() {
  local matlab_entrypoint="$1"
  local startup_delay_seconds="$2"
  local repo_q entry_q matlab_q run_cmd

  repo_q="$(printf %q "$REPO_DIR")"
  entry_q="$(printf %q "$matlab_entrypoint")"
  matlab_q="$(printf %q "$MATLAB_BIN")"

  run_cmd="[[ -f ~/.bashrc ]] && source ~/.bashrc; cd $repo_q;"
  if [[ -n "$JAVA_TOOL_OPTIONS" ]]; then
    run_cmd="$run_cmd export JAVA_TOOL_OPTIONS=$(printf %q "$JAVA_TOOL_OPTIONS");"
  fi
  if [[ "$startup_delay_seconds" != "0" ]]; then
    run_cmd="$run_cmd sleep $(printf %q "$startup_delay_seconds");"
  fi
  run_cmd="$run_cmd $matlab_q -nosplash -nodesktop -r $entry_q"

  # Prefer the original XFCE terminal behavior, then fall back to GNOME/default terminals.
  if command -v xfce4-terminal >/dev/null 2>&1; then
    xfce4-terminal -x bash -lc "$run_cmd; exec bash" &
  elif command -v gnome-terminal >/dev/null 2>&1; then
    gnome-terminal -- bash -lc "$run_cmd; exec bash" &
  elif command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -e bash -lc "$run_cmd; exec bash" &
  else
    bash -lc "$run_cmd" &
  fi
}

case "$STARTUP_MODE" in
  all)
    launch_matlab_terminal "BehaviorBox_App Wheel" 0
    launch_matlab_terminal "BehaviorBox_App Wheel" 20
    launch_matlab_terminal "viewDualCameras" 0
    ;;
  wheel)
    launch_matlab_terminal "BehaviorBox_App Wheel" 0
    ;;
  wheel-second)
    launch_matlab_terminal "BehaviorBox_App Wheel" 20
    ;;
  camera|camat)
    launch_matlab_terminal "viewDualCameras" 0
    ;;
  *)
    echo "Usage: $0 [all|wheel|wheel-second|camera]" >&2
    exit 1
    ;;
esac
