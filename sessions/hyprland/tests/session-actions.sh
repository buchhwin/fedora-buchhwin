#!/usr/bin/env bash
#
# Lock, suspend, log out, restart, shut down — declared ONCE, read everywhere.
#
# ⚠️ THIS CHECK IS ABOUT A COPY THAT WAS ALMOST MADE. The five actions lived
# inside ui/notch/pages/SessionPage.qml. When the same five were asked for in
# the quick panel's corner, the cheap move was to write them out again — and
# that is the fault this project has already paid for four times: a name is
# changed in one place and not the other, and the copy keeps working right up
# until the day it matters.
#
# This file's own subject has the scar. `logout` and `restart_alt` are Material
# Symbols names; Fedora ships "Material Icons Round", which has neither. They
# shipped as one missing glyph and one wrong one, and were found by measuring
# glyph widths rather than by looking.
#
# ⚠️⚠️ NOTHING HERE IS EXECUTED. EVER. Four of these five end the session and
# one of them cuts the power. Every command is READ out of the QML as text and
# checked as text — the same separation tests/lock-idents.sh keeps, and for a
# much more expensive reason. If you are editing this file and reach for `eval`,
# `bash -c`, or a `$(…)` around anything below: don't.
#
# Of the five, LOCK is the only one that can be triggered on purpose and taken
# back — and even that belongs in a screenshot run with a person watching, not
# in a suite that runs on every commit.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
report() { printf '  \033[38;5;203m%s\033[0m  %s\n' "$1" "$2"; fail=1; }

src=shell/services/Session.qml
[[ -f "$src" ]] || { echo "  no $src"; exit 2; }

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "the five exist once"

# ⚠️ The `id:` keys of the action objects, not every `id:` in the file — QML's
# own `id: root` would be counted otherwise, and the check would say six.
ids="$(grep -oE '\{ id: "[a-z]+"' "$src" | sed -E 's/.*"([^"]+)".*/\1/')"
count="$(grep -c . <<< "$ids")"

if [[ "$count" -ne 5 ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    printf '      %s actions in %s, expected 5\n' "$count" "$src"
    fail=1
else
    # Every id used anywhere has to be one of these five. A surface that arms
    # "shutdown" when the service says "poweroff" arms nothing at all, silently.
    printf '\033[38;5;114mok\033[0m\n'
fi

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "no second copy of a command"

# ⚠️ THE REAL SUBJECT OF THIS FILE. Any other QML that spells out one of these
# commands is a second table by another name. `Session.qml` is allowed to; a
# test fixture is not, and neither is a page.
dupes=""
while IFS= read -r f; do
    [[ "$f" == "$src" ]] && continue
    hits="$(grep -nE '"(systemctl|loginctl)"[[:space:]]*,[[:space:]]*"(suspend|reboot|poweroff|lock-session)"' "$f")"
    [[ -n "$hits" ]] && dupes+="$f: $hits"$'\n'
done < <(find shell -name '*.qml' -type f | sort)

if [[ -n "$dupes" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "${dupes%$'\n'}"
    fail=1
    cat <<'WHY'

  A session command written outside services/Session.qml is a second table.
  Read the list from the service and call `Session.run(id)`.
WHY
else
    printf '\033[38;5;114mok\033[0m\n'
fi

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "both surfaces read the service"

for f in shell/ui/notch/pages/SessionPage.qml shell/ui/quick/SessionButtons.qml; do
    [[ -f "$f" ]] || { report "missing" "$f"; continue; }
    grep -q 'Services\.Session' "$f" \
        || report "not wired" "$f does not read Services.Session"
done
(( fail )) || printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "no ui import in the service"

# ⚠️ services/qmldir forbids it and no other service does it. A service that
# imported Ipc would be a service that closes somebody else's panel — and the
# two surfaces here want different things to happen afterwards.
if grep -qE '^import "\.\./(ui|ipc)' "$src"; then
    printf '\033[38;5;203mfound\033[0m\n'
    grep -nE '^import "\.\./(ui|ipc)' "$src" | sed 's/^/      /'
    fail=1
else
    printf '\033[38;5;114mok\033[0m\n'
fi

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "every command is clean argv"

# ⚠️ A LIST, NOT A STRING. `cmd: "systemctl poweroff"` would be handed to a
# shell, and a shell is a place where a space in a path becomes two arguments
# and a semicolon becomes a second command. Read as text, never run.
bad=""
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Everything between the brackets must be quoted words separated by commas.
    inner="${line#*[}"; inner="${inner%]*}"
    [[ "$inner" =~ ^[[:space:]]*\"[^\"]+\"([[:space:]]*,[[:space:]]*\"[^\"]+\")*[[:space:]]*$ ]] \
        || bad+="$line"$'\n'
    # A shell metacharacter inside an argv entry means somebody expected a shell.
    [[ "$inner" =~ [\;\|\&\$\`] ]] && bad+="shell metacharacter: $line"$'\n'
done < <(grep -oE 'cmd: \[[^]]*\]' "$src")

if [[ -n "$bad" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "${bad%$'\n'}"
    fail=1
else
    printf '\033[38;5;114mok\033[0m\n'
fi

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "the three that cost work ask"

# lock and suspend are reversible and go at once. The other three throw away
# every unsaved thing, and the whole reason a session menu exists here is that
# Super+Shift+E was once bound straight to the compositor's `quit`.
for id in logout reboot poweroff; do
    grep -qE "\{ id: \"$id\",.*ask: true" "$src" \
        || report "no question" "$id does not have ask: true"
done
for id in lock suspend; do
    grep -qE "\{ id: \"$id\",.*ask: false" "$src" \
        || report "asks needlessly" "$id should be ask: false"
done
(( fail )) || printf '\033[38;5;114mok\033[0m\n'

if (( fail )); then
    cat <<'EOF'

  The five session actions are one list, in shell/services/Session.qml, read by
  the notch's session page and by the quick panel's corner. Whichever surface
  you are adding, read the list — do not write it again.

EOF
fi
exit $fail
