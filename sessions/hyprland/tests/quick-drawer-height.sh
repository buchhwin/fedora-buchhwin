#!/usr/bin/env bash
# B67 · B68 · closing a drawer must give the height back.
#
# His report: "wenn man WLAN oder Bluetooth ausklappen geht alles wenns man     # english-ok: the report, quoted
# einklappt bleibt die neue Größe und das Fenster geht nicht wieder auf die     # english-ok: the report, quoted
# ursprungsgröße zurück … also bei allem bitte fixen".                          # english-ok: the report, quoted
#
# ⚠️⚠️ THIS NEEDS THE AUDIO FIXTURE, AND THAT IS THE POINT. The lab VM has no
# sound card, no wifi and no bluetooth, so every drawer opens EMPTY there — and
# an empty drawer never grows, so it can never fail to shrink either. A whole
# round was spent measuring clean numbers on a machine that could not stage the
# fault. `BUCHHWIN_SHELL_FAKE=1` gives the sound and microphone drawers real
# entries, which is rule 4's "what CAN it measure against here": a fixture, not
# a relaxed claim.
#
# The cause it guards: a Loader with `active: false` keeps its last implicit
# height. The item is destroyed, the reserved room is not.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; yellow=$'\e[38;5;179m'; off=$'\e[0m'
ok()   { printf '  %sok%s   %s\n'   "$green"  "$off" "$1"; }
bad()  { printf '  %sFAIL%s %s\n'   "$red"    "$off" "$1"; fail=1; }
skip() { printf '  %s--%s   %s\n'   "$yellow" "$off" "$1"; }

command -v qs >/dev/null 2>&1 || { skip "quickshell is not installed"; exit 2; }

# ------------------------------------------------------------ 1 · static half
#
# Runs anywhere, including CI, and catches the exact line being removed.
F=shell/ui/quick/QuickSettings.qml
src="$(cat "$F")"
if grep -q 'Layout.preferredHeight: (drawer.active && drawer.item)' <<< "$src"; then
    ok "the drawer loader pins its height to its item"
else
    bad "the drawer loader no longer resets its height when deactivated"
fi

# ---------------------------------------------------------- 2 · functional half
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/buchhwin-shell.service.d"
# ⚠️ SOURCED, NOT RETYPED — rule 6. The copy that used to stand here knew only
# the systemd unit, so it could not find a shell started by hand and it did not
# filter out the lock screen's instance.
. "$(dirname "$0")/shell-ipc.sh"
if ! bh_shell_pid >/dev/null; then
    skip "buchhwin-shell is not running — static half only"
    exit "$fail"
fi

q() { bh_ipc call "$@" 2>&1; }
probe="$(q notch state)"
case "$probe" in
    *"not found"*|*"Function"*) skip "this shell has no notch IPC"; exit "$fail" ;;
esac

# ⚠️ THE FIXTURE IS INSTALLED AND REMOVED AGAIN, and the removal is read back.
# A test that leaves a machine running on fake audio has broken the desktop it
# was checking.
had_fixture=0
[[ -f "$UNIT_DIR/fake.conf" ]] && had_fixture=1
cleanup() {
    if (( had_fixture == 0 )); then
        rm -f "$UNIT_DIR/fake.conf"
        rmdir "$UNIT_DIR" 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user restart buchhwin-shell 2>/dev/null || true
    fi
}
trap cleanup EXIT

mkdir -p "$UNIT_DIR"
printf '[Service]\nEnvironment=BUCHHWIN_SHELL_FAKE=1\n' > "$UNIT_DIR/fake.conf"
systemctl --user daemon-reload
systemctl --user restart buchhwin-shell
sleep 4
# ⚠️ No second PID lookup here any more, and that is the point of sourcing it:
# `bh_ipc` resolves the shell on every call, so a restart in the middle of a
# measurement cannot leave the rest of it talking to a process that is gone.
# The copy that used to be here captured the PID once, before this restart.

height() { q notch size | awk '{print $2}'; }

q notch collapse >/dev/null; sleep 0.5
q notch tab 0 >/dev/null; sleep 1.5
shut="$(height)"
if [[ -z "$shut" ]]; then
    skip "the card reported no height"
    exit "$fail"
fi
ok "the panel starts at ${shut}px"

for d in sound mic; do
    q notch drawer "$d" >/dev/null; sleep 1.2
    open="$(height)"
    q notch drawer "$d" >/dev/null; sleep 1.2
    back="$(height)"

    if [[ -z "$open" || "$open" == "$shut" ]]; then
        # ⚠️ NOT A PASS. A drawer that did not grow proves nothing about
        # shrinking, and reporting green here is how this went unnoticed.
        skip "the $d drawer did not grow (${shut} -> ${open:-?}) — nothing to prove"
        continue
    fi
    ok "the $d drawer grows to ${open}px"

    if [[ "$back" == "$shut" ]]; then
        ok "and closing it returns to ${back}px"
    else
        bad "the $d drawer kept its height: ${shut} -> ${open} -> ${back:-?}"
    fi
done

q notch collapse >/dev/null
exit "$fail"
