#!/usr/bin/env bash
#
# The runtime smoke test — the one check a linter cannot do.
#
# qmllint reads files; it does not build the object graph. A missing qmldir
# entry, a singleton shadowed by a Qt type, a Connections on a singleton that is
# still being constructed — none of those are visible to a linter, and every one
# of them has turned this desktop black at some point.
#
# ⚠️ It also fails on QML WARNINGS, not only on its own checks. A binding loop
# or an "is not a type" is printed to stderr and the process still exits 0, so
# the message scrolls past and the run is called green. That is exactly how a
# binding loop in the lock screen's avatar survived until somebody read a log.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

rm -f /tmp/buchhwin-smoke.txt
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

BUCHHWIN_TOOL=smoke QT_QPA_PLATFORM=offscreen timeout 60 qs -p shell >"$log" 2>&1

[[ -f /tmp/buchhwin-smoke.txt ]] || {
    echo "  the shell produced no report at all — it did not get that far:"
    sed 's/^/    /' "$log"
    exit 1
}

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' /tmp/buchhwin-smoke.txt

fail=0
grep -q '^  FAIL' /tmp/buchhwin-smoke.txt && fail=1

# QML's own complaints. Filtered to the ones that mean something is broken
# rather than absent: a service that cannot reach D-Bus in a container is
# expected, a binding loop is not.
#
# ⚠️ ONE EXCEPTION, and it has to be an exception rather than a looser pattern.
# Offscreen there is no wlr-layer-shell, so quickshell reports "No PanelWindow
# backend loaded" and every surface type comes out "unavailable". That is the
# stated limit of this test, not a fault — but only for THAT reason. An
# unavailable type for any other reason is a real broken import and must still
# fail, so the pair is dropped together rather than the word being ignored.
complaints="$(awk '
    /Type .* unavailable/ { held = $0; next }
    held != "" {
        if ($0 !~ /No PanelWindow backend loaded/) print held
        held = ""
    }
    /Binding loop|is not a type|Unable to assign|Cannot assign|ReferenceError|TypeError/ { print }
    END { if (held != "") print held }
' "$log")"

if [[ -n "$complaints" ]]; then
    printf '  \033[38;5;203mFAIL\033[0m  QML complained while building:\n'
    printf '%s\n' "$complaints" | sed 's/^/          /'
    fail=1
fi

exit $fail
