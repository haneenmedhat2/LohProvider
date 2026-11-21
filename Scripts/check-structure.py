#!/usr/bin/env python3
"""Validate separate screen/component features with only the MVVM folders they use."""
from pathlib import Path
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "LohProvider"
ROLES = {"View", "ViewModel", "Model"}
UI_TYPES = {"View", "UIViewRepresentable", "UIViewControllerRepresentable", "ViewModifier", "Shape",
            "ButtonStyle", "PrimitiveButtonStyle", "UIView", "UIViewController", "UITextField", "UITextView"}


def main():
    compiler = Path(subprocess.check_output(["xcrun", "--find", "swiftc"], text=True).strip())
    host = compiler.parent.parent / "lib/swift/host"
    with tempfile.TemporaryDirectory(prefix="loh-structure-") as temporary:
        build = Path(temporary)
        executable = build / "inspect-swift-structure"
        subprocess.run([str(compiler), "-module-cache-path", str(build / "modules"), "-I", str(host), "-L", str(host),
                        "-Xlinker", "-rpath", "-Xlinker", str(host), "-lSwiftParser", "-lSwiftSyntax",
                        str(ROOT / "Scripts/inspect-swift-structure.swift"), "-o", str(executable)], check=True)
        paths = sorted(APP.rglob("*.swift"))
        files = json.loads(subprocess.check_output([str(executable), *map(str, paths)], text=True))
    failures, features = [], set()
    count = 0
    for file in files:
        path = Path(file["path"])
        relative = path.relative_to(APP)
        if file.get("syntaxErrors"):
            failures.append(f"{relative}: Swift syntax errors")
        ui = [declaration for declaration in file["declarations"] if set(declaration["inheritance"]) & UI_TYPES]
        count += len(ui)
        if len(ui) > 1:
            failures.append(f"{relative}: multiple UI types: {', '.join(item['name'] for item in ui)}")
        if ui and path.parent.name != "View":
            failures.append(f"{relative}: UI belongs directly under its own feature's View folder")
        if ui and path.stem != ui[0]["name"]:
            failures.append(f"{relative}: name this file {ui[0]['name']}.swift")
        if relative.parts[0] == "App" and not ROLES.intersection(relative.parts):
            failures.append(f"{relative}: app feature sources need a View, ViewModel, or Model folder")
        for parent in path.parents:
            if parent == APP:
                break
            if parent.name in ROLES:
                features.add(parent.parent)
                break
    for feature in sorted(features):
        view_folder = feature / "View"
        if view_folder.is_dir():
            views = list(view_folder.rglob("*.swift"))
            if len(views) != 1:
                failures.append(f"{feature.relative_to(APP)}: give each screen/component its own feature folder; found {len(views)} View files")
            if any(child.is_dir() for child in view_folder.iterdir()):
                failures.append(f"{feature.relative_to(APP)}: put child components beside View, not inside it")
    for folder in APP.rglob("*"):
        if folder.is_dir() and folder.name in ROLES and not any(folder.rglob("*.swift")):
            failures.append(f"{folder.relative_to(APP)}: remove this unused role folder")
    for placeholder in APP.rglob(".gitkeep"):
        failures.append(f"{placeholder.relative_to(APP)}: remove empty folder placeholders")
    if failures:
        raise SystemExit("Source structure checks failed:\n" + "\n".join(failures))
    print(f"Passed source structure: {len(files)} Swift files, {count} UI types, {len(features)} feature/component folders.")


if __name__ == "__main__":
    main()
