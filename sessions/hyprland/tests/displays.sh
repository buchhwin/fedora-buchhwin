#!/usr/bin/env bash
#
# The Displays page — his B3.
#
# ⚠️ THE FIXTURE IS THE POINT. tests/pages.sh builds every page, including this
# one, and reports it green — with ZERO screens, because `QT_QPA_PLATFORM=
# offscreen` has no Wayland outputs. Every card, every dropdown and every
# placement in that page hangs off a Repeater over the monitor list, so all of it
# stays uninstantiated and the suite is green over code that has never run once.
# This check hands the shell three monitors that do not exist.
#
# ⚠️ AND THE FIXTURE IS REAL JSON, not a convenient shape. Every field below was
# measured from `niri msg -j outputs` on hardware — including the three that the
# handouts did not document until this round: `current_mode` (an INDEX into
# `modes`), `vrr_supported`, and `logical` (the SCALED geometry, which is what
# niri counts positions in).
#
# The three screens are chosen to break the three things that have actually been
# got wrong here:
#
#   DP-1       3840x2160 three times over, at 60.000 / 59.940 / 50.000 — the
#              duplicate-resolution case, which real hardware really does
#   HDMI-A-1   3840x2160 at scale 2.0 — logical size 1920x1080, so anything
#              placed by MODE size is wrong by exactly a factor of two
#   eDP-1      1280x800 at 74.994 Hz — the rate that `%.3g` rounded to "75" in
#              bhctl doctor for months
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

read -r -d '' FAKE <<'JSON'
{
  "DP-1": {
    "name": "DP-1", "make": "Dell Inc.", "model": "U2723QE", "serial": null,
    "physical_size": [600, 340],
    "modes": [
      {"width":3840,"height":2160,"refresh_rate":60000,"is_preferred":true},
      {"width":3840,"height":2160,"refresh_rate":59940,"is_preferred":false},
      {"width":3840,"height":2160,"refresh_rate":50000,"is_preferred":false},
      {"width":2560,"height":1440,"refresh_rate":59951,"is_preferred":false},
      {"width":1920,"height":1080,"refresh_rate":60000,"is_preferred":false},
      {"width":1280,"height":720,"refresh_rate":60000,"is_preferred":false}
    ],
    "current_mode": 0, "is_custom_mode": false,
    "vrr_supported": true, "vrr_enabled": false,
    "logical": {"x":0,"y":0,"width":3840,"height":2160,"scale":1.0,"transform":"Normal"}
  },
  "HDMI-A-1": {
    "name": "HDMI-A-1", "make": "LG Electronics", "model": "LG HDR 4K", "serial": null,
    "physical_size": [600, 340],
    "modes": [
      {"width":3840,"height":2160,"refresh_rate":60000,"is_preferred":true},
      {"width":1920,"height":1080,"refresh_rate":60000,"is_preferred":false}
    ],
    "current_mode": 0, "is_custom_mode": false,
    "vrr_supported": false, "vrr_enabled": false,
    "logical": {"x":3840,"y":0,"width":1920,"height":1080,"scale":2.0,"transform":"Normal"}
  },
  "eDP-1": {
    "name": "eDP-1", "make": "AU Optronics", "model": "Internal", "serial": null,
    "physical_size": [320, 200],
    "modes": [
      {"width":1280,"height":800,"refresh_rate":74994,"is_preferred":true}
    ],
    "current_mode": 0, "is_custom_mode": false,
    "vrr_supported": false, "vrr_enabled": false,
    "logical": {"x":0,"y":2160,"width":1280,"height":800,"scale":1.0,"transform":"Normal"}
  }
}
JSON

# ⚠️ ITS OWN XDG_CONFIG_HOME, for the reason tests/lock.sh has one: the page
# reads and WRITES `outputs`, and a check that edits the settings of whoever ran
# it is a check nobody runs twice.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/buchhwin"
printf '{}\n' > "$tmp/buchhwin/shell.json"

rm -f /tmp/buchhwin-displays-check.log
XDG_CONFIG_HOME="$tmp" BUCHHWIN_OUTPUTS_FAKE="$FAKE" \
    BUCHHWIN_TOOL=displays-check QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1
code=$?

# ⚠️ TWO DIFFERENT FAILURES, and a check that sees only one of them is the
# failure it was written against: a tool that REFUSES exits 0 and says ABORT in
# its report, a tool that CRASHES says nothing at all.
if (( code != 0 )); then
    echo "  displays-check crashed or timed out (exit $code)"
    [[ -f /tmp/buchhwin-displays-check.log ]] && tail -5 /tmp/buchhwin-displays-check.log
    exit 1
fi
[[ -f /tmp/buchhwin-displays-check.log ]] || { echo "  no output"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' /tmp/buchhwin-displays-check.log

grep -q ABORT /tmp/buchhwin-displays-check.log && exit 1
exit 0
