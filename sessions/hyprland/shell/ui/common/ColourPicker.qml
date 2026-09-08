// Pick a colour, rather than type one.
//
// ⚠️ THE ONE ROW IN THE WINDOW WHERE A LIST WOULD BE THE WRONG ANSWER. His words
// on 05.08. were "man soll auch custom farben einstellen können … eine eigene    // english-ok: the brief, quoted
// farbe als scheme" — the point is a colour of his own, so a row of prepared   // english-ok: the brief, quoted
// swatches would be the same closed set the fourteen palettes already are. The
// suggestion for `theme.customColor` is therefore not a list but a way to look.
//
// ⚠️ AND THE HEX BOX STAYS. Typing #7fbbb3 is how a colour arrives from
// somewhere else — a screenshot, a brand, another config — and a picker that
// takes the box away makes the easy case impossible. Both edit the same value;
// neither is the master.
//
// ⚠️ NO SHADER, MEASURED AGAINST THE ALTERNATIVE RATHER THAN GUESSED AT. Qt 6
// takes no GLSL at runtime, so a shader here would mean a qsb build step in the
// installer for one gradient — and this surface is drawn while a finger is
// dragging on it, which is exactly the case the laptop notes say to leave
// alone. Two overlaid QtQuick gradients give the same square: white to
// transparent across for saturation, transparent to black down for value, over
// a flat hue. All three are plain rectangles the scene graph already knows how
// to batch.
import QtQuick
import QtQuick.Layouts
import "../../theme"

ColumnLayout {
    id: root

    // "#rrggbb". The value in the settings file, and what comes back out.
    property string value: ""
    property bool usable: true

    signal picked(string hex)

    spacing: Theme.space2

    // ------------------------------------------------------------- the state
    //
    // ⚠️ HUE IS HELD, NOT DERIVED, and that is not a shortcut. Reading it back
    // out of the colour breaks at both ends of the square: black and white have
    // no hue at all (QColor answers -1), so dragging into the bottom corner
    // would throw the hue away and the strip would jump to red. Held here, the
    // square keeps the hue you chose while you move around inside it.
    property real hue: 0
    property real sat: 0
    property real val: 1

    // Whether the fields below are echoing our own edit. Without it, writing the
    // value out and reading it back in re-derives hue/sat/val from a rounded
    // 8-bit colour on every drag step, and the dot creeps away under the finger.
    property bool _mine: false

    function _hex2(n) {
        var s = Math.max(0, Math.min(255, Math.round(n * 255))).toString(16)
        return s.length < 2 ? "0" + s : s
    }
    function _hexOf(c) {
        return "#" + root._hex2(c.r) + root._hex2(c.g) + root._hex2(c.b)
    }
    readonly property color colour: Qt.hsva(root.hue, root.sat, root.val, 1)

    function _adopt(text) {
        // ⚠️ REFUSES WHAT IT CANNOT READ rather than showing black for it.
        // Half-typed input reaches here on every keystroke of a hand-typed
        // value, and a picker that swings to black between "#7f" and "#7fbbb3"
        // is a picker that looks broken while it is working.
        if (!/^#[0-9a-fA-F]{6}$/.test(String(text).trim()))
            return false
        var c = Qt.color(String(text).trim())
        // -1 means achromatic, where there is no hue to take. Keep the one we
        // have so a grey does not reset the strip to red.
        if (c.hsvHue >= 0)
            root.hue = c.hsvHue
        root.sat = c.hsvSaturation
        root.val = c.hsvValue
        return true
    }

    function _emit() {
        root._mine = true
        root.picked(root._hexOf(root.colour))
        root._mine = false
    }

    onValueChanged: if (!root._mine) root._adopt(root.value)
    Component.onCompleted: root._adopt(root.value)

    // -------------------------------------------------- saturation and value
    Item {
        Layout.fillWidth: true
        implicitHeight: Theme.space6 * 4
        opacity: root.usable ? 1 : Theme.dimmed

        Rectangle {
            id: square
            anchors.fill: parent
            radius: Theme.radiusSm
            clip: true
            // The flat hue underneath. Not a theme colour — it IS the subject
            // of the control, which is why there is no token for it.
            color: Qt.hsva(root.hue, 1, 1, 1)

            // Saturation: white on the left, nothing on the right.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.hsva(0, 0, 1, 1) }
                    GradientStop { position: 1; color: Qt.hsva(0, 0, 1, 0) }
                }
            }
            // Value: nothing at the top, black at the bottom.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.hsva(0, 0, 0, 0) }
                    GradientStop { position: 1; color: Qt.hsva(0, 0, 0, 1) }
                }
            }

            // ⚠️ A RING, NOT A FILLED DOT. Over a field of every colour there is
            // no single colour a dot could be that stays visible — the marker
            // has to be a shape instead. Two rings, dark outside and light
            // inside, so one of them contrasts wherever it lands.
            Item {
                x: root.sat * square.width
                y: (1 - root.val) * square.height

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.space4
                    height: width
                    radius: width / 2
                    color: "transparent"                    // literal-ok: absence of colour
                    border.width: Theme.hairline * 2
                    border.color: Qt.hsva(0, 0, 0, 0.6)     // literal-ok: the marker is over every colour at once
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.space4 - Theme.hairline * 2
                    height: width
                    radius: width / 2
                    color: "transparent"                    // literal-ok: absence of colour
                    border.width: Theme.hairline * 2
                    border.color: Qt.hsva(0, 0, 1, 0.9)     // literal-ok: the marker is over every colour at once
                }
            }

            function at(px, py) {
                root.sat = Math.max(0, Math.min(1, px / square.width))
                root.val = 1 - Math.max(0, Math.min(1, py / square.height))
                root._emit()
            }

            TapHandler {
                enabled: root.usable
                onTapped: function (p) { square.at(p.position.x, p.position.y) }
            }
            // The same shape LevelRow uses, and for the same reason: a
            // DragHandler has no "let go" signal, only an `active` that also
            // goes false on a cancelled drag — which is the same thing here.
            DragHandler {
                enabled: root.usable
                target: null
                onCentroidChanged: if (active)
                    square.at(centroid.position.x, centroid.position.y)
            }
        }
    }

    // ------------------------------------------------------------- the hue
    Rectangle {
        id: strip
        Layout.fillWidth: true
        implicitHeight: Theme.space4
        radius: Theme.radiusPill
        opacity: root.usable ? 1 : Theme.dimmed

        // ⚠️ SEVEN STOPS, COMPUTED. Six would leave the strip ending on magenta
        // instead of coming back round to red, and a hue wheel that does not
        // close reads as a gradient that was cut off.
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0000; color: Qt.hsva(0.0000, 1, 1, 1) }
            GradientStop { position: 0.1667; color: Qt.hsva(0.1667, 1, 1, 1) }
            GradientStop { position: 0.3333; color: Qt.hsva(0.3333, 1, 1, 1) }
            GradientStop { position: 0.5000; color: Qt.hsva(0.5000, 1, 1, 1) }
            GradientStop { position: 0.6667; color: Qt.hsva(0.6667, 1, 1, 1) }
            GradientStop { position: 0.8333; color: Qt.hsva(0.8333, 1, 1, 1) }
            GradientStop { position: 1.0000; color: Qt.hsva(1.0000, 1, 1, 1) }
        }

        Rectangle {
            x: root.hue * strip.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.space3
            height: strip.height + Theme.hairline * 4
            radius: width / 2
            color: "transparent"                    // literal-ok: absence of colour
            border.width: Theme.hairline * 2
            border.color: Qt.hsva(0, 0, 1, 0.9)     // literal-ok: the marker is over every colour at once
        }

        function at(px) {
            root.hue = Math.max(0, Math.min(1, px / strip.width))
            root._emit()
        }

        TapHandler {
            enabled: root.usable
            onTapped: function (p) { strip.at(p.position.x) }
        }
        DragHandler {
            enabled: root.usable
            target: null
            onCentroidChanged: if (active) strip.at(centroid.position.x)
        }
    }

    // ------------------------------------------------- the value, in writing
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2

        // What the scheme will actually be built from. Not decoration: the seed
        // goes through Scheme's own derivation, and seeing the colour next to
        // the box is the difference between choosing and guessing.
        Rectangle {
            implicitWidth: Theme.space5
            implicitHeight: Theme.space5
            radius: Theme.radiusSm
            color: root.colour
            opacity: root.usable ? 1 : Theme.dimmed
        }

        TextField {
            id: hexField
            Layout.fillWidth: true
            enabled: root.usable
            text: root.value
            placeholder: "#7fbbb3"   // literal-ok: an example of the FORM, not a colour anything is drawn in
            onAccepted: if (root._adopt(hexField.text)) root._emit()
            Connections {
                target: hexField.input
                function onActiveFocusChanged() {
                    if (!hexField.input.activeFocus && root._adopt(hexField.text))
                        root._emit()
                }
            }
        }

        // The same refusal the pick rows use, said before it is written rather
        // than after: an unreadable value is left where it was.
        BarText {
            visible: !/^#[0-9a-fA-F]{6}$/.test(String(hexField.text).trim())
            text: "Needs #rrggbb"
            font.pixelSize: Theme.fontSizeSm
            color: Theme.warn
        }
    }
}
