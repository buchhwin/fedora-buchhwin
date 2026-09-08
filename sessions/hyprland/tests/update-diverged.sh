#!/usr/bin/env bash
#
# A clone that shares no history with origin gets told what to do about it.
#
# ⚠️ THE FAULT THIS EXISTS FOR, and it happened on a real machine. This
# repository's history was rewritten with `git-filter-repo` to get a leaked
# password out of it, which gave every commit a new hash. A clone taken before
# that run has no common ancestor with origin any more, and `git pull --ff-only`
# is precisely the form that refuses two unrelated histories:
#
#     hint: Diverging branches can't be fast-forwarded
#     fatal: Not possible to fast-forward, aborting.
#
# `bhctl update` turned all of that into two words — "pull failed" — and the
# person in front of it had no way to know their clone was the problem or that
# four lines fix it without losing anything.
#
# ⚠️ THE CONTROLS ARE THE POINT OF THIS FILE, not the happy case. Advice that
# says "throw your side away and take origin's" is dangerous when it is wrong,
# so two trees that must NOT see it are checked as well: one that is simply
# current, and one that has a local commit on top. The second is the sharp one —
# it is genuinely diverged and `--ff-only` genuinely refuses it, so a check
# written against "did the pull fail" instead of "is there a merge base" would
# tell somebody to `git reset --hard` over work they still have.
#
# ⚠️ NOTHING HERE CAN REACH THE INSTALLER. `bhctl update` ends in
# `exec bash install.sh`, and it gets there only when a pull moved HEAD. All
# three trees below are arranged so it never does: two fail before the pull or
# at it, and the third is already current, which returns before the exec.
#
# Reads and runs bhctl against throwaway trees. Needs git and nothing else, so
# it runs in CI and on a machine with no desktop.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v git >/dev/null || { echo "git not installed"; exit 2; }

tmp="$(mktemp -d)" || { echo "  could not make a temporary directory"; exit 2; }
[[ -n "$tmp" && "$tmp" == /tmp/* ]] || { echo "  refusing to run against $tmp"; exit 2; }
trap 'rm -rf "$tmp"' EXIT

fails=0
ok()   { printf '  \033[38;5;114mok\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[38;5;203mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }
note() { printf '       %s\n' "$1"; }

# git refuses to commit without one, and a machine running CI has neither.
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# ⚠️ A COPY OF bhctl, NEVER A SYMLINK. bhctl resolves its own REPO_DIR with
# `readlink -f`, so a link would point every one of these trees back at this
# checkout — the test would then run against the real repository, and the
# "no common history" case could never arise.
maketree() { # maketree <dir>
    mkdir -p "$1/bin" "$1/lib"
    cp -a bin/bhctl "$1/bin/bhctl"
    cp -a lib/common.sh "$1/lib/common.sh"
}

# One commit, so there is something to share or not share.
seed() { # seed <dir> <text>
    ( cd "$1" && git init -q -b main . \
        && printf '%s\n' "$2" > README.md \
        && git add -A && git commit -qm "$2" )
}

# ── the origin every tree points at ─────────────────────────────────────────
mkdir -p "$tmp/origin"
maketree "$tmp/origin"
seed "$tmp/origin" "origin" || { echo "  could not build the origin tree"; exit 2; }
( cd "$tmp/origin" && git commit -q --allow-empty -m "one more" ) || exit 2

# ── 1 · the rewritten-history clone ─────────────────────────────────────────
#
# Built rather than cloned: its commit was made independently, so it has a
# different hash and no ancestor in common with origin. That is exactly the
# state `git-filter-repo` leaves an old clone in.
maketree "$tmp/rewritten"
seed "$tmp/rewritten" "an older life" || exit 2
(
    cd "$tmp/rewritten" || exit 2
    git remote add origin "$tmp/origin"
    git fetch -q origin
    git branch --set-upstream-to=origin/main main -q 2>/dev/null
) || exit 2

out="$("$tmp/rewritten/bin/bhctl" update 2>&1)"
code=$?

if (( code == 0 )); then
    bad "rewritten: bhctl update reported success on an unrelated history"
elif grep -q "share no common history" <<< "$out"; then
    ok "rewritten: it says the histories are unrelated"
else
    bad "rewritten: it does not name the fault"
    note "$(head -3 <<< "$out")"
fi

# The advice has to be actionable, not sympathetic. Both halves: look before
# you throw anything away, then how to throw it away.
if grep -q "git reset --hard" <<< "$out" && grep -q "git log --oneline" <<< "$out"; then
    ok "rewritten: it names the way out, and the check before it"
else
    bad "rewritten: the way out is not printed"
    note "$(head -6 <<< "$out")"
fi

# ── 2 · control: a clone that is simply current ─────────────────────────────
#
# It has a merge base and nothing to pull. If the recipe above fires here, it
# fires on a healthy machine.
# ⚠️ NO `maketree` AFTER A CLONE. origin already carries both files under
# version control, so the clone has them tracked and clean — copying them in
# again would leave two untracked files, and `bhctl update` refuses a dirty
# tree before it ever reaches the question this file is about.
git clone -q "$tmp/origin" "$tmp/current" || exit 2

out="$("$tmp/current/bin/bhctl" update 2>&1)"
code=$?

if grep -q "share no common history" <<< "$out"; then
    bad "current: a healthy clone was told to reset --hard"
    note "$(head -3 <<< "$out")"
elif (( code == 0 )); then
    ok "current: a healthy clone is left alone"
else
    bad "current: exit $code on a clone that is up to date"
    note "$(head -3 <<< "$out")"
fi

# ── 3 · control: local commits, genuinely diverged, but NOT rewritten ───────
#
# ⚠️ THE ONE THAT SEPARATES THE TWO DIAGNOSES. `--ff-only` refuses this tree
# too, so "the pull failed" is true here — and the advice must still stay
# silent, because `git reset --hard` would delete the commit below.
git clone -q "$tmp/origin" "$tmp/ahead" || exit 2
(
    cd "$tmp/ahead" || exit 2
    git commit -q --allow-empty -m "work of my own"
    # origin moves on as well, so the two sides really are divergent rather
    # than one simply being ahead.
    ( cd "$tmp/origin" && git commit -q --allow-empty -m "origin moves on" )
) || exit 2

out="$("$tmp/ahead/bin/bhctl" update 2>&1)"

if grep -q "share no common history" <<< "$out"; then
    bad "ahead: a clone with its own commits was told to reset --hard"
    note "$(head -3 <<< "$out")"
else
    ok "ahead: local commits are not mistaken for a rewritten history"
fi

(( fails == 0 )) || exit 1
exit 0
