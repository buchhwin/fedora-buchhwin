#!/usr/bin/env bash
#
# The two new controls have to write what their labels promise.
#
# ⚠️ THIS IS THE HALF THAT CANNOT BE READ. setting-rows.sh proves every row names
# a real key and suggestions.sh proves every suggesting row has a source that
# answers — both by looking at the source. Neither touches the moment the file
# changes: a chip added, a chip removed, a program picked.
#
# ⚠️ AND ONE PROMISE HERE IS SILENT WHEN IT BREAKS. `programs.terminal` is
# ["kitty", "-e", "btop"] — a program and its arguments, in order. Picking a
# different terminal from the suggestions must keep the arguments; lose them and
# the key binding still works, still opens a terminal, and simply stops opening
# btop. Nothing logs it, no other check sees it, and you find out weeks later.
#
# ⚠️ IT DOES NOT USE SYNTHETIC INPUT, and that is measured rather than lazy: the
# settings window could not be driven with ydotool on the test machine at all —
# pointer motion arrives and hovers highlight, clicks and keystrokes do nothing,
# while the same ydotool typed a password into the lock screen minutes earlier. A
# check built on that would have gone quietly green-because-nothing-happened.
# The control is called directly instead, one function below where a click lands.
#
# It runs against a throwaway XDG_CONFIG_HOME, so nothing here can reach real
# settings — and that is checked rather than trusted.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

tmp="$(mktemp -d)" || { echo "  could not make a temporary directory"; exit 2; }
[[ -n "$tmp" && "$tmp" == /tmp/* ]] || { echo "  refusing to run against $tmp"; exit 2; }
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config/buchhwin"

# A file with values nothing else would produce, so a green line cannot come
# from the defaults happening to match.
cat > "$tmp/config/buchhwin/shell.json" <<'JSON'
{
  "theme": { "palette": "everforest-dark", "customColor": "#111111", "lightFrom": "01:00" },
  "windows": { "blurred": [] },
  "theming": { "enabled": true, "mode": "colour" },
  "programs": { "terminal": ["kitty"] }
}
JSON

out="$tmp/report.txt"
BUCHHWIN_TOOL=row-write-check \
BUCHHWIN_ROWS_OUT="$out" \
QT_QPA_PLATFORM=offscreen \
XDG_CONFIG_HOME="$tmp/config" \
    timeout 90 qs -p shell >/dev/null 2>&1

[[ -f "$out" ]] || { echo "  no output — the tool did not run"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' "$out"

# ⚠️ A REPORT WITH NO CHECKS IN IT IS NOT A PASS. The tool walks to its controls
# and gives up if it cannot find them; without this line, a walk that found
# nothing would print an empty file and exit 0.
n="$(grep -c '^  ok ' "$out")"
if (( n < 17 )); then
    printf '  \033[38;5;203mFAIL\033[0m %s\n' "only $n checks ran — the tool stopped early"
    exit 1
fi

grep -q '^  FAIL' "$out" && exit 1
exit 0
