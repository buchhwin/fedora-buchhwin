#!/usr/bin/env bash
#
# The network and Bluetooth panels are the shell's own, and they show something.
#
# ⚠️⚠️ WHAT THIS EXISTS TO PREVENT ALREADY HAPPENED ONCE, for months.
# services/Net.qml and services/Bt.qml were written complete — connect,
# disconnect, forget, needsPassword, connectWithPassword, the adapter switch —
# and NOTHING CALLED ANY OF IT. The quick panel opened KDE's System Settings
# instead. Every check in the suite was green throughout, because a service with
# no caller is not a broken service; it is a service nobody looks at, and there
# is no shape of static check that can tell those apart.
#
# So this asks the panels to build against the fixtures the two services already
# carry for their own fake mode, and requires a row per entry. Building alone
# proves nothing — a Repeater over an empty model builds perfectly and draws
# nothing, which is exactly the fault tests/displays.sh was written against on
# the other side of the shell.
#
# ⚠️ IT RUNS ANYWHERE. `BUCHHWIN_SHELL_FAKE=1` makes both services answer from
# their own fixtures, so no NetworkManager, no bluez adapter and no radio of any
# kind is needed — the CI container and a laptop give the same answer.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "  -- quickshell (qs) not installed"; exit 2; }

LOG=/tmp/buchhwin-netpanel-check.log
rm -f "$LOG"

# ⚠️ ITS OWN XDG_CONFIG_HOME, the same reason tests/lock.sh has one: the panels
# read Config through the Theme layer, and a check that picks up whatever is in
# the caller's shell.json answers a different question on every machine.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/buchhwin"
printf '{}\n' > "$tmp/buchhwin/shell.json"

XDG_CONFIG_HOME="$tmp" BUCHHWIN_SHELL_FAKE=1 \
    BUCHHWIN_TOOL=netpanel-check QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1
code=$?

# ⚠️ TWO DIFFERENT FAILURES, and a check that sees only one of them is itself
# the fault: a tool that REFUSES exits 0 and says ABORT in its report, a tool
# that CRASHES or hangs says nothing at all. tools/monitors-check.qml spent a
# session in the second state being read as the first.
if (( code != 0 )); then
    echo "  netpanel-check crashed or timed out (exit $code)"
    [[ -f "$LOG" ]] && tail -5 "$LOG"
    exit 1
fi
[[ -f "$LOG" ]] || { echo "  no output"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' "$LOG"

grep -q ABORT "$LOG" && exit 1
exit 0
