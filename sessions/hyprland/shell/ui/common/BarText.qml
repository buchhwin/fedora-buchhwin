// Bar typography, in one place.
//
// The rule from the design brief is "at most two font sizes per surface,
// weights only 400/500/600". Having a single element for bar text is how that
// stays true after the twentieth widget rather than only on day one.
import QtQuick
import "../../theme"

Text {
    property bool dim: false

    font.family: Theme.fontUi
    font.pixelSize: Theme.fontSize
    font.weight: Theme.weightMedium
    color: dim ? Theme.fgDim : Theme.fg
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
