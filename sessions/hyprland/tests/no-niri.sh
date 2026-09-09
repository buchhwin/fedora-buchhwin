#!/usr/bin/env bash
#
# The compositor this profile replaced is not mentioned anywhere.
#
# ⚠️ THIS IS A TRIPWIRE, NOT A TIDINESS RULE, and the difference matters.
# The migration away from that compositor left ~470 mentions behind, and most of
# them were not cosmetic: tests drove a generator that had been deleted, the
# renderer wrote a colour file in a format nothing read, `Config.qml` named
# actions the new compositor does not have, and CI installed the old binary to
# run suites that could no longer pass. Every one of those looked fine in a
# grep for "does it compile" and was dead on a real machine.
#
# So the name is the marker. If it comes back, something was copied from the old
# tree — and whatever was copied is written against a compositor that is not
# installed here.
#
# ⚠️ WHAT IS ALLOWED, and it is nothing. There is no exemption list on purpose:
# the moment one exists, the next mention is added to it instead of being
# resolved. If a historical note genuinely needs to explain why something is the
# way it is, it can say "the previous compositor" and lose nothing.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

printf '  %-42s ' "no trace of the previous compositor"

# ⚠️ THE PATTERN IS BUILT FROM PIECES, AND THE CHECK EXCLUDES ITSELF.
# Written out as a literal it matches this file and the CI step that calls it,
# so the tripwire fails on its own existence — which it did, first run.
needle="ni""ri"

# --exclude-dir on .git; everything else in the tree is fair game, including the
# wallpapers' filenames, the tests and the generated-file paths. This file and
# the workflow that names it are the only exceptions, and only because they
# have to say the word in order to look for it.
hits="$(grep -rIni "$needle" . --exclude-dir=.git         --exclude=no-"$needle".sh --exclude=ci.yml 2>/dev/null || true)"

if [[ -z "$hits" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
    exit 0
fi

printf '\033[38;5;203m%s found\033[0m\n' "$(grep -c . <<< "$hits")"
head -20 <<< "$hits" | sed 's/^/      /'
cat <<'WHY'

  Each of these is one of three things, and all three are worth fixing:

    a path or command that no longer exists   the file it names was deleted
    an action or key name                     the new compositor does not have it
    a note explaining a past decision         say "the previous compositor"

  The first two are broken code that greps clean. That is why this check is a
  hard failure rather than a warning.
WHY
exit 1
