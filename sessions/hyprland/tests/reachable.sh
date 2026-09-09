#!/usr/bin/env bash
#
# Nothing is generated into a void.
#
# The renderer writes seven files, and "change the palette, everything follows"
# is only true if something actually READS each one. GTK finds gtk.css and
# settings.ini by itself; kitty and qt6ct do not. kitty reads kitty.conf and
# only the files it `include`s, qt6ct reads qt6ct.conf and only the colour
# scheme named there — and for a long time neither pointer existed. The terminal
# theme was written to ~/.config/kitty/theme.conf on every palette change and
# read by nobody, so the terminal sat at kitty's own black throughout, while the
# renderer reported success each time. Writing had worked. Nothing else had.
#
# This runs the REAL installer phase into a throwaway config home, so it checks
# what ships rather than a copy of it that can drift.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

fail=0
pass() { printf '  \033[38;5;114mok\033[0m    %s\n' "$1"; }
bad()  { printf '  \033[38;5;203mFAIL\033[0m  %s\n' "$1"; fail=1; }
# ⚠️ A skip is not a pass and must not read like one. Six of the themed
# programs are not installed in the CI container, and the checks that ask THEM
# rather than the filesystem can only run where they exist. Saying which ones
# were not asked is the difference between "green" and "green here".
skip() { printf '  \033[38;5;179mskip\033[0m  %s\n' "$1"; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# ⚠️ THE PATH HAS TO END IN THE SESSION'S OWN ROOT, or every check below looks
# in the wrong place. phase_shell derives its config home by APPENDING
# buchhwin-sessions/hyprland unless XDG_CONFIG_HOME already ends in it — the
# isolation that keeps this session out of Plasma's ~/.config. A plain
# "$work/config" therefore made the renderer write one directory deeper than
# this test looked, and every generated file was reported as never written.
cfg="$work/config/buchhwin-sessions/hyprland"
mkdir -p "$cfg"

# ⚠️ KEEP BOTH REPORTS, because "not written" on its own is a dead end.
#
# That is exactly what this suite said the last time it went red, and it is
# what a refusal, a crash and a genuinely skipped file all look like from out
# here. The renderer's own log tells the three apart — it ends at "start" when
# the process died, at "ABORT" when it refused, at "done" when it ran — and the
# installer's output carries the warning run_tool prints. Both were being sent
# to /dev/null, so the one run that mattered was undiagnosable.
#
# The log is a fixed path shared by every run, so it is copied HERE: this
# script installs twice, and the second run would otherwise overwrite the
# evidence from the first.
# ⚠️ install-hyprland.sh, NOT install.sh — THE SAME RENAME THAT KILLED
# tests/install-runs.sh killed this one too, and here it was quieter. The
# installer simply did not exist, so nothing rendered, and every check below
# reported the file it was looking for as `not written`. That reads as a
# broken renderer rather than a test calling a program by the wrong name.
rm -f /tmp/buchhwin-render.log
XDG_CONFIG_HOME="$cfg" XDG_CACHE_HOME="$work/cache" \
    timeout 120 bash install-hyprland.sh --only shell >"$work/install.log" 2>&1
cp -f /tmp/buchhwin-render.log "$work/render.log" 2>/dev/null || true

why() {
    printf '        ---- renderer log ----\n'
    sed 's/^/        /' "$work/render.log" 2>/dev/null || printf '        (no log at all)\n'
    if grep -qE 'warn|fail|abort' "$work/install.log" 2>/dev/null; then
        printf '        ---- installer complaints ----\n'
        grep -iE 'warn|fail|abort' "$work/install.log" | sed 's/^/        /'
    fi
}

# Written at all.
missing=0
for pair in \
    "gtk3 css|$cfg/gtk-3.0/gtk.css" \
    "gtk3 settings|$cfg/gtk-3.0/settings.ini" \
    "gtk4 css|$cfg/gtk-4.0/gtk.css" \
    "kitty theme|$cfg/kitty/theme.conf" \
    "qt6ct colours|$cfg/qt6ct/colors/buchhwin.conf"
do
    label="${pair%%|*}"; path="${pair##*|}"
    if [[ -s "$path" ]]; then pass "written: $label"
    else bad "not written: $label ($path)"; missing=1; fi
done
(( missing )) && why

# Reachable — the half that used to be missing.
if grep -qE '^ *include  *theme\.conf' "$cfg/kitty/kitty.conf" 2>/dev/null; then
    pass "kitty.conf includes the generated theme"
else
    bad "kitty.conf does not include theme.conf — the palette never reaches the terminal"
fi

if grep -q 'colors/buchhwin\.conf' "$cfg/qt6ct/qt6ct.conf" 2>/dev/null; then
    pass "qt6ct.conf selects the generated colours"
else
    bad "qt6ct.conf does not select colors/buchhwin.conf — Qt apps keep their own"
fi

# ⚠️ VS CODE WAS CHECKED HERE AND IS NOT ANY MORE, because the thing it checked
# was removed on purpose. render.qml used to write three files for it — a
# package.json manifest, the colour theme, and `workbench.colorTheme` in the
# user's settings.json — and this block guarded the pointer, since the first two
# are inert without it. Writing into ~/.vscode and into a program's own
# settings.json reaches outside this session's XDG_CONFIG_HOME and edits a file
# the user owns, which is exactly what the profile was cut back to stop doing;
# the VS Code, Spicetify and Vesktop theming all went with it.
#
# ⚠️ AND LEAVING THE CHECK IN WAS WORSE THAN A RED LINE. Its first branch tests
# for files under $HOME, and this suite RUNS the installer for real — so on any
# machine where an older revision had run once, the leftover extension made the
# branch true and demanded a settings.json that nothing writes any more. It
# reported a fault in code that no longer exists, from a file no longer written.

# And the terminal's transparency lands in the file kitty reads, rather than
# being left to the compositor, which fades the text along with it.
if grep -q '^background_opacity ' "$cfg/kitty/theme.conf" 2>/dev/null; then
    pass "the terminal's background opacity is written"
else
    bad "no background_opacity in the kitty theme"
fi

# ⚠️ THE SAME FAILURE AS THE KITTY INCLUDE, ONE LAYER DEEPER.
#
# qt6ct takes a colour scheme only when active, inactive AND disabled each
# carry a full set of roles, and silently keeps Qt's own default otherwise:
#
#     if(activeColors.count() >= QPalette::NColorRoles &&
#        inactiveColors.count() >= QPalette::NColorRoles &&
#        disabledColors.count() >= QPalette::NColorRoles) { … }
#     else { customPalette = fallback; }
#         — qt6ct-0.11, src/qt6ct-common/qt6ct.cpp
#
# The renderer wrote active_colors and nothing else for months, so the file
# existed, the pointer was right, this suite was green, and every Qt program
# ran on Fusion grey. Counted rather than grepped, because "the line is there"
# was exactly the assertion that did not hold.
qtc="$cfg/qt6ct/colors/buchhwin.conf"
for group in active inactive disabled; do
    n=$(grep -m1 "^${group}_colors=" "$qtc" 2>/dev/null | cut -d= -f2- | awk -F, '{print NF}')
    if [[ "${n:-0}" -ge 21 ]]; then
        pass "qt6ct ${group}_colors has $n roles"
    else
        bad "qt6ct ${group}_colors has ${n:-0} roles — qt6ct falls back to Qt's default palette"
    fi
done

# --------------------------------------------------------------------------
# The six programs that came with their own pointer syntax.
#
# Same rule as kitty and qt6ct: written is half of it. Each of these is asked
# twice — is our file there, and is there something naming it — and where the
# program itself is installed, it is asked a third time: does the colour
# actually arrive. That third question is the one that catches a theme written
# into a void, and it is the only one that would have caught qt6ct.
for pair in \
    "btop theme|$cfg/btop/themes/buchhwin.theme" \
    "alacritty|$cfg/alacritty/buchhwin.toml" \
    "tmux|$cfg/tmux/buchhwin.conf" \
    "git-delta|$cfg/git/buchhwin-delta.gitconfig" \
    "lazygit|$cfg/lazygit/buchhwin.yml" \
    "bat theme|$cfg/bat/themes/buchhwin.tmTheme"
do
    label="${pair%%|*}"; path="${pair##*|}"
    if [[ -s "$path" ]]; then pass "written: $label"
    else bad "not written: $label ($path)"; why; fi
done

# ⚠️ ONLY WHERE THE PROGRAM IS, and that gate copies lib/60-shell.sh rather than
# softening this check. `seed_pointer` there writes a program's OWN config file
# only when the program is installed: the profile stopped installing btop, bat,
# git-delta, tmux, lazygit and alacritty, because they are things a person
# chooses rather than things the desktop needs. Their THEME files are still
# generated unconditionally — that is the loop above, and it stays
# unconditional — so the palette is already right the day one gets installed.
# Only the pointer waits for the program.
#
# This loop demanded the pointer regardless, and turned five lines red over a
# machine that was behaving exactly as the installer intends.
#
# ⚠️ AND IT IS STILL THE CHECK IT WAS, on any machine that has the program: a
# theme written into a void is the fault this loop exists to catch, and nothing
# else in the suite would see it. What is dropped is only the claim that not
# having btop installed is a fault.
#
# The second field is the COMMAND, which is not always the label: git-delta's
# binary is `delta`.
for quad in \
    "btop|btop|$cfg/btop/btop.conf|^color_theme *= *\"buchhwin\"" \
    "alacritty|alacritty|$cfg/alacritty/alacritty.toml|buchhwin\.toml" \
    "tmux|tmux|$cfg/tmux/tmux.conf|buchhwin\.conf" \
    "bat|bat|$cfg/bat/config|buchhwin" \
    "git-delta|delta|$cfg/git/config|buchhwin-delta\.gitconfig"
do
    IFS='|' read -r label prog path marker <<<"$quad"
    if ! command -v "$prog" >/dev/null 2>&1; then
        skip "$label is not installed — the installer seeds no pointer for it"
    elif grep -qE "$marker" "$path" 2>/dev/null; then
        pass "$label points at the generated theme"
    else
        bad "$label has no pointer — its colours never arrive"
    fi
done

# btop's theme is a fixed set of 37 keys; a short one is a theme with holes,
# which btop renders as black rather than as an error.
n=$(grep -c '^theme\[' "$cfg/btop/themes/buchhwin.theme" 2>/dev/null || echo 0)
[[ "$n" == 37 ]] && pass "btop theme has all 37 keys" \
                 || bad "btop theme has $n of 37 keys"

# ⚠️ THE POINT OF THE WHOLE bat TARGET. A .tmTheme in the right folder is
# invisible until `bat cache --build` compiles it, which the renderer runs
# itself. Asked of bat, not of the filesystem.
#
# XDG_CACHE_HOME is redirected so this cannot touch the cache of whoever is
# running the test — the renderer inherits it, so its cache build lands in the
# throwaway directory too.
if command -v bat >/dev/null; then
    bat_themes="$(XDG_CONFIG_HOME="$cfg" XDG_CACHE_HOME="$work/cache" \
                  bat --list-themes --color=never 2>/dev/null)"
    if grep -q buchhwin <<< "$bat_themes"; then
        pass "bat knows the theme (the cache was built)"
    else
        bad "bat does not list the theme — the .tmTheme was never compiled"
    fi
    # ⚠️ ASKED FOR OUR EXACT COLOUR, not merely for "some colour". bat falls
    # back to a built-in theme when it cannot find ours, and that fallback also
    # emits truecolor — so a looser check passes while the theme is ignored.
    # `int` is a keyword, which the generated tmTheme paints in the palette's
    # red; kitty's color1 is the same colour, so it is the expected value
    # without a second source for it.
    printf 'int x = 42;\n' > "$work/probe.c"
    want=$(grep -m1 '^color1 ' "$cfg/kitty/theme.conf" | awk '{print $2}' | tr -d '#')
    if [[ -n "$want" ]]; then
        rgb="38;2;$((16#${want:0:2}));$((16#${want:2:2}));$((16#${want:4:2}))"
        bat_painted="$(COLORTERM=truecolor XDG_CONFIG_HOME="$cfg" XDG_CACHE_HOME="$work/cache" \
                       bat --color=always --style=plain "$work/probe.c" 2>/dev/null)"
        if grep -q "$rgb" <<< "$bat_painted"; then
            pass "bat paints keywords in the palette's own red (#$want)"
        else
            bad "bat did not use the generated theme (expected $rgb)"
        fi
    fi
else
    skip "bat is not installed — its colours were not checked"
fi

if command -v git >/dev/null; then
    # ⚠️ THE GATE IS `delta`, NOT `git`. What is being resolved here is the
    # include line in $XDG_CONFIG_HOME/git/config, and lib/60-shell.sh writes
    # that line only when git-delta is installed — git itself is always here and
    # says nothing about whether there is anything to include. Asked of git
    # alone, this failed on every machine without delta and blamed the include.
    if command -v delta >/dev/null 2>&1; then
        got=$(XDG_CONFIG_HOME="$cfg" git config --get delta.file-style 2>/dev/null)
        if [[ "$got" == *"#"* ]]; then
            pass "git resolves the delta colours through the include ($got)"
        else
            bad "git does not see the delta colours — the include did not take"
        fi
    else
        skip "git-delta is not installed — there is no include for git to resolve"
    fi
    # ⚠️ THE HALF THAT MATTERS MORE THAN THE COLOURS, and it is asked whether or
    # not delta is here: nothing of the user's may have moved. This is the check
    # standing guard over the rule the whole profile was cut back to obey.
    if [[ ! -f "$HOME/.gitconfig" ]] || ! grep -q buchhwin "$HOME/.gitconfig" 2>/dev/null; then
        pass "the global gitconfig in \$HOME was not touched"
    else
        bad "something wrote into ~/.gitconfig, which belongs to the user"
    fi
fi

if command -v tmux >/dev/null; then
    tmux -f /dev/null -L reachable-probe new-session -d 2>/dev/null
    tmux -L reachable-probe source-file "$cfg/tmux/buchhwin.conf" 2>/dev/null
    got=$(tmux -L reachable-probe show -g status-style 2>/dev/null)
    tmux -L reachable-probe kill-server 2>/dev/null
    [[ "$got" == *"#"* ]] && pass "tmux takes the generated colours (${got#status-style })" \
                          || bad "tmux did not take the generated colours"
else
    skip "tmux is not installed — its colours were not checked"
fi

if command -v alacritty >/dev/null; then
    # ⚠️ THE EXIT CODE, AND A DELIBERATELY BROKEN COPY — not a grep for a
    # filename in the output. The first version of this check grepped stdout
    # and failed once in about ten runs for reasons that never reproduced, and
    # an intermittent check is worse than none: it teaches everyone to re-run
    # until it is green.
    #
    # Measured what the tool actually signals: a broken imported file exits 1,
    # a valid chain exits 0 — but a MISSING imported file also exits 0, so the
    # code alone would not prove the import is honoured. Hence the second half:
    # break a copy of the chain, and require a complaint. That is the proof
    # that alacritty really reads our file, and it cannot flake.
    if alacritty migrate --dry-run -c "$cfg/alacritty/alacritty.toml" >/dev/null 2>&1; then
        pass "alacritty parses the generated theme"
    else
        bad "alacritty rejects the generated theme"
        alacritty migrate --dry-run -c "$cfg/alacritty/alacritty.toml" 2>&1 | sed 's/^/        /'
    fi
    probe="$work/ala"; mkdir -p "$probe"
    sed "s|$cfg/alacritty/buchhwin.toml|$probe/buchhwin.toml|" \
        "$cfg/alacritty/alacritty.toml" > "$probe/alacritty.toml"
    { cat "$cfg/alacritty/buchhwin.toml"; printf '[colors.primary\n'; } > "$probe/buchhwin.toml"
    if alacritty migrate --dry-run -c "$probe/alacritty.toml" >/dev/null 2>&1; then
        bad "alacritty ignores the imported file — breaking it changed nothing"
    else
        pass "alacritty really reads the import (a broken copy is refused)"
    fi
else
    skip "alacritty is not installed — its config was not parsed"
fi

# A second run must not fight the user's own file.
printf '# mine\ninclude theme.conf\nfont_size 14\n' > "$cfg/kitty/kitty.conf"
XDG_CONFIG_HOME="$cfg" XDG_CACHE_HOME="$work/cache" \
    timeout 120 bash install-hyprland.sh --only shell >/dev/null 2>&1
if grep -q '^font_size 14' "$cfg/kitty/kitty.conf"; then
    pass "an existing kitty.conf is left alone"
else
    bad "the installer overwrote a kitty.conf that already existed"
fi

# --------------------------------------------------------------------------
# One state per program — checked, not claimed.
#
# The point of the three states is that they differ FROM EACH OTHER on the same
# machine at the same moment: one program grey while the next is coloured. A
# test that renders one state and looks at one file cannot see that, which is
# how twelve switches that did nothing at all passed for months.
#
# The renderer is called directly from here rather than through install.sh:
# same tool, same code path (lib/common.sh and bin/bhctl both run exactly this
# line), a fraction of the time, and the installer would not touch shell.json
# again anyway — it seeds it once and never overwrites.
if ! command -v jq >/dev/null; then
    echo "  jq not installed — skipping the state matrix"
    exit $fail
fi

set_states() {   # mode gtk qt kitty the compositor  [enabled]
    jq --arg m "$1" --arg g "$2" --arg q "$3" --arg k "$4" --arg n "$5" \
       --argjson e "${6:-true}" \
       '.theming = {enabled: $e, mode: $m, gtk: $g, qt: $q, kitty: $k, hypr: $n}' \
       "$cfg/buchhwin/shell.json" > "$work/s.json" \
        && mv "$work/s.json" "$cfg/buchhwin/shell.json"
}
set_one() {      # target state
    jq --arg t "$1" --arg s "$2" '.theming[$t] = $s' \
       "$cfg/buchhwin/shell.json" > "$work/s.json" \
        && mv "$work/s.json" "$cfg/buchhwin/shell.json"
}

# Every file the renderer owns, in one place, so "off takes everything back"
# and "enabled=false takes everything back" cannot drift apart from the list.
generated=(gtk-3.0/gtk.css gtk-3.0/settings.ini gtk-4.0/gtk.css gtk-4.0/settings.ini
           kitty/theme.conf buchhwin/hyprland/generated/colors.lua qt6ct/colors/buchhwin.conf
           btop/themes/buchhwin.theme alacritty/buchhwin.toml tmux/buchhwin.conf
           git/buchhwin-delta.gitconfig lazygit/buchhwin.yml)

render_now() {
    rm -f /tmp/buchhwin-render.log
    # ⚠️ XDG_CACHE_HOME too: the renderer runs `bat cache --build`, and without
    # this it would rebuild the cache of whoever is running the test.
    XDG_CONFIG_HOME="$cfg" XDG_CACHE_HOME="$work/cache" \
        BUCHHWIN_TOOL=render QT_QPA_PLATFORM=offscreen \
        timeout 60 qs -p shell >/dev/null 2>"$work/render.err"
    local code=$?
    cp -f /tmp/buchhwin-render.log "$work/render.log" 2>/dev/null || true
    if (( code != 0 )); then
        bad "the renderer exited $code"
        sed 's/^/        /' "$work/render.log" 2>/dev/null
        tail -5 "$work/render.err" 2>/dev/null | sed 's/^/        /'
        return 1
    fi
    if grep -q ABORT "$work/render.log" 2>/dev/null; then
        bad "the renderer aborted"
        sed -n '/ABORT/,$p' "$work/render.log" | sed 's/^/        /'
        return 1
    fi
    return 0
}

# Grey means r == g == b. The same question tests/wallpaper.sh asks of the
# palette, asked here of the file a program actually reads.
#
# ⚠️ Asked of `background` and `color4`, NOT of `foreground`: the neutral text
# ramp keeps a trace of warmth (#e8e3e3 measured), which is deliberate and
# would make a strict r==g==b check fail on the one line that is least
# interesting.
hex_of() { grep -m1 "^$2 " "$1" 2>/dev/null | awk '{print $2}' | tr -d '#'; }
is_grey() { [[ -n "$1" && "${1:0:2}" == "${1:2:2}" && "${1:2:2}" == "${1:4:2}" ]]; }

# --- A: the mixed case. One program grey, the rest coloured, one switched off.
if set_states colour inherit off neutral inherit && render_now; then
    bg=$(hex_of "$cfg/kitty/theme.conf" background)
    c4=$(hex_of "$cfg/kitty/theme.conf" color4)
    c1=$(hex_of "$cfg/kitty/theme.conf" color1)
    if is_grey "$bg" && is_grey "$c4"; then
        pass "neutral: the terminal's background and blue are grey (#$bg, #$c4)"
    else
        bad "neutral: the terminal is not grey (background #$bg, color4 #$c4)"
    fi
    # The anchored colours stay coloured on purpose — an error has to read as
    # an error in a grey scheme too (theme/FromImage.qml).
    if is_grey "$c1"; then
        bad "neutral: red went grey (#$c1) — meaning colours must stay anchored"
    else
        pass "neutral: red is still red (#$c1)"
    fi
    # Colourless, not unstyled.
    if grep -q '^background_opacity ' "$cfg/kitty/theme.conf" &&
       grep -q '^font_family ' "$cfg/kitty/theme.conf"; then
        pass "neutral: transparency and font survive"
    else
        bad "neutral: transparency or font was dropped — neutral means colourless, not unstyled"
    fi
    # …and the program next to it is untouched. This is the assertion that the
    # reverted first attempt would have failed: its switches never took effect.
    if grep -qE '^@define-color theme_bg_color #' "$cfg/gtk-3.0/gtk.css" &&
       ! is_grey "$(grep -m1 '^@define-color accent_color ' "$cfg/gtk-3.0/gtk.css" \
                    | awk '{print $3}' | tr -d '#;')"; then
        pass "one program neutral leaves the others coloured"
    else
        bad "gtk went grey as well — the state is not per program"
    fi
    if [[ -s "$cfg/qt6ct/colors/buchhwin.conf" ]] &&
       ! grep -q 'active_colors=' "$cfg/qt6ct/colors/buchhwin.conf" &&
       grep -q 'theming is OFF' "$cfg/qt6ct/colors/buchhwin.conf"; then
        pass "off: the file is a stub that overrides nothing, and says so"
    else
        bad "off: the qt6ct colours were not taken back"
    fi
    if grep -q 'colors/buchhwin\.conf' "$cfg/qt6ct/qt6ct.conf"; then
        pass "off: the user's qt6ct.conf is untouched"
    else
        bad "off: something edited qt6ct.conf, which belongs to the user"
    fi
fi

# --- B: the other direction. System neutral, one program explicitly coloured.
if set_states neutral colour inherit inherit inherit && render_now; then
    acc=$(grep -m1 '^@define-color accent_color ' "$cfg/gtk-3.0/gtk.css" | awk '{print $3}' | tr -d '#;')
    kbg=$(hex_of "$cfg/kitty/theme.conf" background)
    if ! is_grey "$acc" && is_grey "$kbg"; then
        pass "mode neutral with one target on colour: gtk #$acc, kitty #$kbg"
    else
        bad "inherit does not follow mode (gtk accent #$acc, kitty background #$kbg)"
    fi
fi

# --- C: the way back. off must not be a one-way door.
if set_states colour inherit inherit inherit inherit && render_now; then
    if grep -q 'active_colors=' "$cfg/qt6ct/colors/buchhwin.conf"; then
        pass "back from off: the qt6ct colours return"
    else
        bad "back from off: the qt6ct colours did not return"
    fi
    if grep -qE '^ *include  *theme\.conf' "$cfg/kitty/kitty.conf"; then
        pass "back from off: the kitty pointer was never lost"
    else
        bad "back from off: kitty.conf lost its include"
    fi
    # And nothing is rewritten for nothing.
    if render_now && grep -q 'done: 0 written' "$work/render.log"; then
        pass "an unchanged run writes no file"
    else
        bad "a second run rewrote files that did not change"
    fi
fi

# --- D: the master switch beats everything, in one line.
if set_states colour colour colour colour colour false && render_now; then
    left=""
    for f in "${generated[@]}"; do
        grep -q 'theming is OFF' "$cfg/$f" || left+=" $f"
    done
    # bat's stub is XML, so it says it differently — asked separately rather
    # than loosening the phrase everything else is checked against.
    grep -q 'OFF for bat' "$cfg/bat/themes/buchhwin.tmTheme" || left+=" bat"
    [[ -n "$left" ]] && bad "theming.enabled=false left files behind:$left" \
                     || pass "theming.enabled=false takes all ${#generated[@]}+1 files back"
fi

# --- E: a target with its own pointer, switched off on its own.
#
# ⚠️ TWO CLAIMS, AND ONLY ONE OF THEM IS ALWAYS ASKABLE. The theme becoming a
# stub is generated work and happens on every machine. That btop.conf is left
# alone can only be asked where btop.conf EXISTS, and lib/60-shell.sh seeds it
# only when btop is installed — so on a machine without btop this failed with a
# grep error about a missing file and called it "not taken back cleanly", which
# named the wrong thing entirely.
if set_states colour inherit inherit inherit inherit && set_one btop off && render_now; then
    btop_untouched=yes
    if command -v btop >/dev/null 2>&1; then
        grep -qE '^color_theme *= *"buchhwin"' "$cfg/btop/btop.conf" \
            || btop_untouched=no
    fi
    if grep -q 'theming is OFF' "$cfg/btop/themes/buchhwin.theme" &&
       [[ "$btop_untouched" == yes ]]; then
        if command -v btop >/dev/null 2>&1; then
            pass "off: btop's theme is a stub and its btop.conf is untouched"
        else
            pass "off: btop's theme is a stub (btop is not installed, so it has no btop.conf to leave alone)"
        fi
    else
        bad "off: btop was not taken back cleanly"
    fi
    if grep -q '^theme\[main_fg\]' "$cfg/btop/themes/buchhwin.theme"; then
        bad "off: the btop theme still carries colours"
    fi
fi

exit $fail
