// Rebinding: does the override resolve, and does the clash check hold?
//
// ⚠️ THE CLASH CHECK IS WHY THIS FILE EXISTS. Two bindings on one key is a KDL
// parse error and niri does not start with a config it cannot parse — so a
// clash check that quietly stopped working would not show up as a wrong colour
// or a dead button. It would show up as a laptop that boots to nothing, once,
// on the day somebody moved a shortcut.
//
// ⚠️ AND THE OVERRIDE SHAPE IS THE OTHER HALF. `binds` is all-or-nothing, so a
// rebinding written as the resolved list freezes every other binding at what it
// was that day. This project has already carried 63 frozen bindings for weeks
// once. The check below is that the FILE holds one small override and not a
// copy of the list.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../config"

Item {
    id: root

    readonly property string out: "/tmp/buchhwin-rebind-check.txt"
    property string report: ""
    property int step: 0

    function say(s) { report += s + "\n"; log.setText(report) }
    function check(name, ok, detail) {
        say((ok ? "  ok   " : "  FAIL ") + name + (detail ? "   " + detail : ""))
    }
    function keyOf(desc) {
        var all = Config.binds
        for (var i = 0; i < all.length; i++)
            if (String(all[i].desc) === desc) return String(all[i].key)
        return ""
    }

    FileView { id: log; path: root.out }

    WaitFor {
        condition: Config.settled
        onTimedOut: { root.say("  FAIL config never settled"); Qt.callLater(Qt.quit) }
        onReady: steps.start()
    }

    // Every write goes through Config.flush(), which posts a file write; the
    // resolution itself is in memory and immediate, so a short step is enough.
    Timer { id: steps; interval: 200; repeat: true; onTriggered: root.advance() }

    function advance() {
        step++
        switch (step) {

        case 1:
            check("the defaults are in force to start with",
                  Config.binds.length === Config.defaultBinds.length,
                  Config.binds.length + " bindings")
            check("Terminal ships on Mod+Return", root.keyOf("Terminal") === "Mod+Return")
            break

        case 2:
            // ------------------------------------------------ a clean rebind
            Config.setRebind("Mod+Return", "Mod+T")
            break

        case 3:
            check("the binding moved", root.keyOf("Terminal") === "Mod+T",
                  root.keyOf("Terminal"))
            check("nothing else moved with it",
                  Config.binds.length === Config.defaultBinds.length)
            check("the browser is still on its own key", root.keyOf("Browser") === "Mod+B")
            check("the FILE holds an override, not a copy of the list",
                  Config.get("rebinds").length === 1
                  && (!Config.get("binds") || Config.get("binds").length === 0),
                  JSON.stringify(Config.get("rebinds")))
            check("rebindOf reports where it went",
                  Config.rebindOf("Mod+Return") === "Mod+T")
            break

        case 4:
            // ------------------------------------------------- the clash check
            //
            // Mod+B belongs to the browser. Trying to move the file manager
            // there has to be refused, and it has to name the browser.
            var clash = Config.bindClash("Mod+E", "Mod+B")
            check("a taken key is refused", clash !== null,
                  clash ? String(clash.desc) : "nothing came back")
            check("and the refusal names the binding in the way",
                  clash && String(clash.desc) === "Browser")

            // ⚠️ THE OTHER DIRECTION, or the check could simply be "always
            // refuse" and still look right here.
            check("a free key is allowed",
                  Config.bindClash("Mod+E", "Mod+F9") === null)
            check("a binding may keep its own key",
                  Config.bindClash("Mod+E", "Mod+E") === null)

            // ⚠️ AND AGAINST THE MOVED KEY, not the default one. Mod+T is where
            // the terminal is NOW; Mod+Return is where it ships. A check that
            // only ever looked at the defaults would let a second binding onto
            // Mod+T and produce exactly the config niri refuses to parse.
            check("the clash check sees the CURRENT keys",
                  Config.bindClash("Mod+E", "Mod+T") !== null)
            check("and the key it was freed from is available again",
                  Config.bindClash("Mod+E", "Mod+Return") === null)
            break

        case 5:
            // -------------------------------------------------- unbinding
            Config.setRebind("Mod+B", "")
            break

        case 6:
            check("an empty override unbinds", root.keyOf("Browser") === "",
                  Config.binds.length + " bindings left")
            check("exactly one binding disappeared",
                  Config.binds.length === Config.defaultBinds.length - 1)
            break

        case 7:
            // ---------------------------------------------- back to default
            Config.setRebind("Mod+Return", "Mod+Return")
            break

        case 8:
            check("rebinding to the default key removes the override",
                  Config.rebindOf("Mod+Return") === undefined)
            check("and it is back where it ships", root.keyOf("Terminal") === "Mod+Return")
            check("the override list holds only the other one",
                  Config.get("rebinds").length === 1,
                  JSON.stringify(Config.get("rebinds")))
            Config.clearRebinds()
            break

        case 9:
            check("clearing puts everything back",
                  Config.binds.length === Config.defaultBinds.length
                  && root.keyOf("Browser") === "Mod+B")
            check("and empties the file", Config.get("rebinds").length === 0)
            steps.stop()
            Qt.callLater(Qt.quit)
            break
        }
    }
}
