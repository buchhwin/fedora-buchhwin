#!/usr/bin/env bash
# Take the Buchhwin Hyprland session back off this machine.
#
#   ./uninstall.sh              remove it
#   ./uninstall.sh --dry-run    print what would be removed, change nothing
#
# ⚠️ THIS EXISTS BECAUSE THE INSTALLER IS MEANT TO RUN ON A MACHINE SOMEBODY
# WORKS ON. It changes the login shell, moves ~/.zshrc aside and writes eight
# files outside the home directory. Every one of those is defensible; none of
# them is something to be stuck with.
#
# What it removes: everything the installer created.
# What it does NOT remove: packages. Uninstalling a session should not take
# Brave, VS Code or a font with it — the same rule the dwl session follows, and
# for the same reason. The list is printed at the end if you want them gone.
#
# Plasma is untouched throughout. It was the fallback session before this was
# installed and it is the session you land in afterwards.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
case "${1:-}" in
    --dry-run) DRY_RUN=1 ;;
    "") ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
esac

(( EUID != 0 )) || { echo "Run as your normal user, not with sudo." >&2; exit 1; }

C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_OFF=$'\033[0m'
section() { printf '\n%s==>%s %s\n' "$C_OK" "$C_OFF" "$*"; }
ok()      { printf '  %s✓%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn()    { printf '  %s!%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
act()     { if (( DRY_RUN )); then printf '  would: %s\n' "$*"; else "$@"; fi; }

# ⚠️ THE SAME UNWRAPPING THE INSTALLER DOES. Running this from inside the
# session means XDG_CONFIG_HOME already points at the session's own root, and
# deriving the path from it again would give
# .../buchhwin-sessions/hyprland/buchhwin-sessions/hyprland.
kde_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
case "$kde_config_home" in
    */buchhwin-sessions/hyprland) kde_config_home="${kde_config_home%/buchhwin-sessions/hyprland}" ;;
esac
CONFIG_HOME="$kde_config_home/buchhwin-sessions/hyprland"

(( DRY_RUN )) && section "Dry run — nothing below will be changed"

# ------------------------------------------------------------- user services
#
# Stopped before their files go, or systemd keeps running a unit whose
# definition no longer exists and says nothing about it.
section "User services"
for unit in buchhwin-shell buchhwin-clipboard buchhwin-clipboard-image buchhwin-drive; do
    if systemctl --user list-unit-files "$unit.service" >/dev/null 2>&1; then
        act systemctl --user disable --now "$unit.service"
        ok "$unit stopped and disabled"
    fi
done
for unit in buchhwin-shell buchhwin-shell-failed buchhwin-clipboard \
            buchhwin-clipboard-image buchhwin-drive; do
    f="$kde_config_home/systemd/user/$unit.service"
    [[ -e "$f" ]] && { act rm -f "$f"; ok "removed $unit.service"; }
done
act systemctl --user daemon-reload

# --------------------------------------------------------------- the session
#
# One directory, because the whole point of the session's own XDG root is that
# it can be removed in one move without a list of exceptions.
section "Session configuration"
if [[ -d "$CONFIG_HOME" ]]; then
    act rm -rf "$CONFIG_HOME"
    ok "removed $CONFIG_HOME"
else
    warn "$CONFIG_HOME was not there"
fi

state="${XDG_STATE_HOME:-$HOME/.local/state}/buchhwin"
[[ -d "$state" ]] && { act rm -rf "$state"; ok "removed $state"; }

# --------------------------------------------------------------- ~/.local/bin
#
# Derived from the repository rather than typed out, so a helper added later is
# never left behind as a dangling symlink.
section "Helpers on your PATH"
bin_home="$HOME/.local/bin"
for helper in "$REPO_DIR"/scripts/buchhwin-*; do
    [[ -e "$helper" ]] || continue
    target="$bin_home/$(basename "$helper")"
    [[ -e "$target" || -L "$target" ]] && { act rm -f "$target"; ok "removed $(basename "$helper")"; }
done
[[ -e "$bin_home/bhctl" || -L "$bin_home/bhctl" ]] && { act rm -f "$bin_home/bhctl"; ok "removed bhctl"; }

# ----------------------------------------------------------------- the shell
#
# ⚠️ THE BACKUP IS RESTORED, NOT JUST LEFT LYING THERE. The installer moved the
# real .zshrc to .zshrc.before-buchhwin and put a symlink in its place. Deleting
# the symlink and stopping would leave an account with no .zshrc at all.
section "Your shell"
if [[ -L "$HOME/.zshrc" ]]; then
    act rm -f "$HOME/.zshrc"
    ok "removed the .zshrc symlink"
    if [[ -f "$HOME/.zshrc.before-buchhwin" ]]; then
        act mv "$HOME/.zshrc.before-buchhwin" "$HOME/.zshrc"
        ok "restored your original .zshrc"
    fi
elif [[ -f "$HOME/.zshrc.before-buchhwin" ]]; then
    warn "$HOME/.zshrc is not our symlink — your backup is still at $HOME/.zshrc.before-buchhwin"
fi

# The login shell is NOT changed back, on purpose: this cannot know what it was
# before, and guessing /bin/bash for somebody who chose zsh years ago would be
# worse than saying nothing. So it says something instead.
current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [[ "$current_shell" == */zsh ]]; then
    warn "your login shell is still $current_shell"
    warn "  to change it back:  chsh -s /bin/bash"
fi

# -------------------------------------------------------- outside your home
section "System files"
sys_files=(
    /usr/local/bin/buchhwin-hyprland-session
    /usr/share/wayland-sessions/buchhwin-hyprland.desktop
    /usr/libexec/buchhwin-charge
    /etc/pam.d/buchhwin-lock
    /etc/polkit-1/rules.d/49-buchhwin.rules
    /usr/share/polkit-1/actions/org.buchhwin.policy
    /etc/systemd/logind.conf.d/50-buchhwin.conf
    /etc/systemd/journald.conf.d/buchhwin.conf
    /etc/dnf/dnf5-aliases.d/buchhwin.conf
    /etc/brave/policies/managed/buchhwin.json
)
for f in "${sys_files[@]}"; do
    if [[ -e "$f" ]]; then
        act sudo rm -f "$f"
        ok "removed $f"
    fi
done

# ⚠️ dnf.conf IS EDITED IN PLACE, NOT REPLACED, so it cannot simply be deleted:
# it is Fedora's file and it had contents before. Only the two lines the
# installer added come out, and only if they still say what it wrote.
section "dnf configuration"
for setting in defaultyes max_parallel_downloads; do
    # ${setting} in braces: bare "$setting[" reads as an array subscript, which
    # is a shellcheck error and, worse, a pattern that quietly means something
    # other than it looks like.
    if grep -qE "^[[:space:]]*${setting}[[:space:]]*=" /etc/dnf/dnf.conf 2>/dev/null; then
        act sudo sed -i "/^[[:space:]]*${setting}[[:space:]]*=/d" /etc/dnf/dnf.conf
        ok "removed $setting from /etc/dnf/dnf.conf"
    fi
done

# ------------------------------------------------------------------- summary
section "Done"
if (( DRY_RUN )); then
    printf '  Nothing was changed. Drop --dry-run to do it for real.\n\n'
    exit 0
fi
cat <<'EOF'
  Log out and pick Plasma in SDDM. It was never removed.

  Packages were deliberately left installed — removing a session should not
  take your browser, editor and fonts with it. If you want them gone, the
  lists are in packages/ and this removes the desktop-only ones:

      sudo dnf remove hyprland xdg-desktop-portal-hyprland quickshell

  ~/Pictures/Wallpaper still holds the wallpapers that were copied there.
EOF
