#!/usr/bin/env bash
#
# `bhctl doctor` names a null section in shell.json — and stays quiet otherwise.
#
# ⚠️⚠️ THIS IS THE CHECK BEHIND HIS LONGEST-RUNNING REPORT. "manche switches      # english-ok: the report, quoted
# gehen nicht wie z.b. der dock switch … der schalter springt zurück", and       # english-ok: the report, quoted
# months later "die slider egal welcher macht nix". Both are one shape: a        # english-ok: the report, quoted
# `Config.set` that walks a dotted path, finds a section that is `null` in the
# file, and refuses — for EVERY row over that block at once, which is what "egal
# welcher" means.
#
# tests/switch-writes.sh drives all of the rows and none of them refuses, so the
# write path is not the fault and never was. What was missing is a way for the
# machine it happens on to SAY which block is broken.
#
# ⚠️ BOTH DIRECTIONS, AND THE SECOND ONE IS THE IMPORTANT ONE. A checker that
# only proves the warning appears would be happy with a doctor that warns about
# everything. An ABSENT section is not a fault — it means "use the default" and
# works perfectly. Only `null` breaks. Crying wolf over the healthy case would
# send the next round after twenty keys that are fine, which is exactly the kind
# of wrong measurement this project has paid for before.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

[[ -x bin/bhctl ]] || { echo "  bin/bhctl is missing"; exit 2; }

red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
fail=0

run_doctor() {   # $1 = json body
    # ⚠️ THE FIXTURE HAS TO SIT WHERE bhctl LOOKS, AND IT DID NOT.
    # bhctl derives its config root by APPENDING buchhwin-sessions/hyprland
    # unless XDG_CONFIG_HOME already ends in it — that is the session isolation
    # the whole profile is built on. A fixture one level short means doctor
    # reads a file that is not there and reports nothing, which reads as the
    # check having been removed rather than the path being wrong.
    local t; t="$(mktemp -d)"
    local root="$t/buchhwin-sessions/hyprland"
    mkdir -p "$root/buchhwin"
    printf '%s\n' "$1" > "$root/buchhwin/shell.json"
    XDG_CONFIG_HOME="$t" bash bin/bhctl doctor 2>/dev/null
    rm -rf "$t"
}

check() {        # $1 = label, $2 = json, $3 = expect-match, $4 = must/mustnot
    local out; out="$(run_doctor "$2")"
    printf '  %-46s ' "$1"
    if [[ "$4" == must ]]; then
        if grep -q "$3" <<< "$out"; then
            printf '%sok%s\n' "$green" "$off"
        else
            printf '%sFAIL%s  expected to see: %s\n' "$red" "$off" "$3"; fail=1
        fi
    else
        if grep -q "$3" <<< "$out"; then
            printf '%sFAIL%s  should NOT have said: %s\n' "$red" "$off" "$3"; fail=1
        else
            printf '%sok%s\n' "$green" "$off"
        fi
    fi
}

# The fault: a null block. Named, and named SPECIFICALLY — "something is wrong"
# would not tell him which switch to stop trusting.
check "a null section is reported"          '{"notch": null}'                'BROKEN' must
check "and the block is named"              '{"notch": null}'                'notch'  must
check "several nulls are all named"         '{"notch": null, "bar": null}'   'bar'    must

# The control. An absent block and a healthy one must both stay silent, or the
# warning means nothing.
check "a healthy file says no null"         '{"look": {"uiScale": 1.0}}'    'no null section' must
check "a healthy file does not cry BROKEN"  '{"look": {"uiScale": 1.0}}'    'BROKEN' mustnot
check "an empty file does not cry BROKEN"   '{}'                            'BROKEN' mustnot
# ⚠️ The word "null" inside a STRING is not a null section. Without this the
# check would be a substring search wearing a diagnosis.
check "the word null in a value is not one" '{"theme": {"palette": "null"}}' 'BROKEN' mustnot

# ⚠️ AND THE ADVICE HAS TO NAME SOMETHING THAT EXISTS. The first draft of the
# doctor section ended in `bhctl reset settings`, a verb this script does not
# have. A diagnosis that ends in an invented command sends the reader off to
# debug the tool instead of the fault.
printf '  %-46s ' "the advice names no invented bhctl verb"
doctor_null_notch="$(run_doctor '{"notch": null}')"
if grep -qE 'bhctl (reset|settings|fix)' <<< "$doctor_null_notch"; then
    printf '%sFAIL%s  it points at a verb bhctl does not have\n' "$red" "$off"; fail=1
else
    printf '%sok%s\n' "$green" "$off"
fi

exit $fail
