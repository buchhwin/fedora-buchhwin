# shellcheck shell=bash
# Phase: install an additional Hyprland/Quickshell session on Fedora KDE.
phase_desktop() {
    section "Hyprland session on KDE"

    mapfile -t pkgs < <(read_list dnf-desktop.txt)
    step "${#pkgs[@]} session packages, without weak dependencies"
    if ! dnf_install noweak "${pkgs[@]}"; then
        # Fedora releases where Hyprland is not in the base repositories use
        # the same maintained COPR as the earlier Buchhwin Hyprland project.
        step "Hyprland was unavailable in Fedora; enabling sachesi/hyprland"
        sudo dnf copr enable -y sachesi/hyprland \
            || die "could not enable the Hyprland repository"
        dnf_install noweak "${pkgs[@]}" || die "desktop packages failed"
    fi

    mapfile -t tools < <(read_list dnf-tools.txt)
    dnf_install noweak "${tools[@]}" || warn "some themed tools failed"

    for copr in atim/starship atim/lazygit; do
        pkg="${copr#*/}"
        rpm -q "$pkg" >/dev/null 2>&1 && continue
        sudo dnf copr enable -y "$copr" >/dev/null 2>&1 \
            && dnf_install noweak "$pkg" >/dev/null 2>&1 \
            || warn "$pkg could not be installed from $copr"
    done

    # ⚠️⚠️ THE SDDM LINE THAT STOOD HERE WAS A DUPLICATE, AND IT WAS THE ONE
    # THAT KILLED THE INSTALL. phase_greeter owns the login manager — that is
    # what it is for — and this phase repeated the same `systemctl enable
    # sddm.service`, four phases earlier, with `|| die` behind it. On Fedora KDE
    # that enable always fails (the display-manager.service alias already
    # exists), so the run ended in phase TWO, with the packages installed and
    # nothing of this session written.
    #
    # The visible result was the worst kind: Hyprland's own default session
    # appearing in the login manager, because the package was in and ours was
    # not. It looked like the profile had installed and did not work.
    #
    # Handling it in one place also means it is handled once, properly: see
    # lib/65-greeter.sh, which checks before it enables and reports what systemd
    # actually said when it cannot.
    sudo systemctl set-default graphical.target >/dev/null 2>&1 \
        || warn "could not set graphical.target"

    ok "Hyprland $(Hyprland --version 2>/dev/null | head -1), quickshell $(qs --version 2>/dev/null | cut -d, -f1)"
}
