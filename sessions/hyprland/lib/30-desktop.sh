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

    # SDDM stays the sole display manager. Plasma remains selectable and no
    # greetd configuration or custom login surface is installed.
    sudo systemctl enable sddm.service >/dev/null 2>&1 \
        || die "SDDM could not be enabled"
    sudo systemctl set-default graphical.target >/dev/null 2>&1 \
        || warn "could not set graphical.target"

    ok "Hyprland $(Hyprland --version 2>/dev/null | head -1), quickshell $(qs --version 2>/dev/null | cut -d, -f1)"
}
