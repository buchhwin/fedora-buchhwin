#!/usr/bin/env bash
#
# A workspace is labelled by its INDEX, never by its name.
#
# ⚠️ THIS CHECK EXISTS BECAUSE THE SAME FAULT WAS REPORTED TWICE.
#
# `Config.workspaces` names the first workspace "scratch", because `Super+Ö`
# focuses it by name. Any surface that prints `ws.name` when it has one
# therefore prints a WORD where every other slot has a number.
#
#   first report   "das erste ist gar keine zahl sondern irgend ein wort"     # english-ok: the report, quoted
#                  → ui/bar/BarContent.qml fixed, August
#   second report  "bei alt tab ist 1 nicht eins sondern irgenein wort mit s" # english-ok: the report, quoted
#                  → ui/notch/pages/WorkspacesPage.qml, the same fault, still
#                    there, because the rule lived in a COMMENT IN ONE FILE.
#
# A comment is not a tripwire. This is.
#
# A row or a map of workspaces is a POSITION indicator — "you are on the second
# of three" — and a word in the first slot destroys that at a glance, because
# the eye can no longer count. The name still exists and `focus-workspace
# scratch` still works; it is just not what a label is for.
#
# A surface that genuinely wants the name — a list where the name IS the
# subject, not the position — says so on the line:
#
#     text: ws.name        // wsname-ok: a chooser, not a position indicator
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0

# ⚠️ ONLY WHERE IT IS BEING DISPLAYED. `focus-workspace scratch` passes the name
# to the compositor and is exactly right; the fault is putting it on screen next to
# numbers. So the subject is an assignment to `text:`, not every mention of
# `name` in the tree.
while IFS=: read -r file line text; do
    [[ -z "${line:-}" ]] && continue
    [[ "$text" == *"wsname-ok"* ]] && continue
    printf '  \033[38;5;203m%s\033[0m  %s\n' "workspace-name  $file:$line" \
           "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-60)"
    fail=1
done < <(grep -rn -E '^[[:space:]]*text:.*\bws\.name\b|^[[:space:]]*text:.*\bworkspace\.name\b' \
              shell/ui 2>/dev/null)

# The other half, and it is the shape the fault actually had: a conditional that
# prefers the name and falls back to the index. It spans two lines in the file
# it was found in, so the match is on the ternary's own text rather than on one
# line of it.
while IFS=: read -r file line text; do
    [[ -z "${line:-}" ]] && continue
    [[ "$text" == *"wsname-ok"* ]] && continue
    printf '  \033[38;5;203m%s\033[0m  %s\n' "name-then-index  $file:$line" \
           "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-60)"
    fail=1
done < <(grep -rn -E '\.ws\.name[[:space:]]*$|\.ws\.name[[:space:]]*\?' shell/ui 2>/dev/null)

if (( fail )); then
    cat <<'EOF'

  A workspace label reads its INDEX. The first workspace is named "scratch" so
  that Super+Ö can focus it by name, and a surface that prefers the name prints
  "scratch 2 3" — which is the bug this file is named after, reported twice.

  Use `ws.idx`. If the name really is the subject rather than the position, say
  so on the line with  // wsname-ok: <reason>
EOF
    exit 1
fi

echo "  every workspace label reads its index, not its name"
