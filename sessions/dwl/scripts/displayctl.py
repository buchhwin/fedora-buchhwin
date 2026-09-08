#!/usr/bin/env python3
"""Machine-readable display control for the integrated Quickshell settings."""
from __future__ import annotations

import json
import re
import subprocess
import sys


def outputs() -> list[dict]:
    result = subprocess.run(["wlr-randr"], text=True, capture_output=True, check=True)
    found: list[dict] = []
    current: dict | None = None
    in_modes = False
    for line in result.stdout.splitlines():
        if line and not line.startswith(" "):
            name, _, description = line.partition(" ")
            current = {"name": name, "description": description.strip().strip('"'),
                       "enabled": True, "modes": [], "mode": "", "scale": 1.0,
                       "transform": "normal", "x": 0, "y": 0}
            found.append(current)
            in_modes = False
            continue
        if current is None:
            continue
        value = line.strip()
        if value == "Modes:":
            in_modes = True
        elif in_modes and re.match(r"^\d+x\d+ px,", value):
            mode = value.split(" px,", 1)[0]
            current["modes"].append(mode)
            if "current" in value:
                current["mode"] = mode
        elif value.startswith("Enabled:"):
            current["enabled"] = value.endswith("yes")
            in_modes = False
        elif value.startswith("Position:"):
            position = value.split(":", 1)[1].strip().split(",")
            current["x"], current["y"] = int(position[0]), int(position[1])
            in_modes = False
        elif value.startswith("Transform:"):
            current["transform"] = value.split(":", 1)[1].strip()
            in_modes = False
        elif value.startswith("Scale:"):
            current["scale"] = float(value.split(":", 1)[1].strip())
            in_modes = False
    return found


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "list":
        print(json.dumps(outputs(), ensure_ascii=False))
        return 0
    if len(sys.argv) == 8 and sys.argv[1] == "set":
        _, _, name, mode, scale, transform, x, y = sys.argv
        command = ["wlr-randr", "--output", name, "--on", "--mode", mode,
                   "--scale", scale, "--transform", transform,
                   "--pos", f"{int(x)},{int(y)}"]
        subprocess.run(command, check=True)
        subprocess.run(["buchhwin-display-profile", "save"], check=True)
        return 0
    print("usage: buchhwin-displayctl list | set OUTPUT MODE SCALE TRANSFORM X Y", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
