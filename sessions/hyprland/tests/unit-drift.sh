#!/usr/bin/env bash
#
# The installed systemd units must still be what the installer would write.
#
# ⚠️ THIS IS THE CHECK FOR "the code was right and the machine was old". The
# unit template gained `ExecStartPre=- … bhctl prune` after quickshell was found
# leaving one instance directory per run behind — in a tmpfs, so in RAM. The
# line went into lib/70-services.sh and the installed unit on the test machine
# never got it, because the installer had not run since. Measured when the
# memory was finally looked at: 1213 directories, 50 MB of RAM, and a repository
# whose source said the problem was solved.
#
# Nothing compared the two. Every file the installer writes once can drift the
# same way — and drift is silent by construction, because the thing that would
# tell you is the file that is out of date.
#
# ⚠️ IT COMPARES AGAINST THIS CHECKOUT. `ExecStartPre` names an absolute path
# into the repository, so a unit pointing somewhere else is reported too. That
# is not a false alarm: it means the desktop starts from a different copy of
# this code than the one being tested, which is worth knowing at least as much.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

CONFIG_HOME_REAL="${XDG_CONFIG_HOME:-$HOME/.config}"
installed="$CONFIG_HOME_REAL/systemd/user"

if [[ ! -f "$installed/buchhwin-shell.service" ]]; then
    # A build container has no installed desktop, and saying so is the honest
    # answer. It is NOT dressed up as a pass: the line says what was skipped.
    echo "  no units installed under $installed — nothing to compare"
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The installer's own function, run against a temporary CONFIG_HOME. Sourcing it
# rather than copying the templates is the whole point: a copy would drift from
# lib/70-services.sh exactly the way the machine drifted from it.
#
# ⚠️ Three stubs and a muzzle. `phase_services` prints through the installer's
# helpers and ends by reloading and enabling units — which would be a test that
# changes the machine it runs on.
section() { :; }
ok() { :; }
warn() { :; }
systemctl() { :; }
export CONFIG_HOME="$tmp"
export REPO_DIR="$PWD"
# shellcheck source=/dev/null
source lib/70-services.sh
phase_services >/dev/null 2>&1

fail=0
for unit in buchhwin-shell.service buchhwin-shell-failed.service \
            buchhwin-clipboard.service buchhwin-clipboard-image.service; do
    printf '  %-34s ' "$unit"
    if [[ ! -f "$tmp/systemd/user/$unit" ]]; then
        printf '\033[38;5;203mthe installer no longer writes it\033[0m\n'; fail=1; continue
    fi
    if [[ ! -f "$installed/$unit" ]]; then
        printf '\033[38;5;203mnot installed\033[0m\n'; fail=1; continue
    fi
    if diff -q "$installed/$unit" "$tmp/systemd/user/$unit" >/dev/null; then
        printf '\033[38;5;114mok\033[0m\n'
    else
        printf '\033[38;5;203mdrifted\033[0m\n'
        diff -u "$installed/$unit" "$tmp/systemd/user/$unit" \
            | sed 's/^/      /' | head -24
        fail=1
    fi
done

if (( fail )); then
    cat <<'EOF'

  The unit on this machine is not what lib/70-services.sh would write. Left is
  what is installed and running, right is what the code says. Re-run install.sh
  to bring them back together — and if the difference is not one you meant,
  that is the finding.
EOF
fi

exit $fail
