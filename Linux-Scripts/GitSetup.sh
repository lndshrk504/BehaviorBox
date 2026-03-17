#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: GitSetup.sh --name "Your Name" --email "you@example.com" [options]

Options:
  --name <name>               Git user.name to set
  --email <email>             Git user.email to set
  --editor <editor>           Optional: set Git core.editor
  --default-branch <branch>   Optional: set Git init.defaultBranch
  --pull-rebase <true|false>  Optional: set Git pull.rebase
  --color-ui <value>          Optional: set Git color.ui
  -h, --help                  Show this help
EOF
}

require_value() {
  if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
    echo "Error: $1 requires a value." >&2
    usage >&2
    exit 1
  fi
}

NAME=""
EMAIL=""
EDITOR_NAME=""
DEFAULT_BRANCH=""
PULL_REBASE=""
COLOR_UI=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      require_value "$@"
      NAME="$2"
      shift 2
      ;;
    --email)
      require_value "$@"
      EMAIL="$2"
      shift 2
      ;;
    --editor)
      require_value "$@"
      EDITOR_NAME="$2"
      shift 2
      ;;
    --default-branch)
      require_value "$@"
      DEFAULT_BRANCH="$2"
      shift 2
      ;;
    --pull-rebase)
      require_value "$@"
      PULL_REBASE="$2"
      shift 2
      ;;
    --color-ui)
      require_value "$@"
      COLOR_UI="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$NAME" || -z "$EMAIL" ]]; then
  echo "Error: --name and --email are required." >&2
  usage >&2
  exit 1
fi

if [[ "$PULL_REBASE" != "true" && "$PULL_REBASE" != "false" ]]; then
  echo "Error: --pull-rebase must be true or false." >&2
  exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
  echo "Please run this script as a normal user (do NOT use sudo ./GitSetup.sh)." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but not installed." >&2
  exit 1
fi

git config --global user.name "$NAME"
git config --global user.email "$EMAIL"

if [[ -n "$DEFAULT_BRANCH" ]]; then
  git config --global init.defaultBranch "$DEFAULT_BRANCH"
fi

if [[ -n "$EDITOR_NAME" ]]; then
  git config --global core.editor "$EDITOR_NAME"
fi

if [[ -n "$PULL_REBASE" ]]; then
  git config --global pull.rebase "$PULL_REBASE"
fi

if [[ -n "$COLOR_UI" ]]; then
  git config --global color.ui "$COLOR_UI"
fi

echo "Updated global Git configuration."
