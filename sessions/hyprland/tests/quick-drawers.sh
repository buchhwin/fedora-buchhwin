#!/usr/bin/env bash
# The quick panel's drawer names exist in TWO places, and they must agree.
#
#   readonly property var drawers: ["wifi", "bt", "sound", "mic", "disks"]
#   sourceComponent: root.open === "wifi" ? networkList : …
#
# ⚠️ WHY A NAME THAT IS IN ONE AND NOT THE OTHER IS WORSE THAN A CRASH. The
# loader is `active: root.open !== ""`, so a name the ternary does not know
# opens an ACTIVE loader holding NOTHING: the panel grows by a few pixels and
# shows an empty band. That is indistinguishable on screen from B68 — "wenn man  # english-ok: the report, quoted
# einklappt bleibt die neue Größe" — so the failure mode of a typo here is a     # english-ok: the report, quoted
# bug report about something else entirely.
#
# The other direction is quieter still: a component in the ternary that is not
# in the list can never be opened, because `show()` filters against the list.
# A drawer nobody can reach is rule 5's "key with no reader" wearing a hat.
#
# ⚠️ STATIC ON PURPOSE. This needs no session, so it runs in CI where the
# functional half cannot.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
ok()  { printf '  %sok%s   %s\n'   "$green" "$off" "$1"; }
bad() { printf '  %sFAIL%s %s\n'   "$red"   "$off" "$1"; fail=1; }

F=shell/ui/quick/QuickSettings.qml
[[ -f "$F" ]] || { bad "$F is missing"; exit 1; }

# ⚠️ READ THE FILE INTO A VARIABLE FIRST. `sed file | grep -q` under pipefail
# aborts the writer with SIGPIPE on the first match, and the whole pipeline
# reports failure — precisely when the match is early in a long file. A checker
# lost its most important file that way and read as clean.
src="$(cat "$F")"

# The declared list.
list_line="$(grep -m1 'property var drawers:' <<< "$src" || true)"
if [[ -z "$list_line" ]]; then
    bad "no 'drawers' list found — did it get renamed?"
    exit 1
fi
mapfile -t declared < <(grep -oE '"[a-z]+"' <<< "$list_line" | tr -d '"' | sort -u)

# The names the loader can actually build. Only the ternary that chooses a
# drawer component, not every quoted string in the file.
mapfile -t wired < <(
    grep -oE 'root\.open === "[a-z]+" \? [a-zA-Z]+' <<< "$src" \
        | grep -oE '"[a-z]+"' | tr -d '"' | sort -u
)

if (( ${#declared[@]} == 0 )); then
    bad "the drawers list parsed as empty"
    exit 1
fi
if (( ${#wired[@]} == 0 )); then
    bad "no drawer components found in the loader's ternary"
    exit 1
fi

ok "the list declares ${#declared[@]}: ${declared[*]}"
ok "the loader can build ${#wired[@]}: ${wired[*]}"

for n in "${declared[@]}"; do
    if [[ " ${wired[*]} " == *" $n "* ]]; then
        ok "\"$n\" is declared and has a component"
    else
        bad "\"$n\" is offered but the loader cannot build it — it would open empty"
    fi
done

for n in "${wired[@]}"; do
    if [[ " ${declared[*]} " != *" $n "* ]]; then
        bad "\"$n\" has a component but is not in the list — nothing can open it"
    fi
done

# ⚠️ AND THE GUARD ITSELF HAS TO BE THERE. Without the indexOf check in show(),
# the list is documentation rather than a guard, and every argument above is
# about a list nothing enforces.
if grep -q 'root.drawers.indexOf(which) < 0' <<< "$src"; then
    ok "show() rejects a name that is not in the list"
else
    bad "show() no longer filters against the list — an unknown name opens an empty drawer"
fi

exit "$fail"
