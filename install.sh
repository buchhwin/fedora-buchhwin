#!/usr/bin/env bash
# Install one or both Buchhwin sessions on an existing Fedora KDE system.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
session=""
forward=()

while (($#)); do
    case "$1" in
        --session)
            [[ $# -ge 2 ]] || { echo "--session needs dwl, hyprland or both" >&2; exit 2; }
            session="$2"; shift 2 ;;
        --session=*) session="${1#*=}"; shift ;;
        -h|--help)
            cat <<'EOF'
Usage: ./install.sh [--session dwl|hyprland|both] [profile options]

Without --session an interactive menu is shown. Fedora KDE Plasma and SDDM
must already be installed. Each compositor is added as a separate SDDM session.
EOF
            exit 0 ;;
        *) forward+=("$1"); shift ;;
    esac
done

if [[ -z "$session" ]]; then
    [[ -t 0 ]] || { echo "Use --session dwl, --session hyprland or --session both" >&2; exit 2; }
    printf '%s\n' 'Choose the Buchhwin session to install:' \
        '  1) dwl' '  2) Hyprland' '  3) both'
    read -r -p '> ' choice
    case "$choice" in
        1|dwl) session=dwl ;;
        2|hyprland) session=hyprland ;;
        3|both) session=both ;;
        *) echo "Invalid selection: $choice" >&2; exit 2 ;;
    esac
fi

case "$session" in
    dwl|hyprland|both) ;;
    *) echo "Unknown session '$session' (expected dwl, hyprland or both)" >&2; exit 2 ;;
esac

command -v rpm >/dev/null 2>&1 \
    || { echo "This installer requires Fedora KDE" >&2; exit 1; }
rpm -q plasma-desktop sddm >/dev/null 2>&1 \
    || { echo "Install the Fedora KDE Plasma edition (including SDDM) first" >&2; exit 1; }

case "$session" in
    dwl) exec "$ROOT/sessions/dwl/install-fedora.sh" "${forward[@]}" ;;
    hyprland) exec "$ROOT/sessions/hyprland/install-hyprland.sh" "${forward[@]}" ;;
    both)
        # ⚠️ THE SECOND INSTALLER IS TOLD THE FIRST ONE RAN, and it is not a
        # convenience. The Hyprland profile sweeps up packages it considers
        # replaced — swaylock among them, because it ships its own lock screen —
        # and swaylock is one the dwl session INSTALLS. Run one after the other
        # with neither knowing about the other, and the second one's tidying is
        # aimed at the first one's desktop.
        #
        # ⚠️ IT DID NOT ACTUALLY REMOVE ANYTHING, and that is worth writing down
        # rather than relying on. `dnf install swaylock` marks it User, and the
        # sweep leaves anything marked User alone — so the outcome was a warning
        # saying "swaylock is installed and marked as YOUR choice", about a
        # package the installer two lines up had just put there. The protection
        # was real and the sentence was wrong, which is the sort of thing that
        # gets "fixed" by somebody who believes it.
        BUCHHWIN_SIBLING_SESSION=hyprland \
            "$ROOT/sessions/dwl/install-fedora.sh" "${forward[@]}"
        BUCHHWIN_SIBLING_SESSION=dwl \
            "$ROOT/sessions/hyprland/install-hyprland.sh" "${forward[@]}"
        ;;
esac
