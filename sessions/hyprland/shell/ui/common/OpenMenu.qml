pragma Singleton

// Which popup list is open right now, so the window it sits in can close it.
//
// ⚠️⚠️ IT EXISTS BECAUSE A POPUP CANNOT SEE THE CLICK THAT SHOULD DISMISS IT.
// `PopupWindow` is its own Wayland surface — that is exactly why it was chosen,
// since no `clip` and no z-order anywhere can reach it — and the price is that a
// click beside it lands in a different surface entirely. Three separate attempts
// tried to detect that from inside the popup, and all three were dead:
//
//   1  `onVisibleChanged` with `visible` bound to the open flag — the handler
//      set the flag that had already been set. Dead by construction.
//   2  reparenting to `Window.contentItem` — a construct used nowhere else in
//      this project, never proven, reported still broken.
//   3  `onActiveFocusChanged` on the sheet, latched by `everFocused`.
//
// ⚠️ THE THIRD WAS MEASURED, not reasoned about, in tools/popup-close-check.qml
// on the lab VM: over a full open-click-away cycle, `activeFocus` on the sheet
// DID NOT CHANGE ONCE. It never becomes true, so the latch never arms and the
// closing branch can never run. Both `closed` and `backingWindowVisible` were
// watched in the same run — `closed` never fired, and `backingWindowVisible`
// only ever followed our own `visible`. There is nothing inside the popup to
// hang this on.
//
// So it is hung outside it. The component that opens a list says so here; the
// window that contains it catches the next press and closes it.
//
// ⚠️ ONE AT A TIME, AND THAT IS NOT A LIMITATION. Two open lists in one window
// is not a state this shell can reach — opening the second one requires a press,
// and that press is the one that closes the first.
//
// ⚠️ WHY A SINGLETON AND NOT A PROPERTY PASSED DOWN. Three components need it
// (Dropdown, FolderPicker, SuggestField) and they sit at different depths inside
// pages that are built by a Loader. Threading an owner reference through that is
// the "same list in two places" fault rule 6 names, one indirection later.
import QtQuick

QtObject {
    id: root

    // The component whose list is up. It must carry a `close()` function; all
    // three callers already had one or now have one.
    property var current: null

    function claim(who) {
        // Opening a second list closes the first. Nothing reaches this today —
        // see the note above — but leaving the old one registered would strand
        // it open with nobody holding the reference.
        if (root.current !== null && root.current !== who)
            root.closeCurrent()
        root.current = who
    }

    // ⚠️ IT ONLY LETS GO IF IT IS STILL THE ONE HOLDING IT. A list that closed
    // after another had already claimed the slot would otherwise clear the new
    // owner, and the catcher would go inert while a list was on screen.
    function release(who) {
        if (root.current === who)
            root.current = null
    }

    // ⚠️ CLEARED BEFORE `close()` IS CALLED. `close()` sets the caller's flag,
    // which runs its own `release()`, which would find the slot already empty —
    // harmless — whereas the other order re-enters this function while it is
    // still holding the reference.
    // ⚠️⚠️ THE TYPING COMES FROM THE WINDOW, and this is the seam. A popup list
    // has no keyboard — deliberately, because a keyboard needs `grabFocus` and a
    // grab is what makes the compositor tear the surface down on a click beside
    // it, which is the whole of B25. Measured on the running shell before any of
    // this was built: a letter typed with a list open arrives at
    // settings/SettingsContent.qml, with `current` already set.
    //
    // ⚠️ ASKED, NOT ASSUMED. Not every list wants forwarded keys —
    // common/SuggestField.qml keeps its own grab and its own search box, so
    // sending it characters as well would type each one twice. A list opts in by
    // having the function; the window asks first.
    function wantsTyping() {
        return root.current !== null && typeof root.current.type === "function"
    }

    function type(t) {
        if (root.wantsTyping())
            root.current.type(t)
    }

    function backspace() {
        if (root.wantsTyping() && typeof root.current.backspace === "function")
            root.current.backspace()
    }

    function closeCurrent() {
        if (root.current === null)
            return
        var who = root.current
        root.current = null
        if (typeof who.close === "function")
            who.close()
    }
}
