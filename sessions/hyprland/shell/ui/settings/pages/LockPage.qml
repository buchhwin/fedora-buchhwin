// Lock Screen — what is on the screen while the session is locked.
//
// ⚠️ IT IS A SEPARATE PROCESS (`BUCHHWIN_MODE=lock`). It reads shell.json
// itself and learns nothing from the running shell, so a change here reaches it
// the next time it starts — which is the next time you lock. That is not a
// caveat to work around; it is why the lock screen survives a shell that has
// crashed.
//
// The brief asks for a large clock, the date, a round avatar and nothing else
// until you touch a key. Each of those three can go; the clock cannot, because
// then it would be a black rectangle you have to trust.
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
        title: "What it shows"

        SettingRow {
            Layout.fillWidth: true
            key: "lock.showDate"
            label: "Date under the clock"
            hint: "Its format is on the Clock & Date page."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "lock.showAvatar"
            label: "Avatar"
            // Why it is this way: With neither, the initial of your account
            // name — never an empty circle, which reads as an image that
            // failed.
            hint: "Your picture from AccountsService or ~/.face."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "lock.wallpaper"
            label: "Wallpaper behind it"
            // Why it is this way: The opaque colour stays underneath either
            // way — the picture loads asynchronously, and for those frames it
            // is the only thing between the screen and the desktop below.
            hint: "Off is a plain dark surface."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "lock.wallpaperBlur"
            label: "How soft the picture is"
            // Why it is this way: blurred in QML rather than by the compositor
            // — the compositor blurs LAYER surfaces, and neither the lock screen (an
            // ext-session-lock surface) nor the greeter (which runs before
            // there is a session) is one.
            hint: "0 is the sharp photograph."
            kind: "slider"
            from: 0
            to: 96
            unit: "px"
        }
    }

    BarText {
        Layout.fillWidth: true
        text: "Mod+L locks. A change here takes effect the next time it starts, "
            + "because the lock screen is its own process."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }
}
