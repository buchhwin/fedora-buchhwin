#!/usr/bin/env bash
#
# Does a PRESS reach the function? Not "does the function work" — that is what
# every other checker in this folder already asks.
#
# ⚠️⚠️ THIS IS THE BLIND SPOT THAT KEPT B20 GREEN FOR WEEKS AND B39 FOR THREE
# ROUNDS. Both faults were "the press never arrives": a slider that wrote
# nothing, and a reset that wrote a correct file the running shell never read.
# Every suite here drove the function directly — set the property, call the
# verb, assert the file — and every one of them was right and green while the
# desktop was broken from the chair. Both were found by hand with ydotool in
# the end, which is a checker nobody had written down.
#
# ⚠️ AND A TWO-STAGE BUTTON CANNOT BE MEASURED ANY OTHER WAY. "Reset this page"
# arms on the first press and acts on the second. A checker that calls the
# handler sees one step and passes; a finger sees two. That difference is
# already in this project's history as "die reset taste geht nicht".        # english-ok: his report, quoted
#
# ---------------------------------------------------------------- how it aims
#
# A click needs a screen coordinate, and under Wayland neither side has one:
#
#   * the compositor knows where the WINDOW is    — niri msg -j windows
#   * the shell knows where the ROW is inside it  — ipc call settings probe <key>
#
# Neither is guessed and neither is hardcoded, so this file does not rot when a
# page is reordered.
#
# ⚠️ EXIT 2, NOT 1, WITHOUT A SESSION. "Cannot run here" and "the desktop is
# broken" must never be the same number — a CI container answers the first.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
fail=0
ok()  { printf '  %-46s %sok%s   %s\n' "$1" "$green" "$off" "${2:-}"; }
bad() { printf '  %-46s %sFAIL%s %s\n' "$1" "$red" "$off" "${2:-}"; fail=1; }
skip() { echo "$1"; exit 2; }

command -v ydotool  >/dev/null || skip "ydotool is not installed"
command -v niri     >/dev/null || skip "niri is not installed"
command -v qs       >/dev/null || skip "quickshell (qs) is not installed"
command -v jq       >/dev/null || skip "jq is not installed"

# ⚠️ THE SOCKET IS NOT WHERE THE CLIENT LOOKS. ydotoold listens on
# /run/ydotool.sock and the client goes to /tmp/.ydotool_socket, where a stale
# file from a dead run answers "Connection refused / is ydotoold running" while
# the service is running perfectly. Measured, after ten minutes of disbelief.
export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-/run/ydotool.sock}"
[[ -S "$YDOTOOL_SOCKET" ]] || skip "no ydotoold socket at $YDOTOOL_SOCKET"

# ⚠️ THE SHELL BY PID, NEVER `qs -c buchhwin`. The lock screen is a SECOND
# instance of the same config, so while the session is locked — or while any
# checker that locked it has not cleaned up — `-c buchhwin` is ambiguous and
# every call answers "Target not found". That one line is why suites in this
# folder passed alone and failed in a stack.
#
# ⚠️⚠️ AND THIS FILE USED TO WRITE THE RULE DOWN AND THEN IMPLEMENT IT AGAIN
# BESIDE IT, which is rule 6 broken by the very comment explaining rule 6. The
# retyped version knew only the systemd unit: no /proc fallback for a shell
# started by hand, and no BUCHHWIN_MODE=lock filter. It is sourced now.
# ⚠️ `niri msg` NEEDS ITS SOCKET, AND OVER SSH NOTHING SETS IT. Without it every
# call answers as if the compositor were dead, which looks exactly like a broken
# desktop. WAYLAND_DISPLAY and XDG_RUNTIME_DIR have to be right as well — this
# project has already lost ten minutes to that combination once.
if [[ -z "${NIRI_SOCKET:-}" ]]; then
    NIRI_SOCKET="$(ls "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/niri.*.sock 2>/dev/null | head -1)"
    [[ -n "$NIRI_SOCKET" ]] && export NIRI_SOCKET
fi
niri msg -j windows >/dev/null 2>&1 || skip "niri does not answer (NIRI_SOCKET/WAYLAND_DISPLAY?)"

. "$(dirname "$0")/shell-ipc.sh"
bh_shell_pid >/dev/null || skip "buchhwin-shell is not running"
ipc() { bh_ipc call "$@" 2>/dev/null; }
ipc settings state >/dev/null || skip "the shell does not answer on ipc"

# ⚠️ A LOCKED SESSION MAKES EVERY RESULT A LIE — the click lands on the lock
# face, niri refuses screenshots, and the readings come back unchanged, which
# reads as "the press does nothing". Refuse instead of measuring that.
if [[ "$(systemctl --user is-active buchhwin-lock 2>/dev/null)" == "active" ]]; then
    skip "the session is locked — unlock it first, this measures clicks"
fi

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/buchhwin/shell.json"
[[ -f "$CFG" ]] || skip "no shell.json to watch"

# ⚠️ DOES THE ENVIRONMENT EXPLAIN THE RESULT? niri's overview covers everything
# and swallows every press, so a run started with it open would report every
# control in this window as dead. Ask, close it, and say so — rather than
# measuring through it.
if [[ "$(niri msg -j overview-state 2>/dev/null | jq -r '.is_open')" == "true" ]]; then
    niri msg action close-overview >/dev/null 2>&1 || niri msg action toggle-overview >/dev/null 2>&1
    sleep 0.6
    [[ "$(niri msg -j overview-state 2>/dev/null | jq -r '.is_open')" == "true" ]] \
        && skip "niri's overview is open and would swallow every click"
fi

# ---------------------------------------------------------------- the aiming
#
# The settings window's own position, from the compositor. `tile_pos_in_workspace_view`
# is where the tile sits on this output; `window_offset_in_tile` is the window
# inside it, and it is not always zero.
win_json() {
    niri msg -j windows 2>/dev/null \
        | jq -c 'map(select(.app_id == "org.quickshell" and .title == "Settings"))[0] // empty'
}

# ⚠️⚠️ BRING THE WINDOW INTO VIEW FIRST, AND THIS IS NOT POLITENESS. Opening a
# page over ipc does not move the workspace: measured here, the Settings window
# sat on workspace 1 while workspace 2 was in front, `niri msg -j windows` still
# reported a perfectly good position for it, the pointer went exactly where the
# arithmetic said — onto bare wallpaper — and every reading came back unchanged.
# That reads as "the press does nothing", which is the very fault this file is
# supposed to detect. It is the same trap this project already wrote down once:
# a probe click switched the workspace and three null results followed.
focus_settings() {
    local id
    id="$(win_json | jq -r '.id // empty')"
    [[ -n "$id" ]] || return 1
    niri msg action focus-window --id "$id" >/dev/null 2>&1
    sleep 0.5
}

# The window's origin — but only once it is proven to be ON THE WORKSPACE IN
# FRONT. An origin for a window nobody can see is a number that looks right.
win_origin() {
    local w ws focused
    w="$(win_json)"; [[ -n "$w" ]] || return 1
    ws="$(jq -r '.workspace_id' <<< "$w")"
    focused="$(niri msg -j workspaces 2>/dev/null | jq -r 'map(select(.is_active))[].id' | tr '\n' ' ')"
    grep -qw "$ws" <<< "$focused" || {
        echo "the Settings window is on workspace $ws, which is not in front" >&2
        return 1
    }
    # ⚠️ PLUS THE OUTPUT'S OWN ORIGIN. `tile_pos_in_workspace_view` is measured
    # inside the workspace of ONE output; the pointer moves across all of them.
    # With a single screen the two are the same number and the addition is zero,
    # which is why this was invisible until the VM grew a second head.
    local ox oy
    read -r ox oy _ _ <<< "$(win_output)" || { ox=0; oy=0; }
    jq -r --argjson ox "${ox:-0}" --argjson oy "${oy:-0}" \
          '(((.layout.tile_pos_in_workspace_view[0] + .layout.window_offset_in_tile[0] + $ox) | floor | tostring)
           + " " +
           ((.layout.tile_pos_in_workspace_view[1] + .layout.window_offset_in_tile[1] + $oy) | floor | tostring))' <<< "$w"
}

# Screen centre of the control that owns <key>. Prints it, or prints nothing and
# says on stderr WHICH half failed.
#
# ⚠️ THE TWO HALVES REPORT SEPARATELY, and the first draft did not. It answered
# "could not locate the dock.enabled row" when the truth was that `niri msg` had
# no socket — sending the reader to look at a page that was perfectly fine. Rule
# 4: a checker that reads the wrong place invents work, which is worse than one
# that misses something.
centre_of() {
    local key="$1" origin rect ox oy rx ry rw rh
    origin="$(win_origin)"
    if [[ -z "$origin" ]]; then
        echo "the compositor does not report a Settings window" >&2
        return 1
    fi
    # ⚠️ REVEAL, THEN WAIT, THEN PROBE — three steps, and the middle one is not
    # padding. A row further down the page has a position and no place on the
    # screen; `probe` refuses those on purpose and `reveal` scrolls it into view
    # first, through the window's OWN scrolling. But that scroll is ANIMATED, so
    # the answer reveal gives is where the row is GOING to be. Aiming at it
    # while the page is still moving puts the pointer on whatever happens to
    # slide past — measured, and it looks exactly like a dead control.
    ipc settings reveal "$key" >/dev/null
    sleep 0.8
    rect="$(ipc settings probe "$key")"
    if [[ -z "$rect" ]]; then
        echo "the window does not show a control for '$key' on this page" >&2
        return 1
    fi
    read -r ox oy <<< "$origin"
    read -r rx ry rw rh <<< "$rect"
    echo "$(( ox + rx + rw / 2 )) $(( oy + ry + rh / 2 ))"
}

# ⚠️ NO `--absolute`. The virtual device ydotoold creates reports EV=7 and has
# no ABS axes at all, so an absolute move is accepted and goes nowhere. The way
# that works is: slam into the top-left corner with one huge relative move, then
# move by exactly the wanted offset.
#
# ⚠️ AND THE BUTTON IS 0xC0. `ydotool click 0x00` is in every example on the
# internet and does nothing; its own --help says 0xC0 is the left button.
#
# ⚠️⚠️ AND `sudo` THROWS THE SOCKET AWAY. sudo resets the environment, so
# YDOTOOL_SOCKET does not survive it and the client falls back to
# /tmp/.ydotool_socket — the very path the note above is about. Exported into
# the command itself it works; exported into the shell it does not. Measured
# both ways, one minute apart:
#
#   sudo -n ydotool mousemove …                          exit 2, "is ydotoold running"
#   sudo -n YDOTOOL_SOCKET=/run/ydotool.sock ydotool …   exit 0
yd() { sudo -n "YDOTOOL_SOCKET=$YDOTOOL_SOCKET" ydotool "$@" >/dev/null 2>&1; }

#
# ⚠️⚠️ AND THE CORNER IT SLAMS INTO IS THE BOTTOM-RIGHT ONE, WHICH IS NOT A
# DETAIL. The obvious choice is the top-left — and niri has a HOT CORNER there
# that opens the overview. Measured with a control, `niri msg -j overview-state`
# before and after one move: `is_open` false -> true. The overview then eats the
# next click, so the pattern was "the first press works and every press after it
# does nothing" — which reads as a control that only responds once, and would
# have been reported as a bug in the shell.
#
# It is the third time this project has been caught by the overview standing
# open. Now the file both avoids opening it AND says so if it is.
# ⚠️⚠️ THE OUTPUT THE SETTINGS WINDOW IS ON, NOT "the first one in the map".
#
# This used to take `[.[]][0]` — fine on a machine with one screen, and wrong the
# moment the lab VM got a second head on 12.08.2026: jq handed back whichever
# output the map happened to list first, so the pointer was homed against a
# 5120x2160 screen while the window sat on a 1280x800 one, and every click landed
# somewhere else. The suite reported "still false after a real click", which is
# word for word the fault it exists to detect — a checker lying in the vocabulary
# of the thing it checks.
#
# Prints "x y width height" of that output in GLOBAL logical coordinates, which
# is what the pointer moves in.
win_output() {
    local w ws
    w="$(win_json)"; [[ -n "$w" ]] || return 1
    ws="$(jq -r '.workspace_id' <<< "$w")"
    local name
    name="$(niri msg -j workspaces 2>/dev/null \
            | jq -r --argjson ws "$ws" 'map(select(.id == $ws))[0].output // empty')"
    [[ -n "$name" ]] || return 1
    niri msg -j outputs 2>/dev/null \
        | jq -r --arg n "$name" '.[$n].logical
                 | ((.x | floor | tostring) + " " + (.y | floor | tostring) + " "
                    + (.width | floor | tostring) + " " + (.height | floor | tostring))'
}

screen_size() {
    local ox oy ow oh
    if read -r ox oy ow oh <<< "$(win_output)" && [[ "${ow:-0}" -gt 0 ]]; then
        printf '%s %s\n' "$ow" "$oh"
        return 0
    fi
    niri msg -j outputs 2>/dev/null \
        | jq -r '[.[] | select(.logical != null)][0].logical
                 | ((.width | floor | tostring) + " " + (.height | floor | tostring))'
}

#
# ⚠️⚠️ AND IT SLAMS INTO A CORNER EXACTLY ONCE, WHICH IS THE WHOLE TRICK. Every
# corner of this screen does something:
#
#   top-left      niri's own hot corner, opens the overview. Measured with a
#                 control: `overview-state.is_open` false -> true after ONE move.
#   right corners this desktop's own hot corner — the Bar & Island page shows it
#                 set to "Right", and its own hint says niri already owns the
#                 top-left one.
#
# Whatever opens then eats the NEXT press, so re-cornering before every click
# produced "the first press works and every one after it does nothing" — which
# looks precisely like a control that answers once. Both times the desktop was
# fine and the aiming was not.
#
# So: corner once into the bottom-left, close whatever that may have opened, and
# from there keep the position in a variable and move by the DIFFERENCE. The
# device has no absolute axes, so relative is all there is — but relative from a
# known point is exact.
POS_X=-1; POS_Y=-1

calibrate() {
    local sh_
    read -r _ sh_ <<< "$(screen_size)"
    [[ "${sh_:-0}" -gt 0 ]] || return 1
    yd mousemove -x -20000 -y 20000 || return 1
    POS_X=0; POS_Y=$(( sh_ - 1 ))
    sleep 0.4
    if [[ "$(niri msg -j overview-state 2>/dev/null | jq -r '.is_open')" == "true" ]]; then
        niri msg action close-overview >/dev/null 2>&1
        sleep 0.4
    fi
}

click_at() {
    local x="$1" y="$2"
    [[ "$POS_X" -ge 0 ]] || calibrate || return 1
    yd mousemove -x "$(( x - POS_X ))" -y "$(( y - POS_Y ))" || return 1
    POS_X="$x"; POS_Y="$y"
    # ⚠️ LONG ENOUGH FOR THE HOVER TO ARRIVE. A press 0.2 s after the move
    # landed before the row had been told the pointer was over it, and the
    # reading came back unchanged — which is the exact false negative this
    # file exists to avoid. Measured by hand at 0.4 s and working.
    sleep 0.6
    yd click 0xC0                    || return 1
    sleep 0.8
}

sudo -n true 2>/dev/null || skip "ydotool needs passwordless sudo here"

# The value of a dotted path as the FILE has it. Reading the file is half the
# measurement; the other half is the screen, and the screen is what `probe`
# answers for — a control that did not move has not been pressed.
val_of() { jq -r --arg p "$1" 'getpath($p | split("."))' "$CFG" 2>/dev/null; }

# ⚠️ WAIT FOR THE WRITE TO SETTLE rather than guessing a duration. Config.save()
# is debounced by 250 ms, so an immediate read is a race that passes on a fast
# machine and fails on a busy one.
#
# ⚠️ AND THE FIRST VERSION ONLY SAID SO. It was a fixed three-second sleep
# wearing a loop, which is the duration-guessing this comment forbids — and the
# unused loop variable is what shellcheck caught, so the wrong thing pointed at
# the right one. This watches until the file stops changing, which is what was
# claimed all along.
settle() {
    local last="" now tries=0
    while (( tries < 25 )); do
        now="$(stat -c '%Y %s' "$CFG" 2>/dev/null || true)"
        [[ -n "$now" && "$now" == "$last" ]] && return 0
        last="$now"; tries=$(( tries + 1 )); sleep 0.2
    done
}

# ------------------------------------------------------- 1 · a switch is a write
ipc settings dock >/dev/null; sleep 1.2
focus_settings
before="$(val_of dock.enabled)"
if xy="$(centre_of dock.enabled)"; then
    click_at $xy || bad "a press on a switch reaches the write" "ydotool refused"
    settle
    after="$(val_of dock.enabled)"
    if [[ "$before" != "$after" ]]; then
        ok "a press on a switch reaches the write" "$before -> $after"
        # ⚠️ AIM AGAIN RATHER THAN REUSING THE COORDINATE. Pressing a row can
        # move it: a status line appears, a group grows, the page scrolls. The
        # second press has to be aimed at where the row is NOW, or this reads as
        # "the press does nothing" for a reason that has nothing to do with the
        # press.
        if xy2="$(centre_of dock.enabled)"; then
            click_at $xy2; settle
            back="$(val_of dock.enabled)"
            [[ "$back" == "$before" ]] \
                && ok  "and the second press puts it back" "$before" \
                || bad "and the second press puts it back" "left at $back"
        else
            bad "and the second press puts it back" "lost sight of the row"
        fi
    else
        bad "a press on a switch reaches the write" "still $after after a real click"
    fi
else
    bad "a press on a switch reaches the write" "could not locate the dock.enabled row"
fi

# ------------------------------------------- 2 · the two-stage reset really resets
#
# His report: "hab die bar angemacht und wollte die seite resetten, es passiert  # english-ok: the report, quoted
# nix und es steht da nothing to change". This is that sequence, pressed        # english-ok: the report, quoted rather
# than called: change something on the page, then press Reset twice — because
# the first press only arms it.
ipc settings bar >/dev/null; sleep 1.2
focus_settings
# ⚠️ SET IT, DO NOT TOGGLE IT. A toggle depends on what the machine happened to
# be in, and this file has already produced one run where the bar was switched
# OFF here and the case then failed for the wrong reason.
[[ "$(ipc bar state)" == "on" ]] || { ipc bar toggle >/dev/null; settle; }
armed_from="$(val_of bar.enabled)"
if [[ "$armed_from" != "true" ]]; then
    bad "the page reset undoes a change" "could not switch the bar on to begin with"
else
    # ⚠️ SCROLL TO THE ROW, AIM AT THE BUTTON. Two names on purpose: the row is
    # what `reveal` can bring into view, and the button inside it is the only
    # part that answers a press — see the note in ui/settings/ActionRow.qml.
    ipc settings reveal reset-page >/dev/null; sleep 0.8
    if xy="$(centre_of reset-page-press)"; then
        click_at $xy; sleep 0.8      # press one: arms only
        mid="$(val_of bar.enabled)"
        # ⚠️ AIM AGAIN. Arming makes the row GROW — the caption becomes "Again to
        # confirm" and a status line appears under it — so the button is no
        # longer where it was. Measured: the second press landed on the row's
        # edge and did nothing, which reads as a confirm step that never fires.
        xy="$(centre_of reset-page-press)" || xy=""
        [[ -n "$xy" ]] || bad "the page reset undoes a change" "lost the button after arming"
        click_at $xy; settle         # press two: acts
        end="$(val_of bar.enabled)"
        if [[ "$mid" == "true" && "$end" == "false" ]]; then
            ok "the page reset undoes a change" "armed, then reset"
        elif [[ "$end" != "false" ]]; then
            bad "the page reset undoes a change" "bar.enabled is still $end after two presses"
        else
            bad "the page reset is two-stage" "one press already reset it — the confirm step is gone"
        fi
    else
        bad "the page reset undoes a change" "could not locate the reset button"
    fi
fi

# ⚠️ LEAVE THE MACHINE AS IT WAS FOUND. The bar is off by default and staying off
# is his decision; a checker that leaves it on has changed the desktop it was
# only supposed to measure.
[[ "$(ipc bar state)" == "on" ]] && { ipc bar toggle >/dev/null; settle; }
[[ "$(val_of bar.enabled)" == "false" ]] \
    || bad "and the bar is off again afterwards" "left at $(val_of bar.enabled)"

exit "$fail"
