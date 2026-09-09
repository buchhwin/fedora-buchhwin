# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: fonts — two downloads, because they are the two things nobody packages
# for Fedora: the Nerd font, and the macOS-style pointer he asked for.
phase_fonts() {
    section "Fonts"
    local dir="$DATA_HOME/fonts/JetBrainsMonoNerdFont"
    if [[ -d "$dir" ]] && compgen -G "$dir/*.ttf" >/dev/null; then
        ok "JetBrainsMono Nerd Font already installed"
    else
        step "fetching JetBrainsMono Nerd Font"
        mkdir -p "$dir"
        # WARNING: A PINNED TAG, NOT `latest`. `latest` means the font can
        # change under a machine between two installs of the same commit,
        # which is the one thing a repository like this exists to prevent.
        local url=https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.tar.xz
        if curl -fsSL "$url" | tar -xJ -C "$dir" 2>/dev/null; then
            # The Windows-compatible variants are duplicates with different
            # metrics; keeping them makes fontconfig pick unpredictably.
            find "$dir" -name '*Windows*' -delete 2>/dev/null
            fc-cache -f "$dir" >/dev/null 2>&1
            ok "JetBrainsMono Nerd Font"
        else
            warn "could not fetch the Nerd Font; the mono font will fall back"
        fi
    fi

    # ⚠️ THIS ONE IS COPIED, NOT FETCHED, AND THAT IS THE DIFFERENCE WORTH
    # NAMING. The two downloads in this file exist upstream as files, so they
    # can be pinned and checked. The Fluent subset does not exist anywhere: it
    # is twenty-one glyphs cut out of a 2.81 MB font by tools/subset-fluent.py
    # and it weighs 5 KB. There is nothing to pin and nothing that can change
    # under us, so it lives in the tree.
    #
    # ⚠️ ITS LICENCE IS IN docs/CREDITS.md and it is MIT, which requires the
    # notice to travel with the file. See the note there for why the real
    # Windows font (Segoe Fluent Icons) is NOT what this is.
    local fl="$DATA_HOME/fonts/BuchhwinFluentIcons"
    local fl_src="$REPO_DIR/assets/fonts/BuchhwinFluentIcons.ttf"
    if [[ -f "$fl_src" ]]; then
        mkdir -p "$fl"
        # ⚠️ `cp` UNCONDITIONALLY, not `cp -n`. This file is ours and an update
        # may well change which glyphs it carries — leaving an older copy in
        # place would draw the replacement box for a symbol the shell has since
        # started asking for, which is exactly the failure tests/icons.sh
        # exists to catch and the hardest kind to attribute.
        if cp "$fl_src" "$fl/" 2>/dev/null; then
            fc-cache -f "$fl" >/dev/null 2>&1
            ok "Fluent icon subset"
        else
            warn "could not install the Fluent icon subset; the notch will fall back"
        fi
    fi
}

# ⚠️ PINNED TO A COMMIT AND CHECKED AGAINST A HASH, unlike the font above.
# A long-term setup may not contain a foreign source that can change under it
# silently — and this one is a pointer, which is on screen at all times.
#
# ⚠️ WHY NOT THE PACKAGE MANAGER: it is not in Fedora. Apple's own cursors are
# not redistributable, so McMojave-cursors is a free rebuild (GPL-3). His choice,
# by name, on 06.08.2026.

# WARNING: phase_cursors IS GONE, and with it a pinned tarball of the
# McMojave cursor theme fetched from GitHub and verified by hand.
#
# The session sets XCURSOR_THEME=breeze_cursors in config/hypr/buchhwin/env.lua
# and packages/dnf-desktop.txt installs breeze-cursor-theme, which is what the
# Fedora KDE base uses anyway. So the cursor already matched Plasma's; the
# tarball replaced it with a third-party rebuild of Apple's, downloaded at
# install time, for a machine somebody works on. The dwl session reads KDE's
# cursor choice and leaves it alone; this one now does the same.
