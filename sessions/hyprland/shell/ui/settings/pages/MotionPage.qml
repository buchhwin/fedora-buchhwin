// Motion — whether things move, and how quickly.
//
// ⚠️ ONE MULTIPLIER, NOT THREE DURATIONS, and that is a design decision rather
// than a shortcut. 120/200/320 ms is not three independent numbers: the fade is
// faster than the settle, which is what makes content appear to arrive INSIDE a
// shape rather than after it. Three separate settings would invite breaking that
// ratio; a multiplier cannot.
//
// It reaches niri's own window animations too, because tools/niri.qml generates
// those from the same three numbers — so this is the tempo of the whole desktop,
// not only of our surfaces. That half arrives on its own: services/Theming.qml
// fingerprints these values and runs the generator, and niri watches its own
// config. Measured: 200 ms became 100 ms about two seconds after the file
// changed, with nothing typed.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../common"
import "../../../config"
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

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
        SettingRow {
            Layout.fillWidth: true
            key: "motion.durMove"
            label: "Movement (size / position)"
            hint: "An island opening, a panel growing, a window sliding."
            kind: "slider"
            from: 0; to: 800; step: 10; unit: "ms"
            usable: !Config.motion.reduce
        }
        SettingRow {
            Layout.fillWidth: true
            key: "motion.durFade"
            label: "Fades & colour"
            kind: "slider"
            from: 0; to: 600; step: 10; unit: "ms"
            usable: !Config.motion.reduce
        }
        SettingRow {
            Layout.fillWidth: true
            key: "motion.durHover"
            label: "Hover response"
            // Why it is the shortest: above about 200 ms the response to the
            // pointer arriving reads as lag rather than as motion.
            hint: "How quickly something answers the pointer arriving."
            kind: "slider"
            from: 0; to: 400; step: 10; unit: "ms"
            usable: !Config.motion.reduce
        }
        SettingRow {
            Layout.fillWidth: true
            key: "motion.bounce"
            advanced: true
            label: "Bounce"
            // Why movement only: overshoot on a fade means going past the
            // target opacity, which is either invisible or a flicker.
            hint: "How far a movement travels past its target before settling."
            kind: "slider"
            from: 0; to: 100; step: 1; unit: "%"
            usable: !Config.motion.reduce
        }
    }

    BarText {
        Layout.fillWidth: true
        text: "Right now the three durations are " + Theme.durFast + ", " + Theme.durBase
            + " and " + Theme.durSlow + " ms — one curve, no overshoot anywhere."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }

    BarText {
        Layout.fillWidth: true
        // Measured, because the first version of this line said the opposite:
        // shell.json changes, the theming watcher notices within about two
        // seconds, the generator rewrites config.kdl and niri reloads it. 200 ms
        // became 100 ms with nothing typed.
        text: "niri's own window animations come from the same numbers, "
            + "and follow within a couple of seconds."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }
}
