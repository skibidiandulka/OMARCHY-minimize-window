#!/usr/bin/env bash
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_BINDINGS="$XDG_CONFIG_HOME/hypr/bindings.conf"
WAYBAR_CONFIG="$XDG_CONFIG_HOME/waybar/config.jsonc"
MIN_SCRIPT="$HOME/.local/bin/omarchy-minimize.sh"
LISTENER_SCRIPT="$HOME/.local/bin/omarchy-minimize-listener.sh"
HYPR_AUTOSTART="$XDG_CONFIG_HOME/hypr/autostart.conf"
SYSTEMD_UNIT="$HOME/.config/systemd/user/omarchy-minimize-listener.service"

if [[ -f "$HYPR_BINDINGS" ]]; then
  # Remove the two binds we added.
  tmp="$(mktemp)"
  grep -v "omarchy-minimize.sh" "$HYPR_BINDINGS" | \
    grep -v "togglespecialworkspace, minimized" > "$tmp"
  mv "$tmp" "$HYPR_BINDINGS"
fi

if [[ -f "$WAYBAR_CONFIG" ]]; then
  export WAYBAR_CONFIG
  python - <<'PY'
import json
import os
import sys

path = os.environ["WAYBAR_CONFIG"]
with open(path, "r", encoding="utf-8") as f:
    raw = f.read()

try:
    data = json.loads(raw)
except Exception:
    print("Waybar config is not valid JSON; edit manually:", path, file=sys.stderr)
    sys.exit(1)

mods = data.get("modules-right")
if isinstance(mods, list):
    data["modules-right"] = [m for m in mods if m != "wlr/taskbar"]

data.pop("wlr/taskbar", None)

with open(path, "w", encoding="utf-8") as f:
    f.write(json.dumps(data, indent=2, ensure_ascii=False))
    f.write("\n")
PY
fi

if [[ -f "$MIN_SCRIPT" ]]; then
  rm -f "$MIN_SCRIPT"
fi
if [[ -f "$LISTENER_SCRIPT" ]]; then
  rm -f "$LISTENER_SCRIPT"
fi

if [[ -f "$HYPR_AUTOSTART" ]]; then
  tmp="$(mktemp)"
  grep -v "omarchy-minimize-listener.sh" "$HYPR_AUTOSTART" > "$tmp"
  mv "$tmp" "$HYPR_AUTOSTART"
fi

if [[ -f "$SYSTEMD_UNIT" ]]; then
  systemctl --user disable --now omarchy-minimize-listener.service >/dev/null 2>&1 || true
  rm -f "$SYSTEMD_UNIT"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

echo "Uninstalled. Restart Hyprland and Waybar (or reload configs)."
