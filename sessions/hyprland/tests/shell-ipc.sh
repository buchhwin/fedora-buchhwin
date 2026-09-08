# shellcheck shell=bash
#
# Talking to THE SHELL, and to nothing else that happens to share its name.
# Sourced by every suite that drives the running shell over ipc; never executed.
#
# ⚠️⚠️ THIS FILE EXISTS BECAUSE OF ONE MEASURED FAULT WITH SEVERAL FACES.
# `surfaces.sh` and `ipc-effect.sh` each passed on their own and failed inside a
# stack run, and it was read as flaky suites for weeks. It is one line:
#
# ⚠️ AND THIS PARAGRAPH USED TO NAME A THIRD SUITE, `bhctl-usage.sh`, WHICH WAS
# NEVER INVOLVED. Checked to the bottom of its history: it contains no `qs`, no
# `bh_ipc` and no reference to this file — it reads `bin/bhctl` with sed and says
# so in its own header ("Reads the file. Nothing is executed"). It cannot collide
# with a lock screen because it never speaks to a shell. Whichever suite the
# third face really was, it is not that one, and a wrong name in an explanation
# sends the next person to read a file that has nothing to say.
#
#   the lock screen is a SECOND instance of the SAME config —
#   systemd-run … sh -c 'BUCHHWIN_MODE=lock qs -c buchhwin'
#
# `qs -c buchhwin ipc call …` matches instances by config path, so while the
# session is locked — or while any suite that locked it has not cleaned up —
# the name matches two processes and every call answers:
#
#   Target not found.
#
# which reads like a missing handler and is a name collision. Any suite that
# runs after one that locks is then measuring nothing, and says so in the
# vocabulary of a broken desktop.
#
# ⚠️ THE FIX IS TO NAME THE PROCESS, NOT THE CONFIG. And `--pid` belongs AFTER
# `ipc`: `qs --pid N ipc call …` answers "The following arguments were not
# expected", which sounds like the option does not exist. It does.
#
# ⚠️ FIRST AID FOR "the ipc does not answer": `qs ipc --pid N show`. An empty
# list from a shell that is plainly running means you are talking to the wrong
# instance — not that the handlers are gone.

# The PID of the shell, never of the lock screen.
bh_shell_pid() {
    local pid
    pid="$(systemctl --user show buchhwin-shell -p MainPID --value 2>/dev/null)"
    if [[ "${pid:-0}" -gt 0 ]]; then
        printf '%s' "$pid"
        return 0
    fi
    # ⚠️ THE FALLBACK STILL HAS TO TELL THEM APART, so it asks each candidate
    # what it was started as rather than taking the first one. A shell started
    # by hand — which is how half of this gets debugged — has no unit to ask.
    local p env_of
    for p in $(pgrep -f 'qs -c buchhwin' 2>/dev/null); do
        # ⚠️ INTO A VARIABLE FIRST, never a pipeline into `grep -q`. Under
        # pipefail grep leaves at its first match, the writer takes SIGPIPE and
        # the whole pipeline reports failure — exactly when the match is early.
        # tests/pipefail-grep.sh guards it, and caught this line.
        env_of="$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null || true)"
        grep -q '^BUCHHWIN_MODE=lock$' <<< "$env_of" && continue
        printf '%s' "$p"
        return 0
    done
    return 1
}

# `bh_ipc call notch state`, `bh_ipc show`, … — the same words `qs ipc` takes.
bh_ipc() {
    local pid
    pid="$(bh_shell_pid)" || return 2
    qs ipc --pid "$pid" "$@"
}

# Is there a shell to talk to at all? Suites use this for their exit-2 guard.
#
# ⚠️⚠️ NOT `call notch state`, AND NOT THE EXIT CODE. Measured, both halves:
#
#   qs -c buchhwin ipc call notch state   ->  "Target not found."   exit 0
#   qs ipc --pid <shell> call notch state ->  ""                    exit 0
#
# `qs ipc call` reports a missing target on stdout and still exits 0, so a guard
# written `… >/dev/null || exit 2` cannot fire. And an empty answer is not proof
# of a problem either: a collapsed notch answers with the empty string, which is
# correct. So the guard asks for the TARGET LIST, which is never empty from a
# shell that is really there and always empty from the lock screen's instance.
bh_shell_answers() {
    local listing
    listing="$(bh_ipc show 2>/dev/null)" || return 1
    grep -q '^target ' <<< "$listing"
}
