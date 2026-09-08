#!/usr/bin/env bash
#
# M11's other half: "XWayland-Ausrottung, messbar". Randlos was built long ago
# and never measured — there was no suite for it at all, which is how a
# milestone stays half done without anybody noticing.
#
# ⚠️ THE OBVIOUS TEST DOES NOT EXIST, AND THAT IS THE FIRST FINDING. niri 26.04
# does not say whether a window is X11: `niri msg -j windows` gives id, title,
# app_id, pid, workspace_id, is_focused, is_floating, is_urgent, layout and
# focus_timestamp — measured against a real window rather than hoped for. An
# XWayland window arrives with WM_CLASS in `app_id` and is indistinguishable
# from a native one there.
#
# So the check is made one level down, where the answer is complete rather than
# sampled: XWayland on niri is a SEPARATE PROCESS (xwayland-satellite). If it is
# not installed and not running, there is no X server, and no window can be an
# X11 window. That is a proof about every window at once, including the ones
# that are not open yet — which is stronger than walking the window list, not
# weaker.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0

# ⚠️ THE ALLOWLIST IS ONE ENTRY AND IT IS NOT INSTALLED EITHER. docs/CITRIX.md
# is the standing exception: Citrix Workspace has no Wayland client, and if it
# is ever needed it needs XWayland with it. Nothing here ships it — the point of
# naming it is that a future "just add xwayland-satellite" has to come past this
# line and say which program needed it.
allow="citrix"

# ---------------------------------------------------------------- static half
printf '  %-38s ' "no package list installs XWayland"
hits="$(grep -ln 'xwayland' packages/*.txt 2>/dev/null || true)"
if [[ -z "$hits" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203m%s\033[0m\n' "$hits"
    grep -n 'xwayland' packages/*.txt | sed 's/^/      /'
    fail=1
fi

printf '  %-38s ' "nothing spawns xwayland-satellite"
# The generator is the only thing that writes spawn-at-startup lines.
if grep -qi 'xwayland' shell/tools/niri.qml shell/config/Config.qml 2>/dev/null; then
    printf '\033[38;5;203mfound\033[0m\n'
    grep -in 'xwayland' shell/tools/niri.qml shell/config/Config.qml | sed 's/^/      /'
    fail=1
else
    printf '\033[38;5;114mok\033[0m\n'
fi

# ⚠️ AND THE FOUR MECHANISMS THAT MAKE A WINDOW BORDERLESS, checked as text
# because three of them are in generated files and one is in a foreign app's
# settings. They were all built on 06.08.2026 and never had a wire.
#
# ⚠️⚠️ AND ONE OF THE FOUR WAS BLIND UNTIL TODAY — measured, with the control
# that decides it: delete the only line that does the work
# (render.qml's `"gtk-decoration-layout=:\n"`) and leave the prose alone, and
# this check stayed GREEN. `gtk-decoration-layout` appears three times in that
# file and only one of them is the mechanism:
#
#   :29   // gtk-decoration-layout to ":" removes …   ← a QML comment
#   :401  "# gtk-decoration-layout=\":\" removes …    ← a comment IN THE FILE WE WRITE
#   :409  "gtk-decoration-layout=:\n"                 ← the only line with an effect
#
# The second one is the nastier of the two, because stripping QML comments does
# not touch it: it is a string, and the `#` makes it a comment only once the
# generated file exists. A checker hanging on its own documentation is the exact
# fault this project has now found in eighteen suites.
#
# So both are cut before the search: a line whose first non-space character
# opens a comment, and a string that begins `"# ` — hash and a SPACE, which a
# colour literal like "#1e1e2e" never has.
effective() {
    grep -vE '^[[:space:]]*(//|#)' "$1" | grep -v '"#[[:space:]]'
}
printf '  %-38s ' "the four borderless mechanisms exist"
missing=""
niri_eff="$(effective shell/tools/niri.qml)"
render_eff="$(effective shell/tools/render.qml)"
grep -q 'prefer-no-csd'   <<< "$niri_eff"   || missing+=" prefer-no-csd"
grep -q 'gtk-decoration-layout' <<< "$render_eff" || missing+=" gtk-decoration-layout"
grep -q 'QT_WAYLAND_DISABLE_WINDOWDECORATION' <<< "$niri_eff" \
    || missing+=" QT_WAYLAND_DISABLE_WINDOWDECORATION"
grep -q 'titleBarStyle'   <<< "$render_eff" || missing+=" vscode-titleBarStyle"
if [[ -z "$missing" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mmissing:%s\033[0m\n' "$missing"
    fail=1
fi

# ------------------------------------------------------------------ live half
#
# ⚠️ IT SKIPS RATHER THAN PASSES WITHOUT A SESSION. A check that reports "ok"
# because it could not look is the exact shape this project has been burned by
# four times — a green from a mute instrument.
if ! command -v niri >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf '  %-38s \033[38;5;179mskipped\033[0m (no session)\n' "no X server on this machine"
    exit $fail
fi

printf '  %-38s ' "no X server on this machine"
# ⚠️ THE PATTERN IS ANCHORED, AND THE FIRST VERSION WAS NOT — it matched THIS
# SCRIPT. `pgrep -f xwayland` finds `bash tests/xwayland.sh`, so the check
# reported an X server on a machine that had none, and it reported it in the
# green run as well as the red one. A test that cannot tell its subject from
# itself is worse than no test: it is red for a reason that will never go away,
# and the next person turns it off. Requiring the name to end at a space or at
# the end of the line means `xwayland.sh` no longer counts.
running="$(pgrep -a -f '(^|/)(Xwayland|xwayland-satellite)([[:space:]]|$)' 2>/dev/null || true)"
if [[ -z "$running" ]]; then
    printf '\033[38;5;114mok\033[0m  no XWayland process, so no X11 window can exist\n'
else
    # An X server IS up. That is not automatically wrong — Citrix is allowed —
    # but every client on it has to be named.
    printf '\033[38;5;179mXWayland is running\033[0m\n'
    sed 's/^/      /' <<< "$running"
    if grep -qi "$allow" <<< "$running"; then
        printf '      \033[38;5;114mallowed\033[0m — matches the documented exception (%s)\n' "$allow"
    else
        printf '      \033[38;5;203mnot in the allowlist\033[0m — see docs/CITRIX.md\n'
        fail=1
    fi
fi

exit $fail
