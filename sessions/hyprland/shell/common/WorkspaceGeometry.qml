pragma Singleton

// Where a workspace's windows sit inside a thumbnail box, as shares of it.
//
// It lives here rather than on a page because TWO surfaces draw the same
// picture now: `Mod+Tab` shows one column per workspace of this monitor (B32),
// and `Shift+Alt+Tab` shows one column per MONITOR (B33). Rule 6 — a list may
// not exist twice — and a copy would have been worse than usual here, because
// the arithmetic is measured against niri's real numbers and a second copy would
// drift away from those measurements silently.
//
// It is a function rather than a pile of bindings for a reason this project has
// paid for: the geometry used to be spread across four expressions inside a
// Repeater delegate, where nothing could read it without a pointer and a
// screenshot. `tests/workspaces.sh` calls it directly, so the arithmetic is
// checkable on a machine with one screen and no session.
//
// ⚠️ MEASURED INPUTS, not assumed ones. From `niri msg -j windows` on the lab
// VM:
//
//   pos_in_scrolling_layout      [column, row], 1-based
//   tile_size                    [w, h] in logical pixels
//   tile_pos_in_workspace_view   NULL — it is not usable, so it is not used
//
// Each window was 1232 wide on a 1280 output: niri scrolls, so a workspace is
// legitimately wider than its screen. Three of those as a share of the box is
// 2.9x, and that overflow is exactly what "voll abgeschnitten" was.            // english-ok: the report, quoted

import QtQuick

QtObject {
    id: root

    // Returns [{ win, x, y, w, h }] with x/y/w/h as shares 0..1 of the box.
    function layoutWindows(wins, outW, outH) {
        var out = []
        if (!wins || !wins.length)
            return out

        // Group into columns, keeping niri's own column numbers.
        var cols = {}
        for (var i = 0; i < wins.length; i++) {
            var L = wins[i].layout
            var p = (L && L.pos_in_scrolling_layout) || [i + 1, 1]
            var size = (L && L.tile_size) || [0, 0]
            var c = p[0]
            if (cols[c] === undefined)
                cols[c] = { w: 0, wins: [] }
            if (size[0] > cols[c].w)
                cols[c].w = size[0]
            cols[c].wins.push({ win: wins[i], row: p[1], w: size[0], h: size[1] })
        }

        var keys = Object.keys(cols).map(Number).sort(function (a, b) { return a - b })

        // ⚠️ THE DENOMINATOR IS THE WIDER OF SCREEN AND CONTENT, and that single
        // choice is the whole of B77. A workspace that fits its screen is drawn
        // against the screen, so a half-width window still looks half-width. One
        // that scrolls past the edge is drawn against its own total, so it fits
        // the box complete — smaller, but nothing clipped and the windows still
        // comparable to each other.
        var total = 0
        for (var k = 0; k < keys.length; k++)
            total += cols[keys[k]].w
        var spanW = Math.max(outW || 0, total, 1)
        var spanH = Math.max(outH || 0, 1)

        // ⚠️⚠️ B82 · THE ROW IS CENTRED, AND THAT IS A MEASUREMENT RATHER THAN A
        // TASTE. His report: "beim normalen supertab stimmen links und rechts    // english-ok: the report, quoted
        // die abstände nicht zwischen fenster und rand, der ist rechts zu groß". // english-ok: the report, quoted
        //
        // He was right, and the cause was this loop starting at x = 0: one
        // window of 1232 on a 1280 screen used 96 % of the box from the left
        // edge, so the whole 4 % of slack collected on the right.
        //
        // ⚠️ CENTRING IS NOT THE "SYMMETRIC LOOKS NICER" ANSWER — it is what niri
        // does. Photographed on the lab VM, one window, `grim -o Virtual-1`: the
        // wallpaper shows through about 24 px on the LEFT and about 24 px on the
        // RIGHT of a 1232-wide window on a 1280 screen. The thumbnail was drawing
        // a layout the compositor never produces.
        //
        // ⚠️ And it costs nothing in the overflow case: there `spanW === total`,
        // so the offset is 0 and B77's full-bleed picture is untouched.
        var offset = (spanW - total) / 2

        var x = offset
        for (var j = 0; j < keys.length; j++) {
            var col = cols[keys[j]]
            col.wins.sort(function (a, b) { return a.row - b.row })
            var y = 0
            for (var m = 0; m < col.wins.length; m++) {
                var e = col.wins[m]
                out.push({
                    win: e.win,
                    x: x / spanW,
                    y: y / spanH,
                    w: e.w / spanW,
                    h: e.h / spanH
                })
                y += e.h
            }
            x += col.w
        }
        return out
    }

    // ⚠️ B33 · WHICH WORKSPACE EACH MONITOR COLUMN SHOWS, as a pure function so
    // it can be checked headless — the same reason `layoutWindows` is one.
    //
    // `outputs` is niri's map (connector name → output), `workspaces` its list.
    // `wanted` is the index every column starts on: his instruction is that the
    // menu opens with the workspace he is standing on, on EVERY monitor —
    // "aber auf allen monitoren wird der aktuelle workspace genommen".          // english-ok: the request, quoted
    //
    // ⚠️ INDICES COUNT PER OUTPUT. Measured on the lab VM with two heads: idx=1
    // exists on Virtual-1 AND on Virtual-2. So a column picks the workspace with
    // that index ON ITS OWN MONITOR, and a global sort by idx — which is what
    // `Niri.orderedWorkspaces` gives — mixes the two together.
    //
    // ⚠️ A monitor may simply not have that index. niri creates workspaces on
    // demand, so a monitor showing one workspace has no idx=3 at all. That
    // column falls back to the highest index it does have rather than going
    // blank: an empty column reads as "this monitor is empty", which is a
    // different and wrong statement.
    // ⚠️ `byOutput` IS THE PER-COLUMN OVERRIDE, and it is a parameter rather than
    // state inside the page for the reason his example gives: "wenn das fenster  // english-ok: the request, quoted
    // aufm 2. workspace ist aufm linken monitor, das ich den dann aufm 3ten      // english-ok: the request, quoted
    // workspace aufm rechten monitor ziehen kann" — two different indices at     // english-ok: the request, quoted
    // once. A single shared number cannot express that, and keeping the map out
    // here means the whole picture stays one pure function that a test can call.
    function monitorColumns(outputs, workspaces, windows, wanted, byOutput) {
        var out = []
        if (!outputs)
            return out

        var byWs = {}
        var all = windows || []
        for (var i = 0; i < all.length; i++) {
            var k = String(all[i].workspace_id)
            if (byWs[k] === undefined)
                byWs[k] = []
            byWs[k].push(all[i])
        }

        // Left to right as they really stand, not as the map happens to iterate.
        var names = Object.keys(outputs)
        names.sort(function (a, b) {
            var la = (outputs[a] && outputs[a].logical) || {}
            var lb = (outputs[b] && outputs[b].logical) || {}
            var dx = (la.x || 0) - (lb.x || 0)
            if (dx !== 0)
                return dx
            return String(a) < String(b) ? -1 : 1
        })

        var ws = workspaces || []
        for (var n = 0; n < names.length; n++) {
            var name = names[n]
            var mine = []
            for (var j = 0; j < ws.length; j++)
                if (String(ws[j].output || "") === String(name))
                    mine.push(ws[j])
            mine.sort(function (a, b) { return a.idx - b.idx })

            var want = wanted
            if (byOutput && byOutput[String(name)] !== undefined)
                want = byOutput[String(name)]

            var pick = null
            for (var m = 0; m < mine.length; m++)
                if (mine[m].idx === want)
                    pick = mine[m]
            if (!pick && mine.length)
                pick = mine[mine.length - 1]

            var lg = (outputs[name] && outputs[name].logical) || {}
            out.push({
                output: String(name),
                logical: lg,
                workspaces: mine,
                ws: pick,
                windows: pick ? (byWs[String(pick.id)] || []) : []
            })
        }
        return out
    }
}
