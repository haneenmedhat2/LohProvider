#!/usr/bin/env python3
"""Install the Figma English typeface when outbound downloads are available.

Run from any directory: python3 Scripts/install-loh-poppins.py
Source: Google Fonts' Poppins distribution, licensed under the SIL OFL.
"""
from pathlib import Path
import plistlib
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "LohProvider/Shared/DesignSystem/Fonts"
BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl/poppins/"
FILES = [f"Poppins-{weight}.ttf" for weight in ("Regular", "Medium", "SemiBold", "Bold", "ExtraBold", "Black")]


def main():
    # Stage all downloads before changing the project or its font registration.
    with tempfile.TemporaryDirectory(prefix="loh-poppins-") as directory:
        staging = Path(directory)
        for name in FILES + ["OFL.txt"]:
            subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error", BASE + name, "-o", str(staging / name)], check=True)
            if not (staging / name).stat().st_size:
                raise RuntimeError(f"Empty font download: {name}")
        for name in FILES:
            data = (staging / name).read_bytes()
            if data[:4] not in (b"\x00\x01\x00\x00", b"OTTO"):
                raise RuntimeError(f"Invalid font download: {name}")
        DESTINATION.mkdir(parents=True, exist_ok=True)
        for name in FILES:
            (DESTINATION / name).write_bytes((staging / name).read_bytes())
        (DESTINATION / "Poppins-OFL.txt").write_bytes((staging / "OFL.txt").read_bytes())
        plist = ROOT / "LohProvider/Core/Info.plist"
        data = plistlib.loads(plist.read_bytes())
        data["UIAppFonts"] = list(dict.fromkeys(data.get("UIAppFonts", []) + FILES))
        plist.write_bytes(plistlib.dumps(data))
    print("Poppins installed and registered. Rebuild the app to use it.")


if __name__ == "__main__":
    main()
