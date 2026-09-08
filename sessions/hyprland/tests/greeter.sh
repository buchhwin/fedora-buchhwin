#!/usr/bin/env bash
#
# The login screen has to build, and it has to build without complaints.
#
# ⚠️ THIS IS tests/lock.sh's ARGUMENT, ONE STEP MORE SERIOUS. Two faults lived
# in the lock screen for four rounds because nothing built that file:
# tests/smoke.sh starts the SHELL and the lock screen is its own process. The
# greeter is a different process AND a different user AND a different copy of
# the tree (/usr/share/buchhwin/shell, because Fedora home directories are
# 0700). A lock screen that does not come up is an inconvenience. A login screen
# that does not come up is a machine nobody can get into.
#
# Two halves, and only together are they a check:
#
#   1. shell/tools/greeter-check.qml builds GreeterFace and asks it for the
#      parts the brief names — who, which session, and that it admits when it
#      is guessing.
#   2. This script reads the process's STDERR. A binding that names something
#      which no longer exists does not stop the object being built: it throws
#      when evaluated, leaves the property at its default, and warns. That is
#      exactly how the lock screen's avatar ring shipped invisible.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

fail=0
log="$(mktemp)"
report=/tmp/buchhwin-greeter-check.txt
trap 'rm -f "$log"' EXIT
rm -f "$report"

# Its own XDG_CONFIG_HOME, same reason as tests/lock.sh: the face reads Config,
# and a test that picks up the caller's shell.json answers a different question
# on every machine.
tmp="$(mktemp -d)"
mkdir -p "$tmp/buchhwin"
printf '{"version":8}\n' > "$tmp/buchhwin/shell.json"

# ⚠️⚠️ THE USER LIST IS READ FROM A FIXTURE, NOT FROM THIS MACHINE, and that is
# a repair rather than a refinement. The check used to read the real /etc/passwd
# and ask only whether it found "at least one human". Two things were wrong with
# that at once:
#
#   1. It fails where it should not. The `qml` lane runs in `container:
#      fedora:44`, and a fresh Fedora image has no account at UID >= 1000 — so
#      the greeter correctly reported "No users found" and three checks went red
#      over the machine rather than over the code. That is the question rule 4
#      asks: does the ENVIRONMENT explain the result?
#   2. It passes where it should not. "At least one" is true on any developer
#      laptop no matter what the filter does — delete the UID test, delete the
#      nologin test, and it still finds a human. The check could not fail for the
#      reason it exists.
#
# An absolute path, because the tool resolves it from wherever qs is running.
fixture="$PWD/tests/fixtures/passwd"
[[ -f "$fixture" ]] || { echo "no passwd fixture at $fixture"; exit 2; }

printf '  %-34s ' "GreeterFace builds headless"
XDG_CONFIG_HOME="$tmp" BUCHHWIN_TOOL=greeter-check QT_QPA_PLATFORM=offscreen \
    BUCHHWIN_PASSWD_FAKE="$fixture" \
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

# The second half. Only warnings naming a file under ui/greeter count.
#
# ⚠️ THREE EXPECTED WARNINGS, FILTERED BY THEIR OWN TEXT rather than by
# softening the check, so everything else still fails:
#
#   "Created graphical object was not placed in the graphics scene"
#       what building an Item without a window means. Opening one is the thing
#       this test exists to avoid.
#   "Cannot open: file:///var/lib/AccountsService/icons/…"
#       the avatar. A machine with no portrait is a normal machine and the
#       initial is the intended fallback.
#   anything naming Greetd being unavailable
#       `Greetd.available` is false anywhere that is not an actual greeter
#       session — CI included. The face is required to SAY so, which is checked
#       in the first half; it is not required to stay quiet about it.
#   "No PanelWindow backend loaded"  (GreeterScreen.qml)
#       the offscreen platform has no Wayland connection, so a layer surface
#       cannot exist. This is the greeter's version of the lock screen's "not
#       placed in the graphics scene": a statement about the test environment,
#       not about the file. ⚠️ It is filtered by its own text and only its own
#       text — a real fault in GreeterScreen still comes through here.
printf '  %-34s ' "no QML warning out of ui/greeter"
noise="$(grep -iE 'ui/greeter/[A-Za-z]+\.qml' "$log" \
         | grep -viE '^\s*(INFO|DEBUG)' \
         | grep -v 'not placed in the graphics scene' \
         | grep -vE 'Cannot open: file://.*AccountsService/icons' \
         | grep -viE 'greetd (is )?(not|un)available' \
         | grep -v 'No PanelWindow backend loaded' || true)"
if [[ -z "$noise" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203m%s line(s)\033[0m\n' "$(wc -l <<< "$noise")"
    sed 's/^/      /' <<< "$noise" | head -10
    fail=1
fi

# ⚠️ AND THE ONE THING NEITHER HALF ABOVE CAN SEE: that the greeter does not
# reach for PAM. It must not — greetd owns the conversation and runs it as root
# on the greeter's behalf, and a greeter that authenticated by itself would have
# to be root to do it. This is a text check because the alternative is running
# an authentication conversation in CI.
#
# ⚠️ COMMENTS ARE STRIPPED FIRST, and this file learned that the hard way on its
# own first run: the check went red against the SENTENCE in GreeterFace.qml that
# says "there is no PamContext here and there must not be one". tests/
# lock-idents.sh has the same warning at the top — a check that reads source has
# to read source, not prose about source. That is now three times in this
# project, and this is the second-funniest.
printf '  %-34s ' "it talks to greetd, not to PAM"
code="$(sed 's://.*::' shell/ui/greeter/*.qml)"
if grep -qE 'Quickshell\.Services\.Pam|PamContext[ \t]*\{' <<< "$code"; then
    printf '\033[38;5;203mPamContext in ui/greeter\033[0m\n'
    grep -nE 'Quickshell\.Services\.Pam|PamContext[ \t]*\{' shell/ui/greeter/*.qml | sed 's/^/      /'
    fail=1
elif ! grep -q 'Quickshell\.Services\.Greetd' shell/ui/greeter/GreeterFace.qml; then
    printf '\033[38;5;203mno Greetd import at all\033[0m\n'
    fail=1
else
    printf '\033[38;5;114mok\033[0m\n'
fi

exit $fail
