#!/usr/bin/env bash
# B33 · the Shift+Alt+Tab map: one column per MONITOR, and it may not confuse two.
#
# His request: "wenn ich shift alt tab mache soll auch ein menü angezeigt werden # english-ok: the request, quoted
# wie bei den workspaces aber dort … nur die monitore … aber auf allen monitoren # english-ok: the request, quoted
# wird der aktuelle workspace genommen … aber man muss auch irgendwie in dem     # english-ok: the request, quoted
# menü zwischen den workspaces wechseln können".                                 # english-ok: the request, quoted
#
# ⚠️⚠️ THE FAULT THIS GUARDS IS AN AMBIGUITY, NOT A MISDRAW. Workspace indices
# count PER OUTPUT in the compositor — measured on the lab VM once it had two heads, idx=1
# exists on Virtual-1 AND on Virtual-2. A column that picks "the workspace with
# index 1" out of a global list therefore shows the wrong screen's windows, and
# it does it silently: the picture is plausible, it is just somebody else's.
#
# ⚠️ IT RUNS ANYWHERE. `WorkspaceGeometry.monitorColumns` is a pure function over
# the output map, the workspace list and the windows, so a machine with one
# screen — or none — can still check the whole arrangement. Whether it LOOKS
# right on three monitors stays his to confirm.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "  -- quickshell (qs) not installed"; exit 2; }

LOG=/tmp/buchhwin-monitors-check.log
rm -f "$LOG"

BUCHHWIN_TOOL=monitors-check QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1
code=$?

# ⚠️ TWO DIFFERENT FAILURES, and a check that sees only one of them is itself the
# fault: a tool that REFUSES exits 0 and says ABORT in its report, a tool that
# CRASHES says nothing at all.
if (( code != 0 )); then
    echo "  monitors-check crashed or timed out (exit $code)"
    [[ -f "$LOG" ]] && tail -5 "$LOG"
    exit 1
fi
[[ -f "$LOG" ]] || { echo "  no output"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' "$LOG"

grep -q ABORT "$LOG" && exit 1
exit 0
