#!/usr/bin/env bash
#
# One press, one write. A switch row may not answer the same press twice.
#
# ⚠️⚠️ THE FAULT THIS EXISTS FOR IS B20/B10, AND IT SURVIVED EVERY CHECK IN THIS
# REPOSITORY. Both settings/SettingRow.qml and settings/OutputRow.qml put a
# TapHandler across the WHOLE ROW — right, because a 44x24 switch at the end of a
# 700 px row is a target you miss — and common/Toggle.qml owned a TapHandler of
# its own, also right on its own terms. Press the label and one fires. Press the
# SWITCH and both do, and the second computes its new value from state the first
# has already written:
#
#     row-handler    current=false   -> writes true      (label)
#     toggle-handler v=false         -> writes false     (switch)
#     row-handler    current=false   -> writes true      (switch, again)
#
# Read out of the running shell's journal, one press per line. The value flipped
# and flipped straight back: on screen the bar disappeared for a single frame,
# and the file was rewritten with the value it already had.
#
# ⚠️ WHY NOTHING CAUGHT IT, and this is the part worth keeping. Every check this
# project has for switches calls the write path ONCE and directly:
# tests/switch-writes.sh drives all 191 rows through `Config.set` and all 191
# land; tools/revert-check.qml proves the value survives the file round trip.
# Both are correct and both are blind here, because neither has a pointer, and
# the fault only exists when two handlers see one press. A whole class of bug
# lives in the gap between "the function works" and "the press reaches exactly
# one function".
#
# ⚠️ IT IS ALSO WHY THE REPORT SAID "SOME". Pressing the label worked and         # english-ok: the report, quoted
# pressing the switch did not — the same row behaving two ways depending on where
# it was pressed, which reads as "manche switches gehen nicht".                   # english-ok: the report, quoted
#
# Static. No quickshell, no session, runs in CI.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
ok()  { printf '  %-56s \033[38;5;114mok\033[0m  %s\n' "$1" "${2:-}"; }
bad() { printf '  %-56s \033[38;5;203mFAIL\033[0m %s\n' "$1" "${2:-}"; fail=1; }

T=shell/ui/common/Toggle.qml
[[ -f "$T" ]] || { echo "  $T is gone — did the switch move?"; exit 2; }

# ⚠️ Comments stripped before every match. This file's whole subject is described
# at length in the headers of the three files it checks — including the words
# "TapHandler" and "onToggled" — and a checker that reads prose would fail on its
# own documentation. Same reason tests/theme-tokens.sh strips them.
tcode="$(sed 's://.*::' "$T")"

# ── the switch draws, it does not write ────────────────────────────────────
if grep -qE '^\s*TapHandler\s*\{' <<< "$tcode"; then
    bad "Toggle.qml carries no tap handler" "it has one — that is the second writer"
else
    ok "Toggle.qml carries no tap handler"
fi

# ⚠️ AND NO SIGNAL EITHER. Leaving `signal toggled` behind with nothing emitting
# it would be worse than the bug: QML says NOTHING about a handler for a signal
# that is never emitted, so a call site writing `onToggled:` would compile, look
# right, and never run. This project has already paid for that shape once, when
# a row wrote `options:` where `choices:` was meant and drew a label, a hint and
# an empty space.
if grep -qE '^\s*signal\s+toggled' <<< "$tcode"; then
    bad "Toggle.qml declares no toggled signal" "nothing emits it — a silent dead handler"
else
    ok "Toggle.qml declares no toggled signal"
fi

# ── every place that shows a switch ────────────────────────────────────────
# ⚠️⚠️ NO `sed file | grep -q` HERE, AND THE REASON IS THIS FILE'S OWN HISTORY.
# The first version selected with `sed 's://.*::' "$f" | grep -q …` under
# `set -o pipefail`, and it silently skipped settings/SettingRow.qml — the very
# file the bug was found in. `grep -q` exits at the FIRST match; on a long file
# `sed` is still writing, takes SIGPIPE, and `pipefail` hands the whole pipeline
# a non-zero status. So the pipeline reports FAILURE precisely when the match is
# found early in a big file. OutputRow.qml is 200 lines and passed; SettingRow
# is a thousand and vanished.
#
# ⚠️ AND IT FAILS IN THE DIRECTION NOBODY LOOKS: a checker that reports nothing
# reads as "clean". Only the missing line in the output gave it away.
#
# The text goes into a variable first; a here-string has no upstream to kill.
users=()
while IFS= read -r f; do
    stripped="$(sed 's://.*::' "$f")"
    grep -qE '^[[:space:]]*Toggle[[:space:]]*\{' <<< "$stripped" && users+=("$f")
done < <(find shell/ui -name '*.qml' | sort)

if (( ${#users[@]} == 0 )); then
    echo "  nothing instantiates Toggle — did the settings rows move?"
    exit 2
fi

for f in "${users[@]}"; do
    name="${f#shell/ui/}"
    code="$(sed 's://.*::' "$f")"

    # The row has to answer, or the switch is decoration and nothing writes at
    # all — the opposite failure, and just as silent.
    if grep -qE '^\s*TapHandler\s*\{' <<< "$code"; then
        ok "$name answers the press itself"
    else
        bad "$name" "shows a Toggle but has no TapHandler — nobody writes"
    fi

    # ⚠️ SCOPED TO THE Toggle BLOCK, not the file. `onToggled:` is a perfectly
    # good handler elsewhere in SettingRow.qml — the multi-pick menu uses one —
    # and a file-wide match would report that as a fault. Checking the wrong
    # thing confidently is how a checker starts inventing work.
    if awk '
        /^[[:space:]]*Toggle[[:space:]]*\{/ { inblock = 1; depth = 1; next }
        inblock {
            n = gsub(/\{/, "{"); m = gsub(/\}/, "}")
            depth += n - m
            if ($0 ~ /onToggled/) found = 1
            if (depth <= 0) inblock = 0
        }
        END { exit(found ? 0 : 1) }
    ' <<< "$code"; then
        bad "$name" "passes onToggled to a Toggle — the signal is gone, it never runs"
    else
        ok "$name passes no dead onToggled to the switch"
    fi
done

exit $fail
