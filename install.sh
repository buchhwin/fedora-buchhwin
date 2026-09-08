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
        "$ROOT/sessions/dwl/install-fedora.sh" "${forward[@]}"
        "$ROOT/sessions/hyprland/install-hyprland.sh" "${forward[@]}"
        ;;
esac
