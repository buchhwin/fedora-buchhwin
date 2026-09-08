#!/usr/bin/env bash
#
# No checker may end a pipeline in `grep -q` while `pipefail` is on.
#
# ⚠️⚠️ THE FAULT THIS EXISTS FOR IS SILENT, AND IT ATE THE ONE FILE THAT
# MATTERED. `grep -q` exits at the FIRST match. Whatever is writing into it —
# `sed`, `awk`, `printf`, another `grep` — is then killed with SIGPIPE, and
# `set -o pipefail` hands the whole pipeline that non-zero status. So this:
#
#     sed 's://.*::' "$f" | grep -q 'Toggle {' && files+=("$f")
#
# fails EXACTLY WHEN THE MATCH IS FOUND EARLY IN A LONG FILE, and succeeds on
# short ones. tests/switch-one-writer.sh selected its files that way:
# OutputRow.qml is 200 lines and came through, SettingRow.qml is a thousand and
# vanished — and SettingRow.qml is the file the bug had been found in. The
# checker printed a clean, complete-looking report with its subject missing.
#
# ⚠️ IT FAILS IN THE DIRECTION NOBODY LOOKS. A checker that reports nothing
# reads as "everything is fine". Only the missing LINE in the output gave it
# away, and only because somebody happened to know how many there should be.
#
# ⚠️ AND IT IS NOT ALWAYS SILENT, WHICH IS WHY THE RULE IS BLANKET RATHER THAN
# CASE-BY-CASE. In `… | grep -q X || bad=1` the same accident produces a FALSE
# FAILURE instead — loud, but pointing at working code. Neither is acceptable,
# and deciding which one a given line would produce is exactly the reasoning
# that gets skipped when somebody is in a hurry.
#
# **The fix is one line either way:** put the text in a variable first and use a
# here-string, which has no upstream process to kill.
#
#     text="$(sed 's://.*::' "$f")"
#     grep -q 'Toggle {' <<< "$text" && files+=("$f")
#
# ⚠️ `grep -q FILE` IS FINE — there is no pipe and nothing to signal. Only a
# pipeline is refused.
#
# Static. No quickshell, no session, runs in CI.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
ok()  { printf '  %-46s \033[38;5;114mok\033[0m  %s\n' "$1" "${2:-}"; }
bad() { printf '  %-46s \033[38;5;203mFAIL\033[0m %s\n' "$1" "${2:-}"; fail=1; }

# ⚠️ THE CORPUS IS EVERY SHELL FILE THIS PROJECT SHIPS, not just tests/. `bhctl`
# runs on his machine and carries the same shape; a checker that only guards the
# checkers is half a checker.
#
# ⚠️ `--others --exclude-standard` IS NOT OPTIONAL, and the reason is written in
# tests/tap-targets.sh: plain `git ls-files` lists TRACKED files only, so a
# brand-new file — the most likely place for a mistake — is silently left out.
mapfile -t files < <(git ls-files --cached --others --exclude-standard \
                         'tests/*.sh' 'lib/*.sh' 'bin/*' 'install.sh' 2>/dev/null)
if (( ${#files[@]} == 0 )); then
    mapfile -t files < <(find tests lib bin -type f \( -name '*.sh' -o -name 'bhctl' \) 2>/dev/null)
fi
[[ ${#files[@]} -gt 0 ]] || { echo "  found no shell files to check"; exit 2; }

hits=0
for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue

    # ⚠️⚠️ COMMENTS STRIPPED FIRST, AND THIS FILE IS THE PROOF OF WHY. Every
    # place that documents the trap has to SPELL IT OUT to be any use — this
    # header does it four times, and so do the two files that were fixed. A
    # checker that matched raw text would fail on its own explanation, and the
    # obvious "fix" would be to stop explaining.
    #
    # A `#` inside a string is not a comment, but no line in this project puts a
    # pipeline inside a quoted `#` — and the alternative is a shell parser.
    # ⚠️ BOTH SHAPES. The first version stripped only `<space>#…`, so a comment
    # starting at column 0 stayed — and this file's own examples, which have to
    # spell the bad pipeline out to be any use, were reported as faults in it.
    code="$(sed -e 's/^[[:space:]]*#.*$//' -e 's/[[:space:]]#.*$//' "$f")"

    # `… | grep -q`, in any of its spellings: -q, -qE, -Eq, -qxF, -qi.
    #
    # ⚠️⚠️ THE `[^|]` IS NOT DECORATION — WITHOUT IT THIS CHECKER INVENTS WORK.
    # The first pattern was a bare `\|`, and `||` contains one: it reported
    # `if [[ ! -f "$probe" ]] || grep -q PATTERN "$probe"` as a faulty pipeline.
    # That line has no pipe at all — it is an OR followed by a plain file grep,
    # which is entirely safe. A checker that reads the wrong shape sends
    # somebody to "fix" working code, which is worse than one that misses
    # something; the same lesson tests/popup-close.sh learned twice in one day.
    found="$(grep -nE '(^|[^|])\|[[:space:]]*grep[[:space:]]+-[A-Za-z]*q' <<< "$code")"
    if [[ -n "$found" ]]; then
        while IFS= read -r line; do
            bad "$f:${line%%:*}" "pipeline into grep -q — SIGPIPE under pipefail"
            hits=$((hits + 1))
        done <<< "$found"
    fi
done

if (( hits == 0 )); then
    ok "no pipeline ends in grep -q" "${#files[@]} files"
else
    printf '\n  Put the text in a variable and use a here-string:\n'
    printf '      text="$(sed … "$f")"\n'
    printf '      grep -q PATTERN <<< "$text"\n'
fi

exit $fail
