#!/usr/bin/env bash
#
# An update must not touch what you chose.
#
# ⚠️ THIS IS HIS SENTENCE, AND IT IS A REQUIREMENT RATHER THAN AN ASSUMPTION:
# "bei einem update sollen userdaten also user settings etc wallpaper nicht      # english-ok: his words, quoted
# resetet werden das wäre ja blöd". The update button runs `bhctl update`, which # english-ok: same quote, second line
# pulls and then runs install.sh — so every install run is an update run, and
# the installer is the thing that has to keep its hands off.
#
# It is not obviously safe. phase_shell seeds shell.json, fills in an empty
# wallpaper folder, and — since the empty-fallback fix — can rewrite the palette
# of a machine that came up with no pictures. Three chances to overwrite a
# decision, and the third one is new.
#
# So: install once, make choices the way a person would, install again, and
# compare. Same sandbox and same stubs as tests/install-runs.sh — nothing here
# touches the machine it runs on.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v jq >/dev/null || { echo "jq not installed"; exit 2; }

fail=0
tmp="$(mktemp -d)"
# KEEP_TMP=1 leaves the sandbox behind, which is the only way to read the
# installer's own log when a run does not do what it should.
trap '[[ -n "${KEEP_TMP:-}" ]] && echo "  (sandbox kept: $tmp)" || rm -rf "$tmp"' EXIT

ok()  { printf '  \033[32mok\033[0m   %s\n' "$*"; }
bad() { printf '  \033[38;5;203mFAIL\033[0m %s\n' "$*"; fail=1; }

bin="$tmp/bin"; mkdir -p "$bin"
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$bin/$1"; chmod +x "$bin/$1"; }
stub sudo     'cat >/dev/null 2>&1; exit 0'
stub dnf      'exit 0'
stub systemctl 'exit 0'
stub rpm      'exit 1'
stub flatpak  'exit 0'
stub curl     'exit 1'
stub ping     'exit 0'
stub pgrep    'exit 1'
stub fc-cache 'exit 0'
stub xdg-mime 'exit 0'
stub xdg-user-dirs-update 'exit 0'
stub localectl 'exit 0'
stub getent   'echo "test:x:1000:1000::/home/test:/bin/bash"'
stub chsh     'exit 0'
stub qs       'exit 0'
stub niri     'exit 0'

home="$tmp/home"; mkdir -p "$home"
stub xdg-user-dir "echo \"$home/Pictures\""

src="$tmp/repo"; mkdir -p "$src"
files="$(git ls-files --cached --others --exclude-standard 2>/dev/null)"
[[ -z "$files" ]] && files="$(find . -type f -not -path './.git/*' -printf '%P\n' 2>/dev/null)"
[[ -n "$files" ]] || { echo "  found no files to copy — cannot test"; exit 2; }
printf '%s\n' "$files" | while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    mkdir -p "$src/$(dirname "$f")"
    cp -p "$f" "$src/$f"
done
[[ -f "$src/install.sh" ]] || { echo "  the copy has no install.sh — cannot test"; exit 2; }
chmod +x "$src/install.sh" "$src/bin/bhctl" 2>/dev/null

run_installer() {
    env -i PATH="$bin:/usr/bin:/bin" HOME="$home" \
        XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" \
        XDG_STATE_HOME="$home/.local/state" XDG_RUNTIME_DIR="$tmp/run" \
        BUCHHWIN_SYSFS="$tmp/sysfs-empty" TERM=dumb \
        bash "$src/install.sh" </dev/null >"$tmp/log-$1" 2>&1
}

cfg="$home/.config/buchhwin/shell.json"

run_installer first
if [[ ! -f "$cfg" ]]; then
    bad "the first run produced no settings file at all"
    exit 1
fi
ok "first run seeded $(jq -c '.theme // {}' "$cfg" 2>/dev/null)"

# ⚠️ ONE SETTING OF EACH SHAPE, and the wallpaper by name because it is the one
# he asked about. A bool, an int, a string, a list — the same reasoning as
# tests/settings-survive.sh: the failures here are type-shaped.
jq '.theme.palette = "dracula"
  | .theme.accent  = "mauve"
  | .wallpaper.current = "file:///home/test/Pictures/mine.jpg"
  | .wallpaper.folder  = "/home/test/Pictures/Mine"
  | .dock.enabled = true
  | .notch.flare  = 21
  | .windows.blurred = ["kitty","nautilus"]' "$cfg" > "$tmp/chosen" \
    && cp "$tmp/chosen" "$cfg" \
    || { bad "could not write the chosen settings"; exit 1; }
before="$(cat "$cfg")"

run_installer second

if [[ ! -f "$cfg" ]]; then
    bad "the second run DELETED the settings file"
    exit 1
fi

after="$(cat "$cfg")"

# The blunt question first, because it is the one he asked.
if [[ "$before" == "$after" ]]; then
    ok "a second install run changed nothing at all"
else
    bad "the second run rewrote shell.json"
    diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -12 | sed 's/^/        /'
fi

# And key by key, so a failure names which decision was taken away rather than
# just "the file differs".
check_key() {   # $1 dotted path, $2 what it should still be
    local got
    got="$(jq -r "$1" "$cfg" 2>/dev/null)"
    if [[ "$got" == "$2" ]]; then
        ok "kept $1 = $got"
    else
        bad "$1 was $2 and is now $got"
    fi
}
check_key '.theme.palette'         'dracula'
check_key '.theme.accent'          'mauve'
check_key '.wallpaper.current'     'file:///home/test/Pictures/mine.jpg'
check_key '.wallpaper.folder'      '/home/test/Pictures/Mine'
check_key '.dock.enabled'          'true'
check_key '.notch.flare'           '21'
check_key '.windows.blurred | join(",")' 'kitty,nautilus'

# ⚠️ AND THE ONE PLACE THE INSTALLER IS ALLOWED TO WRITE, checked from the other
# side so the permission cannot quietly widen. The empty-fallback recovery may
# only fire on a machine still carrying that exact fingerprint: the emergency
# palette AND no wallpaper at all. Anything else is a decision.
printf '%s' '{"theme":{"palette":"everforest-dark","accent":"green"},"wallpaper":{"folder":"","current":""}}' > "$cfg"
run_installer third
pal="$(jq -r '.theme.palette' "$cfg" 2>/dev/null)"
wp="$(jq -r '.wallpaper.current' "$cfg" 2>/dev/null)"
if [[ "$pal" == "wallpaper" && -n "$wp" && "$wp" != "null" ]]; then
    ok "the empty fallback is picked up ($pal, $(basename "$wp"))"
elif [[ "$pal" == "everforest-dark" ]]; then
    bad "a machine seeded with no pictures still cannot escape it"
else
    bad "unexpected state after recovery: palette=$pal current=$wp"
fi

exit $fail
