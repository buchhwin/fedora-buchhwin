#!/usr/bin/env bash
#
# No Python in the product.
#
# ⚠️ THE RULE THIS HOLDS IS ONE OF THE FOUR HARD ONES, and it had been broken
# for a long time with nothing to say so: "kein Python, kein Lua im Betrieb;      # english-ok: the brief, quoted
# Bash nur für den Installer, ohne jede Konfigurationslogik."                     # english-ok: the brief, quoted
#
# `bin/bhctl` carried FOUR embedded python3 scripts. Two of them merely read
# JSON to print a line; one of them REWROTE shell.json, which is configuration
# logic by any reading. None of them was noticed by any of the fifty-three
# checks, because none of them was looking.
#
# ⚠️ AND ONE OF THOSE FOUR WAS ALSO WRONG. The one that reassembled a mode out
# of `current_mode` and milli-hertz printed 74.994 Hz as "75", because it used
# `%.3g`. The compositor prints the right thing itself, and `hyprctl outputs` without
# `-j` needed no parser at all. The rule was not being pedantic; the detour was
# the bug.
#
# ------------------------------------------------------------------ the scope
#
# ⚠️ `tests/` IS NOT COVERED, AND THAT IS A DECISION RATHER THAN AN OVERSIGHT.
# Six suites use python3 to read Config.qml's schema or to stand up a throwaway
# HTTP server. A test harness is not "im Betrieb": it never runs on his machine, # english-ok: the brief, quoted
# it ships no behaviour, and rewriting it in QML would mean the checker and the
# checked share an engine — which is how a check goes blind.
#
# ⚠️ `lib/` IS COVERED, AND THE LIST BELOW IS EMPTY — which it was not when this
# file was written. Two installer phases parsed JSON with python3 and both were
# configuration logic:
#
#   lib/40-apps.sh       edited Brave's Preferences. Gone: the colour and the
#                        frame moved to shell/tools/render.qml, where a value
#                        that changes with the palette belongs.
#   lib/70-services.sh   read the keyboard layout out of shell.json. Gone: it
#                        reads the GENERATED config.kdl instead, which is also
#                        more truthful — that is what the compositor loaded.
#
# ⚠️ THE EMPTY LIST IS WHY THE SECOND HALF OF THIS CHECK EXISTS. It fires when a
# KNOWN name no longer needs excusing, and that is exactly how both of these
# came off it — the check reported "lib/40-apps.sh is clean now" rather than
# quietly going on excusing a file that had been fixed. An exemption list that
# nobody prunes is a check that says "ok" for ever.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# Names are added here individually and visibly. There are none, and the aim is
# that there continue to be none.
KNOWN=""

fail=0

# ⚠️ COMMENTS DO NOT COUNT, and this is not tidiness — it is the trap this very
# round fell into. Grepping the tree for `import "../config"` matched a comment
# in tools/binds.qml saying the file deliberately does NOT import it, and the
# file was duly listed among those that do. A scan that reads its own
# documentation as evidence is the same fault as `pgrep -f` finding itself.
scan() {
    local f="$1"
    sed -e 's/^[[:space:]]*#.*$//' -e 's/^[[:space:]]*\/\/.*$//' "$f" \
        | grep -c 'python3\|python2\|[^a-z]python[^a-z0-9]' 2>/dev/null || true
}

# ⚠️ `mapfile`, NOT an unquoted `$(find …)`, and this exact warning is written
# out in tests/icons.sh — where the same mistake was made and fixed once
# already. SC2044: word splitting is what makes the bare form work at all, and
# it breaks the moment a path contains a space. The CI runs shellcheck and
# caught this one before it reached anybody, which is the whole point of having
# it: the note in icons.sh did not stop it being written a second time.
found=""
mapfile -t candidates < <(find bin lib shell -type f 2>/dev/null)
for f in "${candidates[@]}"; do
    [[ -n "$f" ]] || continue
    n="$(scan "$f")"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( n > 0 )) || continue
    if grep -qxF "$f" <<< "$KNOWN"; then
        printf '  \033[38;5;179mknown\033[0m %s (%s)\n' "$f" "$n"
        continue
    fi
    found="$found $f"
    printf '  \033[38;5;203mFAIL\033[0m  %s calls python (%s)\n' "$f" "$n"
    fail=1
done

if [[ -z "$found" ]]; then
    printf '  \033[38;5;114mok\033[0m    no new python in bin/, lib/ or shell/\n'
fi

# ⚠️ THE OTHER DIRECTION, and without it this file is half a check. If somebody
# removes a KNOWN entry from the code but leaves it on the list, the list grows
# stale and starts excusing a file that is already clean — so a name that no
# longer needs excusing is a failure too.
while read -r k; do
    [[ -n "$k" ]] || continue
    if [[ ! -f "$k" ]]; then
        printf '  \033[38;5;203mFAIL\033[0m  %s is on the known list and does not exist\n' "$k"
        fail=1
        continue
    fi
    n="$(scan "$k")"
    if [[ "$n" == "0" ]]; then
        printf '  \033[38;5;203mFAIL\033[0m  %s is clean now — take it off the known list\n' "$k"
        fail=1
    fi
done <<< "$KNOWN"

exit $fail
