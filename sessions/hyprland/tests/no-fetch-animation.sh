#!/usr/bin/env bash
#
# The terminal greeting is plain fastfetch, and nothing is left of the player.
#
# ⚠️ WHY A CHECK FOR SOMETHING THAT WAS REMOVED. He asked for a spinning Fedora
# logo on 10.08.2026 and asked for it back out the same day — "mach einfach ein  # english-ok: the request, quoted
# normales schönes fastfetch, nimm einfach ne pre config die passt". A removal   # english-ok: the request, quoted
# across seven files is exactly the shape that leaves one reference behind, and
# the one left behind is always the one that breaks: a zshrc calling a binary
# that is gone prints "command not found" on EVERY terminal, and a fastfetch
# config pointing at a logo file nobody writes prints an error on every prompt.
#
# ⚠️ A DELETION CANNOT BE PROVEN BY A MISSING FILE. `[[ ! -f bin/buchhwin-fetch ]]`
# passes on a tree where six files still call it. The provable half is the other
# one: nothing names it, and nothing writes what it used to read.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
ok()  { printf '  %sok%s    %s\n' "$green" "$off" "$1"; }
bad() { printf '  %sFAIL%s  %s\n' "$red" "$off" "$1"; fail=1; }

# ⚠️ COMMENTS DO NOT COUNT, and here that is not a nicety: five files carry a
# note saying the player USED to be called from them, which is the record of why
# they look the way they do. A scan that reads its own documentation as evidence
# is the trap this project sprang once already, grepping for an import that a
# comment mentioned in order to say it was absent.
naming="$(grep -rn 'buchhwin-fetch' bin lib shell dotfiles docs 2>/dev/null \
          | grep -v '^\([^:]*\):[0-9]*: *#' \
          | grep -v '^\([^:]*\):[0-9]*: *//' \
          | grep -v '^\([^:]*\):[0-9]*: *|' || true)"
if [[ -z "$naming" ]]; then
    ok "nothing calls the player any more"
else
    bad "the player is still called:"
    sed 's/^/        /' <<< "$naming"
fi

# The three files the renderer used to write. A config that still points at one
# of them is the failure that shows up on every prompt.
for artefact in "fetch/logo.txt" "fetch/frames.txt" "fetch/meta"; do
    hits="$(grep -rn "$artefact" shell bin lib 2>/dev/null \
            | grep -v '^\([^:]*\):[0-9]*: *//' || true)"
    if [[ -z "$hits" ]]; then
        ok "nothing writes or reads $artefact"
    else
        bad "$artefact is still referenced:"
        sed 's/^/        /' <<< "$hits"
    fi
done

# ⚠️ AND THE POSITIVE HALF, without which this file only proves an absence. The
# greeting still has to happen, and the config still has to be ours — a tree
# where somebody deleted the whole fastfetch target would pass every check
# above and greet nobody.
# ⚠️ THE OPENING BRACKET IS LOAD-BEARING. Without it the pattern was
# `function fetchConfig`, which also matches `function fetchConfigX` — so the
# red-proof for this line stayed GREEN when the function was renamed away. Found
# by running that proof rather than by reading, which is the whole argument for
# running it.
if grep -q "function fetchConfig(" shell/tools/render.qml; then
    ok "the fastfetch config is still generated"
else
    bad "shell/tools/render.qml no longer writes a fastfetch config at all"
fi
if grep -q '^\s*fastfetch$' dotfiles/zsh/zshrc; then
    ok "a new terminal still greets you"
else
    bad "dotfiles/zsh/zshrc no longer runs fastfetch"
fi
# The logo has to be fastfetch's own — `builtin`, not a file we stopped writing.
if grep -q 's("builtin")' shell/tools/render.qml; then
    ok "the logo is fastfetch's builtin one"
else
    bad "the generated config does not ask for the builtin logo"
fi

# ⚠️⚠️ B61 · THE TOP PADDING IS MEASURED, NEVER TYPED. His request was "mach das  # english-ok: the request, quoted
# so das das logo perfekt mit der letzten zeile abschließt", and the number that  # english-ok: the request, quoted
# does it is `textLines - logoLines` — both facts about the MACHINE, not about
# the logo. This project has written that logo height down five different ways
# (10, 19, 15, 16, 9), and two of those came from a measurement that read our own
# config and so added its own previous padding back in.
#
# A literal here is therefore right on at most one machine and silently wrong on
# every other, which is worse than the blemish: a typed 10 put the logo seven
# rows down on the lab VM. A machine without a battery prints one line fewer, and
# that case is the reason this cannot be a constant at all.
pad_line="$(grep -A1 's("padding")' shell/tools/render.qml | tr -d '\n')"
if grep -qE 's\("top"\) \+ ": " *\+ *[0-9]+' <<< "$pad_line"; then
    bad "the fastfetch logo padding is a typed number again — it is right on one machine at most"
elif grep -q 'fetchTextLines' <<< "$pad_line"; then
    ok "the fastfetch logo padding is computed from the measured rows"
else
    bad "the fastfetch logo padding no longer comes from the measurement"
fi

# And the measurement must not read the config it is about to rewrite.
if grep -q 'config none' shell/tools/render.qml && \
   grep -q 'logo-padding-top 0' shell/tools/render.qml; then
    ok "…and the measurement neutralises our own config and padding"
else
    bad "the logo measurement reads our own config — it would feed its padding back in"
fi

exit $fail
