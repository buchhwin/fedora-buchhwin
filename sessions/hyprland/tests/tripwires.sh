#!/usr/bin/env bash
#
# The check over the checks: can each tripwire go red at all?
#
# ⚠️⚠️ THIS IS THE SHARPEST FINDING THIS PROJECT HAS EVER HAD ABOUT ITSELF, and
# it sat in the handouts as a number for weeks: "fifteen of the checkers do not
# go red". A checker that cannot fail reports "ok" for ever, so every green tick
# beside it is worth nothing — and there is no way to tell those apart from the
# green ticks that mean something by reading either of them.
#
# Rule 4 says it plainly: "a checker that does not go red at the exact fault it
# was written for is worse than none — it reports ok for ever."
#
# ------------------------------------------------------------------ how it works
#
# For each entry: break the thing the suite is supposed to notice, run the suite,
# and require a non-zero exit. Then put the file back and READ BACK that it is
# back — this project has left a deliberately broken probe lying around once
# already, and reported a clean state over it.
#
# ⚠️ THE MUTATION HAS TO BE THE REAL FAULT, not a syntax error. Deleting a brace
# makes everything red and proves nothing; what has to be caught is the plausible
# mistake — a level mark that moves, a key nobody reads, a colour that vanishes.
#
# ⚠️ AND IT IS SLOW ON PURPOSE. Each entry starts a suite, and some of those
# start quickshell. It is not in the fast path and it is not meant to be: it is
# the thing you run before believing the other fifty-five.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
proved=0
skipped=0
total=0
red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; dim=$'\e[38;5;245m'; off=$'\e[0m'

# ⚠️⚠️ THE FILE IS BROKEN ON PURPOSE BETWEEN THESE TWO LINES, so an abort in
# between leaves it broken. That is not a theoretical risk: this run was killed
# by a dropped SSH connection after 21 of the cases, and the only reason the
# tree survived is that the signal happened to land between cases rather than
# inside one. A checker that can leave the working tree mutated is worse than
# the fault it looks for — the next person measures against a file nobody
# edited on purpose.
#
# So the mutation is registered BEFORE it is made, and the trap puts it back on
# any exit at all, including Ctrl-C, SIGTERM and a lost terminal.
MUT_FILE=""
MUT_BACKUP=""
restore_now() {
    [[ -n "$MUT_FILE" && -n "$MUT_BACKUP" && -f "$MUT_BACKUP" ]] || return 0
    cp "$MUT_BACKUP" "$MUT_FILE"
    rm -f "$MUT_BACKUP"
    printf '\n  %srestored%s %s after an interrupted run\n' "$dim" "$off" "$MUT_FILE" >&2
    MUT_FILE=""; MUT_BACKUP=""
}
trap restore_now EXIT
trap 'restore_now; exit 130' INT
trap 'restore_now; exit 143' TERM HUP

# suite | file | sed expression that introduces the real fault | what it is
#
# ⚠️ ONE FAULT PER LINE, AND IT NAMES ITSELF. A table of opaque sed expressions
# would be a checker nobody can audit — which is the same problem one level up.
#
# ⚠️⚠️ THE FAULT HAS TO BE THE SUITE'S OWN SUBJECT, and the first draft of this
# table got that wrong in a way worth keeping as a warning. `key-readers` was
# given "a generated key removed from the fingerprint" and duly stayed green —
# which this file reported as "this checker is blind". It is not: a key missing
# from the fingerprint is `fingerprint.sh`'s subject, and that one went red at
# the same mutation. The blind one was the CASE.
#
# A meta-check can only detect a mutation that changes nothing, not one aimed at
# the wrong checker. So every line here has to be read as "is this really what
# that suite promises?" before it is believed.
#
# ⚠️⚠️ AND A CASE GOES STALE SILENTLY — this table has already had one. The
# `english` line used to inject German by rewriting a specific sentence
# ("^// The gap between"). The sentence was later reworded, the sed matched
# nothing, and from that moment `english.sh` was UNVERIFIED while this file kept
# printing a line about it. Only the "changed nothing" guard below told the two
# apart; without it, it would have read as a blind checker.
#
# ⚠️ AND ONE CASE WRITES ITS PIPE AS `\x7c`, WHICH IS NOT A TYPO. The fault
# `pipefail-grep` guards IS a pipe, and `|` is this table's field separator — a
# literal one would split the row into the wrong columns and the case would
# quietly test something else. GNU sed expands `\x7c` in the `a` command's text,
# verified on both machines before it was written here.
#
# So: ANCHOR A MUTATION TO SOMETHING STRUCTURAL, never to prose. `pragma
# Singleton` and a property declaration survive an editing pass; a sentence in a
# comment is rewritten by the next person who improves it.
#
# ⚠️ FIVE CASES WENT STALE IN ONE MIGRATION, and the guard caught all five —
# which is the argument for the guard. The move from the previous compositor to
# Hyprland, and the cutting back of the profile that followed it, took the
# ground out from under them:
#
#   greeter        REMOVED. shell/ui/greeter/ and tests/greeter.sh are both
#                  gone; the login screen is SDDM's now. A row naming two files
#                  that do not exist is not a stale case, it is a case about
#                  nothing, and there is nothing to re-point it at.
#   no-secrets     docs/HYPRLAND.md has not been written yet — it is still on
#                  the to-do list. Re-pointed at docs/CONFIG.md, which exists
#                  and is published, so the check has a real file again.
#   fingerprint    `Config.windows.defaultWidth` was removed from the shell.
#                  Re-pointed at `Config.keys.mod`, which the config generator
#                  reads and which therefore has to be in the fingerprint.
#   bhctl-usage    the help text no longer reads `bhctl <cmd>` — the lines are
#                  indented two spaces now, so the old sed matched nothing.
#   workspaces     the centring step it deleted is gone: Hyprland reports where
#                  a window actually is, so there is no slack to share by hand.
#                  Re-pointed at the line that reads that position, which is
#                  where "packed against the left edge" now comes from.
#
# ⚠️ AND A SIXTH WAS RE-POINTED DELIBERATELY, which is a different thing from
# going stale. `setting-rows` mutated a row on the dock's settings page, and the
# dock was removed on 09.09.2026 — surface, page, ipc verb and Config block. The
# case now mutates `bar.enabled` on Bar & Island: the same shape of fault, on a
# page that is going to stay.
CASES=$(cat <<'TABLE'
no-python|lib/70-services.sh|$a python3 -c "print(1)"|python in an installer phase
no-fetch-animation|dotfiles/zsh/zshrc|s/^        fastfetch$/        buchhwin-fetch/|a call to the deleted player
setting-rows|shell/ui/settings/pages/BarIslandPage.qml|s/key: "bar.enabled"/key: "bar.enabledX"/|a row over a key that does not exist
key-readers|shell/config/Config.qml|s/^                property bool noCsd: true$/                property bool noCsd: true\n                property bool nobodyReadsThis: true/|a key nothing reads
fingerprint|shell/services/Theming.qml|s/Config.keys.mod,//|a generated key outside the fingerprint
reset-page|shell/ui/settings/pages/DisplaysPage.qml|s/resetKeys: \["outputs"\]/resetKeys: []/|a page that writes settings its reset forgets
displays|shell/services/Compositor.qml|s/toFixed(3)/toFixed(1)/|a refresh rate the compositor will not accept
english|shell/services/Connectors.qml|s/^pragma Singleton$/pragma Singleton\n\/\/ Das ist der Fehler und wird nicht uebersetzt/|German in the source  # english-ok: the fixture IS German, that is the fault being injected
no-literals|shell/ui/common/WiredIcon.qml|s/color: root.colour/color: "#ff0000"/|a hard-coded colour outside theme\/
theme-tokens|shell/ui/common/Pill.qml|s/Theme.radiusPill/Theme.radiusPillX/|a Theme token that does not exist
flickable-children|shell/ui/settings/SettingsContent.qml|s/^                    id: railScroll$/&\n                    ScrollIndicator { flickable: railScroll }/|a scroll bar back inside its Flickable
surface-build|shell/ui/quick/QuickSettings.qml|s/^            visible: root.showMore && Services.Drive.installed$/            visible: root.showMore\n            visible: Services.Drive.installed/|a surface type that will not build
duplicate-props|shell/ui/quick/QuickSettings.qml|s/^            visible: root.showMore && Services.Drive.installed$/            visible: root.showMore\n            visible: Services.Drive.installed/|the same property declared twice
contrast|shell/theme/Theme.qml|s/alpha(surfaceHigh, panelOpacity)/alpha(surface, panelOpacity)/|a pill in its card's own colour
quick-drawers|shell/ui/quick/QuickSettings.qml|s/if (which.length > 0 && root.drawers.indexOf(which) < 0)/if (false)/|a drawer name nothing validates
displays|shell/ui/settings/OutputArrangement.qml|s/return ySpan >= Math.min(root._minTouch, Math.min(a.h, b.h))/return ySpan >= 0/|two screens that meet only at a corner
settings-nulls|bin/bhctl|s/if \[\[ -n "\$nulls" \]\]/if [[ -z "$nulls" ]]/|doctor blind to a null config section
update-diverged|bin/bhctl|s#if ! git merge-base HEAD#if git merge-base HEAD#|update saying only "pull failed" to a rewritten clone
popup-close|shell/ui/settings/SettingsWindow.qml|s#enabled: OpenMenu.current !== null#enabled: true#|a click catcher that is always on
pipefail-grep|tests/no-python.sh|$a printf x \x7c grep -q x \x7c\x7c true|a checker piping into grep -q
motion|shell/ui/common/StagedFace.qml|s/^        Behavior on scale {$/        Behavior on implicitHeight {/|an animation driving a layout size
ui-imports|shell/ui/common/Toggle.qml|s/^import QtQuick$/import QtQuick\nimport Quickshell.Services.Pam/|a surface importing Quickshell.Services directly
tap-targets|shell/ui/common/IconRail.qml|s/^                onClicked: root.activated(railPill.index)$/                TapHandler { onTapped: root.activated(railPill.index) }/|a TapHandler hidden inside a Pill
no-secrets|docs/CONFIG.md|$a A machine at 192.168.178.42 answers on port 8080.|an address in a published file  # secrets-ok: the fixture IS an address, that is the fault being injected
workspace-labels|shell/ui/notch/pages/WorkspacesPage.qml|s/box.modelData.ws.idx/box.modelData.ws.name/|a workspace label reading the name instead of the index
config-shape|shell/config/Config.qml|s/^                property bool noCsd: true$/                property bool noCsd: true\n                property var crashesQuickshell: []/|a nested property var, which segfaults quickshell
bhctl-usage|bin/bhctl|s/^  prune .*$//|a subcommand that usage() no longer mentions
switch-one-writer|shell/ui/common/Toggle.qml|s#^    HoverHandler {#    TapHandler { onTapped: root.toggled(!root.checked) }\n    HoverHandler {#|a switch that answers the press its row already answers
no-secrets|docs/CONFIG.md|$a Measured on a Ryzen 7 7840HS with an RTX 4060.|an exact device model in a published file  # secrets-ok: the fixture IS a model, that is the fault being injected
no-foreign-bar|lib/80-shellenv.sh|s/^    remove_unwanted$/    true/|nothing removes the bar this desktop replaces
notch-keys|shell/ui/surface/OverlaySurface.qml|s@^        Keys.onEscapePressed:@        // Keys.onEscapePressed:@|Escape answered by nothing at all
reset-page|shell/config/Config.qml|s/typeof v.length === "number"/false/|a QML list<string> that never reaches the schema
nested-taps|shell/ui/quick/Tile.qml|s/^                gesturePolicy: TapHandler.WithinBounds$//|a nested press that also reaches the surface under it
lock-survives|shell/services/Idle.qml|s/--quiet --collect --unit=buchhwin-lock/--quiet --unit=buchhwin-lock/|a lock screen that keeps its name after a crash, with the comment still explaining --collect
xwayland|shell/tools/render.qml|/"gtk-decoration-layout=:/d|the one line that removes the window buttons, with its own documentation left in place
notch-frame|shell/ui/surface/OverlaySurface.qml|s/^        anchors.fill: parent$/        anchors.centerIn: parent/|the card sized from its own request again, painted before the surface has it
motion|shell/ui/surface/ShellSurface.qml|s/^    implicitHeight: Math.max(1, root.maxIslandHeight)$/    implicitHeight: Math.max(1,\n                            root.islandH)/|a surface following an animated size across TWO lines, which a line-by-line read cannot see
no-fetch-animation|shell/tools/render.qml|s/+ Math.max(0, root.fetchTextLines - root.fetchLogoLines) + ", "/+ 6 + ", "/|the fastfetch logo padding typed as a number again, right on one machine at most
notch-frame|shell/ui/surface/OverlaySurface.qml|s/^            anchors.top: parent.top$/            anchors.verticalCenter: parent.verticalCenter/|the page centred in the card again, so every height change slides it by half
monitors|shell/common/WorkspaceGeometry.qml|s/^            var want = wanted$/            var want = 1/|every monitor column pinned to the first workspace, so paging one column does nothing
workspaces|shell/common/WorkspaceGeometry.qml|s/^                x: Number.*$/                x: 0,/|the window row packed against the left edge again, with all the slack on the right
TABLE
)

while IFS='|' read -r suite file expr what; do
    [[ -n "${suite:-}" ]] || continue
    total=$((total + 1))
    printf '  %-22s %s%s%s\n' "$suite" "$dim" "$what" "$off"

    if [[ ! -f "tests/$suite.sh" ]]; then
        printf '    %sFAIL%s  tests/%s.sh does not exist\n' "$red" "$off" "$suite"
        fail=1; continue
    fi
    if [[ ! -f "$file" ]]; then
        printf '    %sFAIL%s  %s does not exist — this case is watching nothing\n' \
               "$red" "$off" "$file"
        fail=1; continue
    fi

    # ⚠️ GREEN FIRST. A suite that is already red proves nothing about the
    # mutation, and would report a false pass here.
    #
    # ⚠️⚠️ AND EXIT 2 IS NOT RED. Every suite in this repo uses 2 for "I cannot
    # run here" — no quickshell, no jq, no session — and 1 for "I found a fault".
    # Reading both as failure is how this file reported `reset-page` and
    # `displays` as broken on a machine that simply has no `qs` installed. That
    # is a checker misreporting the environment as a regression, which is the
    # exact fault one level down that this whole file exists to catch.
    bash "tests/$suite.sh" >/dev/null 2>&1
    case $? in
        0) ;;
        2) printf '    %sskip%s  the suite cannot run here (exit 2) — nothing was proved\n' \
                  "$dim" "$off"
           skipped=$((skipped + 1)); continue ;;
        *) printf '    %sFAIL%s  already red before the mutation — cannot tell what caught what\n' \
                  "$red" "$off"
           fail=1; continue ;;
    esac

    backup="$(mktemp)"
    cp "$file" "$backup"
    # Registered before the file is touched, so the trap above can always find
    # it — registering afterwards would leave a window with no way back.
    MUT_FILE="$file"; MUT_BACKUP="$backup"
    sed -i "$expr" "$file"

    # ⚠️ DID THE MUTATION CHANGE ANYTHING? A sed expression that matches nothing
    # leaves the file alone, the suite stays green, and this reports the checker
    # as blind when in fact the CASE is stale. That is the same class of fault
    # one level down, and it has to be told apart.
    if cmp -s "$backup" "$file"; then
        printf '    %sFAIL%s  the mutation changed nothing — this case is stale, not the checker\n' \
               "$red" "$off"
        fail=1
    else
        if bash "tests/$suite.sh" >/dev/null 2>&1; then
            printf '    %sFAIL%s  stayed GREEN with the fault in place — this checker is blind\n' \
                   "$red" "$off"
            fail=1
        else
            printf '    %sok%s    went red\n' "$green" "$off"
            proved=$((proved + 1))
        fi
    fi

    cp "$backup" "$file"
    # ⚠️⚠️ READ THE RESTORE BACK — AND READ THE FILE, NOT THE SUITE. This line
    # used to run the suite again and call a green exit "restored". Those are
    # two different statements: a suite can go green over a file that is still
    # subtly different from the one it started with, and the header three
    # screens up promises "it is the same file". `cmp` is that promise; a
    # passing suite is a weaker claim wearing its clothes.
    #
    # It is also 34 fewer suite runs, which is most of what made this slow.
    if ! cmp -s "$backup" "$file"; then
        printf '    %sFAIL%s  the file did not come back — the tree has been left dirty\n' \
               "$red" "$off"
        fail=1
    fi
    rm -f "$backup"
    MUT_FILE=""; MUT_BACKUP=""
done <<< "$CASES"

# ⚠️⚠️ A RUN THAT PROVED NOTHING IS NOT A GREEN RUN. `exit $fail` knew only 0
# and 1, so a machine where every suite says "I cannot run here" printed a wall
# of skips and exited 0 — which reads as "all the checkers can go red" and is
# the same lie one level up that this whole file exists to catch.
#
# 2 is this repo's word for "cannot run here", the same one every suite uses.
printf '\n  %d proved, %d skipped, %d cases in the table\n' \
       "$proved" "$skipped" "$total"
if (( fail )); then
    exit 1
fi
if (( proved == 0 )); then
    printf '  %snothing was proved here — no suite in the table could run%s\n' "$dim" "$off"
    exit 2
fi
exit 0
