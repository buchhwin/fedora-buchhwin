#!/usr/bin/env bash
#
# The .desktop overrides must describe the program they are named after.
#
# ⚠️ THIS IS WRITTEN AGAINST A BUG THAT SHIPPED. shell/tools/hypr.qml reuses one
# FileView for every entry in its override list, and a FileView hands back what
# it already holds when you point it at a new path. So the second pass read
# BRAVE's system file and wrote it out as code.desktop:
#
#     brave-browser.desktop   Name=Brave Web Browser   8650 bytes
#     code.desktop            Name=Brave Web Browser   8650 bytes   <-- identical
#
# A user desktop file REPLACES the system one — there is no merge and no
# fallback. So that single missing `path = ""` deleted VS Code from the launcher
# and listed Brave twice. The generator logged `wrote code.desktop` throughout,
# which is exactly why no test and no eye caught it for as long as it existed.
#
# What this checks is therefore not "a file was written" but "the file is about
# the right program", which is the thing that was wrong.
#
# ⚠️ XDG_DATA_HOME IS REDIRECTED. A test that leaves files in the real
# ~/.local/share/applications is a test that changes the machine it runs on —
# and in this case it would change which programs appear in the launcher.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

# The generator can only override what is installed. On a build host that is
# nothing, and a test that silently passes on zero files is the failure mode
# this whole suite exists to prevent — so say so and skip.
SYS=/usr/share/applications
installed=0
for f in brave-browser.desktop code.desktop; do
    [[ -f "$SYS/$f" ]] && installed=$((installed + 1))
done
if [[ $installed -eq 0 ]]; then
    echo "neither brave nor code installed — nothing to override here"
    exit 2
fi

fail=0
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
bad()  { printf '  \033[38;5;203mFAIL\033[0m %s\n' "$*"; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/cfg/buchhwin" "$tmp/cfg/niri" "$tmp/cfg/environment.d" "$tmp/share"

rm -f /tmp/buchhwin-niri.log
XDG_CONFIG_HOME="$tmp/cfg" XDG_DATA_HOME="$tmp/share" \
    BUCHHWIN_TOOL=hypr QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1

APPS="$tmp/share/applications"

# The generator's own report is the truth; it exits 0 even when it gives up.
if grep -q ABORT /tmp/buchhwin-niri.log 2>/dev/null; then
    bad "generator aborted"
    exit 1
fi

# ---------------------------------------------------------------- per program
#
# $1 desktop file, $2 a string that must appear in Name=, $3 one that must not.
check_program() {
    local file="$1" want="$2" foreign="$3"
    local path="$APPS/$file"

    if [[ ! -f "$SYS/$file" ]]; then
        printf '  \033[38;5;245mskip\033[0m %s (not installed)\n' "$file"
        # ⚠️ And while we are here: not installed must mean no file at all.
        # An override for a program that is not there would hide nothing today
        # and the wrong thing tomorrow.
        [[ -f "$path" ]] && bad "$file: not installed, yet an override was written"
        return
    fi

    [[ -f "$path" ]] || { bad "$file: no override written at all"; return; }

    local name
    name="$(grep -m1 '^Name=' "$path")"

    if [[ "$name" != *"$want"* ]]; then
        bad "$file: Name is '$name', expected it to mention '$want'"
    elif [[ "$name" == *"$foreign"* ]]; then
        bad "$file: Name is '$name' — that is the OTHER program's file"
    else
        ok "$file: $name"
    fi

    # The whole reason these files exist. Measured: without the flag Brave takes
    # 57-100 s to start because it waits for an X11 probe to fail.
    if grep -q '^Exec=.*--ozone-platform=wayland' "$path"; then
        ok "$file: Exec carries --ozone-platform=wayland"
    else
        bad "$file: no Exec line with --ozone-platform=wayland"
    fi
}

echo "  generated overrides"
check_program brave-browser.desktop "Brave" "Visual Studio"
check_program code.desktop          "Code"  "Brave"

# ------------------------------------------------------- the direct statement
#
# Name= could in principle be missing from both; this is the blunt version of
# the same question and it is the one that would have caught the shipped bug on
# its own.
if [[ -f "$APPS/brave-browser.desktop" && -f "$APPS/code.desktop" ]]; then
    if cmp -s "$APPS/brave-browser.desktop" "$APPS/code.desktop"; then
        bad "the two overrides are byte-for-byte identical — one FileView, two paths"
    else
        ok "the two overrides differ"
    fi
fi

# ------------------------------------------------------------- the log agrees
#
# ⚠️ The bug was invisible partly because the report said the right thing. If
# the generator claims it wrote a file, the file has to be there.
while read -r label; do
    [[ -z "$label" ]] && continue
    [[ -f "$APPS/$label" ]] && continue
    bad "log says it wrote $label, but the file is not there"
done < <(grep -oE 'wrote  [a-z-]+\.desktop' /tmp/buchhwin-niri.log 2>/dev/null | awk '{print $2}')

[[ $fail == 0 ]] && ok "report and disk agree"
exit $fail
