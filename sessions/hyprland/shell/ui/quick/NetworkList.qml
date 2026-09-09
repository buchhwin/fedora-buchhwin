// The wireless networks in range, and the way onto one.
//
// ⚠️⚠️ THIS FILE WAS FORBIDDEN BY tests/check-repo.sh UNTIL 09.09.2026, and the
// rule was right about the wrong thing. What it guarded is that neither session
// ships a second network application — "nirgends Doppelungen" — and it enforced  // english-ok: the brief, quoted
// that by banning this file, on the reading that a panel here would be that
// second application. It is the opposite: services/Net.qml has been complete
// since it was written, with connect, disconnect, forget, needsPassword and
// connectWithPassword, and NOTHING CALLED ANY OF IT. The quick panel jumped to
// `systemsettings kcm_networkmanagement` instead, which is the duplication the
// rule exists to prevent — a whole second interface, in another application,
// for a thing this shell already knew how to do.
//
// The rule is turned around rather than deleted: the repository check now
// refuses a second network APPLICATION in the package lists.
//
// ⚠️ THE SCANNER IS ONLY ON WHILE THIS IS OPEN. `Net.watch(true/false)` on
// creation and destruction, the same shape SoundList uses for its nodes. A
// scanner nobody switches off is a radio sweep every few seconds for a list
// nobody is looking at, on a laptop.
//
// ⚠️ AND A PASSWORD IS ASKED FOR ONLY WHERE ONE IS NEEDED. `needsPassword`
// answers that from the entry itself — secured and not already known — so a
// network NetworkManager has a key for joins on one press. The field appears
// under the row that asked for it and takes the focus, rather than opening a
// dialogue somewhere else on the screen.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services" as Services
import "../common"

ColumnLayout {
    id: root

    spacing: Theme.space2

    // The network whose password is being typed, by name. Empty means no field
    // is open — the same "" convention the panel's own `open` uses.
    property string asking: ""

    Component.onCompleted: Services.Net.watch(true)
    Component.onDestruction: Services.Net.watch(false)

    // ------------------------------------------------------------- the radio
    //
    // ⚠️ THE ROW ANSWERS THE PRESS, NOT THE SWITCH. common/Toggle.qml has no
    // `toggled` signal at all — it says so in its own file, and removing the
    // signal was as deliberate as removing the handler: a switch that moves
    // itself can end up saying something the machine does not. So the switch
    // SHOWS the state and this row WRITES it, and a refusal stays visible.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: radioLine.implicitHeight + Theme.space2 * 2
        radius: Theme.radiusSm
        color: radioHover.hovered ? Theme.pillHover
                                  : "transparent"             // literal-ok: absence of colour

        HoverHandler { id: radioHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            enabled: !Services.Net.wifiBlocked
            onTapped: Services.Net.setWifi(!Services.Net.wifiEnabled)
        }

        RowLayout {
            id: radioLine
            anchors.fill: parent
            anchors.margins: Theme.space2
            spacing: Theme.space3

            BarText {
                Layout.fillWidth: true
                text: Services.Net.wifiEnabled ? "Wi-Fi" : "Wi-Fi is off"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
            }

            // ⚠️ IT SAYS SO WHEN THE SWITCH CANNOT HELP. A killswitch on the machine
            // itself is not something this panel can undo, and a toggle that does
            // nothing is the fault rule 5 is about — so the toggle goes away and the
            // reason takes its place.
            BarText {
                visible: Services.Net.wifiBlocked
                text: "blocked in hardware"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.warn
            }

            Toggle {
                visible: !Services.Net.wifiBlocked
                usable: !Services.Net.wifiBlocked
                checked: Services.Net.wifiEnabled
            }
        }
    }

    // ⚠️ ABSENT RATHER THAN EMPTY, which is the rule SoundList states at the top
    // of its own file: a heading over no rows is furniture. Each of the three
    // states below says which one it is, because "scanning" and "nothing here"
    // and "the radio is off" look identical as a blank space.
    BarText {
        Layout.fillWidth: true
        visible: !Services.Net.wifiPresent
        text: "No wireless adapter"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Net.wifiPresent && Services.Net.wifiEnabled
                 && Services.Net.networks.length === 0
        text: Services.Net.scanning ? "Looking for networks …" : "No networks in range"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    // --------------------------------------------------------- the networks
    Repeater {
        model: Services.Net.wifiEnabled ? Services.Net.networks : []

        ColumnLayout {
            id: entry
            required property var modelData
            Layout.fillWidth: true
            spacing: 0    // literal-ok: absence of a gap — the row and its password field are one entry

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: line.implicitHeight + Theme.space2 * 2
                radius: Theme.radiusSm
                color: entry.modelData.connected ? Theme.surfaceHigh
                     : hover.hovered ? Theme.pillHover
                     : "transparent"                          // literal-ok: absence of colour

                HoverHandler { id: hover }

                // ⚠️ ONE PRESS DOES THE OBVIOUS THING, and what is obvious
                // depends on the row. Connected means disconnect; a network with
                // a stored key means join; anything else opens the field below
                // it. Three outcomes from one tap is not a hidden mode — it is
                // the only reading of "press the network you want".
                TapHandler {
                    onTapped: {
                        if (entry.modelData.connected) {
                            Services.Net.disconnect(entry.modelData)
                            root.asking = ""
                        } else if (Services.Net.needsPassword(entry.modelData)) {
                            root.asking = root.asking === entry.modelData.name
                                          ? "" : entry.modelData.name
                        } else {
                            Services.Net.connect(entry.modelData)
                            root.asking = ""
                        }
                    }
                }

                RowLayout {
                    id: line
                    anchors.fill: parent
                    anchors.margins: Theme.space2
                    spacing: Theme.space3

                    SignalBars {
                        level: entry.modelData.level
                        activeColour: entry.modelData.connected ? Theme.accent : Theme.fg
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0    // literal-ok: absence of a gap — a name and its state are one thing

                        BarText {
                            Layout.fillWidth: true
                            text: entry.modelData.name
                            elide: Text.ElideRight
                            color: entry.modelData.connected ? Theme.accent : Theme.fg
                        }

                        // The second line only when it has something to say.
                        BarText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: entry.modelData.busy ? "working …"
                                : entry.modelData.connected ? "connected"
                                : entry.modelData.known ? "saved"
                                : entry.modelData.secured ? entry.modelData.security
                                : "open"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.fgMuted
                            elide: Text.ElideRight
                        }
                    }

                    Icon {
                        visible: entry.modelData.secured
                        text: "lock"
                        size: Theme.fontSizeSm
                        color: Theme.fgMuted
                    }

                    // ⚠️ FORGETTING IS SEPARATE FROM PRESSING THE ROW, and it is
                    // only offered for a network there is something to forget
                    // about. A stored key removed by accident is a password
                    // typed again from memory, which is exactly the memory
                    // nobody has.
                    Icon {
                        visible: entry.modelData.known
                        text: "close"
                        size: Theme.fontSizeSm
                        color: forget.hovered ? Theme.warn : Theme.fgDisabled
                        HoverHandler { id: forget }
                        // ⚠️ AN EXCLUSIVE GRAB, and tests/nested-taps.sh is the
                        // reason it is spelled out. A TapHandler defaults to
                        // `DragThreshold`, which takes a PASSIVE grab: the press
                        // keeps travelling and the row underneath answers it
                        // too. That exact fault reached him three times in one
                        // day, and one of the three was this panel's Wi-Fi
                        // chevron switching the radio off while opening the
                        // list. Forgetting a network AND disconnecting from it
                        // in one press would be the same shape again.
                        TapHandler {
                            gesturePolicy: TapHandler.WithinBounds
                            onTapped: {
                                Services.Net.forget(entry.modelData)
                                root.asking = ""
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------ the password
            //
            // ⚠️ UNDER THE ROW THAT ASKED FOR IT. A dialogue in the middle of
            // the screen loses which network it is about the moment it covers
            // the list, and this panel is already the thing that knows.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: visible ? Theme.space2 : 0
                Layout.bottomMargin: visible ? Theme.space2 : 0
                visible: root.asking === entry.modelData.name
                spacing: Theme.space2

                PasswordField {
                    id: secret
                    Layout.fillWidth: true
                    focus: parent.visible
                    onAccepted: {
                        Services.Net.connectWithPassword(entry.modelData, secret.text)
                        secret.text = ""
                        root.asking = ""
                    }
                }
            }
        }
    }

    // ⚠️ WHAT WENT WRONG, IN THE PANEL. Net.status is set by the service and
    // cleared by the next successful action, so a failure is visible where the
    // attempt was made rather than only in the journal.
    BarText {
        Layout.fillWidth: true
        visible: Services.Net.status.length > 0
        text: Services.Net.status
        font.pixelSize: Theme.fontSizeSm
        color: Theme.warn
        wrapMode: Text.WordWrap
    }
}
