# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: apps — third-party repositories, applications, flatpaks.
phase_apps() {
    (( MINIMAL )) && { section "Applications"; step "skipped (--minimal)"; return 0; }
    section "Applications"

    if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
        sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc 2>/dev/null
        sudo dnf config-manager addrepo --overwrite \
            --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo \
            >/dev/null 2>&1 || warn "could not add the Brave repository"
    fi
    if [[ ! -f /etc/yum.repos.d/vscode.repo ]]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null
        printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
            | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
    fi

    mapfile -t pkgs < <(read_list dnf-apps.txt)
    dnf_install weak "${pkgs[@]}" || warn "some applications failed"

    # ⚠️ BRAVE GETS A POLICY FILE, and the one key here is MEASURED rather than
    # remembered. Chromium reads /etc/brave/policies/managed/*.json at start.
    #
    # Proven with a control on 07.08.2026, because "I wrote a policy and the
    # browser looks different" is not a measurement: with the file in place the
    # new tab is blank; with the same file REMOVED and Brave restarted, the full
    # Brave page comes back — background photo, the "Ask anything, find
    # anything…" box, a STATS panel and a REWARDS panel. That is exactly the
    # strip 2026-08-06/vorlage-brave-sauber.png asks to be rid of, and blanking
    # the new tab removes all of it at once, because all of it lives there.
    #
    # ⚠️⚠️ `BookmarkBarEnabled` IS GONE, AND THE SENTENCE THAT USED TO STAND HERE
    # WAS WRONG. It said the bar was off because Chromium has no "on hover", and
    # that "Ctrl+Shift+B brings it back for as long as it is wanted". A MANAGED
    # POLICY cannot be brought back: setting it false forces the bar off AND
    # greys the setting out, which is exactly what he ran into — "in brave sehe   # english-ok: the report, quoted
    # ich aktuell keine bookmark also ich kann die leiste auch nicht              # english-ok: the report, quoted
    # einschalten aber die brauche ich".                                          # english-ok: the report, quoted
    #
    # A policy is for the things this desktop genuinely decides — the new tab
    # page, rewards, the AI panel. Whether a bookmarks bar is showing is his,
    # and the key that made it ours has no business here. Removed rather than
    # flipped to `true`: forcing it ON would lock the switch just as hard, in the
    # other direction.
    step "brave policy"
    sudo mkdir -p /etc/brave/policies/managed
    sudo tee /etc/brave/policies/managed/buchhwin.json >/dev/null <<'POLICY'
{
  "NewTabPageLocation": "about:blank",
  "BraveRewardsDisabled": true,
  "BraveAIChatEnabled": false
}
POLICY
    ok "brave policy"

    # ⚠️ AND THE COLOURS, which the policy above does not touch. His reference
    # is 2026-08-07/vorlage-brave-gefaerbt.png: the whole browser chrome — tab
    # strip, navigation row, empty content — in the palette's dark green, not
    # Brave's own grey — his words, quoted: "bei brave soll das theme genau     english-ok: the request, quoted
    # so greifen."                                                              english-ok: the request, quoted
    #
    # ⚠️ ONE SETTING, NOT A GENERATOR. `extensions.theme.system_theme = 1` is
    # Chromium's "follow the GTK theme", and we ALREADY generate a GTK theme
    # from the palette. So Brave follows the palette for free, on every change,
    # for ever — where a colour written into a policy or a generated theme
    # extension would have to be rewritten on each switch, and /etc needs root
    # that the renderer does not have.
    #
    # ⚠️ ONLY WHILE BRAVE IS NOT RUNNING. Chromium keeps Preferences in memory
    # and writes it out on exit, so editing it under a live browser is edited
    # away again a minute later. Refusing is better than doing nothing visible.
    # ⚠️⚠️ THE BRAVE COLOUR AND FRAME MOVED TO shell/tools/render.qml, and the
    # long note that used to stand here moved with them. It said so itself:
    # "when it is proven it moves out of here. A colour has to be rewritten on
    # every palette change, so it belongs in tools/render.qml and in the Theming
    # fingerprint." It is there now, together with
    # `browser.custom_chrome_frame = false` — his "ohne close button rechts".   # english-ok: his report, quoted
    #
    # ⚠️ AND THAT TOOK THE LAST python3 OUT OF THIS FILE. Editing somebody's
    # Preferences is configuration logic, which rule 2 puts in QML and not in a
    # bash phase; tests/no-python.sh now watches the whole of lib/.
    #
    # Nothing is seeded here any more: the renderer runs during the install as
    # well, so a profile that does not exist yet is created by the same writer
    # that maintains it afterwards. One writer, one shape.


    # ⚠️ `programs.imageViewer` AND `programs.video` HAD NO READER AT ALL.
    # `loupe` and `vlc` sat in the settings and nothing ever opened them —
    # found by tests/key-readers.sh. His decision on 07.08.2026 was to make them
    # the system defaults, which is what the keys were for: then they apply
    # everywhere, out of Nautilus and out of any download, not on one key.
    #
    # ⚠️ AND BRAVE HAD TAKEN THE IMAGES. Measured on the fresh machine:
    #   image/png    brave-browser.desktop
    #   image/jpeg   brave-browser.desktop
    #   video/mp4    vlc.desktop
    # Clicking a picture opened the browser. The Brave package claims those
    # associations on install, so this is a repair as much as a setting.
    #
    # ⚠️ ONCE, AND ONLY ONCE — marked by a stamp file. Every later run leaves
    # the associations alone, because by then any difference is the user's own
    # choice and an installer that re-asserts itself on every run is a program
    # that will not be argued with. The .desktop names were read off the
    # machine, not remembered: `org.gnome.Loupe.desktop`, `vlc.desktop`.
    # MIME defaults are account-wide and therefore also affect Plasma. Leave
    # the user's KDE choices untouched; Buchhwin shortcuts launch KDE apps
    # explicitly where a particular program is intended.
    ok "KDE default applications left unchanged"

    sudo dnf install -y flatpak >/dev/null 2>&1
    sudo flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1
    # ⚠️ THE USER REMOTE HAS TO EXIST TOO. `flatpak install --user` does not see
    # a remote that was only added system-wide — measured: "No remote refs found
    # for 'flathub'", which reads like the app is missing rather than like the
    # remote is.
    flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1

    mapfile -t flat < <(read_list flatpak.txt)
    for f in "${flat[@]}"; do
        # ⚠️ SPOTIFY GOES IN PER-USER so spicetify can write into its Apps
        # directory without root — see the note in packages/flatpak.txt.
        if [[ "$f" == "com.spotify.Client" ]]; then
            step "flatpak --user $f"
            flatpak install --user -y --noninteractive flathub "$f" >/dev/null 2>&1 \
                || warn "flatpak --user $f failed"
            continue
        fi
        step "flatpak $f"
        sudo flatpak install -y --noninteractive flathub "$f" >/dev/null 2>&1 \
            || warn "flatpak $f failed"
    done

    # Discord ships with an x11-only socket set; without this it falls back to
    # X11 even with the ozone flags. Measured, not assumed. ⚠️ Vesktop is an
    # Electron app from the same family and its manifest lists `sockets=x11`
    # first, so it gets the same treatment.
    sudo flatpak override --socket=wayland dev.vencord.Vesktop 2>/dev/null || true

    install_webapp_icons

    ok "applications"
}

# ------------------------------------------------------- B76 · web app icons
# The Teams and Outlook launcher entries name an icon, and until now they named
# one nobody has: measured on a stock Fedora, `outlook` resolves in no installed
# theme at all and `teams` only inside Papirus, under the name of a completely
# different program. The entries therefore drew nothing — "teams und Outlook   # english-ok: the report, quoted
# haben kein Logo also kein icon".                                             # english-ok: the report, quoted
#
# ⚠️ SHIPPING MICROSOFT'S ARTWORK IS NOT THE FIX. It is a trademark and this
# repository is public. assets/icons holds two plain shapes of our own instead,
# which say what the app does without claiming to be anyone's logo.
install_webapp_icons() {
    local dir="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
    local src="$REPO_DIR/assets/icons"
    [[ -d "$src" ]] || { warn "assets/icons is missing — web apps will have no icon"; return 0; }

    mkdir -p "$dir"
    local n=0 f
    for f in "$src"/buchhwin-*.svg; do
        [[ -e "$f" ]] || continue
        install -m 0644 "$f" "$dir/" && n=$((n + 1))
    done

    # ⚠️ THE CACHE IS WHY THIS IS A FUNCTION AND NOT A `cp`. A scalable icon
    # dropped into hicolor is not visible to an icon loader until the theme
    # index is rebuilt, so without this the file is on disk and the launcher
    # still shows nothing — the same symptom, one layer further along.
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -qtf "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" \
            2>/dev/null || true
    fi

    # ⚠️ THE COUNT IS PRINTED, not assumed. "wallpapers in … (0)" was once an
    # `ok` line over an empty directory, and it is the reason this project reads
    # the number before it believes the tick.
    if (( n > 0 )); then
        ok "web app icons ($n)"
    else
        warn "no buchhwin-*.svg found in assets/icons"
    fi
}

# ---------------------------------------------------------------- spicetify
#
# The one program in this project that themes Spotify, and the only way to do
# it: Spotify has no configuration for colours, so spicetify patches its bundled
# web app in place.
#
# ⚠️ NOT IN ANY REPOSITORY — checked with `dnf repoquery spicetify`,
# `spicetify-cli` and `vencord`: none of the three exist in Fedora or RPM
# Fusion. So it is a pinned tarball with a checksum, the same shape as
# McMojave-cursors in 50-fonts.sh, and for the same reason.
#
# ⚠️ THE CHECKSUM WAS COMPUTED HERE, not copied from the release page. GitHub's
# API reports a digest for the asset; the file was downloaded and hashed
# independently and the two agree.
readonly SPICETIFY_VERSION=2.44.0
readonly SPICETIFY_SHA256=115045610a609a2084af389e65aa4f60351a4b8ef1497ce98bdbdf379544ef9b

phase_spicetify() {
    section "Spotify theming"

    # ⚠️ NOTHING HERE NEEDS ROOT, and that is the whole reason Spotify is
    # installed with --user (see packages/flatpak.txt). In a system flatpak the
    # directory spicetify has to write into is root-owned — measured — and a
    # theming step that needs sudo is a theming step that stops working the
    # moment he updates Spotify himself.
    local spotify="$HOME/.local/share/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify"
    if [[ ! -d "$spotify" ]]; then
        warn "Spotify is not installed per-user — skipping spicetify"
        warn "  expected $spotify"
        return 0
    fi

    local bin="$HOME/.local/bin/spicetify"
    if [[ ! -x "$bin" ]]; then
        step "fetching spicetify $SPICETIFY_VERSION"
        local tmp
        tmp="$(mktemp -d)" || { warn "no temporary directory"; return 0; }
        local url="https://github.com/spicetify/cli/releases/download/v$SPICETIFY_VERSION/spicetify-$SPICETIFY_VERSION-linux-amd64.tar.gz"

        if ! curl -fsSL -o "$tmp/s.tar.gz" "$url"; then
            warn "could not fetch spicetify; Spotify stays untinted"
            rm -rf "$tmp"; return 0
        fi

        # A mismatch STOPS. An archive that is not the one this was written
        # against is not a slightly different theming tool, it is an unknown
        # binary about to be run against a program's own files.
        local got
        got="$(sha256sum "$tmp/s.tar.gz" | cut -d' ' -f1)"
        if [[ "$got" != "$SPICETIFY_SHA256" ]]; then
            warn "spicetify checksum mismatch — refusing to unpack"
            warn "  expected $SPICETIFY_SHA256"
            warn "  got      $got"
            rm -rf "$tmp"; return 0
        fi

        mkdir -p "$HOME/.local/bin" "$HOME/.local/share/spicetify"
        if tar xzf "$tmp/s.tar.gz" -C "$HOME/.local/share/spicetify"; then
            ln -sf "$HOME/.local/share/spicetify/spicetify" "$bin"
            ok "spicetify $SPICETIFY_VERSION"
        else
            warn "spicetify archive did not unpack"
            rm -rf "$tmp"; return 0
        fi
        rm -rf "$tmp"
    else
        ok "spicetify already installed"
    fi

    # ⚠️ spicetify FOLLOWS XDG_CONFIG_HOME, measured rather than assumed — the
    # first version of this comment claimed the opposite:
    #   HOME=/tmp/sph ./spicetify -c                  -> /tmp/sph/.config/spicetify/…
    #   HOME=/tmp/sph XDG_CONFIG_HOME=/tmp/spx … -c   -> /tmp/spx/spicetify/…
    # So the renderer's ordinary `$XDG_CONFIG_HOME/spicetify/Themes/buchhwin/`
    # is the right place and the two agree without a special case.
    "$bin" config spotify_path "$spotify" >/dev/null 2>&1 || true
    "$bin" config prefs_path "$HOME/.var/app/com.spotify.Client/config/spotify/prefs" >/dev/null 2>&1 || true
    "$bin" config current_theme buchhwin >/dev/null 2>&1 || true
    "$bin" config color_scheme buchhwin >/dev/null 2>&1 || true

    # ⚠️ APPLY IS NOT RUN HERE. The colour file comes from the renderer, which
    # runs in phase_shell AFTER this one — applying now would inject a theme
    # that has no colours yet. `bhctl theme spotify` is the one command that
    # does both in the right order, and it is also the one to run after a
    # Spotify update, which throws the patch off. docs/CONFIG.md says so.
    ok "spicetify configured — run 'bhctl theme spotify' to apply"
}
