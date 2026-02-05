#!/usr/bin/env bash
set -euo pipefail

TARGET_WS="${OMARCHY_MINIMIZE_WS:-99}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-minimize"
LOG_FILE="$STATE_DIR/listener.log"
LAST_WS_FILE="$STATE_DIR/last_workspace"

mkdir -p "$STATE_DIR"

if ! command -v socat >/dev/null 2>&1; then
  echo "socat not found" >&2
  exit 1
fi

find_socket() {
  local base="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr"
  ls -t "$base"/*/.socket2.sock 2>/dev/null | head -n 1
}

echo "--- listener start $(date) ---" >> "$LOG_FILE"
echo "target_ws=$TARGET_WS" >> "$LOG_FILE"

while true; do
  SOCK="$(find_socket)"
  if [[ -z "${SOCK:-}" ]]; then
    echo "socket not found, retrying..." >> "$LOG_FILE"
    sleep 1
    continue
  fi
  echo "sock=$SOCK" >> "$LOG_FILE"

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
      # Track last non-target workspace from active window too (more reliable than workspace events)
      if [[ -n "$ws_name" && "$ws_name" != "$TARGET_WS" ]]; then
        printf '%s' "$ws_name" > "$LAST_WS_FILE"
        echo "last_ws=$ws_name" >> "$LOG_FILE"
      fi
      if [[ -n "$addr" && "$ws_name" == "$TARGET_WS" ]]; then
        if [[ -f "$LAST_WS_FILE" ]]; then
          target_ws="$(cat "$LAST_WS_FILE")"
        else
          target_ws=""
        fi
        if [[ -z "$target_ws" || "$target_ws" == "$TARGET_WS" ]]; then
          # Fallback to current workspace name if available
          target_ws="$cur_ws"
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

  echo "socket closed, reconnecting..." >> "$LOG_FILE"
  sleep 1
done
