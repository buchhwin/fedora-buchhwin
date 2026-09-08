# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: base — the packages nothing else works without.
phase_base() {
    section "Base system"
    mapfile -t pkgs < <(read_list dnf-core.txt)
    step "${#pkgs[@]} packages"
    dnf_install weak "${pkgs[@]}" || die "base packages failed"
    ok "base system"

    # ⚠️ `Is this ok [y/N]:` WITH N AS THE DEFAULT means every install needs an
    # explicit y. Flipped to [Y/n]: on this machine the answer is essentially
    # always yes, and pressing Enter should not abort the install you just asked
    # for.
    #
    # ⚠️ THIS WAS IN THE PREDECESSOR AND WAS NEVER CARRIED ACROSS. It is not a
    # regression — fedora-buchhwin-hyprland/lib/20-base.sh has had it since that
    # project started, and the rewrite simply left it behind. He noticed because
    # he uses it every day. What else was left behind is being gone through
    # separately; this is the first of them.
    #
    # Idempotent, and the placement matters: the key belongs under [main], and
    # appended to the end of a file that has other sections dnf ignores it.
    #
    # ⚠️⚠️ THIS BLOCK ARRIVED WRAPPED IN `if (( DRY_RUN ))`, AND THAT ONE LINE
    # BROKE THE WHOLE INSTALLER. The predecessor has a full --dry-run mode
    # threaded through eight phase files; the rewrite has none, and the flag is
    # not among the four in the help text at install.sh:4-8. So `DRY_RUN` was
    # referenced exactly once in this repo and defined nowhere — and under
    # `set -u` (lib/common.sh:9) an unbound name in an arithmetic test is fatal:
    # phase_base died with exit 127 right here, and desktop, apps, fonts,
    # cursors, shell, services and summary never ran at all.
    #
    # Measured, with the control: the same construct with DRY_RUN set runs
    # through and prints everything after it. CI never saw it because CI does
    # not run install.sh — see tests/install-runs.sh, which now does.
    #
    # The fix is deletion, not `DRY_RUN=${DRY_RUN:-0}`. A branch that cannot
    # ever be true is the same fault this project bans everywhere else: a key
    # with no reader. A real --dry-run has to be honoured by every phase or it
    # half-installs, which is worse than not offering it.
    step "dnf answers [Y/n]"
    sudo mkdir -p /etc/dnf
    sudo touch /etc/dnf/dnf.conf
    if grep -qE '^[[:space:]]*defaultyes[[:space:]]*=' /etc/dnf/dnf.conf; then
        sudo sed -i -E 's/^[[:space:]]*defaultyes[[:space:]]*=.*/defaultyes=True/' \
            /etc/dnf/dnf.conf
    elif grep -q '^\[main\]' /etc/dnf/dnf.conf; then
        sudo sed -i '/^\[main\]/a defaultyes=True' /etc/dnf/dnf.conf
    else
        printf '[main]\ndefaultyes=True\n' | sudo tee -a /etc/dnf/dnf.conf >/dev/null
    fi
    # ⚠️ THE LINE THAT STOOD NEXT TO IT AND WAS LEFT BEHIND. In the
    # predecessor these two were one block; the rewrite took `defaultyes`
    # and not this. Ten parallel downloads is the single biggest difference
    # to how long an install feels on a fast line.
    if grep -qE '^[[:space:]]*max_parallel_downloads[[:space:]]*=' /etc/dnf/dnf.conf; then
        sudo sed -i -E 's/^[[:space:]]*max_parallel_downloads[[:space:]]*=.*/max_parallel_downloads=10/' \
            /etc/dnf/dnf.conf
    elif grep -q '^\[main\]' /etc/dnf/dnf.conf; then
        sudo sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf
    else
        printf '[main]\nmax_parallel_downloads=10\n' | sudo tee -a /etc/dnf/dnf.conf >/dev/null
    fi
    ok "dnf answers [Y/n] and downloads ten at a time"

    # ⚠️ WE READ THIS FILE AND NEVER CREATED IT. lib/60-shell.sh asks
    # `xdg-user-dir PICTURES` and tools/niri.qml parses ~/.config/user-dirs.dirs
    # to decide where screenshots go — but nothing ever ran the updater, so on a
    # fresh machine the file does not exist and both fall back silently. The
    # package was installed (packages/dnf-core.txt); only the one command that
    # makes it do anything was missing.
    if command -v xdg-user-dirs-update >/dev/null; then
        xdg-user-dirs-update
        ok "xdg user directories"
    fi

    # `dnf i` as well as `dnf install`, and under sudo too.
    #
    # dnf5 already ships `in` for install and `if` for info; this adds the
    # single letter. It goes in a SYSTEM directory on purpose — a shell alias
    # would not survive `sudo`, which runs the real binary, and this is a
    # package manager: the sudo form is the one that matters.
    #
    # ⚠️ Two things measured rather than assumed, because both failed first:
    # the drop-in directory is /etc/dnf/dnf5-aliases.d (NOT the empty
    # /etc/dnf/aliases.d that also exists), and the file must end in .conf —
    # a .toml is ignored without a word, which looks exactly like a wrong alias.
    if [[ -d /usr/share/dnf5/aliases.d ]]; then
        sudo mkdir -p /etc/dnf/dnf5-aliases.d
        sudo tee /etc/dnf/dnf5-aliases.d/buchhwin.conf >/dev/null <<'EOF'
# Generated by buchhwin. `dnf i` alongside dnf5's own `in` and `if`.
version = '1.0'

['i']
type = 'command'
attached_command = 'install'
descr = "Alias for 'install'"
EOF
        ok "dnf i works as dnf install (sudo too)"
    fi
}
