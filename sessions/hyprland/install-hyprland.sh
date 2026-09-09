#!/usr/bin/env bash
# Buchhwin Hyprland profile — called by the repository-level installer.
#
#   ./install.sh                     everything
#   ./install.sh --minimal           no applications
#   ./install.sh --wallpapers <dir>  copy wallpapers from <dir> and use them
#   ./install.sh --only <phase>      one phase; repeatable
#   ./install.sh --skip <phase>      all but one; repeatable
#   ./install.sh --dry-run           print what would happen; change nothing
#
# ⚠️ RUN --dry-run FIRST ON A MACHINE YOU WORK ON. This installer adds about
# seventy-five packages, may remove three, writes four files outside your home
# directory and enables SDDM. It does NOT change your login shell and does not
# move ~/.zshrc: the session sets its own ZDOTDIR and its own XDG root. All of
# it is reversible with ./uninstall.sh, and all of it is easier to agree to
# before it happens than after.
#
# ⚠️⚠️ THIS PARAGRAPH IS PRINTED BY --help, and until 10.09.2026 it promised a
# chsh, a moved ~/.zshrc and an edit to /etc/dnf/dnf.conf — three things this
# installer stopped doing when the profile was cut back. A stale comment is a
# comment; a stale HELP TEXT is an answer given to somebody who asked. Both
# directions are checked by tests/dry-run-truth.sh now.
#
#
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

MINIMAL=0; WALLPAPERS=""; ONLY=(); SKIP=(); DRY_RUN=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --minimal)    MINIMAL=1 ;;
        --wallpapers) WALLPAPERS="${2:?}"; shift ;;
        --only)       ONLY+=("${2:?}"); shift ;;
        --skip)       SKIP+=("${2:?}"); shift ;;
        --dry-run)    DRY_RUN=1 ;;
        # ⚠️ NOT A LINE RANGE. `sed -n '2,24p'` printed exactly the header until
        # somebody added a line to it, and then it printed most of the header
        # and half a sentence. The block is every comment line after the first;
        # it ends where the code starts, which is a fact the file states itself.
        -h|--help) sed -n '2,${/^#/!q;p;}' "$0"; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done
export MINIMAL WALLPAPERS DRY_RUN

should_run() {
    local p="$1" s
    for s in "${SKIP[@]:-}"; do [[ "$s" == "$p" ]] && return 1; done
    (( ${#ONLY[@]} )) || return 0
    for s in "${ONLY[@]}"; do [[ "$s" == "$p" ]] && return 0; done
    return 1
}

for phase_file in "$REPO_DIR"/lib/[0-9][0-9]-*.sh; do
    # shellcheck source=/dev/null
    source "$phase_file"
done

run_phase() { should_run "$1" && "phase_$1"; return 0; }

run_phase preflight

# ⚠️ AFTER preflight, NOT BEFORE. The plan reports on the machine in front of
# it — which of the unwanted packages are installed, and how they got there —
# and preflight is what establishes this is a Fedora KDE machine at all.
if (( DRY_RUN )); then
    all_phases=()
    for p in preflight base desktop apps fonts shell services greeter shellenv summary; do
        should_run "$p" && all_phases+=("$p")
    done
    print_plan "${all_phases[@]}"
    exit 0
fi
# ⚠️ THERE IS NO GRAPHICS PHASE, AND THAT IS THE POINT.
# lib/10-gpu.sh used to be the largest file in this directory: it enabled RPM
# Fusion, detected GPUs from sysfs, built akmod-nvidia against the running
# kernel, set up hybrid-graphics offload, walked you through Secure Boot MOK
# enrolment, and swapped Fedora's mesa drivers for the RPM Fusion codec build.
#
# None of it is needed to have a working desktop. On a hybrid laptop the
# compositor runs on the integrated GPU either way, and the dwl session — which
# is the standard this profile is measured against — has never installed a
# driver, a codec or a third-party repository.
#
# What it cost: it was the slowest and most failure-prone step in the installer,
# it added a third-party repository to the system, and it made decisions about
# the machine's graphics stack while somebody thought they were installing a
# window manager.
#
# If you want NVIDIA drivers, install them the way Fedora documents. That is
# your machine's graphics stack, not this repository's.
run_phase base
run_phase desktop
run_phase apps
run_phase fonts
# ⚠️ `cursors` AND `spicetify` ARE GONE, not skipped. The first fetched a
# third-party cursor tarball to replace Breeze, which the KDE base already
# provides and which config/hypr/buchhwin/env.lua points at. The second themed
# Spotify, which is no longer installed.
run_phase shell
run_phase services
# ⚠️ AFTER `shell`, and the order is load-bearing rather than tidy: the greeter
# gets a SNAPSHOT of the palette and the wallpaper, because it runs as the
# `greetd` user and Fedora home directories are 0700. phase_shell is what seeds
# shell.json, so running earlier would snapshot a file that does not exist yet.
# After `services` too, so the login manager is decided once, at the end.
run_phase greeter
# ⚠️ AFTER `services`, because it changes the login shell and that is the last
# thing to touch: if anything earlier fails, the account still logs in.
run_phase shellenv
run_phase summary

# An `--only` run that filters out `summary` must still exit 0. The previous
# project ended on `should_run summary && phase_summary`, so every such run
# reported failure while having done exactly what was asked.
exit 0
