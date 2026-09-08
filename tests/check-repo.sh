#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

bash -n install.sh
bash -n sessions/dwl/install-fedora.sh
bash -n sessions/hyprland/install-hyprland.sh
for file in sessions/hyprland/lib/*.sh; do bash -n "$file"; done

grep -q -- '--session dwl|hyprland|both' install.sh
grep -q 'sessions/dwl/install-fedora.sh' install.sh
grep -q 'sessions/hyprland/install-hyprland.sh' install.sh

packages="$({ grep -hEv '^[[:space:]]*(#|$)' sessions/hyprland/packages/dnf-*.txt || true; } \
    | sed 's/[[:space:]]*#.*//')"
if grep -Eiq '^(greetd|niri|nautilus|loupe|gnome-(shell|session|control-center|keyring))$' <<<"$packages"; then
    echo "Hyprland profile still installs a forbidden Niri/GNOME/greeter package" >&2
    exit 1
fi

grep -q '^hyprland$' <<<"$packages"
grep -q '^xdg-desktop-portal-kde$' <<<"$packages"
grep -q '^plasma-nm$' <<<"$packages"
grep -q '^bluedevil$' <<<"$packages"

test -f sessions/hyprland/session/buchhwin-hyprland.desktop
test -f sessions/dwl/session/buchhwin.desktop
test ! -e sessions/hyprland/shell/ui/greeter/GreeterScreen.qml
test ! -e sessions/hyprland/shell/ui/quick/NetworkList.qml
test ! -e sessions/hyprland/shell/ui/quick/BluetoothList.qml

grep -q 'systemsettings.*kcm_networkmanagement' \
    sessions/hyprland/shell/ui/quick/QuickSettings.qml
grep -q 'systemsettings.*kcm_bluetooth' \
    sessions/hyprland/shell/ui/quick/QuickSettings.qml

echo "repository checks passed"
