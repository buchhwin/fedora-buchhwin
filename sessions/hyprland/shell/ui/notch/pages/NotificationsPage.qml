// Notifications, as a page of the island rather than a stack of popups.
//
// The design brief's rule for nothing-to-show is one sentence of text, so an
// empty list says so instead of presenting an empty frame.
//
// ⚠️ CARDS, NOT ROWS, and a header above them — from the reference
// (2026-08-06/vorlage-control-center.png). The old shape was a coloured square,
// two lines of text and a close button, all on the panel's own background, so
// three notifications ran together into one block of text and the only thing
// separating them was a gap. A card gives each one an edge, which is what makes
// a list of them countable at a glance.
//
// ⚠️ AND "CLEAR ALL" IS THE POINT OF THE HEADER. Dismissing four notifications
// one × at a time is the kind of small tax that makes people stop opening the
// panel. The service already had `dismissAll()` with nothing calling it — a
// function with no reader, which in this project is the same debt as a key with
// no reader.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services" as Services
import "../../common"

ColumnLayout {
    id: root
    spacing: Theme.space2
    implicitWidth: Theme.space6 * 16

    // ------------------------------------------------------------- the header
    RowLayout {
        Layout.fillWidth: true
        visible: Services.Notifications.count > 0
        spacing: Theme.space3

        BarText {
            text: "Notifications"
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
        }

        Item { Layout.fillWidth: true }

        // ⚠️ A `Pill`, not a bare piece of coloured text. It looks like a link
        // in the reference and it would have been easy to build one — but a
        // word with no hit area of its own is the "every pill was half dead"
        // bug wearing different clothes, and this one deletes things.
        Pill {
            interactive: true
            BarText {
                text: "Clear all"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.accent
            }
            onClicked: Services.Notifications.dismissAll()
        }
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Notifications.count === 0
        text: "No notifications"
        color: Theme.fgMuted
        horizontalAlignment: Text.AlignHCenter
    }

    Repeater {
        model: Services.Notifications.list.slice(0, 3)

        Rectangle {
            id: card
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: cardBody.implicitHeight + Theme.space3 * 2
            radius: Theme.radiusMd
            color: Theme.pillBg

            RowLayout {
                id: cardBody
                anchors.fill: parent
                anchors.margins: Theme.space3
                spacing: Theme.space3

                // The sending programme's own icon in a disc, as the tiles do.
                // ⚠️ The disc is not decoration here either: an app icon is
                // whatever shape its author drew, and a row of them at
                // different silhouettes reads as untidy where the same icons
                // inside identical circles read as a list.
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Theme.space6
                    implicitHeight: Theme.space6
                    radius: width / 2      // literal-ok: a circle is half its width
                    // Urgency is information, so it gets colour; everything
                    // else lives on surface and spacing.
                    color: {
                        var u = Services.Notifications.urgencyOf(card.modelData)
                        return u === "critical" ? Theme.error
                             : u === "low" ? Theme.surfaceHigh
                             : Theme.accent
                    }

                    AppIcon {
                        anchors.centerIn: parent
                        size: Theme.fontSizeLg
                        source: card.modelData.appName || ""
                        appName: card.modelData.appName || ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0            // literal-ok: no gap at all — the three
                                          // lines are one block, not three things

                    BarText {
                        Layout.fillWidth: true
                        visible: card.modelData.appName.length > 0
                        text: card.modelData.appName
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                        elide: Text.ElideRight
                    }

                    BarText {
                        Layout.fillWidth: true
                        text: card.modelData.summary
                        font.weight: Theme.weightSemibold
                        elide: Text.ElideRight
                    }

                    BarText {
                        Layout.fillWidth: true
                        visible: card.modelData.body.length > 0
                        text: card.modelData.body
                        color: Theme.fgMuted
                        font.pixelSize: Theme.fontSizeSm
                        // ⚠️ Wrapped and capped rather than elided. A
                        // notification body is a sentence, and a sentence cut
                        // off after one line is worth less than two lines of
                        // it — but a mail with a thousand-word preview may not
                        // push the panel off the screen either.
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }
                }

                Pill {
                    Layout.alignment: Qt.AlignTop
                    interactive: true
                    Icon { text: "close"; size: Theme.fontSize; color: Theme.fgDim }
                    onClicked: Services.Notifications.dismiss(card.modelData)
                }
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Notifications.count > 3
        // ⚠️ ENGLISH, and it was German. The label read                        english-ok: the old label, quoted
        // "+ 2 weitere" in the middle of a panel whose every other word is      english-ok: the old label, quoted
        // English. tests/english.sh missed it because the word was not in the
        // list, and the file's own rule is that a miss earns an entry rather
        // than a shrug. Adding it caught a SECOND one the same minute, shipped
        // in CalendarPage: "and 3 <the same word>" under a day with too many
        // events. A word list is only as good as its last miss.
        text: "+ " + (Services.Notifications.count - 3) + " more"
        color: Theme.fgDim
        font.pixelSize: Theme.fontSizeSm
        horizontalAlignment: Text.AlignHCenter
    }
}
