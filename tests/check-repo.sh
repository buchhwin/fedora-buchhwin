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
# ⚠️ THIS RULE WAS TURNED AROUND ON 09.09.2026, and the reversal is the point.
# It used to read `test ! -e .../NetworkList.qml` — the two shell panels were
# BANNED, on the reading that a panel here would be the second network
# application "nirgends Doppelungen" forbids. That had it backwards: the
# services behind them were complete and uncalled, and the quick panel opened
# KDE's System Settings instead — a whole second interface, in another
# application, for something this shell already did.
#
# What the rule was always about is a second APPLICATION, so that is what it
# checks now: no profile may install one.
for pkg in nm-connection-editor blueman plasma-nm-openconnect network-manager-applet; do
    if grep -rqx "$pkg" sessions/*/packages/ 2>/dev/null; then
        echo "a session installs $pkg — a second network or Bluetooth application" >&2
        exit 1
    fi
done
test -e sessions/hyprland/shell/ui/quick/NetworkList.qml
test -e sessions/hyprland/shell/ui/quick/BluetoothList.qml
test ! -e sessions/hyprland/shell/services/Niri.qml
test ! -e sessions/hyprland/shell/tools/niri.qml

if grep -Rqs 'Services\.Niri\|BUCHHWIN_TOOL=niri' \
        sessions/hyprland/shell sessions/hyprland/bin sessions/hyprland/lib; then
    echo "Hyprland runtime still calls the old Niri backend" >&2
    exit 1
fi

grep -q 'rpm -q plasma-desktop' sessions/hyprland/lib/00-preflight.sh

# ⚠️⚠️ THIS RULE POINTED AT lib/30-desktop.sh AND WAS PINNING A BUG IN PLACE.
# The line it demanded was `sudo systemctl enable sddm.service || die`, sitting
# in phase two — a duplicate of what phase_greeter is for. That enable FAILS on
# every Fedora KDE machine, because sddm.service carries
# Alias=display-manager.service and systemd will not overwrite a symlink that
# already exists. So the installer died in phase two on the only kind of machine
# it installs onto, and this check would have gone red at the fix.
#
# A repository-level rule that names a FILE and a LINE is a rule about where
# code sits, not about what it does. What matters is that the login manager is
# handled, once, in the phase whose whole job that is.
grep -q 'systemctl enable sddm.service' sessions/hyprland/lib/65-greeter.sh
if grep -q 'systemctl enable sddm.service' sessions/hyprland/lib/30-desktop.sh; then
    echo "the SDDM enable is back in phase desktop — it belongs to phase greeter," >&2
    echo "and duplicating it there is what aborted the install in phase two" >&2
    exit 1
fi
grep -q 'XDG_CONFIG_HOME="$config_home"' sessions/hyprland/bin/buchhwin-hyprland-session
grep -q 'overrides.lua' sessions/hyprland/config/hypr/hyprland.lua
grep -q 'overrides.lua' sessions/hyprland/lib/60-shell.sh

# ⚠️ THE OPPOSITE OF WHAT THIS ASKED UNTIL 09.09.2026. It REQUIRED the quick
# panel to jump to `systemsettings kcm_networkmanagement` and `kcm_bluetooth`,
# as the proof that neither session ships its own network application. That
# proved the reverse: services/Net.qml and services/Bt.qml were complete and had
# zero callers, so the desktop had two interfaces for one job — and the one it
# actually opened was in another application.
#
# The panels are the shell's own now, and the jump has to be gone.
if grep -qE 'systemsettings.*kcm_(networkmanagement|bluetooth)' \
        sessions/hyprland/shell/ui/quick/QuickSettings.qml; then
    echo "the quick panel still opens KDE System Settings for network or Bluetooth" >&2
    exit 1
fi
grep -q 'NetworkList' sessions/hyprland/shell/ui/quick/QuickSettings.qml
grep -q 'BluetoothList' sessions/hyprland/shell/ui/quick/QuickSettings.qml

echo "repository checks passed"
