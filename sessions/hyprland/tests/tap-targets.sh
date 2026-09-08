#!/usr/bin/env bash
#
# The third tripwire: no TapHandler inside a Pill.
#
# `Pill` hands whatever it is given to an inner Item sized to `childrenRect`, so
# a TapHandler written inside a Pill attaches to THAT — not to the pill. The
# hover highlight still covers the whole pill, so the thing lights up under the
# pointer and then ignores the click everywhere except on the letters.
#
# Measured on the quick panel's "Media" tab before this was fixed: the pill was
# 68 x 29 px and the tap target 44 x 21, leaving 1050 px² — more than half of
# it — lit and dead. It was reported as "I click it and nothing happens", which
# is exactly what it was, and it had been that way in every Pill in the shell.
#
# Pill now carries `clicked` and `rightClicked` of its own, so call sites write
# `onClicked:` and there is nothing to get wrong. This is what stops the old
# shape coming back the next time somebody adds a button in a hurry.
#
# ⚠️ It is a structural check, not a taste one. TapHandler is right and normal on
# a Rectangle, an Item or a delegate; the fault is specifically a handler in a
# container that re-parents its children.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0

# Same fallback as tests/english.sh, and for the same reason: the working copy
# on the test machine has no .git, and a check that cannot enumerate there is a
# check that never runs where the code runs.
# ⚠️ `--others --exclude-standard` IS NOT OPTIONAL. Plain `git ls-files` lists
# TRACKED files only, so a brand-new file — the most likely place for a mistake
# to be — is silently left out. Found on 07.08.2026 when a new shell/common/
# singleton became the sole reader of four settings and key-readers.sh reported
# all four as having none: the advice it printed was "delete the key", which
# would have deleted four working settings. Untracked-but-not-ignored is the
# corpus that matches what is actually on disk.
files=$(git ls-files --cached --others --exclude-standard \
               'shell/ui/*.qml' 'shell/ui/**/*.qml' 2>/dev/null)
[[ -n "$files" ]] || files=$(find shell/ui -name '*.qml' -type f 2>/dev/null)
[[ -n "$files" ]] || { echo "  found no ui files to check"; exit 2; }

# Brace depth, the same technique tests/icons.sh uses to find Icon { } blocks:
# remember the depth at which a Pill opened, report any TapHandler seen before
# the depth comes back down, and forget the pill again on the way out.
while IFS=: read -r file line text; do
    [[ -z "${line:-}" ]] && continue
    printf '  \033[38;5;203m%s\033[0m  %s\n' "tap-in-pill  $file:$line" \
           "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-60)"
    fail=1
done < <(
    # shellcheck disable=SC2086  # a deliberately word-split file list
    awk '
        FNR == 1 { depth = 0; pill = -1 }
        {
            bare = $0
            sub(/^[[:space:]]*/, "", bare)
            if (bare ~ /^\/\//) next

            if (pill < 0 && match($0, /(^|[^A-Za-z])Pill[[:space:]]*\{/))
                pill = depth
            else if (pill >= 0 && $0 ~ /TapHandler[[:space:]]*\{/)
                printf "%s:%d:%s\n", FILENAME, FNR, $0

            n = gsub(/\{/, "{"); depth += n
            n = gsub(/\}/, "}"); depth -= n
            if (pill >= 0 && depth <= pill) pill = -1
        }
    ' $files
)

if (( fail )); then
    cat <<'EOF'

  A TapHandler declared inside a Pill attaches to the Pill's inner Item, which
  is only as big as its contents — so most of the pill highlights on hover and
  ignores the click. Use the pill's own signals instead:

      Pill {
          interactive: true
          BarText { text: "Media" }
          onClicked: doTheThing()          // and onRightClicked for a menu
      }
EOF
    exit 1
fi

echo "  no tap handlers hidden inside a Pill"

# ---------------------------------------------------------------------------
# The other half of the same fault: a surface that is lit and answers nothing.
#
# ⚠️ THIS ONE SHIPPED. The notch's click used to live in a status pill inside
# NotchWide.qml. The brief changed to "the whole hovered notch opens the quick
# panel", the pill was deleted — and no handler took its place. The result was a
# release in which clicking the notch did nothing whatsoever, and nothing went
# red, because every check in this repo asks whether a target is big enough and
# none asked whether there was one at all.
#
# The island is the drawn shape of the notch. If it has no handler, the notch is
# decoration.
surface="shell/ui/surface/ShellSurface.qml"
if [[ ! -f "$surface" ]]; then
    echo "  cannot find $surface"
    exit 2
fi

# Same brace-depth walk as above: find `id: island`, remember the depth its
# block opened at, and look for a TapHandler before that depth closes again.
if awk '
    {
        bare = $0
        sub(/^[[:space:]]*/, "", bare)
        if (bare ~ /^\/\//) next

        # The opening brace of the island block is on the line above `id:`, so
        # arm on the id and take the depth as it stands.
        if (!armed && bare ~ /^id:[[:space:]]*island[[:space:]]*$/) {
            armed = 1
            base = depth
        }
        if (armed && $0 ~ /TapHandler[[:space:]]*\{/) { found = 1; exit }

        n = gsub(/\{/, "{"); depth += n
        n = gsub(/\}/, "}"); depth -= n
        if (armed && depth < base) exit
    }
    END { exit(found ? 0 : 1) }
' "$surface"; then
    echo "  the notch itself answers a click"
else
    cat <<'EOF'
  the notch has no click receiver

  There is no TapHandler inside `Item { id: island }` in
  shell/ui/surface/ShellSurface.qml, so a click on the notch does nothing.

  The island is the drawn shape, so a handler on it can never be narrower than
  what is lit. Do not put it back inside a child: the brief is that clicking
  ANYWHERE on the hovered notch opens the quick panel.

      Item {
          id: island
          TapHandler {
              enabled: root.mode === "wide" || root.mode === "full"
              onTapped: Ipc.toggle("quick")
          }
      }
EOF
    exit 1
fi
