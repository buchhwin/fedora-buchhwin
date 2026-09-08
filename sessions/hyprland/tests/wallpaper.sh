#!/usr/bin/env bash
#
# The wallpaper's colour scheme, and the one promise that matters about it:
# what you pick is still there after a restart.
#
# That promise has two halves, and both are checked here rather than assumed:
#
#   * shell.json remembers the image — one key, written atomically
#   * the derived palette is a CACHE keyed on that image, so a restart loads
#     colours from disk instead of re-reading a 6000x3750 PNG
#
# ⚠️ That cache lives in XDG_STATE_HOME, NOT in the shell tree. It used to sit
# in theme/palettes/ beside the eleven palettes that ship, which put generated
# user state into a source checkout — one `git pull` or one deploy that mirrors
# the tree and somebody's colours are gone. This test pins the new location so
# it cannot drift back.
#
# The cache is the part that can rot silently. If it were not keyed on the
# source, changing the wallpaper would leave the old colours in place for ever
# and the only symptom would be "the theme did not change" — which reads as a
# missing feature, not as a bug. So case 2 and case 3 below are the real test:
# same image must NOT rewrite, different image MUST.
#
# ⚠️ Needs a real image. ImageMagick is not assumed; the images are written as
# tiny uncompressed PPMs, which Qt reads without any extra plugin.
#
# ⚠️ And it runs against a COPY of shell/. The derived palette is written into
# the shell's own folder — that is the deliberate design, because giving Scheme
# a second search path broke loading for all eleven palettes twice. The cost is
# that a desktop running on this machine and a headless tool share one cache
# file: measured here, the live shell noticed the test's write, saw a `source`
# that did not match ITS wallpaper, and re-derived over it mid-test. Testing a
# copy keeps the test honest without asking anyone to shut their desktop down.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }
command -v jq >/dev/null || { echo "jq not installed"; exit 2; }

fail=0

pass() { printf '  \033[38;5;114mok\033[0m    %s\n' "$1"; }
bad()  { printf '  \033[38;5;203mFAIL\033[0m  %s\n' "$1"; fail=1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cp -r shell "$work/shell"
statedir="$work/state"; mkdir -p "$statedir/buchhwin"
derived="$statedir/buchhwin/wallpaper.json"

pics="$work/pics"; mkdir -p "$pics"

# A PPM is "P3, width height, maxval, then RGB triples" — no library needed.
# Colourful enough to seed a palette, and small enough to be instant.
make_ppm() {   # make_ppm <file> <r> <g> <b> <r2> <g2> <b2>
    { printf 'P3\n8 8\n255\n'
      for ((y = 0; y < 8; y++)); do
          for ((x = 0; x < 8; x++)); do
              if (( (x + y) % 2 == 0 )); then printf '%s %s %s ' "$2" "$3" "$4"
              else printf '%s %s %s ' "$5" "$6" "$7"; fi
          done
          printf '\n'
      done
    } > "$1"
}

make_ppm "$pics/blue.ppm"  30  90 220  10  20  40
make_ppm "$pics/red.ppm"  220  50  40  40  10  10
# Flat mid-grey: an image with no colour in it at all.
make_ppm "$pics/grey.ppm" 128 128 128 128 128 128
# Not an image. Qt decodes nothing from it, which is the one failure the
# derivation genuinely cannot work around — see case 4.
printf 'this is not an image\n' > "$pics/broken.png"

cfgdir="$work/cfg"; mkdir -p "$cfgdir/buchhwin"

set_wallpaper() {
    printf '{"version":2,"theme":{"palette":"wallpaper","accent":"blue"},"wallpaper":{"folder":"%s","current":"file://%s"}}\n' \
        "$pics" "$1" > "$cfgdir/buchhwin/shell.json"
}

derive() {
    rm -f /tmp/buchhwin-wallpaper-palette.log 2>/dev/null
    # ⚠️ The report lives at a fixed path, so a copy left behind by another
    # user — one `sudo bash tests/wallpaper.sh` is enough — cannot be replaced,
    # and `rm -f` says nothing about it. Every check below then reads a report
    # from a different run and fails for a reason that is not in the code. Ask
    # once, out loud, rather than let it look like a bug in the shell.
    if [[ -e /tmp/buchhwin-wallpaper-palette.log ]]; then
        echo "  /tmp/buchhwin-wallpaper-palette.log belongs to someone else." >&2
        echo "  Every check below would read a stale report. Remove it and re-run." >&2
        exit 2
    fi
    XDG_CONFIG_HOME="$cfgdir" XDG_STATE_HOME="$statedir" \
        BUCHHWIN_TOOL=wallpaper-palette \
        QT_QPA_PLATFORM=offscreen timeout 40 qs -p "$work/shell" >/dev/null 2>&1
}

# ---------------------------------------------------------------- 1. it builds
set_wallpaper "$pics/blue.ppm"
derive
if [[ ! -f "$derived" ]]; then
    bad "a palette is derived from the wallpaper (no file was written)"
else
    src="$(jq -r '.source // ""' "$derived")"
    if [[ "$src" != "file://$pics/blue.ppm" ]]; then
        bad "the derived palette names its source (got '$src')"
    else
        pass "a palette is derived, and it names the image it came from"
    fi
    # 26 names, or something downstream reads undefined and renders black.
    n="$(jq -r '.colors | length' "$derived")"
    [[ "$n" == "26" ]] && pass "it has all 26 colours" \
                       || bad "it has $n colours, expected 26"
fi

# ------------------------------------------------------ 1b. the folder listing
# The picker turns the folder into paths through Wallpaper.pathAt(). That call
# asked for the role `fileURL`, which Qt 6 renamed to `fileUrl` — and asking for
# the old name does not fail, it returns undefined. Every image in the folder
# came back as "", so the picker listed covers you could not choose. Nothing
# else here would have caught it, because every other case sets the wallpaper
# by writing shell.json directly.
#
# ⚠️ The .ppm files above are deliberately NOT counted here: the shell filters
# the folder by extension (jpg/png/gif/avif/jxl), so a PPM is invisible to the
# picker even though the quantiser reads it happily when pointed straight at it.
# That is why the fixture below carries one .png as well.
listed="$(grep -oE 'folder: [0-9]+ images' /tmp/buchhwin-wallpaper-palette.log | grep -oE '[0-9]+')"
first="$(grep -oE 'first file:///[^ ]+' /tmp/buchhwin-wallpaper-palette.log)"
if [[ "${listed:-0}" -ge 1 && -n "$first" ]]; then
    pass "the folder lists its images with real paths ($listed found)"
else
    bad "the folder listed '${listed:-none}' images, first path '${first:-empty}'"
    # ⚠️ The report, and the folder as the SHELL sees it. This check has been
    # the only red job in CI for weeks while passing everywhere it was run by
    # hand, which is precisely the situation where the number alone is useless:
    # "none" means the line is missing, and the line is missing for a different
    # reason than a zero would be.
    printf '        ---- wallpaper-palette log ----\n'
    sed 's/^/        /' /tmp/buchhwin-wallpaper-palette.log 2>/dev/null \
        || printf '        (no log at all)\n'
    printf '        ---- the fixture folder ----\n'
    ls -la "$pics" | sed 's/^/        /'
fi

# ------------------------------------------------- 2. the cache is not rebuilt
# The whole point of the cache: a restart with the same wallpaper must load
# colours, not re-read the image.
before="$(stat -c %Y "$derived" 2>/dev/null)"
sleep 1.1                      # coarser than the filesystem's timestamp
derive
after="$(stat -c %Y "$derived" 2>/dev/null)"
[[ "$before" == "$after" ]] && pass "the same wallpaper does not rebuild the cache" \
                            || bad "the same wallpaper rebuilt the cache ($before -> $after)"

# ---------------------------------------------------- 3. a new image rebuilds
seed_before="$(jq -r '.colors.blue' "$derived")"
set_wallpaper "$pics/red.ppm"
derive
seed_after="$(jq -r '.colors.blue' "$derived")"
src="$(jq -r '.source // ""' "$derived")"
if [[ "$src" == "file://$pics/red.ppm" && "$seed_before" != "$seed_after" ]]; then
    pass "a different wallpaper rebuilds it ($seed_before -> $seed_after)"
else
    bad "a different wallpaper did not rebuild it (source '$src')"
fi

# -------------------------------------------- 4. an undecodable image is refused
# Refusing keeps the previous scheme, which matters most on the NEXT start: a
# broken image that overwrote the cache would come back broken every time.
keep="$(jq -r '.colors.base' "$derived")"
set_wallpaper "$pics/broken.png"
derive
if grep -qE 'REFUSED|ABORT' /tmp/buchhwin-wallpaper-palette.log 2>/dev/null; then
    now="$(jq -r '.colors.base' "$derived")"
    [[ "$now" == "$keep" ]] && pass "an image that cannot be decoded is refused, the old scheme stays" \
                            || bad "refused, but the cache changed anyway ($keep -> $now)"
else
    bad "an undecodable image was accepted"
fi

# --------------------------------- 5. a grey image does not get an invented hue
# The seed falls back to hue 0 when an image has no chroma, and hue 0 with a
# saturation floor is RED. Measured before this was fixed: a flat grey wallpaper
# produced the accent #ca7272. A picture with no colour must yield a scheme with
# no colour — except for the meaning colours, which are anchored and must stay
# recognisable no matter what the wallpaper looks like.
set_wallpaper "$pics/grey.ppm"
derive
acc="$(jq -r '.colors.blue' "$derived")"
err="$(jq -r '.colors.red' "$derived")"
if [[ "${acc:0:2}" == "${acc:2:2}" && "${acc:2:2}" == "${acc:4:2}" ]]; then
    pass "a grey wallpaper gives a grey accent (#$acc), not an invented one"
else
    bad "a grey wallpaper invented the accent #$acc"
fi
[[ "${err:0:2}" != "${err:2:2}" ]] && pass "the error colour stays red (#$err) even so" \
                                   || bad "the error colour went grey (#$err); meaning must not follow the image"

# ------------------------------------------------------- 6. nothing set at all
# A machine with no wallpaper must not crash, hang or produce a file.
rm -f "$derived"
printf '{"version":2,"theme":{"palette":"wallpaper","accent":"blue"},"wallpaper":{"folder":"","current":""}}\n' \
    > "$cfgdir/buchhwin/shell.json"
derive
if [[ -f "$derived" ]]; then
    bad "no wallpaper set, yet a palette file was written"
elif grep -qE 'ABORT|REFUSED' /tmp/buchhwin-wallpaper-palette.log 2>/dev/null; then
    pass "no wallpaper set is reported, not crashed on"
else
    bad "no wallpaper set produced neither a file nor a reason"
fi

# --------------------------------------------------------- the shipped default
#
# ⚠️ THIS IS THE HALF THAT WAS MISSING WHEN IT MATTERED. Everything above tests
# the cache once a wallpaper is set. Nothing asked whether a fresh machine ends
# up with one — and it did not: Fedora's /usr/share/backgrounds has no image at
# its top level, the fallback copied zero files while reporting `ok (0)`, and
# every clean install came up on the emergency palette with no picture. Reported
# as "die wallpaper sind nicht als standard gesetzt".               # english-ok: his report, quoted
printf '  %-34s ' "a wallpaper actually ships"
shipped="$(find wallpapers -maxdepth 1 -type f \
           \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) 2>/dev/null | head -1)"
if [[ -n "$shipped" ]]; then
    pass "$(basename "$shipped")"
else
    bad "wallpapers/ has no image — a fresh machine has nothing to seed from"
fi

# ⚠️ AND IT HAS TO STAY SMALL. The original was 6.3 MB; the shell loads it
# through `sourceSize` regardless, so the bytes bought nothing and every clone
# paid for them. 2 MB is the ceiling, not the target.
printf '  %-34s ' "and it is not a 6 MB photograph"
if [[ -z "$shipped" ]]; then
    bad "nothing to weigh"
else
    bytes="$(stat -c%s "$shipped")"
    if [[ "$bytes" -le 2097152 ]]; then
        pass "$((bytes / 1024)) KiB"
    else
        bad "$((bytes / 1024)) KiB — over the 2048 KiB ceiling"
    fi
fi

# ⚠️ AND THE INSTALLER MUST NOT CALL ZERO FILES A SUCCESS. Static, because the
# real thing needs a whole install run: the line that reports the count has to
# look at the count first.
printf '  %-34s ' "zero copied wallpapers is a warning"
if grep -q 'no wallpapers copied from' lib/60-shell.sh; then
    pass "reported"
else
    bad "lib/60-shell.sh still reports ok regardless of how many arrived"
fi

# ⚠️ AND THE EMERGENCY STATE MUST BE ESCAPABLE. A second install run used to
# fill in only `wallpaper.folder`, so a machine seeded green stayed green for
# ever no matter how many pictures were added afterwards.
printf '  %-34s ' "the empty fallback can be undone"
if grep -q 'picked up where the empty fallback left off' lib/60-shell.sh; then
    pass "a later run picks it up"
else
    bad "nothing in lib/60-shell.sh recovers a machine seeded with no pictures"
fi

# ⚠️ AND CHOOSING A PICTURE HAS TO BRING THE COLOURS. `choose()` wrote
# wallpaper.current and paletteFrom and never theme.palette, so on any of the
# eleven fixed palettes a new wallpaper changed the picture and nothing else.
printf '  %-34s ' "choosing a wallpaper recolours"
if grep -q 'Config.theme.palette = "wallpaper"' shell/services/Wallpaper.qml; then
    pass "choose() switches the scheme back on"
else
    bad "Wallpaper.choose() never writes theme.palette — picture changes, colours do not"
fi

exit $fail
