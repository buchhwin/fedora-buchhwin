#!/usr/bin/env bash
#
# Every `Theme.<name>` the shell reads has to exist in shell/theme/Theme.qml.
#
# ⚠️⚠️ WRITTEN AFTER A ONE-LINE FAULT THAT BLANKED A WHOLE PAGE.
# `ui/settings/OutputArrangement.qml` declared its canvas height as
# `Theme.space10 * 4`, and there is no `space10` — the spacing grid stops at
# `space6`. QML says NOTHING about a property that does not exist, so the
# multiplication produced NaN, the canvas got no height, and the monitors he was
# supposed to drag had nowhere to be drawn. The description beside them is a
# sibling item and kept rendering, so the page looked half-built rather than
# broken: "eine beschreibung ist da aber ich sehe die monitore nicht als        # english-ok: the report, quoted
# rechteck".                                                                    # english-ok: the report, quoted
#
# ⚠️ FOUR CHECKERS WERE GREEN OVER IT AT THE SAME TIME, which is the reason this
# file exists rather than a one-line fix being the end of it:
#
#   pages.sh        builds the displays page EMPTY under offscreen — there are
#                   no Wayland outputs, so its repeater walks nothing
#   displays.sh     measures the ARITHMETIC against a fake fixture, not geometry
#   no-literals.sh  demands a token instead of a bare number, which is what
#                   turned a plain 160 into an invented NAME — and it never asks
#                   whether the name it insisted on exists
#   qmllint-qt6     measured on this exact class once before, when an avatar ring
#                   still pointed at `Theme.glassRimTop` after the token was
#                   deleted: it had nothing to say. See shell/tools/lock-check.qml
#
# ⚠️ COMMENTS ARE STRIPPED FIRST, AND THAT IS NOT TIDINESS. Three names appear in
# prose only — `Theme.glassRimTop` in lock-check.qml's own account of the bug
# above, `Theme.qml` wherever a file is named, and `Theme.spaceN` in BarContent's
# description of the 4 px grid. A checker that reported those would be wrong
# three times on its first run, and a checker that is wrong on its first run gets
# switched off. So prose does not count; only code does.
#
# ⚠️ AND IT COUNTS THE FILES IT READ. `tests/english.sh` once passed over ZERO
# files on the VM — the working copy is an rsync without `.git`, `git ls-files`
# answered with nothing, and every green tick it printed was worth nothing. A
# check that finds no faults because it looked at no files must say so.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

theme="shell/theme/Theme.qml"
[[ -f "$theme" ]] || { echo "  $theme is missing"; exit 2; }

red=$'\e[38;5;203m'; off=$'\e[0m'

# Strip comments so prose cannot be mistaken for code: block comments first
# (they span lines, so this needs a state machine rather than sed), then
# everything from `//` to the end of the line.
strip_comments() {
    awk '
        {
            line = $0
            out = ""
            while (length(line)) {
                if (inblock) {
                    p = index(line, "*/")
                    if (p == 0) { line = ""; break }
                    inblock = 0
                    line = substr(line, p + 2)
                    continue
                }
                b = index(line, "/*")
                l = index(line, "//")
                if (l > 0 && (b == 0 || l < b)) {
                    out = out substr(line, 1, l - 1)
                    line = ""
                    break
                }
                if (b > 0) {
                    out = out substr(line, 1, b - 1)
                    line = substr(line, b + 2)
                    inblock = 1
                    continue
                }
                out = out line
                line = ""
            }
            print out
        }
    ' "$1"
}

# What Theme actually declares: its properties (including aliases and list
# types) and its functions.
declared="$(grep -oE '^[[:space:]]*(readonly[[:space:]]+)?(property[[:space:]]+[A-Za-z_][A-Za-z0-9_<>]*|function)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$theme" \
            | awk '{ print $NF }' | sort -u)"

if [[ -z "$declared" ]]; then
    echo "  ${red}read no declarations out of $theme${off} — this check was measuring nothing"
    exit 2
fi

# ⚠️ mapfile, not an unquoted $(find …) — SC2044, and this repo has walked into
# it twice with the comment warning against it already in the file.
mapfile -t files < <(find shell -name '*.qml' -type f | sort)

if (( ${#files[@]} == 0 )); then
    echo "  ${red}found no QML files under shell/${off} — this check was measuring nothing"
    exit 2
fi

fail=0
seen=0

for f in "${files[@]}"; do
    while IFS=: read -r line name; do
        [[ -n "${name:-}" ]] || continue
        seen=$((seen + 1))
        if ! grep -qxF "$name" <<< "$declared"; then
            printf '  %sFAIL%s  %s:%s  Theme.%s is not declared in %s\n' \
                   "$red" "$off" "$f" "$line" "$name" "$theme"
            fail=1
        fi
    done < <(strip_comments "$f" \
             | grep -noE '\bTheme\.[A-Za-z_][A-Za-z0-9_]*' \
             | sed 's/:Theme\./:/')
done

if (( seen == 0 )); then
    echo "  ${red}no Theme.<name> reference found in ${#files[@]} files${off} — that cannot be right"
    exit 2
fi

if (( fail )); then
    cat <<'EOF'

  A name that Theme does not declare is `undefined` at runtime, and QML does not
  say a word about it. In a binding it throws, and a binding that throws keeps
  the property's last value — usually the default. In arithmetic it does not
  even throw: `undefined * 4` is NaN, and a NaN height is a surface with nothing
  in it.

  Either add the token to shell/theme/Theme.qml or use one that is already there.
EOF
    exit 1
fi

printf '  %d Theme references across %d files, all declared\n' "$seen" "${#files[@]}"
