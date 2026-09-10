-- Buchhwin Hyprland session — entry point.
--
-- This file deliberately contains no settings. It only wires modules together,
-- because the order in which they load IS the precedence: a later hl.config()
-- overrides an earlier one, so "who wins" has to be readable at a glance.
--
--   buchhwin/*    shipped by the repository, edited by hand
--   generated/*   written by the shell from shell.json — never edit by hand
--   overrides.lua yours; created empty once and never overwritten
--
-- Hyprland's own example config says it outright: "You can (and should!!) split
-- this configuration into multiple files". require() is that mechanism.

-- ⚠️ package.path FIRST, OR EVERY require() BELOW FAILS.
-- Hyprland loads this file through --config with an absolute path, and Lua's
-- default search path has no idea where that was. debug.getinfo gives us the
-- directory of *this* file, which is the one thing that is always right —
-- XDG_CONFIG_HOME would be a second source of truth that can disagree.
local here = debug.getinfo(1, "S").source:match("^@(.*)/") or "."
package.path = here .. "/?.lua;" .. here .. "/?/init.lua;" .. package.path

-- Existence is checked before require() rather than wrapping it in pcall.
-- pcall(require, …) cannot tell "the file is not there yet" from "the file is
-- there and has a syntax error", and silently skipping a broken generated
-- config is exactly how a desktop ends up with no keybindings and no clue why.
local function present(relative)
    local handle = io.open(here .. "/" .. relative, "r")
    if not handle then return false end
    handle:close()
    return true
end

require("buchhwin.env")
require("buchhwin.monitors")
require("buchhwin.input")
require("buchhwin.look")
require("buchhwin.rules")

-- Generated values come after the hand-written defaults so a setting changed in
-- the shell wins over the shipped default without either file knowing about the
-- other. A fresh checkout has none of these and must still start.
-- ⚠️ THE ELSE BRANCH IS THE CURSOR, AND IT IS NOT DECORATION. The pointer's
-- theme and size are settings in shell.json, so the generator writes them —
-- but the FIRST login happens before any generator has run: the installer
-- renders the colour files and never the compositor's settings, which is why
-- the shipped buchhwin/binds.lua exists for the same moment. A session with no
-- XCURSOR_THEME at all gets Hyprland's own pointer at its own size, and this
-- project already has that report in writing: "the cursor is far too big".
--
-- The two values here are the schema's own defaults. They are HERE rather than
-- in buchhwin/env.lua so that exactly one writer runs: with a generated file,
-- the generator's; without one, these. Nothing rests on which of two hl.env
-- calls for the same variable would win, which is not something this project
-- has been able to measure.
if present("generated/settings.lua") then
    require("generated.settings")
else
    hl.env("XCURSOR_THEME", "breeze_cursors")
    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_SIZE", "24")
end

-- Keys: exactly one source at a time. The generator writes the COMPLETE set
-- (defaults with the user's rebinds already resolved), so when it exists the
-- shipped defaults must not also run — two binds on one key is a conflict
-- Hyprland resolves by silently keeping one of them.
if present("generated/binds.lua") then
    require("generated.binds")
else
    require("buchhwin.binds")
end

if present("generated/colors.lua") then require("generated.colors") end

-- Autostart last: it only registers a hyprland.start hook, but keeping it at
-- the end means nothing it launches can race a config value that is still
-- being assigned above.
require("buchhwin.autostart")

-- Yours. Machine-specific monitors, extra rules, personal binds — none of it
-- leaks into the Plasma session and none of it is touched by an update.
if present("overrides.lua") then require("overrides") end
