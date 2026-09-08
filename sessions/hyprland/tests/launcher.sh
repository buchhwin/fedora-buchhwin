#!/usr/bin/env bash
#
# Which column a program lands in, and what never reaches the list.
#
# The launcher's whole job is finding a program you cannot otherwise start, so
# the failure that matters is not a crash — it is a program that is installed,
# works, and cannot be found. Two shapes of that, both of which the predecessor
# had: a menu full of entries nobody wants (`noDisplay`, and one row per
# `entry.action` — twenty lines of Evolution), and a category column sorted by
# toolkit, where "GTK" held half the system.
#
# ⚠️ The rules are checked against invented category lists rather than against
# whatever happens to be installed. The machine's own programs differ between a
# laptop, the VM and a CI container; the rules do not.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

rm -f /tmp/buchhwin-launcher-check.txt
BUCHHWIN_TOOL=launcher-check QT_QPA_PLATFORM=offscreen timeout 60 qs -p shell >/dev/null 2>&1

[[ -f /tmp/buchhwin-launcher-check.txt ]] || { echo "  no output"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' /tmp/buchhwin-launcher-check.txt

grep -q '^  FAIL' /tmp/buchhwin-launcher-check.txt && exit 1
exit 0
