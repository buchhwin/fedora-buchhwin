// Wait for a condition, not for a guessed number of milliseconds.
//
// This exists because a fixed settle timer hid a real bug for the whole of M1.
// QML creates a singleton on FIRST ACCESS. Both headless tools touched Scheme
// and Config for the first time INSIDE their settle timer — so the palette only
// began loading in the same line that read the result, and `Scheme.ready` was
// false every single time. The tools then either aborted (render) or reported
// the built-in fallback colours as if they were the palette (dump-tokens), and
// tests/all-palettes.sh passed eleven times while testing one palette.
//
// Binding `condition` here is what fixes it, and it is not a trick: evaluating
// the binding at creation IS the first access, so the singletons are built and
// their FileViews start loading before anything waits on them. After that the
// binding notifies, so we continue the instant the data lands — measured at
// ~50 ms, against the 700 ms that were being burned for nothing.
//
//   WaitFor {
//       condition: Scheme.ready && Config.loaded
//       onReady: writeEverything()
//       onTimedOut: report("ABORT: palette did not load")
//   }
//
// The timeout is a real failure path, not a formality: a tool that cannot see
// its own data must say so and exit non-zero, never write half a desktop.

import QtQuick

Item {
    id: root

    // Bind this to whatever "the data is here" means for the caller.
    property bool condition: false

    // Generous: this guards against a broken checkout, not against slow I/O.
    property int timeoutMs: 5000

    signal ready
    signal timedOut

    readonly property bool settled: _done
    property bool _done: false

    // Emit one event-loop step after the condition holds.
    //
    // Measured, not assumed: FileView.loaded turns true BEFORE JsonAdapter has
    // pushed the parsed JSON into its properties. A consumer that reads values
    // inside onReady — which is what a file generator does — would still get
    // the defaults and write them out with no error anywhere. The probe read
    // gapsOut=10 at `settled` and gapsOut=24 after a single Qt.callLater.
    //
    // One deferral is enough, and it is here rather than in each consumer so
    // that nobody has to rediscover it. `adapterUpdated` would look like the
    // signal for this; it does not fire on load.
    function _finish(ok) {
        if (_done)
            return
        _done = true
        guard.stop()
        if (ok)
            Qt.callLater(root.ready)
        else
            root.timedOut()
    }

    onConditionChanged: if (condition) _finish(true)

    Component.onCompleted: {
        guard.start()
        // Already true is possible on a warm start; do not wait for a change
        // that will never come.
        if (condition)
            _finish(true)
    }

    Timer {
        id: guard
        interval: root.timeoutMs
        onTriggered: root._finish(false)
    }
}
