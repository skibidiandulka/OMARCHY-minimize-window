# Omarchy Minimize (Hyprland + Waybar)

Adds a simple "minimize" flow for Omarchy on Hyprland:
- `Super + B` minimizes the active window by moving it to workspace `99`.
- Restore by clicking the app icon in the taskbar.

To make the restore work reliably, a small background listener is installed. It watches for focus events and, when you click an app icon in the taskbar, it moves that window from workspace `99` to your current workspace.
- A taskbar is inserted between the clock and Bluetooth in Waybar so you can see app icons.

This is a Hyprland-style workaround (there is no native minimize). It is reliable and reversible.

## Files
- scripts/omarchy-minimize.sh – moves the active window to workspace 99 and stores its original workspace
- scripts/omarchy-minimize-listener.sh – restores on taskbar click
- systemd/omarchy-minimize-listener.service – user service for autostart
- install.sh – installs scripts + adds Hyprland bind + adds Waybar taskbar + enables service
- uninstall.sh – removes binds + taskbar and deletes scripts + disables service

## Install
bash
./install.sh

Then restart Hyprland and Waybar (or reload their configs).

## Service
The listener runs as a systemd user service:
bash
systemctl --user status omarchy-minimize-listener.service


## Uninstall
bash
./uninstall.sh

## Notes / Caveats
- The installer rewrites ~/.config/waybar/config.jsonc using JSON parsing. If you have comments or non‑JSON syntax there, the installer will stop and ask you to edit manually.
- To place the taskbar between the clock and Bluetooth, the installer reorders modules-right so the order becomes: wlr/taskbar, group/tray-expander, bluetooth, then the rest.
- The restore listener depends on socat and jq.
- The taskbar click uses on-click: activate in wlr/taskbar.

## Manual Waybar edit (if needed)
If the installer can’t parse your config, add this:

1) Insert "wlr/taskbar" as the first entry in modules-right.
2) Add this block anywhere at top level:
json
"wlr/taskbar": {
  "icon-size": 14,
  "tooltip": true
}

"I have created all of this- including the README.md with codex ai on the fifth of February 2026." 
