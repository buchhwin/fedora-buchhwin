// Keyboard shortcuts — all of them, and the way back out. (The count is not
// written down here: it was wrong in five places at once. SettingsContent's
// blurb derives it from Config.binds.length.)
//
// ⚠️ IT HAS NO `SettingRow` AT ALL, and `binds` is named in the exemption list of
// tests/setting-rows.sh for exactly that reason. Sixty-three bindings are a list
// with its own view, not a row per key.
//
// It used to be the last item on the old System page, below the graphics card
// and the timezone — which is where you would look for it only if you already
// knew. A page of its own is most of what "I cannot find anything" was asking
// for.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../common"
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    BindsList { Layout.fillWidth: true }

    BarText {
        Layout.fillWidth: true
        text: "The built-in set is live while shell.json holds no bindings of its "
            + "own. ⚠️ The moment it holds one, every default in this list is "
            + "frozen on this machine and new ones will never arrive — "
            + "`bhctl binds reset` is the way back."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }
}
