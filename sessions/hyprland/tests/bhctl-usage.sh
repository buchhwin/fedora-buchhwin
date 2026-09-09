#!/usr/bin/env bash
#
# Every subcommand bhctl implements is listed, and every line it lists is real.
#
# ⚠️ THE FAULT THIS EXISTS FOR. `bhctl binds reset` was implemented, and
# `bhctl doctor` printed "run: bhctl binds reset" as its advice — but `usage()`
# did not mention it, and `usage()` is what a bare `bhctl` prints. Its own
# comment calls it "THE ONE HANDLE THAT UNFREEZES A MACHINE", so the one command
# somebody needs when their keys have stopped working could only be found by
# reading the source.
#
# Both directions, because the opposite drift is just as bad: a line advertising
# a subcommand that was renamed sends people to `bhctl: unknown` and reads as a
# broken program rather than a stale document.
#
# Reads the file. Nothing is executed, so this needs no desktop and runs in CI.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0

# ⚠️ THE LABELS ARE INDENTED AND THIS WAS ANCHORED AT COLUMN 0, so it matched
# nothing and the whole suite exited 2 — "found no subcommands" — which CI
# reports as a skip. The test that checks bhctl's usage text against its real
# subcommands had therefore not run since the file was reformatted.
#
# The original `case "${1:-}" in` labels. Leading whitespace is allowed because
# nested case in this file is indented — `reset)` inside `binds)` is not a
# subcommand of its own, and matching it would demand a usage line for it.
#
# ⚠️ QUOTED LABELS COUNT. Two of them are written `"prune")` and `"shell")`,
# and the first version of this pattern silently skipped both — it then reported
# those two usage lines as advertising commands that do not exist, which is the
# opposite of the truth. A check whose extractor is wrong invents faults; the
# quotes are stripped here rather than the pattern being loosened, so a label
# that is genuinely indented still cannot sneak in.
# ⚠️⚠️ THE ANCHOR MOVED FROM COLUMN 0 TO EXACTLY FOUR SPACES, and until it did
# this whole suite was dead. The reasoning above is still right — a nested label
# must not count — but it assumed the top-level labels sit at column 0, and they
# have not since bin/bhctl was reformatted. `^"?[a-z|]+"?\)$` then matched
# nothing at all, the array came back empty, and the guard below exited 2:
# "found no subcommands". CI reads that as a skip, so the check that keeps the
# usage text honest had not run in months.
#
# Four spaces is what tells the two apart: the top-level labels are one level
# in, and anything nested inside them is deeper still.
mapfile -t implemented < <(
    sed -n '/^case "${1:-}" in$/,/^esac$/p' bin/bhctl \
    | sed -nE 's/^    "?([a-z|]+)"?\).*/\1/p' | tr '|' '\n' | sort -u
)
# ⚠️ THE USAGE TEXT LISTS COMMANDS INDENTED, NOT PREFIXED. The pattern here
# looked for lines starting `bhctl <cmd>`, which is how the help used to read;
# it is a two-space-indented table now. So this half came back empty too, and
# between the two extractors the suite compared nothing against nothing.
mapfile -t advertised < <(
    sed -n "/^usage() {/,/^}$/p" bin/bhctl \
    | sed -nE 's/^  ([a-z]+)[[:space:]].*/\1/p' | sort -u
)

if (( ${#implemented[@]} == 0 )); then
    echo "  found no subcommands — the case block moved?"; exit 2
fi

# ⚠️⚠️ ONE ELEMENT PER LINE, IN A VARIABLE, AND BOTH HALVES OF THAT MATTER.
# `grep -x` matches WHOLE LINES, so the haystack has to be one entry per line —
# `<<< "${arr[@]}"` joins the array with spaces into a single line and every
# lookup then fails. And the obvious `printf '%s\n' "${arr[@]}" | grep -qxF` is
# the pipefail/SIGPIPE trap tests/pipefail-grep.sh exists for: grep leaves at
# the first match, printf takes the signal, and the pipeline reports failure
# precisely when the entry WAS found. Building the text once is both fixes.
advertised_lines="$(printf '%s\n' "${advertised[@]}")"
implemented_lines="$(printf '%s\n' "${implemented[@]}")"

printf '  %-40s ' "every subcommand is in usage()"
missing=""
for c in "${implemented[@]}"; do
    [[ "$c" == "*" ]] && continue
    grep -qxF "$c" <<< "$advertised_lines" || missing+=" $c"
done
if [[ -z "$missing" ]]; then
    printf '\033[38;5;114mok\033[0m  %d subcommands\n' "${#implemented[@]}"
else
    printf '\033[38;5;203mnot listed:%s\033[0m\n' "$missing"; fail=1
fi

printf '  %-40s ' "every usage() line is implemented"
ghost=""
for c in "${advertised[@]}"; do
    grep -qxF "$c" <<< "$implemented_lines" || ghost+=" $c"
done
if [[ -z "$ghost" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mno such subcommand:%s\033[0m\n' "$ghost"; fail=1
fi

# ⚠️ THREE CHECKS STOOD HERE AND DROVE `bhctl binds reset`, WHICH IS GONE.
# They guarded a rescue path that could clear every keybinding: that the
# command was advertised in usage(), that its exit code was read rather than
# assumed, and that BUCHHWIN_BINDS_MODE could not leak from a diagnosis into a
# reset. All three were right, and all three now test nothing — the subcommand
# left with the 1,500 lines this file shed in the move to Hyprland.
#
# They are not commented out and waiting. If a rescue path comes back it will
# be a different one, and a copy of the old checks would be three assertions
# about a command nobody wrote yet.

exit $fail
