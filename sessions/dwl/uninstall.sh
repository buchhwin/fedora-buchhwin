#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="$HOME/.local/bin"

rm -rf "$CONFIG_HOME/quickshell/buchhwin"
rm -rf "$CONFIG_HOME/buchhwin-dwl"
rm -f "$CONFIG_HOME/xdg-desktop-portal/buchhwin-portals.conf"
rm -f "$CONFIG_HOME/systemd/user/buchhwin-session.target"
rm -rf "$DATA_HOME/buchhwin-dwl"

# Derive the helper list from the repository so a newly added helper is never
# left behind in ~/.local/bin.
for helper in "$ROOT"/scripts/buchhwin-*; do
  [[ -e "$helper" ]] || continue
  rm -f "$BIN_HOME/$(basename "$helper")"
done

sudo rm -f /usr/local/bin/dwl-buchhwin
sudo rm -f /usr/local/bin/buchhwin-session
sudo rm -f /usr/share/wayland-sessions/buchhwin.desktop

systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true

echo "buchhwin-dwl removed."
echo "Installed system packages and the MesloLGS Nerd Font were intentionally left in place."
echo "Backups, if any, remain under ~/.local/state/buchhwin-dwl/backups/."
