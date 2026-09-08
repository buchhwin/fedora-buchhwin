#!/usr/bin/env bash
#
# The tripwire for motion.
#
# ⚠️ THIS EXISTS BECAUSE TUNING NUMBERS DID NOT WORK TWICE. The animations were
# reported as stuttering, the durations were changed (320 → 200 → 150 ms) and the
# curve was changed (OutExpo → OutCubic), and both times the answer came back:
# still stuttering, on a current AMD laptop APU. A machine like that
# does not struggle to slide a panel. The cost was never in the numbers.
#
# It was this: a `Behavior` on a size that a WAYLAND LAYER SURFACE is sized
# from. Animating that property re-sizes the surface once per frame, and a
# surface re-size is not drawing — it is a `set_size` plus an `ack_configure`
# round trip with niri, a buffer of a new size (so the swapchain is discarded
# every frame), a fresh corner-radius and blur calculation, and a new input
# region. Measured on the VM at 60 Hz, ONE opening of the quick panel:
#
#     before   11 × set_size, 9 × ack_configure     one per frame
#     after     0 × for the notch, 3 × for a page   once per content stage
#
# At 144 Hz the "before" number is about 21 and the "after" number is still 3,
# which is the difference between a cost that scales with the refresh rate and
# one that does not.
#
# ⚠️⚠️ AND AN ANIMATED PROPERTY WAS ONLY HALF OF IT — the other half was
# reported months later as "everything wobbles fast from left to right".        # english-ok: quoted brief
# ShellSurface's width read the CONTENT:
#
#     implicitWidth : max(collapsedWidth, notch.implicitWidth)   ← content
#     island.x      : (parent.width - islandW) / 2               ← window
#
# The island is centred in the window and the window is sized by the content, so
# every content change — the clock, a media title, a timer counting down, an
# icon resolving — re-sized the surface AND slid the island sideways to stay
# centred in it. Nothing here was animated, so check 1 stayed green through all
# of it. Same consequence, different sentence: a Wayland surface re-sized out
# from under a running animation.
#
# So there are three checks here, and the first two are the important ones:
#
#   1. HARD — a PanelWindow's implicit size may not be bound to a property that
#      something animates. This is the fault that cost two rounds.
#   1b HARD — nor to a CHILD's implicit size, which is the same thing arriving
#      from the other direction.
#   2. SOFT — a `Behavior` on any layout size has to say why. Some are correct
#      (a level bar's fill really is a width; a card that folds really does
#      change height). Each one states its reason at the site, so the next
#      person meets the argument rather than the pattern.
#
# An exception is written on the line or the line above it:
#
#     Behavior on width { ... }        // motion-ok: a fill level, not a layout
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
report() { printf '  \033[38;5;203m%s\033[0m  %s\n' "$1" "$2"; fail=1; }
note()   { printf '  \033[38;5;245m%s\033[0m  %s\n' "$1" "$2"; }

layout_props='width|height|implicitWidth|implicitHeight|Layout\.[A-Za-z]+'

# ⚠️⚠️ QML HAS TWO WAYS TO ANIMATE A PROPERTY AND THIS FILE ONLY KNEW ONE.
# `Behavior on implicitHeight { NumberAnimation {} }` and
# `NumberAnimation on implicitHeight {}` do the same thing; every expression
# here matched the word `Behavior`, so the second form walked past all three
# hard rules. The brace is allowed to be on the next line for the same reason —
# a checker that depends on where somebody put a `{` is a formatting rule
# wearing a correctness rule's clothes.
anim_on='(Behavior|NumberAnimation|SmoothedAnimation|SpringAnimation|PropertyAnimation|ColorAnimation) on'

# ⚠️⚠️ A BINDING CAN BE TWO LINES LONG, and reading line by line is the blind
# spot this project has now found in four suites — including this one, where
# rule 4 further down says so in its own comment and rules 1, 1b and 3 above it
# were never brought up to it. `implicitWidth: Math.max(collapsedWidth,` with
# `notch.implicitWidth)` underneath it was invisible to every one of them.
#
# ⚠️ IT JOINS ONLY WHILE THE EXPRESSION IS UNFINISHED — unbalanced brackets, or
# a trailing operator. Swallowing a fixed number of following lines would make
# rule 1 match an animated name on an unrelated line below, and a checker that
# reads the wrong place invents work, which this project holds to be worse than
# one that misses something.
#
# Emits `lineno:joined text`, so every caller keeps the real line number.
logical_lines() {
    awk -v pat="$2" '
        function occurrences(t, ch,   tmp) { tmp = t; return gsub(ch, ch, tmp) }
        function unfinished(t,   tail) {
            if (occurrences(t, "\\(") > occurrences(t, "\\)")) return 1
            if (occurrences(t, "\\[") > occurrences(t, "\\]")) return 1
            tail = t
            sub(/[[:space:]]*(\/\/.*)?$/, "", tail)
            if (tail ~ /(\|\||&&)$/) return 1
            if (tail ~ /[-+*\/,?:]$/) return 1
            return 0
        }
        { line[NR] = $0 }
        END {
            for (i = 1; i <= NR; i++) {
                if (line[i] !~ pat) continue
                s = line[i]
                for (j = i + 1; j <= NR && j <= i + 4 && unfinished(s); j++)
                    s = s " " line[j]
                print i ":" s
            }
        }
    ' "$1"
}

# ---------------------------------------------------------------------- hard
# A PanelWindow sizes a Wayland layer surface. If its implicit size reads a
# property that is animated somewhere in the same file, every frame of that
# animation is a round trip with the compositor.
while IFS= read -r file; do
    grep -q 'PanelWindow' "$file" || continue

    # Every property this file animates, in either of QML's two forms.
    animated=$(grep -oE "^[[:space:]]*${anim_on} [A-Za-z_][A-Za-z0-9_]*" "$file" \
               | awk '{print $3}' | sort -u)
    [[ -z "$animated" ]] && continue

    while IFS= read -r hit; do
        line=${hit%%:*}
        text=${hit#*:}
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"motion-ok"* ]] && continue

        # ⚠️ ONLY THE RIGHT-HAND SIDE. The first version of this matched the
        # whole line, so `implicitWidth: …` matched the animated property
        # `implicitWidth` by its own DECLARATION and reported every such line
        # whether or not it referenced anything animated. It happened to be red
        # on the real bug, which is exactly how a broken check survives — and it
        # missed ShellSurface.qml completely, where the reference is
        # `root.islandW` and the declaration is `implicitWidth`.
        rhs=${text#*:}

        for prop in $animated; do
            # `islandW`, `root.islandW` and `card.implicitWidth` all count;
            # `islandWidth` does not, which is why the boundary is spelled out.
            if grep -qE "(^|[^A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*\.)?${prop}([^A-Za-z0-9_]|\$)" <<< "$rhs"; then
                report "surface  $file:$line" \
                       "implicit size follows the animated '$prop'"
            fi
        done
    done < <(logical_lines "$file" '^[[:space:]]*implicit(Width|Height)[[:space:]]*:')

    # ── 1b · …and it may not follow a CHILD either ──────────────────────────
    #
    # `implicitWidth: Math.max(1, card.implicitWidth)` is a surface that grows
    # and shrinks with whatever it happens to contain. Legitimate for an ordinary
    # Item, wrong for a layer surface: the compositor is told a new size every
    # time the content changes, and anything positioned from the window's own
    # width — a centred child most of all — slides with it. That is the "wobbles
    # from left to right" fault, and check 1 stayed green through all of it
    # because nothing involved was animated.
    #
    # ⚠️ EXACTLY FOUR SPACES **AND THE ROOT MUST BE THE WINDOW**, which took two
    # tries. Four spaces alone matched fifteen perfectly correct lines — an Item
    # measuring its child is what Items are for — and it also fired on
    # Dropdown.qml, whose root is an `Item` with a PopupWindow inside it. Both
    # halves are needed: the indentation says "this is the root object's own
    # property" and the root type says "and that object is a layer surface".
    #
    # A surface sized from CONFIG or from a constant is untouched — that is what
    # a fixed surface reads. An exception says why on the line.
    if grep -qE '^PanelWindow[[:space:]]*\{' "$file"; then
        while IFS= read -r hit; do
            ln=${hit%%:*}
            text=${hit#*:}
            [[ "$text" == *"motion-ok"* ]] && continue
            rhs=${text#*:}
            if grep -qE '[A-Za-z_][A-Za-z0-9_]*\.implicit(Width|Height)' <<< "$rhs"; then
                report "surface  $file:$ln" \
                       "surface size follows a child's implicit size"
            fi
        done < <(logical_lines "$file" '^    implicit(Width|Height)[[:space:]]*:')
    fi

    # ⚠️ AND THE POSITION COUNTS TOO. A layer surface is re-configured when it
    # MOVES, not only when it re-sizes — `Behavior on margins.top` in
    # ToastWindow.qml is the same protocol cost by a different property, and the
    # first version of this check walked straight past it. Anything animating a
    # window margin has to say why.
    while IFS=: read -r line text; do
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"motion-ok"* ]] && continue
        found=0
        n=$((line - 1))
        while (( n > 0 )); do
            prev=$(sed -n "${n}p" "$file")
            trimmed=${prev#"${prev%%[![:space:]]*}"}
            [[ "$trimmed" == //* ]] || break
            if [[ "$prev" == *"motion-ok"* ]]; then found=1; break; fi
            n=$((n - 1))
        done
        (( found )) && continue
        report "surface  $file:$line" "a window margin is animated"
    done < <(grep -nE "^[[:space:]]*${anim_on} margins\." "$file" 2>/dev/null)
done < <(find shell -name '*.qml' -type f | sort)

# ---------------------------------------------------------------------- hard
# ⚠️ NOTHING ANIMATES AN `implicit` SIZE. EVER. NO EXCEPTION, so this one takes
# no `motion-ok:`.
#
# `implicitWidth`/`implicitHeight` mean "the size this content wants". Putting a
# Behavior on one animates the CONTENT ARRIVING, which is never a gesture
# anybody made, and there is no case where it is what you meant — if a fold or a
# fill really should move, animate a proxy (a 0..1 `fold`, a scale, an explicit
# `height`) and let the implicit size land in one frame.
#
# This is the third face of the same fault and the first two are above:
#
#   1. a Behavior on a size a layer surface is sized from   → protocol per frame
#   2. a surface sized from its own content                 → the notch sliding
#   3. a Behavior on an implicit size                       → THIS
#
# It shipped as "manchmal wird auf einmal alles größer und dann sofort wieder   # english-ok: the report, quoted
# kleiner": SettingGroup animated the card's implicitHeight, gated on one
# laid-out frame. That gate was right about the build and wrong about everything
# after it — the suggestion lists added on 08.08. arrive from a process about
# 100 ms later, so the card was "settled" by the time the pills appeared, and
# their height was animated in, then animated back out when a list got shorter.
# Before those lists the same rows were text fields of a fixed height, so the
# flaw existed and could not be seen.
#
# ⚠️ The `motion-ok:` escape hatch is deliberately NOT honoured here. The one
# place that had a well-argued reason is the place that shipped the bug.
while IFS= read -r file; do
    while IFS=: read -r line text; do
        [[ -z "${line:-}" ]] && continue
        report "implicit $file:$line" \
               "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-60)"
    done < <(grep -nE "^[[:space:]]*${anim_on} implicit(Width|Height)[[:space:]]*(\{|\$)" \
                  "$file" 2>/dev/null)
done < <(find shell -name '*.qml' -type f | sort)

# ---------------------------------------------------------------------- soft
# Every Behavior on a layout size states its reason, or it is a finding.
while IFS= read -r file; do
    while IFS=: read -r line text; do
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"motion-ok"* ]] && continue

        # ⚠️ THE WHOLE COMMENT BLOCK ABOVE, not just one line. The reasons in
        # this project are paragraphs — the first version of this check only
        # looked one line up, so every reason that took more than a sentence was
        # invisible to it and five correctly-argued exceptions stayed red.
        # Walking up while the lines are comments stops at the first real line,
        # so a reason cannot be borrowed from an unrelated block further away.
        found=0
        n=$((line - 1))
        while (( n > 0 )); do
            prev=$(sed -n "${n}p" "$file")
            trimmed=${prev#"${prev%%[![:space:]]*}"}
            [[ "$trimmed" == //* ]] || break
            if [[ "$prev" == *"motion-ok"* ]]; then found=1; break; fi
            n=$((n - 1))
        done
        (( found )) && continue
        report "layout   $file:$line" \
               "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-60)"
    done < <(grep -nE "^[[:space:]]*${anim_on} (${layout_props})[[:space:]]*(\{|\$)" "$file" 2>/dev/null)
done < <(find shell/ui -name '*.qml' -type f | sort)

if (( fail )); then
    cat <<'EOF'

  A size that decides a layer surface, or a layout, is being animated.

  Animating a PanelWindow's implicit size re-sizes a Wayland surface once per
  frame — protocol traffic, not drawing, and no duration or easing curve can
  make it cheap. Set the size and animate `scale`, `opacity` or `x`/`y`
  instead: those are GPU transforms the compositor never hears about.

  If the motion genuinely is a size — a fill level, a card that folds — say so:

      Behavior on width { ... }   // motion-ok: the fill of a level bar

  An `implicit` finding takes no such note, on purpose. An implicit size IS
  "what the content wants", so animating one animates the content ARRIVING —
  which is never a gesture anybody made. Animate a proxy instead and let the
  implicit size land in one frame:

      property real fold: collapsed ? 0 : 1
      implicitHeight: Math.round(full * fold)
      Behavior on fold { NumberAnimation { ... } }

EOF
    exit 1
fi

note "motion" "no layer surface follows an animated size"
echo "  every animated layout size states its reason"

# --------------------------------------------- 4. a size that arrives a frame late
#
# ⚠️ THE THREE RULES ABOVE ALL ASK ABOUT ANIMATION, AND THIS SHAPE HAS NONE.
# A group whose `visible` depends on a property that is ASSIGNED IN A HANDLER
# rather than bound appears one frame after the page around it has been laid
# out — so the column grows under the cursor with no Behavior anywhere in sight.
# motion.sh stayed green through it, three times, and two of the three "fixes"
# were guesses.
#
# The settings window's reset group was the last one: `visible: … &&
# currentKeys.length > 0`, with currentKeys filled in `Loader.onLoaded`.
#
# ⚠️ NARROW ON PURPOSE. It only looks at names this file itself assigns inside
# an `on…:` handler, so a property that is genuinely bound — and therefore has
# its value from the first frame — is not flagged.
late=0
while IFS= read -r f; do
    # ⚠️ ONLY LIFECYCLE HANDLERS. A property set by a CLICK is a gesture, and a
    # gesture is allowed to change a height — that is the whole point of one.
    # The fault is a property set while the thing is being BUILT, because then
    # the first frame is drawn without it and the second one is taller.
    # The first version of this check skipped any name that was also declared as
    # a property, and `property var currentKeys: []` is exactly that — so it sat
    # green over the very line it was written for. Found by running the red
    # probe, not by reading it back.
    assigned="$(awk '
        /^[[:space:]]*(on(Loaded|Completed|StatusChanged|CurrentIdChanged|SourceChanged)|Component\.onCompleted)[[:space:]]*:/ { win = 10 }
        win > 0 {
            if (match($0, /root\.[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=[^=]/)) {
                t = substr($0, RSTART + 5)
                sub(/[^a-zA-Z0-9_].*/, "", t)
                print t
            }
            win--
        }' "$f" | sort -u)"
    [[ -z "$assigned" ]] && continue
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        # ⚠️ A BINDING CAN BE TWO LINES LONG, and reading line by line is the
        # exact blind spot this project has already found in three other suites
        # — including this one. The first version of this rule grepped single
        # lines, and the red probe it was written for is written as
        #     visible: pageLoader.status === Loader.Ready
        #              && root.currentKeys.length > 0
        # so it sat green over its own reason for existing. Found by running the
        # probe, not by reading the code back.
        hits="$(awk -v n="$name" '
            /^[[:space:]]*visible:/ { buf = $0; ln = NR; cont = 3; next }
            cont > 0 { buf = buf " " $0; cont-- }
            buf != "" && (cont == 0 || /^[[:space:]]*visible:/) {
                if (buf ~ ("[^a-zA-Z0-9_]" n "([^a-zA-Z0-9_]|$)")) print ln ":" buf
                buf = ""
            }' "$f")"
        [[ -z "$hits" ]] && continue
        report "late" "$(basename "$f"): visible: waits for '$name', set while the page is being built"
        sed 's/^/        /' <<< "$hits"
        late=1
    done <<< "$assigned"
# ⚠️ SETTINGS ONLY, AND THAT IS A MEASURED NARROWING RATHER THAN A RETREAT.
# Over all of shell/ui it flagged LockFace, where `visible: root.status.length`
# shows an authentication message — a response to something you typed, which is
# a gesture and is allowed to change a height. The fault shape needs a container
# whose CONTENTS are swapped by a Loader while the frame around them is already
# laid out, and in this tree that is the settings window.
done < <(find shell/ui/settings -name '*.qml')

if [[ $late -eq 1 ]]; then
    cat <<'EOF'

  A `visible` that waits for a handler is a height that arrives late. The page
  is measured, drawn, and THEN grows — which looks exactly like a glitch and has
  no Behavior for the other three rules to find.

  Either bind the property so it is right in the first frame, or leave the
  control visible and switch off what it can do:

      visible: pageLoader.status === Loader.Ready
      ActionRow { usable: root.currentKeys.length > 0 }

EOF
    exit 1
fi
echo "  nothing visible waits for a handler"
