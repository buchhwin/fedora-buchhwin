#!/usr/bin/env bash
#
# The calendar's HTTP transport — the method it can send, and where the token
# goes.
#
# ⚠️ WHY THIS EXISTS AT ALL. QML's XMLHttpRequest has no `REPORT`, and REPORT is
# the only way CalDAV asks for events, so the calendar could never have fetched
# an appointment however good the token was. The transport is `curl` now, and
# both properties that buys are invisible from the screen: a regression leaves a
# calendar that is merely empty, and a token on the command line looks exactly
# like a token that is not.
#
# Three halves, and the middle one is the one with teeth:
#
#   1. The config we hand curl (shell/tools/caldav-check.qml), plus a live
#      REPORT against a throwaway server that really answers.
#   2. ⚠️ THE ARGV SCAN, WITH A CONTROL THAT CAN FAIL. "No token found" from a
#      scan that finds nothing either way is not a measurement — the first
#      version of this check matched its own `grep` and reported a hit for both
#      cases, which is the trap tests/xwayland.sh fell into.
#   3. No call site may go back to XMLHttpRequest.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
ok()  { printf '  %sok%s   %s\n' "$green" "$off" "$1"; }
bad() { printf '  %sFAIL%s %s\n' "$red" "$off" "$1"; fail=1; }

# ------------------------------------------------------------------- 3 static
# ⚠️ The comment-free copy is built ONCE rather than piped, because
# `… | grep -q` under `pipefail` reports failure the moment grep leaves early —
# and here that would read as "no call site went back to XMLHttpRequest", which
# is the answer nobody would question. See tests/pipefail-grep.sh.
calendar_code="$(grep -v '^\s*//' shell/services/Calendar.qml)"
if grep -q "XMLHttpRequest" shell/services/Calendar.qml \
   && grep -q "XMLHttpRequest" <<< "$calendar_code"; then
    bad "Calendar.qml uses XMLHttpRequest again in code — Qt cannot send REPORT, so events would silently stop arriving"
else
    ok "no call site went back to XMLHttpRequest"
fi

if grep -nE '"-H"|-H "Authorization' shell/services/Calendar.qml >/dev/null; then
    bad "Calendar.qml passes a header on curl's command line — /proc/<pid>/cmdline is world-readable"
else
    ok "no header is passed on the command line"
fi

command -v curl >/dev/null || { echo "  curl not installed"; exit 2; }
command -v python3 >/dev/null || { echo "  python3 not installed — cannot run a throwaway server"; exit 2; }

# --------------------------------------------------------------- 2 the argv scan
#
# A curl that finishes before the scan runs is a scan that finds nothing for the
# wrong reason, so both cases aim at an unroutable address and sit in connect.
scan_argv() {   # $1 = needle. Reads /proc directly: a `ps | grep` matches itself.
    local n=0 c
    for p in /proc/[0-9]*/cmdline; do
        c=$(tr '\0' ' ' < "$p" 2>/dev/null) || continue
        case "$c" in *curl*"$1"*) n=$((n+1));; esac
    done
    printf '%s' "$n"
}

needle="ARGV-SCAN-TOKEN-4c1e"
# ⚠️⚠️ A LOCAL BLACK HOLE, NOT AN UNROUTABLE ADDRESS, and the first two attempts
# at this both failed for opposite reasons:
#
#   10.255.255.1   hangs in connect — but it is an RFC1918 address in a public
#                  repo, which reads like somebody's real network. This project
#                  has already published one of those by accident.
#   192.0.2.1      is TEST-NET-1 and therefore unimpeachable — and it FAILS
#                  INSTANTLY here, so curl was gone before the scan ran and the
#                  control reported "not found" for both cases. A control that
#                  cannot fail is worth less than no control.
#
# A socket that listens and never accepts is deterministic and needs no network
# at all: the kernel completes the handshake into the backlog, so curl believes
# it is connected and then waits for a response that never comes.
python3 - <<'PY' &
import socket, time
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 45789))
s.listen(8)          # listen, never accept
time.sleep(30)
PY
hole=$!
# ⚠️ ONE EXIT TRAP, AND IT CLEANS UP BOTH. bash keeps a single EXIT handler, so
# a second `trap … EXIT` further down REPLACES this one rather than adding to
# it — which is how the first version of this file left a python process behind
# on every run. `srv` is empty until the http server starts; `kill ""` is
# harmless and `2>/dev/null` covers it.
srv=""
trap 'kill "$hole" "$srv" 2>/dev/null' EXIT
for _ in $(seq 1 40); do
    (exec 3<>/dev/tcp/127.0.0.1/45789) 2>/dev/null && break
    sleep 0.1
done
hang="http://127.0.0.1:45789/probe"

curl -s --max-time 6 -H "Authorization: Bearer $needle" "$hang" -o /dev/null &
pos_pid=$!
sleep 1.5
positive=$(scan_argv "$needle")
kill "$pos_pid" 2>/dev/null; wait "$pos_pid" 2>/dev/null

printf 'url = "%s"\nheader = "Authorization: Bearer %s"\nmax-time = 6\nsilent\n' \
       "$hang" "$needle" | curl --config - -o /dev/null 2>/dev/null &
neg_pid=$!
sleep 1.5
negative=$(scan_argv "$needle")
kill "$neg_pid" 2>/dev/null; wait "$neg_pid" 2>/dev/null

# ⚠️ THE CONTROL IS CHECKED FIRST. If the positive case does not find the token
# the scan is broken, and the negative result below means nothing at all.
if [[ "$positive" -ge 1 ]]; then
    ok "the argv scan can see a token on the command line (control: $positive)"
else
    bad "the argv scan found nothing even with the token on the command line — the scan is broken, so its verdict below is worthless"
fi

if [[ "$negative" -eq 0 ]]; then
    ok "a token passed through --config never reaches argv (0 hits)"
else
    bad "the token was visible in argv $negative times even through --config"
fi

# ------------------------------------------------------- 1 the config and a live call
command -v qs >/dev/null || { echo "  quickshell (qs) not installed"; exit 2; }

port=$(python3 - <<'PY'
import socket
s = socket.socket(); s.bind(("127.0.0.1", 0))
print(s.getsockname()[1]); s.close()
PY
)

python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1 &
srv=$!
trap 'kill "$srv" 2>/dev/null' EXIT

# Wait for it to answer rather than sleeping at it.
for _ in $(seq 1 40); do
    curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$port/" && break
    sleep 0.1
done

rm -f /tmp/buchhwin-caldav-check.txt

BUCHHWIN_TOOL=caldav-check \
BUCHHWIN_CALDAV_PORT="$port" \
QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1

if [[ ! -f /tmp/buchhwin-caldav-check.txt ]]; then
    bad "no output — the tool did not run"
    exit 1
fi

sed -e "s/^  ok /  ${green}ok${off} /" \
    -e "s/^  FAIL /  ${red}FAIL${off} /" /tmp/buchhwin-caldav-check.txt

grep -q '^  FAIL' /tmp/buchhwin-caldav-check.txt && fail=1
exit $fail
