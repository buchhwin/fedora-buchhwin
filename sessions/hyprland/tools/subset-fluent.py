#!/usr/bin/env python3
"""Cut Microsoft's Fluent UI System Icons down to the glyphs this desktop uses.

⚠️ WHY A SUBSET AND NOT THE FONT. Fluent's Regular face is 2.81 MB and carries
9689 glyphs; this shell asks it for twenty-one. A public repository does not
need 2.8 MB of unused outlines, and rule 8 ("performant and efficient, from the
start") is not only about the running desktop. The result is 5 KB.

⚠️ WHY VENDORED AND NOT FETCHED. lib/50-fonts.sh does fetch two things nobody
packages for Fedora — but both exist upstream as files. This one does not: it is
something made here, so there is nothing to download and nothing to pin. The
5 KB file lives in the tree and this script is how it is reproduced.

⚠️ AND IT IS RENAMED, deliberately. Keeping the upstream family name would mean
two different fonts called the same thing the moment somebody installs the real
one — with ours shadowing it and most of its glyphs missing. MIT allows the
modification; docs/CREDITS.md carries the notice it requires.

    python3 -m venv /tmp/fs && /tmp/fs/bin/pip install fonttools brotli
    /tmp/fs/bin/python tools/subset-fluent.py <FluentSystemIcons-Regular.ttf>
"""
import sys, subprocess, tempfile, os, json, urllib.request

FAMILY = "Buchhwin Fluent Icons"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "fonts", "BuchhwinFluentIcons.ttf")
META = ("https://raw.githubusercontent.com/microsoft/fluentui-system-icons/"
        "main/fonts/FluentSystemIcons-Regular.json")

# Exactly what shell/ui/ asks for, and nothing kept "in case".
WANTED = (
    [f"ic_fluent_wifi_{i}_24_regular" for i in (1, 2, 3, 4)]
    + ["ic_fluent_wifi_off_24_regular"]
    + [f"ic_fluent_battery_{i}_24_regular" for i in range(0, 11)]
    + ["ic_fluent_battery_charge_24_regular"]
    + ["ic_fluent_plug_connected_24_regular",
       "ic_fluent_plug_disconnected_24_regular",
       "ic_fluent_router_24_regular",
       "ic_fluent_connector_24_regular"]
)

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = sys.argv[1]
    with urllib.request.urlopen(META) as r:
        names = json.load(r)
    missing = [w for w in WANTED if w not in names]
    if missing:
        sys.exit("not in the upstream font any more: " + ", ".join(missing))
    points = sorted({names[w] for w in WANTED})
    with tempfile.TemporaryDirectory() as tmp:
        uni = os.path.join(tmp, "unicodes.txt")
        open(uni, "w").write(",".join(f"U+{p:04X}" for p in points))
        subprocess.run([sys.executable, "-m", "fontTools.subset", src,
                        f"--unicodes-file={uni}", f"--output-file={OUT}",
                        "--no-hinting", "--desubroutinize",
                        "--name-IDs=*", "--drop-tables+=DSIG"], check=True)
    from fontTools.ttLib import TTFont
    f = TTFont(OUT)
    for rec in f["name"].names:
        if rec.nameID in (1, 3, 4, 6, 16):
            rec.string = FAMILY if rec.nameID != 6 else FAMILY.replace(" ", "")
    f.save(OUT)
    print(f"{OUT}: {len(points)} glyphs, {os.path.getsize(OUT)} bytes, family {FAMILY!r}")

if __name__ == "__main__":
    main()
