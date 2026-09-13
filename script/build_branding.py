#!/usr/bin/env python3
"""Package the supplied mascot and its charcoal app-icon tile at macOS icon sizes."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = root / "cider-mascot.png"
destination = root / "Sources/CiderPlatform/Resources/branding"
destination.mkdir(parents=True, exist_ok=True)


def resize(size, output, input_image=source):
    subprocess.run(["sips", "-z", str(size), str(size), str(input_image), "--out", str(output)],
                   check=True, stdout=subprocess.DEVNULL)


with tempfile.TemporaryDirectory(prefix="cider-mascot-icon-") as temporary:
    iconset = Path(temporary) / "Cider.iconset"
    iconset.mkdir()
    icon = Path(temporary) / "app-icon.png"
    subprocess.run(["swift", str(root / "script/branding/RenderIcon.swift"), str(source), str(icon)], check=True)
    for size in (16, 32, 128, 256, 512):
        resize(size, iconset / f"icon_{size}x{size}.png", icon)
        resize(size * 2, iconset / f"icon_{size}x{size}@2x.png", icon)
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(destination / "Cider.icns")], check=True)
    resize(512, destination / "cider.png")

print("Packaged Cider mascot PNG and 16–1024 pixel app icon representations.")
