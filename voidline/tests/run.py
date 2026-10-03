#!/usr/bin/env python3
"""Headless test runner for VOIDLINE's pure Luau modules.

Bundles every module under src/shared into one Luau file with a fake
Roblox-style `script` hierarchy, so modules can keep using
`require(script.Parent.X)`. Then appends tests/*.spec.luau and runs the
bundle with the `luau` CLI (set LUAU=/path/to/luau or put it on PATH).
"""
import os
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"
TESTS = ROOT / "tests"


def long_string(text: str) -> str:
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{text}]{eq}]"


def main() -> int:
    luau = os.environ.get("LUAU") or shutil.which("luau")
    if not luau:
        print("luau CLI not found (set LUAU=/path/to/luau)")
        return 2

    parts = [(TESTS / "prelude.luau").read_text()]
    for path in sorted(SHARED.rglob("*.luau")):
        rel = path.relative_to(SHARED).with_suffix("")
        parts.append(f"__registerModule({str(rel.as_posix())!r}, {long_string(path.read_text())})")
    specs = sorted(TESTS.glob("*.spec.luau"))
    for spec in specs:
        parts.append(f"__runSpec({spec.name!r}, {long_string(spec.read_text())})")
    parts.append("__finish()")

    bundle = ROOT / ".cache" / "test_bundle.luau"
    bundle.parent.mkdir(exist_ok=True)
    bundle.write_text("\n".join(parts))
    result = subprocess.run([luau, str(bundle)])
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
