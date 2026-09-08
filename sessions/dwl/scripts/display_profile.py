#!/usr/bin/env python3
"""Save and safely restore a wlr-randr display profile."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

PROFILE = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "buchhwin-dwl" / "display-profile.json"
OUTPUT_RE = re.compile(r"^(\S+)(?:\s+\".*\")?$")
MODE_RE = re.compile(r"^\s+(\d+)x(\d+) px, ([\d.]+) Hz.*\(current")


def query() -> str:
    result = subprocess.run(["wlr-randr"], capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "wlr-randr failed")
    return result.stdout


def parse(raw: str) -> dict[str, dict]:
    outputs: dict[str, dict] = {}
    current: dict | None = None
    for line in raw.splitlines():
        if line and not line[0].isspace():
            match = OUTPUT_RE.match(line)
            if match:
                current = {"enabled": True}
                outputs[match.group(1)] = current
            continue
        if current is None:
            continue
        value = line.strip()
        if value.startswith("Enabled:"):
            current["enabled"] = value.split(":", 1)[1].strip() == "yes"
        elif value.startswith("Position:"):
            pos = value.split(":", 1)[1].strip().split(",", 1)
            if len(pos) == 2:
                current["position"] = [int(pos[0]), int(pos[1])]
        elif value.startswith("Transform:"):
            current["transform"] = value.split(":", 1)[1].strip()
        elif value.startswith("Scale:"):
            current["scale"] = float(value.split(":", 1)[1].strip())
        else:
            match = MODE_RE.match(line)
            if match:
                current["mode"] = [int(match.group(1)), int(match.group(2)), float(match.group(3))]
    return outputs


def save() -> int:
    outputs = parse(query())
    if not outputs or not any(item.get("enabled") for item in outputs.values()):
        raise RuntimeError("no enabled outputs detected")
    PROFILE.parent.mkdir(parents=True, exist_ok=True)
    temporary = PROFILE.with_suffix(".tmp")
    temporary.write_text(json.dumps({"version": 1, "outputs": outputs}, indent=2) + "\n", encoding="utf-8")
    temporary.replace(PROFILE)
    return 0


def apply() -> int:
    if not PROFILE.exists():
        return 0
    profile = json.loads(PROFILE.read_text(encoding="utf-8"))
    wanted = profile.get("outputs", {})
    available: set[str] = set()
    for _ in range(30):
        try:
            available = set(parse(query()))
        except (OSError, RuntimeError):
            pass
        if available:
            break
        time.sleep(0.2)

    enabled = [(name, data) for name, data in wanted.items() if data.get("enabled") and name in available]
    # A dock profile must never disable the laptop panel when none of its saved
    # active external outputs are connected.
    if not enabled:
        return 0

    for name, data in enabled:
        command = ["wlr-randr", "--output", name, "--on"]
        mode = data.get("mode")
        if isinstance(mode, list) and len(mode) == 3:
            command += ["--mode", f"{mode[0]}x{mode[1]}@{mode[2]:g}Hz"]
        position = data.get("position")
        if isinstance(position, list) and len(position) == 2:
            command += ["--pos", f"{position[0]},{position[1]}"]
        if data.get("transform"):
            command += ["--transform", str(data["transform"])]
        if data.get("scale"):
            command += ["--scale", str(data["scale"])]
        subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

    for name, data in wanted.items():
        if not data.get("enabled") and name in available:
            subprocess.run(["wlr-randr", "--output", name, "--off"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    return 0


def main() -> int:
    try:
        action = sys.argv[1] if len(sys.argv) > 1 else "apply"
        return save() if action == "save" else apply() if action == "apply" else 2
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:
        print(f"buchhwin-display-profile: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
