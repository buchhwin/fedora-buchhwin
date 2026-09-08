#!/usr/bin/env bash
#
# What the installer thinks is a graphics card.
#
# `gpu_devices()` in lib/10-gpu.sh decides whether the NVIDIA branch runs at
# all, so a wrong answer either installs a driver on a machine that has no card
# for it, or leaves the target laptop without one. It reads sysfs rather than
# calling lspci — pciutils is in no package list, sysfs parses a number instead
# of English, and it hands back the PCI address that /dev/dri/by-path/ names its
# render nodes after.
#
# ⚠️ THE FIXTURE THAT MATTERS IS THE FOURTH ONE. An NVIDIA laptop GPU brings an
# HDMI audio function on the same card: same vendor 0x10de, class 0x0403 instead
# of 0x0300. Matching on the vendor alone counts it as a second GPU, and "this
# machine has two NVIDIAs" is the kind of wrong that then gets acted on — the
# hybrid message, the render device list, the PCI address in the report. So the
# audio function is not a curiosity in this file, it is the reason for it.
#
# Runs anywhere: it builds its own /sys tree and needs neither hardware nor root.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# shellcheck source=../lib/10-gpu.sh
source lib/10-gpu.sh 2>/dev/null || { echo "  cannot source lib/10-gpu.sh"; exit 2; }

fail=0
tmp="$(mktemp -d)" || exit 2
trap 'rm -rf "$tmp"' EXIT

# A fake PCI device: $1 = tree, $2 = address, $3 = class, $4 = vendor
device() {
    local d="$1/bus/pci/devices/$2"
    mkdir -p "$d"
    printf '%s\n' "$3" > "$d/class"
    printf '%s\n' "$4" > "$d/vendor"
}

check() {   # $1 = label, $2 = tree, $3 = expected output (one device per line)
    printf '  %-40s ' "$1"
    local got
    got="$(BUCHHWIN_SYSFS="$2" gpu_devices | sort)"
    local want; want="$(printf '%s' "$3" | sed '/^$/d' | sort)"
    if [[ "$got" == "$want" ]]; then
        printf '\033[38;5;114mok\033[0m\n'
    else
        printf '\033[38;5;203mmismatch\033[0m\n'
        printf '      expected: %s\n' "${want:-<nothing>}"
        printf '      got:      %s\n' "${got:-<nothing>}"
        fail=1
    fi
}

# 1. A machine with no graphics at all — a VM with a virtio GPU that does not
#    register as class 0x03, or a server. The branch must not run.
none="$tmp/none"; mkdir -p "$none/bus/pci/devices"
check "no display controller at all" "$none" ""

# 2. Integrated only. This is the test VM, and the answer decides whether
#    `--only gpu` says "nothing to install" or starts downloading a driver.
amd="$tmp/amd"; device "$amd" 0000:c5:00.0 0x030000 0x1002
check "AMD integrated only" "$amd" "0000:c5:00.0 0x1002"

# 3. A desktop with one discrete NVIDIA and nothing else.
nv="$tmp/nv"; device "$nv" 0000:01:00.0 0x030000 0x10de
check "NVIDIA only" "$nv" "0000:01:00.0 0x10de"

# 4. A hybrid laptop: integrated Radeon plus an NVIDIA card — AND the HDMI audio function the
#    card brings with it, which is the trap this file exists for.
hy="$tmp/hybrid"
device "$hy" 0000:c5:00.0 0x030000 0x1002   # integrated Radeon
device "$hy" 0000:01:00.0 0x030000 0x10de   # NVIDIA discrete
device "$hy" 0000:01:00.1 0x040300 0x10de   # ⚠️ its audio function, NOT a GPU
check "hybrid laptop, audio function ignored" "$hy" \
      "0000:c5:00.0 0x1002
0000:01:00.0 0x10de"

# 5. Class 0x0380 is "display controller, other" — how some cards present. It
#    is still a display controller and must be counted, which is why the test is
#    on the 0x03 PREFIX and not on the exact value 0x030000.
other="$tmp/other"; device "$other" 0000:02:00.0 0x038000 0x10de
check "display controller, other subclass" "$other" "0000:02:00.0 0x10de"

# 6. A directory with no readable class file — sysfs on a machine where
#    something is being hot-removed. It must be skipped, not counted as a match
#    with an empty vendor.
half="$tmp/half"; mkdir -p "$half/bus/pci/devices/0000:03:00.0"
device "$half" 0000:04:00.0 0x030000 0x1002
check "unreadable device is skipped" "$half" "0000:04:00.0 0x1002"

exit $fail
