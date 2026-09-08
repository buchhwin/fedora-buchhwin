// Media — what is playing, and where it is shown.
//
// ⚠️ `MediaPage` ALSO EXISTS UNDER ui/notch/pages/, and the two are different
// things: that one IS the media card, this one is its settings. They live in
// separate folders with separate qmldirs, so QML resolves them correctly — the
// risk is a person opening the wrong file, which is what this note is for.
// (NotifyPage was renamed for the same collision; this one keeps its name
// because "Media" is what the reference calls the page.)
import QtQuick
import QtQuick.Layouts
import ".."
import "../../common"
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "Player"

        SettingRow {
            Layout.fillWidth: true
            key: "media.preferredPlayer"
            label: "Preferred player"
            // Why it is this way: a browser page that starts playing is an
            // MPRIS player too, so without this the island jumps from your
            // music to an advert and back. Matched loosely against the
            // player's own name.
            hint: "Empty means whatever is actually playing."
            kind: "pick"
            options: Services.Suggest.players
            placeholder: "Whatever is playing"
        }

        // Not a setting — an answer. Naming a player is only useful if you can
        // see what the names are, and they come from the programs themselves
        // rather than from any list we could write.
        BarText {
            Layout.fillWidth: true
            text: Services.Media.available
                ? "On the bus right now: " + Services.Media.label
                : "Nothing is on the bus right now."
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
            wrapMode: Text.WordWrap
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Where it is shown"

        SettingRow {
            Layout.fillWidth: true
            key: "media.showInIsland"
            label: "In the island"
            hint: "The track appears when the pointer rests on the island. Off leaves the clock and the status pill there."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "media.artworkAsBackground"
            label: "Cover art as the card background"
            // Why it is this way: right on the dark covers it was drawn from,
            // and worth turning off on a bright one, where the card fights the
            // words.
            hint: "As the reference draws it."
        }
    }
}
