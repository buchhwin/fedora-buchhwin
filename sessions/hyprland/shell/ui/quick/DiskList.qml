pragma ComponentBehavior: Bound

// The removable drives, one line each, with the two things you do to them.
//
// ⚠️ EJECT IS TWO STEPS AND THE SECOND ONE IS THE POINT. Unmounting flushes the
// filesystem and the drive keeps spinning; pulling it out then is the thing
// everybody has been told not to do. `udisksctl power-off` is what makes the
// light go out, and services/Disks.qml does both in order behind one button.
//
// ⚠️ AND THE BUTTON SAYS WHICH ONE IT IS. "Eject" on a mounted drive, "Mount" on
// one that is not — never one word that means different things depending on a
// state you have to read somewhere else on the line.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../services" as Services
import "../../theme"

ColumnLayout {
    id: root
    spacing: Theme.space2

    function human(bytes) {
        if (bytes >= 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
        if (bytes >= 1024 * 1024)
            return Math.round(bytes / (1024 * 1024)) + " MB"
        return Math.round(bytes / 1024) + " kB"
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Disks.drives.length === 0
        text: "Nothing plugged in"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    Repeater {
        model: Services.Disks.drives

        RowLayout {
            id: line
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.space2

            Icon {
                text: "usb"
                size: Theme.fontSizeLg
                color: line.modelData.mounted ? Theme.accent : Theme.fgMuted
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0    // literal-ok: a name and its own detail are one thing

                BarText {
                    Layout.fillWidth: true
                    text: line.modelData.label
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                BarText {
                    Layout.fillWidth: true
                    // ⚠️ THE MOUNT POINT, not just "mounted". It is the answer to
                    // the question you opened this for — where the files are —
                    // and a word that only repeats the icon is noise.
                    text: line.modelData.mounted
                        ? line.modelData.mountpoint
                        : root.human(line.modelData.size) + " · " + line.modelData.fstype
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Pill {
                interactive: true
                BarText {
                    text: line.modelData.mounted ? "Eject" : "Mount"
                    font.pixelSize: Theme.fontSizeSm
                }
                onClicked: {
                    if (line.modelData.mounted)
                        Services.Disks.eject(line.modelData.path,
                                             line.modelData.parent)
                    else
                        Services.Disks.mount(line.modelData.path)
                }
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Disks.lastError.length > 0
        text: Services.Disks.lastError
        font.pixelSize: Theme.fontSizeSm
        color: Theme.warn
        wrapMode: Text.WordWrap
    }
}
