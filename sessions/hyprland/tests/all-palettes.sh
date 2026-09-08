#!/usr/bin/env bash
#
# Every palette must resolve to a complete token set.
#
# This is the regression net for the whole theming idea: eleven palettes, one
# renderer, no conditionals anywhere. A palette that is missing a key, or whose
# accent does not exist in its own colour list, has to fail here — not on
# somebody's screen as an unreadable panel.
#
# It runs the REAL shell headless, so it exercises the same import graph, the
# same singletons and the same asynchronous palette load as the desktop does.
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }
command -v jq >/dev/null || { echo "jq not installed"; exit 2; }

fail=0
for p in shell/theme/palettes/*.json; do
    name="$(basename "$p" .json)"
    printf '  %-18s ' "$name"

    # A palette is chosen through the same config the desktop reads, so this
    # also proves the config path works from a clean machine.
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/buchhwin"
    # Each palette's OWN first accent, not a value that happens to exist
    # everywhere. An earlier version fell back to "green" whenever extraction
    # failed, so all eleven "passed" while testing the same colour eleven times.
    accent="$(jq -r '.accents[0]' "$p")"
    [[ -n "$accent" && "$accent" != "null" ]] || { printf '\033[38;5;203mno accents[]\033[0m\n'; fail=1; rm -rf "$tmp"; continue; }
    printf '{"theme":{"palette":"%s","accent":"%s"}}\n' "$name" "$accent" \
        > "$tmp/buchhwin/shell.json"

    rm -f /tmp/buchhwin-tokens.txt
    XDG_CONFIG_HOME="$tmp" BUCHHWIN_TOOL=dump-tokens QT_QPA_PLATFORM=offscreen \
        timeout 30 qs -p shell >/dev/null 2>&1

    if [[ ! -f /tmp/buchhwin-tokens.txt ]]; then
        printf '\033[38;5;203mno output\033[0m\n'; fail=1; rm -rf "$tmp"; continue
    fi
    if grep -q '^  FAIL:' /tmp/buchhwin-tokens.txt; then
        printf '\033[38;5;203m%s\033[0m\n' "$(grep '^  FAIL:' /tmp/buchhwin-tokens.txt)"
        fail=1; rm -rf "$tmp"; continue
    fi
    # An unresolved colour renders as the magenta sentinel; catching it here is
    # the difference between a failing test and a desktop with a pink panel.
    if grep -qi '#ff00ff' /tmp/buchhwin-tokens.txt; then
        printf '\033[38;5;203munresolved colour (magenta sentinel)\033[0m\n'
        fail=1; rm -rf "$tmp"; continue
    fi
    printf '\033[38;5;114mok\033[0m  accent=%s\n' "$accent"
    rm -rf "$tmp"
done

exit $fail
