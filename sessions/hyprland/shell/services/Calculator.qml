pragma Singleton

// An expression evaluator, written out by hand.
//
// ⚠️ NO `eval()`, AND NOT OUT OF SUPERSTITION. The shell's JS engine is the same
// one every binding in this desktop runs in; handing it a string typed into a
// text field gives that string the run of the whole configuration. A parser is
// forty lines longer and can only ever produce a number.
//
// It is also the reason this can be tested at all: like Ical, it is pure
// JavaScript with no Quickshell type, no clock and no files, so tools/
// calc-check.qml can run it against fixed expressions with known answers and
// tests/calculator.sh can fail the build when one of them stops being true.
//
// What it takes:
//
//   12 + 3*4          arithmetic, with the precedence you expect
//   (1+2)^10          power, right associative — 2^3^2 is 512, not 64
//   17 % 5            remainder
//   0xff  0b1011  0o17    hex, binary and octal in
//   1_000_000         underscores anywhere in a number, ignored
//   sqrt(2) log2(1024)    a handful of functions
//   ans * 2           the previous result
//
// Integer answers come back in decimal, hex and binary at once, because the
// question "what is 0x2000 in decimal" is most of what a calculator gets used
// for on a machine like this one.
import QtQuick
import Quickshell

Singleton {
    id: root

    // Arithmetic, on any machine, always. Same reasoning as Ical: the flag is
    // constant rather than absent, so services/qmldir's "without exception"
    // stays true and nobody has to look up why this one is different.
    readonly property bool available: true

    // The last successful answer, reachable as `ans`.
    property real answer: 0
    property bool hasAnswer: false

    readonly property var functions: ({
        "sqrt": Math.sqrt, "abs": Math.abs, "round": Math.round,
        "floor": Math.floor, "ceil": Math.ceil, "ln": Math.log,
        "log2": function (x) { return Math.log(x) / Math.LN2 },
        "log10": function (x) { return Math.log(x) / Math.LN10 },
        "sin": Math.sin, "cos": Math.cos, "tan": Math.tan
    })

    readonly property var constants: ({ "pi": Math.PI, "e": Math.E })

    // ------------------------------------------------------------- tokenizer
    //
    // ⚠️ The base prefixes are checked BEFORE the plain number, or "0x1f" reads
    // as the number 0 followed by an unknown name.
    function tokenize(text) {
        var out = []
        var i = 0
        var s = String(text)
        while (i < s.length) {
            var c = s.charAt(i)
            if (c === " " || c === "\t") { i++; continue }

            if (c >= "0" && c <= "9" || c === ".") {
                var rest = s.substring(i)
                var m = rest.match(/^0[xX][0-9a-fA-F_]+/)
                    || rest.match(/^0[bB][01_]+/)
                    || rest.match(/^0[oO][0-7_]+/)
                if (m) {
                    var body = m[0].replace(/_/g, "")
                    var base = body.charAt(1) === "x" || body.charAt(1) === "X" ? 16
                             : body.charAt(1) === "b" || body.charAt(1) === "B" ? 2 : 8
                    out.push({ t: "num", v: parseInt(body.substring(2), base) })
                    i += m[0].length
                    continue
                }
                m = rest.match(/^[0-9_]*\.?[0-9_]+([eE][-+]?[0-9]+)?/)
                if (!m)
                    return { ok: false, error: "That is not a number" }
                out.push({ t: "num", v: parseFloat(m[0].replace(/_/g, "")) })
                i += m[0].length
                continue
            }

            if (c >= "a" && c <= "z" || c >= "A" && c <= "Z") {
                var name = s.substring(i).match(/^[A-Za-z][A-Za-z0-9]*/)[0]
                out.push({ t: "name", v: name.toLowerCase() })
                i += name.length
                continue
            }

            if ("+-*/%^()".indexOf(c) >= 0) {
                out.push({ t: c })
                i++
                continue
            }

            return { ok: false, error: "I do not know what " + c + " means" }
        }
        return { ok: true, tokens: out }
    }

    // ---------------------------------------------------------------- parser
    //
    // Recursive descent, one function per level of precedence. `pos` is carried
    // in a one-element array because JavaScript has no out-parameters and a
    // property on the singleton would make two evaluations at once share it.
    function parseExpr(tk, pos) {
        var left = root.parseTerm(tk, pos)
        if (!left.ok) return left
        while (pos[0] < tk.length && (tk[pos[0]].t === "+" || tk[pos[0]].t === "-")) {
            var op = tk[pos[0]].t
            pos[0]++
            var right = root.parseTerm(tk, pos)
            if (!right.ok) return right
            left = { ok: true, v: op === "+" ? left.v + right.v : left.v - right.v }
        }
        return left
    }

    function parseTerm(tk, pos) {
        var left = root.parseUnary(tk, pos)
        if (!left.ok) return left
        while (pos[0] < tk.length
               && (tk[pos[0]].t === "*" || tk[pos[0]].t === "/" || tk[pos[0]].t === "%")) {
            var op = tk[pos[0]].t
            pos[0]++
            var right = root.parseUnary(tk, pos)
            if (!right.ok) return right
            if ((op === "/" || op === "%") && right.v === 0)
                return { ok: false, error: "Division by zero" }
            left = { ok: true, v: op === "*" ? left.v * right.v
                              : op === "/" ? left.v / right.v
                              : left.v % right.v }
        }
        return left
    }

    // ⚠️ Unary minus binds LOOSER than power, so -2^2 is -4, which is what every
    // calculator and every algebra teacher means by it.
    function parseUnary(tk, pos) {
        if (pos[0] < tk.length && (tk[pos[0]].t === "-" || tk[pos[0]].t === "+")) {
            var op = tk[pos[0]].t
            pos[0]++
            var inner = root.parseUnary(tk, pos)
            if (!inner.ok) return inner
            return { ok: true, v: op === "-" ? -inner.v : inner.v }
        }
        return root.parsePower(tk, pos)
    }

    // Right associative: 2^3^2 is 2^(3^2) = 512.
    function parsePower(tk, pos) {
        var base = root.parsePrimary(tk, pos)
        if (!base.ok) return base
        if (pos[0] < tk.length && tk[pos[0]].t === "^") {
            pos[0]++
            var exp = root.parseUnary(tk, pos)
            if (!exp.ok) return exp
            return { ok: true, v: Math.pow(base.v, exp.v) }
        }
        return base
    }

    function parsePrimary(tk, pos) {
        if (pos[0] >= tk.length)
            return { ok: false, error: "The expression stops early" }
        var t = tk[pos[0]]

        if (t.t === "num") {
            pos[0]++
            return { ok: true, v: t.v }
        }

        if (t.t === "(") {
            pos[0]++
            var inner = root.parseExpr(tk, pos)
            if (!inner.ok) return inner
            if (pos[0] >= tk.length || tk[pos[0]].t !== ")")
                return { ok: false, error: "A bracket is not closed" }
            pos[0]++
            return inner
        }

        if (t.t === "name") {
            pos[0]++
            if (t.v === "ans")
                return { ok: true, v: root.answer }
            if (root.constants[t.v] !== undefined)
                return { ok: true, v: root.constants[t.v] }
            var fn = root.functions[t.v]
            if (!fn)
                return { ok: false, error: "I do not know " + t.v }
            if (pos[0] >= tk.length || tk[pos[0]].t !== "(")
                return { ok: false, error: t.v + " needs a bracket after it" }
            pos[0]++
            var arg = root.parseExpr(tk, pos)
            if (!arg.ok) return arg
            if (pos[0] >= tk.length || tk[pos[0]].t !== ")")
                return { ok: false, error: "A bracket is not closed" }
            pos[0]++
            return { ok: true, v: fn(arg.v) }
        }

        return { ok: false, error: "That does not belong there" }
    }

    // ------------------------------------------------------------ the answer
    function evaluate(text) {
        if (String(text).trim().length === 0)
            return { ok: false, error: "" }
        var lexed = root.tokenize(text)
        if (!lexed.ok) return lexed
        if (lexed.tokens.length === 0)
            return { ok: false, error: "" }
        var pos = [0]
        var res = root.parseExpr(lexed.tokens, pos)
        if (!res.ok) return res
        // ⚠️ Anything left over is an error rather than something to ignore.
        // "2 3" is a typo, and a calculator that quietly answers 2 is worse than
        // one that says it does not understand.
        if (pos[0] !== lexed.tokens.length)
            return { ok: false, error: "There is more here than I can read" }
        if (!isFinite(res.v))
            return { ok: false, error: "That is not a number any more" }
        return { ok: true, v: res.v }
    }

    // Decimal, with enough places to be useful and not so many that floating
    // point noise shows through. 0.1 + 0.2 answers 0.3, not 0.30000000000000004.
    function format(v) {
        if (Math.abs(v) >= 1e15 || (v !== 0 && Math.abs(v) < 1e-9))
            return v.toExponential(6)
        var s = v.toFixed(10).replace(/0+$/, "").replace(/\.$/, "")
        return s.length ? s : "0"
    }

    function isWhole(v) {
        return isFinite(v) && Math.floor(v) === v && Math.abs(v) < 9007199254740992
    }

    // ⚠️ `>>> 0` FIRST for negatives, because JavaScript's toString(16) on a
    // negative gives "-ff" rather than a two's complement — readable, but not
    // what anybody staring at a register wants to see. Only 32-bit values get
    // that treatment; a larger one is shown as its own sign and magnitude.
    function hexOf(v) {
        if (!root.isWhole(v)) return ""
        if (v < 0 && v >= -2147483648)
            return "0x" + ((v >>> 0).toString(16))
        return (v < 0 ? "-0x" : "0x") + Math.abs(v).toString(16)
    }

    function binOf(v) {
        if (!root.isWhole(v)) return ""
        if (Math.abs(v) > 4294967295) return ""
        if (v < 0 && v >= -2147483648)
            return "0b" + ((v >>> 0).toString(2))
        return (v < 0 ? "-0b" : "0b") + Math.abs(v).toString(2)
    }

    function remember(v) {
        root.answer = v
        root.hasAnswer = true
    }
}
