// What the lock screen shows: a large clock, the date, a round avatar, and
// nothing else until you touch a key.
//
// The brief asks for exactly that: "große Uhr, Datum, runder Avatar, beliebige Taste".  // english-ok: the specification, quoted in the words it was given in
// The reason it works is that a lock screen is looked at far more
// often than it is used. Most of the time you want the time.
//
// ⚠️ EVERY FAILURE HAS TO BE VISIBLE. A lock screen that silently does nothing
// when PAM is misconfigured is indistinguishable from a wrong password, and you
// would sit there retyping a password that was never going to be checked. So
// the PAM state is on screen: what it asked, what went wrong, and whether it is
// busy.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pam    // services-ok: authentication is not a device, and there is nothing sensible to wrap it in
import "../../theme"
import "../../config"
import "../common"
import "../../common"

Item {
    id: root

    signal unlocked()

    // ⚠️ THREE SOURCES, NOT ONE, AND CI FOUND IT. This was `Quickshell.env
    // ("USER")` alone. `USER` is set by login shells and by systemd user
    // services, so it is there on the real machine — but it is NOT set inside a
    // bare container, which is where tests/lock.sh runs (ci.yml, job `qml`,
    // `container: fedora:44`). The check "it knows who is logged in" went red,
    // and it was right to: the lock screen would have shown "?" for an avatar
    // and no name at all.
    //
    // `LOGNAME` is the POSIX spelling of the same thing and is set in places
    // `USER` is not. `HOME` is set essentially everywhere, and its last segment
    // is the account name on any normal layout — a guess, but the right kind:
    // it is only ever reached when the two authoritative answers are missing,
    // and a plausible name beats a question mark on the screen you have to
    // recognise yourself in.
    readonly property string user: {
        var named = Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
        if (named.length > 0)
            return named
        var home = String(Quickshell.env("HOME") || "")
        var cut = home.lastIndexOf("/")
        return cut >= 0 ? home.slice(cut + 1) : home
    }

    // Nothing but the clock until a key is pressed — which is also the "press
    // any key" the brief asks for, rather than an instruction printed under a
    // password box that is already there.
    property bool asking: false

    function ask() {
        if (!root.asking) {
            root.asking = true
            pam.start()
        }
    }

    focus: true
    Keys.onPressed: function (event) {
        root.ask()

        // ⚠️ ENTER IS NOT A CHARACTER, and treating it as one is why the screen
        // never unlocked even after the identifier below was fixed. `event.text`
        // for Return is "\r" — length 1 — so it passed the emptiness test, got
        // appended to the password, and `event.accepted = true` swallowed it, so
        // the TextInput's `onAccepted` never fired. Submitting from here as well
        // means it works whether focus has reached the box yet or not.
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.submit()
            event.accepted = true
            return
        }

        // The first keystroke wakes the field; it must not also be swallowed,
        // or typing your password starts one character short.
        if (!event.text.length || event.key === Qt.Key_Escape)
            return
        // ⚠️ `input`, NOT `field`. There is no `field` in this file and never
        // was — the id on the TextInput is `input`. Every keystroke therefore
        // threw a ReferenceError, the character was dropped and focus never
        // moved to the box: THE LOCK SCREEN COULD NOT BE TYPED INTO AT ALL.
        //
        // Measured on the VM, which is the only way this was ever going to be
        // found: PAM started, relayed "Password: ", received four submissions
        // and refused every one, while `su $USER` accepted the very same
        // password (rc 0). So the whole authentication chain was correct and
        // the box was simply never filled.
        //
        // It survived because nothing builds this file: tests/smoke.sh runs the
        // SHELL, and the lock screen is a separate process
        // (`BUCHHWIN_MODE=lock`). tests/lock.sh now builds it.
        fieldPill.text += event.text
        fieldPill.focusField()
        event.accepted = true
    }

    TapHandler { onTapped: root.ask() }

    SystemClock {
        id: clock
        // ⚠️ Minutes unless asked otherwise, and the warning belongs with the
        // setting rather than here: a lock screen is on for hours, so a
        // second-precision clock is a redraw every second for a digit nobody
        // reads, on battery, with the lid possibly shut. The row in the
        // settings window says exactly that.
        precision: Clock.precision
    }

    // ⚠️⚠️ THE FACE IS `common/StagedFace` NOW, SHARED WITH THE GREETER. His
    // instruction: "mach beides gleich … also beides neues design", and the      // english-ok: the request, quoted
    // older brief says why — the screen before logging in and the one after
    // locking must not look like two products. Both stages (the clock alone,
    // then the clock lifted with the identity underneath) have one definition
    // there instead of two that drift.
    //
    // ⚠️ NOTHING ABOUT AUTHENTICATION MOVED. PamContext, `submit`, the status
    // handling and the avatar search are what they were, line for line. This is
    // the one surface where a mistake locks him out, and a redesign is not a
    // reason to touch the part that opens the door.
    //
    // ⚠️ THE AVATAR IS IN THE REVEALED HALF NOW, not on the resting screen —
    // what the reference does, and the honest reading of his brief: at rest you
    // want the time, and whose machine it is answers a question nobody asked
    // until a key was pressed.
    StagedFace {
        id: face
        anchors.fill: parent
        revealed: root.asking
        now: clock.date
        hint: "Press any key"

        // ⚠️ THE ARRIVAL STAYS HERE rather than moving into StagedFace. The
        // lock surface underneath must be opaque from its first frame —
        // LockScreen.qml paints Theme.bgDeep for exactly that reason — so only
        // what is drawn ON it may fade in.
        property bool shown: false
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.94
        transformOrigin: Item.Center
        Component.onCompleted: face.shown = true

        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
        Behavior on scale {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.space5
            // ⚠️ `visible: false` on a Layout child removes it from the layout
            // entirely, gap included — which is what is wanted here. It is the
            // opposite of a Loader with `active: false`, which stays visible at
            // zero height and keeps its spacing.
            visible: Config.lock ? Config.lock.showAvatar : true
            implicitWidth: Theme.space6 * 3
            implicitHeight: Theme.space6 * 3

            Rectangle {
                id: avatarRing
                anchors.fill: parent
                radius: width / 2
                color: Theme.surface
                border.width: Theme.hairline
                // ⚠️ `outline`, not `glassRimTop`. That token was deleted when
                // the panes lost their rim, and this was its last reader — QML
                // answered with "Unable to assign [undefined] to QColor" in the
                // lock screen's own log and drew the ring in whatever the
                // default is. A dangling token reference is invisible until
                // somebody reads a log, which for a separate process means
                // never.
                border.color: Theme.outline
            }

            // The initial, shown when there is no picture. A blank circle looks
            // like an image that failed to load.
            BarText {
                anchors.centerIn: parent
                visible: avatar.status !== Image.Ready
                text: root.user.length ? root.user.charAt(0).toUpperCase() : "?"
                font.pixelSize: Theme.fontSizeXl
                color: Theme.fgMuted
            }

            Image {
                id: avatar
                anchors.fill: parent
                anchors.margins: Theme.hairline
                fillMode: Image.PreserveAspectCrop
                // Read at the size it is drawn at, not at whatever the file
                // happens to be — a 4000 px portrait decoded for a 96 px circle
                // is megabytes of nothing.
                sourceSize.width: width
                sourceSize.height: height
                // Drawn only through the mask below, never directly: showing
                // both would put a square photo behind a round one.
                visible: false
                layer.enabled: true

                // Two places a face can live, tried in order, because neither is
                // guaranteed: AccountsService is where GNOME and SDDM put it,
                // `~/.face` is the older convention that still works everywhere.
                //
                // ⚠️ Assigned, not bound. A binding `source: candidates[i]`
                // that `onStatusChanged` advances is a property feeding itself:
                // QML logs "Binding loop detected" and from then on the order in
                // which the two are evaluated is not ours to rely on. Walking
                // the list by hand is one line longer and has one outcome.
                property int candidate: 0
                readonly property var candidates: [
                    "/var/lib/AccountsService/icons/" + root.user,
                    Quickshell.env("HOME") + "/.face"
                ]
                function tryNext() {
                    if (candidate >= candidates.length) {
                        source = ""       // out of places to look: show the initial
                        return
                    }
                    source = "file://" + candidates[candidate]
                    candidate++
                }
                Component.onCompleted: tryNext()
                onStatusChanged: if (status === Image.Error) tryNext()
            }

            // The round frame. A rectangular photo in a round hole is the single
            // most obvious way to look unfinished.
            //
            // ⚠️ `layer.enabled` is a per-item texture, which this project
            // warns about on the notch — but the warning is about a shape that
            // ANIMATES. This one is a still picture that changes when the file
            // changes, so it is rasterised once and then reused.
            Item {
                id: avatarMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.fg          // the mask reads alpha, not hue
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: avatar
                maskEnabled: true
                maskSource: avatarMask
                visible: avatar.status === Image.Ready
            }
        }

        // ⚠️ WHO YOU ARE ABOUT TO LET IN. It was missing, and its absence is
        // half of why the second stage read as unfinished: an avatar with no
        // name is a picture, not an identity. macOS puts the name between the
        // portrait and the field, which is also the reading order.
        BarText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Theme.space2
            text: root.user
            font.pixelSize: Theme.fontSizeLg
            font.weight: Theme.weightSemibold
        }

        // ⚠️⚠️ ONE COMPONENT FOR BOTH FACES. This pill was written out here and
        // again, almost line for line, in ui/greeter/GreeterFace.qml — same
        // GlassPane, same arrow, same margins, same glyph. B24 says the two are
        // one face, so the field is one file: common/PasswordField.qml, which
        // also carries the transparency, the smaller size and the shake he
        // asked for.
        PasswordField {
            id: fieldPill
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.space4
            visible: root.asking
            // ⚠️ `locked`, which becomes `readOnly` rather than `enabled: false`
            // inside the component — the difference cost a round, see the note
            // there.
            locked: pam.active && !pam.responseRequired
            onAccepted: root.submit()
        }

        // What PAM is doing, in its own words. Its messages are the only honest
        // account of why a password was refused — "Authentication failure" and
        // "Account expired" need different reactions from you.
        BarText {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Theme.space6 * 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.status.length > 0
            text: root.status
            color: root.statusIsError ? Theme.error : Theme.fgDim
            font.pixelSize: Theme.fontSizeSm
        }
    }

    // Kept as our own state rather than read straight off PamContext: the
    // context clears its message when it finishes, and "wrong password" has to
    // survive long enough to be read.
    property string status: ""
    property bool statusIsError: false

    // Alias so the field can be reached from the key handler above without
    // knowing where it sits in the layout.
    property alias field: fieldPill

    function submit() {
        if (!pam.active) {
            root.status = "Authentication is not running"
            root.statusIsError = true
            return
        }
        if (!pam.responseRequired)
            return
        root.status = ""
        pam.respond(fieldPill.text)
        fieldPill.clear()
    }

    PamContext {
        id: pam
        // Our own service file, placed by the installer, following the shape
        // Fedora's own `vlock` uses. Borrowing another program's service name
        // means breaking when that program is not installed.
        config: "buchhwin-lock"
        user: root.user

        onPamMessage: {
            // A prompt that wants an answer is the password question; anything
            // else is PAM talking, and worth showing rather than swallowing.
            if (!pam.responseRequired && pam.message.length > 0) {
                root.status = pam.message
                root.statusIsError = pam.messageIsError
            }
        }

        onCompleted: function (result) {
            if (result === PamResult.Success) {
                root.unlocked()
                return
            }
            // ⚠️⚠️ A WRONG PASSWORD SHAKES AND SAYS NOTHING — his request, and
            // the reason it is only THIS result: "wenn man das passwort falsch  // english-ok: his request, quoted
            // eingibt nicht 'wrong password' sondern ne animation so wie bei    // english-ok: same quote, second line
            // mac". `PamResult.Failed` is the one outcome the movement can      // english-ok: same quote, third line
            // carry, because everybody already knows what it means.
            //
            // ⚠️ EVERY OTHER OUTCOME KEEPS ITS WORDS. An expired account and a
            // required password change also arrive here, and a field that
            // shakes and never opens — with nothing on screen saying why — is
            // worse than the sentence it replaced. That distinction is the whole
            // reason this is a branch and not a deletion.
            if (result === PamResult.Failed) {
                root.status = ""
                root.statusIsError = false
                fieldPill.shake()
                return
            }
            root.statusIsError = true
            root.status = "Authentication failed"
            // PAM is finished either way, so a second attempt needs a second
            // conversation. Without this the next Return does nothing at all
            // and the screen looks frozen.
            pam.start()
        }

        onError: function (error) {
            root.statusIsError = true
            // Naming the service, because the overwhelmingly likely cause is
            // that /etc/pam.d/buchhwin-lock is missing — and "authentication
            // error" alone sends you looking at your password instead.
            root.status = "PAM error (" + error + ") — is /etc/pam.d/buchhwin-lock installed?"
        }
    }
}
