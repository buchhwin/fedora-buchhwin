# Keyboard shortcuts

⚠️ **This file is generated from `shell/config/Binds.qml`** by
`tests/keybinds-doc.sh`, which also fails if the two disagree. Edit the bindings
there, not here — a shortcut list that drifts from the shortcuts is worse than
no list, because it is the thing somebody reaches for when a key does not do
what they expected.

The modifier is **Super** throughout, and it is a setting (`keys.mod`): a
machine where Super is taken can move every one of these to Alt in one place.
The bindings follow the dwl session's, on his instruction that they are the
good ones, so muscle memory carries between the two desktops.

There are 67 of them.

## Programs

| Keys | What it does |
|---|---|
| `SUPER + Return` | Terminal |
| `SUPER + D` | App launcher |
| `SUPER + B` | Web browser |
| `SUPER + E` | Files |
| `SUPER + C` | Editor |
| `SUPER + L` | Lock screen |

## Windows

| Keys | What it does |
|---|---|
| `SUPER + Q` | Close window |
| `SUPER + J` | Focus next window |
| `SUPER + K` | Focus previous window |
| `SUPER + SHIFT + SPACE` | Toggle floating |
| `SUPER + SHIFT + F` | Toggle fullscreen |
| `SUPER + I` | More master windows |
| `SUPER + SHIFT + I` | Fewer master windows |
| `SUPER + SHIFT + Return` | Promote to master |
| `SUPER + Left` | Shrink master |
| `SUPER + Right` | Grow master |
| `SUPER + Up` | Top stack, shrink |
| `SUPER + Down` | Top stack, grow |
| `SUPER + F` | Float everything here |
| `SUPER + mouse:272` | Move window · pointer |
| `SUPER + mouse:273` | Resize window · pointer |

## Workspaces

| Keys | What it does |
|---|---|
| `SUPER + SHIFT + 0` | Pin to every workspace |
| `SUPER + TAB` | Previous workspace |
| `SUPER + 0` | Workspace overview |

## Sound, screen and media

| Keys | What it does |
|---|---|
| `SUPER + P` | Media |
| `XF86AudioRaiseVolume` | Volume up · works while locked |
| `XF86AudioLowerVolume` | Volume down · works while locked |
| `XF86AudioMute` | Mute · works while locked |
| `XF86AudioMicMute` | Mute the microphone · works while locked |
| `XF86MonBrightnessUp` | Brighter · works while locked |
| `XF86AudioPlay` | Play or pause · works while locked |
| `XF86AudioPause` | Play or pause · works while locked |
| `XF86AudioNext` | Next track · works while locked |
| `XF86AudioPrev` | Previous track · works while locked |

## The island

| Keys | What it does |
|---|---|
| `SUPER + V` | Clipboard history |
| `SUPER + N` | Notifications |
| `SUPER + ESCAPE` | Collapse the island |
| `SUPER + SHIFT + S` | Settings |
| `SUPER + SHIFT + K` | Calendar |
| `SUPER + SHIFT + W` | Wallpaper |
| `SUPER + SHIFT + T` | Theme |
| `SUPER + SHIFT + Z` | Timer |

## Everything else

| Keys | What it does |
|---|---|
| `SUPER + CTRL + SHIFT + R` | Restart the shell |
| `SUPER + SHIFT + M` | Monocle |
| `SUPER + T` | Tiled layout |
| `SUPER + SPACE` | Cycle layout |
| `SUPER + ALT + SPACE` | Top-and-bottom layout |
| `SUPER + COMMA` | Focus left monitor |
| `SUPER + PERIOD` | Focus right monitor |
| `SUPER + SHIFT + COMMA` | Move to left monitor |
| `SUPER + SHIFT + PERIOD` | Move to right monitor |
| `SUPER + S` | Screenshot a region |
| `SUPER + Print` | Screenshot a region |
| `SUPER + SHIFT + Print` | Screenshot the screen |
| `SUPER + CTRL + Print` | Screenshot and annotate |
| `SUPER + M` | Power menu |
| `SUPER + R` | Calculator |
| `SUPER + SHIFT + C` | Control centre |
| `SUPER + F1` | Keyboard shortcuts |
| `SUPER + SHIFT + Y` | System tray |
| `SUPER + SHIFT + TAB` | Monitors |
| `SUPER + SHIFT + E` | Emoji |
| `SUPER + SHIFT + N` | New event |
| `SUPER + SHIFT + B` | Show or hide the bar |
| `CTRL + SHIFT + ESCAPE` | Task manager |
| `XF86MonBrightnessDown` | Dimmer · works while locked |
| `SUPER + SHIFT + Q` | Log out |

## Changing one

Settings → Shortcuts, or `qs -c buchhwin ipc call settings keys`. What you set
is written to `binds` in `shell.json`, and `shell/tools/hypr/EmitBinds.qml`
regenerates the compositor's own config from it — so a rebind takes effect
without editing a Lua file by hand.

⚠️ **The action names are ours, not Hyprland's.** `Binds.qml` names an action
like `move-window-workspace`; `tools/hypr/Binds.qml` maps that to the
dispatcher. A rename upstream is one edit there rather than sixty here, and
`tests/bind-actions.sh` fails if an action has no mapping.
