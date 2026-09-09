#!/usr/bin/env bash
#
# No `property var` inside a nested JsonObject.
#
# ⚠️ THIS IS A CRASH TRIPWIRE, NOT A STYLE RULE. quickshell segfaulted on
# roughly half of every start for at least a week, always with the same
# backtrace:
#
#   QV4::QObjectWrapper::wrap
#   QQmlVMEMetaObject::writeProperty
#   QMetaProperty::write
#   qs::io::JsonAdapter::deserializeRec      <- TWICE: a nested object
#   qs::io::JsonAdapter::deserializeAdapter
#   qs::io::FileViewAdapter::onDataChanged
#
# Bisected on the machine, one config key at a time, twelve runs each:
#
#   {}                                    0/10 crashes
#   {"keys":{}}                           0/10
#   {"keys":{"binds":[]}}                 6/12   <- var, NESTED
#   {"keys":{"binds":[ …63 objects… ]}}   4/12   <- var, NESTED
#   {"outputs":[ …the same 63 objects… ]} 0/12   <- var, TOP LEVEL
#   {"autostart":["nm-applet"]}           0/10   <- list<string>
#   {"windows":{"blurred":["kitty"]}}     0/12   <- list<string>, nested
#
# An EMPTY nested list is enough, so it is neither the length nor the contents.
# It is writing a `var` property that lives inside a nested JsonObject. Moving
# `binds` to the top level took the same configs from 6/12 to 0/12.
#
# `list<string>` is safe at any depth — it has a real element type and never
# goes through QObjectWrapper::wrap.
#
# ⚠️ THIS USED TO SAY "list<string> and list<int>", AND THE list<int> HALF WAS
# WRONG. It is true that a numeric list does not CRASH, which is what this
# paragraph is about — but it does not work either, and the third check at the
# bottom of this file is what came of finding that out.
#
# So: a `var` in the adapter belongs at the TOP LEVEL. This checks that, because
# the alternative is rediscovering it with another week of "sometimes it does not
# come up".
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

file=shell/config/Config.qml
printf '  %-34s ' "no nested 'property var'"

# Depth is counted in `JsonObject {` openings after the adapter starts. The
# adapter's own body is depth 1, so anything deeper is nested.
bad="$(awk '
    /JsonAdapter[ \t]*\{/            { inadapter = 1 }
    !inadapter                       { next }
    /property JsonObject [A-Za-z_]+: JsonObject \{/ { depth++ ; next }
    /^[ \t]*\}/                      { if (depth > 0) depth-- }
    /^[ \t]*property var [A-Za-z_]+/ {
        if (depth > 0) printf "%s:%d %s\n", FILENAME, NR, $0
    }
' "$file")"

if [[ -n "$bad" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "$bad"
    cat <<'WHY'

  A `property var` inside a nested JsonObject makes quickshell segfault when the
  file supplies that key — about half the time, and it recovers on its own, so
  it looks like "sometimes the shell does not come up" rather than like a bug.

  Two ways out, both fine:
    * move it to the top level of the adapter, next to `binds` and `outputs`
    * give it a real element type — list<string>, and ONLY list<string>; see
      the third check below for why a numeric list is not an option

  Moving a key needs a migration; see shell/config/Migrations.qml step 5 -> 6,
  which is the one this check was written for.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
# Every section of the adapter is reachable as `Config.<name>`.
#
# ⚠️ ALSO A TRIPWIRE, AND IT COST A ROUND. The adapter's sections are private:
# what the rest of the shell sees is the list of `readonly property alias` lines
# at the top of Config.qml. Add a section and forget the alias, and
# `Config.brightness` is not an error — it is `undefined`, so `Config.brightness
# .external` is `TypeError: Cannot read property 'external' of undefined`, at
# runtime, in whichever file happened to read it first. It looks like a bug in
# the reader.
#
# Caught here rather than by reading carefully, because "read carefully" is what
# was already being done the time it slipped through.
printf '  %-34s ' "every section has an alias"

missing=""
while read -r name; do
    grep -qE "readonly property alias $name: adapter\.$name\b" "$file" || missing+="$name"$'\n'
done < <(awk '
    /JsonAdapter[ \t]*\{/ { inadapter = 1 }
    !inadapter            { next }
    # depth 0 inside the adapter body is where the sections live
    /property JsonObject [A-Za-z_]+: JsonObject \{/ {
        # `property JsonObject brightness: JsonObject {` -> field 3, colon off
        if (depth == 0) { n = $3; sub(/:$/, "", n); print n }
        depth++ ; next
    }
    /^[ \t]*\}/ { if (depth > 0) depth-- }
' "$file")

if [[ -n "$missing" ]]; then
    printf '\033[38;5;203mmissing\033[0m\n'
    sed 's/^/      Config./' <<< "${missing%$'\n'}"
    cat <<'WHY'

  These sections exist in the adapter but nothing exposes them. Add one line
  each to the block at the top of shell/config/Config.qml:

      readonly property alias <name>: adapter.<name>

  Without it the section is not missing, it is `undefined` — and the error
  surfaces in whatever reads it, which is never where the mistake is.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
# No list of numbers anywhere in the adapter.
#
# ⚠️ MEASURED, AND IT CONTRADICTS WHAT THE TOP OF THIS FILE USED TO SAY.
# The note above claims "list<string> and list<int> are safe at any depth". That
# is true of CRASHING — a numeric list does not segfault. It also does not work.
# JsonAdapter cannot deserialise one at all:
#
#   list<string> nested (windows.blurred)   0 warnings
#   list<string> top level (autostart)      0 warnings
#   list<int>    nested (timer.presets)     1 warning
#   list<int>    top level                  1 warning
#   list<real>   nested                     1 warning
#
#   "Failed to deserialize property presets: expected QList<int> but got
#    QVariantList"
#
# So it is the type, not the depth, and it fails for a VALID list as much as for
# a null one. `timer.presets` was the only one, and every preset anybody wrote
# in shell.json was being thrown away in favour of the defaults, with one line
# in the journal as the only sign. Strings, converted at the reader.
# ⚠️ AND EVERY GROUP IS DOCUMENTED. docs/CONFIG.md carried eighteen of the
# twenty-nine top-level groups, so nine of them — cursor, gpu, brightness,
# clock, motion, media, lock, terminal, clipboard — were settable, had rows in
# the settings window, and appeared in no document at all. That is the sort of
# gap nobody trips over: the code works perfectly and the reader concludes the
# feature does not exist.
# ⚠️ A DEFAULT THAT NAMES SOMETHING ON THE MACHINE MUST BE SOMETHING WE PUT
# THERE. `cursor.theme` shipped as "Breeze_Dark" with a comment claiming it
# "ships with Fedora's breeze-cursor-theme" — a package that appears in none of
# the lists under packages/. So every fresh machine handed the compositor a theme name
# that does not resolve, the compositor fell back to its own pointer at its own size, and
# it was reported as "the cursor is far too big and cannot be changed".
#
# The check is deliberately about what the INSTALLER provides, not about what
# happens to be on the machine running the test: a CI container has no cursor
# themes at all, so asking /usr/share/icons here would be green for the wrong
# reason on every runner and red for the wrong reason on a workstation.
printf '  %-38s ' "the cursor default is one we install"
curdef="$(grep -A1 'property JsonObject cursor:' "$file" \
          | grep -oE 'property string theme: "[^"]+"' | grep -oE '"[^"]+"' | tr -d '"')"
[[ -n "$curdef" ]] || curdef="$(sed -n '/property JsonObject cursor:/,/^            }/p' "$file" \
                                | grep -oE 'property string theme: "[^"]+"' \
                                | grep -oE '"[^"]+"' | tr -d '"')"
if [[ -z "$curdef" ]]; then
    printf '\033[38;5;203mcould not read the default\033[0m\n'; exit 1
# ⚠️ MENTIONED IS NOT INSTALLED, and the first version of this check could not
# tell the difference: a plain `grep -r` matched the WARNING in lib/50-fonts.sh
# that says "Breeze_Dark stays the pointer", so the control stayed green with
# the exact fault it was written to catch. Two precise forms instead:
#   - the installer places a directory of that name (a slash before it), or
#   - an uncommented package line names a cursor package
elif grep -qF "/$curdef" lib/*.sh 2>/dev/null; then
    printf '\033[38;5;114mok\033[0m  %s (the installer places it)\n' "$curdef"
# ⚠️ THE THIRD ANSWER, AND IT IS A MEASUREMENT RATHER THAN A GUESS.
# The installer no longer places any cursor directory: the phase that fetched a
# third-party tarball is gone, and the pointer comes from the KDE base like
# everything else. So the branch above can never be true again, and the branch
# below would fail a default that is genuinely installed.
#
# What can be said honestly is which names a package is KNOWN to provide, and
# the note under this block already records it, measured on the machine:
# breeze-cursor-theme contains Breeze_Light and breeze_cursors.
#
# ⚠️ TWO NAMES, AND IT STAYS TWO. A general "a cursor package is installed"
# rule is what version two of this check did, and it passed Breeze_Dark — a
# name that package does not contain. Every entry here has to name both the
# theme and the package, and be something somebody actually looked at.
elif [[ "$curdef" == "breeze_cursors" || "$curdef" == "Breeze_Light" ]] \
     && grep -qxF "breeze-cursor-theme" packages/*.txt 2>/dev/null; then
    printf '\033[38;5;114mok\033[0m  %s (breeze-cursor-theme provides it)\n' "$curdef"
# ⚠️ AND "A CURSOR PACKAGE IS INSTALLED" WAS NOT GOOD ENOUGH EITHER — that was
# the second version of this check and the control caught it too. packages/
# does list `breeze-cursor-theme`, so the test went green for `Breeze_Dark`
# again. Measured on his laptop: that package is installed and it contains
# `Breeze_Light` and `breeze_cursors`. THERE IS NO Breeze_Dark IN IT. A package
# being present says nothing about which names it provides, and the repository
# cannot know that — so the only claim this file can honestly make is the one
# above: we place a directory of that name ourselves.
else
    printf '\033[38;5;203m%s is installed by nothing under lib/ or packages/\033[0m\n' "$curdef"
    printf '      Naming it in a comment is not installing it. That is exactly how\n'
    printf '      Breeze_Dark shipped as the default to machines that never had it,\n'
    printf '      where the compositor fell back to its own pointer at its own size.\n'
    exit 1
fi

printf '  %-38s ' "every config group is in docs/CONFIG.md"
undoc=""
while read -r g; do
    [[ -n "$g" ]] || continue
    grep -qE "^\| \`$g\`|^\| \`[a-z]+\` / \`$g\`|/ \`$g\` /|/ \`$g\` \|" docs/CONFIG.md || undoc+=" $g"
done < <(grep -oE '^ *readonly property alias [a-z]+:' "$file" | awk '{print $4}' | tr -d ':')
if [[ -z "$undoc" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mnot documented:%s\033[0m\n' "$undoc"
    exit 1
fi

# ⚠️⚠️ AND THE OTHER DIRECTION, WHICH NOTHING WAS ASKING. The check above is a
# subset test: every group in the schema has to appear in docs/CONFIG.md. It
# says nothing about a document that names a setting the schema no longer has,
# and that is the half that had rotted — `vscode`, `vesktop` and `spicetify`
# were documented as theming targets, one of them with its own table and two
# paragraphs of measured detail, months after all three were removed with the
# applications they coloured. Config.qml kept their comments too, and one of
# them had lost its property and started a sentence mid-thought.
#
# A setting that is documented and does not exist is worse than one that exists
# undocumented: the reader writes it into shell.json, the adapter drops it,
# nothing happens and nothing says why.
#
# The theming block is the one place with a name per program, so it is the one
# place where the two lists can be compared exactly rather than by heuristic.
# docs/CONFIG.md carries the line "Targets: `gtk` `qt` …" for that purpose.
printf '  %-38s ' "the theming targets match the document"
schema_targets="$(sed -n '/property JsonObject theming:/,/^            }$/p' "$file" \
                  | grep -oE '^ *property string [a-z]+:' | awk '{print $3}' | tr -d ':' \
                  | grep -vxE 'mode' | sort)"
doc_targets="$(grep -E '^Targets: ' -A2 docs/CONFIG.md \
               | grep -oE '`[a-z]+`' | tr -d '`' | sort -u)"

if [[ -z "$schema_targets" ]]; then
    printf '\033[38;5;203mcould not read the theming block\033[0m\n'; exit 1
elif [[ -z "$doc_targets" ]]; then
    printf '\033[38;5;203mdocs/CONFIG.md has no "Targets:" line any more\033[0m\n'; exit 1
elif [[ "$schema_targets" != "$doc_targets" ]]; then
    printf '\033[38;5;203mthey differ\033[0m\n'
    comm -23 <(printf '%s\n' "$schema_targets") <(printf '%s\n' "$doc_targets") \
        | sed 's/^/      in the schema, not in the document: /'
    comm -13 <(printf '%s\n' "$schema_targets") <(printf '%s\n' "$doc_targets") \
        | sed 's/^/      documented, and not a setting: /'
    exit 1
else
    printf '\033[38;5;114mok\033[0m  %s\n' "$(printf '%s\n' "$schema_targets" | wc -l | tr -d ' ') targets"
fi

printf '  %-34s ' "no list<int>/list<real>"

numeric="$(grep -nE 'property list<(int|real|double|float)>' "$file" || true)"

if [[ -z "$numeric" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
    exit 0
fi

printf '\033[38;5;203mfound\033[0m\n'
sed 's/^/      /' <<< "$numeric"
cat <<'WHY'

  JsonAdapter cannot read these back. The key will appear to work — the default
  is used and the shell runs — but nothing anybody writes in shell.json ever
  reaches it.

  Use `list<string>` and convert at the reader, as timer.presets does, and add a
  migration so existing numbers become their own text instead of being lost.
WHY
exit 1
