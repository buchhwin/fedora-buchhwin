pragma Singleton

// The notification server.
//
// Quickshell IS the server here — there is no dunst or swaync underneath, which
// is why `Config.surfaces.notifications` switching it off means notifications
// go nowhere at all rather than to somebody else's popup. That is a real
// consequence and it is written down rather than discovered.
//
// `keepOnReload` matters more than it looks: without it every shell reload
// throws away what is on screen, and a reload happens on every palette change.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../config"

Singleton {
    id: root

    readonly property bool available: Config.surfaces.notifications

    property var list: []
    readonly property int count: list.length
    readonly property var latest: list.length ? list[0] : null

    signal arrived(var notification)

    // ------------------------------------------------------------------ toasts
    //
    // What is on screen RIGHT NOW, newest first, as opposed to `list`, which is
    // everything still unacknowledged. Two different questions: `list` answers
    // "what have I missed", `toasts` answers "what is interrupting me".
    //
    // It lives here rather than in the surface because a service owns state and
    // the ui draws it — and because two screens must not each keep their own
    // idea of which notifications are showing.
    property var toasts: []

    // How long this one should stay, in ms; 0 means "until dismissed".
    //
    // ⚠️ Critical never expires on its own. That is what the urgency level
    // means, and a disk-full warning that vanishes while you are looking at
    // another window is worse than no warning.
    // ⚠️ THE ENUM LIVES IN Quickshell.Services.Notifications, AND ui/ MAY NOT
    // IMPORT THAT. NotificationsPage used `NotificationUrgency` anyway — without
    // importing it — so every urgency comparison in that file threw a
    // ReferenceError, the colour binding never evaluated, and the dot fell back
    // to Rectangle's own default. Measured off a screenshot: 254,254,254, a
    // white square beside every notification on a dark panel, shipped.
    //
    // A string is the right shape for the answer anyway: the ui wants to know
    // which of three cases it is, not what number the specification gave it.
    function urgencyOf(n) {
        if (!n) return "normal"
        if (n.urgency === NotificationUrgency.Critical) return "critical"
        if (n.urgency === NotificationUrgency.Low) return "low"
        return "normal"
    }

    function toastDuration(n) {
        if (!n) return 0
        if (n.urgency === NotificationUrgency.Critical) return 0
        // The sender's own wish wins when it expressed one. -1 is the spec's
        // "you decide", 0 is the spec's "never" — both are theirs to say.
        if (n.expireTimeout > 0) return n.expireTimeout
        if (n.expireTimeout === 0) return 0
        return Config.notifications.timeoutMs
    }

    function _showToast(n) {
        var out = [n]
        for (var i = 0; i < root.toasts.length; i++)
            if (root.toasts[i] !== n)
                out.push(root.toasts[i])
        // Oldest fall off the end rather than newest being refused: a burst of
        // messages should show you the newest, not the first three.
        var max = Math.max(1, Config.notifications.maxVisible)
        root.toasts = out.slice(0, max)
    }

    // Take it off the screen but leave it in the list — it has not been read,
    // it has only stopped shouting. `Mod+N` is where it still is.
    function hideToast(n) {
        var out = []
        for (var i = 0; i < root.toasts.length; i++)
            if (root.toasts[i] !== n)
                out.push(root.toasts[i])
        root.toasts = out
    }

    function dismiss(n) { if (n) n.dismiss() }

    function dismissAll() {
        var copy = list.slice()
        for (var i = 0; i < copy.length; i++)
            copy[i].dismiss()
    }

    // ⚠️ NotificationServer has NO `enabled` property — assigning one fails the
    // whole services module, because they share a qmldir and one broken file
    // takes the rest with it ("Type Compositor unavailable" for a fault in
    // Media.qml, and so on up the chain).
    //
    // Switching notifications off therefore means not BEING the server, not
    // being it quietly: registering on the bus and then hiding what arrives
    // would swallow every notification on the machine with nothing to show for
    // it. A Loader is the honest way to say "we are not the daemon".
    Loader {
        id: serverLoader
        active: root.available
        // ⚠️ An explicit Component. Writing `sourceComponent: NotificationServer {}`
        // assigns an INSTANCE where a Component is expected; QML accepts it
        // without complaint and the server never registers on the bus, so
        // notify-send answers "The name is not activatable" and it looks like
        // a D-Bus problem rather than a typo.
        sourceComponent: serverComponent
    }

    Component {
        id: serverComponent

        NotificationServer {
            keepOnReload: true
            bodySupported: true
            bodyMarkupSupported: true
            imageSupported: true
            actionsSupported: true

            onNotification: function (n) {
                // Tracking is opt-in: without this the object is destroyed as
                // soon as the handler returns and the list holds dangling
                // entries.
                n.tracked = true
                root._rebuild()
                // A notification the sender marks transient is one it says is
                // not worth keeping — another program's volume popup, usually.
                // It still arrives, it just does not deserve to interrupt.
                // ⚠️ CRITICAL COMES THROUGH ANYWAY, dnd or not. Silencing a
                // disk-full warning because the switch is on is the failure
                // mode that makes people stop trusting the switch. Everything
                // else is merely not shown — it is still in the list.
                var loud = !n.transient
                    && (!Config.notifications.dnd
                        || n.urgency === NotificationUrgency.Critical)
                if (loud) {
                    root._showToast(n)
                    root.arrived(n)
                } else if (Config.notifications.dnd && !n.transient) {
                    // ⚠️⚠️ COUNTED, BECAUSE A SWITCH THAT SWALLOWS IN SILENCE IS
                    // A SWITCH YOU STOP TRUSTING. He reported "sie werden nicht  // english-ok: the report, quoted
                    // aufm desktop angezeigt als pop up" without knowing whether // english-ok: the report, quoted
                    // anything was suppressing them — and from the outside a
                    // do-not-disturb that works looks exactly like a broken
                    // notification daemon. Rule 5: what does not happen has to
                    // say so.
                    //
                    // ⚠️ ONLY THE ONES DND ACTUALLY TOOK. A transient message is
                    // one the SENDER said is not worth interrupting for, so
                    // counting it here would blame the switch for a decision it
                    // did not make.
                    root.silenced += 1
                }
            }
        }
    }

    // How many messages do-not-disturb has taken since it was switched on. Not
    // a config key: it is a reading, and a reading that survived a restart would
    // be a number nobody could explain.
    property int silenced: 0

    // ⚠️ RESET WHEN THE SWITCH GOES OFF, not when it goes on. Turning it on and
    // seeing a count from yesterday is the same confusion in the other
    // direction.
    Connections {
        target: Config.notifications ? Config.notifications : null
        function onDndChanged() {
            if (!Config.notifications.dnd)
                root.silenced = 0
        }
    }

    readonly property var server: serverLoader.item

    Connections {
        target: root.server ? root.server.trackedNotifications : null
        function onValuesChanged() { root._rebuild() }
    }

    function _rebuild() {
        var s = root.server
        var vals = s && s.trackedNotifications ? s.trackedNotifications.values : null
        var out = []
        if (vals)
            for (var i = 0; i < vals.length; i++)
                out.push(vals[i])
        // Newest first — the list is read top down.
        out.reverse()
        root.list = out

        // A notification that has been closed — by the sender, by a click, by
        // anything — must leave the screen with it. Without this a toast for a
        // withdrawn message stays up pointing at something that no longer
        // exists.
        var live = []
        for (var j = 0; j < root.toasts.length; j++)
            if (out.indexOf(root.toasts[j]) !== -1)
                live.push(root.toasts[j])
        if (live.length !== root.toasts.length)
            root.toasts = live
    }
}
