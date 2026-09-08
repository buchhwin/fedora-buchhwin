#!/usr/bin/env bash
#
# Every page verb actually opens its page.
#
# ⚠️ EXISTING AND WORKING ARE DIFFERENT CLAIMS, and this project has already paid
# for the gap. `notch settings` existed, was reachable, appeared in every
# listing — and did nothing at all, because it called `showQuick` with a
# constant that had been deleted the day before. The only trace was one line in
# the journal, "Cannot assign [undefined] to int".
#
# tools/smoke.qml checks that a keybinding names a verb the handler HAS.
# tests/ipc-names.sh checks that the handler's own reads resolve. Neither asks
# the one question a user would: press it, does the thing appear.
#
# So this calls each verb and asks the shell what page it is on afterwards.
#
# ⚠️ IT NEEDS A RUNNING SHELL — it is a check about behaviour, not about source,
# and there is no way to answer it from a file. Skips with 2 where there is
# none, exactly as the other live checks do.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# ⚠️⚠️ NOT `qs -c buchhwin ipc`, AND THAT ONE WORD IS WHY THIS SUITE USED TO
# PASS ALONE AND FAIL IN A STACK. The lock screen is a second instance of the
# same config; while it lives, the config name matches two processes and every
# call answers "Target not found". tests/shell-ipc.sh names the PROCESS.
. "$(dirname "$0")/shell-ipc.sh"

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }
bh_shell_answers \
    || { echo "no running shell to ask"; exit 2; }

printf '  %-34s ' "every page verb opens its page"

# verb : the page `notch state` must report afterwards.
#
# ⚠️ Only the verbs that OPEN something are here. `collapse` closes, `state`
# reports, and the three that toggle a service rather than a page (`mic` and
# friends behave the same but auto-close, which would make this flaky) are
# deliberately left out — a check that is right nine times in ten teaches people
# to ignore it.
pairs="media:media
quick:quick
notifications:notifications
calendar:calendar
tray:tray
workspaces:workspaces
monitors:monitors
wallpaper:wallpaper
theme:theme
event:event
brightness:brightness
calculator:calculator
timer:timer
session:session
clipboard:clipboard"

# ⚠️ `settings` IS NOT IN THAT LIST ANY MORE, and it is not an omission. It was
# `settings:quick` while the gear opened the quick panel for want of anywhere
# else to go. M8 gave it somewhere: it is its own IPC target now and opens a
# real niri window, so it sets no page at all and `notch state` is the wrong
# question to ask about it. The check for it is below, in its own terms.

bad=""
while IFS=: read -r verb want; do
    [[ -z "$verb" ]] && continue
    bh_ipc call notch collapse >/dev/null 2>&1
    sleep 0.4
    bh_ipc call notch "$verb" >/dev/null 2>&1
    sleep 0.8
    got="$(bh_ipc call notch state 2>/dev/null | tr -d '\r\n')"
    [[ "$got" == "$want" ]] || bad+="$verb -> expected '$want', got '${got:-<nothing>}'"$'\n'
done <<< "$pairs"

bh_ipc call notch collapse >/dev/null 2>&1

if [[ -n "$bad" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "${bad%$'\n'}"
    cat <<'WHY'

  The verb answered and the page did not appear. That is the shape the gear on
  the bar had: reachable, listed, silent. Look for a constant that was renamed
  or removed — QML reads a property that does not exist as `undefined` and says
  nothing, so the failure surfaces wherever the value is used rather than where
  the mistake is.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m  %s verbs\n' "$(wc -l <<< "$pairs")"

# ─────────────────────────────────────────────────────────────────────────────
# The settings window answers in its own terms.
#
# It reports `open`/`closed` rather than a page name, so it needs its own check
# — and it needs one for exactly the reason the list above exists: the gear was
# reachable, listed and silent for a day, and nothing noticed.
printf '  %-34s ' "settings toggles its window"

bh_ipc call settings hide >/dev/null 2>&1
sleep 0.4
before="$(bh_ipc call settings state 2>/dev/null | tr -d '\r\n')"
bh_ipc call settings toggle >/dev/null 2>&1
sleep 0.8
after="$(bh_ipc call settings state 2>/dev/null | tr -d '\r\n')"
bh_ipc call settings hide >/dev/null 2>&1

if [[ "$before" == "closed" && "$after" == "open" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
    exit 0
fi

printf '\033[38;5;203mfound\033[0m\n'
printf '      expected closed -> open, got %s -> %s\n' \
       "${before:-<nothing>}" "${after:-<nothing>}"
cat <<'WHY'

  An empty answer means the target is not registered at all — check that
  `settings` is in Ipc's `targets` map, which is what the smoke test asks.
  An answer that never changes means the window is not loaded on
  `Ipc.settingsOpen` in ui/Shell.qml.
WHY
exit 1
