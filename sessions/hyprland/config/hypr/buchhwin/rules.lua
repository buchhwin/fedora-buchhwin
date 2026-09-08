-- Window and layer rules.
--
-- The layer rules are the load-bearing half. Every surface the shell draws is a
-- layer-shell surface with a fixed namespace, and without a rule per namespace
-- the blur, the corner radius and the open/close animation are whatever
-- Hyprland's defaults happen to be — which is how a panel ends up with square
-- corners on one machine and rounded ones on another.
--
-- The namespaces are not invented here; they are the `namespace:` values in
-- shell/ui/**. Keep the two in step: a renamed surface silently loses its rule.

local shellSurfaces = {
    "buchhwin-notch",
    "buchhwin-overlay",
    "buchhwin-launcher",
    "buchhwin-toast",
}

for _, ns in ipairs(shellSurfaces) do
    hl.layer_rule({
        name  = "blur-" .. ns,
        match = { namespace = "^" .. ns .. "$" },
        blur        = true,
        blur_popups = true,
        -- ignore_alpha keeps the blur from bleeding through the fully
        -- transparent padding around a panel, which otherwise shows as a
        -- rectangular halo the size of the surface rather than of the panel.
        ignore_alpha = 0.2,
    })
end

-- The wallpaper is drawn by the shell on its own surface. Blurring it would
-- blur the desktop background against itself, and animating it makes the very
-- first frame of a session fade in from grey.
hl.layer_rule({
    name    = "wallpaper-plain",
    match   = { namespace = "^buchhwin-wallpaper$" },
    no_anim = true,
})

-- Input-only surfaces: nothing is drawn, so every effect is wasted work.
for _, ns in ipairs({ "buchhwin-catcher", "buchhwin-hotcorner", "buchhwin-strut", "buchhwin-corner" }) do
    hl.layer_rule({
        name    = "plain-" .. ns,
        match   = { namespace = "^" .. ns .. "$" },
        no_anim = true,
    })
end

-- ---------------------------------------------------------------- windows

-- Ignore maximize requests. Applications that maximize themselves on start
-- fight a tiling layout, and the master layout has no concept of a maximized
-- window to hand them anyway.
hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- XWayland drag-and-drop surfaces arrive with no class and no title. Focusing
-- them steals focus mid-drag and the drop lands nowhere.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- KDE's dialogs are the ones this session actually shows: the polkit prompt,
-- KWallet's unlock, the file chooser from the portal. Tiling a password prompt
-- into the master area is wrong every single time.
hl.window_rule({
    name  = "float-kde-dialogs",
    -- A long-bracket string: Lua does no escape processing inside [[ ]], so the
    -- backslashes reach the regex engine instead of being eaten on the way.
    match = { class = [[^(org\.kde\.polkit-kde-authentication-agent-1|org\.kde\.kwalletd6|xdg-desktop-portal-kde)$]] },
    float = true,
})
