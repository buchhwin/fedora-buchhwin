// System — what this machine is, and the one button that undoes everything.
//
// ⚠️ HE ASKED FOR BOTH ON ONE PAGE, AND FOR IT TO BE LAST: "es soll ganz unten  // english-ok: his request, quoted
// in einem evtl nueen tab mit systeninfos so die wichtigesten systeminfos       // english-ok: same quote, second line
// angezeigt werden soll es einen button geben mit dem man alles an settings die // english-ok: same quote, third line
// es gibt zum default reseten kann aber dann mit deutlichem hinweis was der     // english-ok: same quote, fourth line
// button macht und mit bestätigung".                                           // english-ok: same quote, fifth line
//
// ⚠️⚠️ AND "Reset everything" MOVED HERE RATHER THAN BEING COPIED. It used to
// sit in "Backup and reset" on This Machine, where he did not find it — which
// is what prompted the request. Two reset buttons in two places is the
// duplication rule 6 forbids, and the export/import pair stays where it is
// because those are not the same question.
//
// ⚠️ WHICH FACTS ARE ON THE PAGE IS HIS CHOICE, not a judgement call: the
// machine (processor, memory, graphics, disk) and the system (Fedora, kernel,
// niri, quickshell, this desktop). Session/monitors and battery/thermals were
// offered and NOT picked, so they are absent rather than forgotten.
//
// ⚠️ THE READINGS ARE ActionRows WITH NO BUTTON, which is a shape this window
// already has — see the note in ActionRow.qml about a row that carries only a
// statement. A SettingRow would have needed a key into shell.json, and none of
// this is a setting.
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

    // Asked for by the row at the bottom; answered by SettingsContent, which
    // owns the surface that covers the window.
    signal askReset()

    // ⚠️ ON OPENING, ONCE. Both services answer in about a tenth of a second and
    // never run again; neither has a timer. See services/SystemInfo.qml for why
    // an info page is the worst possible place for polling.
    Component.onCompleted: {
        Services.SystemInfo.scan()
    }

    // "unknown" rather than a blank. A row that reads "Kernel" and then nothing
    // looks like a bug in the page; a row that says it could not tell is a fact.
    function orUnknown(s) {
        return String(s).length > 0 ? String(s) : "unknown"
    }

    // Kibibytes as the machine reports them, in the units a person reads. One
    // decimal, because "7.6 GB free of 7.7" says something that "8 of 8" does
    // not.
    function gib(kb) {
        if (!kb || kb <= 0)
            return "unknown"
        return (kb / 1048576).toFixed(1) + " GB"
    }

    // ------------------------------------------------------------- the machine
    SettingGroup {
        Layout.fillWidth: true
        title: "This machine"

        ActionRow {
            Layout.fillWidth: true
            label: "Processor"
            hint: Services.SystemInfo.cpuCores > 0
                  ? root.orUnknown(Services.SystemInfo.cpuModel)
                    + " · " + Services.SystemInfo.cpuCores + " threads"
                  : root.orUnknown(Services.SystemInfo.cpuModel)
        }

        ActionRow {
            Layout.fillWidth: true
            label: "Memory"
            hint: Services.SystemInfo.memTotalKb > 0
                  ? root.gib(Services.SystemInfo.memAvailableKb) + " free of "
                    + root.gib(Services.SystemInfo.memTotalKb)
                  : "unknown"
        }

        ActionRow {
            Layout.fillWidth: true
            label: "Graphics"
            hint: root.orUnknown(Services.SystemInfo.graphics)
        }

        ActionRow {
            Layout.fillWidth: true
            label: "Disk"
            hint: Services.SystemInfo.diskFree.length > 0
                  ? Services.SystemInfo.diskFree + " free of "
                    + Services.SystemInfo.diskTotal + " on /"
                  : "unknown"
        }
    }

    // -------------------------------------------------------------- the system
    SettingGroup {
        Layout.fillWidth: true
        title: "System"

        ActionRow {
            Layout.fillWidth: true
            label: "Fedora"
            hint: root.orUnknown(Services.SystemInfo.osName)
        }

        ActionRow {
            Layout.fillWidth: true
            label: "Kernel"
            hint: root.orUnknown(Services.SystemInfo.kernel)
        }

        ActionRow {
            Layout.fillWidth: true
            label: "Compositor"
            hint: root.orUnknown(Services.SystemInfo.hyprlandVersion)
        }

        ActionRow {
            Layout.fillWidth: true
            label: "Shell toolkit"
            hint: root.orUnknown(Services.SystemInfo.quickshellVersion)
        }

        ActionRow {
            Layout.fillWidth: true
            label: "This desktop"
            // ⚠️ FROM THE STAMP THE INSTALLER LEAVES, and it says so when there
            // is none. A version compiled into the source is right on the day
            // it is typed and wrong every day after.
            hint: Services.SystemInfo.desktopVersion.length > 0
                  ? Services.SystemInfo.desktopVersion
                  : "unknown — this tree was not installed by install.sh"
        }
    }

    // ------------------------------------------------------------------- reset
    //
    // ⚠️⚠️ A SURFACE, NOT A SECOND PRESS, AND THAT IS HIS DECISION AFTER BEING
    // ASKED. The two-stage button is what the per-page reset uses and it is
    // right there: small, reversible in effect, and it now prints a line beside
    // itself. This one is neither small nor reversible — and the two-stage form
    // is exactly what produced "die reset taste geht nicht", because stage one // english-ok: his report, quoted
    // was four words under his own finger.
    SettingGroup {
        Layout.fillWidth: true
        title: "Reset"

        ActionRow {
            Layout.fillWidth: true
            label: "Reset everything"
            hint: "Every setting back to the way it ships. Ask first — this cannot be undone."
            button: "Reset everything"
            destructive: true
            status: Backup.lastAction === "reset" ? Backup.status : ""
            failed: Backup.failed
            // ⚠️ A SIGNAL, NOT A REACH UPWARDS. The sheet covers the whole
            // window, so it belongs to the window; a page that positioned it
            // would have to find its way there through `Window.contentItem`,
            // and that exact expression is recorded in the handover as the
            // cause of a dropdown that was "fixed" twice. SettingsContent
            // listens for this.
            onTriggered: root.askReset()
        }
    }
}
