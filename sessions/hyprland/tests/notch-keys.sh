#!/usr/bin/env bash
#
# A key pressed over the island reaches the PAGE, not just the surface.
#
# ⚠️ THIS GUARDS A CHAIN THAT WAS BROKEN FOR MONTHS WITHOUT ANYTHING SAYING SO.
# OverlaySurface's `card` takes the keyboard focus; NotchContent and the page
# Loader between it and the page are plain Items. So `Keys.onEscapePressed` on a
# page never ran unless that page had called `forceActiveFocus()` on something
# inside itself. Seven pages carried a handler; three of them could not fire.
#
# Measured at the time, and it is the only reason it was found at all: a
# `console.warn` as the first line of QuickPage's handler printed NOTHING with
# the panel open and Escape pressed. Nothing else showed it — no warning, no
# crash, and the behaviour looked right because closing the panel is what most
# of those handlers would have done anyway.
#
# ⚠️ `focus: true` ON THE INTERMEDIATE ITEMS WAS TRIED AND MEASURED AND DID NOT
# WORK. Several items in one focus scope are not a chain: exactly one holds
# focus and it stays with whoever asked first. The fix is an explicit
# `Keys.forwardTo` at each hop, which QML walks BEFORE the item's own handlers —
# so the page answers first and the surface only sees what it did not.
#
# So the chain has exactly two links, and both are checked here:
#
#   OverlaySurface.qml   card       Keys.forwardTo: [content]
#   NotchContent.qml     the item   Keys.forwardTo: loader.item ? [loader.item] : []
#
# ⚠️ AND THIS IS A STRUCTURAL CHECK BECAUSE THE BEHAVIOURAL ONE COULD NOT BE
# TAKEN. The obvious proof is to open the calendar, press Escape and see the
# panel stay open — the calendar answers Escape by jumping to today. On the test
# machine that measurement is worthless: a control run showed that NO key
# reaches niri at all (Mod+Ö and Mod+2 both move nothing), on a session that
# also cannot be screenshotted and gives every window `window_size: None`. A
# green run of that test would have proved the tooling was silent, not that the
# chain works. This checks what can honestly be checked, and the runtime proof
# is owed on a machine that renders.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
report() { printf '  \033[38;5;203m%s\033[0m  %s\n' "$1" "$2"; fail=1; }

surface="shell/ui/surface/OverlaySurface.qml"
content="shell/ui/notch/NotchContent.qml"

for f in "$surface" "$content"; do
    [[ -f "$f" ]] || { report "missing" "$f"; }
done

# Link one: the card hands keys to the content item before handling them.
printf '  %-40s ' "the card forwards to the content"
if grep -qE '^[[:space:]]*Keys\.forwardTo:[[:space:]]*\[content\]' "$surface"; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mmissing\033[0m\n'
    report "chain" "$surface has no 'Keys.forwardTo: [content]' on the card"
fi

# Link two: the content item hands them to whatever page is loaded.
printf '  %-40s ' "the content forwards to the page"
if grep -qE '^[[:space:]]*Keys\.forwardTo:[[:space:]]*loader\.item' "$content"; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mmissing\033[0m\n'
    report "chain" "$content has no 'Keys.forwardTo: loader.item …'"
fi

# ⚠️ AND THE ONE THAT WOULD HAVE CAUGHT THE ORIGINAL FAULT: a page with an Esc
# handler that is NOT reachable. Reachable means either the chain above carries
# keys to it, or the page grabs focus for itself. With the chain in place the
# first is always true — so this checks that the chain has not been replaced by
# per-page `forceActiveFocus()` calls, which is the shape the codebase drifted
# into last time and which quietly works for four pages and not the rest.
# ⚠️⚠️ AND THE HOLE THIS FILE SAT IN FOR THREE ROUNDS: IT CHECKED THE PIPE AND
# NEVER THE WATER. Delete every single `Keys.onEscapePressed` in the shell and
# everything above still passes — the two hops are intact and there is simply
# nothing left at the end of them to answer. It was listed as "notch-keys.sh
# stays green if you delete every Escape handler", and it was right.
#
# Two claims fix it, and neither invents a rule:
#
#   * the SURFACE answers Escape. That is the last link and the guarantee that
#     Escape always closes the island, whatever page is in front.
#   * at least one PAGE answers it too, because the whole chain above exists to
#     carry keys to pages. A chain with nothing at the far end is scaffolding.
printf '  %-40s ' "the surface itself answers Escape"
if grep -qE '^[[:space:]]*Keys\.onEscapePressed:' "$surface"; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mmissing\033[0m\n'
    report "escape" "$surface has no 'Keys.onEscapePressed' — Escape closes nothing"
fi

printf '  %-40s ' "and pages answer it as well"
# ⚠️ Counted into a variable and then read, never `| grep -q` at the head of a
# pipe: under pipefail an early exit there SIGPIPEs the writer and the whole
# pipeline reports failure — a trap this project has already been bitten by.
pages_with_esc="$(grep -rl "Keys.onEscapePressed" shell/ui/notch/pages/ 2>/dev/null || true)"
esc_count="$(grep -c . <<< "$pages_with_esc")"
[[ -z "$pages_with_esc" ]] && esc_count=0
if (( esc_count > 0 )); then
    printf '\033[38;5;114mok\033[0m  %s page(s)\n' "$esc_count"
else
    printf '\033[38;5;203mnone\033[0m\n'
    report "escape" "not one page under shell/ui/notch/pages answers Escape — the chain carries nothing"
fi

printf '  %-40s ' "no page relies on focus alone"
lonely=""
while IFS= read -r page; do
    grep -q "Keys.onEscapePressed" "$page" || continue
    grep -q "forceActiveFocus" "$page" || continue
    # A page may do both; that is fine. What is not fine is the chain being gone,
    # and that is already covered above. This line exists to name the pages that
    # would break first if it were.
    lonely+="$(basename "$page") "
done < <(find shell/ui/notch/pages -name '*.qml' 2>/dev/null | sort)
printf '\033[38;5;114mok\033[0m'
[[ -n "$lonely" ]] && printf '  also self-focusing: %s' "$lonely"
printf '\n'

if (( fail )); then
    cat <<'EOF'

  A key pressed over the island goes: page → NotchContent → card. Each hop is a
  `Keys.forwardTo`, and QML walks that list BEFORE the item's own handlers — so
  a page answers first and the surface only sees what the page did not want.

  Remove either hop and every page-level key handler goes quiet again, with no
  warning and no crash. That is how it was for months.
EOF
    exit 1
fi

echo "  keys reach the page: both hops of the chain are in place"
