// Appearance — size, shape, transparency, effects, type and the pointer.
//
// ⚠️ THIS IS THREE PAGES IN ONE, and the merge is his decision rather than a
// tidy-up: Size & Shape, Effects and Type & Pointer became one page, the way
// the dwl session has a single Appearance area. Nothing was dropped in the
// move — every row that was on the three pages is below, under the heading it
// already had.
//
// ⚠️ IT IS THE LONGEST PAGE IN THE WINDOW, AND THAT IS THE COST. The note at
// the top of SettingsContent.qml says nothing should be longer than seventeen
// rows, because two pages holding two thirds of every setting is what
// "unübersichtlich und echt schlecht" was about. This page has thirty-one. The  // english-ok: the brief, quoted
// five SettingGroups below are what keeps it navigable — the fault back then
// was an unstructured column, not a long one.
//
// ⚠️ TWO ROWS ARRIVED FROM THE DELETED MOTION PAGE, and they are here rather
// than gone because each answers a question the rest of this page cannot.
// `look.profile` is the one lever for a machine that would rather have the
// frames — docs/CONFIG.md calls it the first thing to reach for on a slow
// machine — and `motion.reduce` is an accessibility switch. The three duration
// keys and the bounce went with the page; those were tuning.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "Size and shape"

        // ⚠️ THE SCREEN SCALE USED TO BE HERE AND HAS MOVED TO Displays. It is
        // per monitor, and so are the resolution and the refresh rate it belongs
        // beside; here it was the only control on the page that was not a
        // SettingRow, sitting above four that were. `look.uiScale` below stays,
        // because it is one number for our own surfaces and genuinely is a
        // matter of size and shape.
        SettingRow {
            Layout.fillWidth: true
            key: "look.uiScale"
            label: "Interface scale"
            hint: "Multiplies our own grid and type together, on top of the screen scale above. The fine adjustment, not the 4K lever."
            kind: "slider"
            from: 0.75; to: 2.0; step: 0.05; decimals: 2; unit: "×"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.rounding"
            label: "Corner radius"
            hint: "Every other radius in the shell is a proportion of this one."
            kind: "slider"
            from: 0; to: 32; step: 1; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.borderWidth"
            advanced: true
            label: "Window border"
            kind: "slider"
            from: 0; to: 8; step: 1; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.panelBorderWidth"
            advanced: true
            label: "Panel edge"
            hint: "The optional rim on our own surfaces."
            kind: "slider"
            from: 0; to: 8; step: 1; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.gapsIn"
            advanced: true
            label: "Gap between windows"
            kind: "slider"
            from: 0; to: 48; step: 1; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.gapsOut"
            advanced: true
            label: "Gap at the screen edge"
            kind: "slider"
            from: 0; to: 64; step: 1; unit: "px"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Transparency"

        SettingRow {
            Layout.fillWidth: true
            key: "look.opacityActive"
            advanced: true
            label: "Focused window"
            // Why it is this way: That is why the default is 0.95 and not
            // lower.
            hint: "Compositor opacity fades the TEXT as well, unlike a terminal's own background opacity."
            kind: "slider"
            from: 0.4; to: 1.0; step: 0.01; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.opacityInactive"
            advanced: true
            label: "Unfocused window"
            kind: "slider"
            from: 0.4; to: 1.0; step: 0.01; decimals: 2
        }
        // ⚠️ ABOVE the opacity slider, because it decides whether that slider
        // is consulted at all. A control that silently does nothing because of
        // another control further down the page is the shape of "the switch
        // that lies" this project keeps finding.
        SettingRow {
            Layout.fillWidth: true
            key: "look.surfaceStyle"
            label: "What our surfaces are made of"
            hint: "Applications keep their own colours either way."
            kind: "choice"
            // ⚠️ `choices`, not `options` — and the wrong name drew NOTHING and
            // said nothing. The row appeared with its label and hint and an
            // empty space where the switch belongs, which is the same silent
            // shape as a key with no reader. tests/setting-rows.sh now fails a
            // `kind: "choice"` that has no choices.
            choices: [
                { value: "black",  label: "Black" },
                { value: "scheme", label: "Palette" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            // ⚠️ The `advanced:` mark sits on the line IMMEDIATELY after the
            // key — the check reads the previous physical line, so even a
            // comment between them counts as separated. It is the fine
            // adjustment behind the choice above, and marking it is also what
            // keeps this page inside the six-row simple limit.
            key: "look.opacityPanel"
            advanced: true
            label: "Our own surfaces"
            // Why it is dimmed on Black: black mode is opaque by definition, so
            // this number is kept but not read — switching back to Palette
            // restores whatever it was rather than whatever black left behind.
            hint: "How see-through they are. Only used with the Palette style."
            usable: Config.look.surfaceStyle !== "black"
            kind: "slider"
            from: 0.3; to: 1.0; step: 0.01; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.opacityApp"
            advanced: true
            label: "Themed programs"
            hint: "Written into the foreign config files, so it only reaches programs we theme."
            kind: "slider"
            from: 0.3; to: 1.0; step: 0.01; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.opacityTerminal"
            advanced: true
            label: "Terminal"
            hint: "The terminal's own background opacity, which leaves the text sharp — not the compositor's."
            kind: "slider"
            from: 0.2; to: 1.0; step: 0.01; decimals: 2
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Effects"

        SettingRow {
            Layout.fillWidth: true
            key: "look.blur"
            advanced: true
            label: "Blur"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.blurPasses"
            advanced: true
            label: "Blur passes"
            hint: "Passes cost GPU, offset does not — the compositor's own documentation says so. Raise the offset first."
            kind: "slider"
            from: 1; to: 6; step: 1
            usable: Config.look.blur
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.blurOffset"
            advanced: true
            label: "Blur offset"
            kind: "slider"
            from: 1; to: 12; step: 0.5; decimals: 1
            usable: Config.look.blur
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.blurNoise"
            advanced: true
            label: "Blur noise"
            hint: "A little grain stops large blurred areas banding."
            kind: "slider"
            from: 0; to: 0.2; step: 0.01; decimals: 2
            usable: Config.look.blur
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.blurSaturation"
            advanced: true
            label: "Blur saturation"
            kind: "slider"
            from: 0.5; to: 2.0; step: 0.05; decimals: 2
            usable: Config.look.blur
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.glass"
            advanced: true
            label: "Glass sheen"
            hint: "The light lying over the top of a pane."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadows"
            advanced: true
            label: "Shadows"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadowSoftness"
            advanced: true
            label: "Shadow softness"
            kind: "slider"
            from: 0; to: 96; step: 1; unit: "px"
            usable: Config.look.shadows
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadowSpread"
            advanced: true
            label: "Shadow spread"
            kind: "slider"
            from: 0; to: 24; step: 1; unit: "px"
            usable: Config.look.shadows
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadowOffsetY"
            advanced: true
            label: "Shadow drop"
            kind: "slider"
            from: 0; to: 32; step: 1; unit: "px"
            usable: Config.look.shadows
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadowOpacity"
            advanced: true
            label: "Shadow strength"
            kind: "slider"
            from: 0; to: 1.0; step: 0.05; decimals: 2
            usable: Config.look.shadows
        }
        // ⚠️ A ROW FOR `look.shadowBehindWindow` STOOD HERE. The setting came
        // from a compositor that could choose whether to draw a shadow under
        // an opaque window; Hyprland always does, and its decoration.shadow
        // block has no key for it. A switch that writes into shell.json and
        // reaches nothing is worse than no switch.
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Type"

        SettingRow {
            Layout.fillWidth: true
            key: "look.fontUi"
            label: "Interface font"
            kind: "pick"
            options: Services.Installed.fonts
            placeholder: "Inter"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.fontMono"
            advanced: true
            label: "Monospace font"
            hint: "Only the fixed-width families, asked of fontconfig rather than kept in a list here."
            kind: "pick"
            options: Services.Installed.monoFonts
            placeholder: "JetBrainsMono Nerd Font"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.fontIcon"
            advanced: true
            label: "Icon font"
            hint: "\"Material Icons Round\", not the Symbols name — the wrong one renders every icon as a box."
            kind: "pick"
            options: Services.Installed.fonts
            placeholder: "Material Icons Round"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.fontSize"
            advanced: true
            label: "Font size"
            kind: "slider"
            from: 7; to: 18; step: 1; unit: "pt"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Pointer"

        SettingRow {
            Layout.fillWidth: true
            key: "cursor.theme"
            advanced: true
            label: "Cursor theme"
            hint: "The themes on this machine — a directory under /usr/share/icons or ~/.icons that actually contains cursors."
            kind: "pick"
            options: Services.Installed.cursorThemes
            placeholder: "Adwaita"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "cursor.size"
            advanced: true
            label: "Cursor size"
            kind: "slider"
            from: 12; to: 64; step: 1; unit: "px"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Motion"

        SettingRow {
            Layout.fillWidth: true
            key: "look.profile"
            label: "Effects and motion"
            // Why it is this way: one setting for a machine that would rather
            // have the frames.
            hint: "Minimal switches off every animation, the blur, the shadows and the glass sheen together."
            kind: "choice"
            choices: [
                { value: "full",    label: "Full" },
                { value: "minimal", label: "Minimal" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "motion.reduce"
            label: "Reduce motion"
            // Why it is separate from Minimal: Minimal is a machine decision —
            // it also switches off blur, shadows and the glass sheen. This one
            // keeps the desktop looking exactly as it does and only stops it
            // moving.
            hint: "Everything appears where it belongs, without travelling there."
        }
    }
}
