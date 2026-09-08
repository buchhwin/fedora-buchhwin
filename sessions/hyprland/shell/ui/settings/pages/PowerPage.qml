// Power — when the screen goes off, when the session locks, when the machine
// sleeps, and what the lid does.
//
// ⚠️ EVERY DELAY COUNTS FROM THE START OF IDLE, not from the previous step. Four
// independent timers, the way Windows counts them, so "screen off after 5, lock
// after 6" is two numbers that can be read back rather than one number and an
// offset. 0 means never, everywhere.
//
// ⚠️ AND EVERY ONE OF THEM STOPS FOR AN IDLE INHIBITOR. A video player asking to
// keep the screen awake is honoured, which is the whole reason the protocol has
// inhibitors — without it this page is a machine for locking the screen during
// films.
//
// Battery and mains are separate throughout. They are the two situations where
// the right answer genuinely differs, and one shared number would be wrong in
// one of them permanently.
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

    // Which column is doing anything right now, so the page is readable while
    // it is open rather than being two lists of numbers that look equally live.
    readonly property string nowOn:
        Services.Power.available
            ? (Services.Power.charging ? "mains" : "battery")
            : "mains"

    BarText {
        Layout.fillWidth: true
        text: Services.Power.available
              ? "Running on " + root.nowOn + " — "
                + Math.round(Services.Power.percent) + "%. "
                + "The " + root.nowOn + " numbers are the ones in effect."
              : "No battery on this machine, so the mains numbers are always the "
                + "ones in effect."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "On battery"

        SettingRow {
            Layout.fillWidth: true
            key: "power.screenOffBattery"
            label: "Turn the screen off after"
            hint: "Minutes of no input. 0 never turns it off. Moving the mouse or pressing a key brings it straight back."
            kind: "slider"
            from: 0; to: 60; step: 1
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.lockBattery"
            label: "Lock after"
            // Why it is this way: A minute more than the screen delay turns 'I
            // looked away' into a keypress instead of a password.
            hint: "Counted from the start of idle, not from the screen going off."
            kind: "slider"
            from: 0; to: 120; step: 1
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.suspendBattery"
            label: "Suspend after"
            hint: "The session is locked first, so opening the lid again asks for the password."
            kind: "slider"
            from: 0; to: 180; step: 5
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.lidClosedBattery"
            label: "When the lid closes"
            // Why it is this way: `bhctl power apply` writes it, and it takes
            // effect after the next reboot or a restart of systemd-logind.
            hint: "Handled by logind, not by the shell."
            kind: "choice"
            choices: [{ value: "suspend", label: "Suspend" },
                      { value: "lock",    label: "Lock only" },
                      { value: "ignore",  label: "Do nothing" }]
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "On mains"

        SettingRow {
            Layout.fillWidth: true
            key: "power.screenOffAc"
            advanced: true
            label: "Turn the screen off after"
            hint: "Minutes of no input. 0 never turns it off."
            kind: "slider"
            from: 0; to: 120; step: 1
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.lockAc"
            advanced: true
            label: "Lock after"
            hint: "0 never locks by itself. Mod+L always locks now."
            kind: "slider"
            from: 0; to: 180; step: 1
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.suspendAc"
            advanced: true
            label: "Suspend after"
            // Why it is this way: a machine that is plugged in is usually
            // plugged in because something should keep running.
            hint: "0 means never, and that is the default on mains."
            kind: "slider"
            from: 0; to: 240; step: 5
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.lidClosedAc"
            advanced: true
            label: "When the lid closes"
            // Why it is this way: logind keeps the two apart, so a docked
            // laptop can stay awake with the lid shut.
            hint: "The same setting for a machine on mains."
            kind: "choice"
            choices: [{ value: "suspend", label: "Suspend" },
                      { value: "lock",    label: "Lock only" },
                      { value: "ignore",  label: "Do nothing" }]
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Performance"

        SettingRow {
            Layout.fillWidth: true
            key: "power.profile"
            advanced: true
            label: "Power profile"
            // Why it is this way: Balanced is the default; power saver caps
            // the boost clocks, which is quieter and cooler.
            hint: "The three tuned-ppd offers on this machine."
            kind: "choice"
            choices: [{ value: "power-saver", label: "Power saver" },
                      { value: "balanced",    label: "Balanced" },
                      { value: "performance", label: "Performance" }]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.dimBeforeOff"
            advanced: true
            label: "Dim shortly before the screen goes off"
            // Why it is this way: not a fixed brightness, which would quietly
            // overwrite yours.
            hint: "Half a minute of warning, and the level you had is restored the moment anything happens."
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Battery warnings"

        SettingRow {
            Layout.fillWidth: true
            key: "power.warnAt"
            advanced: true
            label: "Warn at"
            // Why it is this way: UPower reports every few seconds, and a
            // warning that repeats is one you learn to ignore. Plugging in
            // re-arms it.
            hint: "Once per discharge, not once per reading."
            kind: "slider"
            from: 0; to: 50; step: 1
            unit: "%"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.criticalAt"
            advanced: true
            label: "Warn urgently at"
            hint: "The second and last warning. Also once per discharge."
            kind: "slider"
            from: 0; to: 30; step: 1
            unit: "%"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Battery health"

        // ⚠️ THE ROWS ARE HERE EVEN WHEN THE MACHINE HAS NO THRESHOLDS, and the
        // caption below says which it is. The alternative — hiding them — makes
        // a laptop that DOES have them look identical to one that does not, and
        // the only way to find out would be to own both.
        SettingRow {
            Layout.fillWidth: true
            key: "power.chargeStart"
            advanced: true
            label: "Start charging at"
            // Why it is this way: firmware clamps these, so the value that
            // comes back is the value that counts, not the one that was set.
            hint: "Zero leaves the firmware alone."
            kind: "slider"
            from: 0; to: 95; step: 5
            unit: "%"
        }

        SettingRow {
            Layout.fillWidth: true
            key: "power.chargeEnd"
            advanced: true
            label: "Stop charging at"
            hint: "Around 80 is the usual answer for a laptop that lives on a desk."
            kind: "slider"
            from: 0; to: 100; step: 5
            unit: "%"
        }

        BarText {
            Layout.fillWidth: true
            text: !Services.Power.thresholdsPresent
                  ? "This machine exposes no charge thresholds — the two rows above have nothing to write to."
                  : Services.Power.chargeStatus.length > 0
                    ? Services.Power.chargeStatus
                    : "The battery currently reports "
                      + Services.Power.chargeStartNow + "% to "
                      + Services.Power.chargeEndNow + "%."
            font.pixelSize: Theme.fontSizeSm
            color: Services.Power.chargeStatus.length > 0 ? Theme.warn : Theme.fgMuted
            wrapMode: Text.WordWrap
        }
    }

    BarText {
        Layout.fillWidth: true
        text: "Idle is handled by the shell itself — Quickshell's IdleMonitor "
            + "over ext-idle-notify, the same protocol swayidle uses. The lid is "
            + "the one thing here logind owns, because it happens whether or not "
            + "the shell is running."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }
}
