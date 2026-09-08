#!/usr/bin/env bash
# B69 · the card is never drawn at a size the surface does not have.
#
# His report: "das fenster wird so ne 1ms groß und dann sofort wieder klein",   # english-ok: the report, quoted
# on every button — Show more, wifi, bluetooth, the microphone arrow.
#
# ⚠️⚠️ WHY THIS SUITE EXISTS RATHER THAN A LINE IN quick-drawer-height.sh: that
# one asks whether the height comes BACK, which is B68 and is about a settled
# number. This one asks whether the frames in between were right, which is a
# different question and was answered "yes" for a whole round by a counter that
# could not see them. `resizes` in OverlaySurface counts on the far side of the
# settle wait; fifty-five painted frames at the wrong size fit between two of
# its ticks.
#
# The fault: the card sized itself from its own request (`implicitWidth` via no
# explicit width) while the window followed two event-loop turns plus a Wayland
# round trip later, and `GlassPane` fills the card. So the pane changed size
# underneath the content, shifted by half the difference because the card was
# centred rather than filled.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; yellow=$'\e[38;5;179m'; off=$'\e[0m'
ok()   { printf '  %sok%s   %s\n'   "$green"  "$off" "$1"; }
bad()  { printf '  %sFAIL%s %s\n'   "$red"    "$off" "$1"; fail=1; }
skip() { printf '  %s--%s   %s\n'   "$yellow" "$off" "$1"; }

# ------------------------------------------------------------ 1 · static half
#
# Runs anywhere, including CI. Comments are cut first: this file explains the
# fault at length directly above the line that fixes it, and a checker that
# reads its own documentation as evidence is the fault one level up.
F=shell/ui/surface/OverlaySurface.qml
src="$(grep -vE '^[[:space:]]*//' "$F")"

# ⚠️⚠️ EIGHT SPACES, NOT `[[:space:]]*`, AND THE FIRST DRAFT OF THIS SUITE GOT
# IT WRONG. `anchors.fill: parent` appears twice in that file — once on the card
# and once on the `GlassPane` inside it. A loose expression matches the pane, so
# deleting the card's line would have left this check green: a checker blind to
# the exact fault it was written for, which is the thing rule 4 calls worse than
# no checker at all. The card is a direct child of the window, so its properties
# sit at one level of indentation; that is what pins this to the right one.
if grep -qE '^        anchors\.fill: parent$' <<< "$src"; then
    ok "the card is drawn at the surface's size"
else
    bad "the card no longer fills the surface — it can be painted at its own request again"
fi

# The exact shape that was there before, named so it cannot return by accident.
if grep -qE '^        anchors\.centerIn: parent$' <<< "$src"; then
    bad "the card is centred again — half the size difference becomes a shift"
else
    ok "…and not centred inside it, which used to add a jump to the resize"
fi

# ⚠️⚠️ B81 · AND THE PAGE INSIDE THE CARD IS TOP-ANCHORED, NOT CENTRED. This is
# the same fault one level in, and it survived the B69 fix untouched: the card
# was the right size in every frame — `off` stayed 0 — while the whole page,
# icon rail included, slid by half of every height change.
#
# His report names both the symptom and the family: "wenn ich auf show more oder  # english-ok: the report, quoted
# show less clicke buggen alle icons aus dem quickpanel nach unten und dann ganz  # english-ok: the report, quoted
# schnell wieder nach oben" · "das ist ein bug der davor auch schon links bei     # english-ok: the report, quoted
# der leiste war im quick panel".                                                 # english-ok: the report, quoted
#
# Fourth appearance of one shape: B18 (icon rail centred in a per-tab height),
# B38 (the header, one level up), B45 (the panel floor), B81 (the page in the
# card). His reason from the first still decides it: "damit die einzelnen punkte  # english-ok: the request, quoted
# immer an der gleichen stelle sind".                                             # english-ok: the request, quoted
if grep -qE '^            anchors\.top: parent\.top$' <<< "$src"; then
    ok "the page is anchored to the top of the card"
else
    bad "the page is not top-anchored — a height change moves it by half the difference"
fi

# The sampler itself. Without it the functional half below measures nothing,
# and the fault it was built for is invisible to every other check in the repo.
if grep -q 'FrameAnimation' <<< "$src" && grep -q 'offFrames' <<< "$src"; then
    ok "the per-frame sampler is still in place"
else
    bad "the per-frame sampler is gone — nothing here can see a one-frame fault again"
fi

# --------------------------------------------------------- 2 · functional half
command -v qs >/dev/null 2>&1 || { skip "quickshell is not installed"; exit "${fail:-0}"; }

# ⚠️ --pid, never -c buchhwin: a locked session is a second instance under the
# same config name and every call answers "Target not found".
. "$(dirname "$0")/shell-ipc.sh"
bh_shell_answers || { skip "no shell answering on IPC — static half only"; exit "$fail"; }

probe="$(bh_ipc call notch chain 2>&1)"
case "$probe" in
    *"not found"*|*"Function"*) skip "this shell has no notch chain verb"; exit "$fail" ;;
esac

# ⚠️⚠️ THE FIXTURE IS THE WHOLE REASON THIS CAN BE MEASURED HERE. The lab VM has
# no sound card, no wifi and no bluetooth, so every drawer opens empty — and an
# empty drawer does not grow, so it cannot be drawn at the wrong size either.
# `BUCHHWIN_SHELL_FAKE=1` gives the sound drawer real entries.
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/buchhwin-shell.service.d"
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
sleep 5

bh_ipc call notch collapse >/dev/null 2>&1
sleep 0.5
bh_ipc call notch tab 0 >/dev/null 2>&1
sleep 2

# Reads `off=N` and `shift=N` out of the chain line.
offcount()   { sed -n 's/.*[[:space:]]off=\([0-9]*\).*/\1/p' <<< "$1"; }
shiftcount() { sed -n 's/.*[[:space:]]shift=\([0-9]*\).*/\1/p' <<< "$1"; }

# ⚠️ THE CONTROL COMES FIRST, and it is the reason any number below means
# anything: a resting panel must report ZERO frames off. A sampler that can only
# ever say zero would pass this suite while seeing nothing at all.
bh_ipc call notch probe >/dev/null 2>&1
sleep 1.5
rest="$(bh_ipc call notch chain 2>&1)"
rest_off="$(offcount "$rest")"
rest_shift="$(shiftcount "$rest")"
if [[ "$rest_off" == "0" && "$rest_shift" == "0" ]]; then
    ok "at rest: nothing is drawn wrong and nothing moves  [$rest]"
else
    bad "at rest the panel already reports off=$rest_off shift=$rest_shift — nothing below can be trusted"
fi

for verb in "drawer sound" "drawer sound" "fold" "fold"; do
    bh_ipc call notch probe >/dev/null 2>&1
    # shellcheck disable=SC2086
    bh_ipc call notch $verb >/dev/null 2>&1
    sleep 1.2
    line="$(bh_ipc call notch chain 2>&1)"
    n="$(offcount "$line")"
    s="$(shiftcount "$line")"
    if [[ -z "$n" || -z "$s" ]]; then
        bad "no off=/shift= in the reading after '$verb' — the verb or the sampler is gone"
        continue
    fi
    if [[ "$n" == "0" ]]; then
        ok "'$verb': every frame matched the surface"
    else
        bad "'$verb': $n frames drawn at a size the surface did not have  [$line]"
    fi
    # ⚠️⚠️ B81 · AND THE PAGE MAY NOT MOVE INSIDE IT. This is a separate reading
    # on purpose: the two faults are independent, and the first one was fixed
    # while this one was still there — `off` was 0 on every press while the whole
    # page slid by half of every height change. One number cannot report both.
    #
    # This is also the guard he asked for by name: "schau das das in zukunft gar  # english-ok: the request, quoted
    # nicht mehr passieren kann". It measures the SYMPTOM per drawn frame, so a  # english-ok: the request, quoted
    # new spelling of "centred" — an anchor, an alignment, a Behavior — is caught
    # by what it does rather than by how it is written.
    if [[ "$s" == "0" ]]; then
        ok "…and the page did not move inside the card"
    else
        bad "'$verb': the page slid $s px inside the card — the icons visibly jump  [$line]"
    fi
done

exit "$fail"
