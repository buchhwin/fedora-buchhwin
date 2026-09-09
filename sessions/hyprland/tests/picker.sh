#!/usr/bin/env bash
#
# The theme and wallpaper pickers are ONE component, it wraps, and browsing
# through it changes nothing.
#
# ⚠️⚠️ THE THIRD OF THOSE IS THE ONE NOTHING ELSE CAN SEE. "Enter to apply" is
# his decision and the footer says so; a picker that quietly became a live
# preview would still build, still draw and still look right in a screenshot,
# and the only symptom would be a laptop that gets warm while somebody looks
# through twelve palettes — one full render over thirteen foreign files plus a
# `Hyprland --verify-config` per keypress.
#
# So the checks live next to the fixture in shell/tools/picker-check.qml, and
# this script only runs them and reports.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "  -- quickshell (qs) not installed"; exit 2; }

LOG=/tmp/buchhwin-picker-check.log
rm -f "$LOG"

# ⚠️ ITS OWN XDG_CONFIG_HOME. The strongest check here is "the config was not
# written", and running it against the caller's own shell.json would mean a
# failing run had edited the settings of whoever ran it.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/buchhwin"
printf '{"theme":{"palette":"black"},"wallpaper":{"current":"file:///nowhere.png"}}\n' \
    > "$tmp/buchhwin/shell.json"

XDG_CONFIG_HOME="$tmp" BUCHHWIN_TOOL=picker-check QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1
code=$?

if (( code != 0 )); then
    echo "  picker-check crashed or timed out (exit $code)"
    [[ -f "$LOG" ]] && tail -5 "$LOG"
    exit 1
fi
[[ -f "$LOG" ]] || { echo "  no output"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' "$LOG"

grep -q ABORT "$LOG" && exit 1
exit 0
