#!/usr/bin/env bash
#
# The second tripwire.
#
# This desktop was written in German and is published in English, and that is
# not a one-off translation but a boundary that decays: the next label typed in
# a hurry is German, because the person typing it thinks in German. It happened
# once already — ~90 visible strings, 55 keybinding descriptions that land in
# niri's own shortcut overlay, and a whole checklist, all in a public
# repository whose own plan says English.
#
# So it is checked rather than remembered, in the same shape as
# tests/no-literals.sh: a line that genuinely needs an exception says so.
#
#     property string key: "Super+Ö"    // english-ok: the name of a physical key
#
# ⚠️ IT LOOKS FOR GERMAN FUNCTION WORDS, NOT FOR UMLAUTS.
#
# Umlauts alone are the wrong test twice over: half of German has none
# ("Fokus nach links"), and the ones that survive on purpose are key names on a
# German keyboard. Function words are what a sentence cannot avoid, and they do
# not collide with English — which is why `die`, `was`, `man`, `mit` and `so`
# are deliberately NOT in the list below, however German they look: this
# repository contains a shell function called `die`, the MIT licence, and a
# great many English sentences. `Taste` came out for the same reason on the
# tripwire's very first run — "a matter of taste" is not German.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
report() { printf '  \033[38;5;203m%s\033[0m  %s\n' "$1" "$2"; fail=1; }

words='der|das|dass|und|oder|nicht|kein|keine|keinen|wird|wurde|werden|sind'
words+='|eine|einen|einem|eines|von|für|fuer|auf|aus|nach|noch|schon|wenn|dann'
words+='|alle|alles|muss|kann|soll|sollen|warum|ich|sich|mehr|immer|nie|sehr'
words+='|wie|wo|zum|zur|vom|beim|durch|ohne|gegen|über|ueber|unter|zwischen'
words+='|jeder|jede|jedes|dieser|diese|dieses|diesem|damit|weil|aber|auch|nur'
words+='|schliessen|schließen|öffnen|oeffnen|Fenster|Farbe|Datei|Ordner'
# Added after one slipped through: "Einstellungen kommen in M8 — bis dahin
# shell.json" contains not one word from the list above. A word list is only
# ever as good as its last miss, so a miss earns an entry rather than a shrug.
words+='|Einstellung|Einstellungen|kommen|kommt|bis|dahin|bisher|jetzt|heute'
# ⚠️ `Programme` CAME BACK OUT, on the rule this file already states about
# `die`, `was`, `man` and `Taste`: a word that is also correct English does not
# belong in the list. "programme" is the British spelling this repository writes
# elsewhere ("colour", "behaviour"), and forbidding it turns the tripwire into a
# trap for somebody writing correct prose. `Programm` alone has no English
# collision and stays — \b sees the trailing "e" as part of the word, so it does
# not match the English one.
words+='|Programm|Taste[nr]|Starter|Leiste|Suche|Sitzung|Bildschirm'
# Two more that slipped through into the location picker and shipped: a button
# labelled "stimmt" and a status reading "sucht …". Neither contains a word from
# the lists above, and neither is a function word — which is the limit of the
# method, not a reason to stop extending it.
words+='|stimmt|stimmen|sucht|suchen|gefunden|Ton|Netz|Gerät|Geraet|Geräte|Geraete'
# ⚠️ AND THEN A WHOLE WEATHER FORECAST WAS FOUND IN GERMAN — nine of the ten
# descriptions the panel shows, plus two calendar errors, a location error and
# the town-name placeholder. Not one of them contains a function word, which is
# the honest limit of the method: it catches sentences, and a label is not a
# sentence. Nouns a user-facing string is likely to be made of therefore go in
# too, even though each one is a guess about the future rather than a rule.
words+='|klar|bedeckt|Nebel|Niesel|Regen|Schnee|Schauer|Gewitter|Wolken|Sonne'
# And one more that sat in the session menu, in the one place where a wrong
# word is pressed by somebody in a hurry: "Ausschalten" beside four English
# labels. Nouns again — the method catches sentences, not labels.
words+='|Ausschalten|Neustart|Abmelden|Sperren|Ruhezustand'
words+='|Anmeldung|abgelehnt|Konto|Stadt|eingeben|Ortssuche|Unsinn|Uhrzeit|Datum'
words+='|Lautstärke|Lautstaerke|Helligkeit|Verbindung|verbunden|getrennt|Passwort'
# And "+ 2 weitere" in the notification list, which shipped. Same limit as
# above: not a function word, not a sentence — a two-word label. It is in now.
words+='|weitere|weiteren|Meldung|Meldungen|Mitteilung|Mitteilungen'

# ⚠️ `git ls-files` FIRST, `find` WHEN THERE IS NO GIT — and the fallback is the
# point, not a nicety. The working copy on the test machine is an rsync without
# .git, so the git form answered with nothing and this check printed a green
# tick over ZERO files for a whole session. A check that only works in a
# checkout does not run where the code actually runs.
# ⚠️ `--others --exclude-standard` IS NOT OPTIONAL. Plain `git ls-files` lists
# TRACKED files only, so a brand-new file — the most likely place for a mistake
# to be — is silently left out. Found on 07.08.2026 when a new shell/common/
# singleton became the sole reader of four settings and key-readers.sh reported
# all four as having none: the advice it printed was "delete the key", which
# would have deleted four working settings. Untracked-but-not-ignored is the
# corpus that matches what is actually on disk.
files=$(git ls-files --cached --others --exclude-standard \
               'shell/*.qml' 'shell/**/*.qml' 'docs/*.md' 'README.md' \
               'lib/*.sh' 'bin/*' 'install.sh' 'tests/*.sh' 2>/dev/null)
if [[ -z "$files" ]]; then
    files=$(find shell docs lib bin tests -type f \
                 \( -name '*.qml' -o -name '*.md' -o -name '*.sh' -o -path 'bin/*' \) \
                 2>/dev/null; ls README.md install.sh 2>/dev/null)
fi

# ⚠️ AN EMPTY LIST IS A BROKEN CHECK, NOT A CLEAN REPOSITORY — and this one
# reported "ok" for a whole session. `git ls-files` answers with nothing outside
# a git checkout, and the working copy on the test VM is an rsync WITHOUT .git.
# So every green tick this printed there was over zero files.
#
# Found on 07.08.2026 by installing onto a fresh machine: tap-targets.sh, which
# already had this guard, went red at once and pointed at the hole. Same guard
# here, and exit 2 rather than 1 so it reads as "could not check" instead of
# "checked and clean".
[[ -n "$files" ]] || { echo "  found no files to check — not a git checkout?"; exit 2; }

for file in $files; do
    # This file names the words it forbids, so it cannot check itself.
    [[ "$file" == "tests/english.sh" ]] && continue
    while IFS=: read -r line text; do
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"english-ok"* ]] && continue
        report "german  $file:$line" \
               "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-72)"
    done < <(grep -nEi "\\b(${words})\\b" "$file" 2>/dev/null)
done

# ------------------------------------------------------- and the third tripwire
#
# ⚠️ NO WARNING TRIANGLE IN A STRING THAT REACHES THE SCREEN.
#
# This is the same class of mistake as the one above — a habit from one place
# leaking into another — and it shipped: 22 visible hints in the settings window
# carried a ⚠️, because the comments in this repository use it constantly and
# the hand that types the comment types the hint.
#
# The two meanings are not the same. In a comment ⚠️ means "somebody fell in
# here, read this before you change it", which is exactly right. In a row of the
# settings window it means "something is wrong with this setting", and it is
# said about settings that are perfectly fine. His words: "es gibt auch ganz
# viel settings wo ein dreieck davor ist, das sieht auch echt blöd aus".   # english-ok: the report, quoted
#
# So the comments keep theirs — 150 of them, deliberately — and only the
# properties that get painted are checked. Same escape hatch as above, on the
# line, for the day a string genuinely is a warning:
#
#     status: "⚠️ battery critical"    // warn-ok: it really is a warning
#
# ⚠️ The match is the property prefix plus a triangle anywhere on the line, not
# a triangle inside the quotes. Parsing where a QML string ends means handling
# \" escapes, and two of the 22 had them — a check that is easy to get subtly
# wrong is worse than one that occasionally asks for a `warn-ok:`.
painted='hint|label|status|title|placeholder|desc|text'
for file in $files; do
    [[ "$file" == "tests/english.sh" ]] && continue
    while IFS=: read -r line text; do
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"warn-ok"* ]] && continue
        report "triangle  $file:$line" \
               "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-72)"
    done < <(grep -nE "^[[:space:]]*(${painted}):.*⚠️" "$file" 2>/dev/null)
done

# ⚠️ AND THE THIRD RULE: AN EXPLANATION IN THE WINDOW IS ONE SENTENCE.
#
# On 09.08. he named seven pages — Type, Pointer, Clock & Date, Keyboard,
# Windows, Programs, This Machine — as "unübersichtlich". Two of the three     # english-ok: the report, quoted
# causes were countable: the suggestion pills, and the fact that five of those
# pages had no `advanced:` marks at all. The third was this file's business.
#
# Forty-four `hint:` strings were over 120 characters and the longest was 293.
# They were not explanations, they were JUSTIFICATIONS — why the setting is
# built the way it is, which is what a code comment is for. SettingRow elides
# them to one line and puts the rest in a tooltip, so the wall was not visible
# in the layout; it was visible in the reading.
#
#   In a comment, an explanation says "this is how it is built."
#   In the window, it says "you have to understand this first."
#
# This is the same fault as the warning triangles above, one step further in:
# a habit from the comments leaking into the interface. So the same shape of
# rule, with the same kind of exit for a line that genuinely needs it:
#
#     hint: "…160 characters of real instruction…"   // hint-ok: <reason>
LIMIT_HINT=120
while IFS= read -r file; do
    while IFS=: read -r line text; do
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"hint-ok"* ]] && continue
        # The string between the first pair of quotes on the line.
        body="$(printf '%s' "$text" | sed -E 's/^[^"]*"//; s/"[^"]*$//')"
        (( ${#body} > LIMIT_HINT )) || continue
        report "long-hint  $file:$line" "${#body} characters: $(printf '%s' "$body" | cut -c1-52)…"
    done < <(grep -nE '^[[:space:]]*hint:[[:space:]]*"' "$file" 2>/dev/null)
done <<< "$files"


if (( fail )); then
    cat <<'EOF'

  This repository is public and its plan says English — everywhere, without an
  i18n apparatus. A German label reaches further than it looks: the `desc:`
  fields become the entries in niri's own keyboard-shortcut overlay.

  If a line is right as it stands — the name of a key, a folder that really is
  called that on the machine — say so on the line:

      "Super+Ö"    // english-ok: the name of a physical key

  A `triangle` finding is the other rule: ⚠️ belongs in comments, where it warns
  the next person editing the code, and not in a string the user reads, where it
  says a setting is broken when it is not. Take the character out and keep the
  sentence. If the string really is a warning, say so on the line:

      status: "⚠️ battery critical"    // warn-ok: it really is a warning

  A `long-hint` finding is the third: a row explains what a setting DOES, in one
  sentence. Why it is built that way belongs in a comment above the row, where
  the next person editing it will read it and the person using the desktop will
  not. If a line really needs the length, say so:

      hint: "…"    // hint-ok: it is a format string and every code matters

EOF
else
    printf '  English everywhere, no ⚠️ on screen, and every hint one sentence\n'
fi
exit $fail
