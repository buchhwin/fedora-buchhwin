#!/usr/bin/env bash
# Take the Buchhwin Hyprland session back off this machine.
#
#   ./uninstall.sh              remove it
#   ./uninstall.sh --dry-run    print what would be removed, change nothing
#
# ⚠️ THIS EXISTS BECAUSE THE INSTALLER IS MEANT TO RUN ON A MACHINE SOMEBODY
# WORKS ON. It writes four files outside your home directory, enables SDDM and
# adds about seventy-five packages. Every one of those is defensible; none of
# them is something to be stuck with.
#
# ⚠️⚠️ THIS PARAGRAPH IS PRINTED BY --help, and until 10.09.2026 it said "changes
# the login shell, moves ~/.zshrc aside and writes eight files" — which was the
# old installer, not this one. It removes MORE than four files even so, on
# purpose: a machine that ran the old version still has six others on it, and
# this is the only thing that will ever take them off. Which of the two a path
# belongs to is written next to it below, because otherwise the next reader
# deletes the ones that look unused.
#
# What it removes: everything the installer created.
# What it does NOT remove: packages. Uninstalling a session should not take a
# font, an office suite or a terminal emulator with it — the same rule the dwl
# session follows, and for the same reason. The list is printed at the end if
# you want them gone.
#
# (It used to say "Brave, VS Code or a font". Neither is installed any more —
# both went with the application list when the profile was cut back, and the
# sentence stayed behind naming them.)
#
# Plasma is untouched throughout. It was the fallback session before this was
# installed and it is the session you land in afterwards.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
case "${1:-}" in
    --dry-run) DRY_RUN=1 ;;
    "") ;;
    # Every comment line after the first, not a fixed range: a range prints half
    # a sentence the day somebody adds a line to the header.
    -h|--help) sed -n '2,${/^#/!q;p;}' "$0"; exit 0 ;;
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
#
# ⚠️⚠️ AND THAT INSTALLER IS GONE. Nothing has taken ~/.zshrc over since the
# profile was cut back — lib/80-shellenv.sh writes into its own ZDOTDIR and, on
# an upgrade, hands the file back itself. This block is here for the account
# that ran the old version and never re-ran the new one, and for no other
# reason. It is not dead and it is not current; it is the last thing that will
# ever look.
#
# ⚠️ THE TARGET IS CHECKED, AND IT WAS NOT. `[[ -L ~/.zshrc ]]` alone deletes a
# symlink somebody made themselves — the dotfiles repo half this machine's
# owners keep — on the way out of a desktop that never touched it. Only a link
# into THIS repository is ours to remove, which is the test lib/80-shellenv.sh
# already applies for the same file.
section "Your shell"
if [[ -L "$HOME/.zshrc" ]] && [[ "$(readlink -f "$HOME/.zshrc")" == "$REPO_DIR"/* ]]; then
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
#
# ⚠️ TWO LISTS IN ONE, AND SAYING SO IS THE POINT. The first four are what this
# installer writes — the same four the dry run names, and lib/common.sh is the
# other end of that promise. The rest were written by the version before the
# profile was cut back and are written by nothing today.
#
# ⚠️⚠️ THEY STAY ANYWAY. Every entry is guarded by `[[ -e ]]`, so on a machine
# that never ran the old installer the whole second half is six tests that find
# nothing — and on a machine that did, this is the only thing that will ever
# take a root-owned polkit rule and a setuid-adjacent helper back off it. An
# uninstaller that only knows the current version leaves the mess made by the
# one people actually ran.
#
# Do not "clean these up" because they look unused. Remove one only when you are
# willing to say that nobody is still running the release that wrote it.
sys_files=(
    # written by this version — kept in step with lib/common.sh's plan
    /usr/local/bin/buchhwin-hyprland-session
    /usr/share/wayland-sessions/buchhwin-hyprland.desktop
    /etc/pam.d/buchhwin-lock
    /etc/systemd/logind.conf.d/50-buchhwin.conf

    # written by the version before the cut-back; here for machines that ran it
    /usr/libexec/buchhwin-charge
    /etc/polkit-1/rules.d/49-buchhwin.rules
    /usr/share/polkit-1/actions/org.buchhwin.policy
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
#
# ⚠️⚠️ THE INSTALLER STOPPED ADDING THEM. This is the second half of the list
# above in another shape: nothing has touched /etc/dnf/dnf.conf since the
# cut-back, and this is here for the machine that ran the version that did.
#
# ⚠️ AND IT ONLY DELETES A LINE IT RECOGNISES. `defaultyes=True` is a setting a
# person may have set for themselves years earlier — the sed below is aimed at
# the setting NAME, so it takes that line out too, and this is the one entry in
# the file where the old installer's edit and somebody's own preference are
# indistinguishable. Nothing here can tell them apart, so the setting is named
# on screen as it goes and --dry-run shows it before it happens.
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
