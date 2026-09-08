#!/usr/bin/env bash
#
# Every keybinding calls an action niri actually has.
#
# ⚠️ THE OTHER HALF OF A BINDING THAT DOES NOTHING. tools/smoke.qml already
# checks the IPC side — that `ipc call notch media` names a verb that exists —
# and it found a real one this week: the gear on the bar pointed at a function
# whose target had been deleted. But the majority of bindings are not IPC calls
# at all. They are niri's own actions, and nothing checked those.
#
# A name niri does not know is not an error anybody sees. niri drops the binding
# while loading the config, `niri validate` still says "config is valid" for the
# rest of the file, and the key is simply dead. That is the exact shape of the
# Super+F report — the key was bound, the action existed, and it did nothing
# visible — and while the cause there turned out to be different, chasing it
# proved there was no check standing between a typo and a silent dead key.
#
# ⚠️ WHAT THIS CANNOT DO, said plainly, so nobody trusts it further than it goes:
# it proves the action EXISTS, not that pressing the key changes anything.
# `toggle-windowed-fullscreen` is a real action that moved 40 pixels. Only a
# human or a screenshot pair can answer that, and the handover says so.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v niri >/dev/null || { echo "niri not installed"; exit 2; }

file=shell/config/Config.qml
printf '  %-34s ' "every bind action exists in niri"

# niri's own list, asked rather than remembered — it changes between releases and
# a copy here would be one more thing to keep in step.
known="$(niri msg action --help 2>&1 | grep -oE "^  [a-z][a-z0-9-]+" | tr -d ' ' | sort -u)"
[[ -n "$known" ]] || { echo "could not read niri's action list"; exit 2; }

# `spawn` and `spawn-sh` are ours to resolve, not niri's to name; both appear in
# the list above anyway, so nothing special is needed for them.
ours="$(grep -oE 'action: "[a-z][a-z0-9-]*"' "$file" | sed 's/action: "//;s/"//' | sort -u)"
[[ -n "$ours" ]] || { echo "found no bindings in $file"; exit 2; }

unknown="$(comm -23 <(printf '%s\n' "$ours") <(printf '%s\n' "$known"))"

if [[ -z "$unknown" ]]; then
    printf '\033[38;5;114mok\033[0m  %s actions, niri knows %s\n' \
           "$(wc -l <<< "$ours")" "$(wc -l <<< "$known")"
    exit 0
fi

printf '\033[38;5;203mfound\033[0m\n'
while read -r a; do
    [[ -z "$a" ]] && continue
    printf '      %s\n' "$a"
    grep -n "action: \"$a\"" "$file" | head -3 | sed 's/^/        /'
done <<< "$unknown"
cat <<'WHY'

  niri has no such action. It will drop the binding while loading the config and
  say nothing — `niri validate` still calls the file valid, because the rest of
  it is — so the key is simply dead and there is no message to search for.

  Check the spelling against `niri msg action --help`. Action names do change
  between niri releases, so a binding that worked before an update can end up
  here; that is the case this check exists for.
WHY
exit 1
