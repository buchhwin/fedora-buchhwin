#!/usr/bin/env bash
# The generated compositor config parses, and a second run writes nothing.
#
# Replaces the config test of the previous compositor, whose generator was deleted.
#
# Three questions, in order of what they cost to get wrong:
#
#   1. Does the generator produce the two files at all? A generator that exits
#      0 having written nothing is the failure this suite exists for — it is
#      what "rebinding does nothing" looked like from the outside.
#   2. Is the result valid? `Hyprland --verify-config` is the compositor's own
#      answer, not ours. luac -p is the cheaper half and runs even where
#      Hyprland is not installed.
#   3. Does an unchanged config stay unchanged? Hyprland reloads on every write,
#      so a generator that rewrites byte-identical files reloads the compositor
#      on every palette change for nothing.
#
# exit 2 = a prerequisite is missing, which is not a failure.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null 2>&1 || { echo "quickshell not installed — skipping"; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

hypr_home="$tmp/buchhwin/hyprland"
mkdir -p "$hypr_home/buchhwin" "$hypr_home/generated"
cp config/hypr/hyprland.lua "$hypr_home/hyprland.lua"
cp config/hypr/buchhwin/*.lua "$hypr_home/buchhwin/"

fail=0
say() { printf '%s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }

run_generator() {
    BUCHHWIN_TOOL=hypr QT_QPA_PLATFORM=offscreen XDG_CONFIG_HOME="$tmp" \
        timeout 60 qs -p shell >/dev/null 2>&1
    return 0
}

# ---------------------------------------------------------------- first run

run_generator
log=/tmp/buchhwin-hypr.log

if grep -q 'ABORT' "$log" 2>/dev/null; then
    bad "the generator refused to write:"
    sed -n '/ABORT/,$p' "$log" >&2
fi

for f in generated/settings.lua generated/binds.lua; do
    if [[ -s "$hypr_home/$f" ]]; then
        say "ok: $f written"
    else
        bad "$f was not written"
    fi
done

# ------------------------------------------------------------- it is Lua

if command -v luac >/dev/null 2>&1; then
    for f in "$hypr_home"/generated/*.lua; do
        [[ -e "$f" ]] || continue
        if luac -p "$f" 2>/dev/null; then
            say "ok: $(basename "$f") is valid Lua"
        else
            bad "$(basename "$f") is not valid Lua:"
            luac -p "$f" >&2
        fi
    done
else
    say "note: luac not installed, skipping the syntax check"
fi

# ------------------------------------------- the compositor accepts the whole

if command -v Hyprland >/dev/null 2>&1; then
    if Hyprland --verify-config --config "$hypr_home/hyprland.lua" >/dev/null 2>&1; then
        say "ok: Hyprland accepts the generated config"
    else
        bad "Hyprland refused the generated config:"
        Hyprland --verify-config --config "$hypr_home/hyprland.lua" 2>&1 \
            | sed -n '/Config parsing result/,$p' >&2
    fi
else
    say "note: Hyprland not installed, skipping the config check"
fi

# ------------------------------------------------- the bindings actually exist
#
# A generated file that parses but binds nothing is exactly the state this
# whole exercise started from, so it gets its own question.

binds_written="$(grep -c '^hl.bind(' "$hypr_home/generated/binds.lua" 2>/dev/null || echo 0)"
if (( binds_written >= 40 )); then
    say "ok: $binds_written bindings generated"
else
    bad "only $binds_written bindings generated — the table has around 60 rows"
fi

for expected in 'SUPER + Return' 'SUPER + Q' 'SUPER + SHIFT + Q' 'XF86AudioRaiseVolume' 'SUPER + 1'; do
    if grep -qF "\"$expected\"" "$hypr_home/generated/binds.lua" 2>/dev/null; then
        say "ok: $expected is bound"
    else
        bad "$expected is not in the generated bindings"
    fi
done

# --------------------------------------------------------------- second run

run_generator
if grep -q 'done: 0 written' "$log" 2>/dev/null; then
    say "ok: a second run writes nothing"
else
    bad "the second run wrote something — an unchanged config must cost nothing"
    tail -5 "$log" >&2
fi

exit "$fail"
