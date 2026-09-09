#!/usr/bin/env bash
#
# docs/KEYBINDS.md lists exactly the bindings that exist.
#
# ⚠️⚠️ A SHORTCUT LIST THAT DRIFTS IS WORSE THAN NO LIST, and that is not a
# style opinion. The list is the thing somebody opens when a key did not do what
# they expected — so a stale line sends them to look for a fault in the
# compositor, in the generator, or in their own memory, when the only thing
# wrong is the document. This project has already been bitten by a number
# written out in prose: "All sixty-three key bindings" stood on the Shortcuts
# page while there were seventy-four, in five places, true in none of them.
#
# So the document is GENERATED from shell/config/Binds.qml, and this check is
# what makes that claim keep meaning something: every chord in the source is in
# the document, every chord in the document is in the source, and the count the
# prose states is the count there actually is.
#
# ⚠️ IT COMPARES CHORDS, NOT LINES. A description can be reworded — that is
# prose and it is allowed to improve. What may not differ is the set of keys,
# because that is the part somebody reads the file for.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
fail=0
ok()  { printf '  %sok%s    %s\n' "$green" "$off" "$1"; }
bad() { printf '  %sFAIL%s  %s\n' "$red" "$off" "$1"; fail=1; }

doc=docs/KEYBINDS.md
src=shell/config/Binds.qml

[[ -f "$doc" ]] || { bad "$doc does not exist"; exit 1; }
[[ -f "$src" ]] || { bad "$src does not exist"; exit 1; }

# ⚠️ THE TEXT GOES INTO A VARIABLE FIRST — tests/pipefail-grep.sh's rule: a
# `grep -q` at the head of a pipe exits on its first match, the writer takes
# SIGPIPE, and under pipefail the whole pipeline reports failure.
src_text="$(cat "$src")"
doc_text="$(cat "$doc")"

# The chords, one per line, from each side.
from_src="$(grep -oE '^[[:space:]]*\{[[:space:]]*key:[[:space:]]*"[^"]*"' <<< "$src_text" \
            | sed -E 's/.*"(.*)"/\1/' | sort -u)"
from_doc="$(grep -oE '^\| `[^`]*`' <<< "$doc_text" \
            | sed -E 's/^\| `(.*)`/\1/' | sort -u)"

if [[ -z "$from_src" ]]; then
    bad "no bindings found in $src — the extraction is broken, not the document"
    exit 1
fi
if [[ -z "$from_doc" ]]; then
    bad "no bindings found in $doc — the extraction is broken, not the source"
    exit 1
fi

missing="$(comm -23 <(printf '%s\n' "$from_src") <(printf '%s\n' "$from_doc"))"
extra="$(comm -13 <(printf '%s\n' "$from_src") <(printf '%s\n' "$from_doc"))"

if [[ -n "$missing" ]]; then
    bad "bound but not documented:"
    sed 's/^/        /' <<< "$missing"
else
    ok "every binding is in the document"
fi

if [[ -n "$extra" ]]; then
    bad "documented but not bound — these keys do nothing:"
    sed 's/^/        /' <<< "$extra"
else
    ok "every documented chord is really bound"
fi

# ⚠️ AND THE NUMBER IN THE PROSE. This is the one that has actually gone wrong
# here, five times over, and it is one line to check.
want="$(grep -c . <<< "$from_src")"
if grep -qE "There are $want of them\." <<< "$doc_text"; then
    ok "the count in the prose is $want"
else
    said="$(grep -oE 'There are [0-9]+ of them' <<< "$doc_text" | head -1)"
    bad "the document says \"${said:-nothing}\" but there are $want"
fi

exit "$fail"
