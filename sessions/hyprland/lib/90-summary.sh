# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
phase_summary() {
    section "Done"
    if (( WARNINGS )); then
        printf '  %s%s warning(s)%s — read them before rebooting.\n' "$C_WARN" "$WARNINGS" "$C_OFF"
    else
        printf '  no warnings.\n'
    fi
    cat <<'EOF'

  Log out, then pick "Buchhwin Hyprland" in SDDM.

    bhctl theme <palette> [accent]   switch colours (everything follows)
    bhctl doctor                     check the session

EOF
}
