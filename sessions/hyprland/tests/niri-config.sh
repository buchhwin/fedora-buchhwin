#!/usr/bin/env bash
#
# The generated niri config must parse — and it must parse cleanly.
#
# `niri validate` exits 1 only on a HARD error. Deprecated keys, an opacity
# outside 0..1, a duplicated output block: all of those exit 0 with either a
# warning or complete silence. So this checks the exit code AND the stderr, or
# it would happily pass a config that niri complains about on every start.
#
# It also validates a real file on disk rather than a process substitution:
# relative include paths resolve against the including file, and /dev/fd is not
# a directory that contains colors.kdl.
#
# ⚠️ XDG_DATA_HOME IS REDIRECTED TOO. The generator writes a desktop-file
# override into ~/.local/share/applications as well as the config, and a test
# that leaves files outside its own temporary directory is a test that changes
# the machine it runs on.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }
command -v niri >/dev/null || { echo "niri not installed"; exit 2; }

fail=0
check() {   # $1 = label, $2 = shell.json contents ("" = no file at all)
    local label="$1" json="$2"
    printf '  %-34s ' "$label"

    local tmp; tmp="$(mktemp -d)"
    mkdir -p "$tmp/buchhwin" "$tmp/niri" "$tmp/environment.d"
    [[ -n "$json" ]] && printf '%s\n' "$json" > "$tmp/buchhwin/shell.json"

    rm -f /tmp/buchhwin-niri.log
    XDG_CONFIG_HOME="$tmp" XDG_DATA_HOME="$tmp/share" BUCHHWIN_TOOL=niri QT_QPA_PLATFORM=offscreen \
        timeout 60 qs -p shell >/dev/null 2>&1

    if [[ ! -f "$tmp/niri/config.kdl" ]]; then
        printf '\033[38;5;203mno config generated\033[0m\n'; fail=1; rm -rf "$tmp"; return
    fi
    # The generator exits 0 even when it gives up; its report is the truth.
    if grep -q ABORT /tmp/buchhwin-niri.log 2>/dev/null; then
        printf '\033[38;5;203mgenerator aborted\033[0m\n'; fail=1; rm -rf "$tmp"; return
    fi

    local out rc
    out="$(NO_COLOR=1 niri validate -c "$tmp/niri/config.kdl" 2>&1)"; rc=$?
    if (( rc != 0 )); then
        printf '\033[38;5;203minvalid\033[0m\n'
        sed 's/^/      /' <<< "$out" | head -12
        fail=1; rm -rf "$tmp"; return
    fi
    # Exit 0 is not enough — see the header.
    #
    # ⚠️ ONE warning is expected and is not a fault: the generated config ends
    # with `include optional=true ~/.config/niri/colors.kdl`, and in a bare test
    # (or in CI) the renderer has never run, so that file does not exist. That
    # is exactly what `optional` means. It is filtered by its own text rather
    # than by relaxing the check, so every OTHER warning still fails the test —
    # the whole reason this check exists is that niri exits 0 on a config it has
    # complained about.
    out="$(grep -v 'optional include not found' <<< "$out")"
    if grep -qi 'warn' <<< "$out"; then
        printf '\033[38;5;203mvalid but warns\033[0m\n'
        grep -i warn <<< "$out" | sed 's/^/      /' | head -6
        fail=1; rm -rf "$tmp"; return
    fi

    printf '\033[38;5;114mok\033[0m  %s lines\n' "$(wc -l < "$tmp/niri/config.kdl")"
    rm -rf "$tmp"
}

# A fresh machine has no settings file at all; the defaults must still produce
# a working compositor, because that is the state right after installation.
check "defaults (no shell.json)" ""
check "everforest-dark" '{"version":1,"theme":{"palette":"everforest-dark","accent":"green"}}'
check "borders on, wide gaps" '{"version":1,"look":{"borderWidth":3,"gapsOut":24}}'
check "minimal profile (blur off)" '{"version":1,"look":{"profile":"minimal"}}'
check "bar on, osd off" '{"version":1,"bar":{"enabled":true},"surfaces":{"osd":false}}'
check "german keyboard, no touchpad tap" \
      '{"version":1,"input":{"keyboard":{"layout":"de","variant":"nodeadkeys"},"touchpad":{"tap":false,"naturalScroll":false}}}'
check "an output override" \
      '{"version":1,"outputs":[{"name":"eDP-1","mode":"1920x1080@60.000","scale":1.5,"x":0,"y":0,"vrr":true}]}'
check "extra autostart + floating rule" \
      '{"version":1,"autostart":["nm-applet"],"windows":{"floating":["pavucontrol"],"blockFromScreencast":["keepassxc"]}}'
# A program that is not configured must DROP its key rather than emit a binding
# to nothing — and the result still has to parse.
check "no terminal configured" '{"version":1,"programs":{"terminal":[]}}'
# ⚠️ THE `debug` BLOCK, and the path deliberately does NOT exist on the machine
# running this. Measured on niri 26.04 with two controls: an invented key inside
# the block IS rejected, so the name is real; a device that does not exist is
# accepted WITHOUT a warning, so this case is safe for a suite that fails on any
# warning — and that acceptance is exactly why the settings row is a closed list
# rather than a text field. A config naming a device niri cannot open parses
# perfectly and then does not start.
check "render device set" \
      '{"version":1,"gpu":{"renderDevice":"/dev/dri/by-path/pci-0000:01:00.0-render"}}'

# ⚠️ AND THE OTHER HALF OF THE SAME KEY, which is the half that would rot
# silently. An empty renderDevice must write NO `debug` block at all — not an
# empty one. `debug` is a section niri documents as unsupported and subject to
# change, so being inside it on every machine that has no opinion is a standing
# risk taken for nothing. A green "it parses" would not notice the difference.
printf '  %-34s ' "empty render device writes no block"
tmp="$(mktemp -d)"; mkdir -p "$tmp/buchhwin" "$tmp/niri" "$tmp/environment.d" "$tmp/share"
printf '{"version":1,"gpu":{"renderDevice":""}}\n' > "$tmp/buchhwin/shell.json"
XDG_CONFIG_HOME="$tmp" XDG_DATA_HOME="$tmp/share" BUCHHWIN_TOOL=niri QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1
# ⚠️ `grep -c ... || echo 0` IS WRONG HERE, and it was written that way first:
# grep -c prints 0 AND exits 1 when it matches nothing, so the fallback fires on
# top of the answer and the variable holds two lines. The message read "wrote 0
# 0 debug block(s)", which is the check reporting on its own arithmetic rather
# than on the file. `|| true` keeps the single number grep already printed.
n="$(grep -c '^debug {' "$tmp/niri/config.kdl" 2>/dev/null || true)"
if [[ "${n:-0}" == "0" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mwrote %s debug block(s) for an empty value\033[0m\n' "$n"; fail=1
fi
rm -rf "$tmp"

# Regenerating must be a no-op: niri live-reloads on every write, so a rewrite
# that changes nothing still costs a full compositor reload.
printf '  %-34s ' "second run writes nothing"
tmp="$(mktemp -d)"; mkdir -p "$tmp/buchhwin" "$tmp/niri" "$tmp/environment.d"
printf '{"version":1}\n' > "$tmp/buchhwin/shell.json"
for _ in 1 2; do
    XDG_CONFIG_HOME="$tmp" XDG_DATA_HOME="$tmp/share" BUCHHWIN_TOOL=niri QT_QPA_PLATFORM=offscreen \
        timeout 60 qs -p shell >/dev/null 2>&1
done
if grep -q '0 written' /tmp/buchhwin-niri.log; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mrewrote unchanged files\033[0m\n'; fail=1
fi
rm -rf "$tmp"

# No key may be bound twice.
#
# niri takes the LAST binding for a key and says nothing about the one it
# dropped, so a duplicate is a shortcut that silently stopped working. The
# predecessor accumulated several of these — a duplicated Super+Tab is in the
# list of things deliberately left behind — and it happened again the moment a
# conventional Super+L was added on top of the vim navigation group.
#
# ⚠️ THIS CHECK CANNOT ACTUALLY FAIL, and that was measured rather than
# suspected: the generator (tools/niri.qml, bindsSection) drops a duplicate
# before writing the file, so the output is deduplicated by construction. A
# second Mod+K was added on purpose and this stayed green while the binding
# quietly did not exist. The real check is in tools/smoke.qml, against
# Config.keys.binds. This one is kept as the second net — it would catch a
# duplicate the generator itself introduced, which the other cannot see.
# Every layer rule must name the radius its surface actually DRAWS.
#
# ⚠️ THIS IS THE CHECK FOR "the corners of all the panels are a weird red".
# `background-effect` belongs to the SURFACE, and niri clips the blur to
# `geometry-corner-radius`. The generator used to pass `look.rounding` for every
# namespace — but that is the BASE the radii derive from, not a radius anybody
# paints: the panes draw `Theme.radiusLg`, which at rounding 16 is 21. The five
# pixels between the two came out as a crescent of RAW blurred wallpaper at each
# corner, and raw means through `blur { saturation }`. Measured on the VM before
# the fix: panel interior r−b = +2, crescent r−b = +138, i.e. more saturated
# than the wallpaper itself.
#
# ⚠️ AND IT DOES NOT RE-COMPUTE THE FORMULA. Multiplying rounding by 1.33 here
# would pass whatever the theme does, including the same mistake — the check
# would be a mirror. Instead the two independent producers are compared: the
# token dump says what QML draws, the generated config says what niri is told.
# Both must be run with the SAME shell.json, or they are answering different
# questions.
printf '  %-34s ' "layer radii match what is drawn"
tmp="$(mktemp -d)"; mkdir -p "$tmp/buchhwin" "$tmp/niri" "$tmp/environment.d"
# Deliberately NOT the defaults: a wrong radius that happens to equal the right
# one on the default numbers would slip through. 20 → radiusLg 27, and the notch
# corner is moved off both.
printf '{"version":2,"look":{"rounding":20},"notch":{"cornerRadius":11}}\n' \
    > "$tmp/buchhwin/shell.json"
rm -f /tmp/buchhwin-tokens.txt
XDG_CONFIG_HOME="$tmp" XDG_DATA_HOME="$tmp/share" BUCHHWIN_TOOL=dump-tokens \
    QT_QPA_PLATFORM=offscreen timeout 60 qs -p shell >/dev/null 2>&1
XDG_CONFIG_HOME="$tmp" XDG_DATA_HOME="$tmp/share" BUCHHWIN_TOOL=niri \
    QT_QPA_PLATFORM=offscreen timeout 60 qs -p shell >/dev/null 2>&1

# "  radius xs..pill        7 10 20 27 33 999"
# ⚠️ SIX NUMBERS AFTER TWO WORDS. "radius" and "xs..pill" are fields 1 and 2, so
# xs..pill run from $3 to $8 and radiusLg — the one the panes draw — is $6. The
# first version of this line took $4 and reported "drawn 10" against a config
# that said 27; the check failed while the code under it was correct, which is
# the worst kind of test.
drawn="$(awk '/^  radius xs\.\.pill/ { print $6 }' /tmp/buchhwin-tokens.txt 2>/dev/null)"
radius_of() {   # $1 = namespace
    awk -v ns="\"^$1\$\"" '
        $1 == "layer-rule" { inrule = 1; match_ns = 0 }
        inrule && $1 == "match" && $2 == "namespace=" ns { match_ns = 1 }
        inrule && match_ns && $1 == "geometry-corner-radius" { print $2; exit }
        $1 == "}" { inrule = 0 }
    ' "$tmp/niri/config.kdl"
}
bad=""
if [[ -z "$drawn" ]]; then
    bad="no radius in the token dump"
else
    for ns in buchhwin-overlay buchhwin-toast buchhwin-launcher; do
        got="$(radius_of "$ns")"
        [[ "$got" == "$drawn" ]] || bad+="$ns=$got (drawn $drawn) "
    done
    # The notch and the bar each stand alone — one namespace, one expected
    # number — so neither is a loop. It used to be `for ns in buchhwin-notch`,
    # over a list of exactly one, and shellcheck was right to call it out
    # (SC2043): a one-element loop reads as the start of a list somebody meant
    # to extend, and the next person adding a namespace would have put it here
    # rather than in the group above, where the rule is different.
    got="$(radius_of buchhwin-notch)"
    [[ "$got" == "11" ]] || bad+="buchhwin-notch=$got (notch corner 11) "
    got="$(radius_of buchhwin-bar)"
    [[ "$got" == "0" ]] || bad+="buchhwin-bar=$got (draws nothing rounded) "
fi
if [[ -z "$bad" ]]; then
    printf '\033[38;5;114mok\033[0m  panes %s, notch 11, bar 0\n' "$drawn"
else
    printf '\033[38;5;203m%s\033[0m\n' "$bad"; fail=1
fi
rm -rf "$tmp"

# The shadow must be a shadow — on EVERY palette, and switched on exactly once.
#
# ⚠️ TWO FAULTS IN ONE CHECK, and both shipped.
#
# 1. The colour used to be `crust` at a fixed alpha. `crust` is the palette's
#    DARKEST tone, which on latte is #dce0e8 and on everforest-light #e6e2cc —
#    both nearly white. Every window on a light palette would have been given a
#    glow instead of a shadow, and nothing would have complained.
#
# 2. Whether the shadow exists at all is decided in config.kdl and must NOT be
#    decided a second time in the included colours file: an include overrides
#    what came before it, and `on`/`off` mean different things depending on
#    which file they are in. So colors.kdl carries a colour and nothing else.
#
# The check runs the renderer as well as the generator, because the colour and
# the switch live in different files and only the pair of them is the answer.
printf '  %-34s ' "the shadow is a shadow"
bad=""
for pal in latte everforest-light gruvbox; do
    tmp="$(mktemp -d)"; mkdir -p "$tmp/buchhwin" "$tmp/niri" "$tmp/environment.d"
    printf '{"version":2,"theme":{"palette":"%s"}}\n' "$pal" > "$tmp/buchhwin/shell.json"
    for tool in niri render; do
        XDG_CONFIG_HOME="$tmp" XDG_DATA_HOME="$tmp/share" BUCHHWIN_TOOL="$tool" \
            QT_QPA_PLATFORM=offscreen timeout 60 qs -p shell >/dev/null 2>&1
    done
    col="$(sed -n '/^layout {/,/^}/p' "$tmp/niri/colors.kdl" 2>/dev/null \
           | awk '/shadow \{/ { s = 1 } s && $1 == "color" { print $2; exit }' | tr -d '"')"
    if [[ ! "$col" =~ ^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$ ]]; then
        bad+="$pal: no shadow colour "
    else
        # Dark enough to BE a shadow: the mean channel must sit in the bottom
        # quarter. A threshold rather than a formula, because the point is
        # "darker than anything it can fall on", not a particular tone.
        mean=$(( (16#${BASH_REMATCH[1]:0:2} + 16#${BASH_REMATCH[1]:2:2} + 16#${BASH_REMATCH[1]:4:2}) / 3 ))
        (( mean < 64 )) || bad+="$pal: shadow is $col (mean $mean, that is a glow) "
    fi
    grep -q 'on' <<< "$(sed -n '/shadow {/,/}/p' "$tmp/niri/colors.kdl" 2>/dev/null)" \
        && bad+="$pal: colors.kdl decides on/off "
    shadow_block="$(sed -n '/^layout {/,/^}/p' "$tmp/niri/config.kdl" \
                    | sed -n '/shadow {/,/}/p')"
    grep -q '^        on$' <<< "$shadow_block" \
        || bad+="$pal: config.kdl does not switch it on "
    rm -rf "$tmp"
done
if [[ -z "$bad" ]]; then
    printf '\033[38;5;114mok\033[0m  dark on light palettes too\n'
else
    printf '\033[38;5;203m%s\033[0m\n' "$bad"; fail=1
fi

printf '  %-34s ' "no key is bound twice"
tmp="$(mktemp -d)"; mkdir -p "$tmp/buchhwin" "$tmp/niri" "$tmp/environment.d"
printf '{"version":2}\n' > "$tmp/buchhwin/shell.json"
XDG_CONFIG_HOME="$tmp" XDG_DATA_HOME="$tmp/share" BUCHHWIN_TOOL=niri QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1
dupes="$(sed -n '/^binds {/,/^}/p' "$tmp/niri/config.kdl" \
         | grep -oE '^    [A-Za-z0-9+_]+' | tr -d ' ' | sort | uniq -d)"
if [[ -z "$dupes" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mbound twice: %s\033[0m\n' "$(echo "$dupes" | tr '\n' ' ')"
    fail=1
fi
rm -rf "$tmp"

# ---------------------------------------------------------------------------
# `bhctl niri diff` must compare the machine against ITS OWN settings.
#
# ⚠️ THE FAULT THIS EXISTS FOR. `diff` renders into a temporary XDG_CONFIG_HOME
# and it created $tmp/niri and $tmp/environment.d but never $tmp/buchhwin — so
# the generator looked for shell.json (Config.qml:663-667), found nothing, and
# produced a config from the pure schema defaults. Every machine with a single
# non-default key was told "niri config STALE", and `bhctl niri apply`, the fix
# it recommended, could never clear it. `doctor` reuses this command, so the one
# line meant to prove the generated config was current was the least trustworthy
# line in the report.
#
# The test is a round trip against a DELIBERATELY NON-DEFAULT value, because
# that is the only kind this could ever get wrong: `apply`, then `diff`, and the
# answer has to be "no changes". With the bug present the second step prints the
# default back at you, which is what makes this the control and not a mirror.
printf '  %-34s ' "apply then diff says no changes"
tmp="$(mktemp -d)"; mkdir -p "$tmp/buchhwin" "$tmp/niri" "$tmp/environment.d" "$tmp/share"
# gapsOut 24 rather than the default, and a cursor theme that is not Breeze_Dark:
# one key the layout section reads and one the misc section reads, so a sandbox
# that loses the settings file cannot pass by touching only one code path.
printf '{"version":1,"look":{"gapsOut":24},"cursor":{"theme":"McMojave-cursors","size":32}}\n' \
    > "$tmp/buchhwin/shell.json"
#
# ⚠️ HOME IS REDIRECTED TOO, and it is not tidiness. bhctl falls back to
# $HOME/.config and $HOME/.local/share when the XDG variables are absent, and
# the generator reads ~/.config/user-dirs.dirs to decide where screenshots go.
# Leaving the real HOME in place makes this test depend on the account running
# it — which is how it passed on the VM and failed in the CI container.
mkdir -p "$tmp/home"
applyout="$(HOME="$tmp/home" XDG_CONFIG_HOME="$tmp" XDG_DATA_HOME="$tmp/share" \
            bin/bhctl niri apply 2>&1)"; applyrc=$?
if (( applyrc == 0 )) && [[ -f "$tmp/niri/config.kdl" ]]; then
    out="$(HOME="$tmp/home" XDG_CONFIG_HOME="$tmp" XDG_DATA_HOME="$tmp/share" \
           bin/bhctl niri diff 2>&1)"
    if [[ "$out" == "no changes" ]]; then
        printf '\033[38;5;114mok\033[0m\n'
    else
        printf '\033[38;5;203mreports a difference against its own settings\033[0m\n'
        # ⚠️ SAY WHAT WAS ACTUALLY SEEN. The first version printed only the diff,
        # and when this failed in CI the diff was EMPTY — which says nothing at
        # all about why. An empty answer here has three different causes and
        # they need telling apart: bhctl printed nothing, the generated file is
        # missing, or diff itself errored with its stderr thrown away.
        printf '      %s bytes of output, exit was %s\n' "${#out}" "$applyrc"
        printf '%s\n' "$out" | head -8 | sed 's/^/      | /'
        fail=1
    fi
else
    printf '\033[38;5;203mbhctl niri apply failed (rc %s, config %s)\033[0m\n' \
        "$applyrc" "$([[ -f "$tmp/niri/config.kdl" ]] && echo present || echo MISSING)"
    printf '%s\n' "$applyout" | head -6 | sed 's/^/      | /'
    fail=1
fi
rm -rf "$tmp"

exit $fail
