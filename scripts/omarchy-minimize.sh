#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-minimize"
STATE_FILE="$STATE_DIR/windows.json"

# Minimize the active window by moving it to a hidden workspace.
# Default is a normal workspace (99) to allow restoring via taskbar click.
# Override via OMARCHY_MINIMIZE_WS, e.g. "99" or "special:minimized".
TARGET_WS="${OMARCHY_MINIMIZE_WS:-99}"

if ! command -v hyprctl >/dev/null 2>&1; then
  echo "hyprctl not found" >&2
  exit 1
fi

if ! hyprctl activewindow -j >/dev/null 2>&1; then
  echo "Hyprland not available" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"

active_json="$(hyprctl activewindow -j)"
active_addr="$(printf '%s' "$active_json" | jq -r '.address')"
active_ws="$(printf '%s' "$active_json" | jq -r '.workspace.name')"
active_full="$(printf '%s' "$active_json" | jq -r '.fullscreen')"

# Minimize the active window and remember its workspace.
if [[ -f "$STATE_FILE" ]]; then
  map_json="$(cat "$STATE_FILE")"
else
  map_json='{}'
fi

map_json="$(printf '%s' "$map_json" | jq --arg addr "$active_addr" --arg ws "$active_ws" '. + {($addr): $ws}')"
printf '%s\n' "$map_json" > "$STATE_FILE"
hyprctl dispatch movetoworkspacesilent "$TARGET_WS",active
