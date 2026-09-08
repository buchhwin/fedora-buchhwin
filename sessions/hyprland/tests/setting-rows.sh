#!/usr/bin/env bash
#
# Every setting has EXACTLY ONE row in the settings window.
#
# ⚠️ THIS IS THE OTHER HALF OF tests/key-readers.sh, and the two together are the
# whole of "alles einstellbar". That one asks whether anything READS a key — it   english-ok: the brief, quoted
# found five that nothing did. This one asks whether anything OFFERS it. A key
# with a reader and no row is a setting you can only reach by editing JSON; a row
# with no key is a control that writes into nothing.
#
# ⚠️ IT CANNOT BORROW key-readers.sh's EXTRACTION, and that is worth spelling out
# because the two files look like they should share one. key-readers.sh matches
# LEAF NAMES: `enabled` exists four times, `monitors` five, and `height`,
# `width`, `size`, `name`, `on` and `mode` more than once each — so `grep -qw
# enabled` is true no matter which one you meant. For "one row per setting" that
# is useless: the question is precisely which of the four. This walks the adapter
# and builds full dotted paths, `input.touchpad.tap` included.
#
# Three directions, and all three are real failures that have happened in this
# project in some form:
#
#   missing    a key with no row      → the promise is broken, quietly
#   twice      a key with two rows    → two controls that can disagree
#   invented   a row with no key      → a control that writes into nothing
#
# The fourth failure — a row labelled for one key that WRITES another — has no
# check here on purpose. It cannot happen: SettingRow reads and writes through
# its `key` and nothing else, so there is no second place for the two to drift
# apart. See shell/ui/settings/SettingRow.qml.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v python3 >/dev/null || { echo "python3 not installed"; exit 2; }

# ─────────────────────────────────────────────────────────────────────────────
# ⚠️ SETTINGS THAT DO NOT HAVE A ROW YET. IT IS EMPTY, AND THAT IS THE POINT.
#
# It is checked in BOTH directions, so a key that gains a row and is not struck
# out fails just as loudly as one that never gets a row at all. That is what
# stops a list like this rotting into a set of excuses — and it has already
# done its job twice: it went red when the six new pages landed and the list
# still claimed a hundred and eight things were owed.
#
# Empty therefore means something exact: **every setting in shell.json can be
# reached from the settings window.** Not "most of them", not "the ones anyone
# thought of" — all 123, counted by this script from the adapter itself.
#
# ⚠️ IT WILL NOT STAY EMPTY, AND THAT IS ALSO THE POINT. Media, Clock & Date and
# Lock Screen have no section in shell.json at all, and neither does the tempo
# of an animation. Those pages need NEW keys — and the moment one is declared
# without a row, this list is where it shows up. Add the key and the row in the
# same change, or write it here with a reason.
PENDING=""

# Settings that will never be a row, each named rather than matched by a
# pattern — a pattern is how an exception list stops being read.
#
#   version   the migration stamp, not a setting
#   binds     63 key bindings; a list with its own view, not a row. ⚠️ And an
#             empty list means "the built-in set", so "no bindings at all" needs
#             an explicit marker rather than an empty box (see Config.qml).
#   rebinds   the overrides that move a binding off the key it ships on, as
#             {from,to} pairs. Same view as `binds` and for the same reason —
#             ⚠️ and it is separate from `binds` deliberately: `binds` is
#             all-or-nothing, so rebinding by writing that list would freeze
#             every other binding at whatever it was that day. See Config.binds.
#   outputs   one object per monitor, with a scale and a mode inside it
#   wallpaper.paletteFrom
#             which image the palette is derived from when that is not the one
#             on screen. Machinery, not a setting: the slideshow writes it to
#             pin the colours and choosing a wallpaper clears it again. A text
#             field holding a file:// path that something else overwrites would
#             be a row you can only get wrong.
#   session.apps
#             what was open last time, maintained by the shell while you work.
#             Machinery rather than a setting: a text field somebody edits while
#             a debounced writer overwrites it three seconds later is a control
#             that loses every argument it has with itself.
#   wallpaperPerScreen
#             B75 · the picture assigned to each monitor, as {name,image} pairs.
#             It HAS a control — the "All screens / Per screen" segment on the
#             wallpaper page — but not a `key:` row, and deliberately: the
#             segment reads "is this list empty" and the assignments themselves
#             are made with Mod+Shift+W on the screen you are standing on. A
#             text field holding a JSON array beside that would be a second way
#             to write the same state, and the two would drift.
#             ⚠️ It is listed here rather than left to the "no row" branch so
#             that a key which really is unreachable still gets reported.
EXEMPT="version
binds
rebinds
outputs
wallpaper.paletteFrom
wallpaperPerScreen
session.apps"

paths="$(python3 - shell/config/Config.qml <<'PY'
import re, sys

# Walk the JsonAdapter and emit one full dotted path per leaf. Brace counting
# rather than indentation: `input` nests a second level, and the day a third
# appears this still answers correctly.
src = open(sys.argv[1]).read().splitlines()
paths, stack, depth, inside = [], [], 0, False
pending_section = pending_depth = None

sec_re  = re.compile(r'property\s+JsonObject\s+([A-Za-z_][A-Za-z0-9_]*)\s*:')
leaf_re = re.compile(r'property\s+(?:list<[a-z]+>|[a-z]+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:')

for raw in src:
    line = re.sub(r'//.*$', '', raw)      # a comment may hold braces or prose
    if not inside:
        if 'JsonAdapter' in line and '{' in line:
            inside, depth = True, 0
        continue
    m = sec_re.search(line)
    if m:
        pending_section, pending_depth = m.group(1), depth
    else:
        m2 = leaf_re.search(line)
        if m2:
            paths.append('.'.join(stack + [m2.group(1)]))
    for _ in range(line.count('{')):
        depth += 1
        if pending_section is not None and depth == pending_depth + 1:
            stack.append(pending_section)
            pending_section = None
    for _ in range(line.count('}')):
        if stack and len(stack) == depth:
            stack.pop()
        depth -= 1
print('\n'.join(paths))
PY
)"

[[ -n "$paths" ]] || { echo "  could not read any settings out of Config.qml"; exit 1; }

# ⚠️ `^[[:space:]]*key:` and not just `key:`, so that SettingRow's own
# declaration — `property string key: ""` — is not counted as a row.
rows="$(grep -rhoE '^[[:space:]]*key:[[:space:]]*"[^"]+"' shell/ui/settings/ \
        | sed -E 's/.*"([^"]+)".*/\1/')"

want="$(comm -23 <(sort -u <<< "$paths") <(sort <<< "$EXEMPT"))"

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "no row without a setting"

invented="$(comm -13 <(sort -u <<< "$paths") <(sort -u <<< "$rows"))"
# ⚠️ TWO ROW TYPES NOW, AND THIS IS NOT A LOOSENING. The App Theming page lays
# its thirteen programs out as a table, so they are ThemingRows — a different
# LAYOUT, not a different promise: a ThemingRow reads and writes through one
# dotted `key` exactly as a SettingRow does, and declares it as a literal on its
# own line. What the count asks is unchanged — every declaring block has a key
# and every key belongs to a block — it just knows both spellings of a block.
#
# A row is a SettingRow, and a SettingRow without a key is the same fault seen
# from the other side — it would not appear above, because it names nothing.
missing_key=""
while read -r f; do
    [[ -z "$f" ]] && continue
    declared="$(grep -cE '^[[:space:]]*(Setting|Theming)Row[[:space:]]*\{' "$f")"
    keyed="$(grep -cE '^[[:space:]]*key:[[:space:]]*"' "$f")"
    [[ "$declared" == "$keyed" ]] \
        || missing_key+="$f: $declared rows, $keyed keys"$'\n'
done < <(find shell/ui/settings -name '*.qml')

if [[ -n "$invented$missing_key" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    [[ -n "$invented" ]] && sed 's/^/      no such setting: /' <<< "$invented"
    [[ -n "$missing_key" ]] && sed 's/^/      /' <<< "${missing_key%$'\n'}"
    cat <<'WHY'

  A control that writes into nothing. JsonAdapter drops keys it does not
  declare, so the write lands in an object that is thrown away at the next
  parse — the row appears to work and the file never changes.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "no setting has two rows"

twice="$(sort <<< "$rows" | uniq -d)"
if [[ -n "$twice" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    while read -r k; do
        [[ -z "$k" ]] && continue
        printf '      %s\n' "$k"
        # Only `key:` lines. Grepping the bare name also finds it in a comment,
        # which sends the reader to a sentence about the problem instead of to
        # one of the two rows causing it.
        grep -rnE "^[[:space:]]*key:[[:space:]]*\"$k\"" shell/ui/settings/ \
            | sed 's/^/        /'
    done <<< "$twice"
    cat <<'WHY'

  Two controls for one value. They cannot be kept in step by hand: whichever
  page was opened last is the one that looks right, and the other one lies
  until it is touched.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "every kind is a known one"

badkind="$(grep -rhoE '^[[:space:]]*kind:[[:space:]]*"[^"]+"' shell/ui/settings/ \
           | sed -E 's/.*"([^"]+)".*/\1/' | sort -u \
           | grep -vxE 'switch|slider|choice|field|strings|pick|picks|command|time|colour|folder|image')"
if [[ -n "$badkind" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "$badkind"
    cat <<'WHY'

  SettingRow picks its control by this string and falls through to `null` for
  anything it does not know — so a typo draws a label with nothing under it.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
# ⚠️ A `choice` WITH NO CHOICES DRAWS NOTHING AND SAYS NOTHING, and that is how
# a row shipped on 10.08.2026 with its label, its hint, and an empty space where
# the switch belongs. The cause was one word: the property is `choices:` and it
# had been written `options:`. QML does not object to an unknown property on a
# type that has no such property — it simply is not there — so the control had
# an empty model and drew an empty model.
#
# Same family as the check above: that one catches a `kind` the row cannot draw,
# this one catches a `kind` the row CAN draw and has nothing to draw with.
printf '  %-34s ' "every choice row has choices"
emptychoice=""
for f in shell/ui/settings/pages/*.qml shell/ui/settings/*.qml; do
    [[ -e "$f" ]] || continue
    # The block from a `kind: "choice"` to the end of its row.
    while IFS=: read -r line _; do
        [[ -n "$line" ]] || continue
        block="$(sed -n "${line},$(( line + 12 ))p" "$f")"
        grep -qE '^[[:space:]]*choices:' <<< "$block" \
            || emptychoice+="      $f:$line"$'\n'
    done < <(grep -nE '^[[:space:]]*kind:[[:space:]]*"choice"' "$f")
done
if [[ -n "$emptychoice" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    printf '%s' "$emptychoice"
    cat <<'WHY'

  The property is `choices:`. A row that spells it anything else draws its
  label, its hint, and nothing you can click.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "the owed list is exactly right"

missing="$(comm -23 <(sort -u <<< "$want") <(sort -u <<< "$rows"))"
forgotten="$(comm -23 <(sort -u <<< "$missing") <(sort -u <<< "$PENDING"))"
stale="$(comm -13 <(sort -u <<< "$missing") <(sort -u <<< "$PENDING"))"

if [[ -n "$forgotten$stale" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    [[ -n "$forgotten" ]] && sed 's/^/      no row and not owed: /' <<< "$forgotten"
    [[ -n "$stale" ]] && sed 's/^/      owed but already built: /' <<< "$stale"
    cat <<'WHY'

  "no row and not owed" is a setting that can only be reached by editing JSON,
  with nothing recording that fact. Give it a row, or put it in PENDING with a
  reason.

  "owed but already built" means a row landed and PENDING was not struck out.
  Delete the line — the list is how anyone knows what M8 still owes, and a list
  that overstates is one nobody subtracts from.
WHY
    exit 1
fi

owed="$(grep -c . <<< "$PENDING")"
have="$(grep -c . <<< "$want")"
if [[ "$owed" -eq 0 ]]; then
    printf '\033[38;5;114mok\033[0m  all %s settings have a row\n' "$have"
else
    printf '\033[38;5;114mok\033[0m  %s of %s settings, %s still owed\n' \
           "$(( have - owed ))" "$have" "$owed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# ⚠️ THE TWO LEVELS: every row is on exactly one, and the first one fits.
#
# He asked for two things that look like opposites — 05.08. "notch größe und so   # english-ok: the brief, quoted
# soll man ALLES in den settings einstellen können", 08.08. "das ist alles zu     # english-ok: the brief, quoted
# viel" — and chose the way out where both stay true: nothing is deleted, and a   # english-ok: the brief, quoted
# page opens showing only the rows you reach for. The rest is behind "Show more".
#
# That only works while the first level stays short. A second level that quietly
# fills up is the wall again with an extra click in front of it, so the limit is
# checked rather than remembered: SIX rows on the simple level of any page.
#
# ⚠️ IT WAS EIGHT, AND EIGHT LET SEVEN PAGES THROUGH THAT HE THEN NAMED. On
# 09.08. he listed Type, Pointer, Clock & Date, Keyboard, Windows, Programs and
# This Machine as "unübersichtlich". Every one of them passed this check at      # english-ok: the report, quoted
# eight — five of them because they had NO `advanced:` marks at all and simply
# were not long enough to trip it. A limit that only catches the longest page
# does not catch a wall; it catches a very long wall.
#
# Six is not a nicer number. It is where the pages he did NOT complain about sit
# (Colours 7 → now the only one at the line, Lock 3, Media 3, Launcher 4), and
# it is small enough that a page with nothing marked advanced has to justify
# itself.
#
# ⚠️ ThemingRows DO NOT COUNT, and that is not an exemption of convenience. The
# App Theming table exists BECAUSE thirteen SettingRows were the wall — one
# program per line, four states side by side, the whole page readable at once.
# Counting its thirteen rows against a limit meant to force compactness would
# punish the thing that already solved it.
printf '  %-34s ' "the simple level fits on a page"

LIMIT=6
over=""
for f in shell/ui/settings/pages/*.qml; do
    [[ -e "$f" ]] || continue
    total="$(grep -cE '^[[:space:]]*key:[[:space:]]*"' "$f")"
    (( total > 0 )) || continue
    adv="$(grep -cE '^[[:space:]]*advanced:[[:space:]]*true' "$f")"
    table="$(grep -cE '^[[:space:]]*ThemingRow[[:space:]]*\{' "$f")"
    simple=$(( total - adv - table ))
    (( simple > LIMIT )) && over+="$(basename "$f"): $simple rows on the simple level"$'\n'
done

if [[ -n "$over" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "${over%$'\n'}"
    cat <<'WHY'

  More than six rows open on one page is the wall he asked to be rid of, and
  a "Show more" in front of a wall is a wall with a door on it.

  Mark the fine adjustments with `advanced: true` on the row, next to its `key`.
  A fine adjustment is a shoulder radius, a blur pass, a dwell in milliseconds,
  a protocol flag, or the second half of a symmetric pair — not a size he named
  himself.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
# ⚠️ AND THE MARK BELONGS TO A ROW. `advanced: true` floating in a page that is
# not attached to a row is a level set on something that is not a row — the mark
# would do nothing and read as if it had.
#
# ⚠️⚠️ "ATTACHED TO A ROW" USED TO MEAN "on the line under a `key:`", AND THAT
# STOPPED BEING THE SAME THING. Every row in this window had a key until the
# Displays page, where `outputs` is a list of objects and no dotted path can name
# "the refresh rate of DP-2" — the same reason `outputs` is in the EXEMPT list at
# the top of this file. Its rows are OutputRows, they carry a level like any
# other row, and they have no key to sit under.
#
# So the rule is followed rather than loosened: the mark must be on a row, and a
# row is a `key:` line OR an `OutputRow {` header, whichever opened the block it
# is in. An exemption by filename would have let the NEXT page put `advanced:`
# on a Rectangle with nothing to say so.
printf '  %-34s ' "every advanced mark is on a row"

orphan=""
for f in shell/ui/settings/pages/*.qml; do
    [[ -e "$f" ]] || continue
    while IFS=: read -r line _; do
        [[ -z "${line:-}" ]] && continue
        prev="$(sed -n "$(( line - 1 ))p" "$f")"
        [[ "$prev" =~ ^[[:space:]]*key:[[:space:]]*\" ]] && continue
        # A keyless row: walk back to the nearest opening brace at a shallower
        # indent and ask what it opened. Bounded at twelve lines — a row header
        # further away than that is not a row anybody can read either.
        found=""
        for (( back = 1; back <= 12; back++ )); do
            (( line - back >= 1 )) || break
            probe="$(sed -n "$(( line - back ))p" "$f")"
            if [[ "$probe" =~ ^[[:space:]]*OutputRow[[:space:]]*\{ ]]; then
                found=yes
                break
            fi
            # Any other block opening first means the mark is inside something
            # that is not a row.
            [[ "$probe" =~ \{[[:space:]]*$ ]] && break
        done
        [[ -n "$found" ]] || orphan+="$f:$line"$'\n'
    done < <(grep -nE '^[[:space:]]*advanced:[[:space:]]*true' "$f")
done

if [[ -n "$orphan" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      not directly under a key: /' <<< "${orphan%$'\n'}"
    cat <<'WHY'

  The level is a property of the ROW, so it is written on the row, immediately
  under the key it belongs to. Anywhere else it is a property of nothing.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'
