// Where arriving notifications land: the top-right corner, on their own
// surfaces.
//
// ⚠️ NOT the notch, and that is the point of this file existing. A notification
// used to open the notch on its notifications page and close it again after
// 1.6 s — so anything you had open was interrupted, and the message itself was
// gone before you could act on it. The notch is where you GO to look at
// something; a message that arrives has not been asked for and must not take
// the place over.
//
// It also means the notch stays put while a toast is up: the rule is that only
// surfaces opening AT the notch displace it, and this one is nowhere near it.
//
// ⚠️ ONE WINDOW PER CARD, not one window holding a column of cards. That was
// the first attempt and it was wrong for a reason this project has now paid for
// three times: niri draws shadow and blur behind the WHOLE layer surface,
// invisible parts included. A column of three cards with 8 px between them is
// one surface, so the gaps between the cards were filled with blurred wallpaper
// and shadow — a dark band hanging in mid-air between two floating cards.
// Measured on screen, not reasoned about.
//
// The price is that every card is the same height, since a window has to know
// where it sits before its neighbours have been laid out. That is not really a
// price: fixed-height notifications are what every other desktop does, and the
// alternative is cards that jump as their neighbours resize.
import QtQuick
import Quickshell
import "../../config"
import "../../services" as Services

Scope {
    id: root

    required property var modelData

    Variants {
        // The service owns which messages are showing; this just draws them.
        model: Services.Notifications.toasts

        delegate: ToastWindow {
            required property var modelData
            screen: root.modelData
            notification: modelData
            // Its place in the stack. Recomputed whenever the list changes,
            // which is what makes the cards close ranks when one goes away.
            index: Services.Notifications.toasts.indexOf(modelData)
        }
    }
}
