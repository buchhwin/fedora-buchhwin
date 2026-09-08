#!/usr/bin/env bash
#
# Where the machine thinks it is, and the format that says so.
#
# The location is shared by the weather, by the sunrise/sunset that will drive
# automatic light/dark, and by gammastep — so getting it wrong is wrong in three
# places at once, and all three would look merely "a bit off" rather than broken.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

rm -f /tmp/buchhwin-location-check.txt
BUCHHWIN_TOOL=location-check QT_QPA_PLATFORM=offscreen timeout 60 qs -p shell >/dev/null 2>&1

[[ -f /tmp/buchhwin-location-check.txt ]] || { echo "  no output"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' /tmp/buchhwin-location-check.txt

grep -q '^  FAIL' /tmp/buchhwin-location-check.txt && exit 1
exit 0
