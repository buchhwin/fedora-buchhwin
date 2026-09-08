#!/usr/bin/env bash
#
# A scroll indicator is never a child of the Flickable it reports on.
#
# ⚠️⚠️ WRITTEN AFTER IT SHIPPED THAT WAY TWICE IN ONE FILE. Both bars in the
# settings window — the content pane's and the page sidebar's — were declared
# inside their Flickable. A direct child of a Flickable is handed to its
# `contentItem`, which is THE THING THAT MOVES, so the bar's position on screen
# is `y - contentY`. With the usual `y: contentY * (viewport/content)` that comes
# out as `contentY * (ratio - 1)`: negative, and growing more negative as you
# scroll. The bar climbs out of the top of the view instead of tracking it.
#
# He reported it as "der strich da bewegt sich nicht der geht noch nicht", and    # english-ok: the report, quoted
# it is the worst shape a fault can take here: the thing is visible at rest, so
# it looks built. Nothing in the log, nothing in any other suite.
#
# ⚠️ AND IT WAS WRITTEN TWICE, IDENTICALLY. That is why the fix is one component
# in ui/common/ and why this check exists rather than two corrected copies: a
# copy is a place for the next person to reintroduce it.
#
# ⚠️ THE CHECK IS ON DEPTH, NOT ON PROXIMITY. "ScrollIndicator appears a few
# lines after Flickable" would pass the correct sibling form and fail nothing —
# the two shapes are distinguished only by which brace they are inside.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
files=0

# ⚠️ mapfile, not an unquoted $(find …) — SC2044, and this repo has walked into
# that one with the warning already written in the file.
mapfile -t list < <(find shell/ui -name '*.qml' -type f | sort)

if (( ${#list[@]} == 0 )); then
    echo "  found no QML under shell/ui — this check was measuring nothing"
    exit 2
fi

for f in "${list[@]}"; do
    files=$((files + 1))
    # ⚠️ `_` FOR THE HALF THAT IS NOT USED, not a name. The awk below prints
    # `line:text`, and only the line number is reported — but a named second
    # variable is an unused variable, which shellcheck reports as SC2034 and the
    # CI treats as a failure. `_` is the one name it accepts for "read this and
    # throw it away", and dropping the field entirely is wrong: without it the
    # first variable would swallow the whole line, colon and text included.
    while IFS=: read -r line _; do
        [[ -n "${line:-}" ]] || continue
        printf '  \033[38;5;203mFAIL\033[0m  %s:%s  ScrollIndicator inside the Flickable\n' \
               "$f" "$line"
        fail=1
    done < <(
        awk '
            # Strip line comments so a paragraph about the bug is not the bug.
            { code = $0; sub(/\/\/.*/, "", code) }

            # Remember the depth at which each open Flickable sits, so the block
            # can be recognised on the way out again.
            {
                if (code ~ /(^|[^A-Za-z_])Flickable[[:space:]]*\{/) {
                    flickdepth[depth] = 1
                    inflick++
                }
                opens  = gsub(/\{/, "{", code)
                closes = gsub(/\}/, "}", code)

                # A ScrollIndicator declared while any Flickable block is open —
                # and not itself the line that opened one — is the fault.
                if (inflick > 0 && $0 ~ /ScrollIndicator[[:space:]]*\{/)
                    print NR ":" $0

                depth += opens - closes
                # Leaving a block: drop any Flickable that lived at this depth.
                if (closes > opens && flickdepth[depth]) {
                    delete flickdepth[depth]
                    inflick--
                }
            }
        ' "$f"
    )
done

if (( fail )); then
    cat <<'EOF'

  Put it beside the Flickable, not in it:

      Item {
          Flickable { id: scroller; anchors.fill: parent; … }
          ScrollIndicator { flickable: scroller }
      }

  Inside, it is a child of the contentItem and scrolls away with the content.
EOF
    exit 1
fi

printf '  no scroll indicator is trapped inside its own Flickable (%d files)\n' "$files"
