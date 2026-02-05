#!/usr/bin/env bash
set -euo pipefail

TARGET_WS="${OMARCHY_MINIMIZE_WS:-99}"
SOCK="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-minimize"
LOG_FILE="$STATE_DIR/listener.log"
MAP_FILE="$STATE_DIR/windows.json"
LAST_WS_FILE="$STATE_DIR/last_workspace"

mkdir -p "$STATE_DIR"

if ! command -v socat >/dev/null 2>&1; then
  echo "socat not found" >&2
  exit 1
fi

if [[ ! -S "$SOCK" ]]; then
  echo "Hyprland event socket not found: $SOCK" >&2
  exit 1
fi

echo "--- listener start $(date) ---" >> "$LOG_FILE"
echo "sock=$SOCK target_ws=$TARGET_WS" >> "$LOG_FILE"

socat -u "UNIX-CONNECT:$SOCK" - | while read -r line; do
  echo "raw: $line" >> "$LOG_FILE"
  case "$line" in
    workspace*|activeworkspace*)
      ws="${line#*>>}"
      ws="${ws%%,*}"
      if [[ -n "$ws" && "$ws" != "$TARGET_WS" ]]; then
        printf '%s' "$ws" > "$LAST_WS_FILE"
        echo "last_ws=$ws" >> "$LOG_FILE"
      fi
      ;;
    activewindow*|activewindowv2*)
      echo "event: $line" >> "$LOG_FILE"
      aw_json="$(hyprctl activewindow -j 2>/dev/null || true)"
      ws_name="$(printf '%s' "$aw_json" | jq -r '.workspace.name // empty')"
      addr="$(printf '%s' "$aw_json" | jq -r '.address // empty')"
      cur_ws="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.name // empty')"
      echo "active addr=$addr ws=$ws_name cur_ws=$cur_ws" >> "$LOG_FILE"
      if [[ -n "$addr" && "$ws_name" == "$TARGET_WS" ]]; then
        if [[ -f "$LAST_WS_FILE" ]]; then
          target_ws="$(cat "$LAST_WS_FILE")"
        else
          target_ws=""
        fi
        if [[ -n "$target_ws" ]]; then
          hyprctl dispatch movetoworkspacesilent "$target_ws",address:"$addr" >/dev/null 2>&1 || true
          hyprctl dispatch workspace "$target_ws" >/dev/null 2>&1 || true
          echo "moved $addr to $target_ws" >> "$LOG_FILE"
        fi
      fi
      ;;
  esac
done
