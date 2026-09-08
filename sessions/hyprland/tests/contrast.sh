#!/usr/bin/env bash
#
# No element is drawn in exactly the colour of the surface it sits on.
#
# ⚠️⚠️ THE FINDING THIS GUARDS EXISTED FOR MONTHS AS A SENTENCE AND NOTHING ELSE.
# A comment in shell/theme/Theme.qml records a sweep that found "eight places
# where an element was drawn in exactly its parent's colour — measured at a
# contrast ratio of 1.000:1, which is to say invisible". Which eight it did not
# say, and no suite measured it, so the number could not be checked, reduced, or
# even reproduced. A measurement that survives only as prose is a rumour.
#
# ⚠️ IT IS THE PAIRS THAT MATTER, NOT THE PALETTE. Every one of the eleven
# palettes goes through the same ladder of role colours, so a pair that collapses
# collapses everywhere — but only in SOME palettes, because the ladder is built
# from the palette's own steps and those are not equally far apart. Checking one
# palette would be checking the luckiest one.
#
# ⚠️ AND THE STRUCTURAL CASE IS THE ONE TO CATCH. `pillBg` is `alpha(surface,
# panelOpacity)`. With `panelOpacity` at 1.0 that is `surface` exactly — so a
# pill on a surface-coloured card is invisible, and the setting that does it is
# one the user can move. Black mode sets that opacity to 1 and gets away with it
# only because its `bg` and `surface` differ; the palette mode has no such luck.
# That is the red probe at the bottom of this file.
#
# The pairs are named here rather than derived: "what sits on what" is a fact
# about the surfaces, and a checker that guessed it would be checking its own
# guess.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }
command -v jq >/dev/null || { echo "jq not installed"; exit 2; }

red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; dim=$'\e[38;5;245m'; off=$'\e[0m'

# element | ground | what it is, in a sentence somebody can act on
PAIRS=$(cat <<'TABLE'
pillBg|surface|a pill on a card
pillBg|panelBg|a pill on a panel
cardBg|panelBg|a card on a panel
panelBg|bg|a panel on the desktop
surfaceHigh|surface|a raised area on a card
surfaceHigher|surfaceHigh|the step above that
outline|surface|a border on a card
fgMuted|surface|secondary text on a card
fgDim|surface|the dimmest text on a card
TABLE
)

# ⚠️ `menuBg` IS NOT IN THIS TABLE and that is a gap, not an omission: the token
# dump does not carry it, so the pair cannot be measured from here. Named rather
# than quietly dropped — a menu over a panel is exactly the kind of pair this
# check exists for, and it is currently unchecked.

# ⚠️ THE THRESHOLD IS DELIBERATELY LOW. This is not a legibility check — text
# against its background is a different question with a different number. This
# asks only "can the eye find the edge at all", and 1.02 is about the smallest
# step that survives a photograph. Anything at 1.000 is the fault that was found.
MIN_RATIO=1.02

# WCAG relative luminance, then the ratio. Written out rather than approximated
# with a brightness average: the green channel carries most of it, and an average
# calls #0000ff and #004400 equally bright.
ratio() {
    awk -v a="$1" -v b="$2" '
        function chan(v,  c) { c = v / 255.0
            return (c <= 0.04045) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
        function lum(hex,  r, g, bl) {
            r  = chan(strtonum("0x" substr(hex, 2, 2)))
            g  = chan(strtonum("0x" substr(hex, 4, 2)))
            bl = chan(strtonum("0x" substr(hex, 6, 2)))
            return 0.2126 * r + 0.7152 * g + 0.0722 * bl
        }
        BEGIN {
            la = lum(a); lb = lum(b)
            hi = (la > lb) ? la : lb; lo = (la > lb) ? lb : la
            printf "%.3f", (hi + 0.05) / (lo + 0.05)
        }'
}

fail=0
checked=0

for p in shell/theme/palettes/*.json; do
    name="$(basename "$p" .json)"
    accent="$(jq -r '.accents[0]' "$p")"
    [[ -n "$accent" && "$accent" != "null" ]] || continue

    tmp="$(mktemp -d)"
    mkdir -p "$tmp/buchhwin"
    # ⚠️ `surfaceStyle: palette`, NOT the black default. Black mode forces
    # panelOpacity to 1 and sidesteps the whole question — measuring it would be
    # measuring the mode that is not affected.
    printf '{"theme":{"palette":"%s","accent":"%s"},"look":{"surfaceStyle":"palette"}}\n' \
        "$name" "$accent" > "$tmp/buchhwin/shell.json"

    rm -f /tmp/buchhwin-tokens.txt
    XDG_CONFIG_HOME="$tmp" BUCHHWIN_TOOL=dump-tokens QT_QPA_PLATFORM=offscreen \
        timeout 30 qs -p shell >/dev/null 2>&1
    rm -rf "$tmp"

    if [[ ! -f /tmp/buchhwin-tokens.txt ]]; then
        printf '  %-18s %sno tokens came back%s\n' "$name" "$red" "$off"
        fail=1; continue
    fi

    bad=""
    while IFS='|' read -r elem ground what; do
        [[ -n "${elem:-}" ]] || continue
        a=$(awk -v k="$elem"   '$1 == k { print $2; exit }' /tmp/buchhwin-tokens.txt)
        b=$(awk -v k="$ground" '$1 == k { print $2; exit }' /tmp/buchhwin-tokens.txt)
        # A token the dump does not carry is a stale PAIR, not a collision —
        # the same distinction tripwires.sh had to learn.
        [[ ${#a} -ge 7 && ${#b} -ge 7 ]] || { bad+="    stale pair: $elem/$ground"$'\n'; fail=1; continue; }
        checked=$((checked + 1))
        # ⚠️⚠️ A TOKEN MAY COME BACK AS `#AARRGGBB`, AND TAKING THE FIRST SIX
        # DIGITS OF THAT IS NONSENSE. `cardBg` is `#eb3b4252` — alpha eb, colour
        # 3b4252 — and slicing the front turns it into `#eb3b42`, a red-brown
        # that appears nowhere on screen. The first draft of this file did
        # exactly that and would have reported collisions and clearances that
        # were both invented. The colour is always the LAST six digits.
        r=$(ratio "#${a: -6}" "#${b: -6}")
        if awk -v r="$r" -v m="$MIN_RATIO" 'BEGIN { exit !(r < m) }'; then
            bad+="    $elem on $ground  $r:1  — $what"$'\n'
            fail=1
        fi
    done <<< "$PAIRS"

    if [[ -n "$bad" ]]; then
        printf '  %-18s %sFAIL%s\n%s' "$name" "$red" "$off" "$bad"
    else
        printf '  %-18s %sok%s\n' "$name" "$green" "$off"
    fi
done

if (( checked == 0 )); then
    echo "  ${red}no pair was measured at all${off} — this check proved nothing"
    exit 2
fi

printf '  %s%d pairs measured across the palettes%s\n' "$dim" "$checked" "$off"

if (( fail )); then
    cat <<'EOF'

  An element drawn in its ground's own colour is invisible, and no amount of
  padding brings it back. Either give it its own step on the ladder in
  shell/theme/Theme.qml, or stop drawing it.

  ⚠️ If the pair itself is wrong — the element does not actually sit on that
  ground any more — fix the table in this file. A stale pair reads as a
  collision and sends the next person to repaint something that was fine.
EOF
    exit 1
fi
