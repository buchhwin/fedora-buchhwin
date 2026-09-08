#!/usr/bin/env bash
#
# The foreign programs this desktop replaces are REMOVED, not mentioned.
#
# ⚠️⚠️ THIS FILE EXISTS BECAUSE A WARNING WAS MISTAKEN FOR A FIX. lib/30-desktop.sh
# used to print "waybar is installed … sudo dnf remove waybar" and carry on. On
# the lab VM waybar was installed AND running months later, drawing its own bar
# across the top of the screen with the machine's IP address in it — on every
# screenshot that left that VM. He saw it and asked what it was. Nobody had read
# the warning, and nothing was ever going to.
#
# Two halves, and they answer different questions:
#
#   1. STRUCTURAL, runs anywhere. Is there exactly one list, is every name on it
#      actually acted upon, and does the acting code have a caller? A function
#      nobody calls is the same debt as a key nobody reads.
#   2. FUNCTIONAL, needs the machine. Is one of them installed as something
#      nobody asked for, or — worse — still on screen right now?
#
# ⚠️ "Installed" and "on screen" are two different states. Removing the package
# does not close the window; the process keeps drawing from a binary that is no
# longer on disk. Both are asked.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
ok()  { printf '  %-46s %sok%s   %s\n'   "$1" "$green" "$off" "${2:-}"; }
bad() { printf '  %-46s %sFAIL%s %s\n'   "$1" "$red"   "$off" "${2:-}"; fail=1; }

LIST=packages/dnf-unwanted.txt

# --------------------------------------------------------------- 1 · structural
[[ -f "$LIST" ]] || { echo "no $LIST"; exit 1; }

# The same parser shape read_list() uses. Written into a variable first and then
# fed from it: a `grep -q` at the head of a pipe exits on its first match, the
# writer behind it takes SIGPIPE, and under `set -o pipefail` the whole pipeline
# reports failure — which this project has already been bitten by once.
names="$(grep -vE '^[[:space:]]*(#|$)' "$LIST" | sed 's/[[:space:]]*#.*//' | tr -d ' ')"
count="$(grep -c . <<< "$names")"

if [[ -n "$names" ]]; then
    ok "the list has names" "$count"
else
    bad "the list has names" "$LIST parses to nothing"
fi

# The remover exists, and something calls it. Both, because either alone is a
# green tick over a desktop that still has a second bar on it.
common="$(cat lib/common.sh)"
if grep -q '^remove_unwanted()' <<< "$common"; then
    ok "lib/common.sh defines remove_unwanted"
else
    bad "lib/common.sh defines remove_unwanted" "the remover is gone"
fi

callers="$(grep -ln '^[[:space:]]*remove_unwanted$' lib/[0-9][0-9]-*.sh 2>/dev/null || true)"
if [[ -n "$callers" ]]; then
    ok "a phase calls it" "$(tr '\n' ' ' <<< "$callers")"
else
    bad "a phase calls it" "remove_unwanted has no caller — nothing removes anything"
fi

# ⚠️ THE REMOVAL MUST NOT RUN EARLY, and this is a real fault rather than a
# style rule. dnf sweeps the dependencies that were only there for the package
# it removes; measured on the lab VM, removing waybar wanted to take twenty
# packages with it, one of them `playerctl` — which is on our own list in
# packages/dnf-sysadmin.txt. Called from phase_desktop it deletes a program this
# desktop ships. The caller has to be the phase that runs after every install.
#
# ⚠️ EVERY caller, not "one of them is the right one". The first draft asked
# whether 80-shellenv was among the callers, which stays green when the call is
# in BOTH phases — and the early one still does the damage. A check that a
# second, wrong caller cannot trip is a check that misses the fault.
early="$(grep -v '80-shellenv' <<< "$callers" | grep . || true)"
if [[ -z "$callers" ]]; then
    :                       # already reported above
elif [[ -z "$early" ]]; then
    ok "and only after the last install" "80-shellenv"
else
    bad "and only after the last install" \
        "also called from $(tr '\n' ' ' <<< "$early") — dnf would sweep packages we ship"
fi

# One list, not two. A second hardcoded copy is how a name added here quietly
# stops being handled over there.
hard="$(grep -rn 'waybar[ "]*fuzzel\|fuzzel[ "]*swaylock' \
        lib/ bin/ tests/ .github/ 2>/dev/null | grep -v "$LIST" || true)"
if [[ -z "$hard" ]]; then
    ok "no second copy of the list"
else
    bad "no second copy of the list" "$(head -1 <<< "$hard")"
fi

# --------------------------------------------------------------- 2 · functional
if ! command -v rpm >/dev/null; then
    printf '  %-46s skipped (not an rpm machine)\n' "nothing foreign is installed"
    exit "$fail"
fi

installed=""
running=""
while read -r p; do
    [[ -n "$p" ]] || continue
    if rpm -q "$p" >/dev/null 2>&1; then
        # ⚠️ "User" is his own choice and stays — the desktop says so and moves
        # on. Anything else arrived as somebody's recommendation and is the
        # fault this file is about.
        reason="$(dnf repoquery --installed --qf '%{reason}\n' "$p" 2>/dev/null | head -1)"
        [[ "$reason" == "User" ]] || installed+=" $p($reason)"
    fi
    pgrep -x "$p" >/dev/null 2>&1 && running+=" $p"
done <<< "$names"

if [[ -z "$installed" ]]; then
    ok "nothing foreign is installed"
else
    bad "nothing foreign is installed" "$installed — the installer did not remove it"
fi

if [[ -z "$running" ]]; then
    ok "and nothing foreign is on screen"
else
    bad "and nothing foreign is on screen" "$running is drawing right now"
fi

exit "$fail"
