#!/usr/bin/env bash
#
# The files we generate must be readable by the programs they are for — in
# EVERY state, including "theming is off".
#
# ⚠️ THIS EXISTS BECAUSE OF A LINE IN SOMEBODY ELSE'S LOG. Brave printed
#
#   Gtk-WARNING: Failed to parse ~/.config/gtk-3.0/settings.ini:
#   Key file does not have group "Settings"
#
# on a machine where theming happened to be switched off. In that state the
# renderer wrote a file of nothing but comments — which says "we override
# nothing" in a way GLib treats as a BROKEN file rather than an empty one, so
# every GTK 3 program on the machine repeated our fault in its own output.
#
# The damage is not the warning. It is that the next person looking into why GTK
# theming does not work sees that line first and starts in the wrong place —
# which is the shape of false trail this project has paid for repeatedly.
#
# ⚠️ AND IT CHECKS BOTH STATES, which is the whole point. A check that only ever
# looked at the coloured output would have been green throughout: the "on" files
# were always fine. The fault lived entirely in the state nobody renders twice.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }
command -v python3 >/dev/null || { echo "python3 not installed"; exit 2; }

tmp="$(mktemp -d)" || { echo "  could not make a temporary directory"; exit 2; }
[[ -n "$tmp" && "$tmp" == /tmp/* ]] || { echo "  refusing to run against $tmp"; exit 2; }
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config/buchhwin"

fails=0
ok()  { printf '  \033[38;5;114mok\033[0m   %s\n' "$1"; }
bad() { printf '  \033[38;5;203mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }

# GLib's own parser, not a guess at its rules. `python3-gobject` is not a
# dependency of this project, so `configparser` stands in — it is strict about
# the same thing that matters here: a key file needs a section before any key,
# and a file with no section at all is what GLib rejected.
parse_ini() { # parse_ini <file>
    python3 - "$1" <<'PY'
import configparser, sys
p = sys.argv[1]
c = configparser.ConfigParser()
try:
    c.read(p)
except Exception as e:
    print(f"unreadable: {e}"); sys.exit(1)
if "Settings" not in c:
    print("no [Settings] group"); sys.exit(1)
print(f"ok, {len(c['Settings'])} keys")
PY
}

render() { # render <theming.enabled>
    cat > "$tmp/config/buchhwin/shell.json" <<JSON
{
  "theme": { "palette": "everforest-dark", "accent": "green" },
  "theming": { "enabled": $1, "mode": "colour" }
}
JSON
    BUCHHWIN_TOOL=render \
    QT_QPA_PLATFORM=offscreen \
    XDG_CONFIG_HOME="$tmp/config" \
    HOME="$tmp" \
        timeout 90 qs -p shell >/dev/null 2>&1
}

for state in true false; do
    label=$([[ "$state" == true ]] && echo "theming on" || echo "theming OFF")
    render "$state"
    for f in gtk-3.0 gtk-4.0; do
        path="$tmp/config/$f/settings.ini"
        if [[ ! -f "$path" ]]; then
            bad "$label: $f/settings.ini was not written at all"
            continue
        fi
        if out="$(parse_ini "$path")"; then
            ok "$label: $f/settings.ini parses — $out"
        else
            bad "$label: $f/settings.ini does not parse — $out"
        fi
    done
done

# ⚠️ AND THE OFF FILE MUST STILL SAY IT IS OFF. A valid file that quietly kept
# the old colours in it would parse perfectly and be worse than the warning.
off="$tmp/config/gtk-3.0/settings.ini"
if grep -q "theming is OFF" "$off" && ! grep -q "^gtk-theme-name=" "$off"; then
    ok "theming OFF: the file says so and sets nothing"
else
    bad "theming OFF: the file still carries settings or does not say it is off"
fi

(( fails == 0 )) || exit 1
exit 0
