#!/usr/bin/env bash
#
# Restarting the shell must not lock somebody out of their machine.
#
# ⚠️ THIS IS A MEASURED LOCKOUT, not a hypothetical one. The lock screen used to
# be a plain child process of the shell, so it lived in
# buchhwin-shell.service's control group — and that unit is
# KillMode=control-group. On a locked session:
#
#   locked                        3 qs processes   LockedHint=yes
#   restart buchhwin-shell        2 qs processes   LockedHint=yes
#                                 and typing the password does nothing
#
# The compositor keeps the session locked when the locking client dies, which is correct
# and is the entire security property of ext-session-lock. What is left is a
# machine with no way in short of another terminal. The paths that reach it are
# ordinary: the rescue key, `bhctl update`, and Restart=always after a crash.
#
# ⚠️ IT DOES NOT LOCK YOUR SCREEN TO FIND OUT. A test that locks the machine it
# runs on is a test nobody runs twice, and it would lock his laptop the first
# time he ran the suite. So the MECHANISM is measured against a dummy unit that
# sleeps, in exactly the arrangement the real one is in, and a text check ties
# Idle.qml to that mechanism. Both halves are needed: the behaviour check alone
# would stay green if Idle.qml went back to a bare child, and the text check
# alone would be a green line about a string.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v systemd-run >/dev/null || { echo "systemd-run not installed"; exit 2; }
systemctl --user is-system-running >/dev/null 2>&1 \
    || [[ -n "${XDG_RUNTIME_DIR:-}" && -S "${XDG_RUNTIME_DIR}/systemd/private" ]] \
    || { echo "no user systemd here (a build container has none)"; exit 2; }

fails=0
ok()  { printf '  \033[38;5;114mok\033[0m   %s\n' "$1"; }
bad() { printf '  \033[38;5;203mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }

parent=buchhwin-locktest-parent
child=buchhwin-locktest-child
cleanup() {
    systemctl --user stop    "$parent" "$child" >/dev/null 2>&1
    systemctl --user reset-failed "$parent" "$child" >/dev/null 2>&1
}
trap cleanup EXIT
cleanup

# ── 1 · the mechanism: a transient unit outlives the group that started it ──
#
# The parent stands in for buchhwin-shell.service: KillMode=control-group, and
# it starts the child the way Idle.qml now starts the lock screen. Stopping the
# parent must not take the child with it.
systemd-run --user --quiet --collect --unit="$parent" \
    -p KillMode=control-group \
    sh -c "systemd-run --user --quiet --collect --unit=$child sh -c 'sleep 120'; sleep 120" \
    >/dev/null 2>&1

for _ in 1 2 3 4 5 6 7 8 9 10; do
    systemctl --user is-active --quiet "$child" && break
    sleep 0.3
done

if systemctl --user is-active --quiet "$child"; then
    ok "the lock screen starts in a unit of its own"
else
    bad "the child unit never started — the mechanism does not work here"
fi

# ⚠️ ITS OWN CONTROL GROUP IS THE WHOLE POINT, so it is read rather than assumed.
# A child in the parent's group would pass the "is it running" line above right
# up until the parent was stopped.
cg="$(systemctl --user show "$child" -p ControlGroup --value 2>/dev/null)"
if [[ "$cg" == *"$child"* && "$cg" != *"$parent"* ]]; then
    ok "…in its own control group ($cg)"
else
    bad "the child is inside the parent's group — a restart would kill it: $cg"
fi

systemctl --user stop "$parent" >/dev/null 2>&1
sleep 1
if systemctl --user is-active --quiet "$child"; then
    ok "stopping the shell's group leaves it running"
else
    bad "stopping the shell's group killed it — this is the lockout"
fi
cleanup

# ── 2 · …and Idle.qml actually uses it ──────────────────────────────────────
#
# ⚠️⚠️ COMMENTS DO NOT COUNT, and the `--collect` check below was blind because
# of it. Measured, with the control that decides it: take `--collect` out of the
# one line that runs (`:149`) and leave the note above it alone, and the check
# stayed GREEN — because `--collect` is also the first word of the comment at
# `:141` that explains why it is there.
#
# That is the worst shape of this fault: the better the code is documented, the
# more certainly the checker passes over its own removal. The two checks either
# side of it (`systemd-run --user`, `--unit=buchhwin-lock`) happen to appear in
# code only, so they were sound by luck rather than by construction.
idle_eff="$(grep -vE '^[[:space:]]*//' shell/services/Idle.qml)"

if grep -q 'systemd-run --user' <<< "$idle_eff"; then
    ok "Idle.qml starts the lock screen as a unit"
else
    bad "Idle.qml does not use systemd-run — the lock screen is a child again"
fi

if grep -q -- '--unit=buchhwin-lock' <<< "$idle_eff"; then
    ok "…under a fixed name, which is what refuses a second lock screen"
else
    bad "no fixed unit name — nothing stops a second lock screen starting"
fi

# ⚠️ A FAILED TRANSIENT UNIT KEEPS ITS NAME. Without --collect (or a
# reset-failed) one crash of the lock screen means the name stays taken and the
# screen never locks again — silently, because `lock()` would go on being called
# and go on being refused.
if grep -q -- '--collect' <<< "$idle_eff"; then
    ok "…and collected, so one crash does not disable locking for good"
else
    bad "no --collect: a failed lock screen would hold its name and locking would stop"
fi

# The old shape, named so it cannot come back by accident.
if grep -qE 'command: \[.*"BUCHHWIN_MODE=lock qs' <<< "$idle_eff"; then
    bad "the lock screen is started as a bare child again — see the note above"
else
    ok "the lock screen is not a bare child of the shell"
fi

(( fails == 0 )) || exit 1
exit 0
