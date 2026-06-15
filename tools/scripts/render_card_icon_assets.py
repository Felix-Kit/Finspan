#!/usr/bin/env python3
"""Render live SVG card icons into iOS-stable transparent PNG assets.

The SVG files remain the source of truth. These PNGs are render assets for
SwiftUI / UIKit runtime loading, generated with macOS `sips` from the SVG
source while preserving aspect ratio and alpha.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


DEFAULT_ICON_DIR = Path("Finspan/Resources/CardAssets/icons")


def render_svg(svg_path: Path, max_dimension: int) -> Path:
    output_path = svg_path.with_suffix(svg_path.suffix + ".png")
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_output = Path(temp_dir) / output_path.name
        command = [
            "sips",
            "-s",
            "format",
            "png",
            "--resampleHeightWidthMax",
            str(max_dimension),
            str(svg_path),
            "--out",
            str(temp_output),
        ]
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        shutil.move(str(temp_output), str(output_path))
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--icon-dir", type=Path, default=DEFAULT_ICON_DIR)
    parser.add_argument("--max-dimension", type=int, default=1536)
    args = parser.parse_args()

    if shutil.which("sips") is None:
        print("error: macOS sips is required to render SVG icons", file=sys.stderr)
        return 1

    icon_dir = args.icon_dir
    svg_paths = sorted(icon_dir.glob("*.svg"))
    if not svg_paths:
        print(f"error: no SVG icons found in {icon_dir}", file=sys.stderr)
        return 1

    rendered = []
    for svg_path in svg_paths:
        rendered.append(render_svg(svg_path, args.max_dimension))

    print(f"Rendered {len(rendered)} icon PNG assets in {icon_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
