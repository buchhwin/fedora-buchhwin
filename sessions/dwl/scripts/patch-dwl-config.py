#!/usr/bin/env python3
"""Patch an upstream dwl 0.8 config.h for the buchhwin desktop."""
from __future__ import annotations
import os
import json
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-dwl-config.py /path/to/dwl/config.h")

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
keyboard_layout = os.environ.get("BUCHHWIN_KEYBOARD_LAYOUT", "de").strip() or "de"
appearance_file = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "buchhwin-dwl" / "appearance.json"
appearance = {"border": 1, "gaps": 8}
if appearance_file.exists():
    try:
        appearance.update(json.loads(appearance_file.read_text(encoding="utf-8")))
    except (OSError, ValueError):
        pass
border_px = max(0, min(8, int(appearance["border"])))
gap_px = max(0, min(40, int(appearance["gaps"])))


def replace_once(pattern: str, replacement: str, label: str) -> None:
    global text
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.M)
    if count != 1:
        raise SystemExit(f"patch failed for {label}: expected one match, got {count}")


replace_once(r"^static const unsigned int borderpx\s*=\s*\d+;.*$",
             f"static const unsigned int borderpx = {border_px}; /* border pixel of windows */\nstatic const unsigned int gappx = {gap_px}; /* gap between tiled windows */",
             "border width")
replace_once(r"^static const float bordercolor\[\]\s*=\s*COLOR\([^)]+\);",
             "static const float bordercolor[] = COLOR(0x3f3f3fff);", "border color")
replace_once(r"^static const float focuscolor\[\]\s*=\s*COLOR\([^)]+\);",
             "static const float focuscolor[] = COLOR(0x9ca3afff);", "focus color")
replace_once(r"^static const float urgentcolor\[\]\s*=\s*COLOR\([^)]+\);",
             "static const float urgentcolor[] = COLOR(0xf38ba8ff);", "urgent color")

fullscreen_anchor = re.search(r"^static const float fullscreen_bg\[\].*$", text, flags=re.M)
if not fullscreen_anchor:
    raise SystemExit("patch failed for SceneFX settings: fullscreen background missing")
scenefx_settings = '''

static const int opacity = 0;
static const float opacity_inactive = 1.0;
static const float opacity_active = 1.0;
static const int shadow = 0;
static const int shadow_only_floating = 1;
static const float shadow_color[4] = COLOR(0x00000080);
static const float shadow_color_focus[4] = COLOR(0x000000a0);
static const int shadow_blur_sigma = 16;
static const int shadow_blur_sigma_focus = 20;
static const char *const shadow_ignore_list[] = { NULL };
static const int corner_radius = 0;
static const int corner_radius_inner = 0;
static const int corner_radius_only_floating = 1;
static const int blur = 1;
static const int blur_xray = 0;
static const int blur_ignore_transparent = 1;
static const struct blur_data blur_data = {
    .radius = 7,
    .num_passes = 3,
    .noise = (float)0.01,
    .brightness = (float)0.95,
    .contrast = (float)0.95,
    .saturation = (float)1.05,
};'''
text = text[:fullscreen_anchor.end()] + scenefx_settings + text[fullscreen_anchor.end():]
replace_once(r"^#define MODKEY\s+\S+", "#define MODKEY WLR_MODIFIER_LOGO", "MODKEY")
replace_once(
    r"^static const enum libinput_config_accel_profile accel_profile\s*=\s*[^;]+;",
    "static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT;",
    "flat pointer acceleration profile",
)
if re.search(r"^static const int natural_scrolling\s*=", text, flags=re.M):
    replace_once(r"^static const int natural_scrolling\s*=\s*\d+;",
                 "static const int natural_scrolling = 1;",
                 "natural scrolling")

replace_once(
    r"^static const MonitorRule monrules\[\] = \{[\s\S]*?^\};",
    '''static const MonitorRule monrules[] = {
    /* Portable default. Per-machine layout and scaling are applied at login
     * from ~/.config/buchhwin-dwl/display-profile.json. */
    { NULL, 0.55f, 1, 1.0f, &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, -1, -1 },
};''',
    "monitor layout",
)

# Add a top/bottom layout. With two windows this produces two full-width rows;
# Super+Up/Down selects it and moves their horizontal divider.
layouts_start = text.find("static const Layout layouts[] = {")
layouts_end = text.find("\n};", layouts_start)
if layouts_start < 0 or layouts_end < 0:
    raise SystemExit("could not find layouts[]")
layouts_block = text[layouts_start:layouts_end]
if "bstack" not in layouts_block:
    layouts_block += '\n    { "TTT",      bstack },'
    text = text[:layouts_start] + layouts_block + text[layouts_end:]

# Set the configured XKB layout when the upstream config leaves it unset.
xkb_start = text.find("static const struct xkb_rule_names xkb_rules = {")
if xkb_start >= 0:
    xkb_end = text.find("};", xkb_start)
    block = text[xkb_start:xkb_end]
    if re.search(r"\.layout\s*=", block):
        block = re.sub(r"\.layout\s*=\s*[^,]+,", f'.layout = "{keyboard_layout}",', block, count=1)
    else:
        block = block.replace("{", f'{{\n    .layout = "{keyboard_layout}",', 1)
    text = text[:xkb_start] + block + text[xkb_end:]

replace_once(r'^static const char \*termcmd\[\]\s*=\s*\{[^;]*\};',
             'static const char *termcmd[] = { "buchhwin-terminal", NULL };', "terminal")
replace_once(r'^static const char \*menucmd\[\]\s*=\s*\{[^;]*\};',
             'static const char *menucmd[] = { "buchhwin-launcher", NULL };', "launcher")

anchor = 'static const char *menucmd[] = { "buchhwin-launcher", NULL };'
commands = anchor + '''
static const char *browsercmd[]       = { "buchhwin-browser", NULL };
static const char *filescmd[]         = { "dolphin", NULL };
static const char *controlcmd[]       = { "buchhwin-control-center", NULL };
static const char *codecmd[]          = { "buchhwin-code", NULL };
static const char *notificationscmd[] = { "buchhwin-notifications", NULL };
static const char *powercmd[]         = { "buchhwin-power-menu", NULL };
static const char *keybindscmd[]      = { "buchhwin-keybinds", NULL };
static const char *clipboardcmd[]     = { "buchhwin-clipboard", "toggle", NULL };
static const char *settingscmd[]      = { "buchhwin-settings", NULL };
static const char *lockcmd[]          = { "swaylock", "-f", "-c", "181818", NULL };
static const char *shotcmd[]          = { "buchhwin-screenshot", "region", NULL };
static const char *shotfullcmd[]      = { "buchhwin-screenshot", "full", NULL };
static const char *shoteditcmd[]      = { "buchhwin-screenshot", "edit", NULL };'''
if anchor not in text:
    raise SystemExit("could not insert helper commands")
text = text.replace(anchor, commands, 1)

start = text.find("static const Key keys[] = {")
if start < 0:
    raise SystemExit("could not find keys[]")
end = text.find("\n};", start)
if end < 0:
    raise SystemExit("could not find end of keys[]")
end += 3

if keyboard_layout.lower().startswith("de"):
    tagkeys = """TAGKEYS(                             XKB_KEY_1, XKB_KEY_exclam,                        0),
    TAGKEYS(                             XKB_KEY_2, XKB_KEY_quotedbl,                      1),
    TAGKEYS(                             XKB_KEY_3, XKB_KEY_section,                       2),
    TAGKEYS(                             XKB_KEY_4, XKB_KEY_dollar,                        3),
    TAGKEYS(                             XKB_KEY_5, XKB_KEY_percent,                       4),
    TAGKEYS(                             XKB_KEY_6, XKB_KEY_ampersand,                     5),
    TAGKEYS(                             XKB_KEY_7, XKB_KEY_slash,                         6),
    TAGKEYS(                             XKB_KEY_8, XKB_KEY_parenleft,                     7),
    TAGKEYS(                             XKB_KEY_9, XKB_KEY_parenright,                    8),"""
else:
    tagkeys = """TAGKEYS(                             XKB_KEY_1, XKB_KEY_exclam,                        0),
    TAGKEYS(                             XKB_KEY_2, XKB_KEY_at,                            1),
    TAGKEYS(                             XKB_KEY_3, XKB_KEY_numbersign,                    2),
    TAGKEYS(                             XKB_KEY_4, XKB_KEY_dollar,                        3),
    TAGKEYS(                             XKB_KEY_5, XKB_KEY_percent,                       4),
    TAGKEYS(                             XKB_KEY_6, XKB_KEY_asciicircum,                   5),
    TAGKEYS(                             XKB_KEY_7, XKB_KEY_ampersand,                     6),
    TAGKEYS(                             XKB_KEY_8, XKB_KEY_asterisk,                      7),
    TAGKEYS(                             XKB_KEY_9, XKB_KEY_parenleft,                     8),"""

if keyboard_layout.lower().startswith("de"):
    shift_zero = "XKB_KEY_equal"
    shift_comma = "XKB_KEY_semicolon"
    shift_period = "XKB_KEY_colon"
else:
    shift_zero = "XKB_KEY_parenright"
    shift_comma = "XKB_KEY_less"
    shift_period = "XKB_KEY_greater"

keys = r'''static const Key keys[] = {
    /* modifier                         key                            function          argument */
    { MODKEY,                           XKB_KEY_Return,                 spawn,            {.v = termcmd} },
    { MODKEY,                           XKB_KEY_d,                      spawn,            {.v = menucmd} },
    { MODKEY,                           XKB_KEY_b,                      spawn,            {.v = browsercmd} },
    { MODKEY,                           XKB_KEY_e,                      spawn,            {.v = filescmd} },
    { MODKEY,                           XKB_KEY_c,                      spawn,            {.v = codecmd} },
    { MODKEY|WLR_MODIFIER_SHIFT,        XKB_KEY_C,                      spawn,            {.v = controlcmd} },
    { MODKEY,                           XKB_KEY_n,                      spawn,            {.v = notificationscmd} },
    { MODKEY,                           XKB_KEY_m,                      spawn,            {.v = powercmd} },
    { MODKEY,                           XKB_KEY_l,                      spawn,            {.v = lockcmd} },
    { MODKEY,                           XKB_KEY_F1,                     spawn,            {.v = keybindscmd} },
    { MODKEY,                           XKB_KEY_v,                      spawn,            {.v = clipboardcmd} },
    { MODKEY,                           XKB_KEY_s,                      spawn,            {.v = shotcmd} },
    { MODKEY|WLR_MODIFIER_SHIFT,        XKB_KEY_S,                      spawn,            {.v = settingscmd} },

    { MODKEY,                           XKB_KEY_j,                      focusstack,       {.i = +1} },
    { MODKEY,                           XKB_KEY_k,                      focusstack,       {.i = -1} },
    { MODKEY,                           XKB_KEY_i,                      incnmaster,       {.i = +1} },
    { MODKEY|WLR_MODIFIER_SHIFT,        XKB_KEY_I,                      incnmaster,       {.i = -1} },
    { MODKEY,                           XKB_KEY_Left,                   setmfact,         {.f = -0.05f} },
    { MODKEY,                           XKB_KEY_Right,                  setmfact,         {.f = +0.05f} },
    { MODKEY,                           XKB_KEY_Up,                     sethorizontalmfact,{.f = -0.05f} },
    { MODKEY,                           XKB_KEY_Down,                   sethorizontalmfact,{.f = +0.05f} },
    { MODKEY|WLR_MODIFIER_SHIFT,        XKB_KEY_Return,                 zoom,             {0} },
    { MODKEY,                           XKB_KEY_q,                      killclient,       {0} },
    { MODKEY,                           XKB_KEY_Tab,                    view,             {0} },

    { MODKEY,                           XKB_KEY_t,                      setlayout,        {.v = &layouts[0]} },
    { MODKEY,                           XKB_KEY_f,                      setlayout,        {.v = &layouts[1]} },
    { MODKEY|WLR_MODIFIER_SHIFT,        XKB_KEY_M,                      setlayout,        {.v = &layouts[2]} },
    { MODKEY,                           XKB_KEY_space,                  setlayout,        {0} },
    { MODKEY|WLR_MODIFIER_ALT,          XKB_KEY_space,                  togglelayoutorientation, {0} },
    { MODKEY|WLR_MODIFIER_SHIFT,        XKB_KEY_space,                  togglefloating,  {0} },
    { MODKEY|WLR_MODIFIER_SHIFT,        XKB_KEY_F,                      togglefullscreen, {0} },

    { MODKEY,                           XKB_KEY_0,                      view,             {.ui = ~0} },
    { MODKEY|WLR_MODIFIER_SHIFT,        __SHIFTZERO__,                  tag,              {.ui = ~0} },
    { MODKEY,                           XKB_KEY_comma,                  focusmon,         {.i = WLR_DIRECTION_LEFT} },
    { MODKEY,                           XKB_KEY_period,                 focusmon,         {.i = WLR_DIRECTION_RIGHT} },
    { MODKEY|WLR_MODIFIER_SHIFT,        __SHIFTCOMMA__,                 tagmon,           {.i = WLR_DIRECTION_LEFT} },
    { MODKEY|WLR_MODIFIER_SHIFT,        __SHIFTPERIOD__,                tagmon,           {.i = WLR_DIRECTION_RIGHT} },

    __TAGKEYS__

    { MODKEY,                           XKB_KEY_Print,                  spawn,            {.v = shotcmd} },
    { MODKEY|WLR_MODIFIER_SHIFT,        XKB_KEY_Print,                  spawn,            {.v = shotfullcmd} },
    { MODKEY|WLR_MODIFIER_CTRL,         XKB_KEY_Print,                  spawn,            {.v = shoteditcmd} },

    { 0, XKB_KEY_XF86AudioMute,         spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
    { 0, XKB_KEY_XF86AudioLowerVolume,  spawn, SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") },
    { 0, XKB_KEY_XF86AudioRaiseVolume,  spawn, SHCMD("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+") },
    { 0, XKB_KEY_XF86AudioPlay,         spawn, SHCMD("playerctl play-pause") },
    { 0, XKB_KEY_XF86AudioPrev,         spawn, SHCMD("playerctl previous") },
    { 0, XKB_KEY_XF86AudioNext,         spawn, SHCMD("playerctl next") },
    { 0, XKB_KEY_XF86MonBrightnessDown,spawn, SHCMD("brightnessctl set 5%-") },
    { 0, XKB_KEY_XF86MonBrightnessUp,  spawn, SHCMD("brightnessctl set +5%") },

    { MODKEY|WLR_MODIFIER_SHIFT,        XKB_KEY_Q,                      quit,             {0} },

    /* Preserve the standard VT switching / emergency exit bindings. */
    { WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_Terminate_Server,      quit,             {0} },
#define CHVT(n) { WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_XF86Switch_VT_##n, chvt, {.ui = (n)} }
    CHVT(1), CHVT(2), CHVT(3), CHVT(4), CHVT(5), CHVT(6),
    CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
};'''

keys = (keys.replace('__TAGKEYS__', tagkeys)
            .replace('__SHIFTZERO__', shift_zero)
            .replace('__SHIFTCOMMA__', shift_comma)
            .replace('__SHIFTPERIOD__', shift_period))
text = text[:start] + keys + text[end:]
path.write_text(text, encoding="utf-8")
print(f"patched {path}")
