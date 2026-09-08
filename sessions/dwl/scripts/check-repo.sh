#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

printf 'Checking shell scripts...\n'
while IFS= read -r -d '' file; do
  if head -n 1 "$file" | grep -qE '^#!.*(ba)?sh'; then
    bash -n "$file"
  fi
done < <(find . -type f \( -name '*.sh' -o -path './scripts/buchhwin-*' -o -path './bin/*' \) -print0)

grep -q 'exec bash "$ROOT/install-fedora.sh"' update.sh || {
  echo "Updater must invoke the Fedora installer through Bash." >&2
  exit 1
}

printf 'Checking Python...\n'
python3 -m py_compile scripts/session.py scripts/display_profile.py scripts/patch-dwl-config.py \
  scripts/check-qml.py scripts/buchhwin-wallpaper scripts/patch-dwl-source.py

printf 'Checking QML structure and fonts...\n'
python3 scripts/check-qml.py

grep -q 'MesloLGS Nerd Font Mono' config/quickshell/buchhwin/Theme.qml || {
  echo "Quickshell theme must use the bundled Nerd Font family." >&2
  exit 1
}
if grep -Rqn '󰣇' config/quickshell/buchhwin; then
  echo "Arch logo must not appear in the Fedora shell." >&2
  exit 1
fi
grep -q '' config/quickshell/buchhwin/Bar.qml || {
  echo "Fedora logo is missing from the bar." >&2
  exit 1
}

# One motion vocabulary for the whole shell. Panels referencing durations or
# curves that are not defined centrally is how timing drifts apart.
for token in durationFast durationMedium durationSlow easingEnter easingExit lift slide; do
  grep -q "property .*$token" config/quickshell/buchhwin/Theme.qml || {
    echo "Theme.qml is missing the motion token: $token" >&2
    exit 1
  }
done
if grep -rn 'duration: [0-9]' config/quickshell/buchhwin/*.qml; then
  echo "Animation durations must come from Theme.qml, not be written inline." >&2
  exit 1
fi

# A panel whose visibility is tied directly to `opened` cannot animate closing:
# the window disappears before the fade-out has a chance to run.
for panel in Launcher ControlCenter NotificationCenter PowerMenu Keybinds \
             ClipboardHistory Settings NetworkPanel BluetoothPanel AudioPanel; do
  grep -q 'visible: opened || reveal' "config/quickshell/buchhwin/$panel.qml" || {
    echo "$panel.qml must keep its window mapped until the closing animation ends." >&2
    exit 1
  }
done

printf 'Checking required QML components...\n'
for file in shell.qml Theme.qml AudioState.qml Bar.qml Launcher.qml ControlCenter.qml \
            NotificationService.qml NotificationCenter.qml NotificationPopups.qml \
            PowerMenu.qml Keybinds.qml ClipboardHistory.qml Settings.qml \
            NetworkPanel.qml BluetoothPanel.qml AudioPanel.qml AppearanceStyleSettings.qml \
            ConnectionsSettings.qml SystemTray.qml PowerSettings.qml; do
  [[ -s "config/quickshell/buchhwin/$file" ]] || { echo "Missing QML file: $file" >&2; exit 1; }
done
for key in font theme accent background bar text barPosition; do
  grep -q "\"$key\"" scripts/appearancectl.py || {
    echo "Appearance backend is missing the dwl-only setting: $key" >&2
    exit 1
  }
done

printf 'Checking the isolated Fedora installer...\n'
for dependency in quickshell wlroots-devel xorg-x11-server-Xwayland scenefx \
                  xdg-desktop-portal-wlr xdg-desktop-portal-kde wdisplays cliphist polkit-kde \
                  plasma-desktop dolphin okular gwenview kate vlc merkuro \
                  akonadi-calendar-tools kaccounts-integration-qt6 kaccounts-providers \
                  kwalletmanager plasma-systemsettings zenity zsh flatpak \
                  fastfetch meson ninja-build libdrm-devel pixman-devel lcms2-devel; do
  grep -qw "$dependency" install-fedora.sh || {
    echo "Fedora installer is missing: $dependency" >&2
    exit 1
  }
done
grep -q 'wallpaperChooser' config/quickshell/buchhwin/Settings.qml \
  && grep -q '"zenity", "--file-selection"' config/quickshell/buchhwin/Settings.qml || {
  echo "Wallpaper chooser must work independently of the desktop portal." >&2
  exit 1
}
for token in folderChooser set-folder set-interval WALLPAPER_INTERVAL 'def watch' 'fcntl.LOCK_NB'; do
  grep -Rq "$token" config/quickshell/buchhwin/Settings.qml config/settings.env scripts/buchhwin-wallpaper || {
    echo "Wallpaper slideshow is missing required behavior: $token" >&2
    exit 1
  }
done
grep -q 'buchhwin-session.target' scripts/session.py \
  && grep -q 'Requires=graphical-session.target' config/systemd/user/buchhwin-session.target || {
  echo "The dwl session must pull in graphical-session.target for portals." >&2
  exit 1
}
grep -q 'getent passwd' install-fedora.sh || {
  echo "Fedora installer must resolve the real home outside IDE sandboxes." >&2
  exit 1
}
grep -q -- '--prepare-only' install-fedora.sh || {
  echo "Fedora installer must support isolated, unprivileged preparation." >&2
  exit 1
}
grep -q 'patch-dwl-source.py' scripts/build-dwl-fedora.sh || {
  echo "Fedora build must apply the isolated source compatibility patch." >&2
  exit 1
}
! grep -Fq 'wlr_scene_blur_set_transparency_mask_source(c->blur, buffer)' scripts/patch-dwl-source.py || {
  echo "SceneFX terminal blur must not use the client buffer as an opacity mask" >&2
  exit 1
}
for commit in d41ecb745cc94fbb48e93af01f5fd5d0b2488945 \
              3606f3d3bb4bb97e13228adc5190bf57fc687c88 \
              dc517160a550da7da1b8e0f14cff624f56e94203; do
  grep -q "$commit" scripts/build-dwl-fedora.sh || {
    echo "Fedora build source is not reproducibly pinned: $commit" >&2
    exit 1
  }
done
grep -q "tar --exclude='./.git'.*\$SOURCE" scripts/build-dwl-fedora.sh || {
  echo "Fedora build must compile a clean staging copy without .git." >&2
  exit 1
}
if grep -Eq '(rm|mv|cp|install).*(quickshell/dwl|/usr/local/bin/dwl([[:space:]";]|$))' install-fedora.sh; then
  echo "Fedora installer must not mutate the existing dwl/Quickshell setup." >&2
  exit 1
fi
grep -q 'XKB_KEY_c.*codecmd' scripts/patch-dwl-config.py || {
  echo "Super+C must launch Visual Studio Code." >&2
  exit 1
}
grep -q 'text: root.query' config/quickshell/buchhwin/Launcher.qml || {
  echo "Launcher text must reset together with its query." >&2
  exit 1
}
for file in AudioState.qml Bar.qml ControlCenter.qml Settings.qml; do
  grep -q '^import Quickshell.Io' "config/quickshell/buchhwin/$file" || {
    echo "$file uses Process/StdioCollector and must import Quickshell.Io." >&2
    exit 1
  }
done
grep -q 'id: masterVolume' config/quickshell/buchhwin/ControlCenter.qml \
  && grep -q 'id: brightnessSlider' config/quickshell/buchhwin/ControlCenter.qml \
  && grep -q 'id: deviceVolume' config/quickshell/buchhwin/AudioPanel.qml || {
  echo "Audio and brightness controls must use sliders."
  exit 1
}
grep -q 'MouseArea' config/quickshell/buchhwin/ValueSlider.qml \
  && grep -q 'preventStealing: true' config/quickshell/buchhwin/ValueSlider.qml \
  && grep -q 'TextInput' config/quickshell/buchhwin/ValueSlider.qml || {
  echo "ValueSlider must support touchpad click/drag and numeric input." >&2
  exit 1
}
grep -q 'UPowerDeviceState.Charging' config/quickshell/buchhwin/Bar.qml || {
  echo "Bar must visibly distinguish a charging laptop battery." >&2
  exit 1
}
grep -A5 'visible: panel.player' config/quickshell/buchhwin/Bar.qml | grep -q 'Layout.preferredWidth' || {
  echo "Media widget must reserve its width inside the bar layout." >&2
  exit 1
}
grep -q 'implicitWidth: batMouse.containsMouse' config/quickshell/buchhwin/Bar.qml \
  && grep -q 'Math.round(UPower.displayDevice.percentage \* 100)' config/quickshell/buchhwin/Bar.qml || {
  echo "Battery hover must expose the current percentage." >&2
  exit 1
}
for helper in buchhwin-network buchhwin-bluetooth buchhwin-sound; do
  grep -q "Quickshell.execDetached(\[\"$helper\"\])" config/quickshell/buchhwin/Bar.qml || {
    echo "Bar must open the dedicated $helper panel." >&2
    exit 1
  }
done
grep -q 'settingsMouse' config/quickshell/buchhwin/Bar.qml
grep -A8 'id: settingsMouse' config/quickshell/buchhwin/Bar.qml | grep -q 'buchhwin-settings' || {
  echo "The bar settings button must open full settings." >&2
  exit 1
}
grep -A2 'id: batMouse' config/quickshell/buchhwin/Bar.qml | grep -q 'buchhwin-control-center' || {
  echo "The battery button must open the Control Center." >&2
  exit 1
}
grep -q '"All settings", \["buchhwin-settings"\]' config/quickshell/buchhwin/ControlCenter.qml || {
  echo "Control Center must provide an entry to full settings." >&2
  exit 1
}

printf 'Checking shell references...\n'
for component in Bar Launcher ControlCenter NotificationCenter NotificationPopups \
                 PowerMenu Keybinds ClipboardHistory Settings \
                 NetworkPanel BluetoothPanel AudioPanel; do
  grep -q "$component" config/quickshell/buchhwin/shell.qml || { echo "shell.qml does not reference $component" >&2; exit 1; }
done

printf 'Checking that no Arch-only assumptions remain...\n'
for pattern in pacman makepkg aur.archlinux.org wlroots0.19 libreoffice-fresh ttf-meslo-nerd; do
  if grep -rniq --exclude-dir='.git' --exclude='check-repo.sh' --exclude='CHANGELOG.md' "$pattern" .; then
    echo "Arch-only reference still present: $pattern" >&2
    grep -rni --exclude-dir='.git' --exclude='check-repo.sh' --exclude='CHANGELOG.md' "$pattern" . >&2
    exit 1
  fi
done

grep -q 'nerd-fonts/releases' install-fedora.sh || {
  echo "Installer must fetch the Nerd Font; the bar is glyph-based." >&2
  exit 1
}
grep -q 'flatpak install --user -y flathub org.onlyoffice.desktopeditors' install-fedora.sh || {
  echo "Installer must provision OnlyOffice as a user-local Flatpak." >&2
  exit 1
}
if grep -Eq 'flatpak install.*(com.brave.Browser|com.visualstudio.code)' install-fedora.sh; then
  echo "Installer must not install Brave or Visual Studio Code as Flatpaks." >&2
  exit 1
fi
if grep -Eq '^[[:space:]]*xdg-(mime[[:space:]]+default|settings[[:space:]]+set)' install-fedora.sh; then
  echo "Installer must preserve Plasma's default applications." >&2
  exit 1
fi
for file in scripts/session.py scripts/buchhwin-doctor; do
  grep -q '/usr/libexec/kf6/polkit-kde-authentication-agent-1' "$file" || {
    echo "$file must support Fedora KDE 6's polkit agent path." >&2
    exit 1
  }
done
grep -q '^BROWSER=brave$' config/settings.env || {
  echo "Brave must remain the default buchhwin browser." >&2
  exit 1
}
grep -q 'MesloLGS Nerd Font Mono' config/alacritty.toml || {
  echo "Alacritty must use the bundled monospaced Nerd Font." >&2
  exit 1
}
grep -q '^fastfetch()' config/zshrc && grep -q '^alias ff=fastfetch' config/zshrc || {
  echo "The dwl Zsh profile must apply its Fastfetch config to fastfetch and ff." >&2
  exit 1
}
grep -q 'display_profile.py' install-fedora.sh || {
  echo "Installer must install the persistent display profile helper." >&2
  exit 1
}
grep -q 'XDG_CONFIG_HOME' bin/buchhwin-session || {
  echo "Session launcher must honor XDG_CONFIG_HOME." >&2
  exit 1
}
grep -q 'GTK_THEME=Breeze-Dark' bin/buchhwin-session || {
  echo "The isolated dwl session must request the KDE Breeze GTK theme." >&2
  exit 1
}

printf 'Checking that the shell owns its own settings UI...\n'
# The point of the native panels is that no external configuration program is
# needed; a reintroduced launcher call or package would quietly undo that.
# Comments are allowed to name them ("replacing pavucontrol"), so whole-line
# comments are stripped before matching.
for program in blueman-manager nm-connection-editor pavucontrol; do
  hits="$(grep -rn --exclude='check-repo.sh' "$program" config/quickshell/ scripts/ install-fedora.sh 2>/dev/null \
          | sed 's/^\([^:]*:[0-9]*\):[[:space:]]*/\1|/' \
          | grep -v '|//' | grep -v '|#' || true)"
  if [[ -n "$hits" ]]; then
    echo "External configuration program reintroduced: $program" >&2
    echo "$hits" >&2
    exit 1
  fi
done
grep -q 'pulseaudio-utils' install-fedora.sh || {
  echo "buchhwin-audioctl needs pactl from pulseaudio-utils." >&2
  exit 1
}

printf 'Checking branding...\n'
if grep -Rni --exclude='NOTICE.md' --exclude='README.md' --exclude='check-repo.sh' --exclude-dir='.git' -E 'ChrisTitusTech|dwm-titus' .; then
  echo "Unexpected upstream inspiration branding outside README/NOTICE." >&2
  exit 1
fi

printf 'Checking dwl patcher on a v0.8-shaped fixture...\n'
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/config.h" <<'FIXTURE'
static const unsigned int borderpx = 1; /* border pixel of windows */
static const float bordercolor[] = COLOR(0x444444ff);
static const float focuscolor[] = COLOR(0x005577ff);
static const float urgentcolor[] = COLOR(0xff0000ff);
static const float fullscreen_bg[] = {0.0f, 0.0f, 0.0f, 1.0f};
static const Rule rules[] = { { "Gimp_EXAMPLE", NULL, 0, 1, -1 }, };
static const Layout layouts[] = { { "[]=", tile }, { "><>", NULL }, { "[M]", monocle }, };
static const MonitorRule monrules[] = {
    { NULL, 0.55f, 1, 1, &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, -1, -1 },
};
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;
static const struct xkb_rule_names xkb_rules = {
    .options = NULL,
};
#define MODKEY WLR_MODIFIER_ALT
#define TAGKEYS(KEY,SKEY,TAG) \
    { MODKEY, KEY, view, {.ui = 1 << TAG} }, \
    { MODKEY|WLR_MODIFIER_CTRL, KEY, toggleview, {.ui = 1 << TAG} }, \
    { MODKEY|WLR_MODIFIER_SHIFT, SKEY, tag, {.ui = 1 << TAG} }, \
    { MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT,SKEY,toggletag, {.ui = 1 << TAG} }
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }
static const char *termcmd[] = { "foot", NULL };
static const char *menucmd[] = { "wmenu-run", NULL };
static const Key keys[] = {
    { MODKEY, XKB_KEY_p, spawn, {.v = menucmd} },
    { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Return, spawn, {.v = termcmd} },
};
FIXTURE
BUCHHWIN_KEYBOARD_LAYOUT=de python3 scripts/patch-dwl-config.py "$tmp/config.h" >/dev/null
grep -q 'WLR_MODIFIER_LOGO' "$tmp/config.h"
grep -q 'accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT' "$tmp/config.h"
grep -q 'buchhwin-launcher' "$tmp/config.h"
grep -q 'buchhwin-terminal' "$tmp/config.h"
grep -q 'dolphin' "$tmp/config.h"
grep -q 'XKB_KEY_b' "$tmp/config.h"
grep -q 'XKB_KEY_Left.*setmfact' "$tmp/config.h"
grep -q 'XKB_KEY_Right.*setmfact' "$tmp/config.h"
if grep -Eq 'XKB_KEY_(h|L),.*setmfact' "$tmp/config.h"; then
  echo "Master resizing must only use Super+Left/Right." >&2
  exit 1
fi
if grep -Eq '"(DP|HDMI|eDP)-[0-9]+' "$tmp/config.h"; then
  echo "Generated dwl config must not contain machine-specific output names." >&2
  exit 1
fi
grep -q 'display-profile.json' "$tmp/config.h"
grep -q 'filescmd' "$tmp/config.h"
grep -q 'clipboardcmd' "$tmp/config.h"
grep -q 'settingscmd' "$tmp/config.h"
grep -q 'XKB_KEY_F.*togglefullscreen' "$tmp/config.h"

[[ -s assets/wallpapers/buchhwin-default.png ]] || {
  echo "Default wallpaper is missing." >&2
  exit 1
}
grep -q 'buchhwin-default.png' scripts/session.py || {
  echo "Session must load the default wallpaper." >&2
  exit 1
}

# A Quickshell crash must not leave a usable but invisible desktop.
grep -q 'def supervise' scripts/session.py || {
  echo "session.py must supervise Quickshell so a crash does not blank the shell." >&2
  exit 1
}
grep -q 'polkit-kde-authentication-agent-1' scripts/session.py || {
  echo "session.py must know the KDE polkit agent path." >&2
  exit 1
}

echo "All repository checks passed."
