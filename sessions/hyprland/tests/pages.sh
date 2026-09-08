#!/usr/bin/env bash
#
# Every settings page the window registers has to build, and the rows that come
# out of building them have to be the rows the schema owes.
#
# ⚠️ THIS IS THE HALF tests/setting-rows.sh CANNOT SEE. That check greps the page
# files for `key: "…"` and matches them against the adapter, which is exactly the
# right question asked of the SOURCE — and it stays green for a page the window
# never builds. A path with a typo in it, a file deleted, a page that throws on
# creation: all of them grep perfectly.
#
# The registration used to live in three places (the page list, a Component
# declaration, and a branch in a ten-way ternary) and forgetting the third gave
# you a blank page and no complaint. It is one entry now, and this is what keeps
# that promise checkable.
#
# Two halves, and only together are they a check:
#
#   1. shell/tools/pages-check.qml reads the page list out of SettingsContent
#      itself, builds every entry, and counts the rows each one produces.
#   2. This script compares that total against the number of `key:` lines
#      setting-rows.sh counts. Reading and building are two independent methods,
#      and they must agree: a row declared inside something the window never
#      instantiates is counted by the grep and not by the build.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

fail=0
log="$(mktemp)"
report=/tmp/buchhwin-pages-check.txt
trap 'rm -f "$log"' EXIT
rm -f "$report"

# ⚠️ Its own XDG_CONFIG_HOME, for the same reason lock.sh has one: the pages read
# Config, and a test that picks up whatever is in the caller's shell.json answers
# a different question on every machine.
tmp="$(mktemp -d)"
mkdir -p "$tmp/buchhwin"
printf '{"version":11}\n' > "$tmp/buchhwin/shell.json"

printf '  %-34s ' "every page builds"
XDG_CONFIG_HOME="$tmp" BUCHHWIN_TOOL=pages-check QT_QPA_PLATFORM=offscreen \
    timeout 90 qs -p shell >"$log" 2>&1
rm -rf "$tmp"

if [[ ! -f "$report" ]]; then
    printf '\033[38;5;203mno report — the tool did not run\033[0m\n'
    sed 's/^/      /' "$log" | head -12
    exit 1
fi
if grep -q "all good" "$report"; then
    printf '\033[38;5;114mok\033[0m  %s pages\n' \
           "$(grep -c 'builds — ' "$report")"
else
    printf '\033[38;5;203mfailed\033[0m\n'
    grep -B1 -A3 FAIL "$report" | sed 's/^/      /' | head -24
    fail=1
fi

# ------------------------------------------------------------------ the counts
# The same corpus setting-rows.sh uses, counted the same way. Not a re-derivation
# of its logic: just the one number the two methods have to agree on.
printf '  %-34s ' "built rows match declared rows"
declared="$(grep -rhoE '^[[:space:]]*key:[[:space:]]*"[^"]+"' shell/ui/settings/ \
            | wc -l | tr -d ' ')"
built="$(sed -n 's/^  --  *\([0-9]\+\) rows built in total$/\1/p' "$report")"

if [[ -z "$built" ]]; then
    printf '\033[38;5;203mthe tool reported no total\033[0m\n'
    fail=1
elif [[ "$built" == "$declared" ]]; then
    printf '\033[38;5;114mok\033[0m  %s\n' "$built"
else
    printf '\033[38;5;203m%s built, %s declared\033[0m\n' "$built" "$declared"
    cat <<'EOF'
      The two methods disagree, and that is a real fault either way round.

      Fewer built than declared: a row is inside something the window never
      instantiates — a Loader that is never active, a component nothing reaches.
      It greps as a setting and it is not one.

      More built than declared: a row is being created more than once, or by a
      Repeater over a model. setting-rows.sh needs one literal `key:` line per
      setting, so that row is invisible to the check that guards the schema.
EOF
    fail=1
fi

# ---------------------------------------------------------------- the warnings
# ⚠️ CREATION IS ONLY HALF THE ANSWER, the same way it is in lock.sh: a binding
# that names something which no longer exists does not stop the object being
# built. It throws when evaluated, leaves the property at its default, and warns.
#
# ⚠️ ONE WARNING IS EXPECTED AND IS NOT A FAULT. It is filtered by its own text
# rather than by softening the check, so everything else still fails:
#
#   "Created graphical object was not placed in the graphics scene"
#       what building an Item without a window means, once per page.
printf '  %-34s ' "no complaints from the pages"
noise="$(grep -E '@?ui/settings/' "$log" \
         | grep -viE 'was not placed in the graphics scene' \
         | head -12)"
if [[ -z "$noise" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "$noise"
    fail=1
fi

exit "$fail"
