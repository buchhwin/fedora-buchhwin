#!/usr/bin/env bash
#
# Rebinding a key: the override resolves, and the clash check holds.
#
# ⚠️ THE SECOND HALF IS THE ONE THAT MATTERS. Two bindings on one key is a KDL
# parse error, and niri does not start with a config it cannot parse — so this
# fault does not show up as a wrong colour or a dead button but as a machine
# that boots to nothing, once, on the day somebody moved a shortcut.
#
# ⚠️ AND THE FIRST HALF IS NOT COSMETIC EITHER. `binds` is all-or-nothing: the
# moment it holds anything, the built-in set is gone. Rebinding by saving the
# resolved list would freeze the other sixty-seven bindings at whatever they
# were that day, and every default added later would be invisible on that
# machine. This project has already carried 63 frozen bindings for weeks.
#
# It runs against a throwaway XDG_CONFIG_HOME, so it cannot touch real settings.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

tmp="$(mktemp -d)" || { echo "  could not make a temporary directory"; exit 2; }
[[ -n "$tmp" && "$tmp" == /tmp/* ]] || { echo "  refusing to run against $tmp"; exit 2; }
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config/buchhwin" "$tmp/home"

# No `binds` and no `rebinds`: the healthy state, where the built-in set is in
# force. Starting from a file with its own copy would test a different thing.
printf '{\n  "theme": { "palette": "everforest-dark" }\n}\n' \
    > "$tmp/config/buchhwin/shell.json"

rm -f /tmp/buchhwin-rebind-check.txt

BUCHHWIN_TOOL=rebind-check \
QT_QPA_PLATFORM=offscreen \
XDG_CONFIG_HOME="$tmp/config" \
HOME="$tmp/home" \
    timeout 60 qs -p shell >/dev/null 2>&1

[[ -f /tmp/buchhwin-rebind-check.txt ]] || { echo "  no output — the tool did not run"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' /tmp/buchhwin-rebind-check.txt

grep -q '^  FAIL' /tmp/buchhwin-rebind-check.txt && exit 1
exit 0
