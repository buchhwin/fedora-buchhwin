-- Input.
--
-- The keyboard layout matters more here than it looks. In dwl the layout was a
-- COMPILE-TIME property: changing it meant regenerating config.h and rebuilding
-- the compositor, and the tag keybindings had to spell out German shifted
-- keysyms by hand ("exclam", "quotedbl", "section", …). Hyprland resolves
-- keysyms against the live XKB map, so binds.lua can simply say "SUPER + SHIFT + 1"
-- and it works on any layout. That is why there is no layout branch in binds.lua.

hl.config({
    input = {
        kb_layout  = "de",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",

        -- 1 = focus follows the mouse. On, because the shell's surfaces are
        -- meant to open where the pointer already is.
        follow_mouse = 1,

        repeat_rate  = 40,
        repeat_delay = 300,

        -- 0 = libinput's own acceleration, unmodified. dwl runs the mouse flat
        -- (ACCEL_PROFILE_FLAT); accel_profile below is the equivalent.
        sensitivity   = 0,
        accel_profile = "flat",

        touchpad = {
            natural_scroll          = true,
            tap_to_click            = true,
            tap_and_drag            = true,
            disable_while_typing    = true,
            middle_button_emulation = true,
            clickfinger_behavior    = true,
            scroll_factor           = 1.0,
        },
    },
})

-- ⚠️ NOT `gestures { workspace_swipe = true }`. That key was removed; 0.56 only
-- keeps the workspace_swipe_* tuning options and moves the gesture itself to
-- hl.gesture(). Checked against /usr/share/hypr/stubs/hl.meta.lua, not guessed.
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
