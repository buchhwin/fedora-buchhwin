#!/usr/bin/env bash
#
# Does the calculator get the right answers, and does it refuse the rest?
#
# It was written by hand instead of calling eval() so that it COULD be checked —
# an unchecked parser is eval() with extra steps, and eval() in a shell means a
# text field with the run of the whole configuration. Two of the cases below are
# exactly that: `Qt.quit()` and `[].constructor` must come back as "I do not
# know what that means" rather than as anything at all.
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

rm -f /tmp/buchhwin-calc-check.txt
BUCHHWIN_TOOL=calc-check QT_QPA_PLATFORM=offscreen timeout 60 qs -p shell >/dev/null 2>&1

[[ -f /tmp/buchhwin-calc-check.txt ]] || { echo "  no output"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' /tmp/buchhwin-calc-check.txt

grep -q '^  FAIL' /tmp/buchhwin-calc-check.txt && exit 1
exit 0
