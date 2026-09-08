#!/usr/bin/env bash
#
# Axis 10: a setting survives a shell restart.
#
# shell.json is the store and the shell is supposed to be the only thing that
# writes it, so "it survives" sounds like it cannot fail. It can, and this
# project has the scars: Migrations.qml rewrites the raw JSON on every start,
# and step 7→8 exists precisely because a key had frozen 63 keybindings into
# somebody's file for ever. A migration that drops a key it does not recognise,
# or a JsonAdapter type that cannot read its own output back, both look exactly
# like this — the value is gone the next morning and nothing said a word.
#
# ⚠️ ONE KEY OF EACH SHAPE, not one key. The failure is type-shaped: the
# `list<int>` that tests/config-shape.sh bans could not be read back at all
# while looking perfectly fine on the way in. So: a bool, an int, a real, a
# string, and a list of strings.
#
# ⚠️ NEEDS A RUNNING SHELL — it restarts the thing it is testing. Not in CI, for
# the same reason tests/ipc-effect.sh and tests/surfaces.sh are not.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v python3 >/dev/null || { echo "python3 not installed"; exit 2; }
systemctl --user is-active buchhwin-shell >/dev/null 2>&1 \
    || { echo "the shell is not running as a user unit"; exit 2; }

cfg="${XDG_CONFIG_HOME:-$HOME/.config}/buchhwin/shell.json"
[[ -f "$cfg" ]] || { echo "no shell.json"; exit 2; }

fail=0
backup="$(mktemp)"
cp "$cfg" "$backup"
# ⚠️ Restored whatever happens. A test that leaves somebody's settings changed
# is a test they stop running.
restore() {
    cp "$backup" "$cfg"
    rm -f "$backup"
    systemctl --user restart buchhwin-shell >/dev/null 2>&1
}
trap restore EXIT

# The five, and the shape each one is there to cover. They are written out in
# both python blocks below rather than driven from a list here: a shell array
# feeding two heredocs would need quoting for JSON values, and quoting a test's
# own fixtures is how a test starts measuring its quoting.
#
#   cursor.size            41                  int
#   look.blur              false               bool
#   look.opacityPanel      0.77                real
#   input.keyboard.layout  "fr"                string
#   windows.floating       ["buchhwin-probe"]  list<string>

# ⚠️ THE SHELL IS STOPPED FIRST, AND THE FIRST VERSION OF THIS TEST WAS WRONG
# FOR NOT DOING IT. Writing while the shell runs means the live watcher applies
# the change immediately and the restart afterwards proves nothing — the test
# passed through the path it was not testing. Stopped, written, started is the
# real question: does a change made while the desktop was off ever arrive.
printf '  %-40s ' "stopping the shell"
systemctl --user stop buchhwin-shell >/dev/null 2>&1
sleep 2
printf '\033[38;5;114mok\033[0m\n'

# The control for the half below: before the shell comes back, the generated
# config must NOT contain the new value. Without this, "config.kdl has it" could
# simply mean it always did.
kdl="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
printf '  %-40s ' "config.kdl does not have it yet"
if grep -q 'xcursor-size 41' "$kdl" 2>/dev/null; then
    printf '\033[38;5;203mit already did — nothing can be concluded\033[0m\n'
    fail=1
else
    printf '\033[38;5;114mok\033[0m\n'
fi

printf '  %-40s ' "writing five settings of five shapes"
python3 - "$cfg" <<'PYEOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
def put(path, value):
    cur = d
    parts = path.split(".")
    for k in parts[:-1]:
        cur = cur.setdefault(k, {})
    cur[parts[-1]] = value
put("cursor.size", 41)
put("look.blur", False)
put("look.opacityPanel", 0.77)
put("input.keyboard.layout", "fr")
put("windows.floating", ["buchhwin-probe"])
json.dump(d, open(p, "w"), indent=2)
PYEOF
printf '\033[38;5;114mok\033[0m\n'

printf '  %-40s ' "starting it again"
systemctl --user start buchhwin-shell >/dev/null 2>&1
# The shell reads, migrates and may rewrite shell.json during startup; giving it
# less time than that measures the file before the thing under test has touched
# it, which is the opposite of the question.
sleep 12
printf '\033[38;5;114mok\033[0m\n'

printf '  %-40s ' "every one of them is still there"
lost="$(python3 - "$cfg" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
want = {
    "cursor.size": 41,
    "look.blur": False,
    "look.opacityPanel": 0.77,
    "input.keyboard.layout": "fr",
    "windows.floating": ["buchhwin-probe"],
}
bad = []
for path, value in want.items():
    cur = d
    ok = True
    for k in path.split("."):
        if not isinstance(cur, dict) or k not in cur:
            ok = False
            break
        cur = cur[k]
    if not ok:
        bad.append("%s(gone)" % path)
    elif cur != value:
        bad.append("%s(%r not %r)" % (path, cur, value))
print(" ".join(bad))
PYEOF
)"
if [[ -z "$lost" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203m%s\033[0m\n' "$lost"; fail=1
fi

# ⚠️ AND THE GENERATOR SAW THEM. A value that survives in the file and never
# reaches config.kdl is the fault tests/fingerprint.sh was written for, one step
# later: the watcher has to notice the change a restart brought in. Two of the
# five above are generator keys, so both must be in the compositor's config.
printf '  %-40s ' "and the generated config caught up"
missing=""
grep -q 'xcursor-size 41' "$kdl" 2>/dev/null || missing+=" cursor.size"
grep -q 'layout "fr"' "$kdl" 2>/dev/null || missing+=" input.keyboard.layout"
if [[ -z "$missing" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mnot in config.kdl:%s\033[0m\n' "$missing"
    printf '      the setting survived the restart and the generator never ran —\n'
    printf '      that is the catch-up half of services/Theming.qml.\n'
    fail=1
fi

exit $fail
