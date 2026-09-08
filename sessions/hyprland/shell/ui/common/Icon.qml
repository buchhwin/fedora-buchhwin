// One monochrome icon, one weight, one size per level.
//
// An icon font rather than a set of image files: an icon that is text inherits
// the palette for free, so it can never end up the one thing on the surface
// that did not follow a theme change.
//
// Icons are named by LIGATURE — `Icon { text: "settings" }` — not by codepoint.
// Codepoints are unverifiable by reading and fail silently: a wrong one renders
// as tofu, or worse as some unrelated glyph from the fallback font, and looks
// like a styling problem rather than a missing character. A name is either in
// the font or it is not, and it says what it means.
import QtQuick
import "../../theme"

Text {
    property int size: Theme.fontSizeLg

    font.family: Theme.fontIcon
    font.pixelSize: size
    color: Theme.fg
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
}
