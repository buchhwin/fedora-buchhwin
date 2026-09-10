#!/usr/bin/env bash
#
# install.sh must run from top to bottom.
#
# ⚠️ THE FAULT THIS EXISTS FOR. `lib/20-base.sh` referenced `DRY_RUN`, which the
# predecessor defines and this repository does not — the line came across with
# the `defaultyes` block it was wrapped in. Under `set -u` (lib/common.sh:9) an
# unbound name inside `(( ))` is fatal to a non-interactive shell, so phase_base
# exited 127 halfway through and desktop, apps, fonts, cursors, shell, services
# and summary never ran. A fresh machine got the base packages and nothing else.
#
# It survived a green CI because CI never ran install.sh — every other suite
# reads the repository or starts quickshell. `shellcheck -S warning` did not
# report it either, which is the second reason this check reads the exit code of
# a real run rather than trusting a linter.
#
# ⚠️ WHY THIS IS SAFE TO RUN ANYWHERE. Three separations, and all three matter:
#
#   1. Every command that would touch the machine — sudo, dnf, systemctl, rpm,
#      flatpak, curl, ping — is replaced by a stub earlier on PATH. The `sudo`
#      stub exits without running its arguments, so a `sudo tee /etc/...` writes
#      nothing; it still consumes the heredoc, which is what keeps the parse
#      identical to a real run.
#   2. HOME and the four XDG directories point into a temporary tree, so the
#      files the installer legitimately writes land there.
#   3. It runs a COPY of the repository. phase_shell writes
#      shell/theme/palettes/index.txt back into REPO_DIR, and a test that edits
#      the working tree it is testing is a test nobody can trust twice.
#
# preflight is skipped on purpose: its whole job is to `die` on a machine that
# is not Fedora 44, which is most machines this ever runs on, including the CI
# runner. It is covered separately below, where only the failure MODE is
# checked rather than the exit code.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
repo="$PWD"

fail=0
tmp="$(mktemp -d)" || exit 2
trap 'rm -rf "$tmp"' EXIT

# Taken BEFORE anything runs, so the last check compares against the real
# starting state rather than against an assumption about it.
idx_before=""
[[ -f shell/theme/palettes/index.txt ]] && idx_before="$(cksum < shell/theme/palettes/index.txt)"

# ---------------------------------------------------------------- the stubs
bin="$tmp/bin"; mkdir -p "$bin"
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$bin/$1"; chmod +x "$bin/$1"; }

# ⚠️ `cat >/dev/null` rather than a bare `exit 0`: several callers pipe a
# heredoc into `sudo tee`, and a stub that exits immediately closes the pipe
# early. The write still goes nowhere — sudo's arguments are never executed.
#
# ⚠️⚠️ EXCEPT systemctl, AND LEAVING THAT OUT HID THE WORST FAULT THIS INSTALLER
# HAS SHIPPED. A `sudo` that returns 0 without running anything means every
# privileged command succeeds, always — so `sudo systemctl enable sddm.service
# || die` could not fail here, and the suite reported the installer running to
# the end while on a real Fedora KDE machine it aborted in phase two.
#
# systemctl is passed through to its own stub, which is safe: the stub is first
# on PATH and touches nothing. Everything else still goes nowhere.
stub sudo     'case "$1" in
  systemctl) shift; exec systemctl "$@" ;;
esac
cat >/dev/null 2>&1; exit 0'
stub dnf      'exit 0'
# ⚠️ THE STUB ANSWERS THE WAY A FEDORA KDE MACHINE DOES, WHICH IS THE WHOLE
# POINT. SDDM is already enabled there, and `systemctl enable sddm.service` then
# FAILS: the unit carries `Alias=display-manager.service`, systemd will not
# overwrite that symlink, and it exits non-zero. A blanket `exit 0` describes a
# machine nobody installs onto.
#
# So `is-enabled sddm` says yes and `enable sddm` refuses, exactly as measured
# from the report that came back from a real install. The installer has to reach
# the end anyway — which means checking before enabling, which is what
# lib/65-greeter.sh now does. Re-introduce an unconditional enable and this run
# goes red instead of a laptop doing it.
stub systemctl 'case " $* " in
  *" is-enabled "*)
      case " $* " in *sddm*) exit 0 ;; *) exit 1 ;; esac ;;
  *" enable "*)
      case " $* " in
          *sddm*)
              echo "Failed to enable unit: File /etc/systemd/system/display-manager.service already exists." >&2
              exit 1 ;;
      esac ;;
esac
exit 0'
# ⚠️ `rpm -q sddm` AND `rpm -q plasma-desktop` MUST ANSWER "INSTALLED", and the
# blanket `exit 1` that stood here is why three phases were never reached.
# phase_greeter calls `die` when SDDM is missing, which is right on a real
# machine — preflight refuses to start without it — but in a sandbox where
# nothing is installed it aborted the run, so Login screen, Shell and tools and
# Done were never exercised at all. The stub now answers for the two packages
# this profile REQUIRES to exist and says "not installed" for everything else,
# which is the honest shape of the machine it is pretending to be.
stub rpm      'case " $* " in *" sddm "*|*" plasma-desktop "*) exit 0 ;; *) exit 1 ;; esac'
stub flatpak  'exit 0'
# No network, deliberately: the two downloads must degrade to a warning rather
# than to a broken run. That is a claim about the installer, so it is exercised.
stub curl     'exit 1'
stub ping     'exit 0'
# Brave is not running, so the profile branch is the one that gets taken.
stub pgrep    'exit 1'
stub fc-cache 'exit 0'
stub xdg-mime 'exit 0'
stub xdg-user-dirs-update 'exit 0'
stub localectl 'exit 0'
stub xdg-user-dir 'echo "$HOME/Pictures"'
# phase_shellenv reads the current login shell and may change it. `getent`
# answers with a bash shell so the change branch is the one exercised; `chsh`
# succeeds without touching /etc/passwd.
stub getent   'echo "test:x:1000:1000::/home/test:/bin/bash"'
stub chsh     'exit 0'

# ------------------------------------------------------------- the sandbox
home="$tmp/home"; mkdir -p "$home"
src="$tmp/repo"
mkdir -p "$src"
# git ls-files rather than cp -r: it copies exactly what is tracked, so a stray
# build artefact or a wallpaper folder cannot change what is being tested.
# ⚠️ --cached --others --exclude-standard, not a bare `git ls-files`: a file
# that is new and not yet added is still part of what would be installed, and a
# bare listing makes it invisible. That mistake made three checks lie once.
#
# ⚠️ AND THE `find` FALLBACK IS NOT A NICETY. `git ls-files` answers with
# nothing outside a checkout, and the working copy on the test VM is an rsync
# WITHOUT .git — so the git form alone would have copied an empty tree and then
# reported that install.sh ran perfectly, having run nothing at all. That is
# exactly how tests/english.sh printed a green tick over zero files for a whole
# session. Same guard, same reason.
files="$(git ls-files --cached --others --exclude-standard 2>/dev/null)"
if [[ -z "$files" ]]; then
    files="$(find . -type f -not -path './.git/*' -printf '%P\n' 2>/dev/null)"
fi
[[ -n "$files" ]] || { echo "  found no files to copy — cannot test"; exit 2; }
printf '%s\n' "$files" | while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    mkdir -p "$src/$(dirname "$f")"
    cp -p "$f" "$src/$f"
done
# ⚠️ install-hyprland.sh, NOT install.sh, AND THAT RENAME MADE THIS TEST INERT.
# The standalone repository had install.sh; the monorepo renamed it when the two
# sessions moved under sessions/ and nothing updated this line. The guard below
# then exited 2 on every run — "cannot test" — which CI reports as a skip. So
# the one suite that runs the installer from top to bottom has not actually run
# since the merge, and every fault it exists to catch went unseen.
[[ -f "$src/install-hyprland.sh" ]] || { echo "  the copy has no install-hyprland.sh — cannot test"; exit 2; }
chmod +x "$src/install-hyprland.sh" "$src/bin/bhctl" 2>/dev/null

run_installer() {   # $@ = extra install.sh arguments; $SYSFS = fake /sys, if any
    env -i \
        PATH="$bin:/usr/bin:/bin" \
        HOME="$home" \
        XDG_CONFIG_HOME="$home/.config" \
        XDG_DATA_HOME="$home/.local/share" \
        XDG_STATE_HOME="$home/.local/state" \
        XDG_RUNTIME_DIR="$tmp/run" \
        BUCHHWIN_SYSFS="${SYSFS:-$tmp/sysfs-empty}" \
        TERM=dumb \
        bash "$src/install-hyprland.sh" "$@" </dev/null
}
# ⚠️ `</dev/null` IS LOAD-BEARING. The `sudo` stub drains stdin, so that a
# heredoc piped into `sudo tee` is consumed exactly as it would be in a real
# run — and with the suite's own stdin attached, that `cat` waits for an EOF
# that never comes and the whole thing hangs at the first `sudo` outside a
# heredoc. phase_shellenv's `sudo chsh` is the one that finds it.
#
# It is also the honest shape: a non-interactive install has no terminal, which
# is exactly the case gpu_secureboot's `[[ -t 0 ]]` guard is written for.
# ⚠️ AN EMPTY FAKE /sys BY DEFAULT, not the real one. Reading the host's actual
# PCI bus would make every assertion below depend on what the machine running
# the test happens to contain — green on a laptop with no NVIDIA and red on one
# with, for reasons that have nothing to do with the code.
mkdir -p "$tmp/sysfs-empty/bus/pci/devices"

# ------------------------------------------------- 1. it reaches the end
printf '  %-44s ' "install-hyprland.sh runs to the end"
out="$(run_installer --skip preflight 2>&1)"; rc=$?
if (( rc == 0 )); then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mexit %d\033[0m\n' "$rc"
    printf '%s\n' "$out" | tail -15 | sed 's/^/      /'
    fail=1
fi

# ⚠️ THE EXIT CODE ALONE IS NOT ENOUGH, and that is the whole lesson of the
# fault above. `run_phase` is `should_run "$1" && "phase_$1"; return 0` — it
# swallows a phase's return value on purpose, so that an `--only` run exits 0.
# A phase that never ran and a phase that ran perfectly both leave rc=0 behind.
# The section headings are the evidence that each one was actually entered.
#
# ⚠️ Matched with a regexp, not `grep -F "==> $sect"`. `section()` prints
# `%s==>%s %s` with the colour and the reset code as separate arguments, so the
# bytes on the line are `==>` `ESC[0m` ` ` `Base system` — a fixed-string search
# for "==> Base system" finds nothing and reports ten phases missing on a run
# that was perfectly fine. Measured with `cat -A` rather than guessed at.
#
# ⚠️ "Login screen" IS IN THIS LIST AND HAS TO BE. phase_greeter is the one
# phase whose failure cannot be discovered from inside the desktop, and it is
# also the one that returns early in the most situations (no greetd, no copy, no
# config). A phase that quietly does not run at all is exactly what this loop is
# for — it caught `sddm` being in no package list at all.
# ⚠️ Graphics, Codecs AND Cursors ARE NOT IN THIS LIST ANY MORE, because those
# phases no longer exist. lib/10-gpu.sh is gone entirely: RPM Fusion, the NVIDIA
# akmod and the codec swap were decisions about the machine's graphics stack
# taken while installing a window manager, and the dwl session this profile is
# measured against has never made any of them. Cursors went with them — it
# fetched a third-party cursor tarball to replace Breeze, which the KDE base
# already provides and which env.lua points at.
for sect in "Base system" "Hyprland session on KDE" "Applications" \
            "Fonts" "Shell" "Theme" "Compositor" "Services" \
            "KDE login manager" "Shell and tools" "Done"; do
    printf '  %-44s ' "phase reached: $sect"
    if grep -qE "==>.* ${sect}\$" <<< "$out"; then
        printf '\033[38;5;114mok\033[0m\n'
    else
        printf '\033[38;5;203mnever printed its heading\033[0m\n'; fail=1
    fi
done

# The GPU phase and its three checks are gone. lib/10-gpu.sh no longer exists:
# nothing in this profile enables RPM Fusion, builds an akmod or swaps a mesa
# driver, so there is no branch left to prove takes both paths.

# ------------------------------------------- 2. no phase hit an unbound name
#
# The symptom the exit code showed was 127; the CAUSE is a name that `set -u`
# refused. Checking for the message as well means the next one is named in the
# output rather than left as a number to bisect. It also catches the case where
# the unbound name is inside a subshell, which does NOT take the installer down
# with it and would otherwise pass every check above.
printf '  %-44s ' "no unbound variable anywhere"
if unbound="$(printf '%s\n' "$out" | grep -i 'unbound variable')"; then
    printf '\033[38;5;203m%s\033[0m\n' "$(printf '%s' "$unbound" | head -1)"
    fail=1
else
    printf '\033[38;5;114mok\033[0m\n'
fi

# --------------------------------------------------- 3. preflight, separately
#
# It is expected to die here — "this installer is for Fedora" is the correct
# answer on a CI runner. Only the failure mode is checked: a phase may refuse,
# but it may not fall over on a name.
printf '  %-44s ' "preflight refuses without falling over"
pre="$(run_installer --only preflight 2>&1)"; prerc=$?
if grep -qi 'unbound variable' <<< "$pre"; then
    printf '\033[38;5;203munbound variable in preflight\033[0m\n'; fail=1
elif (( prerc == 127 )); then
    printf '\033[38;5;203mexit 127 — a command or a name is missing\033[0m\n'; fail=1
else
    printf '\033[38;5;114mok\033[0m\n'
fi

# -------------------------------- 4. the working tree is exactly as it was
#
# phase_shell writes shell/theme/palettes/index.txt into REPO_DIR. Running
# against a copy is what keeps that off the real tree, and this is the control
# on that claim rather than a comment asserting it.
#
# ⚠️ Compared by checksum, not by `git diff`. The rsync working copy on the test
# VM has no .git at all, so a git-only check would answer "clean" there without
# looking — the same hole the file listing above had to be given a fallback for.
printf '  %-44s ' "the working tree was not touched"
idx="$repo/shell/theme/palettes/index.txt"
if [[ ! -f "$idx" ]]; then
    printf '\033[38;5;114mok (no index.txt to disturb)\033[0m\n'
elif [[ "$(cksum < "$idx")" == "$idx_before" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mindex.txt was rewritten by the run\033[0m\n'; fail=1
fi

exit $fail
