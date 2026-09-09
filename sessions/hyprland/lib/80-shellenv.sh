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

    mapfile -t pkgs < <(read_list dnf-sysadmin.txt)
    step "${#pkgs[@]} packages"
    # `weak` rather than `noweak`: several of these are metapackage-ish and
    # their recommendations are the parts people expect (bind-utils, sysstat).
    dnf_install weak "${pkgs[@]}" || warn "some tools failed — see above"

    # ------------------------------------------------------------------ zshrc
    #
    # ⚠️ A SYMLINK, like the shell configuration in lib/60-shell.sh. A copy
    # would mean a `git pull` silently not reaching the file everybody is
    # actually using, which is the whole class of fault this repository keeps
    # finding in itself.
    #
    # ⚠️ AND AN EXISTING ~/.zshrc IS NEVER OVERWRITTEN. It is somebody's file.
    # It is moved aside once, with its name said out loud, so nothing is lost
    # and nobody has to guess where it went.
    if [[ -L "$HOME/.zshrc" ]]; then
        ln -sfn "$REPO_DIR/dotfiles/zsh/zshrc" "$HOME/.zshrc"
        ok ".zshrc linked"
    elif [[ -e "$HOME/.zshrc" ]]; then
        mv "$HOME/.zshrc" "$HOME/.zshrc.before-buchhwin"
        ln -sfn "$REPO_DIR/dotfiles/zsh/zshrc" "$HOME/.zshrc"
        warn "your .zshrc was kept as ~/.zshrc.before-buchhwin"
        warn "  anything you want back goes in ~/.zshrc.local, which is sourced last"
    else
        ln -sfn "$REPO_DIR/dotfiles/zsh/zshrc" "$HOME/.zshrc"
        ok ".zshrc linked"
    fi

    # ------------------------------------------------------- the login shell
    #
    # ⚠️ THE FILE ALONE DOES NOTHING. Without this, ~/.zshrc sits there and the
    # account still logs into bash — which is exactly the state this machine was
    # in, with zsh installed for four milestones.
    #
    # ⚠️ `sudo chsh -s <shell> <user>` FIRST, and a bare `chsh` only as the
    # fallback. Plain `chsh` makes the account authenticate to itself, and on a
    # machine where the password is managed elsewhere — or where PAM has just
    # been changed, which lib/70-services.sh does — that prompt can fail with no
    # useful message.
    local want=/usr/bin/zsh

    # ⚠️ `$USER` IS NOT ALWAYS SET, and under `set -u` an unset one is fatal —
    # the installer would die here rather than warn. Found by tests/install-runs.sh
    # running over SSH, where the shell is non-interactive and never sets it;
    # the same is true of a systemd unit, a container and a cron job.
    #
    # Three sources, exactly as ui/lock/LockFace.qml already does for the same
    # question: `id -un` asks the system rather than the environment and is the
    # authoritative one, with the two environment spellings behind it.
    local who
    who="$(id -un 2>/dev/null || true)"
    [[ -n "$who" ]] || who="${USER:-${LOGNAME:-}}"
    if [[ -z "$who" ]]; then
        warn "cannot tell which account this is — the login shell was left alone"
        return 0
    fi

    if [[ ! -x "$want" ]]; then
        warn "zsh is not installed — the login shell was left alone"
    elif [[ "$(getent passwd "$who" | cut -d: -f7)" == "$want" ]]; then
        ok "zsh is already the login shell"
    elif sudo -n chsh -s "$want" "$who" 2>/dev/null \
         || sudo chsh -s "$want" "$who" 2>/dev/null \
         || chsh -s "$want" 2>/dev/null; then
        ok "zsh is the login shell — it applies at the next login"
    else
        warn "could not change the login shell. Run it yourself:"
        warn "  sudo chsh -s $want $who"
    fi

    # ⚠️⚠️ AND `chsh` ALONE IS NOT ENOUGH, WHICH IS WHY THIS EXISTS. He reported
    # "no zsh as the default shell" on a machine where `getent passwd` already
    # said zsh — and he was right. `chsh` changes the passwd entry; a session
    # that was already running keeps the `SHELL` it was handed at login, and
    # kitty starts `$SHELL`. Measured on the test machine:
    #
    #     getent passwd  →  /usr/bin/zsh      what is written down
    #     niri's SHELL=  →  /bin/bash         what actually runs
    #     running shells →  2 × bash
    #
    # Reading the passwd entry and reporting success is checking the form rather
    # than the result. environment.d is read by `systemd --user`, so the next
    # session gets the right value whatever the display manager inherited — and
    # the FIRST login after the change is then already correct, instead of
    # needing a second one nobody would connect to this.
    mkdir -p "$CONFIG_HOME/environment.d"
    if [[ -x "$want" ]]; then
        printf 'SHELL=%s\n' "$want" \
            > "$CONFIG_HOME/environment.d/15-buchhwin-shell.conf"
        if [[ "${SHELL:-}" != "$want" ]]; then
            warn "this session still runs ${SHELL:-unset} — log out once and it is zsh"
        fi
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
