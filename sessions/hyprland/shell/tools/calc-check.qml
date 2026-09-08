// Does the calculator get the right answers?
//
//   BUCHHWIN_TOOL=calc-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// Fixed expressions with answers worked out by hand, in the same shape as
// ical-check: the point of writing the evaluator rather than calling eval() was
// that it could be checked, and an unchecked parser is just eval() with extra
// steps.
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-calc-check.txt" }
    function note(s) { report += s + "\n"; out.setText(report) }

    function ok(what, cond) {
        if (cond) note("  ok    " + what)
        else { failures++; note("  FAIL  " + what) }
    }

    function value(expr, expected) {
        var r = Services.Calculator.evaluate(expr)
        if (!r.ok) {
            failures++
            note("  FAIL  " + expr + " → error: " + r.error)
            return
        }
        // Floating point: compare within a tolerance rather than exactly, or
        // sqrt(2)^2 fails a test that is about the parser, not about IEEE 754.
        var near = Math.abs(r.v - expected) < 1e-9
        if (near) note("  ok    " + expr + " = " + Services.Calculator.format(r.v))
        else {
            failures++
            note("  FAIL  " + expr + " = " + r.v + ", expected " + expected)
        }
    }

    function refuses(expr) {
        var r = Services.Calculator.evaluate(expr)
        if (!r.ok) note("  ok    refuses " + JSON.stringify(expr) + ": " + r.error)
        else {
            failures++
            note("  FAIL  " + JSON.stringify(expr) + " answered " + r.v
                 + " instead of refusing")
        }
    }

    Component.onCompleted: {
        note("buchhwin calc-check")

        // Precedence, the whole reason for a parser.
        root.value("2+3*4", 14)
        root.value("(2+3)*4", 20)
        root.value("12/4/3", 1)
        root.value("17%5", 2)
        root.value("2-3-4", -5)

        // ⚠️ Right associative, and unary minus looser than power. Both are the
        // conventions people expect and both are easy to get backwards.
        root.value("2^3^2", 512)
        root.value("-2^2", -4)
        root.value("(-2)^2", 4)

        // Bases in, which is most of what this gets used for here.
        root.value("0xff", 255)
        root.value("0b1011", 11)
        root.value("0o17", 15)
        root.value("0xff + 1", 256)
        root.value("1_000_000 / 1_000", 1000)

        // Functions and constants.
        root.value("sqrt(16)", 4)
        root.value("log2(1024)", 10)
        root.value("floor(3.7) + ceil(0.2)", 4)
        root.value("round(2.5)", 3)

        // Floating point, presented rather than exposed.
        var sum = Services.Calculator.evaluate("0.1 + 0.2")
        root.ok("0.1 + 0.2 shows as 0.3, not 0.30000000000000004",
                sum.ok && Services.Calculator.format(sum.v) === "0.3")

        // What it must refuse rather than guess at.
        root.refuses("2 3")
        root.refuses("(1+2")
        root.refuses("1/0")
        root.refuses("wat(2)")
        root.refuses("2 +")
        root.refuses("2 $ 3")

        // ⚠️ THE ONE THAT MATTERS MOST. If this ever answers, the field is a
        // way to run code in the shell's own engine rather than a calculator.
        root.refuses("Qt.quit()")
        root.refuses("[].constructor")

        // Bases out.
        root.ok("255 is 0xff", Services.Calculator.hexOf(255) === "0xff")
        root.ok("11 is 0b1011", Services.Calculator.binOf(11) === "0b1011")
        root.ok("a fraction has no hex", Services.Calculator.hexOf(1.5) === "")
        root.ok("-1 shows as 32-bit 0xffffffff",
                Services.Calculator.hexOf(-1) === "0xffffffff")

        // `ans`, which only means anything after an answer.
        Services.Calculator.remember(42)
        root.value("ans / 2", 21)

        note(root.failures === 0 ? "calc: all good"
                                 : "ABORT: " + root.failures + " check(s) failed")
        Qt.callLater(Qt.quit)
    }
}
