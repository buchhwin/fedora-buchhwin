#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
[[ -n "$USER_HOME" && -d "$USER_HOME" ]] || { echo "Could not resolve the real user home." >&2; exit 1; }
# IDE/Flatpak terminals can inject sandbox-specific HOME/XDG paths. Installation
# always targets the real login user's dedicated paths instead.
HOME="$USER_HOME"
export HOME
unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME
CONFIG_HOME="$USER_HOME/.config"
STATE_HOME="$USER_HOME/.local/state"
DATA_HOME="$USER_HOME/.local/share"
BIN_HOME="$USER_HOME/.local/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$STATE_HOME/buchhwin-dwl/backups/$STAMP"
DRY_RUN=0
PREPARE_ONLY=0
case "${1:-}" in
  --dry-run) DRY_RUN=1 ;;
  --prepare-only) PREPARE_ONLY=1 ;;
  "") ;;
  *) echo "Usage: $0 [--dry-run|--prepare-only]" >&2; exit 2 ;;
esac

(( EUID != 0 )) || { echo "Run as your normal user, not with sudo." >&2; exit 1; }
packages=(
  git python3 procps-ng dbus-tools curl unzip fontconfig zsh flatpak fastfetch
  zsh-autosuggestions zsh-syntax-highlighting
  quickshell kitty alacritty xorg-x11-server-Xwayland NetworkManager bluez
  pipewire wireplumber pulseaudio-utils playerctl brightnessctl upower
  swaybg swaylock swayidle gammastep grim slurp swappy wl-clipboard wlr-randr wdisplays
  cliphist udiskie udisks2 gvfs gvfs-mtp libnotify
  xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-kde
  plasma-desktop plasma-workspace sddm qt6-qtwayland breeze-gtk
  dolphin okular gwenview kate kcalc vlc merkuro akonadi akonadi-server
  kdepim-runtime akonadi-calendar-tools kaccounts-integration-qt6 kaccounts-providers
  plasma-systemsettings
  signon-kwallet-extension kwalletmanager polkit-kde kio-fuse kio-gdrive
  plasma-nm bluedevil plasma-pa powerdevil zenity
  geoclue2 geoclue2-demos
  gcc make meson ninja-build pkgconf-pkg-config wlroots-devel wayland-devel
  wayland-protocols-devel libinput-devel libxkbcommon-devel
  libxcb-devel xcb-util-wm-devel libdrm-devel pixman-devel
  mesa-libEGL-devel mesa-libgbm-devel libglvnd-devel lcms2-devel
)

echo "==> Fedora packages"
printf '  %s\n' "${packages[@]}"
echo "==> Isolated destinations"
printf '  %s\n' "$CONFIG_HOME/quickshell/buchhwin" "$CONFIG_HOME/buchhwin-dwl" \
  "$BIN_HOME/buchhwin-*" "/usr/local/bin/dwl-buchhwin" \
  "/usr/share/wayland-sessions/buchhwin.desktop"
if (( DRY_RUN )); then
  echo "Dry run complete; nothing changed."
  exit 0
fi

command -v dnf >/dev/null 2>&1 || { echo "This installer requires Fedora and dnf." >&2; exit 1; }
[[ -r /etc/os-release ]] && . /etc/os-release
[[ "${ID:-}" == "fedora" ]] || { echo "This installer supports Fedora only." >&2; exit 1; }
[[ "${VERSION_ID:-}" == "44" ]] || echo "WARNING: designed for Fedora 44, found ${VERSION_ID:-unknown}." >&2

if (( ! PREPARE_ONLY )); then
  sudo dnf install -y "${packages[@]}"
fi
mkdir -p "$CONFIG_HOME/quickshell" "$CONFIG_HOME/buchhwin-dwl/wallpapers" \
  "$CONFIG_HOME/xdg-desktop-portal" "$CONFIG_HOME/systemd/user" "$BIN_HOME" "$BACKUP_DIR"

# User-local font installation makes the glyph font available to the isolated
# Quickshell and terminal profiles without changing Plasma's selected fonts.
FONT_HOME="$DATA_HOME/fonts/MesloLGS"
if ! fc-list 2>/dev/null | grep -qi "MesloLGS Nerd Font"; then
  font_tmp="$(mktemp -d)"
  curl -fsSL -o "$font_tmp/Meslo.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Meslo.zip
  echo "13b502ac8c2bd9d3161018064560e23cd42b175bb730780a270975265a19ad57  $font_tmp/Meslo.zip" | sha256sum -c -
  mkdir -p "$FONT_HOME"
  unzip -qo "$font_tmp/Meslo.zip" -d "$FONT_HOME"
  fc-cache -f "$DATA_HOME/fonts" >/dev/null
  rm -rf "$font_tmp"
fi

# Install OnlyOffice as a user-local Flatpak without adding RPM repositories.
# Brave and Visual Studio Code are managed separately by the user.
if (( ! PREPARE_ONLY )); then
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install --user -y flathub org.onlyoffice.desktopeditors
  # Default applications are user-wide, including Plasma. Leave the user's
  # choices intact; session shortcuts launch the bundled applications directly.
fi

# Starship is not shipped by Fedora. Install a pinned standalone binary into
# ~/.local/bin so it is used only by this account and can be reproduced later.
if [[ ! -x "$BIN_HOME/starship" ]]; then
  case "$(uname -m)" in
    x86_64) starship_target=x86_64-unknown-linux-gnu; starship_sha=321f0dd7af8340a5f2e6a8fec6538a04f617486f9ec70d878f91c09cd8deef22 ;;
    aarch64) starship_target=aarch64-unknown-linux-musl; starship_sha=dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b ;;
    *) echo "Unsupported architecture for Starship: $(uname -m)" >&2; exit 1 ;;
  esac
  starship_tmp="$(mktemp -d)"
  curl -fsSL -o "$starship_tmp/starship.tar.gz" \
    "https://github.com/starship/starship/releases/download/v1.26.0/starship-${starship_target}.tar.gz"
  echo "$starship_sha  $starship_tmp/starship.tar.gz" | sha256sum -c -
  tar -xzf "$starship_tmp/starship.tar.gz" -C "$starship_tmp" starship
  install -m755 "$starship_tmp/starship" "$BIN_HOME/starship"
  rm -rf -- "$starship_tmp"
fi

backup() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local rel="${path#/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$path" "$BACKUP_DIR/$rel"
  fi
}
backup "$CONFIG_HOME/quickshell/buchhwin"
backup "$CONFIG_HOME/buchhwin-dwl"
backup "$CONFIG_HOME/xdg-desktop-portal/buchhwin-portals.conf"
backup "/usr/local/bin/dwl-buchhwin"
backup "/usr/local/bin/buchhwin-session"
backup "/usr/share/wayland-sessions/buchhwin.desktop"

# Replace only the dedicated buchhwin paths. Existing ~/.config/quickshell/dwl
# and every Plasma setting remain untouched.
if [[ -d "$CONFIG_HOME/quickshell/buchhwin" ]]; then
  mv "$CONFIG_HOME/quickshell/buchhwin" "$BACKUP_DIR/quickshell-buchhwin.previous"
fi
cp -a "$ROOT/config/quickshell/buchhwin" "$CONFIG_HOME/quickshell/buchhwin"
[[ -f "$CONFIG_HOME/buchhwin-dwl/settings.env" ]] || cp "$ROOT/config/settings.env" "$CONFIG_HOME/buchhwin-dwl/settings.env"
[[ -f "$CONFIG_HOME/buchhwin-dwl/alacritty.toml" ]] || cp "$ROOT/config/alacritty.toml" "$CONFIG_HOME/buchhwin-dwl/alacritty.toml"
[[ -f "$CONFIG_HOME/buchhwin-dwl/kitty.conf" ]] || cp "$ROOT/config/kitty.conf" "$CONFIG_HOME/buchhwin-dwl/kitty.conf"
[[ -f "$CONFIG_HOME/buchhwin-dwl/fastfetch.jsonc" ]] || install -m644 "$ROOT/config/fastfetch.jsonc" "$CONFIG_HOME/buchhwin-dwl/fastfetch.jsonc"
mkdir -p "$CONFIG_HOME/buchhwin-dwl/zsh"
install -m644 "$ROOT/config/zshrc" "$CONFIG_HOME/buchhwin-dwl/zsh/.zshrc"
install -m644 "$ROOT/assets/wallpapers/buchhwin-default.png" "$CONFIG_HOME/buchhwin-dwl/wallpapers/buchhwin-default.png"
install -m755 "$ROOT/scripts/session.py" "$CONFIG_HOME/buchhwin-dwl/session.py"
install -m755 "$ROOT/scripts/display_profile.py" "$CONFIG_HOME/buchhwin-dwl/display_profile.py"
install -m755 "$ROOT/scripts/displayctl.py" "$CONFIG_HOME/buchhwin-dwl/displayctl.py"
install -m755 "$ROOT/scripts/calendar_events.py" "$CONFIG_HOME/buchhwin-dwl/calendar_events.py"
install -m755 "$ROOT/scripts/calendar_manage.py" "$CONFIG_HOME/buchhwin-dwl/calendar_manage.py"
install -m755 "$ROOT/scripts/appearancectl.py" "$CONFIG_HOME/buchhwin-dwl/appearancectl.py"
install -m755 "$ROOT/scripts/settings_backend.py" "$CONFIG_HOME/buchhwin-dwl/settings_backend.py"
install -m755 "$ROOT/scripts/media_player.py" "$CONFIG_HOME/buchhwin-dwl/media_player.py"
install -m755 "$ROOT/scripts/weather.py" "$CONFIG_HOME/buchhwin-dwl/weather.py"
install -m755 "$ROOT/scripts/patch-keybinds.py" "$CONFIG_HOME/buchhwin-dwl/patch-keybinds.py"
install -m755 "$ROOT/scripts/buchhwin-rebuild-keybinds" "$BIN_HOME/buchhwin-rebuild-keybinds"
install -m755 "$ROOT/scripts/buchhwin-weather" "$BIN_HOME/buchhwin-weather"
install -Dm644 "$ROOT/data/applications/buchhwin-weather.desktop" "$USER_HOME/.local/share/applications/buchhwin-weather.desktop"
install -m755 "$ROOT/scripts/patch-dwl-config.py" "$CONFIG_HOME/buchhwin-dwl/patch-dwl-config.py"
install -m755 "$ROOT/scripts/patch-dwl-source.py" "$CONFIG_HOME/buchhwin-dwl/patch-dwl-source.py"
install -m755 "$ROOT/scripts/build-dwl-fedora.sh" "$CONFIG_HOME/buchhwin-dwl/build-dwl-fedora.sh"
for helper in "$ROOT"/scripts/buchhwin-*; do install -m755 "$helper" "$BIN_HOME/$(basename "$helper")"; done
install -m644 "$ROOT/config/xdg-desktop-portal/buchhwin-portals.conf" "$CONFIG_HOME/xdg-desktop-portal/buchhwin-portals.conf"
install -m644 "$ROOT/config/systemd/user/buchhwin-session.target" "$CONFIG_HOME/systemd/user/buchhwin-session.target"
systemctl --user daemon-reload

"$CONFIG_HOME/buchhwin-dwl/build-dwl-fedora.sh"
BUILD_DIR="$DATA_HOME/buchhwin-dwl/build/dwl-scenefx-port"
mkdir -p "$USER_HOME/Pictures/Screenshots"
if (( PREPARE_ONLY )); then
  echo "Fedora user preparation complete. Backups: $BACKUP_DIR"
  echo "Run ./install-fedora.sh later to install missing packages and the SDDM session."
  exit 0
fi

sudo install -Dm755 "$BUILD_DIR/dwl" /usr/local/bin/dwl-buchhwin
sudo install -Dm755 "$ROOT/bin/buchhwin-session" /usr/local/bin/buchhwin-session
sudo install -Dm644 "$ROOT/session/buchhwin.desktop" /usr/share/wayland-sessions/buchhwin.desktop

sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service || true
echo "Fedora installation complete. Backups: $BACKUP_DIR"
echo "Select the separate 'buchhwin' session in SDDM; Plasma remains available as the fallback desktop."
