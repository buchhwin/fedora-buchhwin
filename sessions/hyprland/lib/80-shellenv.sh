# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
#
# Phase: shellenv — the sysadmin toolbox, and the shell that makes it usable.
#
# ⚠️ WHY THIS PHASE EXISTS AT ALL. zsh has been in packages/dnf-core.txt since
# M1 and was never configured or made anybody's login shell; starship has been
# installed since M3 and was never initialised. Both are the most reliable
# shape of "forgotten, not decided" this project has: a package that is present
# and the one line that makes it do something missing. bluez, gnome-keyring and
# udisks2 were the same, and each of them was a bug.
#
# ⚠️ NOTHING HERE STARTS A SERVICE. It installs binaries, writes two files in
# $HOME and changes one field in /etc/passwd.
phase_shellenv() {
    section "Shell and tools"

    # WARNING: CONFIG_HOME WAS USED THREE TIMES IN THIS PHASE AND SET NOWHERE.
    # lib/common.sh runs under `set -u`, so the first reference would have
    # killed the phase outright — and everything after it, including bhctl
    # landing on the PATH. It is derived here the same way lib/60-shell.sh
    # derives it, including the unwrapping: running the installer from inside
    # the session means XDG_CONFIG_HOME already points at the session root, and
    # appending to it again gives .../hyprland/buchhwin-sessions/hyprland.
    local kde_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    case "$kde_config_home" in
        */buchhwin-sessions/hyprland) kde_config_home="${kde_config_home%/buchhwin-sessions/hyprland}" ;;
    esac
    local CONFIG_HOME="$kde_config_home/buchhwin-sessions/hyprland"

    mapfile -t pkgs < <(read_list dnf-sysadmin.txt)
    step "${#pkgs[@]} packages"
    # `weak` rather than `noweak`: several of these are metapackage-ish and
    # their recommendations are the parts people expect (bind-utils, sysstat).
    dnf_install weak "${pkgs[@]}" || warn "some tools failed — see above"

    # ------------------------------------------------------------------ zsh
    #
    # WARNING: THIS USED TO TAKE OVER THE ACCOUNT, AND IT NO LONGER DOES.
    # It moved ~/.zshrc to ~/.zshrc.before-buchhwin, put a symlink into this
    # repository in its place, and ran `chsh` to make zsh the login shell. Both
    # are account-wide: they change what happens when you open a terminal in
    # Plasma, over SSH, in a cron job and in a container — in return for
    # installing a window manager.
    #
    # The dwl session has never done either. It keeps its zsh configuration in
    # its own ZDOTDIR and points the session at it, so the shell inside the
    # desktop is the project's and the shell everywhere else is yours. That is
    # what happens here now.
    #
    # WARNING: ZDOTDIR IS SET IN TWO PLACES AND BOTH ARE NEEDED.
    # bin/buchhwin-hyprland-session covers everything the compositor starts;
    # scripts/buchhwin-terminal covers a terminal opened from a keybinding,
    # which does not inherit from the compositor on every path.
    local zdotdir="$CONFIG_HOME/zsh"
    mkdir -p "$zdotdir"
    ln -sfn "$REPO_DIR/dotfiles/zsh/zshrc" "$zdotdir/.zshrc"
    ok "zsh configuration linked into $zdotdir"

    # A previous install may have taken the account over. Give it back rather
    # than leaving a symlink into this repository behind on an upgrade.
    if [[ -L "$HOME/.zshrc" ]] && [[ "$(readlink -f "$HOME/.zshrc")" == "$REPO_DIR"/* ]]; then
        rm -f "$HOME/.zshrc"
        if [[ -f "$HOME/.zshrc.before-buchhwin" ]]; then
            mv "$HOME/.zshrc.before-buchhwin" "$HOME/.zshrc"
            ok "your own ~/.zshrc was put back"
        else
            ok "the symlink into this repository was removed from ~/.zshrc"
        fi
    fi

    # The login shell is deliberately NOT changed. `chsh` decides what runs when
    # you log in anywhere, and that is not this installer's call to make.
    if [[ "$(getent passwd "$(id -un 2>/dev/null || echo "${USER:-}")" 2>/dev/null | cut -d: -f7)" != */zsh ]]; then
        step "your login shell is unchanged — the desktop uses zsh regardless"
        step "  to make it yours everywhere:  chsh -s /usr/bin/zsh"
    fi


    # ------------------------------------------------------------ the PATH
    #
    # ⚠️ ~/.local/bin FOR NON-LOGIN SHELLS TOO. Fedora's /etc/profile.d adds it
    # only for login shells, so a terminal opened from the desktop did not have
    # it — anything installed with `pip --user`, or dropped in by hand, was
    # simply not found. ~/.zshrc adds it as well; this covers the programs that
    # read the environment rather than starting a shell.
    mkdir -p "$HOME/.local/bin" "$CONFIG_HOME/environment.d"

    # ⚠️ AND bhctl ITSELF, WHICH WAS ON NOBODY'S PATH. `doctor` recommends
    # `bhctl binds reset` and `bhctl hypr apply` in its own output, the README
    # names it, the settings window's error banner points at it — and on his
    # laptop `command -v bhctl` answered nothing, because ~/.local/bin was
    # empty. A rescue you have to know the source tree to call is not a rescue.
    #
    # A symlink, not a copy: a `git pull` has to reach it, the same argument as
    # the shell directory in lib/60-shell.sh.
    ln -sfn "$REPO_DIR/bin/bhctl" "$HOME/.local/bin/bhctl"
    # ⚠️ buchhwin-fetch USED TO BE LINKED HERE TOO, and it is gone with the
    # spinning logo it played. The zshrc calls `fastfetch` directly now, which
    # is on the PATH from its own package.
    ok "bhctl is on the PATH"
    if [[ ! -f "$CONFIG_HOME/environment.d/10-buchhwin-path.conf" ]]; then
        printf 'PATH=%s/.local/bin:${PATH}\n' "$HOME" \
            > "$CONFIG_HOME/environment.d/10-buchhwin-path.conf"
        ok "$HOME/.local/bin is on the PATH"
    fi

    # ⚠️ THE LAST INSTALLING STEP IN THE WHOLE RUN, WHICH IS EXACTLY WHY THE
    # REMOVAL SITS HERE. Every package this desktop wants is on the machine and
    # marked "User" by now, so dnf's sweep of unused dependencies cannot reach
    # one of ours. Measured: removing waybar from phase_desktop wanted to take
    # twenty packages with it, one of them `playerctl` — which is on our own
    # list in packages/dnf-sysadmin.txt. The list, the measurement and the
    # reasoning are in packages/dnf-unwanted.txt and remove_unwanted().
    section "Foreign programs this desktop replaces"
    remove_unwanted
}
