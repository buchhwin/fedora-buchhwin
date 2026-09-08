#!/usr/bin/env python3
"""Small cached weather provider for the buchhwin bar."""
from __future__ import annotations

import json
import os
import tempfile
import urllib.request
from pathlib import Path

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "buchhwin-dwl/weather.json"
URL = "https://wttr.in/{location}?format=j1"
REVERSE_URL = "https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lon}&format=jsonv2&addressdetails=1"


def icon_for(code: int, night: bool = False) -> tuple[str, str]:
    if code == 113:
        return ("󰖔", "#cba6f7") if night else ("󰖙", "#f9e2af")
    if code in {116}:
        return ("󰼱", "#bac2de") if night else ("󰖕", "#f9e2af")
    if code in {119, 122, 143, 248, 260}:
        return ("󰖐", "#bac2de")
    if code in {176, 263, 266, 281, 293, 296, 299, 302, 305, 308, 311, 314, 353, 356, 359}:
        return ("󰖗", "#89b4fa")
    if code in {179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377}:
        return ("󰖘", "#cdd6f4")
    if code in {200, 386, 389, 392, 395}:
        return ("󰖓", "#f9e2af")
    return ("󰖐", "#bac2de")


def geoclue_coordinates() -> tuple[float, float, float] | None:
    """Request a street-level fix from GeoClue; return quickly on denial."""
    try:
        import gi
        gi.require_version("Gio", "2.0")
        from gi.repository import Gio, GLib
        manager = Gio.DBusProxy.new_for_bus_sync(
            Gio.BusType.SYSTEM, Gio.DBusProxyFlags.NONE, None,
            "org.freedesktop.GeoClue2", "/org/freedesktop/GeoClue2/Manager",
            "org.freedesktop.GeoClue2.Manager", None)
        client_path = manager.call_sync("GetClient", None, Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]
        bus = manager.get_connection()
        for name, value in (("DesktopId", GLib.Variant("s", "buchhwin-weather")),
                            ("RequestedAccuracyLevel", GLib.Variant("u", 6))):
            bus.call_sync("org.freedesktop.GeoClue2", client_path, "org.freedesktop.DBus.Properties",
                          "Set", GLib.Variant("(ssv)", ("org.freedesktop.GeoClue2.Client", name, value)),
                          None, Gio.DBusCallFlags.NONE, 3000, None)
        client = Gio.DBusProxy.new_sync(bus, Gio.DBusProxyFlags.NONE, None,
                                       "org.freedesktop.GeoClue2", client_path,
                                       "org.freedesktop.GeoClue2.Client", None)
        result = {"value": None, "accuracy": float("inf")}
        loop = GLib.MainLoop()
        def changed(_proxy, _sender, signal, parameters):
            if signal != "LocationUpdated": return
            location_path = parameters.unpack()[1]
            location = Gio.DBusProxy.new_sync(bus, Gio.DBusProxyFlags.NONE, None,
                                              "org.freedesktop.GeoClue2", location_path,
                                              "org.freedesktop.GeoClue2.Location", None)
            accuracy = location.get_cached_property("Accuracy").unpack()
            if accuracy < result["accuracy"]:
                result["accuracy"] = accuracy
                result["value"] = (location.get_cached_property("Latitude").unpack(),
                                   location.get_cached_property("Longitude").unpack(), accuracy)
        client.connect("g-signal", changed)
        GLib.timeout_add_seconds(6, lambda: (loop.quit(), False)[1])
        client.call_sync("Start", None, Gio.DBusCallFlags.NONE, 3000, None)
        loop.run()
        client.call_sync("Stop", None, Gio.DBusCallFlags.NONE, 1000, None)
        return result["value"]
    except Exception:
        return None


def place_for(latitude: float, longitude: float, fallback: str) -> str:
    """Resolve the detected coordinates to a municipality-sized place name."""
    try:
        request = urllib.request.Request(
            REVERSE_URL.format(lat=latitude, lon=longitude),
            headers={"User-Agent": "buchhwin-dwl-weather/1.1"})
        with urllib.request.urlopen(request, timeout=6) as response:
            address = json.load(response).get("address", {})
        return (address.get("municipality") or address.get("city") or
                address.get("town") or address.get("village") or
                address.get("hamlet") or fallback)
    except Exception:
        return fallback


def fetch() -> dict:
    coordinates = geoclue_coordinates()
    location = "" if coordinates is None else f"{coordinates[0]:.5f},{coordinates[1]:.5f}"
    request = urllib.request.Request(URL.format(location=location), headers={"User-Agent": "buchhwin-dwl-weather/1.0"})
    with urllib.request.urlopen(request, timeout=8) as response:
        payload = json.load(response)
    current = payload["current_condition"][0]
    area = payload.get("nearest_area", [{}])[0]
    place = (area.get("areaName") or [{"value": "Current location"}])[0]["value"]
    if coordinates is not None:
        place = place_for(coordinates[0], coordinates[1], place)
    code = int(current.get("weatherCode", 0))
    icon, icon_color = icon_for(code, current.get("weatherIconUrl", [{}])[0].get("value", "").find("night") >= 0)
    return {
        "temperature": int(round(float(current["temp_C"]))),
        "feelsLike": int(round(float(current.get("FeelsLikeC", current["temp_C"])))),
        "description": (current.get("weatherDesc") or [{"value": "Weather"}])[0]["value"],
        "location": place,
        "icon": icon,
        "iconColor": icon_color,
        "precise": coordinates is not None and coordinates[2] <= 5000,
        "accuracy": None if coordinates is None else round(coordinates[2]),
    }


def main() -> int:
    try:
        data = fetch()
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile("w", dir=CACHE.parent, delete=False, encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False)
            temporary = handle.name
        os.replace(temporary, CACHE)
    except Exception:
        if not CACHE.exists():
            data = {"temperature": None, "location": "Weather unavailable", "description": "Offline", "icon": "󰖪", "iconColor": "#a6adc8"}
        else:
            data = json.loads(CACHE.read_text(encoding="utf-8"))
            data["cached"] = True
    print(json.dumps(data, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
