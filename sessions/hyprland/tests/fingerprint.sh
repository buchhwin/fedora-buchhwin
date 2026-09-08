#!/usr/bin/env bash
#
# Every setting a generator reads is in the watcher's fingerprint.
#
# ⚠️ THE RULE EXISTED FOR WEEKS AND WAS BROKEN TWENTY-EIGHT TIMES. The note in
# services/Theming.qml asked whoever adds a key to remember. Nobody remembers.
# Counted on 07.08.2026: the whole `input` block (18), all six `programs`, plus
# `keys.mod`, `binds`, `motion.speed` and `theming.vscode`.
#
# What that MEANT, measured rather than argued: change the keyboard layout or
# switch off tap-to-click in the settings window, wait, and config.kdl is not
# rewritten. The row wrote the file and nothing regenerated, so the setting did
# nothing until something unrelated happened to move the fingerprint. On the
# settings pages that is most of System and half of Motion.
#
# ⚠️ AND THE OTHER DIRECTION IS NOT COSMETIC. Three entries were in the
# fingerprint that no generator reads. Each cost a full render over thirteen
# foreign config files plus a `niri validate` on every drag of a slider, for a
# result that was byte-identical by construction — on a laptop. Worse,
# tests/key-readers.sh counts an occurrence in the fingerprint AS A READER, so
# those three passed that check on its own blind spot.
#
# ⚠️ TWO INDIRECTIONS HAVE TO BE RESOLVED OR THIS FINDS NOTHING:
#
#   Theme.*    the generators read `Theme.durBase`, not `motion.speed`. A check
#              that only looked for `Config.` would have missed the one hole
#              nobody could have found by reading.
#   aliases    `var L = Config.look` and then `L.gapsOut` — the generators do
#              this everywhere, and so does the fingerprint itself.
#
# Plus one string lookup: niri.qml resolves `@terminal` through
# Config.program(), which no search for an identifier can see. The rule is
# single-valued — if a generator calls Config.program(), it reads all of
# `programs.*` — and it is the same convention key-readers.sh already uses.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v python3 >/dev/null || { echo "python3 not installed"; exit 2; }

out="$(python3 - <<'PY'
import re, sys

def strip_comments(text):
    # Whole comment lines only. A trailing `// …` after code stays: a key named
    # beside a line of code is almost always named BY that line as well.
    return "\n".join("" if re.match(r'^\s*//', ln) else ln for ln in text.splitlines())

def read(path):
    return strip_comments(open(path).read())

# ------------------------------------------------- what a setting actually is
#
# ⚠️ EVERY CANDIDATE IS CHECKED AGAINST Config.qml, and that is what makes this
# robust rather than clever. A regex over QML also finds `look.toFixed` and
# `autostart.length` — JS methods on a value that happens to come from a config
# section. Intersecting with the real adapter paths removes all of them without
# a denylist that would need maintaining, and it cannot hide a real setting:
# something that is not a path in Config.qml is not a setting.
#
# Same brace-counting walk as tests/setting-rows.sh, for the same reason:
# `input` nests a second level.
def config_paths():
    src = read("shell/config/Config.qml").splitlines()
    paths, stack, depth, inside = [], [], 0, False
    pend = pend_depth = None
    sec = re.compile(r'property\s+JsonObject\s+([A-Za-z_]\w*)\s*:')
    leaf = re.compile(r'property\s+(?:list<[a-z]+>|[a-z]+)\s+([A-Za-z_]\w*)\s*:')
    for line in src:
        if not inside:
            if 'JsonAdapter' in line and '{' in line:
                inside, depth = True, 0
            continue
        m = sec.search(line)
        if m:
            pend, pend_depth = m.group(1), depth
        else:
            m2 = leaf.search(line)
            if m2:
                paths.append('.'.join(stack + [m2.group(1)]))
        for _ in range(line.count('{')):
            depth += 1
            if pend is not None and depth == pend_depth + 1:
                stack.append(pend); pend = None
        for _ in range(line.count('}')):
            if stack and len(stack) == depth:
                stack.pop()
            depth -= 1
    return set(paths)

VALID = config_paths()
if not VALID:
    print("PARSE could not read Config.qml")
    sys.exit(0)

# `version` is the migration stamp; the generators only log it.
VALID.discard("version")

# ---------------------------------------------------------------- Theme/Scheme
# Theme.<prop> / Scheme.<prop> -> the Config paths it depends on, transitively,
# so `Theme.durBase` resolves through `animate` and `motionSpeed` to
# `look.profile` and `motion.speed`. Without this step the one hole nobody could
# have found by reading stays invisible.
def singleton_map(path, name):
    src = read(path)
    props, cur, body = {}, None, []
    for ln in src.splitlines():
        m = re.match(r'\s*(?:readonly\s+)?property\s+\S+\s+([A-Za-z_]\w*)\s*:(.*)', ln)
        isfn = re.match(r'\s*function\s+[A-Za-z_]', ln)
        if m or isfn:
            if cur:
                props[cur] = "\n".join(body)
            cur, body = (m.group(1), [m.group(2)]) if m else (None, [])
        elif cur is not None:
            body.append(ln)
    if cur:
        props[cur] = "\n".join(body)

    # ⚠️ WHAT IS NOT IN A PROPERTY STILL COUNTS. Scheme reads the light/dark
    # schedule inside functions and timers, not in a binding — so a walk that
    # only looked at properties reported `theme.autoLight` and its three
    # neighbours as watched-for-nothing, when they are exactly what decides
    # which palette the renderer is handed. Everything outside a property is
    # folded into every property of that singleton: coarse, and coarse in the
    # safe direction — a wrongly-included key costs a render, a wrongly-excluded
    # one costs a setting that does nothing.
    shared = paths_in("\n".join(
        ln for ln in src.splitlines()
        if not re.match(r'\s*(?:readonly\s+)?property\s+\S+\s+[A-Za-z_]\w*\s*:', ln)))
    direct = {k: paths_in(v) | shared for k, v in props.items()}
    refs = {k: set(re.findall(name + r'\.([A-Za-z_]\w*)', v)) for k, v in props.items()}
    for _ in range(8):
        changed = False
        for k in props:
            for r in refs[k]:
                if r in direct and not direct[r] <= direct[k]:
                    direct[k] |= direct[r]; changed = True
        if not changed:
            break
    return direct

# ⚠️ ALIASES, AND BOTH SHAPES OF THEM. `var t = Config.theme, l = Config.look`
# assigns three in one statement — a regex anchored on `var` finds only the
# first, which is how `look.*` looked unwatched when it was there all along.
# And `var k = Config.input.keyboard` is an alias for a two-level path, so the
# target has to be kept whole.
ALIAS = re.compile(r'([A-Za-z_]\w*)\s*=\s*Config\.([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)')

def paths_in(src):
    found = set()
    aliases = {}
    for a, target in ALIAS.findall(src):
        aliases[a] = target
    # an alias of an alias: `var t = Config.input.touchpad` is direct, but
    # `var i = Config.input` then `var t = i.touchpad` is not.
    for a, target in list(aliases.items()):
        for b, mid in re.findall(r'([A-Za-z_]\w*)\s*=\s*' + a + r'\.([A-Za-z_]\w*)', src):
            aliases.setdefault(b, target + "." + mid)
    for a, target in aliases.items():
        for lf in re.findall(r'\b' + re.escape(a) + r'\.([A-Za-z_]\w*)', src):
            found.add(target + "." + lf)
        found.add(target)
    for p in re.findall(r'Config\.([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)', src):
        found.add(p)
    return {p for p in found if p in VALID}

THEME = singleton_map("shell/theme/Theme.qml", "Theme")
SCHEME = singleton_map("shell/theme/Scheme.qml", "Scheme")

def keys_in(src):
    found = paths_in(src)
    # ⚠️ The one lookup no identifier search can see: niri.qml resolves
    # "@terminal" through Config.program(), whose argument is a variable.
    if "Config.program(" in src:
        found |= {p for p in VALID if p.startswith("programs.")}
    for pref, table in (("Theme", THEME), ("Scheme", SCHEME)):
        for prop in re.findall(pref + r'\.([A-Za-z_]\w*)', src):
            found |= table.get(prop, set())
    return found

readers = keys_in(read("shell/tools/niri.qml")) | keys_in(read("shell/tools/render.qml"))

# ------------------------------------------------------------ the fingerprint
fp_src = read("shell/services/Theming.qml")
m = re.search(r'readonly property string fingerprint:\s*\{(.*?)\n    \}', fp_src, re.S)
if not m:
    print("PARSE could not find the fingerprint block")
    sys.exit(0)

# ⚠️ EACH BLOCK IS RESOLVED ON ITS OWN, NOT CONCATENATED, because an alias is
# scoped to the property it is declared in — and two of them collide by name:
# `t` is `Config.theme` in the fingerprint and `Config.input.touchpad` in
# inputPrint. Joined into one string the first wins, `t.tap` reads as
# `theme.tap`, that is not a real path, and all eight touchpad keys quietly
# vanish from the watched set. Which is precisely the shape of bug this file
# exists to find, so it would have been an unusually poor place to have one.
blocks = [m.group(1)]
for name in re.findall(r'root\.([A-Za-z_]\w*)\b', m.group(1)):
    hm = re.search(r'property\s+\S+\s+' + name + r':\s*\{(.*?)\n    \}', fp_src, re.S)
    if hm:
        blocks.append(hm.group(1))

fp = set()
for b in blocks:
    fp |= keys_in(b)

missing = sorted(readers - fp)
extra = sorted(fp - readers)
print("READERS %d" % len(readers))
for k in missing:
    print("MISSING " + k)
for k in extra:
    print("EXTRA " + k)
PY
)"

if grep -q '^PARSE' <<< "$out"; then
    printf '  %-34s ' "the fingerprint is complete"
    printf '\033[38;5;203mcannot read\033[0m\n'
    sed 's/^/      /' <<< "$out"
    exit 1
fi

missing="$(grep '^MISSING ' <<< "$out" | sed 's/^MISSING //')"
extra="$(grep '^EXTRA ' <<< "$out" | sed 's/^EXTRA //')"
count="$(grep '^READERS ' <<< "$out" | awk '{print $2}')"

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "every generated key is watched"

if [[ -n "$missing" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "$missing"
    cat <<'WHY'

  A generator reads these and the watcher does not know they exist. Changing one
  writes shell.json and regenerates nothing, so the setting does nothing until
  something unrelated happens to move the fingerprint — which is
  indistinguishable from a control that is broken.

  Add them to `fingerprint` in shell/services/Theming.qml. If a key genuinely
  must not trigger a render, say so there in words; there is no exemption list
  here on purpose, because every exemption this rule ever had turned out to be
  a bug.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m  %s keys\n' "$count"

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "nothing is watched for nothing"

if [[ -n "$extra" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "$extra"
    cat <<'WHY'

  These are in the fingerprint and no generator reads them. Every one costs a
  full render over thirteen foreign config files plus a `niri validate` on every
  change — for a result that is byte-identical by construction. On a laptop.

  They also hide from tests/key-readers.sh, which counts an occurrence in the
  fingerprint as a reader.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'
