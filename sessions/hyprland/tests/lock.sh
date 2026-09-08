#!/usr/bin/env bash
#
# The lock screen has to build, and it has to build without complaints.
#
# ⚠️ THIS IS THE SUITE THAT DID NOT EXIST, and two faults lived in that gap for
# four rounds: `Keys.onPressed` writing into `field` when the field is called
# `input` (so every keystroke threw and the password box stayed empty), and an
# avatar ring bound to `Theme.glassRimTop` after that token was deleted. Both
# were in a file that NOTHING built: tests/smoke.sh starts the shell, and the
# lock screen is its own process. qmllint-qt6 was run against both and said
# nothing.
#
# Two halves, and only together are they a check:
#
#   1. shell/tools/lock-check.qml builds LockFace and asks it for the parts the
#      brief names. That catches a file that does not compile, a type that has
#      gone, a signal that was renamed.
#   2. This script reads the process's STDERR. A binding that names something
#      which no longer exists does not stop the object being built — it throws
#      when evaluated, leaves the property at its default, and warns. That is
#      exactly how the avatar ring shipped invisible.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

fail=0
log="$(mktemp)"
report=/tmp/buchhwin-lock-check.txt
trap 'rm -f "$log"' EXIT
rm -f "$report"

# ⚠️ Its own XDG_CONFIG_HOME. The lock face reads Config, and a test that picks
# up whatever is in the caller's shell.json answers a different question on
# every machine — including "green here, red in CI" for reasons that have
# nothing to do with the lock screen.
tmp="$(mktemp -d)"
mkdir -p "$tmp/buchhwin"
printf '{"version":8}\n' > "$tmp/buchhwin/shell.json"

printf '  %-34s ' "LockFace builds headless"
XDG_CONFIG_HOME="$tmp" BUCHHWIN_TOOL=lock-check QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >"$log" 2>&1
rm -rf "$tmp"

if [[ ! -f "$report" ]]; then
    printf '\033[38;5;203mno report — the tool did not run\033[0m\n'
    sed 's/^/      /' "$log" | head -12
    exit 1
fi
if grep -q "all good" "$report"; then
    printf '\033[38;5;114mok\033[0m  %s checks\n' "$(grep -c '  ok  ' "$report")"
else
    printf '\033[38;5;203mfailed\033[0m\n'
    grep -A3 FAIL "$report" | sed 's/^/      /' | head -20
    fail=1
fi

# The second half. Only warnings that name a file under ui/lock count: the
# shell's other surfaces are not built here, and a stray warning from a service
# would make this test fail for something it does not check.
#
# ⚠️ Two spellings, because quickshell prints both. A binding error says
# "@ui/lock/LockFace.qml[123:45]"; a QML engine warning uses the file's URL.
#
# ⚠️ TWO WARNINGS ARE EXPECTED AND ARE NOT FAULTS. They are filtered BY THEIR
# OWN TEXT rather than by softening the check, so everything else still fails:
#
#   "Created graphical object was not placed in the graphics scene"
#       what building an Item without a window means. The alternative is to
#       open one, which is the thing this test exists to avoid doing.
#   "Cannot open: file:///var/lib/AccountsService/icons/…"  and  "/.face"
#       the avatar. LockFace tries the two places a face picture can live and
#       draws the user's initial when neither is there — a machine with no
#       portrait is a normal machine, and the fallback is on purpose.
printf '  %-34s ' "no QML warning out of ui/lock"
noise="$(grep -iE 'ui/lock/[A-Za-z]+\.qml' "$log" \
         | grep -viE '^\s*(INFO|DEBUG)' \
         | grep -v 'not placed in the graphics scene' \
         | grep -vE 'Cannot open: file://.*(AccountsService/icons|\.face)' || true)"
if [[ -z "$noise" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203m%s line(s)\033[0m\n' "$(wc -l <<< "$noise")"
    sed 's/^/      /' <<< "$noise" | head -10
    fail=1
fi

exit $fail
