#!/usr/bin/env bash
#
# The calendar: reading what konsolekalendar exports, and the month arithmetic
# under it.
#
# Every failure in this area looks the same from outside — an appointment on the
# wrong day, or one that never appears at all — and you find out by missing it.
# So the checks live next to the samples they judge, in
# shell/tools/calendar-check.qml, and this script only runs them and reports.
#
# ⚠️ THE SAMPLES ARE A FIXTURE, AND THEY HAVE TO BE. A machine with no Akonadi
# store answers "no calendars found", and a check that read a live calendar
# would be green over nothing there — the exact shape tests/displays.sh and
# tests/netpanel.sh were both written against. The CSV in the tool is what
# `konsolekalendar --export-type CSV` really emits, field for field.
#
# Deliberately offline: no account, no network, no clock beyond `new Date()`.
# That is what makes it a CI test rather than something only one machine can run.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

rm -f /tmp/buchhwin-calendar-check.log
# ⚠️ TZ IS PINNED, and without it this test is a lie that happens to pass.
#
# The parser builds local `Date` objects and the checks read them back with
# getHours() — the LOCAL time of whatever machine runs it. Under one timezone
# 09:30 reads 09:30; under another the same instant reads something else, and
# checks fail by exactly the offset. That happened here once already, in the
# version of this file that read iCalendar: four checks off by two hours,
# because CI runs in UTC and the fixtures were written in Berlin.
#
# The code is right either way: the CSV carries wall-clock times and the desktop
# shows wall-clock times. What is wrong is a test that asserts a clock without
# saying which wall it means. It is fixed by fixing the clock.
TZ=Europe/Berlin BUCHHWIN_TOOL=calendar-check QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1
code=$?

if [[ ! -f /tmp/buchhwin-calendar-check.log ]]; then
    echo "  no output — the checker did not run (exit $code)"
    exit 1
fi

# Colour the two words that matter, leave the rest as the tool wrote it.
sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' \
    /tmp/buchhwin-calendar-check.log

grep -q '^  FAIL' /tmp/buchhwin-calendar-check.log && exit 1
exit 0
