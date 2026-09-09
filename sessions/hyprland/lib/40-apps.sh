# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: apps — the one application Fedora KDE does not ship.
#
# WARNING: THIS PHASE USED TO INSTALL A BROWSER, AN EDITOR, PRINTING, JAVA, A
# SOFTWARE CENTRE, THREE FLATPAKS, A THIRD-PARTY REPOSITORY EACH FOR BRAVE AND
# VS CODE, AN ENTERPRISE POLICY FILE UNDER /etc, TWO WEB-APP DESKTOP ENTRIES
# AND A SPOTIFY THEMING ENGINE. All of it is gone.
#
# The reason is the rule the dwl session has always followed and this one had
# drifted away from: the repository installs a SESSION, not a workstation. A
# window manager that decides your browser has overstepped, and every one of
# those packages was a decision made on somebody else's machine.
#
# What that costs, honestly: nothing the desktop needs. Super+B and Super+C are
# bound to scripts/buchhwin-browser and scripts/buchhwin-code, which look for
# what you have — an RPM, a Flatpak, the XDG default — and say so plainly if
# there is nothing to find. That is exactly how the dwl session has always
# behaved, and it is why neither installs a browser either.
#
# What is left is the one genuine hole: Fedora KDE ships no office suite.

phase_apps() {
    (( MINIMAL )) && { section "Applications"; ok "skipped (--minimal)"; return 0; }

    section "Applications"

    local wanted
    wanted="$(read_list flatpak.txt)"
    [[ -n "$wanted" ]] || { ok "nothing to install"; return 0; }

    if ! command -v flatpak >/dev/null 2>&1; then
        dnf_install weak flatpak || { warn "flatpak could not be installed"; return 0; }
    fi

    # WARNING: --user, NOT SYSTEM-WIDE, and the two sessions are why. Installed
    # system-wide by one of them and again per-user by the other, the same
    # application ends up on the machine twice with two sets of permissions.
    # The dwl session installs OnlyOffice per-user, so this one does too.
    flatpak remote-add --user --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 \
        || warn "could not add Flathub for your user"

    local app
    while read -r app; do
        [[ -n "$app" ]] || continue
        if flatpak info --user "$app" >/dev/null 2>&1; then
            ok "$app already installed"
            continue
        fi
        step "flatpak --user $app"
        flatpak install --user -y --noninteractive flathub "$app" >/dev/null 2>&1 \
            && ok "$app" || warn "$app failed"
    done <<< "$wanted"

    # WARNING: NO `xdg-mime default`, NO `xdg-settings set`. Default applications
    # are account-wide, so a session that sets them changes what opens a PDF
    # inside Plasma too. The dwl session's CI refuses those two calls outright;
    # this comment is the same promise, written where somebody would add them.
    ok "KDE default applications left unchanged"
}
