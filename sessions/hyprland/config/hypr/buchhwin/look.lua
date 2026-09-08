-- Layout, borders, gaps, decoration.
--
-- ⚠️ THE LAYOUT IS "master" AND THAT IS NOT A STYLE CHOICE.
-- dwl is a master/stack compositor, and the keybindings in binds.lua are dwl's.
-- Half of them (mfact, addmaster, removemaster, swapwithmaster, orientation)
-- only exist in Hyprland's master layout. Switching this to "dwindle" turns
-- those keys into silent no-ops.

hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 12,
        border_size = 2,
        layout      = "master",

        -- Dragging a border to resize is a mouse habit from stacking desktops
        -- and fights Super+Left/Right, which is how resizing is done here.
        resize_on_border = false,
        allow_tearing    = false,
    },

    master = {
        -- dwl's defaults, kept identical: one window in the master area and a
        -- 55/45 split.
        mfact       = 0.55,
        orientation = "left",

        -- A new window becomes the master, like dwl's zoom-on-spawn feel.
        new_status  = "master",
        new_on_top  = true,
    },

    decoration = {
        rounding         = 12,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.96,

        blur = {
            enabled = true,
            size    = 6,
            passes  = 2,
        },

        shadow = {
            enabled = true,
            range   = 12,
        },
    },

    animations = {
        enabled = true,
    },

    misc = {
        -- No Hyprland mascot wallpaper: the shell draws the wallpaper itself
        -- on its own layer surface, and anything underneath would only show
        -- through for the moment before it appears.
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,

        -- The shell owns the splash and the bar; Hyprland should draw neither.
        disable_splash_rendering = true,
    },
})
