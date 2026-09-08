#!/usr/bin/env bash
#
# No IPC function may be called `show`.
#
# ⚠️ MEASURED, NOT STYLE. `qs ipc show` is quickshell's own subcommand, so an
# IPC function of that name cannot be reached from the command line at all:
#
#   $ qs -c buchhwin ipc call launcher show
#   target launcher
#     function toggle(): void
#     …                              <- the listing, and the launcher stayed closed
#   $ qs -c buchhwin ipc call launcher toggle
#   $ qs -c buchhwin ipc call launcher state
#   open                             <- the same handler, a different name, works
#
# Nothing user-facing depended on it — both key bindings use `toggle` — which is
# precisely why it sat there broken. A function nobody can call is the same debt
# as a config key nobody reads.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

printf '  %-34s ' "no IPC function named 'show'"

# Only inside IpcHandler blocks: Ipc.show() as an internal QML function is fine
# and is used by half the shell.
bad="$(awk '
    /IpcHandler[ \t]*\{/          { depth = 1 ; next }
    depth == 0                    { next }
    /\{/                          { depth++ }
    /\}/                          { depth-- ; if (depth <= 0) depth = 0 }
    /^[ \t]*function[ \t]+show[ \t]*\(/ { printf "%s:%d %s\n", FILENAME, NR, $0 }
' shell/ipc/*.qml)"

if [[ -n "$bad" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "$bad"
    echo
    echo "  Rename it — 'open' is what the launcher uses. The command line cannot"
    echo "  reach a function called 'show', and it fails by printing a listing"
    echo "  rather than by saying so."
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
# Every `root.<something>` a handler reads is actually declared in the file.
#
# ⚠️ THIS ONE SHIPPED, and it is the reason the check exists. `quickSettings`
# was deleted when the five tabs became four; `settings()` went on calling
# `root.showQuick(root.quickSettings)`. QML says nothing about reading a
# property that is not there — it hands back `undefined` — so the gear on the
# bar and the settings key both did nothing at all, and the only sign was one
# line in the journal: "Cannot assign [undefined] to int".
#
# The comment beside the deletion said "the compiler found every one of them".
# There is no compiler here. This is what stands in for one.
printf '  %-34s ' "no root.<gone> in the handlers"

declared="$(grep -oE '(readonly )?property [A-Za-z<>]+ [A-Za-z_][A-Za-z0-9_]*' shell/ipc/Ipc.qml \
            | awk '{print $NF}' | sort -u)"
declared+=$'\n'"$(grep -oE '^[ \t]*function [A-Za-z_][A-Za-z0-9_]*' shell/ipc/Ipc.qml \
            | awk '{print $NF}' | sort -u)"
# `id: root` itself, and the QML built-ins reachable through it.
declared+=$'\nobjectName\nparent\nchildren\ndata'

gone=""
while read -r name; do
    [[ -z "$name" ]] && continue
    grep -qxF "$name" <<< "$declared" || gone+="$name"$'\n'
done < <(grep -oE '\broot\.[A-Za-z_][A-Za-z0-9_]*' shell/ipc/Ipc.qml \
         | sed 's/^root\.//' | sort -u)

if [[ -z "$gone" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
    exit 0
fi

printf '\033[38;5;203mmissing\033[0m\n'
while read -r name; do
    [[ -z "$name" ]] && continue
    printf '      root.%s\n' "$name"
    grep -n "root\.$name\b" shell/ipc/Ipc.qml | sed 's/^/        /'
done <<< "${gone%$'\n'}"
cat <<'WHY'

  These are read but never declared, so they are `undefined` at run time and
  whatever consumes them fails quietly. Either the property was renamed and the
  reader was missed, or the reader is a typo.
WHY
exit 1
