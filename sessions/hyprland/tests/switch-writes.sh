#!/usr/bin/env bash
#
# Every row in the settings window has to actually write.
#
# ⚠️ THE REPORT NAMED A CLASS, NOT A ROW. "manche switches gehen nicht wie z.b.  # english-ok: his report, quoted
# der dock switch", and on being asked, "das ist nicht nur beim dock schalter    # english-ok: same, second line
# so sondern bei mehreren". So this does not check the dock switch. It walks
# EVERY key any row declares and reports which ones do not land — because
# repairing one line before the others are measured fixes a symptom and leaves
# the rest, and then next time it is "manche" again.
#
# ⚠️ WHAT WAS ALREADY RULED OUT, so nobody starts where this started:
#
#   * The reader exists. ui/Shell.qml reads Config.bar.enabled.
#   * The writer exists. pages/BarIslandPage.qml declares key: "bar.enabled".
#   * The row is honest by design — it shows Config.get(key) and never moves
#     itself, so "springs back" means the write was REFUSED, not mis-drawn.
#   * The journal has no `Config.set: no such section` and no `no such key` on
#     the test machine, so the two loud refusals are not it. What is left is the
#     silent one (`node[leaf] === value`) and assignment into a JsonAdapter
#     wrapper being accepted without reaching the adapter.
#
# The key list is extracted with the same grep tests/setting-rows.sh uses, so
# the two cannot disagree about what a row is. ⚠️ `^[[:space:]]*key:` and not a
# bare `key:`, or SettingRow's own `property string key: ""` joins the list.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

fail=0
ok()  { printf '  \033[32mok\033[0m   %s\n' "$*"; }
bad() { printf '  \033[38;5;203mFAIL\033[0m %s\n' "$*"; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

keys="$tmp/keys"
grep -rhoE '^[[:space:]]*key:[[:space:]]*"[^"]+"' shell/ui/settings/ \
    | sed -E 's/.*"([^"]+)".*/\1/' | sort -u > "$keys"

n="$(wc -l < "$keys")"
if [[ "$n" -lt 50 ]]; then
    # ⚠️ A sweep that swept nothing is not a pass. There are well over a hundred
    # rows; a handful means the extraction broke, and this suite exists because
    # a third of this project's checks could not go red.
    bad "only $n keys found — the extraction is broken, not the settings"
    exit 1
fi
ok "$n row keys to try"

# ⚠️ A COPY OF THE CONFIG, NOT THE REAL ONE. Every value is put back afterwards
# and the tool checks that it was, but a probe that toggles a hundred live
# settings on the machine it runs on is not something to rely on being tidy.
cfg="$tmp/cfg"
mkdir -p "$cfg/buchhwin"
real="${XDG_CONFIG_HOME:-$HOME/.config}/buchhwin/shell.json"
[[ -f "$real" ]] && cp "$real" "$cfg/buchhwin/shell.json"

out="$tmp/out"
rm -f "$out"
XDG_CONFIG_HOME="$cfg" BUCHHWIN_TOOL=switch-write-check \
    BUCHHWIN_KEYS="$keys" BUCHHWIN_ROWS_OUT="$out" \
    QT_QPA_PLATFORM=offscreen timeout 180 qs -p shell >/dev/null 2>&1

if [[ ! -s "$out" ]]; then
    bad "the probe wrote no report at all"
    exit 1
fi

refused="$(grep -c '^REFUSED' "$out" || true)"
missing="$(grep -c '^MISSING' "$out" || true)"
unrestored="$(grep -c 'could not restore' "$out" || true)"

if [[ "$refused" -gt 0 ]]; then
    bad "$refused rows do not write:"
    grep '^REFUSED' "$out" | sed 's/^/        /'
else
    ok "every row that could be tried wrote its key"
fi

[[ "$missing" -gt 0 ]] && {
    bad "$missing keys are not in the schema at all:"
    grep '^MISSING' "$out" | sed 's/^/        /'
}

[[ "$unrestored" -gt 0 ]] && {
    bad "$unrestored values could not be put back — the probe left a mess"
    grep 'could not restore' "$out" | sed 's/^/        /'
}

tail -1 "$out" | sed 's/^/  /'
exit $fail
