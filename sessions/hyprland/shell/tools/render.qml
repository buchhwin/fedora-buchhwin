// The renderer: writes every foreign application's colours, fonts and radii
// from the same tokens the shell draws itself with.
//
//   BUCHHWIN_TOOL=render QT_QPA_PLATFORM=offscreen qs -p shell
//
// This is what makes "change the palette, everything follows" true rather than
// aspirational. It runs in three situations and is the SAME code every time:
//
//   * during installation, before any session exists (headless)
//   * whenever the palette or a look setting changes (from the running shell)
//   * from `bhctl theme`, as a repair
//
// There is deliberately no template engine and no second renderer in bash.
// One writer, one set of tokens, no drift.
//
// EACH PROGRAM IS THEMED ON ITS OWN, in one of three states (config/Config.qml):
//
//   colour    the system's colours, whatever theme.palette says
//   neutral   a grey scheme — themed, but colourless. The semantic colours
//             stay anchored, so an error still reads as an error.
//   off       we write a stub that overrides nothing, and say so in it
//
// The two colour sets come from the SAME generator: theme/FromImage.qml builds
// every palette from (hue, saturation, dark), so "neutral" is that function
// with saturation zero. Not a second palette format and not a second look —
// one generator, one consumer, a different seed.
//
// Note the GTK caveat, which is written into the generated files too: setting
// gtk-decoration-layout to ":" removes the three window buttons, but a
// libadwaita headerbar is application CONTENT and stays. We remove the
// buttons, not the bar, and we say so instead of pretending.

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../config"
import "../common"

Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cfg: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")

    property string report: ""
    property int written: 0
    property int unchanged: 0

    function note(s) { report += s + "\n"; log.setText(report) }

    // ⚠️ SAY THAT WE STARTED, BEFORE ANYTHING CAN GO WRONG.
    //
    // note() overwrites the log rather than appending, so the file describes
    // one run — but only from the FIRST note(), and until now that was inside
    // WaitFor's onReady. A process that died before ever getting there (a QML
    // load error, a segfault) left the PREVIOUS run's text lying there, and
    // every reader treats that file as this run's result: bin/bhctl greps it
    // for ABORT, lib/common.sh reports from it, tests/reachable.sh is a wrapper
    // around both. That is not theory — it cost a whole attempt at the
    // per-target states, where "the renderer aborted" was read off a stale log
    // and the real failure was never seen.
    //
    // With this line a log that ends at "start" is a crash, a log that ends at
    // "ABORT" is a refusal, and a log that ends at "done" is a run. Three
    // distinguishable outcomes, one file write on tmpfs.
    Component.onCompleted: note("buchhwin render — start")

    // Every file goes through here so that "what did the renderer touch" is a
    // single list, and so a failure is reported rather than swallowed.
    //
    // ⚠️ IT COMPARES FIRST. This used to write every file on every run, and the
    // plan is explicit that "a second installation run changes no file" — which
    // was simply not true. It matters beyond tidiness: a program watching its
    // own config reloads on every write, so an unchanged rewrite is a reload
    // for nothing, and `bhctl theme apply` on an unchanged palette touched
    // seven files' mtimes. tools/hypr.qml has done it this way from the start,
    // because niri live-reloads and the cost was immediately visible there.
    //
    // `blockLoading` on the views is what makes reading and writing possible in
    // the same statement.
    function write(view, path, text, label) {
        // ⚠️ CLEAR FIRST — the same trap that shipped a broken code.desktop out
        // of tools/hypr.qml, whose write() is this function's twin. A FileView
        // hands back what it already holds, so a synchronous text() right after
        // pointing it at a new path reads the PREVIOUS file. Every caller here
        // happens to own its own view today, which is exactly why it never bit:
        // the day someone reuses one, this function would compare two different
        // files and report "same".
        //
        // ⚠️ NOT to be copied into code that reads in `onLoaded`. Measured on
        // the machine: three files through one view, read in onLoaded, returned
        // AAA/BBB/CCC correctly. Clearing there would fire onLoadFailed for the
        // empty path — in GreeterFace that would have skipped every other
        // session. tests/fileview-reuse.sh only asks about SYNCHRONOUS reads.
        view.path = ""
        view.path = path
        if (view.text() === text) {
            unchanged++
            note("  same   " + label)
            return
        }
        view.setText(text)
        written++
        note("  wrote  " + label + "  ->  " + path)
    }

    // ------------------------------------------------------------ the states
    //
    // ⚠️ AN EXPLICIT SWITCH, not Config.theming[target]. Dynamic field access
    // on a JsonObject returns undefined — measured — and an undefined that
    // falls through an else would switch off programs nobody switched off.
    //
    // ⚠️ `enabled === false`, not `!enabled`. If the key ever came back
    // undefined, `!undefined` would turn everything off AND clean up after
    // itself. The direction a doubtful case falls in is not symmetric here.
    //
    // ⚠️ An unrecognised value becomes "colour", NEVER "off", for the same
    // reason: a typo in shell.json must not remove configuration.
    //
    // Only called from onReady. Nothing here may run during construction —
    // see the note there.
    function stateOf(target) {
        var g = Config.theming
        if (g.enabled === false)
            return "off"

        var v
        switch (target) {
        case "gtk":       v = g.gtk;       break
        case "qt":        v = g.qt;        break
        case "kitty":     v = g.kitty;     break
        case "alacritty": v = g.alacritty; break
        case "btop":      v = g.btop;      break
        case "bat":       v = g.bat;       break
        case "fastfetch": v = g.fastfetch; break
        case "delta":     v = g.delta;     break
        case "tmux":      v = g.tmux;      break
        case "starship":  v = g.starship;  break
        case "lazygit":   v = g.lazygit;   break
        case "vscode":    v = g.vscode;    break
        case "brave":     v = g.brave;     break
        case "vesktop":   v = g.vesktop;   break
        case "spicetify": v = g.spicetify; break
        case "hypr":      v = g.hypr;      break
        default:          v = "inherit"
        }

        var s = String(v === undefined || v === null ? "" : v)
        if (s === "" || s === "inherit")
            s = String(g.mode || "colour")
        if (s !== "neutral" && s !== "off") {
            if (s !== "colour")
                note("  WARN   unknown state '" + s + "' for " + target + " — using colour")
            s = "colour"
        }
        return s
    }

    // The grey colour set. Built ONCE, as the first thing onReady does.
    //
    // ⚠️ NOT A BINDING, and the crash is only the third reason.
    //  1. FromImage.neutral() needs `dark`, and Theme.dark reads `true` until
    //     the palette has loaded (Scheme.qml). A property evaluated at
    //     creation would bake a DARK grey set onto latte and everforest-light.
    //  2. Holding one object guarantees all seven files come out of the same
    //     calculation even if the palette reloads mid-run.
    //  3. Reading JsonAdapter properties while the adapter is still
    //     deserialising is the shape that segfaults quickshell — ui/Shell.qml
    //     and services/Theming.qml both document it.
    // FromImage.neutral() is pure and does no I/O, so building it costs
    // nothing worth saving.
    property var neutralPal: null

    // A colour in the chosen state, as "#rrggbb".
    //
    // `key` is a PALETTE key, not a role name: theme/Theme.qml maps every role
    // straight onto one, so there is nothing to invent here — and a second
    // vocabulary for the same colour is the drift this project exists to
    // avoid. tools/smoke.qml checks the two agree.
    //
    // ⚠️ THE PALETTE STORES HEX WITHOUT THE HASH ("base": "212121"), and
    // Scheme.hex() is what puts it back. Reading colors[key] straight out of a
    // palette object and handing it to Qt.color() yields an invalid colour,
    // and the TypeError lands in whichever builder touches it first.
    function col(mode, key) {
        if (mode === "neutral") {
            var h = root.neutralPal ? root.neutralPal.colors[key] : ""
            if (h)
                return Theme.hex(Qt.color("#" + h))
            note("  WARN   the neutral set has no '" + key + "' — using the system colour")
        }
        return Theme.hex(Scheme.color(key))
    }

    // The same rule as Theme.on(), applied to the chosen colour set. Theme.on()
    // always answers out of the ACTIVE palette, which is the wrong answer for a
    // program being themed grey while the system is in colour.
    function onColour(mode, c) {
        return Theme.luminance(c) > Theme.onThreshold ? col(mode, "crust") : col(mode, "text")
    }

    // The accent — the one colour whose KEY comes from the settings.
    //
    // ⚠️ In the neutral set the configured accent is NOT usable. Five of the
    // accent names — red, maroon, peach, yellow, green — are ANCHORED in
    // FromImage and stay coloured at saturation zero, on purpose, so that an
    // error still reads as an error. Measured in the generated neutral.json:
    // green is #99cc66, while blue, mauve, teal and sapphire all come out
    // grey. So "neutral" with accent "green" — which is this project's own
    // default — would have produced a green desktop called neutral.
    // The neutral accent is the seed itself, `blue`.
    function accentOf(mode) { return col(mode, mode === "neutral" ? "blue" : Config.theme.accent) }
    function accentFgOf(mode) { return onColour(mode, Qt.color(accentOf(mode))) }

    // ⚠️ The state belongs IN the generated file, and not only for the reader:
    // it guarantees that switching colour ↔ neutral always produces a
    // difference write() can see, even for a palette whose colours happen to
    // be grey already.
    function head(hash, mode) {
        var c = hash ? "#" : " *"
        return (hash ? "" : "/*\n") +
            c + " Generated by buchhwin from palette '" + Scheme.name + "'" +
            (mode === "neutral" ? ", neutral (themed, but colourless)" : "") + ".\n" +
            c + " Do not edit — regenerated on every palette or look change.\n" +
            (hash ? "" : " */\n")
    }

    // "off" means CLEAN UP, not skip (see config/Config.qml). Cleaning up here
    // means a stub that overrides nothing — not a deletion.
    //
    // ⚠️ FileView has no delete, and that is not an obstacle but the better
    // answer: kitty.conf `include`s theme.conf and niri's config.kdl includes
    // colors.kdl. A deleted file is a pointer into nothing; a file of nothing
    // but comments is exactly as ineffective for both readers — and says why.
    // Measured for the one case where "ineffective" was not obvious: qt6ct
    // falls back to the style's palette for a colour file with no
    // active_colors, byte-identical to having no qt6ct at all.
    //
    // It goes through the same write(), so "a second run changes no file"
    // still holds and there is still one list of what the renderer touched.
    function offText(c, target) {
        return c + " Generated by buchhwin: theming is OFF for '" + target + "'.\n" +
               c + " Nothing in this file overrides anything.\n" +
               c + " It is left in place rather than deleted, so the include\n" +
               c + " that reads it does not point at nothing.\n" +
               c + " Set theming." + target + " to \"inherit\", \"colour\" or\n" +
               c + " \"neutral\" in shell.json to fill it again.\n"
    }
    function offCss(target) { return "/*\n" + offText(" *", target) + " */\n" }

    // ⚠️⚠️ A KEY FILE MUST HAVE A GROUP, EVEN WHEN IT IS EMPTY — and without
    // this every GTK 3 program printed our fault into its own stderr:
    //
    //   Gtk-WARNING: Failed to parse ~/.config/gtk-3.0/settings.ini:
    //   Key file does not have group "Settings"
    //
    // Found in Brave's log while chasing something else, on a machine where
    // theming happened to be switched off. GLib refuses a file that is only
    // comments, so "we override nothing" was being said in a way the reader
    // treats as a broken file rather than as an empty one.
    //
    // It matters more than a warning: someone looking into why GTK theming does
    // not work sees that line and starts there — which is exactly the wrong
    // place, and exactly the kind of false trail this project keeps paying for.
    //
    // ⚠️ AND THE FILE IS NOT DELETED INSTEAD. We generate it, but we cannot know
    // it was ours: a settings.ini that existed before this desktop was ever
    // installed would be somebody's own, and "theming off" is not permission to
    // remove it. An empty, VALID file overrides nothing, which is the exact
    // promise being made.
    function offIni(target) { return offText("#", target) + "[Settings]\n" }

    // One file, one state. The try/catch does not swallow anything — it
    // TRANSLATES.
    //
    // ⚠️ An exception inside a signal handler abandons the handler: the
    // remaining files are never written, Qt.quit() never runs, the process
    // hangs until `timeout 60` collects it — and because run_tool only greps
    // for ABORT, the installation says nothing at all. That is exactly how the
    // first attempt at these states failed: three GTK files written, kitty and
    // qt6ct not, and no word about it anywhere. Now it is an ABORT line with a
    // name and a reason, and the other targets are still written.
    property int threw: 0
    property var thrown: []
    function emitFile(mode, view, path, build, offBody, label, target) {
        try {
            if (mode === "off") {
                write(view, path, offBody, label + " (off)")
                return
            }
            write(view, path, build(mode), label + " (" + mode + ")")
        } catch (e) {
            root.threw++
            root.thrown.push(label)
            note("  ERROR  " + label + ": " + e)
        }
    }

    // ------------------------------------------------------------------ GTK 3
    function gtk3Css(m) {
        return head(false, m) +
            "@define-color theme_bg_color " + col(m, "base") + ";\n" +
            "@define-color theme_fg_color " + col(m, "text") + ";\n" +
            "@define-color theme_base_color " + col(m, "surface0") + ";\n" +
            "@define-color theme_text_color " + col(m, "text") + ";\n" +
            "@define-color theme_selected_bg_color " + accentOf(m) + ";\n" +
            "@define-color theme_selected_fg_color " + accentFgOf(m) + ";\n" +
            "@define-color insensitive_bg_color " + col(m, "mantle") + ";\n" +
            "@define-color insensitive_fg_color " + col(m, "overlay2") + ";\n" +
            "@define-color borders " + col(m, "overlay1") + ";\n" +
            "@define-color warning_color " + col(m, "yellow") + ";\n" +
            "@define-color error_color " + col(m, "red") + ";\n" +
            "@define-color success_color " + col(m, "green") + ";\n" +
            "@define-color accent_color " + accentOf(m) + ";\n" +
            "@define-color accent_fg_color " + accentFgOf(m) + ";\n" +
            // Shape does not follow the state: "neutral" means colourless, not
            // unstyled. Corners follow look.rounding, like every other surface.
            "\n/* Corners follow look.rounding, like every other surface. */\n" +
            "menu, .menu, popover, .popup, tooltip { border-radius: " + Theme.radiusMd + "px; }\n" +
            "button { border-radius: " + Theme.radiusSm + "px; }\n"
    }

    // ------------------------------------------------------------------ GTK 4
    // The same colour, opened up. `look.opacityApp` is what makes a GTK window
    // read as the one on the reference screenshot — near-black with the
    // wallpaper coming through, and the text still sharp.
    //
    // ⚠️ `rgba()` WITH A DECIMAL ALPHA, not an eight-digit hex. GTK's CSS parser
    // takes `rgba(r,g,b,a)` and does NOT take `#rrggbbaa`; the wrong one is not
    // an error, it is a colour that silently stays opaque.
    //
    // ⚠️ And it is written per COLOUR, not as one blanket rule on `window`.
    // libadwaita paints several surfaces — the window, the view, the sidebar —
    // and a single translucent rule underneath opaque ones changes nothing.
    // ⚠️ THERE IS NO `mix()` HELPER HERE ANY MORE, AND THE REASON IS WORTH
    // KEEPING. His report was "und nautilus ist links die leiste immer noch     english-ok: the report, quoted
    // dunkel", so the sidebar was moved half a palette step towards the window  english-ok: the report, quoted
    // colour to soften the difference. Then it was measured, and the change was
    // wrong in both size and direction:
    //
    //   his reference (vorlage-nautilus.png)   sidebar -3.6 against the content
    //   `mantle`, i.e. what shipped            sidebar -2.2
    //   the half step "fix"                    sidebar +2.6   <- lighter!
    //
    // The sidebar in the reference is slightly DARKER than the content, and
    // `mantle` already put it within 1.4 units of that — below anything anyone
    // perceives, and well inside the error of measuring a screenshot of a
    // different palette. So the shipped value was right and the fix was not.
    //
    // The helper went with it: a function nothing calls is the same debt as a
    // key nothing reads. Fifth reading this week that turned out to have no
    // control behind it — the first one caught before it shipped rather than
    // after.

    function alphaOf(hex, a) {
        var c = Qt.color(hex)
        return "rgba(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255)
             + ", " + Math.round(c.b * 255) + ", " + a.toFixed(2) + ")"
    }

    function gtk4Css(m) {
        var a = Config.look.opacityApp
        return head(false, m) +
            "@define-color window_bg_color " + alphaOf(col(m, "base"), a) + ";\n" +
            "@define-color window_fg_color " + col(m, "text") + ";\n" +
            "@define-color view_bg_color " + alphaOf(col(m, "mantle"), a) + ";\n" +
            "@define-color view_fg_color " + col(m, "text") + ";\n" +
            "@define-color headerbar_bg_color " + alphaOf(col(m, "surface0"), a) + ";\n" +
            "@define-color headerbar_fg_color " + col(m, "text") + ";\n" +
            "@define-color popover_bg_color " + col(m, "surface0") + ";\n" +
            "@define-color popover_fg_color " + col(m, "text") + ";\n" +
            "@define-color card_bg_color " + col(m, "surface0") + ";\n" +
            "@define-color card_fg_color " + col(m, "text") + ";\n" +
            "@define-color sidebar_bg_color " + alphaOf(col(m, "mantle"), a) + ";\n" +
            "@define-color sidebar_fg_color " + col(m, "text") + ";\n" +
            "@define-color dialog_bg_color " + col(m, "surface0") + ";\n" +
            "@define-color dialog_fg_color " + col(m, "text") + ";\n" +
            "@define-color accent_bg_color " + accentOf(m) + ";\n" +
            "@define-color accent_fg_color " + accentFgOf(m) + ";\n" +
            "@define-color accent_color " + accentOf(m) + ";\n" +
            "@define-color destructive_bg_color " + col(m, "red") + ";\n" +
            "@define-color destructive_fg_color " + onColour(m, Qt.color(col(m, "red"))) + ";\n" +
            "@define-color success_color " + col(m, "green") + ";\n" +
            "@define-color warning_color " + col(m, "yellow") + ";\n" +
            "@define-color error_color " + col(m, "red") + ";\n" +
            "@define-color borders " + col(m, "overlay1") + ";\n" +
            "\nwindow, popover > contents, .card { border-radius: " + Theme.radiusMd + "px; }\n" +
            "button { border-radius: " + Theme.radiusSm + "px; }\n"
    }

    // ⚠️ NOT A SINGLE COLOUR IN HERE, so it does not take the state — only the
    // header does, and only so the file names the palette it came from. Dark
    // or light is the user's decision (see Scheme.qml), and the neutral set
    // inherits it, so "neutral" keeps the dark GTK theme and the dark icons.
    function gtkSettings(m) {
        // ":" means: no window buttons on either side.
        // Honest note, repeated in the file itself: this removes the three
        // buttons. A libadwaita headerbar is content, not decoration, and stays.
        return head(true, m) +
            "# gtk-decoration-layout=\":\" removes the minimise/maximise/close\n" +
            "# buttons. It does NOT remove a libadwaita headerbar — that is part\n" +
            "# of the application's own layout and no setting can take it away.\n" +
            "[Settings]\n" +
            "gtk-application-prefer-dark-theme=" + (Theme.dark ? 1 : 0) + "\n" +
            "gtk-theme-name=" + (Theme.dark ? "adw-gtk3-dark" : "adw-gtk3") + "\n" +
            "gtk-icon-theme-name=" + (Theme.dark ? "Papirus-Dark" : "Papirus-Light") + "\n" +
            "gtk-font-name=" + Theme.fontUi + " " + Theme.fontSizePt + "\n" +
            "gtk-decoration-layout=:\n" +
            "gtk-xft-antialias=1\n" +
            "gtk-xft-hinting=1\n" +
            "gtk-xft-hintstyle=hintslight\n" +
            "gtk-xft-rgba=rgb\n"
    }

    // ------------------------------------------------------------------ kitty
    //
    // ⚠️ BEHAVIOUR AS WELL AS COLOUR, from today. This file already carried the
    // font and the background opacity, so it was never colours-only; what is
    // new is that four of the lines below describe how the terminal ACTS. See
    // the note on `terminal` in config/Config.qml for why that line was
    // crossed, and note that switching kitty's theming off takes them with it —
    // which is the honest meaning of off.
    function kittyBehaviour() {
        var t = Config.terminal
        if (!t)
            return ""
        return "\n# --- behaviour -------------------------------------------\n" +
            "cursor_shape " + t.cursorShape + "\n" +
            "cursor_blink_interval " + t.cursorBlinkInterval + "\n" +
            "cursor_trail " + t.cursorTrail + "\n" +
            "scrollback_lines " + t.scrollbackLines + "\n" +
            // ⚠️ THE BEHAVIOUR THE REWRITE LEFT BEHIND — see Config.qml.
            "shell_integration " + (t.shellIntegration ? "enabled" : "disabled") + "\n" +
            "enable_audio_bell " + (t.audibleBell ? "yes" : "no") + "\n" +
            // ⚠️ Both lines or neither. allow_remote_control on its own only
            // exposes kitty's own pty, and listen_on without it is ignored.
            // {kitty_pid} is expanded by kitty, so two terminals cannot fight
            // over one socket path.
            (t.remoteControl
             ? "allow_remote_control yes\nlisten_on unix:/tmp/kitty-{kitty_pid}\n"
             : "allow_remote_control no\n") +
            (t.scrollbackPager
             ? "scrollback_pager less --chop-long-lines --RAW-CONTROL-CHARS +INPUT_LINE_NUMBER\n"
             : "") +
            kittyKeysAndChrome()
    }

    // ⚠️ FIXED LINES, AND DELIBERATELY NOT SETTINGS. Twelve shortcuts, a tab
    // bar and a window shape as twelve-plus rows in the settings window would
    // be a wall for values nobody changes twice. They are not dead defaults
    // either: kitty.conf includes this file on its FIRST line, so anything
    // written below that include in the user's own kitty.conf wins. That is the
    // layering this project wants everywhere — we supply, they override — and
    // it is exactly why these are safe here while the four above are not.
    function kittyKeysAndChrome() {
        return "\n# --- keys, tabs and window shape --------------------------\n" +
            "# Overridable: kitty.conf includes this file first, so anything you\n" +
            "# write below that include wins.\n" +
            "map ctrl+shift+enter launch --cwd=current\n" +
            "map ctrl+shift+t     new_tab_with_cwd\n" +
            "map ctrl+shift+w     close_window\n" +
            "map ctrl+shift+left  previous_tab\n" +
            "map ctrl+shift+right next_tab\n" +
            "map ctrl+shift+up    scroll_line_up\n" +
            "map ctrl+shift+down  scroll_line_down\n" +
            "map ctrl+shift+k     scroll_page_up\n" +
            "map ctrl+shift+j     scroll_page_down\n" +
            "map ctrl+shift+h     show_scrollback\n" +
            "map ctrl+shift+g     scroll_to_prompt -1\n" +
            "map ctrl+shift+f     scroll_to_prompt 1\n" +
            "tab_bar_edge top\n" +
            "tab_bar_style powerline\n" +
            "tab_powerline_style slanted\n" +
            "window_padding_width 6\n" +
            "confirm_os_window_close 0\n"
    }

    function kittyTheme(m) {
        return head(true, m) + kittyBehaviour() +
            "foreground " + col(m, "text") + "\n" +
            "background " + col(m, "base") + "\n" +
            // ⚠️ The terminal's own transparency, not the compositor's.
            //
            // It looked "nicely transparent" only while UNFOCUSED and went
            // solid black the moment it was selected — because the only
            // translucency it had was niri's `opacity 0.96` on inactive
            // windows. That is the wrong tool twice over: it fades the TEXT
            // along with the background, and it inverts the meaning, making
            // the window you are not using the readable one.
            //
            // background_opacity affects the background alone, so the type
            // stays crisp, and it does not care whether the window has focus.
            //
            // ⚠️ Transparency is not colour: a neutral terminal is still made
            // of glass. This stays outside the state on purpose.
            "background_opacity " + Theme.terminalOpacity + "\n" +
            "selection_foreground " + accentFgOf(m) + "\n" +
            "selection_background " + accentOf(m) + "\n" +
            "cursor " + accentOf(m) + "\n" +
            "cursor_text_color " + accentFgOf(m) + "\n" +
            "url_color " + col(m, "sapphire") + "\n" +
            "active_border_color " + accentOf(m) + "\n" +
            "inactive_border_color " + col(m, "overlay1") + "\n" +
            "active_tab_foreground " + accentFgOf(m) + "\n" +
            "active_tab_background " + accentOf(m) + "\n" +
            "inactive_tab_foreground " + col(m, "subtext0") + "\n" +
            "inactive_tab_background " + col(m, "surface0") + "\n" +
            "font_family " + Theme.fontMono + "\n" +
            "font_size " + Theme.fontSizePt + "\n" +
            "color0 " + col(m, "crust") + "\n" +
            "color8 " + col(m, "overlay0") + "\n" +
            "color1 " + col(m, "red") + "\n" +
            "color9 " + col(m, "red") + "\n" +
            "color2 " + col(m, "green") + "\n" +
            "color10 " + col(m, "green") + "\n" +
            "color3 " + col(m, "yellow") + "\n" +
            "color11 " + col(m, "yellow") + "\n" +
            "color4 " + col(m, "sapphire") + "\n" +
            "color12 " + col(m, "sapphire") + "\n" +
            "color5 " + col(m, "mauve") + "\n" +
            "color13 " + col(m, "mauve") + "\n" +
            "color6 " + col(m, "teal") + "\n" +
            "color14 " + col(m, "teal") + "\n" +
            "color7 " + col(m, "subtext1") + "\n" +
            "color15 " + col(m, "text") + "\n"
    }

    // ------------------------------------------------------------------- niri
    // COLOURS ONLY. This file is `include`d by the generated config.kdl, and
    // the split is what lets a palette change leave the keybindings alone.
    //
    // ⚠️ Two rules, both from niri's own documentation and both easy to break:
    //
    //  * No `on`, no `off`, no `width`, no `gaps` here. Whether a border exists
    //    is a look setting and belongs to tools/hypr.qml. Worse, the meaning
    //    differs by file: "writing layout { border {} } in an included config
    //    does nothing… the same in the main config will ENABLE the border".
    //    Deciding visibility from here would mean deciding it differently
    //    depending on which file happened to be read.
    //
    //  * An include overrides what came before it, so config.kdl places this
    //    include after its own layout block. Sections merge property by
    //    property, so setting only colours leaves gaps and width untouched.
    // ⚠️ A SHADOW IS SHADE, NOT A COLOUR — and writing it as one was a real
    // fault, not a nicety. It used to be `crust` at a fixed alpha, `crust`
    // being the palette's darkest tone. On the two LIGHT palettes that tone is
    // nearly white (latte `#dce0e8`, everforest-light `#e6e2cc`), so every
    // window would have been given a bright HALO instead of a shadow, and
    // nothing in the shell would have said so.
    //
    // The tint therefore survives only while it is genuinely dark; otherwise
    // the shadow is black, which is what a shadow is. Light palettes also get
    // a gentler one — on a pale desktop a shadow at full strength reads as
    // dirt rather than as depth.
    function shadowColour(m, factor) {
        var c = col(m, "crust")
        var dark = Theme.luminance(c) < 0.25
        var a = Config.look.shadowOpacity * (dark ? 1.0 : 0.45) * factor
        var h = Math.round(Math.max(0, Math.min(1, a)) * 255).toString(16)
        // There is no token for the absence of light, and taking one from the
        // palette is exactly the fault described above.
        var black = "#000000"   // literal-ok: a shadow is shade, not a colour
        return (dark ? c : black) + (h.length < 2 ? "0" + h : h)
    }

    // ------------------------------------------------------------- fastfetch
    //
    // ⚠️⚠️ THE SPINNING LOGO IS GONE, AND IT WAS ASKED FOR AND THEN UNASKED.
    // On 10.08.2026 he wanted it: "statt dem fedora logo etwas animiert … das   // english-ok: the request, quoted
    // sich das logo cool um die eigene achse dreht". Later the same day:        // english-ok: the request, quoted
    // "mach einfach ein normales schönes fastfetch, nimm einfach ne pre config  // english-ok: the request, quoted
    // die passt". Offered the choice between deleting it and keeping it behind  // english-ok: the request, quoted
    // a switch, he chose deleting.
    //
    // What went: twenty-four rendered frames, the ASCII mark they were built
    // from, the still frame, the `logo.txt` fastfetch pointed at, the meta file,
    // and bin/buchhwin-fetch — the player, because fastfetch cannot animate and
    // no fetch program can. tests/no-fetch-animation.sh is the tripwire that
    // keeps a stray reference from being left behind: a deletion is not
    // provable by the absence of a file, only by nothing naming it.
    //
    // What stayed is `fetchConfig` below, which was already the "pre config":
    // its shape was measured against fastfetch 2.66 rather than guessed
    // (`--gen-config` for the module list, `--help color` for the colour keys,
    // and a probe run with `-c none` as the control). Only the LOGO changed —
    // from a file we wrote to fastfetch's own builtin Fedora mark.

    readonly property var fetchRows2: [
        { type: "os",       key: "󰍹 os",     colour: "mauve"    },
        { type: "kernel",   key: "󰌢 kernel", colour: "blue"     },
        { type: "wm",       key: "󱂬 wm",     colour: "sapphire" },
        { type: "terminal", key: "󰆍 term",   colour: "teal"     },
        { type: "shell",    key: "󰅢 shell",  colour: "green"    },
        { type: "packages", key: "󰏖 pkgs",   colour: "yellow"   },
        { type: "uptime",   key: "󰅐 up",     colour: "peach"    },
        { type: "cpu",      key: "󰻠 cpu",    colour: "maroon"   },
        { type: "memory",   key: "󰍛 mem",    colour: "red"      },
        { type: "disk",     key: "󰋊 disk",   colour: "pink"     },
        { type: "battery",  key: "󰁹 bat",    colour: "flamingo" }
    ]

    // ⚠️⚠️ `localip` IS GONE, AND IT IS RULE 2 RATHER THAN TASTE. It printed the
    // machine's own address — read off the lab VM while choosing the logo:
    // "󰩟 net  <address>/24", in the greeting that runs on EVERY new terminal.
    //
    // The standing instruction is in capitals and says "for ever": no IPs, no
    // hostnames, nothing private leaves this machine, and explicitly "not from
    // test VMs either". The rule also says screenshots carry more than you see —
    // and a fetch banner is the single most screenshotted thing on a desktop
    // like this one. It was putting the address into every one of them.
    //
    // ⚠️ THE INFORMATION IS NOT LOST, it moved to where asking for it is a
    // decision: `bhctl doctor` reports the network, and the quick panel shows
    // the connection. A greeting is not the place to publish an address.

    function fetchConfig(m) {
        var q = String.fromCharCode(34)
        function s(x) { return q + x + q }
        var accent = col(m, "blue")
        var rule = col(m, "surface2")

        // ⚠️ THE FEDORA GLYPH AS AN ESCAPE, NOT AS A LITERAL CHARACTER. It was
        // a literal one and it did not survive being edited into this file —
        // the generated config came out with `"key": ""` and fastfetch fell
        // back to printing the word "Title". A single glyph that vanishes
        // silently between an editor and a file is exactly the kind of thing
        // this project writes escapes for; the ESC byte a few functions down
        // has the same note. U+F303 is nf-linux-fedora, checked against the
        // installed font with fc-list.
        var fedora = String.fromCharCode(0xF303)
        var mods = ["    " + s("break"),
                    "    { " + s("type") + ": " + s("title") + ", "
                             + s("key") + ": " + s(fedora) + ", "
                             + s("keyColor") + ": " + s(accent) + " }",
                    "    { " + s("type") + ": " + s("custom") + ", "
                             + s("format") + ": " + s("───────────────────────────────") + ", "
                             + s("outputColor") + ": " + s(rule) + " }"]
        for (var i = 0; i < root.fetchRows2.length; i++) {
            var r = root.fetchRows2[i]
            mods.push("    { " + s("type") + ": " + s(r.type) + ", "
                      + s("key") + ": " + s(r.key) + ", "
                      + s("keyColor") + ": " + s(col(m, r.colour)) + " }")
        }
        mods.push("    { " + s("type") + ": " + s("custom") + ", "
                  + s("format") + ": " + s("───────────────────────────────") + ", "
                  + s("outputColor") + ": " + s(rule) + " }")
        mods.push("    { " + s("type") + ": " + s("colors") + ", "
                  + s("paddingLeft") + ": 2, " + s("symbol") + ": " + s("circle") + " }")
        mods.push("    " + s("break"))

        // ⚠️ THE LOGO IS fastfetch's OWN BUILTIN ONE. It used to be a file we
        // wrote — frame zero of the spinning animation — so that a bare
        // `fastfetch` outside our player still showed the same mark. There is
        // no player and no animation any more, and pointing at a file we no
        // longer write would leave fastfetch printing an error on every prompt.
        //
        // ⚠️ `builtin` RATHER THAN NAMING "fedora": fastfetch detects the
        // distribution itself, so the same config is right on a machine this
        // desktop is installed on that is not Fedora — and the repo is public,
        // so that is not hypothetical.
        // How tall the two halves are, so the padding above can line them up.
        //
        // ⚠️ `Fedora_small` IS TEN LINES on fastfetch 2.66 — measured with
        // `fastfetch -l Fedora_small -s title --pipe | wc -l`, which prints the
        // logo beside a single row and therefore reports the logo's own height.
        //
        // ⚠️ THE TEXT SIDE IS COUNTED, NOT MEASURED, because this function is
        // what writes it: one title, a separator under it, the modules, a
        // separator, and the colour row. A module that prints nothing on a
        // particular machine — `battery` on a desktop — makes the text shorter
        // and the logo then simply ends above the last line rather than below
        // it, which is the harmless direction.
        return "// Written by buchhwin — see shell/tools/render.qml. Edits are lost.\n"
             + "// fastfetch has no include mechanism, so this is the whole file.\n"
             + "{\n"
             + "  " + s("$schema") + ": "
             + s("https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json") + ",\n"
             + "  " + s("logo") + ": {\n"
             + "    " + s("type") + ": " + s("builtin") + ",\n"
             // ⚠️⚠️ THE SMALL MARK, ON HIS REPORT: "fastfetch ist noch nicht     // english-ok: the report, quoted
             // schön, das logo links ist zu groß, mach ein schöneres kleineres". // english-ok: the report, quoted
             //
             // ⚠️⚠️ AND THE LINE COUNT IS NOT A FACT ABOUT THE LOGO — IT IS A
             // FACT ABOUT THE MACHINE. This one question has now produced four
             // different numbers in this project: "10 against 19" in an early
             // handover, then 19/15/15 asked of fastfetch 2.66, then TEN on his
             // laptop and SIXTEEN on the lab VM — same fastfetch version, same
             // logo name, both measured with
             //
             //     fastfetch -l Fedora_small -s title --pipe | wc -l
             //
             // ⚠️⚠️ SO HIS REQUEST — "mach das so das das logo perfekt mit der   // english-ok: the request, quoted
             // letzten zeile abschließt" — IS DONE NOW, AND IT IS DONE BY        // english-ok: the request, quoted
             // ASKING THE MACHINE. Lining the two up needs
             // `padding.top = textLines - logoLines`, and a padding computed
             // from a TYPED logo height is right on exactly one machine: writing
             // 10 here put the logo seven lines down on the VM, which is worse
             // than the blemish it was meant to remove.
             //
             // The note that used to stand here said this generator "has no
             // synchronous way to do that yet" and left the padding at 1. It has
             // no synchronous way still — but it never needed one. `batCache`
             // three hundred lines down has run a process and waited for it
             // since the day bat was themed; the fastfetch config is simply
             // written a second time once the measurement comes back, and
             // `emitFile` writes nothing when nothing changed.
             //
             // ⚠️ BOTH NUMBERS ARE MEASURED, not one measured and one counted.
             // Deriving the text height from `mods.length` looks tidy and is
             // wrong: `break` prints a blank line, `colors` prints its own
             // number of rows, and a machine with no battery prints one line
             // fewer — the very case this has to survive. So the text is
             // measured the same way the logo is, by rendering it.
             //
             // ⚠️ AND "SMALLER" IS A NUMBER WHILE "NICER" IS A LOOK, so both
             // were rendered and read rather than picked from the sizes.
             // `Fedora_small` is the classic f-in-a-circle at a smaller size;
             // `Fedora2_small` is narrower still but abstract enough that it
             // stops reading as Fedora, which is the opposite of nicer.
             //
             // ⚠️ NAMED, AND THAT COSTS THE DETECTION. `builtin` above lets
             // fastfetch pick the logo for whatever distribution it finds, which
             // matters because this repository is public. A name pins it to
             // Fedora — which is what this desktop targets and what its own
             // installer requires, so the loss is on paper only.
             + "    " + s("source") + ": " + s("Fedora_small") + ",\n"
             // ⚠️⚠️ THE TOP PADDING IS COMPUTED SO THE LOGO ENDS WITH THE LAST
             // LINE — B61, "mach das so das das logo perfekt mit der letzten     // english-ok: the request, quoted
             // zeile abschließt". Measured on HIS machine, fastfetch 2.66:
             //
             //     fastfetch -l Fedora_small -s title --pipe | wc -l   ->  10
             //     fastfetch --pipe | wc -l                            ->  17
             //
             // Ten lines of logo against seventeen of text, so the logo has to
             // start seven lines down to finish level with the bottom.
             //
             // ⚠️ NOT THE NUMBER 7. The text is not seventeen lines everywhere:
             // a machine with no battery prints one line fewer, and the module
             // list below is the thing that decides. So the padding is derived
             // from what this function itself writes — `mods.length` plus the
             // title, the two separators and the colour row — and the logo's own
             // height is the one measured constant left.
             //
             // ⚠️ AND THE LOGO HEIGHT HAS NOW BEEN WRITTEN DOWN FIVE DIFFERENT
             // WAYS in this project: "10 against 19" in this file's own comment
             // above, "both small ones are 15" in the handover, TEN on his
             // laptop, SIXTEEN claimed for the lab VM — and NINE, which is what
             // the VM answers today. That is five numbers for one question, and
             // it is the reason none of them is typed here any more.
             //
             // ⚠️⚠️ AND THE MEASUREMENT USED TO MEASURE ITSELF, which is where
             // at least two of those numbers came from. `fastfetch -l X -s title
             // --pipe | wc -l` READS OUR OWN CONFIG, so the padding already in
             // it is added to the answer. Measured, one machine, one minute:
             //
             //     with our config (padding.top: 1)              10
             //     --config none --logo-padding-top 0             9   ← the logo
             //     --config none --logo-padding-top 6            15   = 9 + 6
             //
             // So every render would have fed its own previous padding back in
             // and the logo would have walked down the screen. The measurement
             // below neutralises both the config and the padding.
             //
             // `Math.max(0, …)` because a machine with fewer rows than the logo
             // has must not push the logo off the top.
             + "    " + s("padding") + ": { " + s("top") + ": "
                      + Math.max(0, root.fetchTextLines - root.fetchLogoLines) + ", "
                      + s("right") + ": 3 }\n"
             + "  },\n"
             + "  " + s("display") + ": {\n"
             + "    " + s("separator") + ": " + s("  ") + ",\n"
             + "    " + s("key") + ": { " + s("width") + ": 12 },\n"
             + "    " + s("color") + ": { " + s("keys") + ": " + s(accent) + ", "
                                            + s("title") + ": " + s(accent) + " }\n"
             + "  },\n"
             + "  " + s("modules") + ": [\n" + mods.join(",\n") + "\n  ]\n"
             + "}\n"
    }
    // ------------------------------------------------------- compositor colours
    //
    // ⚠️ THIS USED TO BE DEAD CODE, AND NOTHING SAID SO. Its predecessor wrote
    // niri's colors.kdl and was left behind by the move to Hyprland: the switch
    // in stateOf() lost its case, the theming block lost its key, and the emit
    // call went with the rest. The function stayed, compiled, and was never
    // called — so from the palette switcher onwards everything looked right
    // while no colour reached the compositor at all.
    //
    // ⚠️ COLOURS ONLY. Structure — border width, gaps, blur — belongs to the
    // config generator (tools/hypr.qml). Writing a `border_size` here would put
    // one setting in two files that are generated by different tools on
    // different triggers, which is the drift this project keeps a rule against.
    //
    // Hyprland wants rgb()/rgba(), not "#rrggbb". Both halves of the border
    // are written even though borders are off by default, because turning them
    // on is a settings toggle and a border in yesterday's colour is exactly the
    // kind of half-applied theme this file exists to prevent.
    function hyprColours(m) {
        function rgb(hex) { return "rgb(" + String(hex).replace(/^#/, "") + ")" }

        return head(true, m).replace(/^#/gm, "--") +
            "-- Colours only. Structure lives in the generated settings module.\n" +
            "\n" +
            "hl.config({\n" +
            "    general = {\n" +
            "        col = {\n" +
            "            active_border = \"" + rgb(accentOf(m)) + "\",\n" +
            "            inactive_border = \"" + rgb(col(m, "surface1")) + "\",\n" +
            "        },\n" +
            "    },\n" +
            "    decoration = {\n" +
            "        shadow = {\n" +
            "            color = \"" + rgb(col(m, "crust")) + "\",\n" +
            "        },\n" +
            "    },\n" +
            "})\n"
    }


    // ------------------------------------------------------------------- Qt
    //
    // ⚠️ ALL THREE GROUPS, and this file was written for months with only one.
    //
    // qt6ct takes the colour scheme ONLY if active, inactive AND disabled each
    // carry a full set of roles; otherwise it silently keeps the fallback,
    // which is Qt's own default palette:
    //
    //     if(activeColors.count() >= QPalette::NColorRoles &&
    //        inactiveColors.count() >= QPalette::NColorRoles &&
    //        disabledColors.count() >= QPalette::NColorRoles) { … }
    //     else { customPalette = fallback; }
    //         — qt6ct-0.11, src/qt6ct-common/qt6ct.cpp
    //
    // We wrote active_colors and nothing else, so every Qt application has
    // been running on plain Fusion grey while the file, the pointer in
    // qt6ct.conf and the test all said the colours were there. Measured with a
    // QApplication under QT_QPA_PLATFORMTHEME=qt6ct: with one list the palette
    // came back #efefef/#000000, byte-identical to having no qt6ct at all;
    // with three it came back the palette's own #27231b/#e8e6e3.
    //
    // Exactly the same shape as the kitty theme that was written into a void
    // for a milestone — hence the test extension that reads the file back.
    //
    // 21 entries, in QPalette::ColorRole order up to PlaceholderText. qt6ct
    // appends Accent itself by copying Highlight when the list stops one short
    // of NColorRoles, so 21 is the intended length rather than an oversight.
    function qtColors(m) {
        var fg = col(m, "text"), bg = col(m, "base"), surface = col(m, "surface0")
        var dim = col(m, "mantle"), disabled = col(m, "overlay2")
        var active = [fg, surface, col(m, "surface1"), surface, dim, bg,
                      fg, fg, fg, bg, bg, col(m, "crust"), accentOf(m), accentFgOf(m),
                      col(m, "sapphire"), col(m, "teal"), surface, fg, dim, fg,
                      disabled]
        // Inactive is the same set on purpose: Qt uses it for windows that do
        // not have focus, and a desktop where the unfocused window changes
        // colour is the very effect kitty's background_opacity note argues
        // against. niri already dims unfocused windows if look.opacityInactive
        // says so — one mechanism, not two.
        var inactive = active.slice()
        // Disabled differs in exactly one thing: text stops being readable as
        // text. Everything structural stays, or a greyed-out dialog turns into
        // a different dialog.
        var dis = active.slice()
        dis[0] = disabled     // WindowText
        dis[6] = disabled     // Text
        dis[7] = disabled     // BrightText
        dis[8] = disabled     // ButtonText
        dis[13] = disabled    // HighlightedText
        dis[17] = disabled    // NoRole
        dis[19] = disabled    // ToolTipText
        return head(true, m) +
            "[ColorScheme]\n" +
            "active_colors=" + active.join(", ") + "\n" +
            "inactive_colors=" + inactive.join(", ") + "\n" +
            "disabled_colors=" + dis.join(", ") + "\n"
    }

    // ------------------------------------------------------------------ btop
    //
    // 37 keys, counted in a shipped theme rather than remembered
    // (/usr/share/btop/themes/*.theme). The format is theme[key]="#rrggbb", and
    // btop finds a user theme in ~/.config/btop/themes — both stated by btop's
    // own default config, which also names the pointer: color_theme.
    //
    // ⚠️ main_bg IS DELIBERATELY EMPTY. btop's own comment: "empty for terminal
    // default, need to be empty if you want transparent background". Writing
    // our base colour here would paint an opaque rectangle over a terminal we
    // went to some trouble to make translucent.
    function btopTheme(m) {
        function k(key, colour) { return "theme[" + key + "]=\"" + colour + "\"\n" }
        // Three-stop gradients. Meaning first: rising load goes green → yellow
        // → red, and that direction survives the neutral state because those
        // three are anchored.
        function ramp(prefix, a, b, c) {
            return k(prefix + "_start", col(m, a)) +
                   k(prefix + "_mid", col(m, b)) +
                   k(prefix + "_end", col(m, c))
        }
        return head(true, m) +
            "theme[main_bg]=\"\"\n" +
            k("main_fg", col(m, "text")) +
            k("title", col(m, "text")) +
            k("hi_fg", accentOf(m)) +
            k("selected_bg", col(m, "surface1")) +
            k("selected_fg", col(m, "text")) +
            k("inactive_fg", col(m, "overlay1")) +
            k("proc_misc", col(m, "teal")) +
            k("cpu_box", col(m, "overlay0")) +
            k("mem_box", col(m, "overlay0")) +
            k("net_box", col(m, "overlay0")) +
            k("proc_box", col(m, "overlay0")) +
            k("div_line", col(m, "overlay0")) +
            ramp("temp", "green", "yellow", "red") +
            ramp("cpu", "green", "yellow", "red") +
            ramp("free", "green", "teal", "sapphire") +
            ramp("cached", "sapphire", "blue", "mauve") +
            ramp("available", "teal", "sapphire", "blue") +
            ramp("used", "yellow", "peach", "red") +
            ramp("download", "green", "teal", "sapphire") +
            ramp("upload", "yellow", "peach", "red")
    }

    // ------------------------------------------------------------- alacritty
    //
    // The alternative terminal, themed from the same tokens as kitty so the two
    // are not two looks. ⚠️ `import` lives under [general] as of 0.14 — read in
    // alacritty(5), where it sits in the GENERAL section — and the importing
    // file is loaded LAST, so our values are the ones a user can override.
    function alacrittyToml(m) {
        function q(s) { return "\"" + s + "\"" }
        return head(true, m) +
            "[window]\n" +
            // The same argument as kitty's background_opacity: the terminal's
            // own transparency, not the compositor's, so the type stays crisp.
            "opacity = " + Theme.terminalOpacity + "\n\n" +
            "[font]\nnormal = { family = " + q(Theme.fontMono) + " }\n" +
            "size = " + Theme.fontSizePt + "\n\n" +
            "[colors.primary]\n" +
            "background = " + q(col(m, "base")) + "\n" +
            "foreground = " + q(col(m, "text")) + "\n\n" +
            "[colors.cursor]\n" +
            "text = " + q(accentFgOf(m)) + "\n" +
            "cursor = " + q(accentOf(m)) + "\n\n" +
            "[colors.selection]\n" +
            "text = " + q(accentFgOf(m)) + "\n" +
            "background = " + q(accentOf(m)) + "\n\n" +
            "[colors.normal]\n" +
            "black = " + q(col(m, "crust")) + "\n" +
            "red = " + q(col(m, "red")) + "\n" +
            "green = " + q(col(m, "green")) + "\n" +
            "yellow = " + q(col(m, "yellow")) + "\n" +
            "blue = " + q(col(m, "sapphire")) + "\n" +
            "magenta = " + q(col(m, "mauve")) + "\n" +
            "cyan = " + q(col(m, "teal")) + "\n" +
            "white = " + q(col(m, "subtext1")) + "\n\n" +
            "[colors.bright]\n" +
            "black = " + q(col(m, "overlay0")) + "\n" +
            "red = " + q(col(m, "red")) + "\n" +
            "green = " + q(col(m, "green")) + "\n" +
            "yellow = " + q(col(m, "yellow")) + "\n" +
            "blue = " + q(col(m, "sapphire")) + "\n" +
            "magenta = " + q(col(m, "mauve")) + "\n" +
            "cyan = " + q(col(m, "teal")) + "\n" +
            "white = " + q(col(m, "text")) + "\n"
    }

    // ------------------------------------------------------------------ tmux
    //
    // Sourced from tmux.conf. tmux reads ~/.tmux.conf or
    // $XDG_CONFIG_HOME/tmux/tmux.conf (tmux(1)), and `source-file` is the
    // pointer.
    function tmuxConf(m) {
        return head(true, m) +
            "set -g status-style \"bg=" + col(m, "mantle") + ",fg=" + col(m, "text") + "\"\n" +
            "set -g status-left-style \"bg=" + accentOf(m) + ",fg=" + accentFgOf(m) + ",bold\"\n" +
            "set -g status-right-style \"bg=" + col(m, "surface0") + ",fg=" + col(m, "subtext1") + "\"\n" +
            "setw -g window-status-current-style \"bg=" + accentOf(m) +
            ",fg=" + accentFgOf(m) + ",bold\"\n" +
            "setw -g window-status-style \"bg=" + col(m, "mantle") + ",fg=" + col(m, "subtext0") + "\"\n" +
            "setw -g window-status-activity-style \"fg=" + col(m, "yellow") + "\"\n" +
            "set -g pane-border-style \"fg=" + col(m, "overlay1") + "\"\n" +
            "set -g pane-active-border-style \"fg=" + accentOf(m) + "\"\n" +
            "set -g message-style \"bg=" + col(m, "surface0") + ",fg=" + col(m, "text") + "\"\n" +
            "set -g mode-style \"bg=" + accentOf(m) + ",fg=" + accentFgOf(m) + "\"\n" +
            "set -g display-panes-active-colour \"" + accentOf(m) + "\"\n" +
            "set -g display-panes-colour \"" + col(m, "overlay1") + "\"\n" +
            "set -g clock-mode-colour \"" + accentOf(m) + "\"\n"
    }

    // -------------------------------------------------------------- git-delta
    //
    // ⚠️ INCLUDED FROM ~/.config/git/config, NEVER WRITTEN INTO ~/.gitconfig.
    // Proven rather than hoped: git reads BOTH global files, so an [include] in
    // the XDG one takes effect while a hand-written ~/.gitconfig is left
    // completely alone — measured with two HOMEs and `git config --get`.
    //
    // `syntax-theme` is bat's theme registry, not delta's own: delta renders
    // through bat. It is only named here when bat is themed as well, because
    // pointing at a theme that was never built is the same mistake as writing
    // a file nobody reads.
    function deltaGitconfig(m, batThemed) {
        return head(true, m) +
            "[delta]\n" +
            (batThemed ? "\tsyntax-theme = buchhwin\n" : "") +
            "\tminus-style = normal \"" + col(m, "mantle") + "\"\n" +
            "\tminus-emph-style = normal \"" + col(m, "red") + "\"\n" +
            "\tplus-style = normal \"" + col(m, "surface0") + "\"\n" +
            "\tplus-emph-style = normal \"" + col(m, "green") + "\"\n" +
            "\tline-numbers-minus-style = \"" + col(m, "red") + "\"\n" +
            "\tline-numbers-plus-style = \"" + col(m, "green") + "\"\n" +
            "\tline-numbers-zero-style = \"" + col(m, "overlay1") + "\"\n" +
            "\tline-numbers-left-style = \"" + col(m, "overlay0") + "\"\n" +
            "\tline-numbers-right-style = \"" + col(m, "overlay0") + "\"\n" +
            "\tfile-style = bold \"" + accentOf(m) + "\"\n" +
            "\tfile-decoration-style = \"" + col(m, "overlay0") + "\" ul\n" +
            "\thunk-header-style = \"" + col(m, "subtext0") + "\"\n" +
            "\thunk-header-decoration-style = \"" + col(m, "overlay0") + "\" box\n" +
            "\tblame-palette = \"" + col(m, "base") + "\" \"" + col(m, "mantle") +
            "\" \"" + col(m, "surface0") + "\" \"" + col(m, "surface1") + "\"\n"
    }

    // ------------------------------------------------------------------- bat
    //
    // A .tmTheme — the Sublime format bat's syntax highlighter reads — and the
    // one target with a second step: bat only sees a theme after
    // `bat cache --build`, so the file alone is exactly the kitty mistake with
    // a different name. The renderer runs it, and waits for it.
    function batTheme(m) {
        function scope(name, colour, style) {
            return "\t\t<dict>\n\t\t\t<key>scope</key><string>" + name + "</string>\n" +
                   "\t\t\t<key>settings</key><dict>\n" +
                   "\t\t\t\t<key>foreground</key><string>" + colour + "</string>\n" +
                   (style ? "\t\t\t\t<key>fontStyle</key><string>" + style + "</string>\n" : "") +
                   "\t\t\t</dict>\n\t\t</dict>\n"
        }
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<!-- Generated by buchhwin from palette '" + Scheme.name + "'" +
            (m === "neutral" ? ", neutral" : "") + ". Do not edit. -->\n" +
            "<plist version=\"1.0\">\n<dict>\n" +
            "\t<key>name</key><string>buchhwin</string>\n" +
            "\t<key>settings</key>\n\t<array>\n" +
            "\t\t<dict>\n\t\t\t<key>settings</key><dict>\n" +
            "\t\t\t\t<key>background</key><string>" + col(m, "base") + "</string>\n" +
            "\t\t\t\t<key>foreground</key><string>" + col(m, "text") + "</string>\n" +
            "\t\t\t\t<key>caret</key><string>" + accentOf(m) + "</string>\n" +
            "\t\t\t\t<key>lineHighlight</key><string>" + col(m, "surface0") + "</string>\n" +
            "\t\t\t\t<key>selection</key><string>" + col(m, "surface1") + "</string>\n" +
            "\t\t\t</dict>\n\t\t</dict>\n" +
            scope("comment", col(m, "overlay1"), "italic") +
            scope("string", col(m, "green"), "") +
            scope("constant.numeric", col(m, "peach"), "") +
            scope("constant.language", col(m, "peach"), "") +
            scope("constant.character, constant.other", col(m, "peach"), "") +
            scope("keyword, storage.type, storage.modifier", col(m, "red"), "") +
            scope("entity.name.function, support.function", accentOf(m), "") +
            scope("entity.name.type, entity.name.class, support.type, support.class",
                  col(m, "yellow"), "") +
            scope("variable, variable.parameter", col(m, "text"), "") +
            scope("entity.name.tag", col(m, "mauve"), "") +
            scope("entity.other.attribute-name", col(m, "teal"), "") +
            scope("punctuation, meta.brace", col(m, "subtext0"), "") +
            scope("invalid", col(m, "red"), "") +
            "\t</array>\n</dict>\n</plist>\n"
    }

    // --------------------------------------------------------------- lazygit
    //
    // ⚠️ THE ONLY TARGET WHOSE POINTER IS AN ENVIRONMENT VARIABLE.
    // lazygit reads one config file, and the only way to add a second is
    // LG_CONFIG_FILE with a comma-separated list — stated by lazygit's own
    // --help ("Comma separated list to custom config file(s)"). We already own
    // environment.d, so that is a pointer we can set without editing anything
    // of the user's. Ours is listed LAST so their own config still wins.
    function lazygitYml(m) {
        function style(key, colour, extra) {
            return "    " + key + ":\n      - \"" + colour + "\"\n" +
                   (extra ? "      - " + extra + "\n" : "")
        }
        return head(true, m) +
            "gui:\n  theme:\n" +
            style("activeBorderColor", accentOf(m), "bold") +
            style("inactiveBorderColor", col(m, "overlay1"), "") +
            style("searchingActiveBorderColor", col(m, "yellow"), "bold") +
            style("optionsTextColor", col(m, "subtext0"), "") +
            style("selectedLineBgColor", col(m, "surface1"), "") +
            style("inactiveViewSelectedLineBgColor", col(m, "surface0"), "") +
            style("cherryPickedCommitFgColor", col(m, "base"), "") +
            style("cherryPickedCommitBgColor", col(m, "teal"), "") +
            style("markedBaseCommitFgColor", col(m, "base"), "") +
            style("markedBaseCommitBgColor", col(m, "yellow"), "") +
            style("unstagedChangesColor", col(m, "red"), "") +
            style("defaultFgColor", col(m, "text"), "")
    }

    // blockLoading so write() can compare against what is already on disk in
    // the same statement; printErrors off because "not there yet" is the normal
    // case on a first run and not a fault worth shouting about. Same shape as
    // tools/hypr.qml:520-521.
    FileView { id: f1; blockLoading: true; printErrors: false }
    FileView { id: f2; blockLoading: true; printErrors: false }
    FileView { id: f3; blockLoading: true; printErrors: false }
    FileView { id: f4; blockLoading: true; printErrors: false }
    FileView { id: f5; blockLoading: true; printErrors: false }
    FileView { id: f6; blockLoading: true; printErrors: false }
    FileView { id: f7; blockLoading: true; printErrors: false }
    FileView { id: f8; blockLoading: true; printErrors: false }
    FileView { id: f9; blockLoading: true; printErrors: false }
    FileView { id: f10; blockLoading: true; printErrors: false }
    FileView { id: f11; blockLoading: true; printErrors: false }
    FileView { id: f12; blockLoading: true; printErrors: false }
    FileView { id: f13; blockLoading: true; printErrors: false }
    FileView { id: f14; blockLoading: true; printErrors: false }
    FileView { id: f15; blockLoading: true; printErrors: false }
    FileView { id: f16; blockLoading: true; printErrors: false }
    FileView { id: f17; blockLoading: true; printErrors: false }
    // ⚠️ A SECOND ONE FOR THE FRAMES, AND IT IS NOT A SPARE. f17 wrote the meta
    // file and was then pointed at frames.txt in the next statement; `text()`
    // did not give back the new file in time, so the compare in write() always
    // differed and 26 kB was rewritten on every render. tests/reachable.sh
    // caught it as "a second run rewrote files that did not change" — which is
    // the check earning its keep, because nothing else would ever have noticed
    // a file being rewritten with identical content. Every other call site in
    // this file has its own view; these two now do as well.
    FileView { id: f18; blockLoading: true; printErrors: false }
    FileView { id: f19; blockLoading: true; printErrors: false }
    FileView { id: f20; blockLoading: true; printErrors: false }
    // Vesktop's theme and spicetify's colour set — one view each, for the
    // reason spelled out above f18.
    FileView { id: f21; blockLoading: true; printErrors: false }
    FileView { id: f22; blockLoading: true; printErrors: false }
    // Brave's Preferences. Its OWN view, and the reason is not tidiness: `f20`
    // was the obvious free-looking id and it is already the fetch logo's, so
    // reading Preferences through it would have handed back the logo's text for
    // a path it had never loaded. That is the trap tests/fileview-reuse.sh
    // exists for, sprung while writing the guard against it.
    FileView { id: f23; blockLoading: true; printErrors: false }
    FileView { id: f24; blockLoading: true; printErrors: false }

    // ------------------------------------------------------------- Vesktop
    //
    // ⚠️ VESKTOP RATHER THAN DISCORD, AND IT WAS MEASURED BEFORE IT WAS
    // DECIDED. Vencord themes a Discord that has been PATCHED, and on this
    // system Discord is a flatpak: /var/lib/flatpak/…/discord/resources/app.asar
    // is root-owned with a LINK COUNT OF 2, which means it is hardlinked into
    // OSTree's object store — writing through it rewrites a shared object, and
    // the next `flatpak update` throws the patch away regardless.
    //
    // Vesktop is Discord with Vencord already inside it, so there is nothing to
    // patch: the theme is a CSS file in a directory that belongs to the user.
    // He chose it over patching on 10.08.2026 with both costs on the table.
    //
    // ⚠️ THE PATH IS READ OUT OF THE SHIPPED SOURCE, NOT GUESSED. Vesktop's
    // app.asar carries its own TypeScript:
    //
    //     export const DATA_DIR = process.env.VENCORD_USER_DATA_DIR
    //         || (PORTABLE ? join(vesktopDir, "Data") : join(app.getPath("userData")))
    //     export const VENCORD_THEMES_DIR = join(DATA_DIR, "themes")
    //
    // and under flatpak `app.getPath("userData")` is
    // ~/.var/app/dev.vencord.Vesktop/config/vesktop — confirmed by the
    // `settings/` directory the app creates there on its first run.
    //
    // ⚠️⚠️ AND A THEME FILE IS NOT ENOUGH ON ITS OWN. Vencord is DOWNLOADED by
    // Vesktop at first start — it is not in the flatpak — so its settings, and
    // with them the list of enabled themes, do not exist until then. The file
    // is written here and has to be ticked ONCE under Settings → Themes. That
    // is a manual step, so it is said out loud: the row in the settings window
    // carries it, and so does docs/CONFIG.md. A theme that is written and never
    // enabled would be a generator writing into the void, which is exactly what
    // tests/reachable.sh exists to catch.
    function vesktopCss(m) {
        return head(false, m) +
            "/* Ticked once under Settings -> Themes; Vencord remembers it. */\n" +
            ":root {\n" +
            "    --background-primary: " + col(m, "base") + ";\n" +
            "    --background-secondary: " + col(m, "mantle") + ";\n" +
            "    --background-secondary-alt: " + col(m, "surface0") + ";\n" +
            "    --background-tertiary: " + col(m, "crust") + ";\n" +
            "    --background-accent: " + accentOf(m) + ";\n" +
            "    --background-floating: " + col(m, "surface0") + ";\n" +
            "    --background-modifier-hover: " + col(m, "surface1") + ";\n" +
            "    --background-modifier-active: " + col(m, "surface2") + ";\n" +
            "    --background-modifier-selected: " + col(m, "surface1") + ";\n" +
            "    --channeltextarea-background: " + col(m, "surface0") + ";\n" +
            "    --text-normal: " + col(m, "text") + ";\n" +
            "    --text-muted: " + col(m, "subtext0") + ";\n" +
            "    --text-link: " + accentOf(m) + ";\n" +
            "    --header-primary: " + col(m, "text") + ";\n" +
            "    --header-secondary: " + col(m, "subtext1") + ";\n" +
            "    --interactive-normal: " + col(m, "subtext1") + ";\n" +
            "    --interactive-hover: " + col(m, "text") + ";\n" +
            "    --interactive-active: " + col(m, "text") + ";\n" +
            "    --interactive-muted: " + col(m, "overlay0") + ";\n" +
            "    --brand-experiment: " + accentOf(m) + ";\n" +
            "    --brand-experiment-560: " + accentOf(m) + ";\n" +
            "    --button-danger-background: " + col(m, "red") + ";\n" +
            "    --info-warning-foreground: " + col(m, "yellow") + ";\n" +
            "    --info-positive-foreground: " + col(m, "green") + ";\n" +
            "    --scrollbar-thin-thumb: " + col(m, "surface2") + ";\n" +
            "    --scrollbar-auto-thumb: " + col(m, "surface2") + ";\n" +
            "    --scrollbar-auto-track: " + col(m, "mantle") + ";\n" +
            "}\n"
    }

    // ----------------------------------------------------------- spicetify
    //
    // A `color.ini` under ~/.config/spicetify/Themes/buchhwin/ — spicetify's own
    // layout, one section per colour scheme. The theme is applied by the
    // spicetify binary, which the installer pins and which has to be re-run
    // after a Spotify update; docs/CONFIG.md carries that sentence.
    //
    // ⚠️ SPOTIFY IS INSTALLED PER-USER FOR THIS TO WORK AT ALL. spicetify writes
    // into Spotify's own Apps directory, and in a SYSTEM flatpak that is
    // root-owned — measured. As a --user install it lives under
    // ~/.local/share/flatpak and belongs to him, so nothing here needs root.
    //
    // ⚠️ SIX-DIGIT HEX WITHOUT THE HASH. spicetify's ini parser takes the value
    // literally and a leading '#' starts a comment in an ini file — the whole
    // line would vanish, silently, and the theme would fall back to Spotify's
    // own colours.
    function spicetifyIni(m) {
        function bare(c) { return String(c).replace("#", "") }
        return "; Generated by buchhwin from palette '" + Scheme.name + "'"
             + (m === "neutral" ? ", neutral (themed, but colourless)" : "") + ".\n"
             + "; Do not edit — regenerated on every palette or look change.\n"
             + "[buchhwin]\n"
             + "text               = " + bare(col(m, "text")) + "\n"
             + "subtext            = " + bare(col(m, "subtext0")) + "\n"
             + "main               = " + bare(col(m, "base")) + "\n"
             + "sidebar            = " + bare(col(m, "mantle")) + "\n"
             + "player             = " + bare(col(m, "mantle")) + "\n"
             + "card               = " + bare(col(m, "surface0")) + "\n"
             + "shadow             = " + bare(col(m, "crust")) + "\n"
             + "selected-row       = " + bare(col(m, "subtext1")) + "\n"
             + "button             = " + bare(accentOf(m)) + "\n"
             + "button-active      = " + bare(accentOf(m)) + "\n"
             + "button-disabled    = " + bare(col(m, "surface2")) + "\n"
             + "tab-active         = " + bare(col(m, "surface1")) + "\n"
             + "notification       = " + bare(col(m, "surface0")) + "\n"
             + "notification-error = " + bare(col(m, "red")) + "\n"
             + "misc               = " + bare(col(m, "surface2")) + "\n"
    }

    // ------------------------------------------------------------- VS Code
    //
    // ⚠️ AN EXTENSION, NOT A PILE OF colorCustomizations. VS Code has no
    // include mechanism, so the only two ways in are its settings file — which
    // belongs to the user and would then hold two hundred generated lines — or
    // a colour theme of our own, which is a directory we own entirely with a
    // ONE LINE pointer in the user's file. That is the same shape as kitty's
    // include and btop's `color_theme`, and it is the shape this project uses
    // everywhere for a reason: `off` has something to take back out.
    function vscodePackage() {
        return JSON.stringify({
            name: "buchhwin-theme",
            displayName: "Buchhwin",
            description: "Generated from the buchhwin palette. Do not edit.",
            version: "1.0.0",
            publisher: "buchhwin",
            engines: { vscode: "^1.70.0" },
            categories: ["Themes"],
            contributes: {
                themes: [{
                    label: "Buchhwin",
                    uiTheme: Theme.dark ? "vs-dark" : "vs",
                    path: "./themes/buchhwin-color-theme.json"
                }]
            }
        }, null, 2) + "\n"
    }

    function vscodeTheme(m) {
        var c = ({
            "editor.background": col(m, "base"),
            "editor.foreground": col(m, "text"),
            "editorLineNumber.foreground": col(m, "overlay0"),
            "editorLineNumber.activeForeground": accentOf(m),
            "editorCursor.foreground": accentOf(m),
            "editor.selectionBackground": col(m, "surface1"),
            "editor.lineHighlightBackground": col(m, "mantle"),
            "sideBar.background": col(m, "mantle"),
            "sideBar.foreground": col(m, "subtext1"),
            "sideBarSectionHeader.background": col(m, "surface0"),
            "activityBar.background": col(m, "crust"),
            "activityBar.foreground": col(m, "text"),
            "activityBarBadge.background": accentOf(m),
            "activityBarBadge.foreground": accentFgOf(m),
            "statusBar.background": col(m, "crust"),
            "statusBar.foreground": col(m, "subtext0"),
            "titleBar.activeBackground": col(m, "crust"),
            "titleBar.activeForeground": col(m, "text"),
            "tab.activeBackground": col(m, "base"),
            "tab.inactiveBackground": col(m, "mantle"),
            "tab.activeBorderTop": accentOf(m),
            "panel.background": col(m, "mantle"),
            "terminal.background": col(m, "base"),
            "terminal.foreground": col(m, "text"),
            "focusBorder": accentOf(m),
            "list.activeSelectionBackground": col(m, "surface1"),
            "list.hoverBackground": col(m, "surface0"),
            "errorForeground": col(m, "red"),
            "editorError.foreground": col(m, "red"),
            "editorWarning.foreground": col(m, "yellow"),
            "editorInfo.foreground": col(m, "blue")
        })
        return JSON.stringify({
            name: "Buchhwin",
            type: Theme.dark ? "dark" : "light",
            colors: c,
            tokenColors: [
                { scope: ["comment"], settings: { foreground: col(m, "overlay1"),
                                                  fontStyle: "italic" } },
                { scope: ["string"], settings: { foreground: col(m, "green") } },
                { scope: ["constant.numeric"], settings: { foreground: col(m, "peach") } },
                { scope: ["keyword", "storage.type"], settings: { foreground: col(m, "mauve") } },
                { scope: ["entity.name.function"], settings: { foreground: col(m, "blue") } },
                { scope: ["variable"], settings: { foreground: col(m, "text") } },
                { scope: ["entity.name.type"], settings: { foreground: col(m, "yellow") } }
            ]
        }, null, 2) + "\n"
    }

    // ⚠️ THE USER'S OWN FILE, TOUCHED WITH TWO KEYS AND A BACKUP.
    //
    // settings.json is JSONC — VS Code allows comments in it — and JSON.parse
    // does not. Whole-line comments are stripped, which cannot corrupt a `//`
    // inside a string on a value line, and that is the only stripping done. If
    // what is left still does not parse, NOTHING is written and the line to add
    // by hand is printed instead. Destroying somebody's editor settings to set
    // a colour scheme would be a poor trade.
    function vscodeSettings(mode) {
        var raw = f16.text()
        var obj = ({})
        if (raw && raw.trim().length) {
            var stripped = raw.split("\n").filter(function (l) {
                return l.replace(/^\s+/, "").indexOf("//") !== 0
            }).join("\n")
            try {
                obj = JSON.parse(stripped)
            } catch (e) {
                return null
            }
            if (typeof obj !== "object" || obj === null)
                return null
        }
        if (mode === "off") {
            delete obj["workbench.colorTheme"]
        } else {
            obj["workbench.colorTheme"] = "Buchhwin"
        }
        // Not part of the colour scheme, and set in both states on purpose:
        // "native" means the compositor draws the frame, and niri's
        // prefer-no-csd then draws none at all — no title bar, no buttons.
        obj["window.titleBarStyle"] = "native"
        return JSON.stringify(obj, null, 4) + "\n"
    }

    // Brave's Preferences — the same shape as vscodeSettings above, and for the
    // same two reasons: it is a JSON file somebody else owns, and one of the
    // keys is not a colour.
    //
    // ⚠️⚠️ IF IT DOES NOT PARSE, NOTHING IS WRITTEN. Preferences holds his
    // profile — sessions, permissions, search engines. Overwriting it to set a
    // frame would be a spectacularly poor trade, and the file being unreadable
    // is exactly when the temptation to "just write a fresh one" appears.
    //
    // ⚠️ AN ABSENT FILE IS FINE and is NOT the same case: Brave fills in the
    // rest on first run, so `{}` plus our two keys is a valid Preferences.
    //
    // ⚠️ BRAVE MUST NOT BE RUNNING. It holds the file in memory and writes it
    // out on exit, so anything written underneath a live Brave is discarded
    // without a word. lib/40-apps.sh already waits for it; this reports the
    // fact rather than pretending the write landed.
    //
    // ⚠️⚠️ AND THE COLOUR IS A SIGNED 32-BIT SkColor, NOT "#rrggbb" AND NOT A
    // 24-BIT NUMBER. This was measured on 07.08.2026 and written down in
    // lib/40-apps.sh before this function existed — and the first draft here
    // ignored it and wrote `parseInt("rrggbb", 16)`, which Brave would have
    // taken and dropped without a word.
    //
    // The stored form is 0xAARRGGBB wrapped into negative:
    //
    //     {'is_grayscale': False, 'user_color': -5783424}
    //     -5783424 & 0xFFFFFFFF == 0xFFA7CE00   ->  alpha FF, rgb A7CE00
    //
    // `| 0` is what does the wrapping in JS. Alpha is always FF: a translucent
    // browser chrome is not on offer here.
    //
    // ⚠️ `is_grayscale` GOES WITH IT. It was measured alongside, and leaving it
    // out means a profile that once had grayscale on keeps ignoring the colour.
    function bravePreferences(mode) {
        var raw = f23.text()
        var obj = ({})
        if (raw && raw.trim().length) {
            try {
                obj = JSON.parse(raw)
            } catch (e) {
                return null
            }
            if (typeof obj !== "object" || obj === null)
                return null
        }
        if (obj.browser === undefined || obj.browser === null
            || typeof obj.browser !== "object")
            obj.browser = ({})

        // The frame, in every state — see the note on the config key. This is
        // what takes the buttons off the right-hand end.
        obj.browser.custom_chrome_frame = false

        // ⚠️ THE BOOKMARKS BAR IS ON, AS A DEFAULT RATHER THAN A LAW. He asked
        // for it — "in brave sehe ich aktuell keine bookmark … die brauche ich   // english-ok: the report, quoted
        // die bitte anmachen den rest aus lassen" — and it had been forced OFF   // english-ok: the request, quoted
        // by a managed policy, which also greyed out the switch. The policy key
        // is gone (lib/40-apps.sh); this writes the preference instead.
        //
        // ⚠️ A PREFERENCE, NOT A POLICY, IS THE WHOLE POINT: Ctrl+Shift+B still
        // works and whatever he chooses afterwards survives, because Brave owns
        // this file and simply keeps the newer value. A policy would have taken
        // the choice away again in the opposite direction.
        //
        // ⚠️ AND IT IS SET IN BOTH MODES. Theming being switched off is about
        // COLOUR; the bar is not a colour, and making it disappear with the
        // palette would be the same class of surprise as the policy was.
        obj.bookmark_bar = obj.bookmark_bar || ({})
        obj.bookmark_bar.show_on_all_tabs = true

        if (obj.browser.theme === undefined || obj.browser.theme === null
            || typeof obj.browser.theme !== "object")
            obj.browser.theme = ({})

        if (mode === "off") {
            // Our colour goes away and Brave goes back to its own. The frame key
            // stays: it is not ours to give back, it is what "no title bars"
            // means on this desktop.
            delete obj.browser.theme.user_color
            delete obj.browser.theme.is_grayscale
        } else {
            // ⚠️⚠️ `col()`, NOT `Theme.bg`, AND THE FIRST DRAFT GOT THIS WRONG.
            // It read `Theme.hex(Theme.bg)` and duly wrote -16777216 — pure
            // black — because OUR OWN surfaces are black by his choice. Foreign
            // programs are explicitly excluded from that: "aber nicht apps      // english-ok: his rule, quoted
            // etc". This whole file reads the PALETTE and never Theme.qml, and
            // that separation is the only thing keeping the black-surfaces
            // switch from leaking into thirteen other programs.
            //
            // `base` is what every other window background here uses — the GTK
            // theme's `theme_bg_color` and `window_bg_color` are the same token.
            var c = col(mode, "base")
            var rgb = parseInt(String(c).replace("#", ""), 16)
            obj.browser.theme.user_color = ((0xFF << 24) | rgb) | 0
            obj.browser.theme.is_grayscale = false
        }
        // ⚠️ SEPARATORS WITHOUT SPACES, matching what Chromium itself writes.
        // A reformatted Preferences is a diff nobody can read and a file Brave
        // rewrites on the next exit anyway — there is nothing to gain by
        // prettifying somebody else's profile.
        return JSON.stringify(obj) + "\n"
    }
    FileView { id: log; path: "/tmp/buchhwin-render.log" }

    // ⚠️ bat NEEDS A SECOND STEP, and without it this whole target is the kitty
    // mistake again: the .tmTheme sits in the right folder and bat has never
    // heard of it until `bat cache --build` compiles it into its own cache.
    //
    // Only run when the theme actually changed — it takes about a second and
    // rebuilding an unchanged cache on every look tweak is exactly the kind of
    // idle work this project measures itself against. And the process is waited
    // for rather than fired off: the renderer quits in the next event loop
    // step, which would kill it.
    // ------------------------------------------------- the settings GTK 4 reads
    //
    // ⚠️ settings.ini IS NOT WHERE GTK 4 LOOKS FOR THESE. Measured on the
    // machine: with `gtk-icon-theme-name=Papirus-Dark` written into both
    // gtk-3.0/settings.ini and gtk-4.0/settings.ini, `gsettings get
    // org.gnome.desktop.interface icon-theme` still answered 'Adwaita' — and
    // Nautilus duly drew Adwaita's blue folders on a warm dark palette. Same
    // for `color-scheme`, which answered 'default'.
    //
    // libadwaita and GTK 4 take these from the settings portal, which reads
    // dconf. So they are written there as well as into the files: the files
    // still matter for GTK 3 and for anything that reads them directly, and
    // this is what the toolkit the file manager is built on actually consults.
    //
    // ⚠️ `reset`, not "write the old value back", when theming is off. We never
    // knew what was there before — reset returns the key to the system default,
    // which is the honest meaning of "we are not touching this any more".
    //
    // ⚠️ Through `sh` for the same reason as bat below: a Process whose binary
    // is missing never reports back, and a machine without gsettings would hang
    // the renderer on its guard timer.
    function gsettingsScript(mode) {
        var iface = "org.gnome.desktop.interface"
        if (mode === "off")
            return "command -v gsettings >/dev/null || exit 0; "
                 + "for k in icon-theme gtk-theme color-scheme font-name "
                 + "cursor-theme cursor-size; do "
                 + "gsettings reset " + iface + " $k; done"
        var icons = Theme.dark ? "Papirus-Dark" : "Papirus-Light"
        var gtk = Theme.dark ? "adw-gtk3-dark" : "adw-gtk3"
        var scheme = Theme.dark ? "prefer-dark" : "prefer-light"
        var font = Theme.fontUi + " " + Theme.fontSizePt
        return "command -v gsettings >/dev/null || exit 0; "
             + "gsettings set " + iface + " icon-theme '" + icons + "'; "
             + "gsettings set " + iface + " gtk-theme '" + gtk + "'; "
             + "gsettings set " + iface + " color-scheme '" + scheme + "'; "
             + "gsettings set " + iface + " font-name '" + font + "'; "
             // ⚠️ THE POINTER GOES HERE TOO, not only into the compositor's config. GTK
             // reads it from gsettings and never asks the compositor, so
             // setting only one of the two gives a pointer that changes shape
             // when it crosses from the desktop onto a window.
             //
             // ⚠️ AND IT WORKS — which is worth writing down because it was
             // reported as broken for an afternoon. A single reading said
             // gsettings still held the old theme after a render, and that was
             // a snapshot of a run that had already finished, not a fault. The
             // control settled it: set BOTH `gtk-theme` and `cursor-theme` to
             // nonsense by hand, run `bhctl theme apply`, and both come back —
             // gtk-theme to adw-gtk3-dark, cursor-theme to McMojave-cursors.
             // Fourth time in one week that a "bug" was a measurement without a
             // control.
             + "gsettings set " + iface + " cursor-theme '"
             + Config.cursor.theme + "'; "
             + "gsettings set " + iface + " cursor-size "
             + Config.cursor.size
    }

    Process { id: gsettingsApply }

    // ⚠️ B61 · THE TWO NUMBERS THAT LINE THE LOGO UP WITH THE LAST LINE, and
    // both are asked of the machine rather than typed. See the long note in
    // `fetchConfig`: five different logo heights have been written down in this
    // project for one question, and two of them were this measurement reading
    // its own previous output.
    property bool fetchMeasured: false
    property int fetchLogoLines: 0
    property int fetchTextLines: 0
    // The probe the text height is measured against, so the real config is
    // written once and with the answer already in it. /tmp because it is
    // scaffolding, not configuration — nothing reads it after the process ends.
    readonly property string fetchProbePath: "/tmp/buchhwin-ff-probe.jsonc"
    FileView { id: fProbe; blockLoading: true; printErrors: false }

    // Re-writes the fastfetch config once the measurement is in, then carries on
    // to the bat step exactly as the main block would have.
    //
    // ⚠️ ONCE, AND THE FLAG IS NOT BELT-AND-BRACES. Both the guard timer and
    // `onExited` end here, and on a machine slow enough for the timer to fire
    // first they would both arrive — starting the bat build twice and calling
    // `finish()` twice with it.
    property bool fetchPassed: false
    function fetchSecondPass() {
        if (root.fetchPassed)
            return
        root.fetchPassed = true
        fetchGuard.stop()
        var m = stateOf("fastfetch")
        emitFile(m, f19, root.cfg + "/fastfetch/config.jsonc",
                 fetchConfig,
                 "// buchhwin: theming is OFF for fastfetch.\n"
                 + "// This file overrides nothing; delete it for fastfetch's own defaults.\n"
                 + "{ }\n",
                 "fastfetch config", "fastfetch")
        if (root.batPending) {
            note("  running bat cache --build (a theme file alone is invisible to bat)")
            batGuard.start()
            batCache.running = true
            return
        }
        root.finish()
    }

    Process {
        id: fetchMeasure
        // ⚠️ THROUGH `sh` FOR THE SAME REASON AS batCache BELOW: a Process whose
        // binary is missing never emits onExited, and this would then sit on its
        // guard timer on every machine without fastfetch.
        //
        // ⚠️⚠️ `--config none` AND `--logo-padding-top 0` ARE THE MEASUREMENT.
        // Without them fastfetch reads the file this renderer just wrote and
        // adds its padding to the answer, so each run would feed its own last
        // result back in and the logo would walk down the screen. Measured:
        // 9 lines bare, 10 with our padding of 1, 15 with a padding of 6.
        //
        // ⚠️ AND THE TEXT IS RENDERED, NOT COUNTED. `--logo none` against the
        // config we just wrote gives the real number of rows on THIS machine —
        // which is how the no-battery case, one line shorter, takes care of
        // itself instead of needing a rule.
        command: ["sh", "-c",
                  "command -v fastfetch >/dev/null || exit 3; "
                  + "logo=$(fastfetch --config none --logo-padding-top 0 "
                  + "-l Fedora_small -s title --pipe 2>/dev/null | wc -l); "
                  + "text=$(fastfetch --config " + root.fetchProbePath + " "
                  + "--logo none --pipe 2>/dev/null | wc -l); "
                  + "rm -f " + root.fetchProbePath + "; "
                  + "echo \"$logo $text\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = String(this.text).trim().split(/\s+/)
                if (parts.length >= 2) {
                    root.fetchLogoLines = parseInt(parts[0], 10) || 0
                    root.fetchTextLines = parseInt(parts[1], 10) || 0
                }
            }
        }
        onExited: function (code) {
            if (code === 3) {
                root.note("  skip   fastfetch is not installed; the logo padding stays at 0")
            } else if (code !== 0 || root.fetchLogoLines <= 0) {
                root.note("  WARN   could not measure the fastfetch logo (exit " + code
                          + ") — the logo will not line up with the last row")
            } else {
                root.note("  measured fastfetch: logo " + root.fetchLogoLines
                          + " rows, text " + root.fetchTextLines
                          + " -> padding.top "
                          + Math.max(0, root.fetchTextLines - root.fetchLogoLines))
            }
            root.fetchSecondPass()
        }
    }
    Timer {
        id: fetchGuard
        interval: 10000
        onTriggered: {
            root.note("  ERROR  measuring fastfetch did not finish in 10 s")
            root.fetchSecondPass()
        }
    }

    property bool batPending: false
    Process {
        id: batCache
        // ⚠️ THROUGH `sh`, AND THAT IS NOT A STYLE CHOICE.
        //
        // A Process whose binary does not exist never emits onExited, so the
        // renderer sat on the guard timer for the full ten seconds on every
        // single run on a machine without bat — measured at 11 s, and the CI
        // container has no bat, which would have been six of those inside one
        // suite. `sh` always exists, so the signal always comes: immediately
        // when bat is absent, after the real build when it is there.
        command: ["sh", "-c", "command -v bat >/dev/null || exit 3; exec bat cache --build"]
        onExited: function (code) {
            // 3 is our own signal for "bat is not installed", which is not a
            // fault: the theme file is written and will be compiled the day it
            // is. Anything else is bat itself failing, and that is worth a line.
            root.note(code === 0 ? "  built  bat cache"
                    : code === 3 ? "  skip   bat is not installed; the theme is written anyway"
                                 : "  ERROR  bat cache --build exited " + code)
            root.finish()
        }
    }
    Timer {
        id: batGuard
        interval: 10000
        onTriggered: {
            root.note("  ERROR  bat cache --build did not finish in 10 s")
            root.finish()
        }
    }
    function finish() {
        batGuard.stop()
        note("done: " + written + " written, " + unchanged + " unchanged")
        if (root.threw) {
            note("buchhwin render — ABORT")
            note("  " + root.threw + " target(s) threw: " + root.thrown.join(", "))
        }
        Qt.callLater(Qt.quit)
    }

    // Wait for the palette to actually be there. The previous fixed 700 ms
    // timer looked like it was doing this and was not: it touched Scheme for
    // the first time inside itself, so the palette had not begun loading when
    // `ready` was tested. See WaitFor.qml.
    WaitFor {
        condition: Config.settled && Scheme.ready

        // The derived palette may have to read the wallpaper first, which is
        // a deliberate ~1.8 s wait (the quantiser lies on its first signal —
        // see Scheme.qml). Five seconds is right for reading a file and wrong
        // for reading an image, and this runs on the installer's critical path.
        timeoutMs: Scheme.derived ? 12000 : 5000

        onTimedOut: {
            note("buchhwin render — ABORT")
            note("  the palette did not load; refusing to write fallback colours")
            note("  " + (Scheme.failure.length ? Scheme.failure : "no reason reported"))
            Qt.callLater(Qt.quit)
        }

        onReady: {
            // ⚠️ NOTHING ABOVE THIS LINE READS Config OR Scheme. This is the
            // first moment the config has settled AND the deferral in
            // WaitFor.qml has passed, which is the difference between the
            // real values and the adapter's defaults.
            root.neutralPal = FromImage.neutral(Theme.dark, 0)

            var mGtk = stateOf("gtk"), mQt = stateOf("qt")
            var mKitty = stateOf("kitty")
            var mHypr = stateOf("hypr")
            var mBtop = stateOf("btop"), mAla = stateOf("alacritty")
            var mTmux = stateOf("tmux"), mBat = stateOf("bat")
            var mDelta = stateOf("delta"), mLazy = stateOf("lazygit")
            var mFastfetch = stateOf("fastfetch")

            note("buchhwin render — palette " + Scheme.name +
                 " (" + Scheme.displayName + "), accent " + Config.theme.accent)
            note("  states: gtk=" + mGtk + " qt=" + mQt + " kitty=" + mKitty +
                 " btop=" + mBtop + " alacritty=" + mAla +
                 " tmux=" + mTmux + " bat=" + mBat + " delta=" + mDelta +
                 " lazygit=" + mLazy + "   (theming.enabled " + Config.theming.enabled +
                 ", theming.mode " + Config.theming.mode + ")")

            emitFile(mGtk, f1, root.cfg + "/gtk-3.0/gtk.css",
                     gtk3Css, offCss("gtk"), "gtk3 colours", "gtk")
            emitFile(mGtk, f2, root.cfg + "/gtk-3.0/settings.ini",
                     gtkSettings, offIni("gtk"), "gtk3 settings", "gtk")
            emitFile(mGtk, f3, root.cfg + "/gtk-4.0/gtk.css",
                     gtk4Css, offCss("gtk"), "gtk4 colours", "gtk")
            gsettingsApply.command = ["sh", "-c", root.gsettingsScript(mGtk)]
            gsettingsApply.running = true
            note("  set    gtk desktop settings via gsettings (" + mGtk + ")")

            emitFile(mGtk, f4, root.cfg + "/gtk-4.0/settings.ini",
                     gtkSettings, offIni("gtk"), "gtk4 settings", "gtk")
            emitFile(mKitty, f5, root.cfg + "/kitty/theme.conf",
                     kittyTheme, offText("#", "kitty"), "kitty", "kitty")
            emitFile(mQt, f7, root.cfg + "/qt6ct/colors/buchhwin.conf",
                     qtColors, offText("#", "qt"), "qt6ct", "qt")
            // ⚠️ THE ONE FILE THAT REACHES THE COMPOSITOR. Its predecessor was
            // written for niri and then left uncalled through the move to
            // Hyprland, so a palette change stopped arriving there entirely —
            // silently, because a function nobody calls raises nothing.
            // generated/colors.lua is loaded by hyprland.lua after the shipped
            // defaults, next to the settings the config generator writes.
            emitFile(mHypr, f24, root.cfg + "/buchhwin/hyprland/generated/colors.lua",
                     hyprColours, offText("--", "hypr"), "compositor colours", "hypr")
            emitFile(mBtop, f8, root.cfg + "/btop/themes/buchhwin.theme",
                     btopTheme, offText("#", "btop"), "btop", "btop")
            emitFile(mAla, f9, root.cfg + "/alacritty/buchhwin.toml",
                     alacrittyToml, offText("#", "alacritty"), "alacritty", "alacritty")
            emitFile(mTmux, f10, root.cfg + "/tmux/buchhwin.conf",
                     tmuxConf, offText("#", "tmux"), "tmux", "tmux")
            emitFile(mDelta, f11, root.cfg + "/git/buchhwin-delta.gitconfig",
                     function (mm) { return deltaGitconfig(mm, mBat !== "off") },
                     offText("#", "delta"), "git-delta", "delta")
            emitFile(mLazy, f12, root.cfg + "/lazygit/buchhwin.yml",
                     lazygitYml, offText("#", "lazygit"), "lazygit", "lazygit")

            // bat last, because it is the one that has to be compiled after it
            // is written.
            var batBefore = written
            var home = Quickshell.env("HOME") || "~"
            var ext = home + "/.vscode/extensions/buchhwin-theme"
            var mCode = stateOf("vscode")
            emitFile(mCode, f14, ext + "/package.json",
                     function () { return root.vscodePackage() },
                     root.vscodePackage(), "vscode manifest", "vscode")
            emitFile(mCode, f15, ext + "/themes/buchhwin-color-theme.json",
                     root.vscodeTheme,
                     // ⚠️ `off` writes an EMPTY theme rather than deleting it.
                     // The pointer in settings.json is taken out at the same
                     // time, but a stale pointer at a deleted theme makes VS
                     // Code fall back with a warning on every start.
                     JSON.stringify({ name: "Buchhwin", colors: {}, tokenColors: [] },
                                    null, 2) + "\n",
                     "vscode theme", "vscode")
            f16.path = root.cfg + "/Code/User/settings.json"
            var codeSettings = root.vscodeSettings(mCode)
            if (codeSettings === null)
                note("  skip   vscode settings.json does not parse — "
                     + "add \"workbench.colorTheme\": \"Buchhwin\" by hand")
            else
                write(f16, root.cfg + "/Code/User/settings.json", codeSettings,
                      "vscode settings (" + mCode + ")")

            // Brave. The same shape as vscode's settings.json above: a foreign
            // JSON file, merged rather than replaced, and skipped entirely if it
            // does not parse.
            //
            // ⚠️ CLEAR THE PATH FIRST — a FileView hands back what it already
            // holds for a path it already has. Fourth trap of its kind in this
            // project; tests/fileview-reuse.sh reads this file too.
            var bravePrefs = root.cfg + "/BraveSoftware/Brave-Browser/Default/Preferences"
            f23.path = ""
            f23.path = bravePrefs
            var mBrave = stateOf("brave")
            var braveText = root.bravePreferences(mBrave)
            if (braveText === null)
                note("  skip   brave Preferences does not parse — left alone")
            else
                write(f23, bravePrefs, braveText, "brave (" + mBrave + ")")

            emitFile(mBat, f13, root.cfg + "/bat/themes/buchhwin.tmTheme",
                     batTheme, "<!-- buchhwin: theming is OFF for bat. -->\n",
                     "bat", "bat")
            root.batPending = written !== batBefore

            // ⚠️ THE TWO WHOSE FILES LIVE OUTSIDE ~/.config, each for its own
            // reason: Vesktop is a flatpak and keeps its data under ~/.var/app,
            // and spicetify insists on ~/.config/spicetify whatever
            // XDG_CONFIG_HOME says — so the first is spelled out from $HOME and
            // the second from root.cfg like the rest.
            emitFile(stateOf("vesktop"), f21,
                     home + "/.var/app/dev.vencord.Vesktop/config/vesktop/themes/buchhwin.css",
                     vesktopCss,
                     "/* buchhwin: theming is OFF for Vesktop. */\n",
                     "vesktop", "vesktop")
            emitFile(stateOf("spicetify"), f22,
                     root.cfg + "/spicetify/Themes/buchhwin/color.ini",
                     spicetifyIni,
                     "; buchhwin: theming is OFF for spicetify.\n",
                     "spicetify", "spicetify")

            // ⚠️ starship STILL HAS NO WRITER, and it is not an oversight:
            // read in its own binary and --help output, it names a single
            // config file that belongs to the user, with no include mechanism.
            // Its colours come from the terminal's sixteen ANSI colours, which
            // the kitty and alacritty themes above already set, so it follows
            // the palette without a file of its own. Said out loud rather than
            // silently skipped.
            //
            // ⚠️ fastfetch USED TO BE IN THAT SENTENCE AND NO LONGER IS. It
            // still has no config file we write — but it now has a LOGO we
            // write, twenty-four frames of it, and those are palette-coloured
            // and therefore have to be rewritten when the palette changes.
            note("  no file of its own: starship — it follows the " +
                 "terminal's ANSI colours (no include mechanism exists)")

            // ⚠️ NOTHING IS WRITTEN FOR THE LOGO ANY MORE. There used to be
            // three files here — frames.txt, meta and logo.txt — plus the
            // player that read them. fastfetch draws its own builtin Fedora
            // mark now, which is what "ne pre config die passt" means.        // english-ok: the request, quoted
            //
            // ⚠️ THE OLD FILES ARE NOT DELETED BY THIS RUN, and that is said
            // rather than quietly assumed: a machine that ran an earlier
            // version still has ~/.config/buchhwin/fetch/ lying about. It is
            // inert — nothing reads it, and the config no longer points at it —
            // and removing somebody's files is not something a theme renderer
            // should start doing. `bhctl doctor` names it instead.

            // ⚠️⚠️ B61 · MEASURED FIRST, WRITTEN ONCE. The obvious shape — write
            // the file, measure it, write it again with the right padding — was
            // built and `tests/reachable.sh` caught it in one run: "a second run
            // rewrote files that did not change". It writes padding 0 and then
            // padding 6 on EVERY render, so the file is never at rest and every
            // idempotence check in this repo is right to complain.
            //
            // So the text height is measured against a PROBE in /tmp with the
            // same module list, and the real file is written exactly once, with
            // the number already in it.
            if (mFastfetch === "colour" && !root.fetchMeasured) {
                root.fetchMeasured = true
                try {
                    fProbe.path = ""
                    fProbe.path = root.fetchProbePath
                    fProbe.setText(fetchConfig(mFastfetch))
                    fetchMeasure.running = true
                    fetchGuard.start()
                    return
                } catch (e) {
                    note("  WARN   could not write the fastfetch probe: " + e)
                }
            }

            emitFile(mFastfetch, f19, root.cfg + "/fastfetch/config.jsonc",
                     fetchConfig,
                     "// buchhwin: theming is OFF for fastfetch.\n"
                     + "// This file overrides nothing; delete it for fastfetch's own defaults.\n"
                     + "{ }\n",
                     "fastfetch config", "fastfetch")

            if (root.batPending) {
                note("  running bat cache --build (a theme file alone is invisible to bat)")
                batGuard.start()
                batCache.running = true
                return
            }
            root.finish()
        }
    }
}
