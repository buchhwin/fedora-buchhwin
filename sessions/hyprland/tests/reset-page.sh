#!/usr/bin/env bash
#
# "Reset this page" — does it remove exactly that page's settings?
#
# Two halves, and only together are they a check:
#
#   1. STRUCTURAL. The reset gathers dotted paths by walking the page and
#      reading the `key:` off every row. Two places in this window write
#      settings WITHOUT being a row — the Displays page (`outputs`) and
#      BindsList (`binds`, `rebinds`) — and they are the same two that are named
#      exemptions in tests/setting-rows.sh. They declare what they own in
#      `resetKeys`. A third one added later would be invisible: the button would
#      reset its page, leave those keys standing, and report success.
#      So every literal-path `Config.set("…")` in this window has to be named in
#      its own file's `resetKeys`.
#
#      ⚠️⚠️ AND THE WRITE CAN NOW BE ONE STEP AWAY, which is how this check went
#      briefly blind and is the reason for its third part. `outputs` used to be
#      written by `Config.set("outputs", …)` inside settings/OutputScales.qml,
#      where the grep below could see it. It is written through
#      config/Outputs.qml now — a helper OUTSIDE shell/ui/settings/ — so the
#      literal never appears in this window at all and part 1 has nothing to
#      match. A page could write every monitor setting there is, declare no
#      resetKeys, and this file would still print nothing but green.
#
#      The indirection is right — four controls sharing one writer beats four
#      copies of the same loop — so the check follows it rather than forbidding
#      it: a page that CALLS the helper must declare what the helper writes.
#
#   2. FUNCTIONAL. shell/tools/reset-page-check.qml drives Backup.resetPaths
#      against a throwaway settings file and asserts, for every case, both what
#      went and what STAYED. A reset that reaches too far looks identical on
#      screen to one that does not.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
ok()   { printf '  %sok%s   %s\n'   "$green" "$off" "$1"; }
bad()  { printf '  %sFAIL%s %s\n'   "$red"   "$off" "$1"; fail=1; }

# ---------------------------------------------------------------- 1 structural
#
# ⚠️ LITERAL PATHS ONLY. `Config.set(root.key, …)` is a row writing its own
# declared key and is covered by the walk; `Config.set("outputs", …)` is a file
# naming a key nothing else can see. The distinction is the whole check, so it
# is made by matching a quote rather than by listing filenames.
while IFS= read -r hit; do
    file=${hit%%:*}
    path=$(printf '%s' "$hit" | sed -n 's/.*Config\.set("\([^"]*\)".*/\1/p')
    [[ -n "$path" ]] || continue

    # The key may legitimately belong to a row in the same file.
    if grep -q "key: \"$path\"" "$file"; then
        ok "$path is written by a row in $(basename "$file")"
        continue
    fi
    if grep -q "resetKeys:.*\"$path\"" "$file"; then
        ok "$path is declared in $(basename "$file")'s resetKeys"
    else
        bad "$(basename "$file") writes \"$path\" and does not declare it in resetKeys — \"Reset this page\" would leave it standing and say the page was reset"
    fi
done < <(grep -rn 'Config\.set("' shell/ui/settings/ 2>/dev/null)

# ------------------------------------------------- 1b writes through a helper
#
# ⚠️ THE HALF THAT PART 1 CANNOT SEE — see the note at the top. A file in this
# window that reaches for config/Outputs.qml is writing `outputs`, however many
# functions the call goes through, and it owes the same declaration as if it had
# typed `Config.set("outputs", …)` itself.
#
# Comments do not count. This project has already had a scan read its own
# documentation as evidence: grepping for `import "../config"` matched a comment
# in tools/binds.qml saying the file deliberately does NOT import it.
helper_users="$(grep -rl 'Outputs\.\(setField\|clearField\|setPrimary\)' \
                     shell/ui/settings/ 2>/dev/null || true)"
if [[ -z "$helper_users" ]]; then
    # ⚠️ NOT SILENCE. If nothing calls the helper any more, either the page is
    # gone or it has been rewired — and this block would sit here going green
    # over a rule nobody is subject to.
    bad "nothing in the settings window writes outputs through config/Outputs.qml — has it moved? this check is now watching nothing"
else
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        page_code="$(sed 's|^[[:space:]]*//.*$||' "$f")"
        if grep -q 'Outputs\.\(setField\|clearField\|setPrimary\)' <<< "$page_code"; then
            if grep -q 'resetKeys:.*"outputs"' "$f"; then
                ok "$(basename "$f") writes outputs through the helper and declares it"
            else
                bad "$(basename "$f") writes outputs through config/Outputs.qml and does not declare \"outputs\" in resetKeys — \"Reset this page\" would leave every monitor setting standing and say the page was reset"
            fi
        fi
    done <<< "$helper_users"
fi

# The rebind pair is written through named functions rather than Config.set, so
# it cannot be found by the rule above. Named here instead of excused.
if grep -q 'resetKeys:.*"rebinds"' shell/ui/settings/BindsList.qml; then
    ok "rebinds is declared in BindsList's resetKeys"
else
    bad "BindsList calls Config.setRebind and does not declare \"rebinds\" in resetKeys"
fi

# And every key any of them names has to be a real one in the adapter — a
# resetKeys entry with a typo is a key that never gets removed.
for k in $(grep -rho 'resetKeys: \[[^]]*\]' shell/ui/settings/ \
           | grep -o '"[^"]*"' | tr -d '"' | sort -u); do
    if grep -q "property var $k:" shell/config/Config.qml; then
        ok "resetKeys names a real adapter key: $k"
    else
        bad "resetKeys names \"$k\", which is not a property in Config.qml"
    fi
done

# ⚠️ AN ARMED RESET MUST NOT SURVIVE LEAVING THE PAGE. First press arms, second
# does it — so an arm left standing means the NEXT page you open is one press
# from being reset, and the press that does it looks like the first one. What
# keeps the session buttons in the quick panel safe is the same property, and it
# is checked here rather than trusted because it is one line and invisible.
#
# Synthetic input demonstrably does not reach this window (see the note at the
# top of tests/row-writes.sh), so this is read rather than clicked.
content=$(cat shell/ui/settings/SettingsContent.qml)
if [[ "$content" == *"onCurrentIdChanged:"* ]] \
   && grep -q 'resetArmed = false' <<< "$(grep -A4 'onCurrentIdChanged:' <<< "$content")"; then
    ok "leaving a page disarms its reset"
else
    bad "SettingsContent does not clear resetArmed when the page changes — an armed reset would fire on the next page"
fi

if grep -q 'currentKeys = \[\]' <<< "$(grep -A4 'onCurrentIdChanged:' <<< "$content")"; then
    ok "leaving a page drops its key list"
else
    bad "SettingsContent does not clear currentKeys when the page changes — the reset would use the keys of the page you just left"
fi

# ------------------------------------------------- the half nobody was testing
#
# ⚠️ EVERYTHING ABOVE DRIVES `Backup.resetPaths` DIRECTLY. The BUTTON is
# two-stage — first press arms, second press fires — and no check had ever
# looked at that path. He pressed it and reported "die reset taste geht nicht",   # english-ok: his report, quoted
# which is precisely what a working two-stage button looks like when the only
# sign of stage one is four words on the button your finger is covering.
#
# So: the armed state has to SAY it is armed, somewhere other than on the button.
printf '  %-34s ' "the armed reset says so in words"
content="$(cat shell/ui/settings/SettingsContent.qml)"
if grep -q 'root.resetArmed$' <<< "$content" \
   && grep -q 'Press again to reset' <<< "$content"; then
    ok "there is a status line while armed"
else
    bad "arming changes nothing but the button caption — that reads as a dead button"
fi

# And the other half of the same thought: arming must not survive leaving.
printf '  %-34s ' "arming does not outlive the page"
if grep -q 'resetArmed = false' <<< "$(grep -A4 'onCurrentIdChanged:' <<< "$content")"; then
    ok "leaving the page disarms"
else
    bad "an armed reset would still be armed on the next page"
fi

# ---------------------------------------------------------------- 2 functional
if ! command -v qs >/dev/null; then
    echo "  quickshell (qs) not installed — the functional half did not run"
    exit 2
fi

tmp="$(mktemp -d)" || { echo "  could not make a temporary directory"; exit 2; }
[[ -n "$tmp" && "$tmp" == /tmp/* ]] || { echo "  refusing to run against $tmp"; exit 2; }
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config/buchhwin" "$tmp/home"

# The tool writes its own fixture in step 1; this only has to be a file Config
# will settle on.
echo '{ "theme": { "palette": "dracula" } }' > "$tmp/config/buchhwin/shell.json"

rm -f /tmp/buchhwin-reset-page-check.txt

BUCHHWIN_TOOL=reset-page-check \
QT_QPA_PLATFORM=offscreen \
XDG_CONFIG_HOME="$tmp/config" \
HOME="$tmp/home" \
    timeout 60 qs -p shell >/dev/null 2>&1

if [[ ! -f /tmp/buchhwin-reset-page-check.txt ]]; then
    bad "no output — the tool did not run"
    exit 1
fi

sed -e "s/^  ok /  ${green}ok${off} /" \
    -e "s/^  FAIL /  ${red}FAIL${off} /" /tmp/buchhwin-reset-page-check.txt

grep -q '^  FAIL' /tmp/buchhwin-reset-page-check.txt && fail=1

exit $fail
