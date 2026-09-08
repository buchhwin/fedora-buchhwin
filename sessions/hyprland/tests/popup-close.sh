#!/usr/bin/env bash
#
# A popup list closes when you click beside it — and it does not do that by
# watching itself.
#
# ⚠️⚠️ THE FAULT THIS EXISTS FOR HAS BEEN "FIXED" THREE TIMES AND REPORTED BROKEN
# THREE TIMES. His words: "wenn ich z.b was mit dropdown auswähle in den settings   # english-ok: the report, quoted
# kann ich erst irgendwo hinclicken wenn ich wirklich was ausgewählt habe … wenn    # english-ok: the report, quoted
# man irgendwo anders hinklickt dann schließt sich das dropdown menü einfach ohne   # english-ok: the report, quoted
# was zu tun so solls sein".
#
#   1  a child of the row                cut off by the group card's `clip`
#   2  reparented to Window.contentItem  a construct used nowhere else here
#   3  onActiveFocusChanged + a latch    measured dead: over a full
#                                        open-click-away cycle the sheet's
#                                        activeFocus never changed once
#
# Attempt 3 is the one this file is really about, because it LOOKED right. It
# read like a considered fix, it carried a careful comment about arming late,
# and it could never run. Nothing static could have told those three apart —
# what told them apart was tools/popup-close-check.qml on a real session.
#
# So what is checked here is the SHAPE of the answer that survived measurement:
# a popup cannot see the click beside it, therefore it must announce itself to
# common/OpenMenu.qml and the WINDOW must catch the press.
#
# ⚠️ AND THE DEAD SHAPE IS BANNED BY NAME, not just the fix required. Requiring
# the new thing without forbidding the old one leaves both in the file, and the
# next person reads the dead one as the mechanism — which is exactly how this
# got three rounds deep.
#
# Static. No quickshell, no session, runs in CI.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
ok()   { printf '  %-52s \033[38;5;114mok\033[0m  %s\n' "$1" "${2:-}"; }
bad()  { printf '  %-52s \033[38;5;203mFAIL\033[0m %s\n' "$1" "${2:-}"; fail=1; }

# ── which files open a popup list ───────────────────────────────────────────
#
# ⚠️ THE GREETER IS OUT, AND FOR A STATED REASON RATHER THAN BECAUSE IT WAS
# INCONVENIENT. ui/greeter/GreeterFace.qml also uses a PopupWindow, but it runs
# in its own process as the greetd user, over a session-lock surface, with no
# settings window anywhere near it — there is no containing window to catch a
# press. If a list there ever needs dismissing it needs its own answer.
#
# ⚠️ SELECTED BY CODE, NOT BY THE WORD. The first version matched any file
# CONTAINING "PopupWindow" and immediately reported common/OpenMenu.qml as a
# broken popup component — the singleton names the type in its header, at
# length, because that is what it is for. A checker whose extractor is wrong
# invents faults, which is worse than one that misses them: this one demanded
# that the fix register itself with itself. So the match is on a file that
# actually DECLARES one, with comments stripped first.
#
# ⚠️⚠️ AND NOT THROUGH A PIPE INTO `grep -q`. Under `set -o pipefail` that is a
# silent skip: `grep -q` exits at the first match, `sed` upstream takes SIGPIPE,
# and the pipeline reports failure — exactly when the match is found early in a
# long file. tests/switch-one-writer.sh lost its most important file that way
# and read as clean. The text goes into a variable first.
files=()
while IFS= read -r f; do
    stripped="$(sed 's://.*::' "$f")"
    grep -qE '^[[:space:]]*PopupWindow[[:space:]]*\{' <<< "$stripped" && files+=("$f")
done < <(find shell/ui/common -name '*.qml' | sort)

if (( ${#files[@]} == 0 )); then
    echo "  found no popup components — did they move out of shell/ui/common?"
    exit 2
fi

for f in "${files[@]}"; do
    name="$(basename "$f")"

    # ⚠️ COMMENTS STRIPPED FIRST. Every one of these files describes the dead
    # attempts in its header — in detail, on purpose — and a check that reads
    # prose would fail on the very documentation that keeps the fault from
    # coming back. The same reason tests/theme-tokens.sh strips them.
    code="$(sed 's://.*::' "$f")"

    if grep -q "OpenMenu.claim" <<< "$code" && grep -q "OpenMenu.release" <<< "$code"; then
        ok "$name announces itself while its list is up"
    else
        bad "$name" "no OpenMenu.claim/release — nothing can close it"
    fi

    # `close()` is the handle OpenMenu.closeCurrent() calls. Without it the
    # singleton clears its slot and the list stays on screen — the catcher would
    # then be disabled with a menu still up, which is worse than before.
    if grep -qE "function close\(\)" <<< "$code"; then
        ok "$name has the close() the singleton calls"
    else
        bad "$name" "no close() — OpenMenu.closeCurrent() has nothing to call"
    fi

    # The dead shape, by name.
    if grep -q "everFocused" <<< "$code"; then
        bad "$name" "carries the everFocused latch — measured dead, remove it"
    else
        ok "$name is free of the dead focus latch"
    fi

    # ⚠️⚠️ THE ONE THAT ACTUALLY BROKE IT, AND IT TOOK A RUNNING SESSION TO SEE.
    # Every one of these carried `property bool menuOpen` with `visible:
    # root.menuOpen` on the popup, and that pair comes apart the first time the
    # compositor dismisses the surface: quickshell WRITES `visible = false`, and
    # a written value DESTROYS the binding rather than being stopped by it.
    # After one dismissal the flag says open, the surface is gone, and the list
    # can never be shown again — which is exactly the report.
    #
    # An alias has no binding to destroy: the popup's own visibility is the
    # state, so it does not matter who writes it.
    #
    # ⚠️ SCOPED TO THE PopupWindow BLOCK. The first version matched the whole
    # file and reported two of three as broken over `visible: root.multi` on an
    # inner row — a perfectly good binding on an item that is not a surface.
    # A checker that reads the wrong region invents faults, and this one would
    # have demanded the removal of working code.
    #
    # ⚠️ AND ONLY ITS OWN PROPERTIES, NOT ITS CHILDREN. The second version read
    # the whole nested block and reported the same two files, this time over a
    # `visible:` on a row INSIDE the menu — which is exactly what a row that
    # appears conditionally should have. Only lines at depth one, and only lines
    # that do not open a block of their own, are the popup's own.
    popupblock="$(awk '
        /^[[:space:]]*PopupWindow[[:space:]]*\{/ { inblock = 1; depth = 1; next }
        inblock {
            before = depth
            n = gsub(/\{/, "{"); m = gsub(/\}/, "}")
            depth += n - m
            if (depth <= 0) { inblock = 0; next }
            if (before == 1 && n == 0) print
        }' <<< "$code")"

    if grep -qE '^[[:space:]]*visible:' <<< "$popupblock"; then
        bad "$name" "binds visible to a flag — one dismissal and the list is dead"
    elif grep -qE 'property alias [A-Za-z]+: *popup\.visible' <<< "$code"; then
        ok "$name keeps its open state in the popup itself"
    else
        bad "$name" "no alias onto popup.visible — where does its open state live?"
    fi
done

# ── the window end of it ────────────────────────────────────────────────────
W=shell/ui/settings/SettingsWindow.qml
wcode="$(sed 's://.*::' "$W")"

if grep -q "OpenMenu.closeCurrent()" <<< "$wcode"; then
    ok "the settings window closes the open list"
else
    bad "the settings window" "nothing calls OpenMenu.closeCurrent()"
fi

# ⚠️⚠️ THE GATE IS THE WHOLE SAFETY OF THIS. An always-on invisible MouseArea
# over the settings window is the bug nobody suspects — this project deleted one
# for eating clicks meant for the tabs behind it. `enabled` tied to
# `OpenMenu.current` is what makes it exist only while a list is open.
if grep -qE "enabled:\s*OpenMenu\.current" <<< "$wcode"; then
    ok "the catcher exists only while a list is open"
else
    bad "the settings window" "the catcher is not gated on OpenMenu.current"
fi

# Escape belongs to the innermost thing on screen. Without this, Escape with a
# list up shuts the whole window.
C=shell/ui/settings/SettingsContent.qml
escape_block="$(grep -A4 "Keys.onEscapePressed" <<< "$(sed 's://.*::' "$C")")"
if grep -q "OpenMenu" <<< "$escape_block"; then
    ok "escape closes the list before the window"
else
    bad "the settings content" "escape does not consider an open list"
fi

# ── the singleton is registered, or none of the above is reachable ──────────
#
# ⚠️ Quickshell loads through a virtual filesystem, where QML's implicit
# same-folder rule does not apply. A singleton that is not in qmldir is not a
# type, and every reference above would be an undefined name — which QML reports
# at USE time, in a file nobody was editing.
if grep -qE "^singleton OpenMenu " shell/ui/common/qmldir; then
    ok "OpenMenu is registered in qmldir"
else
    bad "shell/ui/common/qmldir" "OpenMenu is not registered — the type does not exist"
fi

exit $fail
