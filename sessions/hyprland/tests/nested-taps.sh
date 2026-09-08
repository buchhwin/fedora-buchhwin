#!/usr/bin/env bash
#
# A control inside a surface that also answers a press must KEEP the press.
#
# ⚠️⚠️ THIS IS ONE FAULT THAT REACHED HIM THREE TIMES IN ONE DAY. A TapHandler's
# default `gesturePolicy` is `DragThreshold`, which takes a PASSIVE grab: the
# press keeps travelling, so a handler on the surface underneath answers the
# same click. Every one of these was reported as the inner control being wrong:
#
#   the chevron on a quick-panel tile   opened the list AND flipped the radio
#   play in the hovered island          played AND opened the quick panel
#   the icon on a level row             would have muted AND jumped the volume
#
# In all three the OUTER handler is correct and deliberate — one of them is his
# own instruction, "es soll egal sein, wo man in dem Fenster hinklickt". What    # english-ok: the instruction, quoted
# was missing is the inner one taking an exclusive grab.
#
# ⚠️ IT CHECKS THREE NAMED PLACES AND SAYS SO, RATHER THAN GUESSING AT ALL OF
# THEM. Deciding "is this TapHandler nested inside another one" from text means
# tracking braces through a QML file, and a checker that reads the wrong block
# invents work — which rule 4 calls worse than missing something. These three
# are the nestings this shell actually has; a fourth gets a line here the day
# somebody writes it, and the note above tells them why.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
fail=0

# file | the control | a line that must be within a few lines of a TapHandler
CASES="
shell/ui/quick/Tile.qml|the chevron on a tile|root.expandClicked()
shell/ui/notch/NotchWide.qml|play in the island|Services.Media.toggle()
shell/ui/common/LevelRow.qml|the icon on a level row|root.iconTapped()
"

while IFS='|' read -r file what marker; do
    [[ -n "${file// }" ]] || continue
    printf '  %-38s ' "$what"

    if [[ ! -f "$file" ]]; then
        printf '%sFAIL%s  no such file: %s\n' "$red" "$off" "$file"; fail=1; continue
    fi

    # ⚠️ THE TEXT GOES INTO A VARIABLE FIRST. `grep -q` at the head of a pipe
    # exits on its first match, the writer takes SIGPIPE, and under pipefail the
    # whole pipeline reports failure — a trap tests/pipefail-grep.sh exists for.
    text="$(cat "$file")"

    # The handler that owns this marker: the `gesturePolicy` has to be in the
    # same TapHandler block, so the window is the few lines above the marker.
    block="$(grep -B 6 -F "$marker" <<< "$text" || true)"

    if ! grep -q 'TapHandler' <<< "$block"; then
        printf '%sFAIL%s  no TapHandler around "%s"\n' "$red" "$off" "$marker"; fail=1; continue
    fi
    if grep -q 'gesturePolicy' <<< "$block"; then
        printf '%sok%s    exclusive grab\n' "$green" "$off"
    else
        printf '%sFAIL%s  the press also reaches the surface underneath\n' "$red" "$off"
        fail=1
    fi
done <<< "$CASES"

if (( fail )); then
    cat <<'EOF'

  A TapHandler inside something that also answers a press needs

      gesturePolicy: TapHandler.WithinBounds

  so it takes an exclusive grab and the press stops there. Without it BOTH
  handlers fire, and the symptom is always the inner control looking wrong —
  a chevron that also switches the radio off, a play button that also opens
  the quick panel.
EOF
    exit 1
fi

echo "  every nested press stays where it was aimed"
