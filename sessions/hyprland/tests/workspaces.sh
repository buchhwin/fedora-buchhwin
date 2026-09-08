#!/usr/bin/env bash
# B77 · B78 · the Super+Tab map draws the workspace to scale.
#
# Two reports, one cause:
#
#   "wenn ich mehr als 2 Fenster in einem Workspace offen hab buggt super tab   # english-ok: the report, quoted
#   rum das ist dann voll abgeschnitten"                                        # english-ok: the report, quoted
#
#   "die Apps werden nicht richtig groß angezeigt … also die richtige größe     # english-ok: the report, quoted
#   der Fenster"                                                                # english-ok: the report, quoted
#
# ⚠️ THE ARITHMETIC IS THE TESTABLE HALF, and it is the half that was wrong. The
# lab VM has one screen, so "three windows side by side on a laptop" cannot be
# staged here — but `WorkspacesPage.layoutWindows` is a pure function, and it can
# be handed the exact numbers that were measured off the running compositor.
# Whether it LOOKS right on three monitors stays his to confirm; this stops the
# overflow coming back.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "  -- quickshell (qs) not installed"; exit 2; }

LOG=/tmp/buchhwin-workspaces-check.log
rm -f "$LOG"

BUCHHWIN_TOOL=workspaces-check QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1
code=$?

# ⚠️ TWO DIFFERENT FAILURES, and a check that sees only one of them is itself the
# fault: a tool that REFUSES exits 0 and says ABORT in its report, a tool that
# CRASHES says nothing at all.
if (( code != 0 )); then
    echo "  workspaces-check crashed or timed out (exit $code)"
    [[ -f "$LOG" ]] && tail -5 "$LOG"
    exit 1
fi
[[ -f "$LOG" ]] || { echo "  no output"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' "$LOG"

grep -q ABORT "$LOG" && exit 1
exit 0
