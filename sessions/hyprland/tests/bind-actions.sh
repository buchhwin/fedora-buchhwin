#!/usr/bin/env bash
#
# Every keybinding names an action the generator can actually emit.
#
# ⚠️ THE OTHER HALF OF A BINDING THAT DOES NOTHING. tools/smoke.qml checks the
# IPC side — that `ipc call notch media` names a verb that exists — and it has
# caught a real one: a bar button pointing at a function whose target had been
# deleted. But most bindings are not IPC calls. They are compositor actions, and
# nothing checked those.
#
# ⚠️ IT ASKS THE GENERATOR, NOT THE COMPOSITOR, AND THAT IS THE CHANGE.
# The previous version ran the compositor's own `msg action --help` and compared
# against that. Two problems: it needed the compositor installed, so CI skipped
# it on every runner without one; and it validated against the wrong vocabulary.
# config/Binds.qml does not name Hyprland dispatchers — it names actions from a
# table in tools/hypr/EmitBinds.qml, which translates them. An action missing
# from THAT table is dropped with a warning and the key is dead, and no amount
# of asking Hyprland would have found it.
#
# So this reads both files and compares them. No compositor, no session, no
# skip — it runs anywhere the repository does.
#
# ⚠️ WHAT IT CANNOT DO, said plainly so nobody trusts it further than it goes:
# it proves the action is TRANSLATABLE, not that pressing the key changes
# anything on screen. Whether the dispatcher behind it does the right thing is
# what `Hyprland --verify-config` (tests/hypr-config.sh) and a human answer.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

binds=shell/config/Binds.qml
emitter=shell/tools/hypr/EmitBinds.qml
fallback=config/hypr/buchhwin/binds.lua

for f in "$binds" "$emitter" "$fallback"; do
    [[ -f "$f" ]] || { echo "  missing $f — cannot test"; exit 2; }
done

fail=0

# ------------------------------------------- 1. every action can be translated

printf '  %-42s ' "every bind action is in the generator"

known="$(grep -oE '^ *"[a-z][a-z0-9-]*": *function' "$emitter" \
         | sed 's/[^"]*"//;s/".*//' | sort -u)"
[[ -n "$known" ]] || { echo "found no actions in $emitter"; exit 2; }

ours="$(grep -oE 'action: "[a-z][a-z0-9-]*"' "$binds" \
        | sed 's/action: "//;s/"//' | sort -u)"
[[ -n "$ours" ]] || { echo "found no bindings in $binds"; exit 2; }

unknown="$(comm -23 <(printf '%s\n' "$ours") <(printf '%s\n' "$known"))"

if [[ -z "$unknown" ]]; then
    printf '\033[38;5;114mok\033[0m  %s used, %s available\n' \
           "$(wc -l <<< "$ours")" "$(wc -l <<< "$known")"
else
    printf '\033[38;5;203mfound\033[0m\n'
    while read -r a; do
        [[ -z "$a" ]] && continue
        printf '      %s\n' "$a"
        grep -n "action: \"$a\"" "$binds" | head -3 | sed 's/^/        /'
    done <<< "$unknown"
    cat <<'WHY'

  The generator has no case for these, so it drops the binding, writes a line
  into /tmp/buchhwin-hypr.log and carries on. Hyprland never sees the key at
  all, which means --verify-config still passes and nothing anywhere says the
  key is dead.

  Either add the action to the table in tools/hypr/EmitBinds.qml, or use one
  that is already there.
WHY
    fail=1
fi

# ------------------------------- 2. the shipped fallback covers the same keys
#
# ⚠️ TWO HAND-WRITTEN COPIES OF ONE TABLE, and this is what keeps them honest.
# config/hypr/buchhwin/binds.lua exists for the case where the generator has
# never run — a fresh install, or one where it refused. If it drifts from
# Binds.qml, the keys change the first time the generator succeeds, which reads
# as the desktop rebinding itself for no reason.

printf '  %-42s ' "the shipped fallback has the same keys"

qml_keys="$(grep -oE 'key: "[^"]+"' "$binds" | sed 's/key: "//;s/"$//' | sort -u)"
lua_keys="$(grep -oE '(hl\.bind|exec)\((mod \.\. )?"[^"]+"' "$fallback" \
            | sed 's/.*"//;s/"$//' | sort -u)"
lua_raw="$(grep -oE '"[^"]+"' "$fallback" | tr -d '"' | sort -u)"

# The workspace keys are built by a loop in both files rather than typed out, so
# they are in neither list and must not be compared.
missing=""
while read -r k; do
    [[ -z "$k" ]] && continue
    case "$k" in
        "SUPER + "[0-9]|"SUPER + SHIFT + "[0-9]) continue ;;
    esac
    # The Lua file writes `mod .. " + Return"`, so the shipped key is the
    # SUFFIX. Matching on that is what makes the two comparable at all.
    suffix="${k#SUPER}"
    if ! grep -qF "$suffix" <<< "$lua_raw" && ! grep -qxF "$k" <<< "$lua_keys"; then
        missing+="$k"$'\n'
    fi
done <<< "$qml_keys"

if [[ -z "${missing//[$'\n' ]/}" ]]; then
    printf '\033[38;5;114mok\033[0m  %s keys\n' "$(grep -c . <<< "$qml_keys")"
else
    printf '\033[38;5;203mdrifted\033[0m\n'
    printf '      in %s but not in %s:\n' "$binds" "$fallback"
    printf '%s' "$missing" | sed 's/^/        /'
    fail=1
fi

exit "$fail"
