pragma Singleton

// Where a workspace's windows sit inside a thumbnail box, as shares of it.
//
// It lives here rather than on a page because TWO surfaces draw the same
// picture now: `Mod+Tab` shows one column per workspace of this monitor (B32),
// and `Shift+Alt+Tab` shows one column per MONITOR (B33). Rule 6 — a list may
// not exist twice — and a copy would have been worse than usual here, because
// the arithmetic is measured against the compositor's real numbers and a copy would
// drift away from those measurements silently.
//
// It is a function rather than a pile of bindings for a reason this project has
// paid for: the geometry used to be spread across four expressions inside a
// Repeater delegate, where nothing could read it without a pointer and a
// screenshot. `tests/workspaces.sh` calls it directly, so the arithmetic is
// checkable on a machine with one screen and no session.
//
// ⚠️ THIS WAS REBUILT FOR HYPRLAND, AND IT GOT SIMPLER RATHER THAN HARDER.
//
// The previous version reconstructed the picture from the previous compositor's scrolling layout:
// `pos_in_scrolling_layout` gave a [column, row] and `tile_size` gave a size,
// and the columns were stacked left to right to work out where things were. It
// had to, because the previous compositor never reported a window's actual position — a workspace
// there is legitimately wider than its screen, so there is no single frame to
// give coordinates in.
//
// Hyprland reports the real rectangle. `hyprctl -j clients` gives every window
// an `at` [x, y] and a `size` [w, h] in layout pixels, so the thumbnail is a
// scale of what is on screen instead of a reconstruction of it. Floating
// windows, overlapping windows and anything a layout plugin does all come out
// right for free, because none of it is being inferred any more.
//
// ⚠️ WHAT CARRIED OVER, because it was measured rather than assumed: a window
// does not fill its slot. On a 1280-wide screen a single window measured 1232
// wide with about 24 px of wallpaper showing on each side — the gaps. Those
// come through in `at`/`size` on their own now, which is why there is no
// centring step here any more. It was compensating for information the previous compositor did
// not provide.

import QtQuick

QtObject {
    id: root

    // Returns [{ win, x, y, w, h }] with x/y/w/h as shares 0..1 of the box.
    //
    // outX/outY are the monitor's origin in the global layout. They matter as
    // soon as there is a second screen: a window on the right-hand monitor has
    // an `at` in the thousands, and without the origin every one of them would
    // be drawn off the edge of its own thumbnail. They default to 0 so a
    // single-screen caller — and every test — can leave them out.
    function layoutWindows(wins, outW, outH, outX, outY) {
        var out = []
        if (!wins || !wins.length)
            return out

        var originX = Number(outX || 0)
        var originY = Number(outY || 0)

        var boxes = []
        var maxX = 0, maxY = 0
        for (var i = 0; i < wins.length; i++) {
            var w = wins[i]
            var at = w.at || [0, 0]
            var size = w.size || [0, 0]
            var b = {
                win: w,
                x: Number(at[0] || 0) - originX,
                y: Number(at[1] || 0) - originY,
                w: Number(size[0] || 0),
                h: Number(size[1] || 0)
            }
            // A window with no geometry yet — mapped this frame, or a client
            // that has not been given a size — must not collapse the whole
            // picture to a division by zero. It is skipped instead: an absent
            // rectangle is more honest than one at the origin with no size.
            if (b.w <= 0 || b.h <= 0)
                continue
            boxes.push(b)
            if (b.x + b.w > maxX) maxX = b.x + b.w
            if (b.y + b.h > maxY) maxY = b.y + b.h
        }
        if (!boxes.length)
            return out

        // ⚠️ THE DENOMINATOR IS THE LARGER OF SCREEN AND CONTENT, and that one
        // choice is what keeps a thumbnail readable. A workspace that fits its
        // screen is drawn against the screen, so a half-width window still
        // looks half-width. Anything reaching past the edge — a plugin layout,
        // a window dragged partly off — is drawn against its own extent, so it
        // fits the box complete: smaller, but nothing clipped and the windows
        // still comparable to each other.
        var spanW = Math.max(Number(outW) || 0, maxX, 1)
        var spanH = Math.max(Number(outH) || 0, maxY, 1)

        for (var j = 0; j < boxes.length; j++) {
            var e = boxes[j]
            out.push({
                win: e.win,
                x: e.x / spanW,
                y: e.y / spanH,
                w: e.w / spanW,
                h: e.h / spanH
            })
        }
        return out
    }

    // ⚠️ B33 · WHICH WORKSPACE EACH MONITOR COLUMN SHOWS, as a pure function so
    // it can be checked headless — the same reason `layoutWindows` is one.
    //
    // `outputs` is the compositor map (connector name → output), `workspaces` its list.
    // `wanted` is the index every column starts on: his instruction is that the
    // menu opens with the workspace he is standing on, on EVERY monitor —
    // "aber auf allen monitoren wird der aktuelle workspace genommen".          // english-ok: the request, quoted
    //
    // ⚠️ INDICES COUNT PER OUTPUT. Measured on the lab VM with two heads: idx=1
    // exists on Virtual-1 AND on Virtual-2. So a column picks the workspace with
    // that index ON ITS OWN MONITOR, and a global sort by idx — which is what
    // a global sort by idx gives — mixes the two together.
    //
    // ⚠️ A monitor may simply not have that index. The compositor creates workspaces on
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
