import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: root
    property alias server: server
    property var latest: null
    property int generation: 0
    property bool doNotDisturb: false

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: false
        // Do not advertise features the current UI cannot present or invoke.
        imageSupported: false
        actionsSupported: false
        persistenceSupported: true
        keepOnReload: true

        onNotification: notification => {
            notification.tracked = true
            root.latest = notification
            root.generation += 1
        }
    }
}
