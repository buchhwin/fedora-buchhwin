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

# The top-level `case "${1:-}" in` labels. Anchored at column 0 because every
# nested case in this file is indented — `reset)` inside `binds)` is not a
# subcommand of its own, and matching it would demand a usage line for it.
#
# ⚠️ QUOTED LABELS COUNT. Two of them are written `"prune")` and `"shell")`,
# and the first version of this pattern silently skipped both — it then reported
# those two usage lines as advertising commands that do not exist, which is the
# opposite of the truth. A check whose extractor is wrong invents faults; the
# quotes are stripped here rather than the pattern being loosened, so a label
# that is genuinely indented still cannot sneak in.
mapfile -t implemented < <(
    sed -n '/^case "${1:-}" in$/,/^esac$/p' bin/bhctl \
    | grep -E '^"?[a-z|]+"?\)$' | tr -d '")' | tr '|' '\n' | sort -u
)
mapfile -t advertised < <(
    sed -n "/^usage() {/,/^}$/p" bin/bhctl \
    | grep -oE '^bhctl [a-z]+' | awk '{print $2}' | sort -u
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

# ⚠️ AND THE RESCUE ITSELF, checked by name rather than by counting. `binds
# reset` is the one command in here that somebody reaches for when the desktop
# is already misbehaving, and the check above would go green again the day it
# is deleted from both places at once.
printf '  %-40s ' "the rescue is offered by name"
if grep -q '^bhctl binds reset' bin/bhctl; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mbhctl binds reset is not in usage()\033[0m\n'; fail=1
fi

# ⚠️ AND IT CANNOT SILENTLY DO NOTHING. bin/bhctl runs without `set -e`, so the
# edit failing left the `exec` after it to announce a successful regeneration —
# over a settings file whose frozen bindings were untouched.
#
# ⚠️⚠️ THIS CHECK WAS RIGHT AND WENT RED WHEN THE RESCUE MOVED TO QML, which is
# the good outcome and worth writing down. It used to look for `command -v
# python3` and an `rc=$?`, because the edit was an embedded python3 heredoc.
# The edit is shell/tools/binds.qml now — rule 2, rewriting a settings file is
# configuration logic — so the old two markers are gone. The DUTY has not
# changed a bit, so the check follows it to the new shape rather than being
# deleted:
#
#   the exit code of the tool is read          (`rc=$?` after run_tool)
#   the tool's own verdict is read             (`removed …` / `none` / else)
#   anything else exits non-zero               (no `exec` on an unknown answer)
#
# The verdict matters as much as the code: run_tool's own note says a tool that
# REFUSES exits 0 and says so in its report, so an exit code alone would call a
# refusal a success.
printf '  %-40s ' "the rescue cannot fail silently"
block="$(sed -n '/^binds)$/,/^doctor)$/p' bin/bhctl)"
if grep -qE 'rc=\$\?' <<< "$block" \
   && grep -q 'buchhwin-binds.log' <<< "$block" \
   && grep -qE 'exit "\$\{?rc' <<< "$block"; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mthe exit code or the verdict of the rescue is not read\033[0m\n'
    fail=1
fi

# ⚠️ AND THE COUNTING RUN MUST NOT BE ABLE TO DELETE ANYTHING. `bhctl doctor`
# and `bhctl binds reset` drive the SAME tool, told apart by one environment
# variable — so a report that ran with the wrong one would edit the settings of
# somebody who asked for a diagnosis.
#
# The trap is real and specific to bash: a variable assignment in front of a
# FUNCTION call is NOT scoped to that call, it stays set afterwards. `MODE=reset
# run_tool binds` followed later by a plain `run_tool binds` would inherit
# `reset`. Both call sites therefore go through a subshell, and this is what
# holds that shut.
printf '  %-40s ' "a diagnosis cannot delete bindings"
if [[ "$(grep -c 'BUCHHWIN_BINDS_MODE' bin/bhctl)" == \
      "$(grep -c 'export BUCHHWIN_BINDS_MODE' bin/bhctl)" ]] \
   && grep -q 'export BUCHHWIN_BINDS_MODE=count' bin/bhctl \
   && grep -q 'export BUCHHWIN_BINDS_MODE=reset' bin/bhctl; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mBUCHHWIN_BINDS_MODE is set without export in a subshell — it would leak to the next call\033[0m\n'
    fail=1
fi

# ⚠️⚠️ EVERY HELPER IT CALLS HAS TO EXIST, and the day this check was written it
# did not hold: bin/bhctl called `die`, `warn` and `ok` twenty-one times and
# defined none of them. Without `set -e`, a missing function is a `command not
# found` and the script CARRIES ON — so `bhctl greeter enable`, whose three
# refusals are the only thing standing between a fresh machine and a login
# screen that has never been tested, printed nothing and switched over anyway.
#
# ⚠️ ASKED OF THE SHELL, NOT OF A GREP. `declare -F` after sourcing the file in
# a subshell is the only answer that survives somebody moving the definitions
# into another file — which is exactly what the fix did.
printf '  %-40s ' "every helper it calls is defined"
missing=""
for fn in $(grep -oE '(^|[^[:alnum:]_])(die|warn|ok|step|section|read_list|dnf_install)[[:space:]]' bin/bhctl \
            | grep -oE '(die|warn|ok|step|section|read_list|dnf_install)' | sort -u); do
    # ⚠️ `--help` and nothing else: bhctl with no argument would run a real
    # command. It prints usage and exits before any of the case branches.
    bash -c '
        set +e
        . '"$(printf %q "$PWD/bin/bhctl")"' --help >/dev/null 2>&1
        declare -F '"$fn"' >/dev/null
    ' 2>/dev/null || missing+=" $fn"
done
if [[ -z "$missing" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mcalled but never defined:%s\033[0m\n' "$missing"
    printf '      bhctl runs without `set -e`, so each of these is a\n'
    printf '      `command not found` that the script then walks straight past.\n'
    fail=1
fi

exit $fail
