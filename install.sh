#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_BINDINGS="$XDG_CONFIG_HOME/hypr/bindings.conf"
WAYBAR_CONFIG="$XDG_CONFIG_HOME/waybar/config.jsonc"
BIN_DIR="$HOME/.local/bin"
MIN_SCRIPT="$BIN_DIR/omarchy-minimize.sh"
LISTENER_SCRIPT="$BIN_DIR/omarchy-minimize-listener.sh"
HYPR_AUTOSTART="$XDG_CONFIG_HOME/hypr/autostart.conf"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SYSTEMD_UNIT="$SYSTEMD_USER_DIR/omarchy-minimize-listener.service"
TS="$(date +%Y%m%d-%H%M%S)"

if [[ ! -f "$HYPR_BINDINGS" ]]; then
  echo "Missing Hyprland bindings: $HYPR_BINDINGS" >&2
  exit 1
fi
if [[ ! -f "$WAYBAR_CONFIG" ]]; then
  echo "Missing Waybar config: $WAYBAR_CONFIG" >&2
  exit 1
fi
if [[ ! -f "$HYPR_AUTOSTART" ]]; then
  echo "Missing Hyprland autostart: $HYPR_AUTOSTART" >&2
  exit 1
fi

mkdir -p "$BIN_DIR"
install -m 755 "$ROOT_DIR/scripts/omarchy-minimize.sh" "$MIN_SCRIPT"
install -m 755 "$ROOT_DIR/scripts/omarchy-minimize-listener.sh" "$LISTENER_SCRIPT"

cp "$HYPR_BINDINGS" "$HYPR_BINDINGS.bak.$TS"
cp "$WAYBAR_CONFIG" "$WAYBAR_CONFIG.bak.$TS"
cp "$HYPR_AUTOSTART" "$HYPR_AUTOSTART.bak.$TS"

tmp_bind="$(mktemp)"
grep -v "togglespecialworkspace, minimized" "$HYPR_BINDINGS" > "$tmp_bind"
mv "$tmp_bind" "$HYPR_BINDINGS"

if ! grep -q "omarchy-minimize.sh" "$HYPR_BINDINGS"; then
  cat <<BIND >> "$HYPR_BINDINGS"

# Omarchy minimize (move active window to a hidden workspace)
bind = SUPER, B, exec, bash $MIN_SCRIPT
BIND
fi

# Prefer systemd user service for auto-start
mkdir -p "$SYSTEMD_USER_DIR"
install -m 644 "$ROOT_DIR/systemd/omarchy-minimize-listener.service" "$SYSTEMD_UNIT"
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user enable --now omarchy-minimize-listener.service >/dev/null 2>&1 || true

# Remove any previous autostart entry to avoid duplicates
tmp_auto="$(mktemp)"
grep -v "omarchy-minimize-listener.sh" "$HYPR_AUTOSTART" > "$tmp_auto"
mv "$tmp_auto" "$HYPR_AUTOSTART"

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
except Exception as e:
    print("Waybar config is not valid JSON; edit manually:", path, file=sys.stderr)
    print(str(e), file=sys.stderr)
    sys.exit(1)

mods = data.get("modules-right")
if not isinstance(mods, list):
    mods = []

present = set(mods)
ordered = ["wlr/taskbar"]
if "group/tray-expander" in present:
    ordered.append("group/tray-expander")
if "bluetooth" in present:
    ordered.append("bluetooth")
ordered += [m for m in mods if m not in set(ordered)]
data["modules-right"] = ordered

if "wlr/taskbar" not in data:
    data["wlr/taskbar"] = {
        "icon-size": 14,
        "tooltip": True,
        "on-click": "activate"
    }
else:
    # Ensure activation on click for restore behavior
    if isinstance(data["wlr/taskbar"], dict):
        data["wlr/taskbar"].setdefault("on-click", "activate")

with open(path, "w", encoding="utf-8") as f:
    f.write(json.dumps(data, indent=2, ensure_ascii=False))
    f.write("\n")
PY

echo "Installed. Restart Hyprland and Waybar (or reload configs)."
