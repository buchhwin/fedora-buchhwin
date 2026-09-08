#!/usr/bin/env bash
#
# Export, import and reset — the three buttons that replace the settings file.
#
# ⚠️ TWO OF THEM DO IT WITHOUT ASKING TWICE, so the round trip is checked rather
# than assumed: an export that writes nothing, a reset that loses the backup it
# promised, or an import that accepts a broken file are all faults you would
# only find out about at the moment you needed them not to be there.
#
# ⚠️ IT RUNS AGAINST A THROWAWAY HOME. Both paths Backup uses come from the
# environment — XDG_CONFIG_HOME for the settings file, HOME for the export — so
# pointing them at a temporary directory is enough to make sure this can never
# touch anybody's real settings. That is checked below rather than trusted:
# if the temporary directory is not made, the test stops instead of running.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

tmp="$(mktemp -d)" || { echo "  could not make a temporary directory"; exit 2; }
[[ -n "$tmp" && "$tmp" == /tmp/* ]] || { echo "  refusing to run against $tmp"; exit 2; }
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/config/buchhwin" "$tmp/home"

# A file with a value nothing else would produce, so "the export matches" cannot
# pass by accident on a default file.
cat > "$tmp/config/buchhwin/shell.json" <<'JSON'
{
  "theme": { "palette": "dracula", "accent": "mauve" },
  "notch": { "flare": 11, "collapsedWidth": 173 }
}
JSON

rm -f /tmp/buchhwin-backup-check.txt

BUCHHWIN_TOOL=backup-check \
QT_QPA_PLATFORM=offscreen \
XDG_CONFIG_HOME="$tmp/config" \
HOME="$tmp/home" \
    timeout 60 qs -p shell >/dev/null 2>&1

[[ -f /tmp/buchhwin-backup-check.txt ]] || { echo "  no output — the tool did not run"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' /tmp/buchhwin-backup-check.txt

grep -q '^  FAIL' /tmp/buchhwin-backup-check.txt && exit 1
exit 0
