#!/usr/bin/env bash
#
# Axis 7: every surface opens AND closes, and leaves nothing behind.
#
# tests/ipc-effect.sh already asks the first half — press the verb, does the page
# appear. This asks the half that only shows up after a while:
#
#   * does it CLOSE again, or does the notch keep a page open that nobody can
#     see because the next one drew over it
#   * is there still exactly ONE quickshell instance afterwards. Quickshell
#     leaves an instance directory behind for every run and never removes one;
#     407 of them, 15 MB of tmpfs, had accumulated on the test machine before
#     `bhctl prune` existed. A surface that spawns a helper and does not reap it
#     is the same leak with a different name.
#   * did anything reach the journal. A binding that throws while a surface is
#     being built does not crash the shell — it leaves the property at its
#     default and writes one line. That is how a white square shipped beside
#     every notification, and how the settings gear did nothing at all for a day.
#
# ⚠️ IT NEEDS A RUNNING SHELL, so it exits 2 without one, exactly as
# tests/ipc-effect.sh and tests/generated-read.sh do. It is deliberately not in
# CI: a build container has no session for it to talk to.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# ⚠️⚠️ NOT `qs -c buchhwin ipc`, AND THAT ONE WORD IS WHY THIS SUITE USED TO
# PASS ALONE AND FAIL IN A STACK. The lock screen is a second instance of the
# same config; while it lives, the config name matches two processes and every
# call answers "Target not found". tests/shell-ipc.sh names the PROCESS.
. "$(dirname "$0")/shell-ipc.sh"

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }
# ⚠️ WAYLAND_DISPLAY HAS TO BE RIGHT, and the failure looks like a dead shell:
# `qs ipc call` matches instances by display connection as well as by config
# path, so over an ssh session with no WAYLAND_DISPLAY it answers "No running
# instances" while `qs list --all` cheerfully shows the shell running. Measured,
# after ten minutes of believing the shell had crashed.
bh_shell_answers || {
    echo "no running shell to ask (WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset};"
    echo "  over ssh it must name the session's display, e.g. wayland-1)"
    exit 2
}

fail=0

# ⚠️ The same list as tests/ipc-effect.sh, and for the same reason: only verbs
# that OPEN a page. `mic` and its neighbours toggle a service and close
# themselves, so asserting they stay open would be a check that is right nine
# times in ten — which teaches people to ignore it.
verbs="media quick notifications calendar tray workspaces monitors wallpaper theme
event brightness calculator timer session clipboard"

# The journal cursor BEFORE anything is touched, so the comparison covers this
# run and not whatever the shell said at boot.
since="$(date '+%Y-%m-%d %H:%M:%S')"
sleep 1

before="$(ls "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/by-id" 2>/dev/null | wc -l)"

stuck=""
for v in $verbs; do
    bh_ipc call notch "$v" >/dev/null 2>&1
    sleep 0.4
    open="$(bh_ipc call notch state 2>/dev/null | tr -d '[:space:]')"
    bh_ipc call notch collapse >/dev/null 2>&1
    sleep 0.4
    shut="$(bh_ipc call notch state 2>/dev/null | tr -d '[:space:]')"
    # ⚠️ Both halves. Asserting only that it closes would pass a verb that never
    # opened anything at all — the state was already collapsed, so collapsing it
    # again "works". That is exactly the shape `notch settings` had.
    # ⚠️ CLOSED IS THE EMPTY STRING, not the word "collapsed". `notch state`
    # returns `root.page` verbatim (shell/ipc/Ipc.qml:229) and collapsing clears
    # it. Expecting a word here reported all fourteen surfaces as stuck open on
    # a shell that was closing every one of them correctly — the check was right
    # and the expectation was invented.
    [[ "$open" == "$v" ]] || stuck+=" $v(did-not-open:$open)"
    [[ -z "$shut" ]] || stuck+=" $v(did-not-close:$shut)"
done

printf '  %-40s ' "every surface opens and closes again"
if [[ -z "$stuck" ]]; then
    printf '\033[38;5;114mok\033[0m  %d surfaces\n' "$(wc -w <<< "$verbs")"
else
    printf '\033[38;5;203m%s\033[0m\n' "$stuck"; fail=1
fi

printf '  %-40s ' "still exactly one quickshell instance"
after="$(ls "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/by-id" 2>/dev/null | wc -l)"
if [[ "$after" == "$before" ]]; then
    printf '\033[38;5;114mok\033[0m  %s\n' "$after"
else
    printf '\033[38;5;203m%s before, %s after\033[0m\n' "$before" "$after"; fail=1
fi

printf '  %-40s ' "and nothing reached the journal"
# ⚠️ org.bluez is filtered by name and the reason is written down rather than
# assumed: it is quickshell's own D-Bus probe on a machine with no Bluetooth
# adapter, it appears once at every start, and it belongs to quickshell rather
# than to this shell. Everything else counts — a filter list that grows is a
# filter list that stops finding things.
noise="$(journalctl --user -u buchhwin-shell --since "$since" --no-pager 2>/dev/null \
         | grep -E 'WARN|ERROR|qml:|TypeError|Cannot|undefined|is not a' \
         | grep -v 'org.bluez' || true)"
if [[ -z "$noise" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203m%s line(s)\033[0m\n' "$(wc -l <<< "$noise")"
    head -6 <<< "$noise" | sed 's/^/      /'
    fail=1
fi

# ---------------------------------------------------------------------------
# ⚠️ EVERY SURFACE'S ENABLE CONDITION HAS TO SURVIVE A NULL BLOCK, and this is
# the wire against the fault he reported as "the dock cannot be switched off" —
#
# Config.qml documents the window: while shell.json is being deserialised,
# `adapter.<block>` is NULL rather than "still the defaults". A binding written
# `Config.bar.enabled && …` throws on that null, and a binding that throws
# keeps its last value — the schema default — and is never re-evaluated. The
# surface then comes up switched off and stays up.
#
# It is invisible for any surface whose default is ON, which is why the bar, the
# notch and the launcher were all wrong the same way and nobody could see it.
# So this is a text check: no `Config.<block>.` may appear in an activation
# condition in ui/Shell.qml without a guard on the block itself.
printf '  %-38s ' "surface conditions guard the null window"
# ⚠️ IT READS WHOLE BINDINGS, NOT LINES, AND THE FIRST VERSION DID NOT — so the
# red probe stayed green. A binding written over two lines has `Config.bar.` on
# the SECOND one, and a per-line grep for the declaration never sees it. That is
# a check that cannot fail at the exact fault it was written for, which is worse
# than no check: this file would have gone on reporting "ok" for ever. Found by
# putting the bug back deliberately, which is the only reason it was found.
report="$(awk '
    function flush(  blk, i) {
        if (n == 0) return
        blk = ""
        for (i = 0; i < n; i++) blk = blk " " buf[i]
        # Every block this binding reads.
        tmp = blk
        while (match(tmp, /Config\.[a-zA-Z]+\./)) {
            b = substr(tmp, RSTART + 7, RLENGTH - 8)
            tmp = substr(tmp, RSTART + RLENGTH)
            # Guarded as `Config.b ?` or `Config.b &&`.
            if (blk !~ ("Config\\." b "[ \t]*[?]") && blk !~ ("Config\\." b "[ \t]*&&"))
                print start ":" b ":" substr(blk, 1, 70)
        }
        n = 0
    }
    /^[ \t]*(activeAsync|readonly property bool [a-zA-Z]+Here)[ \t]*:/ {
        flush(); start = NR; buf[n++] = $0; next
    }
    n > 0 {
        # The binding ends where the next member starts, or at a blank line.
        if ($0 ~ /^[ \t]*$/ || $0 ~ /^[ \t]*(component|readonly|property|LazyLoader|Loader|\})/) { flush(); next }
        buf[n++] = $0
    }
    END { flush() }
' shell/ui/Shell.qml | sort -u)"
if [[ -z "$report" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203munguarded\033[0m\n'
    while IFS=: read -r ln blk body; do
        printf '      Shell.qml:%-4s Config.%s — %s\n' "$ln" "$blk" "$(sed 's/^ *//;s/  */ /g' <<< "$body")"
    done <<< "$report"
    printf '      a null block throws, and a binding that throws keeps the default\n'
    fail=1
fi

exit $fail
