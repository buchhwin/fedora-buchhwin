#!/usr/bin/env bash
#
# The tripwire.
#
# "Everything looks like one system" is not a thing you decide once — it is a
# thing that decays. The old project drifted into six colour vocabularies and
# twenty hand-typed corner radii, one honest little exception at a time.
#
# So: no QML file outside shell/theme/ may contain a literal colour or a
# literal radius. Every value comes from Theme. A line that genuinely needs an
# exception says so, with a reason:
#
#     color: "#00000001"      // literal-ok: input region needs non-zero alpha
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
report() { printf '  \033[38;5;203m%s\033[0m  %s\n' "$1" "$2"; fail=1; }

# Files that are allowed literals, because they are where colour is defined.
allowed_dir='^shell/theme/'

while IFS= read -r file; do
    [[ "$file" =~ $allowed_dir ]] && continue

    # --- literal colours -----------------------------------------------------
    # #rgb / #rrggbb / #aarrggbb, and Qt.rgba()/Qt.hsla() with numbers.
    while IFS=: read -r line text; do
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"literal-ok"* ]] && continue
        # A comment-only line is documentation, not a value.
        [[ "$(printf '%s' "$text" | sed 's/^[[:space:]]*//')" == //* ]] && continue
        report "colour  $file:$line" "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-72)"
    done < <(grep -nE '"#[0-9a-fA-F]{3,8}"|Qt\.(rgba|hsla)\([0-9]' "$file" 2>/dev/null)

    # --- literal radii and spacing ------------------------------------------
    # `radius: 12` is a drift; `radius: Theme.radiusMd` is the point.
    while IFS=: read -r line text; do
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"literal-ok"* ]] && continue
        [[ "$(printf '%s' "$text" | sed 's/^[[:space:]]*//')" == //* ]] && continue
        report "shape   $file:$line" "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-72)"
    done < <(grep -nE '^[[:space:]]*(radius|spacing|border\.width)[[:space:]]*:[[:space:]]*[0-9]' "$file" 2>/dev/null)

done < <(find shell -name '*.qml' -type f | sort)

if (( fail )); then
    cat <<'EOF'

  A literal colour or radius reached a QML file outside shell/theme/.
  Use a Theme token instead — that is the whole reason the token layer exists.
  If the value genuinely cannot come from Theme, append a reason:

      color: "#00000001"   // literal-ok: needs non-zero alpha for an input region

EOF
    exit 1
fi

echo "  no literal colours or radii outside shell/theme/"
