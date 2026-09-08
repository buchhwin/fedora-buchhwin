#!/usr/bin/env bash
#
# No object declares the same property twice.
#
# ⚠️⚠️ THIS TOOK THE WHOLE SHELL DOWN AND EVERY SUITE STAYED GREEN. Three tiles
# in the quick panel already had a `visible:` of their own; a second one was
# added beside it. QML does not treat that as an override — it says "Property
# value set multiple times", refuses to build the component, and the refusal
# TRAVELS:
#
#     QuickSettings.qml: Property value set multiple times
#       → Type QuickSettings unavailable
#       → QuickPage → NotchContent → ShellSurface unavailable
#
# The notch, the bar, the launcher, the quick panel and every IPC target were
# gone. It was found by restarting the shell and reading the journal.
#
# ⚠️ THE FAULT IS SILENT AT EVERY OTHER LEVEL. There is no crash, no exit code,
# no red anywhere: the process starts, loads, and simply has no surfaces. From
# outside that is indistinguishable from a desktop that was never configured.
#
# ⚠️ AND IT IS EASY TO WRITE. Adding a condition to an object whose declaration
# spans forty lines with a paragraph of comment in the middle is exactly the
# situation where the existing `visible:` is off-screen while you type.
#
# ------------------------------------------------------------------ how it works
#
# Brace depth, not indentation. An object's properties are the assignments at the
# depth its `{` opened; anything deeper belongs to a child and is allowed to
# repeat the name. Comments are stripped first, and declarations (`property`,
# `readonly`, `signal`, `function`) are not assignments.
#
# ⚠️ A DOTTED NAME IS NOT A DUPLICATE. `anchors.left` and `anchors.right` are two
# properties of one grouped object, and `Layout.fillWidth` beside
# `Layout.fillHeight` is the same shape. Only bare names are compared.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

red=$'\e[38;5;203m'; off=$'\e[0m'

mapfile -t files < <(find shell -name '*.qml' -type f | sort)
if (( ${#files[@]} == 0 )); then
    echo "  ${red}found no QML under shell/${off} — this check was measuring nothing"
    exit 2
fi

out="$(python3 - "${files[@]}" <<'PY'
import re, sys

hits = []
for path in sys.argv[1:]:
    lines = open(path, encoding="utf-8").read().split("\n")
    depth = 0
    seen = {}
    for n, raw in enumerate(lines, start=1):
        line = re.sub(r'//.*', '', raw)

        m = re.match(r'^\s*([a-z][A-Za-z0-9_.]*)\s*:\s*\S', line)
        if m and not re.match(r'^\s*(property|readonly|signal|function|import|pragma)\b', line):
            key = m.group(1)
            # A dotted name is one property of a grouped object, never a repeat.
            if "." not in key:
                here = seen.setdefault(depth, {})
                if key in here:
                    hits.append((path, key, here[key], n))
                else:
                    here[key] = n

        opens = line.count("{")
        closes = line.count("}")
        if opens or closes:
            depth += opens - closes
            # Leaving a block: everything recorded at or below the new depth
            # belonged to the object that just closed.
            for d in [d for d in seen if d >= depth]:
                seen.pop(d)

for path, key, first, second in hits:
    print(f"{path}:{second}\t{key}\tfirst declared on line {first}")
PY
)"

if [[ -n "$out" ]]; then
    while IFS=$'\t' read -r where key note; do
        printf '  %sFAIL%s  %s  `%s` %s\n' "$red" "$off" "$where" "$key" "$note"
    done <<< "$out"
    cat <<'EOF'

  QML reads a second declaration as an error, not as an override: the component
  is not built at all, and every type that contains it becomes "unavailable" in
  turn. Nothing crashes and nothing exits non-zero — the desktop simply comes up
  with no surfaces.

  Put both conditions on one line:  visible: root.showMore && Services.X.available
EOF
    exit 1
fi

printf '  no object declares a property twice (%d files)\n' "${#files[@]}"
