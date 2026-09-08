#!/usr/bin/env python3
"""Apply validated per-user key bindings to an existing buchhwin config.h."""
import json, re, sys
from pathlib import Path
path = Path(sys.argv[1]); text = path.read_text(encoding="utf-8")
cfg = Path.home() / ".config/buchhwin-dwl/keybinds.json"
if not cfg.exists(): raise SystemExit(0)
values = json.loads(cfg.read_text(encoding="utf-8"))
targets = {
 "terminal": r"spawn,\s+\{\.v = termcmd\}", "launcher": r"spawn,\s+\{\.v = menucmd\}", "browser": r"spawn,\s+\{\.v = browsercmd\}",
 "files": r"spawn,\s+\{\.v = filescmd\}", "code": r"spawn,\s+\{\.v = codecmd\}", "settings": r"spawn,\s+\{\.v = settingscmd\}",
 "notifications": r"spawn,\s+\{\.v = notificationscmd\}", "power": r"spawn,\s+\{\.v = powercmd\}", "lock": r"spawn,\s+\{\.v = lockcmd\}",
 "clipboard": r"spawn,\s+\{\.v = clipboardcmd\}", "screenshot": r"spawn,\s+\{\.v = shotcmd\}", "close": r"killclient,\s+\{0\}",
 "focus_next": r"focusstack,\s+\{\.i = \+1\}", "focus_previous": r"focusstack,\s+\{\.i = -1\}",
 "resize_left": r"setmfact,\s+\{\.f = -0\.05f\}", "resize_right": r"setmfact,\s+\{\.f = \+0\.05f\}",
 "resize_up": r"sethorizontalmfact,\s*\{\.f = -0\.05f\}", "resize_down": r"sethorizontalmfact,\s*\{\.f = \+0\.05f\}",
 "tile": r"setlayout,\s+\{\.v = &layouts\[0\]\}", "monocle": r"setlayout,\s+\{\.v = &layouts\[1\]\}",
 "layout_orientation": r"togglelayoutorientation,\s+\{0\}",
 "floating": r"togglefloating,\s+\{0\}", "fullscreen": r"togglefullscreen,\s+\{0\}", }
mods = {"Super":"MODKEY", "Super+Shift":"MODKEY|WLR_MODIFIER_SHIFT", "Super+Ctrl":"MODKEY|WLR_MODIFIER_CTRL", "Super+Alt":"MODKEY|WLR_MODIFIER_ALT"}
for ident, value in values.items():
    if ident not in targets or value.get("modifier") not in mods or not re.fullmatch(r"[A-Za-z0-9_]+", value.get("key", "")): continue
    pattern = r"^([ \t]*)\{[ \t]*[^,]+,[ \t]*XKB_KEY_[^,]+,[ \t]*(" + targets[ident] + r")[ \t]*\},"
    replacement = "\\1{ %-34s XKB_KEY_%-23s \\2 }," % (mods[value["modifier"]] + ",", value["key"] + ",")
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.M)
    if count != 1: raise SystemExit(f"Could not locate binding: {ident}")
path.write_text(text, encoding="utf-8")
