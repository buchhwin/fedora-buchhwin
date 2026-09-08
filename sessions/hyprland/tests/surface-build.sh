#!/usr/bin/env bash
#
# Every surface type in the shell can be turned into a QML type at all.
#
# ⚠️⚠️ THE GAP THIS CLOSES COST THE WHOLE DESKTOP AND WAS INVISIBLE TO ALL 57
# SUITES. A second `visible:` on three tiles made QML refuse to build
# QuickSettings; the refusal travelled up through QuickPage, NotchContent and
# ShellSurface, and the shell came up with no notch, no bar, no launcher, no
# quick panel and no IPC. Nothing crashed. Nothing exited non-zero. Every suite
# was green.
#
#   smoke.qml     imports only ../ui/common — never builds the surfaces
#   surfaces.sh   reads the journal of the RUNNING shell, not of this code
#   pages.sh      builds settings pages; the notch surfaces are not pages
#
# ⚠️ IT REPORTS THE INNERMOST FAILURE FIRST. QML names the outermost type in its
# warning ("Shell.qml: Type ShellSurface unavailable") and the cause is three
# lines further down, in a file nobody was editing. The tool walks the list in
# dependency order so the first FAIL is the one to open.
#
# ⚠️ AND IT DOES NOT ASK WHETHER A WINDOW APPEARED. Offscreen there is no
# wlr-layer-shell and a PanelWindow cannot be shown — that is the documented
# limit of headless testing here, not a fault. `Component.Error` is a different
# question: the QML could not become a type at all.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

report=/tmp/buchhwin-surface-build.txt
rm -f "$report"

BUCHHWIN_TOOL=surface-build QT_QPA_PLATFORM=offscreen timeout 60 qs -p shell >/dev/null 2>&1
code=$?

if [[ ! -f "$report" ]]; then
    echo "  the tool wrote no report — it did not run"
    exit 2
fi

if grep -q '^ABORT' "$report"; then
    printf '  \033[38;5;203mFAIL\033[0m  a surface type does not build:\n'
    grep -A6 '^FAIL' "$report" | sed 's/^/      /'
    cat <<'EOF'

  QML refuses to build a component with a duplicate property, an unknown type or
  a bad import — and every type that CONTAINS it becomes "unavailable" in turn.
  The desktop then starts with no surfaces at all and says nothing about it.

  The first FAIL above is the one to open; the ones after it are consequences.
EOF
    exit 1
fi

# ⚠️ A non-zero exit with no ABORT line means the tool died rather than failed —
# a crash, a timeout, a missing import in the tool itself. Told apart, because
# "the checker broke" and "the code is broken" need different people.
if (( code != 0 )); then
    printf '  \033[38;5;203mFAIL\033[0m  the tool exited %s without a verdict\n' "$code"
    tail -5 "$report" | sed 's/^/      /'
    exit 1
fi

printf '  %s surface types build\n' "$(grep -c '^ok' "$report")"
