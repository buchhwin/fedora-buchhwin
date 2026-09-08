#!/usr/bin/env bash
#
# Every file we generate is actually read by the programme it is for.
#
# ⚠️ THE THIRD SHAPE OF THE SAME DEBT. This project has now found it twice in
# the other two directions: a config key nothing reads (five of them, in
# tests/key-readers.sh) and a themed tool with no way to reach it (btop, which
# had a generated theme and no key). This is the middle one — a file we write on
# every palette change that its owner never looks at.
#
# It fails silently and looks like success. The renderer says it wrote the file,
# the file is on disk with the right colours in it, `bhctl theme apply` reports
# no error — and the programme comes up in its own defaults, because nothing
# ever told it to include the thing. There is no message anywhere.
#
# ⚠️ IT RUNS AGAINST THE MACHINE, not the repository. What matters is whether
# kitty.conf on THIS system includes our theme, and that is a question about the
# installed state; a check reading only the generator would pass while the
# include was missing. It therefore skips rather than fails when a file is
# absent — a machine that never ran the installer is not a fault.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
printf '  %-34s ' "generated files are included"

fail=0
missing=""
skipped=0

# generated file : the file that must mention it : what to look for
check() {
    local made="$cfg/$1" owner="$cfg/$2" needle="$3"
    [[ -f "$made" ]]  || { skipped=$(( skipped + 1 )); return; }
    [[ -f "$owner" ]] || { missing+="$1 — $2 does not exist"$'\n'; fail=1; return; }
    grep -q -- "$needle" "$owner" \
        || missing+="$1 — $2 never mentions it"$'\n'
    grep -q -- "$needle" "$owner" || fail=1
}

check kitty/theme.conf              kitty/kitty.conf         "theme.conf"
check alacritty/buchhwin.toml       alacritty/alacritty.toml "buchhwin"
check tmux/buchhwin.conf            tmux/tmux.conf           "buchhwin"
check qt6ct/colors/buchhwin.conf    qt6ct/qt6ct.conf         "buchhwin.conf"
check niri/colors.kdl               niri/config.kdl          "colors.kdl"
# lazygit is reached through an environment variable rather than an include —
# niri sets LG_CONFIG_FILE, which is why the owner here is the compositor's
# config and not lazygit's own.
check lazygit/buchhwin.yml          niri/config.kdl          "buchhwin.yml"

# btop names its theme by NAME, not by path: `color_theme = "buchhwin"` against
# a file called buchhwin.theme. Checking for the path would never match.
if [[ -f "$cfg/btop/themes/buchhwin.theme" ]]; then
    if [[ -f "$cfg/btop/btop.conf" ]]; then
        grep -qE 'color_theme *= *"[^"]*buchhwin' "$cfg/btop/btop.conf" \
            || { missing+="btop/themes/buchhwin.theme — btop.conf selects another theme"$'\n'; fail=1; }
    else
        missing+="btop/themes/buchhwin.theme — btop.conf does not exist"$'\n'; fail=1
    fi
else
    skipped=$(( skipped + 1 ))
fi

if (( fail == 0 )); then
    printf '\033[38;5;114mok\033[0m'
    (( skipped )) && printf '  (%d not generated on this machine)' "$skipped"
    printf '\n'
    exit 0
fi

printf '\033[38;5;203mfound\033[0m\n'
sed 's/^/      /' <<< "${missing%$'\n'}"
cat <<'WHY'

  These are written on every palette change and never looked at. The programme
  comes up in its own defaults and nothing says why — the renderer reports
  success, the file is on disk, and the colours simply do not appear.

  The include belongs in the installer, beside wherever that programme's own
  config is written, not in the renderer: the renderer must be able to run a
  hundred times without editing anybody's hand-written config.
WHY
exit 1
