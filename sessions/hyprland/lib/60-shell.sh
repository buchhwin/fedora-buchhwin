# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: shell — put the Quickshell configuration where quickshell looks for
# it, seed the user's settings once, and render every foreign application's
# theme from the palette.
phase_shell() {
    section "Shell"

    # Everything applications see in this session lives below one dedicated
    # XDG root. Plasma continues to use ~/.config and therefore keeps its own
    # fonts, Qt/GTK themes, terminal settings and application preferences.
    local kde_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    case "$kde_config_home" in
        */buchhwin-sessions/hyprland) kde_config_home="${kde_config_home%/buchhwin-sessions/hyprland}" ;;
    esac
    local CONFIG_HOME="$kde_config_home/buchhwin-sessions/hyprland"
    local XDG_CONFIG_HOME="$CONFIG_HOME"
    export XDG_CONFIG_HOME

    # Dedicated compositor paths: no file below is read by Plasma and no KDE
    # preference is overwritten. SDDM only receives an additional session.
    #
    # The compositor config is a MODULE TREE, not a single file: hyprland.lua is
    # an entry point that require()s buchhwin/*.lua in a fixed order, and load
    # order is what decides which setting wins.
    local hypr_home="$CONFIG_HOME/buchhwin/hyprland"
    mkdir -p "$hypr_home"
    install -m 0644 "$REPO_DIR/config/hypr/hyprland.lua" "$hypr_home/hyprland.lua"

    # ⚠️ REPLACED WHOLESALE, NOT MERGED. A module dropped upstream has to
    # disappear here too — a stale file that nothing require()s any more is
    # harmless, but one that the entry point still names by an old path is a
    # config that silently keeps applying settings nobody can find.
    rm -rf "$hypr_home/buchhwin"
    mkdir -p "$hypr_home/buchhwin"
    install -m 0644 "$REPO_DIR"/config/hypr/buchhwin/*.lua "$hypr_home/buchhwin/"

    # Written by the shell's generator, never by hand and never by this
    # installer. The directory has to exist before the first generator run.
    mkdir -p "$hypr_home/generated"

    # Yours: machine-specific monitors, extra rules, personal binds. Created
    # once, empty, and never touched again by an update.
    if [[ ! -e "$hypr_home/overrides.lua" ]]; then
        install -m 0644 /dev/null "$hypr_home/overrides.lua"
    fi

    sudo install -m 0755 "$REPO_DIR/bin/buchhwin-hyprland-session" \
        /usr/local/bin/buchhwin-hyprland-session
    sudo install -m 0644 "$REPO_DIR/session/buchhwin-hyprland.desktop" \
        /usr/share/wayland-sessions/buchhwin-hyprland.desktop

    # The buchhwin-* helpers the keybindings call. Symlinked rather than copied,
    # for the same reason the shell tree below is: a git pull is immediately
    # live and there is only ever one copy to reason about. The glob is over
    # scripts/ on purpose — bin/ holds the two entries that are installed
    # system-wide instead, and must not end up on the user's PATH twice.
    local bin_home="$HOME/.local/bin"
    mkdir -p "$bin_home"
    local helper
    for helper in "$REPO_DIR"/scripts/buchhwin-*; do
        [[ -e "$helper" ]] || continue
        chmod 0755 "$helper"
        ln -sfn "$helper" "$bin_home/$(basename "$helper")"
    done

    mkdir -p "$CONFIG_HOME/xdg-desktop-portal"
    install -m 0644 "$REPO_DIR/config/xdg-desktop-portal/hyprland-portals.conf" \
        "$CONFIG_HOME/xdg-desktop-portal/hyprland-portals.conf"
    ok "isolated Hyprland configuration and SDDM session installed"

    # `qs -c buchhwin` resolves to this path. A symlink rather than a copy so
    # a git pull is immediately live and there is only ever one tree.
    mkdir -p "$CONFIG_HOME/quickshell"
    ln -sfn "$REPO_DIR/shell" "$CONFIG_HOME/quickshell/buchhwin"
    ok "shell linked to $CONFIG_HOME/quickshell/buchhwin"

    # ---------------------------------------------------------------- images
    #
    # ⚠️ NINE WALLPAPERS ARE SHIPPED, AND THAT REVERSES WHAT THIS COMMENT USED
    # TO SAY TWICE OVER. It first said wallpapers stay out of the repository —
    # somebody's photographs, tens of megabytes, public repo — and the default
    # fell back to whatever Fedora ships. Measured consequence: Fedora's
    # /usr/share/backgrounds has NO image at its top level, only directories, so
    # the fallback copied zero files, reported success, and every fresh machine
    # came up green with no picture at all.
    #
    # He asked for the opposite in as many words: the shipped picture should      # english-ok: paraphrase of a German request
    # simply BE the default, with a palette derived from it, and explicitly
    # regardless of which machine he is on. Then, with eight more pictures in
    # the same folder: "bitte auch alle ins repo packen und als standart         # english-ok: his words, quoted
    # wallpaper für die shell mit shipen und ja ich habe alle rechte für die     # english-ok: same quote, second line
    # bilder". The rights question was his to answer and he answered it.
    #
    # So all nine are in the tree, each recompressed the way the first one was:
    # no larger than 3840x2160, JPEG quality stepped down until the file is
    # under 1.2 MB. 6.3 MB became 1.1 MB, 9.5 MB became 1.2 MB, and the shell
    # loads them through `sourceSize` anyway, so the bytes bought nothing. The
    # whole folder is 6.8 MB.
    #
    # ⚠️ THE DEFAULT IS STILL buchhwin-wallpaper.jpg, and it stays that way by an
    # accident worth writing down rather than relying on: the pick below is
    # `sort | head -1`, and "." sorts before "1", so buchhwin-wallpaper.jpg comes
    # ahead of buchhwin-wallpaper1.jpg. A tenth picture named buchhwin-wallpaper0.jpg
    # would quietly become the default of every fresh machine.
    #
    # ⚠️⚠️ HIS OWN FOLDER USED TO WIN OVER IT, AND THAT SENTENCE STOOD HERE
    # UNTIL IT COST A ROUND. It now ADDS to the shipped nine instead of
    # replacing them — see BuchhwinWP below for what that cost and why.
    # ⚠️ NOT "$HOME/Bilder": that is the German name for the pictures folder,
    # and this repository is public. `xdg-user-dir` answers with whatever the
    # machine actually calls it; the fallback is the XDG default rather than a
    # translation, because a machine with no user-dirs file has no German
    # folder either.
    local pics
    pics="$(xdg-user-dir PICTURES 2>/dev/null)"
    [[ -n "$pics" && "$pics" != "$HOME" ]] || pics="$HOME/Pictures"
    local wp_dir="$pics/Wallpaper"
    local wp_src="${WALLPAPERS:-}"

    # ⚠️ A FOLDER CALLED BuchhwinWP IS THE WAY TO NAME YOUR OWN DEFAULT, and it
    # exists because the alternative was worse. He asked for one particular
    # picture to be the default — "das jetzige nix her macht" — and that picture  # english-ok: his words, quoted
    # is a 6 MB photograph from wallhaven. It cannot go in the repository: this
    # one is public and MIT, the file is somebody else's work, and the comment
    # twenty lines up already says wallpapers stay out for exactly those two
    # reasons. Hard-coding its filename here would be the same problem wearing a
    # different hat.
    #
    # So the installer looks for a FOLDER by name instead. Put your pictures in
    # one called BuchhwinWP anywhere under your home — Syncthing, a USB stick,
    # wherever — and the first of them becomes the seeded default and the source
    # of the derived palette. Nothing is named, nothing is shipped, and a
    # stranger who clones this gets the fallback below.
    # ⚠️⚠️ BOTH SOURCES, NOT THE FIRST ONE THAT EXISTS — and this is the fix for
    # "und die neuen wallpaper fehlen auf der vm".                              # english-ok: his report, quoted
    #
    # It used to be a first-match-wins chain: a folder called BuchhwinWP under
    # $HOME, ELSE the repository, ELSE /usr/share/backgrounds. When that was
    # written it was right, because the pictures were not in the repository at
    # all and a named folder was the only way to have any.
    #
    # B5 reversed that and this chain was never revisited. Nine pictures ship
    # now, and his words are explicitly about every machine — "is ja egal wo    # english-ok: his words, quoted
    # ich teste auf welchem pc das wallpaper soll einfach default werden".      # english-ok: same quote, second line
    # But every machine of his HAS such a folder, because Syncthing puts
    # one there. So on exactly the machines the brief is about, the nine shipped
    # pictures were found, skipped, and never copied.
    #
    # ⚠️ MEASURED, NOT REASONED: on the test VM the named folder holds ONE file,
    # the old wallhaven photograph, and after a complete install run
    # Pictures/Wallpaper held that one file and nothing else — with all nine
    # sitting in the repository beside it.
    #
    # So the repository is ALWAYS a source and a named folder ADDS to it.
    # `cp -n` already means neither can overwrite the other, and the repository
    # goes first so that a name collision resolves in favour of the shipped one.
    local -a wp_srcs=()
    if [[ -n "$wp_src" ]]; then
        wp_srcs+=("$wp_src")
    else
        if [[ -d "$REPO_DIR/wallpapers" ]]; then
            wp_srcs+=("$REPO_DIR/wallpapers")
        fi
        # ⚠️ ONE NAME, AND THE OLD ONE IS GONE ON PURPOSE.
        # This also looked for a folder named after the compositor this desktop
        # used to run on, so machines that already had one kept working. That
        # name is out of the repository now, so a machine still carrying a
        # folder under the OLD name will not be found. Rename it to BuchhwinWP
        # and it is picked up again — one `mv`, and Syncthing carries it.
        #
        # Written down here rather than left to be discovered, because the
        # failure is silent: the install just falls back to the shipped nine.
        local wp_named
        wp_named="$(find "$HOME" -maxdepth 4 -type d -name 'BuchhwinWP' \
                    -not -path '*/.*' 2>/dev/null | head -1)"
        if [[ -n "$wp_named" ]]; then
            wp_srcs+=("$wp_named")
        fi
        # ⚠️ LAST RESORT ONLY, and it is nearly always empty: Fedora's
        # /usr/share/backgrounds has no image at its top level, only
        # directories. It is here for a stranger who cloned this without the
        # wallpapers folder, and the zero-count warning below is what tells them.
        if [[ ${#wp_srcs[@]} -eq 0 && -d /usr/share/backgrounds ]]; then
            wp_srcs+=("/usr/share/backgrounds")
        fi
    fi

    if [[ ${#wp_srcs[@]} -gt 0 ]]; then
        mkdir -p "$wp_dir"
        # ⚠️ Top level only, and no __MACOSX: a folder that came off a Mac
        # carries a shadow tree of resource forks that are not images, and
        # FolderListModel would happily list them as broken tiles.
        local wp_one
        for wp_one in "${wp_srcs[@]}"; do
            [[ -d "$wp_one" ]] || continue
            find "$wp_one" -maxdepth 1 -type f \
                 \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
                    -o -iname '*.gif' -o -iname '*.avif' -o -iname '*.jxl' \) \
                 ! -name '.*' -exec cp -n {} "$wp_dir/" \; 2>/dev/null
        done

        # ⚠️ ZERO IS NOT SUCCESS, AND IT USED TO PRINT ONE. This line said
        # `ok "wallpapers in … (0)"` whenever $wp_src was merely a directory,
        # regardless of whether a single file arrived — and on Fedora that is
        # the normal outcome of the /usr/share/backgrounds fallback, because
        # nothing lives at its top level. A green tick over an empty folder is
        # how a machine ends up seeded with the emergency palette while the
        # install log says everything went fine.
        local wp_count
        wp_count="$(find "$wp_dir" -maxdepth 1 -type f | wc -l)"
        if [[ "$wp_count" -gt 0 ]]; then
            ok "wallpapers in $wp_dir ($wp_count)"
        else
            warn "no wallpapers copied from $wp_src — the picker will be empty"
        fi
    fi

    # The first image in the folder, as the file:// URL the shell stores.
    #
    # ⚠️ A PICTURE FROM THE NAMED FOLDER WINS IF THERE IS ONE. Otherwise "first"
    # means first alphabetically out of everything that was copied, which on a
    # machine that also has Fedora's own backgrounds is whatever happens to sort
    # earliest — and that is how the default ended up being a picture nobody
    # chose.
    # ⚠️⚠️ THE SHIPPED PICTURE WINS THE SEED, AND THAT REVERSES WHAT THIS BLOCK
    # DID — measured on a fresh install rather than reasoned about.
    #
    # A named folder used to decide the default as well as add to it, and while
    # his picture could not be shipped that was the only way to have one. B5
    # ended that: the nine are in the tree now, and his instruction is about
    # every machine — it does not matter which computer he is testing on, the      # english-ok: paraphrase of a German request
    # shipped wallpaper should become the default with a matching palette.
    #
    # ⚠️ MEASURED ON THE FRESH VM, which is what it was rebuilt for: with a
    # named folder holding one unrelated picture, a complete install came
    # up with THAT as `wallpaper.current` — on a machine that had just been
    # given all nine. Every machine of his has such a folder, so "the default on
    # every machine" was true nowhere.
    #
    # ⚠️ AND `sort` WAS THE SECOND HALF OF THE TRAP. It collates by locale, so
    # whether a foreign name sorts before "buchhwin-wallpaper.jpg" depends on
    # LC_COLLATE rather than on anything anybody decided. `LC_ALL=C` makes the
    # order a fact instead of a setting — it is why the note at the top of this
    # phase can still say "." sorts before "1" and be right.
    local wp_first=""
    if [[ -f "$wp_dir/buchhwin-wallpaper.jpg" ]]; then
        wp_first="$wp_dir/buchhwin-wallpaper.jpg"
    fi
    # A named folder still names the default when the shipped one is not there —
    # a stranger who cloned this without the wallpapers folder still gets theirs.
    if [[ -z "$wp_first" && -n "$wp_named" ]]; then
        local pick
        pick="$(find "$wp_named" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | LC_ALL=C sort | head -1)"
        [[ -n "$pick" ]] && wp_first="$wp_dir/$(basename "$pick")"
        [[ -f "$wp_first" ]] || wp_first=""
    fi
    [[ -n "$wp_first" ]] \
        || wp_first="$(find "$wp_dir" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | LC_ALL=C sort | head -1)"

    # Seeded once. Never overwritten: this file is the user's, and the shell
    # has a default for every key, so an old file cannot be "too old".
    mkdir -p "$CONFIG_HOME/buchhwin"
    if [[ -f "$CONFIG_HOME/buchhwin/shell.json" ]]; then
        ok "settings kept (shell.json exists)"

        # ⚠️ AND THE FOLDER STAYED EMPTY FOREVER ON THAT PATH. Both wallpaper
        # keys were only ever written by the seeding branch below, which runs
        # exactly once — when this file does not exist yet. Every machine that
        # had settings before wallpapers were copied kept `folder: ""`, and the
        # picker had nothing to show: reported as "wallpapers cannot be set".
        #
        # Filling a value that is EMPTY is not overwriting a decision, which is
        # the rule this file otherwise keeps. A folder somebody chose stays.
        if command -v jq >/dev/null && [[ -d "$wp_dir" ]]; then
            local f="$CONFIG_HOME/buchhwin/shell.json"
            if [[ -z "$(jq -r '.wallpaper.folder // ""' "$f" 2>/dev/null)" ]]; then
                local tmp
                tmp="$(mktemp)"
                if jq --arg d "$wp_dir" '.wallpaper.folder = $d' "$f" > "$tmp" 2>/dev/null; then
                    mv "$tmp" "$f"
                    ok "wallpaper folder filled in ($wp_dir)"
                else
                    rm -f "$tmp"
                fi
            fi

            # ⚠️⚠️ AND THE EMERGENCY STATE COULD NEVER BE UNDONE. This branch
            # exists because the seeding below happens exactly once — the first
            # time this file does not exist. A machine that came up with no
            # pictures got a palette and an empty `wallpaper.current`, and then
            # EVERY later run took this path and touched neither key. He could
            # add pictures, reinstall, and still get no image: reported as
            # "die wallpaper sind nicht als standard gesetzt".                  # english-ok: his report, quoted
            #
            # ⚠️ IT ONLY FILLS IN THE WALLPAPER NOW, and no longer changes the
            # palette with it. Until 09.09.2026 it also set `theme.palette` to
            # "wallpaper", because the scheme used to be derived from the
            # picture; the shipped default is `black` and staying black is the
            # point of it. If the accent should follow the picture there is a
            # setting for exactly that — `theme.accentSource` — and it changes
            # one colour rather than twenty-six.
            #
            # ⚠️ DELIBERATELY NARROW. It fires only on the fingerprint the
            # no-pictures branch leaves behind: an empty `wallpaper.current`.
            local cur_wp
            cur_wp="$(jq -r '.wallpaper.current // ""'  "$f" 2>/dev/null)"
            if [[ -z "$cur_wp" && -n "$wp_first" ]]; then
                local tmp2
                tmp2="$(mktemp)"
                if jq --arg u "file://$wp_first" \
                      '.wallpaper.current = $u' \
                      "$f" > "$tmp2" 2>/dev/null; then
                    mv "$tmp2" "$f"
                    ok "picked up where the empty fallback left off ($(basename "$wp_first"))"
                else
                    rm -f "$tmp2"
                fi
            fi
        fi
    elif [[ -n "$wp_first" ]]; then
        # ⚠️ THE SCHEME IS SHIPPED NOW, NOT DERIVED. Until 09.09.2026 this wrote
        # `"palette": "wallpaper"` and the desktop took all 26 of its colours
        # from whichever picture happened to be first. His decision replaced
        # that with one palette: "das default theme soll schwarz plain wie auf   # english-ok: his decision, quoted
        # den screenshots sein". The wallpaper is still set, and the accent can  # english-ok: same
        # be told to follow it — `theme.accentSource` — but the scheme is a file
        # like every other palette, and the picker changes it in one keystroke.
        # No "version": the code owns that number, see bin/bhctl and Config.qml.
        printf '{\n  "theme": { "palette": "black", "accent": "green" },\n  "wallpaper": { "folder": "%s", "current": "file://%s" }\n}\n' \
            "$wp_dir" "$wp_first" > "$CONFIG_HOME/buchhwin/shell.json"
        ok "settings seeded — black scheme, wallpaper $(basename "$wp_first")"
    else
        # No pictures anywhere, which changes nothing about the colours: the
        # scheme does not come from a picture any more. Only the wallpaper keys
        # are left out, so the first one found on a later run fills them in.
        printf '{\n  "theme": { "palette": "black", "accent": "green" }\n}\n' \
            > "$CONFIG_HOME/buchhwin/shell.json"
        warn "no wallpapers found — settings seeded without one"
    fi

    # Wayland, not XWayland — and stated as flags rather than hope.
    # Measured on Fedora 44: `--ozone-platform-hint=auto` is NOT enough.
    # Brave and Discord fell back to X11 with "Missing X server or $DISPLAY",
    # and VS Code does not even recognise the hint option.
    #
    # ⚠️ brave-flags.conf USED TO BE WRITTEN HERE AND IT DID NOTHING. That
    # convention is Arch's: their packaging ships wrapper scripts that read
    # ~/.config/<app>-flags.conf. Fedora's /opt/brave.com/brave/brave-browser is
    # a bash wrapper with ZERO occurrences of "flags.conf" — measured on the
    # laptop. The Wayland flag that
    # actually reaches Brave comes from the .desktop replacement in
    # shell/tools/hypr.qml, which is also where the 43 s -> 1.4 s startup
    # measurement lives. A file nobody reads is worse than no file: the next
    # person to look finds a plausible-looking config and stops looking.
    #
    # ⚠️ code-flags.conf WAS THE SAME FILE AND THE SAME NOTHING, and the
    # measurement promised in the commit that removed brave-flags.conf has now
    # been made: /usr/share/code/bin/code is a sh script with ZERO occurrences
    # of "flags.conf", grepped on the machine, exactly as Brave's wrapper was.
    # A running VS Code showed `/usr/share/code/code --no-sandbox` and no ozone
    # flag at all. Both files are gone and both leftovers are removed.
    #
    # The flag now reaches both programs the two ways that were measured to
    # work: a .desktop override written by shell/tools/hypr.qml for the
    # launcher, and an explicit argument in Config.programs for the keybinding,
    # which never reads a desktop file.
    mkdir -p "$CONFIG_HOME"
    rm -f "$CONFIG_HOME/brave-flags.conf" "$CONFIG_HOME/code-flags.conf"
    ok "browser and editor reach Wayland through their .desktop overrides"

    # FileView writes a file, it does not create the folder above it. On a
    # fresh machine none of these exist yet.
    mkdir -p "$CONFIG_HOME/environment.d" \
             "$CONFIG_HOME/gtk-3.0" "$CONFIG_HOME/gtk-4.0" \
             "$CONFIG_HOME/kitty" "$CONFIG_HOME/qt6ct/colors" \
             "$CONFIG_HOME/btop/themes" "$CONFIG_HOME/alacritty" \
             "$CONFIG_HOME/tmux" "$CONFIG_HOME/bat/themes" \
             "$CONFIG_HOME/git" "$CONFIG_HOME/lazygit"

    # ⚠️ AND THE ONE THAT IS NOT UNDER $CONFIG_HOME. The .desktop overrides go to
    # $XDG_DATA_HOME/applications, and that folder was in none of the lists above
    # for the whole life of the feature — the same "FileView writes a file, it
    # does not create the folder above it" that the comment right there explains.
    mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/applications"

    # ⚠️ TWO OF THE GENERATED FILES ARE NOT READ BY ANYBODY UNLESS SOMETHING
    # POINTS AT THEM, and for months nothing did.
    #
    # GTK finds gtk.css and settings.ini on its own. kitty and qt6ct do not:
    # kitty reads kitty.conf and only the files it `include`s, and qt6ct reads
    # qt6ct.conf and only the colour scheme named there. The renderer was
    # faithfully writing theme.conf and colors/buchhwin.conf into a void — so
    # the terminal sat at kitty's own black no matter which palette was chosen,
    # which is exactly how it was noticed.
    #
    # Seeded once, never overwritten: these are the user's files. If one exists
    # without the pointer, say so rather than editing it behind their back.
    if [[ ! -f "$CONFIG_HOME/kitty/kitty.conf" ]]; then
        printf '# buchhwin: colours, font and transparency come from theme.conf,\n# which is regenerated on every palette change. Your own settings go below.\ninclude theme.conf\n' \
            > "$CONFIG_HOME/kitty/kitty.conf"
        ok "kitty.conf seeded (includes the generated theme)"
    elif ! grep -q '^ *include  *theme\.conf' "$CONFIG_HOME/kitty/kitty.conf"; then
        warn "kitty.conf exists but does not 'include theme.conf' — the palette will not reach the terminal"
    fi

    if [[ ! -f "$CONFIG_HOME/qt6ct/qt6ct.conf" ]]; then
        printf '[Appearance]\ncustom_palette=true\ncolor_scheme_path=%s/qt6ct/colors/buchhwin.conf\nstyle=Fusion\nstandard_dialogs=default\n' \
            "$CONFIG_HOME" > "$CONFIG_HOME/qt6ct/qt6ct.conf"
        ok "qt6ct.conf seeded (selects the generated colours)"
    elif ! grep -q 'buchhwin\.conf' "$CONFIG_HOME/qt6ct/qt6ct.conf"; then
        warn "qt6ct.conf exists but does not select colors/buchhwin.conf — Qt apps keep their own colours"
    fi

    # The same shape for the six terminal programs, because it is the same
    # problem six more times: we generate a theme, and something has to point
    # at it. Seeded once, never edited afterwards — these files are the user's.
    #
    # Each pointer syntax was read in the program's own documentation or its
    # --help, not remembered:
    #   btop      "Themes should be placed in … $HOME/.config/btop/themes"  +
    #             color_theme = "<name>"                     (btop --default-config)
    #   alacritty import = [...] under [general]             (alacritty(5), GENERAL)
    #   tmux      source-file, config at $XDG_CONFIG_HOME/tmux/tmux.conf (tmux(1))
    #   bat       --theme in the config file                 (bat --config-file)
    #   delta     git include.path — and ⚠️ into ~/.config/git/config, NEVER
    #             ~/.gitconfig. git reads BOTH global files; measured with two
    #             HOMEs, so a hand-written ~/.gitconfig stays untouched.
    #   lazygit   has no include at all — its pointer is LG_CONFIG_FILE, written
    #             into environment.d by tools/hypr.qml. The file below only has
    #             to EXIST so the list never names a missing file.
    # ⚠️ ONLY FOR PROGRAMS THAT ARE ACTUALLY HERE, and that guard is new.
    # btop, bat, git-delta, tmux, lazygit and alacritty are no longer installed
    # by this profile — they are things a person chooses, and the lists were cut
    # back to what the desktop itself needs. Their THEMING stayed, because
    # writing a colour file costs nothing and means the palette is already right
    # the day you install one.
    #
    # What must not stay is seeding a CONFIG FILE for a program that is not
    # there: ~/.config/btop/btop.conf on a machine with no btop is a file
    # nothing reads, which the next person has to work out the meaning of. The
    # theme file is generated regardless; only the pointer waits for the program.
    seed_pointer() {   # program  file  marker  what-it-does  content
        local prog="$1" f="$2" marker="$3" what="$4" content="$5"
        if [[ -n "$prog" ]] && ! command -v "$prog" >/dev/null 2>&1; then
            return 0
        fi
        if [[ ! -f "$f" ]]; then
            printf '%s' "$content" > "$f"
            ok "$(basename "$f") seeded ($what)"
        elif ! grep -qE "$marker" "$f"; then
            warn "$(basename "$f") exists but does not $what — the palette will not reach it"
        fi
    }

    seed_pointer btop "$CONFIG_HOME/btop/btop.conf" '^color_theme *= *"buchhwin"' \
        'selects the generated theme' \
        '#? buchhwin: colours come from themes/buchhwin.theme, regenerated on
#? every palette change. Your own settings go below.
color_theme = "buchhwin"
'
    seed_pointer alacritty "$CONFIG_HOME/alacritty/alacritty.toml" 'buchhwin\.toml' \
        'import the generated theme' \
        "# buchhwin: colours, font and transparency come from buchhwin.toml,
# which is regenerated on every palette change. Yours go below — an import is
# loaded BEFORE the importing file, so anything here wins.
[general]
import = [\"$CONFIG_HOME/alacritty/buchhwin.toml\"]
"
    seed_pointer tmux "$CONFIG_HOME/tmux/tmux.conf" 'buchhwin\.conf' \
        'source the generated theme' \
        "# buchhwin: colours come from buchhwin.conf, regenerated on every
# palette change. Your own settings go below.
source-file \"$CONFIG_HOME/tmux/buchhwin.conf\"
"
    seed_pointer bat "$CONFIG_HOME/bat/config" '^--theme *= *"?buchhwin' \
        'select the generated theme' \
        '# buchhwin: the theme is built into bat cache from
# themes/buchhwin.tmTheme. Your own options go below.
--theme="buchhwin"
'
    seed_pointer delta "$CONFIG_HOME/git/config" 'buchhwin-delta\.gitconfig' \
        'include the generated delta colours' \
        "# buchhwin: git-delta's colours are generated into
# buchhwin-delta.gitconfig and included from here. Your own ~/.gitconfig is
# never touched — git reads both global files.
[include]
	path = $CONFIG_HOME/git/buchhwin-delta.gitconfig
"
    seed_pointer lazygit "$CONFIG_HOME/lazygit/config.yml" '.' \
        'exist for LG_CONFIG_FILE' \
        '# buchhwin: your lazygit settings. The generated colours are in
# buchhwin.yml, and LG_CONFIG_FILE names both files — yours first, so anything
# you set here wins.
'

    # ⚠️ WITHOUT THIS FILE THE LOCK SCREEN CANNOT CHECK A PASSWORD. PamContext
    # names a service in /etc/pam.d and there is no sensible fallback: a locker
    # that cannot authenticate is a locker you get out of with a TTY.
    #
    # Our own service rather than borrowing another program's. swaylock ships
    # /etc/pam.d/swaylock and it is tempting to point at it, but then locking
    # breaks the day swaylock is uninstalled — and it is not a dependency of
    # anything here. The shape is Fedora's own /etc/pam.d/vlock.
    if [[ ! -f /etc/pam.d/buchhwin-lock ]]; then
        sudo tee /etc/pam.d/buchhwin-lock >/dev/null <<'PAM'
#%PAM-1.0
# buchhwin lock screen. Same shape as Fedora's /etc/pam.d/vlock.
auth       include      system-auth
account    required     pam_permit.so
PAM
        ok "PAM service for the lock screen installed"
    else
        ok "PAM service for the lock screen already present"
    fi

    section "Theme"
    # FileView writes a file, it does not create the folder above it — and the
    # derived palette is the one generated file that is NOT in the repository.
    mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/buchhwin"

    step "rendering session-local GTK, Qt and kitty colours from the palette"
    # ⚠️ This also BUILDS the derived palette when the seed above chose it:
    # loading the "wallpaper" palette is what makes the shell read the image
    # and write the derived palette into XDG_STATE_HOME.
    run_tool render && ok "theme rendered"

    # The palette picker reads this instead of globbing at runtime.
    #
    # ⚠️ "wallpaper" is appended by hand rather than found by the listing: it is
    # the one palette that is generated and therefore does NOT live in this
    # folder. It used to, which meant a git pull could delete somebody's colour
    # scheme — see the note in shell/theme/Scheme.qml.
    ( cd "$REPO_DIR/shell/theme/palettes" && ls -1 ./*.json 2>/dev/null \
        | sed 's|^\./||; s|\.json$||' ) > "$REPO_DIR/shell/theme/palettes/index.txt"
    if [[ -f "${XDG_STATE_HOME:-$HOME/.local/state}/buchhwin/wallpaper.json" ]]; then
        echo wallpaper >> "$REPO_DIR/shell/theme/palettes/index.txt"
    fi

    section "Compositor"
    ok "Hyprland reads $CONFIG_HOME/buchhwin/hyprland/hyprland.lua"

    # ------------------------------------------------------------ which version
    #
    # ⚠️ THE SYSTEM PAGE ASKS "which desktop is this", AND THE ONLY HONEST
    # ANSWER COMES FROM THE INSTALL RATHER THAN FROM A LITERAL IN THE SOURCE. A
    # version typed into a QML file is right on the day it is typed and wrong
    # every day after; a key with no writer is the debt rule 5 is about.
    #
    # ⚠️ `git describe` OR NOTHING — and "nothing" is a real answer here. The
    # working copy on the lab VM is an rsync WITHOUT `.git`, so git says nothing
    # there, and that is exactly the case the page has to survive: it prints
    # "unknown — this tree was not installed by install.sh" rather than inventing
    # a number. The date is recorded either way, because "when did I install
    # this" is the other half of the question.
    mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/buchhwin"
    local stamp_ver=""
    if command -v git >/dev/null && git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        stamp_ver="$(git -C "$REPO_DIR" describe --tags --always --dirty 2>/dev/null || true)"
    fi
    if [[ -n "$stamp_ver" ]]; then
        printf '%s (installed %s)\n' "$stamp_ver" "$(date +%Y-%m-%d)" \
            > "${XDG_STATE_HOME:-$HOME/.local/state}/buchhwin/version"
        ok "version stamp: $stamp_ver"
    else
        printf 'from a copy without git history (installed %s)\n' "$(date +%Y-%m-%d)" \
            > "${XDG_STATE_HOME:-$HOME/.local/state}/buchhwin/version"
        ok "version stamp: no git history in $REPO_DIR"
    fi
}
