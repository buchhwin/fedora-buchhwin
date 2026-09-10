#!/usr/bin/env bash
# Shared installer helpers.
#
# The installer is the ONLY bash in this project, and it deliberately contains
# no configuration logic: it installs packages, places files and enables
# services. Everything that decides how the desktop looks or behaves is QML,
# rendered by `qs` — including on a machine that has no session yet.

set -uo pipefail

C_OK=$'\033[38;5;114m'; C_WARN=$'\033[38;5;179m'; C_ERR=$'\033[38;5;203m'; C_OFF=$'\033[0m'

# ⚠️ These four are used by the PHASE files that source this one, so shellcheck
# — which reads one file at a time — cannot see it and reports them as unused.
# Silenced with a reason rather than left to be scrolled past: a warning nobody
# can act on trains everyone to ignore the ones that matter.
#
# `C_DIM` used to be here too and really was unused, in every file. It was
# deleted rather than silenced, which is the other half of the same rule.
# shellcheck disable=SC2034
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC2034
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
# shellcheck disable=SC2034
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
# shellcheck disable=SC2034
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

WARNINGS=0
section() { printf '\n%s==>%s %s\n' "$C_OK" "$C_OFF" "$*"; }
step()    { printf '  %s\n' "$*"; }
ok()      { printf '  %s✓%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn()    { printf '  %s!%s %s\n' "$C_WARN" "$C_OFF" "$*"; WARNINGS=$((WARNINGS+1)); }
die()     { printf '  %sx%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

# Package lists are plain text with comments; this is the only parser.
read_list() {
    local f="$REPO_DIR/packages/$1"
    [[ -f "$f" ]] || die "missing package list: $f"
    grep -vE '^[[:space:]]*(#|$)' "$f" | sed 's/[[:space:]]*#.*//' | tr -d ' '
}

dnf_install() {
    local weak="$1"; shift
    (( $# )) || return 0
    local args=(-y)
    [[ "$weak" == "noweak" ]] && args+=(--setopt=install_weak_deps=False)
    sudo dnf install "${args[@]}" "$@"
}

# The foreign programs this desktop replaces — see packages/dnf-unwanted.txt for
# the list and for the measurement that turned a warning into a removal.
#
# ⚠️⚠️ REMOVING ONE OF THEM CAN TAKE OURS WITH IT, AND THAT IS MEASURED. dnf
# sweeps every package that was only installed for the one being removed. The
# dry run on the lab VM listed TWENTY, and one of them was `playerctl` — which
# is on our own list in packages/dnf-sysadmin.txt, because the media keys talk
# through it. waybar had pulled it in first, so as far as dnf is concerned it
# belongs to waybar.
#
# ⚠️⚠️ AND THE OBVIOUS DEFENCE DOES NOT WORK. The first version of this function
# ran late and said in its own comment that by then our packages are "marked
# User, so the sweep cannot reach them". That reads well and is false: measured
# on the VM, `dnf install playerctl` on an already-installed package answers
# "Nothing to do" and leaves the reason at `Dependency`. Installing something
# that is already there does not claim it. The comment would have shipped as a
# reason nobody re-checked — rule 3, a comment is not a source.
#
# What actually works is saying so out loud: `dnf mark user` sets the reason,
# and a package marked User is never swept. Verified on the VM, before and
# after: `Dependency` -> `User`.
#
# ⚠️ IT STILL RUNS LATE, for the smaller and true reason: a package that is not
# installed yet cannot be marked, and would be swept if it arrived later.
#
# ⚠️ AND IT KILLS THE RUNNING ONE. Removing the package does not close the
# window: waybar was still drawing its bar, from a binary that no longer existed
# on disk, and would have stayed until the next logout. "Installed" and "on
# screen" are two different states and both have to be answered.
# ---------------------------------------------------------------- the plan
#
# ⚠️ THIS EXISTS BECAUSE THE INSTALLER IS MEANT TO RUN ON A MACHINE SOMEBODY
# WORKS ON. It installs about seventy-five packages, may remove three, writes
# four files outside your home directory and enables SDDM. Every one of those
# is defensible on its own and none of them is something to discover afterwards.
#
# ⚠️⚠️ AND THIS PARAGRAPH WAS WRONG UNTIL 09.09.2026, WHICH IS WORSE THAN NO
# PARAGRAPH. It said the installer "changes the login shell, moves ~/.zshrc
# aside, edits /etc/dnf/dnf.conf" and installs "around 150 packages". Every one
# of those had been removed when the profile was cut back, and the plan below
# went on promising them. It overstated rather than understated — which is the
# safe direction to be wrong in and still a document that lies, in the one place
# somebody reads before deciding whether to trust it.
#
# So each line below was checked against the executable code, not against the
# comments explaining why something was taken out. Five were stale and two real
# changes were missing entirely.
#
# So: `--dry-run` prints exactly what would happen and touches nothing. It is
# the same shape the dwl session has had from the start, and its absence here
# was the difference between the two installers that mattered most.
#
# Nothing below runs dnf, sudo or any write. It reads the package lists and the
# rpm database, which is what makes it safe to run on the machine in question
# rather than on a copy of it.
print_plan() {
    local phases=("$@")

    section "Dry run — nothing below will be changed"

    step "Phases that would run:"
    printf '      %s
' "${phases[*]}"

    section "Packages"
    local list count total=0
    for list in dnf-core dnf-desktop dnf-tools dnf-apps dnf-sysadmin dnf-codecs; do
        [[ -f "$REPO_DIR/packages/$list.txt" ]] || continue
        count="$(read_list "$list.txt" | grep -c .)"
        total=$((total + count))
        printf '      %-16s %3d packages
' "$list" "$count"
    done
    printf '      %-16s %3d
' "TOTAL" "$total"
    step "Flatpaks:"
    if [[ -f "$REPO_DIR/packages/flatpak.txt" ]]; then
        read_list flatpak.txt | sed 's/^/      /'
    fi

    section "Packages that would be REMOVED"
    # The honest version of this question: a package the user chose is kept,
    # and only a dependency is swept. Saying which is which is the whole value
    # of printing it at all.
    local pkg reason
    while read -r pkg; do
        [[ -n "$pkg" ]] || continue
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            printf '      %-14s not installed, nothing to do
' "$pkg"
            continue
        fi
        reason="$(dnf repoquery --installed --qf '%{reason}' "$pkg" 2>/dev/null | head -1)"
        if [[ "$reason" == "User" ]]; then
            printf '      %-14s installed BY YOU — would be kept, with a warning
' "$pkg"
        else
            printf '      %-14s would be removed (reason: %s)
' "$pkg" "${reason:-unknown}"
        fi
    done < <(read_list dnf-unwanted.txt)

    section "Files outside your home directory"
    # ⚠️ FOUR, AND THEY WERE EIGHT ON PAPER. The four that went: a charge helper
    # in /usr/libexec, two polkit rules, a dnf5 alias file and an in-place edit
    # of /etc/dnf/dnf.conf. None of them is written any more — they went when the
    # profile was cut back, and this list went on promising them for a month.
    #
    # ⚠️⚠️ THE LOGIND FILE WAS ALMOST DROPPED FROM THIS LIST TOO, on the reasoning
    # that `bhctl power apply` writes it, "when you ask for it, not the
    # installer". Phase 70 asks for it, on every run: lib/70-services.sh calls
    # bin/bhctl itself, and bhctl's `sudo tee` writes the file. The write is one
    # file further out than the other three and it is still this installer's
    # write — which is exactly the shape of thing this list exists to name, and
    # exactly the shape a checker misses. tests/dry-run-truth.sh reads bin/bhctl
    # for that reason, and reported four green lines about this list before it
    # did.
    printf '      %s\n' \
        "/usr/local/bin/buchhwin-hyprland-session" \
        "/usr/share/wayland-sessions/buchhwin-hyprland.desktop" \
        "/etc/pam.d/buchhwin-lock  (only if it does not exist yet)" \
        "/etc/systemd/logind.conf.d/50-buchhwin.conf  (what closing the lid does)"

    section "System settings that change"
    # ⚠️ NAMED, BECAUSE THEY WERE NOT. The first two are ordinarily no-ops on a
    # Fedora KDE machine — SDDM is already the display manager and the marking
    # only touches packages that are already installed — but "ordinarily a
    # no-op" is not the same as "does nothing", and this is the list somebody
    # reads to decide whether to run it on a machine they work on.
    #
    # ⚠️⚠️ AND THE THREE COPRs WERE MISSING ENTIRELY, WHICH IS THE WORSE HALF.
    # A COPR is a third-party repository added to the machine PERMANENTLY: it
    # stays enabled after the install, its packages take part in every `dnf
    # upgrade` from then on, and ./uninstall.sh does not take it off — the same
    # rule as packages, for the same reason. That is a real decision, and it was
    # being made on the reader's behalf without appearing anywhere in the plan
    # they read in order to decide.
    #
    # `set-default graphical.target` was missing for the same reason the first
    # two nearly were: it is what a KDE machine already boots into, so it looks
    # like nothing. A plan that lists only the changes it expects to matter is a
    # plan that decides for the reader what matters.
    #
    # ⚠️ AND THREE SYSTEM SERVICES, FOUND THE SAME WAY. They are enabled only if
    # they exist and are not enabled already, which is why they read as nothing
    # — but systemd-oomd decides what this machine kills when it runs out of
    # memory, and that is not a window manager's call to make quietly.
    printf '      %s\n' \
        "systemctl enable sddm.service  (already enabled on Fedora KDE)" \
        "systemctl set-default graphical.target  (already the default on KDE)" \
        "systemctl enable udisks2.service      — mounting a stick from the file manager" \
        "systemctl enable systemd-oomd.service — kills a runaway process instead of swapping" \
        "systemctl enable tuned-ppd.service    — the power profiles the panel talks to" \
        "  each only if it exists and is not already enabled" \
        "dnf mark user, on packages we ship that the removal below could sweep up" \
        "dnf copr enable sachesi/hyprland  — ONLY if Fedora has no Hyprland" \
        "dnf copr enable atim/starship     — ONLY if starship is not installed" \
        "dnf copr enable atim/lazygit      — ONLY if lazygit is not installed" \
        "  a COPR stays enabled afterwards; uninstall.sh does not remove it" \
        "  to take one off:  sudo dnf copr disable <owner/repo>"

    section "Changes to your account"
    # shellcheck disable=SC2088  # literal text for the reader, not a path
    printf '      %s\n' \
        "~/.config/buchhwin-sessions/hyprland/ created (the whole session lives here)" \
        "~/.local/bin/ gains bhctl and the buchhwin-* helpers" \
        "systemd user units: buchhwin-shell, -clipboard, -clipboard-image, -drive"

    section "What is NOT touched"
    # shellcheck disable=SC2088  # literal text for the reader, not a path
    printf '      %s\n' \
        "your login shell — the session sets ZDOTDIR for itself; chsh is only suggested" \
        "~/.zshrc and ~/.config — this session uses its own XDG root" \
        "Plasma stays installed and stays the fallback session in SDDM" \
        "the dwl session, if you have one: its files, its config and its packages" \
        "no default application, MIME association or Plasma setting is changed" \
        "SDDM stays the only display manager; no greeter is installed"

    section "To run it for real"
    step "drop --dry-run. To leave your shell and dnf alone:"
    printf '      ./install.sh --session hyprland --skip shellenv --skip base
'
    printf '
'
}

remove_unwanted() {
    local pkgs p reason weak=() mine=()
    mapfile -t pkgs < <(read_list dnf-unwanted.txt)
    (( ${#pkgs[@]} )) || return 0

    # ⚠️ WHAT THE OTHER SESSION NEEDS IS NOT OURS TO SWEEP. `install.sh
    # --session both` runs the dwl installer and then this one, and these are
    # the names dwl installs that this profile lists as replaced. Removing — or
    # even warning about — the other desktop's own tools is the same overreach
    # as touching a package the user chose.
    #
    # ⚠️⚠️ AND IT IS DETECTED, NOT DECLARED. This used to fire only when
    # `install.sh --session both` set BUCHHWIN_SIBLING_SESSION — which misses the
    # case that actually happens: dwl is ALREADY installed, from a run last
    # month, and you now install Hyprland on its own. The variable is unset,
    # the guard never fires, and the sweep is aimed at the other desktop's lock
    # screen.
    #
    # ⚠️ IT WAS NOT ACTUALLY REMOVING ANYTHING, and that is worth writing down
    # rather than relying on: `dnf install swaylock`, which is how dwl gets it,
    # marks the package User, and the loop above only WARNS about those. So the
    # outcome was a sentence saying "swaylock is installed and marked as YOUR
    # choice" about a package the other session put there on purpose. The
    # protection was real and the sentence was wrong — which is the sort of
    # thing that gets "fixed" by somebody who believes it.
    #
    # The marker is dwl's own session file, because that is what exists exactly
    # when the other desktop is installed and nothing else writes it.
    local sibling=()
    if [[ "${BUCHHWIN_SIBLING_SESSION:-}" == "dwl" ]] \
       || [[ -f /usr/share/wayland-sessions/buchhwin.desktop ]]; then
        sibling=(swaylock swaybg swayidle)
    fi

    for p in "${pkgs[@]}"; do
        rpm -q "$p" >/dev/null 2>&1 || continue
        if [[ " ${sibling[*]} " == *" $p "* ]]; then
            ok "$p stays — the dwl session installed for its own use"
            continue
        fi
        # ⚠️ ONE LINE, and `head -1` rather than trusting there to be one: a
        # package installed for more than one architecture answers twice, and
        # the comparison below would then match neither word.
        reason="$(dnf repoquery --installed --qf '%{reason}\n' "$p" 2>/dev/null | head -1)"
        if [[ "$reason" == "User" ]]; then
            mine+=("$p")
        else
            weak+=("$p")
        fi
    done

    for p in "${mine[@]}"; do
        warn "$p is installed and marked as YOUR choice, so it stays. This desktop replaces it: sudo dnf remove $p"
    done

    (( ${#weak[@]} )) || return 0

    # ⚠️ CLAIM WHAT IS AT RISK, AND ONLY THAT. Removing a weak package lets
    # dnf sweep up whatever was only there for it, and that sweep has taken
    # things of ours before — removing waybar took `playerctl`, measured in a
    # twenty-package dry run. Marking a package User stops the sweep.
    #
    # ⚠️⚠️ IT USED TO CLAIM EVERY NAME ON EVERY LIST, and that was too much by
    # about twenty-five packages. Our lists include what Fedora KDE already
    # installed — plasma-desktop, sddm, dolphin, the KDE PIM set — and marking
    # those User rewrites the reason the USER's own base packages are on their
    # machine. It is invisible, it is not undone by uninstall.sh, and it is
    # exactly the class of change the profile was cut back to stop making:
    # nothing outside what this desktop actually brought.
    #
    # So the set is computed rather than assumed: what the packages being
    # removed depend on, intersected with what we ship. On a machine where the
    # weak set is `waybar`, that is a handful of names instead of seventy-eight.
    local ours=() f
    for f in "$REPO_DIR"/packages/dnf-*.txt; do
        [[ "$(basename "$f")" == "dnf-unwanted.txt" ]] && continue
        mapfile -t -O "${#ours[@]}" ours < <(read_list "$(basename "$f")")
    done

    # What the weak packages pull in, resolved to package names. A failure here
    # is not fatal: the fallback is the old behaviour, said out loud, because
    # protecting too much is a smaller harm than a sweep taking our files.
    local atrisk=() wide=0
    if ! mapfile -t atrisk < <(
            dnf repoquery --installed --requires --resolve --qf '%{name}' \
                "${weak[@]}" 2>/dev/null | sort -u); then
        wide=1
    fi
    (( ${#atrisk[@]} )) || wide=1
    if (( wide )); then
        warn "could not work out what the removal endangers — claiming every package we ship instead"
        atrisk=("${ours[@]}")
    fi

    # ⚠️ `--skip-unavailable`, because the lists name packages that a particular
    # machine may not have (flatpaks are not rpms) and one absent name must not
    # abort the marking of the rest.
    local claim=() p2
    for p in "${ours[@]}"; do
        [[ -n "$p" ]] || continue
        rpm -q "$p" >/dev/null 2>&1 || continue
        for p2 in "${atrisk[@]}"; do
            if [[ "$p" == "$p2" ]]; then claim+=("$p"); break; fi
        done
    done
    if (( ${#claim[@]} )); then
        sudo dnf mark user -y --skip-unavailable "${claim[@]}" >/dev/null 2>&1 \
            || warn "could not mark ${#claim[@]} of our packages as user-installed — check what the removal below takes with it"
    fi

    step "removing ${weak[*]} — pulled in as a weak dependency, replaced by this desktop"
    if sudo dnf remove -y "${weak[@]}" >/dev/null 2>&1; then
        ok "removed ${weak[*]}"
    else
        warn "could not remove ${weak[*]} — run: sudo dnf remove ${weak[*]}"
        return 0
    fi

    # Only the ones that keep a window open. A launcher and a lock screen are
    # not running right now; a bar is.
    for p in "${weak[@]}"; do
        pgrep -x "$p" >/dev/null 2>&1 || continue
        pkill -x "$p" >/dev/null 2>&1 \
            && ok "$p was still on screen and has been closed" \
            || warn "$p is still running — log out to be rid of it"
    done
}

# `qs` is how this project renders anything. Running it headless is a first
# class path, not a trick: the installer and a running session use the same
# code, so a fresh machine and a palette switch cannot drift apart.
#
# Quickshell leaves an instance directory behind for EVERY run and never removes
# one. Measured on the test machine after two days: 407 directories, 15 MB, in
# /run/user/<uid> — which is a tmpfs, so it is RAM. Each run adds exactly one.
#
# ⚠️ NOT `flock` ON instance.lock. That is the obvious way to tell a live
# instance from a dead one and it does not work: measured, `flock -n` succeeded
# on all 407 of them INCLUDING the directory belonging to the running shell, so
# a prune built on it would have deleted the live instance's socket out from
# under it.
#
# `qs list` names the instances that are actually alive. Anything else under
# by-id/ belongs to a process that is gone.
prune_instances() {
    local dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/by-id"
    [[ -d "$dir" ]] || return 0
    command -v qs >/dev/null || return 0

    local live
    # ⚠️ If the listing itself fails, do NOTHING. An empty answer would
    # otherwise read as "nothing is alive" and take the running shell with it.
    live="$(qs list --all --json 2>/dev/null)" || return 0
    [[ -n "$live" ]] || return 0
    live="$(printf '%s' "$live" | sed -n 's/.*"id": "\([^"]*\)".*/\1/p')"

    local d name
    for d in "$dir"/*/; do
        [[ -d "$d" ]] || continue
        name="$(basename "$d")"
        grep -qxF "$name" <<< "$live" && continue
        rm -rf "$d"
    done
}

# One helper for every tool, rather than one function per tool hardcoding its
# own name — there were two copies of this, in common.sh and in bin/bhctl, and
# adding the compositor generator would have meant editing both.
run_tool() {
    local tool="$1"
    local log="/tmp/buchhwin-$tool.log"
    command -v qs >/dev/null || { warn "quickshell not installed yet; skipping $tool"; return 0; }
    if ! BUCHHWIN_TOOL="$tool" QT_QPA_PLATFORM=offscreen \
            timeout 60 qs -p "$REPO_DIR/shell" >/dev/null 2>&1; then
        warn "$tool pass failed — run 'bhctl $tool apply' after logging in"
        return 1
    fi
    # The tools exit 0 even when they abort, so their own report is the only
    # place a failure shows. Surfacing it here is the difference between a
    # warning and a desktop that quietly has no colours.
    if [[ -f "$log" ]] && grep -q 'ABORT' "$log"; then
        warn "$tool aborted: $(grep -m1 -A1 'ABORT' "$log" | tail -1 | sed 's/^ *//')"
        return 1
    fi
    return 0
}

render() { run_tool render; }
