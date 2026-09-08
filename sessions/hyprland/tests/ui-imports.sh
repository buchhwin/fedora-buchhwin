#!/usr/bin/env bash
#
# The fourth tripwire: ui/ does not reach into Quickshell.Services directly.
#
# The rule is written at the top of shell/services/qmldir — every service is a
# singleton with an `available` flag, and the ui asks it rather than the module,
# so a surface can find out whether the hardware is there instead of assuming.
#
# ⚠️ IT WAS BROKEN IN THE WORST POSSIBLE WAY: not by importing the module, but by
# using a name FROM it without importing anything. NotificationsPage compared
# `row.modelData.urgency` against `NotificationUrgency.Critical` with no import
# in the file, so the name was undefined, the binding threw a ReferenceError,
# and QML did what it always does with a binding that throws — it kept the
# property's default. Rectangle's default colour is white. The result was a
# white square beside every notification on a dark panel, measured off a
# screenshot at 254,254,254, and nothing said a word about it.
#
# So the check is on the import, and the enums moved behind the services that
# own them (see Notifications.urgencyOf).
#
# A file that genuinely needs a module — the lock screen needs PAM, and there is
# no sensible service wrapper for "ask the user for their password" — says so on
# the line:
#
#     import Quickshell.Services.Pam    // services-ok: PAM is not a device
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0

while IFS=: read -r file line text; do
    [[ -z "${line:-}" ]] && continue
    [[ "$text" == *"services-ok"* ]] && continue
    printf '  \033[38;5;203m%s\033[0m  %s\n' "direct-import  $file:$line" \
           "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-60)"
    fail=1
done < <(grep -rn '^[[:space:]]*import Quickshell\.Services' shell/ui 2>/dev/null)

if (( fail )); then
    cat <<'EOF'

  A surface that talks to Quickshell.Services directly has no `available` flag
  to consult, so it cannot tell "there is no hardware" from "it is not ready
  yet" — and a name used from a module that was never imported is worse still:
  the binding throws and the property silently keeps its default.

  Put it behind a singleton in shell/services/ and let the surface ask that.
EOF
    exit 1
fi

echo "  no surface imports Quickshell.Services directly"
