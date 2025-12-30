#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
START_SCRIPT="${START_SCRIPT:-$SCRIPT_DIR/BBatStartup_popos.sh}"

if [[ ! -f "$START_SCRIPT" ]]; then
  echo "Startup script not found: $START_SCRIPT" >&2
  exit 1
fi

chmod +x "$START_SCRIPT" || true

mkdir -p "$HOME/.config/autostart"

escape_for_single_quotes() {
  # Replaces: '  ->  '"'"'
  printf "%s" "$1" | sed "s/'/'\"'\"'/g"
}

start_script_escaped="$(escape_for_single_quotes "$START_SCRIPT")"

cat >"$HOME/.config/autostart/behaviorbox.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=BehaviorBox
Comment=Start BehaviorBox on login
Exec=/usr/bin/env bash -lc '$start_script_escaped'
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

echo "Installed: $HOME/.config/autostart/behaviorbox.desktop"
