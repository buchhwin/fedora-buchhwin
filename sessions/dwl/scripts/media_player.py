#!/usr/bin/env python3
"""Persist the preferred MPRIS player and open its desktop application."""
import configparser, json, os, subprocess, sys
from pathlib import Path
STATE = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "buchhwin-dwl/media-player.json"
def get() -> str:
    try: return str(json.loads(STATE.read_text(encoding="utf-8")).get("identity", ""))
    except Exception: return ""
def set_player(identity: str) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True); STATE.write_text(json.dumps({"identity": identity}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
def open_player(identity: str) -> int:
    wanted = "".join(ch for ch in identity.lower() if ch.isalnum()); matches = []
    roots = [Path.home()/".local/share/applications", Path("/usr/share/applications"), Path("/var/lib/flatpak/exports/share/applications")]
    for root in roots:
        for path in root.glob("*.desktop") if root.is_dir() else []:
            try:
                parser = configparser.ConfigParser(interpolation=None, strict=False); parser.read(path, encoding="utf-8"); entry = parser["Desktop Entry"]
                values = [entry.get("Name", ""), entry.get("StartupWMClass", ""), path.stem]
                normalized = ["".join(c for c in value.lower() if c.isalnum()) for value in values]
                score = max((len(value) if wanted == value else min(len(wanted), len(value)) if wanted and value and (wanted in value or value in wanted) else 0) for value in normalized)
                if score: matches.append((score, path.stem))
            except Exception: pass
    if not matches: return 1
    subprocess.Popen(["gtk-launch", max(matches)[1]], start_new_session=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0
def main() -> int:
    args = sys.argv[1:]
    if args == ["get"]: print(get()); return 0
    if len(args) == 2 and args[0] == "set": set_player(args[1]); return 0
    if len(args) == 2 and args[0] == "open": return open_player(args[1])
    return 2
if __name__ == "__main__": raise SystemExit(main())
