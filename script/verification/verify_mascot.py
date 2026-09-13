#!/usr/bin/env python3
"""Check packaged icon resources and optionally render the native expression sheet."""
import argparse
from pathlib import Path
import plistlib
import struct
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--app", type=Path, required=True)
parser.add_argument("--render", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
resources = args.app / "Contents/Resources"
source = root / "Sources/CiderPlatform/Resources/branding"
with (args.app / "Contents/Info.plist").open("rb") as handle:
    assert plistlib.load(handle)["CFBundleIconFile"] == "Cider.icns"
assert (resources / "Cider.icns").read_bytes() == (source / "Cider.icns").read_bytes()
packaged = resources / "Cider_CiderPlatform.bundle/Resources/branding"
for name in ("cider.png", "Cider.icns"):
    assert (packaged / name).read_bytes() == (source / name).read_bytes(), name

with tempfile.TemporaryDirectory(prefix="cider-icon-check-") as temporary:
    iconset = Path(temporary) / "Cider.iconset"
    subprocess.run(["iconutil", "-c", "iconset", str(resources / "Cider.icns"), "-o", str(iconset)], check=True)
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            name = f"icon_{size}x{size}" + ("@2x" if scale == 2 else "") + ".png"
            data = (iconset / name).read_bytes()
            assert data[:8] == b"\x89PNG\r\n\x1a\n"
            assert struct.unpack(">II", data[16:24]) == (size * scale, size * scale)
    print("PASS: packaged mascot assets match; all 10 app icon representations decode at the expected sizes.")
    if args.render:
        build = Path(subprocess.check_output(["swift", "build", "--show-bin-path"], cwd=root, text=True).strip())
        objects = [str(p) for target in ("CiderDomain", "CiderUI") for p in (build / (target + ".build")).glob("*.swift.o")]
        binary = str(Path(temporary) / "render")
        subprocess.run(["swiftc", "-parse-as-library", "-I", str(build / "Modules"),
                        str(root / "script/verification/MascotRender.swift"), *objects, "-o", binary], check=True)
        args.render.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([binary, str(args.render)], check=True)
