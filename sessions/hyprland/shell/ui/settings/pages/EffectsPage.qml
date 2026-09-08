// Effects — blur, shadows, and how much you can see through.
//
// Transparency and effects are one page because they are one question: what is
// drawn between a surface and what is behind it. They were two groups on a page
// with six others, which is how "the menus have a strange gradient" took a
// session to track down — the two halves of the answer were never on screen
// together.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "Transparency"

        SettingRow {
            Layout.fillWidth: true
            key: "look.opacityActive"
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
            label: "Blur"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.blurPasses"
            advanced: true
            label: "Blur passes"
            hint: "Passes cost GPU, offset does not — niri's own documentation says so. Raise the offset first."
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
            label: "Glass sheen"
            hint: "The light lying over the top of a pane."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadows"
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
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadowBehindWindow"
            advanced: true
            label: "Shadow behind the window"
            // Why it is this way: measured on Nautilus, the interior went from
            // (66,50,35) to (40,32,25).
            hint: "Off, because a translucent window shows its own shadow through itself."
            usable: Config.look.shadows
        }
    }
}
