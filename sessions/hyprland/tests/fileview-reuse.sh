#!/usr/bin/env bash
#
# A FileView read SYNCHRONOUSLY after being pointed at a new path must have its
# path cleared first.
#
# ⚠️ WHY THIS IS A STATIC RULE AND NOT A COMMENT. It has been a comment since
# config/Backup.qml:104 said it in capitals — and the trap sprang four more
# times after that: Backup._read, Backup._replace, tools/reset-page-check.qml,
# and tools/hypr.qml, where it shipped. There it wrote Brave's desktop file out
# as code.desktop (8650 bytes, `Name=Brave Web Browser`, byte for byte the same
# file) and, because a user desktop file REPLACES the system one, deleted VS
# Code from the launcher. The generator logged "wrote code.desktop" all along.
#
#     view.path = newPath
#     var old = view.text()     <-- the PREVIOUS file's text
#
# ⚠️⚠️ AND THE RULE IS DELIBERATELY NARROW — the wide version would have broken
# something that works. ui/greeter/GreeterFace.qml walks ONE FileView over every
# wayland-session file and reads in `onLoaded`. Measured on the machine, three
# files through one view: AAA / BBB / CCC, each correct. Clearing the path there
# fires `onLoadFailed` for the empty string, GreeterFace answers that with
# nextSession(), and the greeter would silently skip every other session.
#
# So: an asynchronous read in onLoaded is fine and must stay untouched. Only a
# `text()` in the same function as the assignment is the fault.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
ok()  { printf '  \033[32mok\033[0m   %s\n' "$*"; }
bad() { printf '  \033[38;5;203mFAIL\033[0m %s\n' "$*"; fail=1; }

# How far after the assignment a read still counts as "the same statement".
# The measured cases all read within two lines; six is generous and still well
# inside one small function.
WINDOW=6

found=0
checked=0

while IFS= read -r hit; do
    file="${hit%%:*}"
    rest="${hit#*:}"
    line="${rest%%:*}"
    code="${rest#*:}"

    # The receiver of the assignment: `fSystemDesktop.path = …` -> fSystemDesktop
    recv="$(sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)\.path[[:space:]]*=.*/\1/' <<< "$code")"
    [[ -z "$recv" || "$recv" == "$code" ]] && continue

    # The clearing line itself is not a finding.
    #
    # ⚠️ THIS BELONGS HERE AND NOT IN THE PATTERN. Excluding it with `[^"]` in
    # the grep looked equivalent and was not: it dropped every assignment whose
    # value STARTS with a quote — which is
    #     fSystemDesktop.path = "/usr/share/applications/" + o.file
    # the exact line that shipped the bug this whole file is about. The red
    # probe for that site came back green while three others went red, and one
    # site out of four silently unguarded is how a suite becomes decoration.
    val="$(sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//' <<< "$code")"
    [[ "$val" == '""' ]] && continue

    # Is there a synchronous read of the same view just below?
    #
    # ⚠️ THE WINDOW STOPS AT THE END OF THE FUNCTION. The first version did not,
    # and it walked straight out of GreeterFace.nextSession() into takeSession()
    # four lines later — reporting the one case in this tree that is measurably
    # CORRECT. A rule that flags working code gets switched off, and then it
    # guards nothing.
    #
    # ⚠️⚠️ AND THE BOUNDARY IS ANCHORED, WHICH COST A ROUND. The first version
    # looked for `function ` anywhere in the line — and the comment directly
    # under the very assignment this test was written for says "...this
    # function reported 2 written...". The window stopped one line short of the
    # `view.text()` it was hunting, the site was never examined, and the red
    # probe came back GREEN. A checker hanging on its own comment is the exact
    # fault this project has found in seventeen other suites; it found it here
    # only because the red probe was actually run.
    tail_="$(sed -n "$((line + 1)),$((line + WINDOW))p" "$file" \
             | sed -n '1,/^\( \{0,4\}\}\|[[:space:]]*function \)/p')"
    grep -q "${recv}\.text()" <<< "$tail_" || continue

    checked=$((checked + 1))

    # Then the line above must clear it. Two lines of slack for a comment.
    before="$(sed -n "$((line > 2 ? line - 2 : 1)),$((line - 1))p" "$file")"
    if grep -qE "${recv}\.path[[:space:]]*=[[:space:]]*\"\"" <<< "$before"; then
        ok "$(basename "$file"):$line  $recv"
    else
        bad "$file:$line — $recv.path is set and read with $recv.text() right after, without '$recv.path = \"\"' first"
        found=$((found + 1))
    fi
# ⚠️ THE PATTERN IS DELIBERATELY WIDE — it takes every `X.path = <anything>` and
# lets the loop above decide. Two narrower versions were tried and both were
# wrong: `[^"]` matched the space in `path = ""` (so every FIXED site was
# reported as broken), and `[^"[:space:]]` then dropped every value starting
# with a quote (so the one line that actually shipped the bug was never looked
# at). Filtering in the loop is longer and says what it means.
done < <(grep -rn --include='*.qml' \
              -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\.path[[:space:]]*=[[:space:]]*[^[:space:]]' \
              shell/ 2>/dev/null)

if [[ $checked -eq 0 ]]; then
    # ⚠️ A check that examined nothing is not a passing check. This suite exists
    # because seventeen others in this project could not go red.
    bad "no synchronous FileView reads found at all — the pattern this checks for is gone, or the search is broken"
elif [[ $found -eq 0 ]]; then
    ok "$checked synchronous FileView reads, all cleared first"
fi

exit $fail
