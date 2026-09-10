# shellcheck shell=bash
# KDE owns the login screen. This phase only verifies the invariant and never
# writes a theme, copies QML into a greeter account, or replaces SDDM.
phase_greeter() {
    section "KDE login manager"
    # ⚠️ `rpm -q sddm || die` STOOD HERE AND IT WAS THE WRONG QUESTION. Nothing
    # in this session talks to SDDM: the session is a .desktop file in
    # /usr/share/wayland-sessions, which every display manager reads. Demanding
    # one particular manager turned somebody else's working login screen into a
    # fatal error.
    #
    # ⚠️⚠️ ALREADY ENABLED WAS FATAL, ON THE ONLY KIND OF MACHINE THIS INSTALLS
    # ONTO. `systemctl enable sddm.service` does not just create a wants-link:
    # the unit carries `Alias=display-manager.service`, so enabling it writes
    # /etc/systemd/system/display-manager.service. systemd REFUSES when that
    # symlink already exists — and on Fedora KDE it always does, because SDDM is
    # the display manager there out of the box.
    #
    # So the line below used to abort the install on every target machine, in
    # phase two, AFTER the packages were in. What the user saw was Hyprland
    # appearing in their login manager with its own default config — the session
    # file from the Hyprland package, because ours is written four phases later
    # and never was.
    #
    # ⚠️ AND THE REASON WAS THROWN AWAY. `>/dev/null 2>&1` swallowed systemd's
    # message, so a fatal error reported "SDDM could not be enabled" and nothing
    # else. An error that ends the run has to say what it saw.
    if systemctl is-enabled --quiet sddm.service 2>/dev/null; then
        ok "SDDM is already the login manager — nothing to do"
        return 0
    fi

    # ⚠️ WHO OWNS THE ALIAS IS ASKED BEFORE ANYTHING IS TRIED, not after a failed
    # enable. If another display manager holds display-manager.service, enabling
    # SDDM would either fail or — with --force — SWITCH THE MACHINE'S LOGIN
    # SCREEN, which is not a decision an installer for a session makes on
    # somebody's behalf. The session is a file in /usr/share/wayland-sessions
    # and every display manager reads it, so there is nothing to do here.
    local current=""
    if [[ -L /etc/systemd/system/display-manager.service ]]; then
        current="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
    fi
    if [[ -n "$current" && "$current" != "sddm.service" ]]; then
        ok "your login manager is ${current%.service} — left exactly as it is"
        step "this session appears there like any other; nothing was enabled or disabled"
        return 0
    fi

    local err
    if err="$(sudo systemctl enable sddm.service 2>&1)"; then
        ok "SDDM enabled as the login manager"
        return 0
    fi

    die "SDDM could not be enabled: $err"
}
