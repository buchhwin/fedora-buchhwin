// Mouse and touchpad — tapping, scrolling, and pointer speed.
//
// One page, because the two devices answer the same questions and the answers
// should be readable side by side. The mouse CURSOR is a different thing and
// lives with the fonts, where its size belongs.
//
// ⚠️ THE TWO GROUPS ASK THEIR QUESTIONS IN THE SAME ORDER, and that is the
// whole point of putting them on one page. They did not: the touchpad went
// tap · dwt · natural · middle-click · speed · acceleration · method · scroll
// speed · click method, and the mouse went natural · speed · acceleration ·
// scroll speed. The two sliders he actually reaches for — pointer speed and
// scrolling speed — sat in different places in each list, with fine adjustments
// wedged between them. Reported as part of "bei type und pointer musst du       // english-ok: the report, quoted
// nochmal ran das ist noch unübersichtlich".                                    // english-ok: the report, quoted
//
// Both lists now read: what it does · pointer speed · scrolling speed, then
// everything that is a fine adjustment behind "Show more". Same order, same
// place, so the eye can compare them.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    readonly property var accelProfiles: [
        { value: "adaptive", label: "Adaptive" },
        { value: "flat",     label: "Flat" }
    ]

    SettingGroup {
        Layout.fillWidth: true
        title: "Touchpad"

        // ── what you reach for ───────────────────────────────────────────────
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.tap"
            label: "Tap to click"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.naturalScroll"
            label: "Natural scrolling"
            hint: "The content follows your fingers."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.accelSpeed"
            label: "Pointer speed"
            kind: "slider"
            from: -1.0; to: 1.0; step: 0.05; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.scrollFactor"
            label: "Scrolling speed"
            // Why it is this way: the schema had natural scroll, pointer
            // acceleration and scroll method, so "scrolling is too fast" had no
            // answer anywhere. 1.0 is niri's own; below 1 is slower.
            hint: "There was no speed here at all."
            kind: "slider"
            from: 0.1; to: 3.0; step: 0.1; decimals: 1
        }

        // ── fine adjustments ─────────────────────────────────────────────────
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.accelProfile"
            advanced: true
            label: "Acceleration"
            hint: "Flat disables pointer acceleration entirely."
            kind: "choice"
            choices: root.accelProfiles
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.dwt"
            advanced: true
            label: "Disable while typing"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.scrollMethod"
            advanced: true
            label: "Scroll method"
            kind: "choice"
            choices: [
                { value: "two-finger",     label: "Two finger" },
                { value: "edge",           label: "Edge" },
                { value: "on-button-down", label: "Button held" },
                { value: "no-scroll",      label: "None" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.clickMethod"
            advanced: true
            label: "Click method"
            hint: "Clickfinger counts fingers; button areas splits the pad."
            kind: "choice"
            choices: [
                { value: "clickfinger",  label: "Count fingers" },
                { value: "button-areas", label: "Button areas" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.middleEmulation"
            advanced: true
            label: "Middle click by both buttons"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Mouse"

        // ── what you reach for, in the same order as above ───────────────────
        //
        // ⚠️ NATURAL SCROLLING IS THE ONE THING THAT IS NOT IN THE SAME PLACE,
        // and it is a decision rather than an oversight. The simple level of a
        // page holds six rows (tests/setting-rows.sh) and these two groups want
        // seven between them. On a laptop the touchpad is the pointer that is
        // always there and the mouse is the one that sometimes is; reversing a
        // wheel is also the rarer wish of the two. So this is the row that goes
        // behind "Show more" — named here so the asymmetry is on the record
        // instead of looking like the old mess.
        SettingRow {
            Layout.fillWidth: true
            key: "input.mouse.accelSpeed"
            label: "Pointer speed"
            kind: "slider"
            from: -1.0; to: 1.0; step: 0.05; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.mouse.scrollFactor"
            label: "Scrolling speed"
            // Why it is this way: a wheel notch and two fingers on glass are
            // not the same gesture and almost never want the same number.
            hint: "Separate from the touchpad's on purpose."
            kind: "slider"
            from: 0.1; to: 3.0; step: 0.1; decimals: 1
        }

        // ── fine adjustments, in the same order as above ─────────────────────
        SettingRow {
            Layout.fillWidth: true
            key: "input.mouse.accelProfile"
            advanced: true
            label: "Acceleration"
            hint: "Flat disables pointer acceleration entirely."
            kind: "choice"
            choices: root.accelProfiles
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.mouse.naturalScroll"
            advanced: true
            label: "Natural scrolling"
            hint: "The page follows the wheel rather than the other way round."
        }
    }
}
