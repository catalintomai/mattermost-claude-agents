#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$HOME/.claude"
MM_DIR="$HOME/mattermost/.claude"

PROJECTS=(
  "mattermost-plugin-playbooks"
  "mattermost-pages-channel"
  "mattermost-plugin-agents"
)

usage() {
  echo "Usage: $0 [global|mattermost|project:<name>|all] [--dry-run]"
  echo ""
  echo "  global               Install global agents, skills, and docs to ~/.claude/"
  echo "  mattermost           Install Mattermost-suite agents to ~/mattermost/.claude/agents/"
  echo "  project:<name>       Install project-specific files to ~/mattermost/<name>/.claude/"
  echo "  all                  Install everything (default)"
  echo "  --dry-run            Show what would be copied without copying"
  echo ""
  echo "Available projects:"
  for p in "${PROJECTS[@]}"; do echo "  project:$p"; done
  echo ""
  echo "Examples:"
  echo "  $0 all"
  echo "  $0 global"
  echo "  $0 project:mattermost-pages-channel"
  echo "  $0 all --dry-run"
}

DRY_RUN=false
SCOPE="all"
PROJECT_NAME=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    global|mattermost|all) SCOPE="$arg" ;;
    project:*) SCOPE="project"; PROJECT_NAME="${arg#project:}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $arg"; usage; exit 1 ;;
  esac
done

copy_dir() {
  local src="$1"
  local dst="$2"
  local label="$3"
  if [ ! -d "$src" ]; then return; fi
  echo "→ $label → $dst"
  if [ "$DRY_RUN" = true ]; then
    find "$src" -maxdepth 2 \( -name "*.md" -o -name "*.sh" \) | sort | while read -r f; do
      echo "    ${f#$src/}"
    done
  else
    mkdir -p "$dst"
    cp -r "$src/." "$dst/"
  fi
}

install_project() {
  local name="$1"
  local src="$REPO_DIR/projects/$name"
  local dst="$HOME/mattermost/$name/.claude"
  echo "--- Project: $name ---"
  copy_dir "$src/agents"   "$dst/agents"   "agents"
  copy_dir "$src/skills"   "$dst/skills"   "skills"
  copy_dir "$src/docs"     "$dst/docs"     "docs"
  copy_dir "$src/commands" "$dst/commands" "commands"
  copy_dir "$src/scripts"  "$dst/scripts"  "scripts"
}

if [[ "$SCOPE" == "global" || "$SCOPE" == "all" ]]; then
  copy_dir "$REPO_DIR/global/agents" "$GLOBAL_DIR/agents" "Global agents"
  copy_dir "$REPO_DIR/global/skills" "$GLOBAL_DIR/skills" "Global skills"
  copy_dir "$REPO_DIR/global/docs"   "$GLOBAL_DIR/docs"   "Global docs"
fi

if [[ "$SCOPE" == "mattermost" || "$SCOPE" == "all" ]]; then
  copy_dir "$REPO_DIR/mattermost/agents" "$MM_DIR/agents" "Mattermost-suite agents"
fi

if [[ "$SCOPE" == "project" ]]; then
  install_project "$PROJECT_NAME"
fi

if [[ "$SCOPE" == "all" ]]; then
  for p in "${PROJECTS[@]}"; do install_project "$p"; done
fi

echo ""
if [ "$DRY_RUN" = true ]; then
  echo "Dry run complete. Re-run without --dry-run to apply."
else
  echo "Done. Restart Claude Code for changes to take effect."
fi
