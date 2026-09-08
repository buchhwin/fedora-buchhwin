# shellcheck shell=bash
# KDE owns the login screen. This phase only verifies the invariant and never
# writes a theme, copies QML into a greeter account, or replaces SDDM.
phase_greeter() {
    section "KDE login manager"
    rpm -q sddm >/dev/null 2>&1 || die "SDDM is not installed"
    sudo systemctl enable sddm.service >/dev/null 2>&1 \
        || die "SDDM could not be enabled"
    ok "SDDM remains the only login manager"
}
