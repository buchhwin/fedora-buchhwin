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
    # WARNING: THIS PHASE USED TO EDIT /etc/dnf/dnf.conf AND ADD AN ALIAS FILE.
    # It set defaultyes=True and max_parallel_downloads=10, and wrote
    # /etc/dnf/dnf5-aliases.d/buchhwin.conf. Both are pleasant and neither is
    # this project's business: they change how dnf behaves for every package
    # on the machine, for every user, forever, in return for installing a
    # window manager. The dwl session has never touched them.
    #
    # If you want them, they are two lines you own rather than two lines that
    # arrived with a desktop:
    #
    #     sudo dnf config-manager setopt defaultyes=True
    #     sudo dnf config-manager setopt max_parallel_downloads=10
}
