#!/usr/bin/env bash
# B74 · the quick panel's "Show more" fold must NOT survive a reopen.
#
# His request, in his words: "der Show more Button soll nicht gespeichert      # english-ok: the request, quoted
# werden … dann das quickpanel erneut öffnen soll das wieder automatisch       # english-ok: the request, quoted
# geschlossen sein das Show more panel".                                       # english-ok: the request, quoted
#
# ⚠️ WHY THIS NEEDS A RUNNING SHELL AND CANNOT BE STATIC. The requirement is
# about the state BETWEEN two openings — fold it, close the panel, open it
# again — and no amount of reading QML says what the second opening renders. It
# is measured through the card's own height, which the shell reports over IPC.
# The check compares shut-against-open rather than either constant, so a future
# spacing change cannot make it lie.
#
# ⚠️ AND IT CHECKS BOTH DIRECTIONS. Making the fold forget its state is easy;
# the trap is doing it by deleting the setting, which would leave the row in the
# settings window pointing at nothing — rule 5 from the other side. So the
# stored key still has to SEED the fold, and that is checked with the key on.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; yellow=$'\e[38;5;179m'; off=$'\e[0m'
ok()   { printf '  %sok%s   %s\n'   "$green"  "$off" "$1"; }
bad()  { printf '  %sFAIL%s %s\n'   "$red"    "$off" "$1"; fail=1; }
skip() { printf '  %s--%s   %s\n'   "$yellow" "$off" "$1"; }

# ⚠️ EXIT 2 IS "CANNOT RUN HERE", NOT "FAILED". A CI lane once counted 2 as a
# failure and turned four green pushes red; the distinction is load-bearing.
command -v qs >/dev/null 2>&1 || { skip "quickshell is not installed"; exit 2; }
command -v jq >/dev/null 2>&1 || { skip "jq is not installed"; exit 2; }

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/buchhwin/shell.json"
[[ -f "$CFG" ]] || { skip "no shell.json on this machine"; exit 2; }

# ⚠️ --pid, NEVER -c buchhwin. A locked session runs a SECOND instance of the
# same config, so the name is ambiguous and every call answers "Target not
# found" — which reads like a missing verb. That cost a whole round once.
#
# ⚠️⚠️ AND IT IS SOURCED RATHER THAN RETYPED. This file used to carry its own
# copy of the lookup, which is rule 6's "a list may not exist twice" — and the
# copy was already missing half of it: `shell-ipc.sh` falls back to reading
# /proc when there is no unit, and skips any candidate carrying
# BUCHHWIN_MODE=lock. A shell started by hand, which is how half of this gets
# debugged, was invisible to the copy.
. "$(dirname "$0")/shell-ipc.sh"
bh_shell_pid >/dev/null || { skip "buchhwin-shell is not running"; exit 2; }

q() { bh_ipc call "$@" 2>&1; }

# ⚠️ AND THE VERB HAS TO EXIST BEFORE ITS ANSWER MEANS ANYTHING. `qs ipc call`
# prints its complaint on stdout and still exits 0 — measured — so a check that
# reads the exit code here would be blind by construction.
probe="$(q notch state)"
case "$probe" in
    *"not found"*|*"Function"*) skip "this shell has no notch IPC (older build?)"; exit 2 ;;
esac

card_h() { q notch size | awk '{print $2}'; }

ORIG="$(jq -r '.quick.showMore' "$CFG")"
restore() {
    jq ".quick.showMore=${ORIG}" "$CFG" > "$CFG.tmp" 2>/dev/null && mv "$CFG.tmp" "$CFG"
    q notch collapse >/dev/null 2>&1
}
trap restore EXIT

set_key() {
    jq ".quick.showMore=$1" "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
    sleep 1.2
}

open_panel() {
    q notch collapse >/dev/null
    sleep 0.5
    q notch tab 0 >/dev/null
    sleep 1.2
}

# ----------------------------------------------------- key off: starts folded up
set_key false
open_panel
shut_h="$(card_h)"
if [[ -z "$shut_h" ]]; then
    skip "the card reported no height — no page is open"
    exit 2
fi
ok "the panel opens with the fold shut (${shut_h}px)"

q notch fold >/dev/null
sleep 1.0
open_h="$(card_h)"
if [[ -n "$open_h" ]] && (( open_h > shut_h )); then
    ok "folding it open makes the card taller (${open_h}px)"
else
    bad "the fold changed nothing: ${shut_h} -> ${open_h:-?}"
fi

open_panel
again_h="$(card_h)"
if [[ "$again_h" == "$shut_h" ]]; then
    ok "reopening forgets the fold (${again_h}px)"
else
    bad "the fold survived a reopen: expected ${shut_h}, got ${again_h:-?}"
fi

# ------------------------------------------------ key on: the seed still works
# ⚠️ THIS IS THE HALF THAT CATCHES THE LAZY FIX. Deleting the key outright would
# pass everything above and quietly kill a setting that has its own row.
set_key true
open_panel
seeded_h="$(card_h)"
if [[ "$seeded_h" == "$open_h" ]]; then
    ok "with the setting on, the panel starts folded open (${seeded_h}px)"
else
    bad "the setting no longer seeds the fold: expected ${open_h:-?}, got ${seeded_h:-?}"
fi

q notch fold >/dev/null
sleep 1.0
seeded_shut="$(card_h)"
if [[ "$seeded_shut" == "$shut_h" ]]; then
    ok "and it can still be folded shut by hand (${seeded_shut}px)"
else
    bad "folding shut did not return to ${shut_h}, got ${seeded_shut:-?}"
fi

# ⚠️ THE FILE MUST NOT MOVE. Pressing the fold is a glance, not a decision — if
# it writes shell.json the panel is still remembering, just through another door.
now="$(jq -r '.quick.showMore' "$CFG")"
if [[ "$now" == "true" ]]; then
    ok "pressing the fold did not rewrite the setting"
else
    bad "the fold wrote to shell.json (key is now ${now}, expected true)"
fi

exit "$fail"
