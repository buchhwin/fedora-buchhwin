#!/usr/bin/env bash
#
# A row may only be an empty text box if there is a reason written down.
#
# ⚠️ THIS IS THE PERMANENT ANSWER TO A COMPLAINT, not a style rule. Thirty of
# the hundred and sixty-five rows asked you to TYPE something the machine
# already knew: which screens exist, which app-ids are running, which programs
# are installed, which xkb options xkb has. His words were "überall wo es          # english-ok: the brief, quoted
# Vorschläge geben muss" — and the reason it matters is not convenience. A         # english-ok: the brief, quoted
# mistyped app-id is not an error anywhere: the compositor takes the string, never matches
# a window with it, and the window you wanted blurred is simply not blurred. No
# log line, no red check, nothing to notice.
#
# ⚠️ IT IS CHECKED IN BOTH DIRECTIONS, like the PENDING list in
# tests/setting-rows.sh and for the same reason. A row left as free text must be
# named below with a reason; a row named below that has since GAINED
# suggestions fails just as loudly. That is what stops a list like this rotting
# into a set of excuses — the only way to keep it green is to keep it true.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# ─────────────────────────────────────────────────────────────────────────────
# ROWS THAT ARE ALLOWED TO STAY A PLAIN TEXT BOX, each with the reason.
#
# ⚠️ IT IS DOWN TO THREE, and the three are not a backlog — they are the rows
# where a list would be the wrong answer rather than a missing one. Everything
# else that was a text box now has a control that fits its value.
#
#   location.name          ⚠️ THESE THREE ARE THE ONLY ONES LEFT, AND THEY STAY.
#   location.lat           There is no list of places this machine knows, so
#   location.lon           there is nothing to suggest — what there is, is a
#                          search, and ui/common/LocationPicker.qml is it. It
#                          sits above these three rows on the same page and
#                          fills all three at once, which is exactly why it is
#                          NOT a SettingRow: a row reads and writes one dotted
#                          path, and that rule is what gives
#                          tests/setting-rows.sh its meaning.
FREETEXT="
location.name
location.lat
location.lon
"

fails=0
ok()  { printf '  \033[38;5;114mok\033[0m   %s\n' "$1"; }
bad() { printf '  \033[38;5;203mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }

pages=shell/ui/settings/pages

# key<TAB>kind<TAB>file, one line per row. Anchored on `^ *key:` for the same
# reason tests/setting-rows.sh is: SettingRow's own `property string key` must
# not count as a row.
rows() {
    for f in "$pages"/*.qml; do
        awk -v F="$(basename "$f")" '
            /^ *key: *"/  { k = $0; sub(/.*key: *"/, "", k);  sub(/".*/, "", k);
                            kind = "switch"; opts = 0; next }
            /^ *kind: *"/ { kind = $0; sub(/.*kind: *"/, "", kind); sub(/".*/, "", kind) }
            /^ *options:/ { opts = 1 }
            /^ *}/        { if (k != "") { print k "\t" kind "\t" opts "\t" F; k = "" } }
        ' "$f"
    done
}

all="$(rows)"
[[ -n "$all" ]] || { echo "  no rows found — the extraction is broken, not the pages"; exit 1; }

# ── 1 · every free-text row is on the list ──────────────────────────────────
while IFS=$'\t' read -r key kind opts file; do
    [[ "$kind" == "field" || "$kind" == "strings" ]] || continue
    if grep -qxF "$key" <<< "$FREETEXT"; then
        ok "$key is free text, and the reason is written down"
    else
        bad "$key is a plain text box with no reason given ($file)"
    fi
done <<< "$all"

# ── 2 · …and nothing on the list has quietly gained suggestions ─────────────
#
# The half that keeps the list honest. Without it, a row that got a `pick` last
# month is still listed as owed, and the list slowly becomes a description of
# the past.
while read -r key; do
    [[ -n "$key" ]] || continue
    line="$(grep -P "^\Q$key\E\t" <<< "$all" | head -1)"
    if [[ -z "$line" ]]; then
        bad "$key is on the free-text list but has no row at all"
        continue
    fi
    kind="$(cut -f2 <<< "$line")"
    if [[ "$kind" == "field" || "$kind" == "strings" ]]; then
        ok "$key is still owed ($kind)"
    else
        bad "$key is a \"$kind\" now — strike it off the list in this file"
    fi
done <<< "$FREETEXT"

# ── 3 · a row that promises suggestions has a source ────────────────────────
#
# ⚠️ `pick` WITH NO `options` IS THE WORST OF THE THREE STATES. It draws a text
# box that looks like the others, shows no suggestions because there are none,
# and says nothing about it — so it reads as a machine that simply has no fonts
# installed. Measured once already, from the other end: the pick control looked
# empty on a machine with 109 fonts, and the service was innocent both times.
while IFS=$'\t' read -r key kind opts file; do
    case "$kind" in
        pick|picks|command) ;;
        *) continue ;;
    esac
    if [[ "$opts" == "1" ]]; then
        ok "$key ($kind) has a source"
    else
        bad "$key is a \"$kind\" with no options — an empty list that cannot say so ($file)"
    fi
done <<< "$all"

# ── 4 · the sources are real ────────────────────────────────────────────────
#
# A text check, and a narrow one: every `options:` expression must name
# something that exists in the services layer. It catches the rename that leaves
# a binding pointing at nothing — QML resolves an unknown property to undefined
# without a word, and `options: undefined` is again a list that is empty and
# silent.
grep -rhoE '^ *options: *(Services\.[A-Za-z]+\.[A-Za-z]+|root\.[A-Za-z]+)' "$pages" \
    | sed -E 's/^ *options: *//' | sort -u \
    | while read -r expr; do
        case "$expr" in
        Services.*)
            svc="$(cut -d. -f2 <<< "$expr")"
            prop="$(cut -d. -f3 <<< "$expr")"
            if [[ ! -f "shell/services/$svc.qml" ]]; then
                echo "MISSING service $svc"
            elif ! grep -qE "(property|function) +[A-Za-z<>]* *$prop\b" "shell/services/$svc.qml"; then
                echo "MISSING $expr"
            fi
            ;;
        esac
    done > /tmp/buchhwin-suggest-missing.$$
if [[ -s /tmp/buchhwin-suggest-missing.$$ ]]; then
    while read -r l; do bad "options points at nothing: $l"; done < /tmp/buchhwin-suggest-missing.$$
else
    ok "every options: expression names something that exists"
fi
rm -f /tmp/buchhwin-suggest-missing.$$

# ── 5 · the two list kinds keep their meaning apart ─────────────────────────
#
# ⚠️ `programs.*` MUST NOT BECOME `picks`. It is an argument list — ["kitty",
# "-e", "btop"] — where the order carries meaning, and a chip field would let
# you shuffle it. `spawn` with the arguments in the wrong order fails with a
# message that does not mention the reason.
for k in terminal browser fileManager editor imageViewer video; do
    line="$(grep -P "^programs\.$k\t" <<< "$all" | head -1)"
    kind="$(cut -f2 <<< "$line")"
    if [[ "$kind" == "command" ]]; then
        ok "programs.$k keeps its argument order"
    else
        bad "programs.$k is \"$kind\" — an argv is not a set, see SettingRow"
    fi
done

# ── 6 · the lists actually have something in them ───────────────────────────
#
# ⚠️ EVERYTHING ABOVE IS TEXT, AND TEXT CANNOT SEE AN EMPTY LIST. A `pick` whose
# source returns nothing draws a box with no pills under it, which looks exactly
# like a machine that has no fonts — and that is how this control was reported
# broken once already, on a machine a headless probe found 109 fonts on at the
# same moment. So the services are asked.
#
# Which lists are allowed to be empty is decided HERE rather than in the tool:
# `players` is empty when nothing is playing and `workspaceNames` is empty until
# somebody names a workspace, both correct. `monitors` being empty would be a
# desktop that cannot see its own screen.
#
# ⚠️⚠️ AND THE PROBE ITSELF NEEDED A CONTROL BEFORE IT COULD BE BELIEVED. Its
# first run reported `monitors=0` and it was NOT a fault in the code — under
# QT_QPA_PLATFORM=offscreen there are no Wayland outputs, so Quickshell.screens
# is legitimately empty. Measured both ways at the same moment:
#
#   offscreen                monitors=0
#   the real session         monitors=1, Virtual-1
#
# A red line believed at that point would have gone into a handover as "the
# screen list is broken", and the next round would have started by looking at
# the wrong thing. So the screen list is only required where screens exist, and
# where they do not the line says so rather than passing quietly.
if ! command -v qs >/dev/null; then
    printf '       %s\n' "skipped the runtime half: quickshell is not installed here"
else
    probe=/tmp/buchhwin-suggest-check.$$
    rm -f "$probe"
    onscreen=no
    if [[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" \
          && -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
        onscreen=yes
        BUCHHWIN_TOOL=suggest-check BUCHHWIN_SUGGEST_OUT="$probe" \
            timeout 60 qs -p shell >/dev/null 2>&1
    else
        BUCHHWIN_TOOL=suggest-check BUCHHWIN_SUGGEST_OUT="$probe" \
        QT_QPA_PLATFORM=offscreen timeout 60 qs -p shell >/dev/null 2>&1
    fi
    if [[ ! -f "$probe" ]]; then
        bad "the probe wrote nothing at all — it crashed before it could report"
    else
        v() { grep -m1 "^$1=" "$probe" | cut -d= -f2-; }

        # ⚠️ THE ONE SERVICE THAT MUST ANSWER, and it is asked by name. The probe
        # used to write `timeout=yes` and nothing else whenever its wait ran out,
        # and this said "the services never answered" — which was true of one of
        # the two services waited on, and never said which. Installed is the one
        # that is genuinely asked a question; if it has not answered, everything
        # below it is measuring an empty machine and says so.
        if [[ "$(v installed)" == yes ]]; then
            ok "the installed-programs service answered"
        else
            bad "Installed never answered — its scan hung or died, so every list below is empty for that reason"
        fi

        required=(keyboardOptions durations)
        if [[ "$onscreen" == yes ]]; then
            required+=(monitors)
        else
            printf '       %s\n' "screens not measured: no Wayland session here, so Quickshell.screens is empty by definition, not by fault"
        fi

        # ⚠️⚠️ THE PROGRAM LISTS ARE ONLY REQUIRED WHERE THERE ARE PROGRAMS, and
        # this is the same distinction the sounds block below makes, arrived at
        # the same way. `allPrograms` and `appIds` are built from the freedesktop
        # database with NoDisplay entries dropped — services/Apps.qml drops them
        # deliberately, because they exist to own a MIME type rather than to be
        # picked out of a menu. The Fedora WSL used for testing has exactly one
        # .desktop file, `org.quickshell.desktop`, and it is NoDisplay; the CI
        # container has none at all. On both, an empty program list is a fact
        # about the machine and not a fault in the code.
        #
        # ⚠️ AND IT REMAINS A CHECK WHERE IT CAN BE ONE. On any machine with
        # programs installed — every developer machine, the real session — both
        # lists must be non-empty. What is dropped is the claim that a machine
        # with no menu entries is broken.
        app_files=0
        for d in /usr/share/applications /usr/local/share/applications \
                 "$HOME/.local/share/applications" \
                 /var/lib/flatpak/exports/share/applications; do
            [[ -d "$d" ]] || continue
            n="$(grep -LiE '^NoDisplay[[:space:]]*=[[:space:]]*true' \
                 "$d"/*.desktop 2>/dev/null | wc -l)"
            app_files=$(( app_files + n ))
        done
        if [[ "$app_files" -gt 0 ]]; then
            required+=(appIds allPrograms)
        else
            printf '       %s\n' "programs not measured: this machine has no visible .desktop entry at all (appCount=$(v appCount)), so an empty program list is a fact rather than a fault"
        fi
        # ⚠️⚠️ SOUNDS ARE ONLY REQUIRED WHERE THERE ARE SOUNDS, and that is not a
        # softened check — it is the same distinction the screens line above
        # already makes. The list is built from /usr/share/sounds and
        # ~/.local/share/sounds; the CI runs in a bare `fedora:44` container,
        # which ships no sound theme at all. So this said "sounds is EMPTY — the
        # row shows a box and says nothing" and turned the lane red over a
        # machine rather than over the code, exactly as tests/greeter.sh did
        # until it was given a fixture.
        #
        # ⚠️ AND IT IS STILL A CHECK WHERE IT CAN BE ONE. On any machine with a
        # sound theme installed — every developer machine, the lab VM — the list
        # must be non-empty and its entries must carry readable labels. What is
        # dropped is the claim that a container without sounds is broken.
        sound_files=0
        for d in /usr/share/sounds "$HOME/.local/share/sounds"; do
            [[ -d "$d" ]] || continue
            n="$(find "$d" -type f \( -name '*.oga' -o -name '*.ogg' -o -name '*.wav' \) 2>/dev/null | wc -l)"
            sound_files=$(( sound_files + n ))
        done
        if [[ "$sound_files" -gt 0 ]]; then
            required+=(sounds)
        else
            printf '       %s\n' "sounds not measured: this machine has no sound theme installed at all, so an empty list is a fact rather than a fault"
        fi
        for key in "${required[@]}"; do
            n="$(v "$key")"
            if [[ "${n:-0}" -gt 0 ]]; then ok "$key has $n entries"
            else bad "$key is EMPTY — the row shows a box and says nothing"; fi
        done
        # ⚠️ ORDERED, NOT FILTERED. If the category list ever becomes a filter,
        # the first casualty is a program that carries no category — and it
        # would get "Not installed here" under a program that is installed.
        if [[ "$(v networkFirst)" == "$(v allPrograms)" ]]; then
            ok "programs(cats) orders rather than filters ($(v allPrograms) either way)"
        else
            bad "programs(cats) is filtering: $(v networkFirst) of $(v allPrograms) survive"
        fi
        # Same reasoning as above: a label check over an empty list measures
        # nothing, and reporting it as a fault points at the wrong thing.
        if [[ "$sound_files" -eq 0 ]]; then
            printf '       %s\n' "sound labels not measured: there are no sounds on this machine to label"
        elif [[ "$(v soundsLabelled)" == "yes" ]]; then
            ok "sounds are offered by name, not by 55 characters of path"
        else
            bad "sounds carry no readable label"
        fi
        printf '       %s\n' "not required to be non-empty here: players=$(v players), workspaceNames=$(v workspaceNames)"
    fi
    rm -f "$probe"
fi

(( fails == 0 )) || exit 1
exit 0
