#!/usr/bin/env bash
#
# The dry run says what the installer does, and nothing else.
#
# ⚠️⚠️ THIS IS THE ONE DOCUMENT SOMEBODY READS BEFORE DECIDING TO TRUST THE
# INSTALLER, and on 09.09.2026 five of its ten lines were untrue. It promised
# edits to /etc/dnf/dnf.conf, a dnf5 alias file, two polkit rules, a helper in
# /usr/libexec and a logind drop-in — every one of them removed when the profile
# was cut back — and it claimed to change the login shell and move ~/.zshrc
# aside, which it stopped doing at the same time. It also failed to mention two
# things it really does: enabling SDDM and rewriting package install reasons.
#
# It overstated rather than understated, which is the safe direction to be wrong
# in. It is still a document that lies, in the place where being trusted is the
# entire point — and nothing in the suite could see it, because a `printf` of a
# string is valid shell whatever the string says.
#
# ⚠️ SO IT IS CHECKED IN BOTH DIRECTIONS, the same shape as tests/setting-rows.sh
# and for the same reason: a list that only has to be a subset rots into a set of
# excuses. Every path the plan names must be written by the code, and every path
# the code writes outside $HOME must be named by the plan.
#
# ⚠️ EXECUTABLE LINES ONLY. This repository explains removals in comments on
# purpose — "THIS PHASE USED TO EDIT /etc/dnf/dnf.conf" is a warning worth
# keeping — and a checker that greps the comments finds every path that was ever
# written and reports the plan as correct. That mistake was made while writing
# this file, which is why the note is here.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
fail=0
ok()  { printf '  %sok%s    %s\n' "$green" "$off" "$1"; }
bad() { printf '  %sFAIL%s  %s\n' "$red" "$off" "$1"; fail=1; }

# ⚠️ THE TEXT GOES INTO A VARIABLE FIRST — tests/pipefail-grep.sh's rule.
plan="$(sed -n '/section "Files outside your home directory"/,/section "System settings/p' \
        lib/common.sh)"
[[ -n "$plan" ]] || { bad "the plan's file section could not be read — did it get renamed?"; exit 1; }

# The absolute paths the plan promises, one per line.
promised="$(grep -oE '"/(usr|etc|opt|var)[^" ]*' <<< "$plan" | tr -d '"' | sort -u)"
[[ -n "$promised" ]] || { bad "the plan names no paths at all"; exit 1; }

# What the installer really writes: executable lines only, `sudo` writes only.
#
# ⚠️ LINE CONTINUATIONS ARE JOINED FIRST, and leaving that out is how this
# check first reported the two paths that ARE written as missing. A long
# `sudo install -m 0755 "$REPO_DIR/bin/..."` puts its destination on the NEXT
# line, which is where a destination usually goes when the command is long —
# so a per-line regex sees the `sudo install` and none of the paths.
#
# ⚠️⚠️ bin/bhctl IS IN THE CORPUS BECAUSE THE INSTALLER RUNS IT. This check was
# written with the corpus lib/*.sh plus install-hyprland.sh, and passed with
# four green lines over a plan that had just LOST a file: phase 70 calls
# `bin/bhctl power apply`, bhctl's `sudo tee` writes the logind drop-in, and the
# paragraph explaining its removal from the plan said the file is written "when
# you ask for it, not by the installer". The installer asks for it, every run.
#
# So the rule is not "which files are named lib/" but WHAT THE INSTALLER
# CAUSES. One indirection was enough to hide a write from a checker whose whole
# job is to find writes. If a phase ever runs another helper that writes outside
# $HOME, it belongs here too — and the second direction below will say so,
# loudly, the first time it does.
code="$(grep -rhvE '^[[:space:]]*#' lib/*.sh install-hyprland.sh bin/bhctl 2>/dev/null \
        | sed -e ':a' -e '/\\$/N; s/\\\n//; ta')"
written="$(grep -oE 'sudo (install|tee|mkdir|cp|ln)[^|;&]*' <<< "$code" \
           | grep -oE '/(usr|etc|opt|var)[^ "]*' | sort -u)"

# ── 1 · nothing is promised that is not written ─────────────────────────────
stale=""
while read -r p; do
    [[ -n "$p" ]] || continue
    # A promised path counts as written if any real write mentions it, or is
    # inside a directory it names.
    if ! grep -qF "$p" <<< "$written"; then
        stale+="$p"$'\n'
    fi
done <<< "$promised"

if [[ -n "$stale" ]]; then
    bad "the plan promises paths the installer does not write:"
    sed 's/^/        /' <<< "${stale%$'\n'}"
    printf '        %s\n' "Each of these is a line somebody reads and believes."
else
    ok "every path the plan names is really written"
fi

# ── 2 · nothing is written that is not promised ─────────────────────────────
#
# ⚠️ THE DIRECTION THAT CATCHES THE NEXT ONE. A path added to an installer phase
# and not to the plan is a change the reader was never told about, which is the
# worse half of the two.
unlisted=""
while read -r w; do
    [[ -n "$w" ]] || continue
    if ! grep -qF "$w" <<< "$promised"; then
        unlisted+="$w"$'\n'
    fi
done <<< "$written"

if [[ -n "$unlisted" ]]; then
    bad "the installer writes paths the plan does not mention:"
    sed 's/^/        /' <<< "${unlisted%$'\n'}"
else
    ok "every path the installer writes is in the plan"
fi

# ── 3 · the two claims about your account that were wrong ───────────────────
#
# These are not paths, so the comparison above cannot see them. They are checked
# by name because they are the two that were untrue: the installer suggests
# `chsh` in a printed line and never runs it, and it writes its zshrc into its
# OWN ZDOTDIR rather than moving yours aside.
if grep -qE '^[^#]*\bchsh -s' <<< "$code" \
   && ! grep -qE '^[^#]*(step|printf|echo).*chsh -s' <<< "$code"; then
    bad "something calls chsh for real — the plan says it only suggests it"
else
    ok "chsh is suggested, never run"
fi

if grep -qE '^[^#]*mv .*\$HOME/\.zshrc"? ' <<< "$code"; then
    bad "the installer moves ~/.zshrc — the plan says it leaves it alone"
else
    ok "~/.zshrc is left where it is"
fi

# ── 4 · the two HELP TEXTS say the same number as the plan ──────────────────
#
# ⚠️⚠️ THE HEADER OF A SCRIPT IS NOT A COMMENT WHEN `--help` PRINTS IT. Both
# scripts print their header block with `sed`, and both headers carried the same
# sentence the plan did — "changes the login shell, moves ~/.zshrc aside, edits
# /etc/dnf/dnf.conf" — for a month after none of it was true. Fixing the plan
# and leaving those two is fixing the copy nobody reads.
#
# ⚠️ THE COUNT IS WHAT IS CHECKED, not the wording. A test that greps for the
# exact stale sentence only ever catches the mistake that was already made. The
# headers claim a NUMBER of files outside $HOME, the plan lists them, and the
# next file added to one and not the other moves them apart. Wording is for a
# reader; the number is the part a machine can hold to account.
words=(zero one two three four five six seven eight nine ten)
n_promised="$(grep -c . <<< "$promised")"
expected="${words[$n_promised]:-$n_promised}"

for script in install-hyprland.sh uninstall.sh; do
    # The header block: every comment line after the first, which is exactly
    # what `--help` prints. Read here the same way the script reads it.
    #
    # ⚠️ THE COMMENT MARKERS COME OFF AND THE LINES ARE JOINED, because the
    # sentence is WRAPPED. "writes four files outside your home\n# directory" is
    # one claim to a reader and two lines to grep, and the first run of this
    # check reported a help text that says nothing — about a help text that says
    # it plainly. A check that reads prose has to read it the way it is written.
    header="$(sed -n '2,${/^#/!q;p;}' "$script" | sed 's/^#[[:space:]]\?//' | tr '\n' ' ' | tr -s ' ')"
    claim="$(grep -oE '(zero|one|two|three|four|five|six|seven|eight|nine|ten) files outside your home directory' <<< "$header" | head -1)"

    if [[ -z "$claim" ]]; then
        bad "$script --help no longer says how many files it writes outside \$HOME"
        printf '        %s\n' "The plan lists $n_promised. A help text that stops saying is not an improvement."
    elif [[ "$claim" != "$expected files outside your home directory" ]]; then
        bad "$script --help says \"$claim\", the plan lists $n_promised"
    else
        ok "$script --help agrees with the plan: $expected files"
    fi
done

# ── 5 · the system changes the plan names are really made ───────────────────
#
# Not paths, so section 1 cannot see them — and they are the two the plan did
# not mention at all until 09.09.2026. Named here so that removing either from
# the code is a failing test rather than a quiet over-promise.
while IFS='|' read -r what pattern; do
    if grep -qE "$pattern" <<< "$code"; then
        ok "the plan's \"$what\" really happens"
    else
        bad "the plan announces \"$what\" and nothing in the code does it"
    fi
done <<'CHANGES'
systemctl enable sddm|systemctl enable sddm
dnf mark user|dnf mark user
CHANGES

exit "$fail"
