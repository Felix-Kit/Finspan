#!/usr/bin/env python3
"""Audit card icon render assets for real pixel renderability.

The SVG files under CardAssets/icons remain the source of truth. This script
checks the generated PNG render assets that iOS actually loads and rejects the
failure mode that caused white icon blocks: opaque white thumbnails whose file
paths resolved successfully but whose pixels were not useful card icons.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import struct
import subprocess
import sys
import tempfile
import zlib
from collections import Counter
from pathlib import Path
from typing import Any


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
WHITE_THRESHOLD = 238
LOW_ALPHA_THRESHOLD = 8
MIN_RENDER_DIMENSION = 128
MIN_MAX_DIMENSION = 512


def with_cli_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="Audit generated card icon PNGs for non-white, non-transparent pixels."
    )
    parser.add_argument(
        "--icon-dir",
        type=Path,
        default=repo_root / "Finspan/Resources/CardAssets/icons",
        help="Directory containing live SVG icons and generated PNG render assets.",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=repo_root / "build/reports/card_icon_renderability.json",
        help="JSON report path.",
    )
    parser.add_argument("--json", action="store_true", dest="json_output")
    parser.set_defaults(repo_root=repo_root)
    return parser.parse_args()


def read_png_header(path: Path) -> tuple[int, int, int, int]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("not a PNG file")

    pos = len(PNG_SIGNATURE)
    while pos + 8 <= len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        chunk_type = data[pos + 4 : pos + 8]
        chunk_data = data[pos + 8 : pos + 8 + length]
        pos += 12 + length

        if chunk_type == b"IHDR":
            return struct.unpack(">IIBBBBB", chunk_data)[:4]
    raise ValueError("missing IHDR")


def read_png_rgba(path: Path) -> tuple[int, int, list[tuple[int, int, int, int]]]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("not a PNG file")

    pos = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = None
    idat = bytearray()

    while pos + 8 <= len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        chunk_type = data[pos + 4 : pos + 8]
        chunk_data = data[pos + 8 : pos + 8 + length]
        pos += 12 + length

        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk_data)
        elif chunk_type == b"IDAT":
            idat.extend(chunk_data)
        elif chunk_type == b"IEND":
            break

    if width is None or height is None or bit_depth is None or color_type is None:
        raise ValueError("missing IHDR")
    if bit_depth != 8:
        raise ValueError(f"unsupported bit depth {bit_depth}")
    if color_type != 6:
        raise ValueError(f"unsupported PNG color type {color_type}; expected RGBA")

    raw = zlib.decompress(bytes(idat))
    bytes_per_pixel = 4
    stride = width * bytes_per_pixel
    rows: list[bytes] = []
    prev = bytearray(stride)
    cursor = 0

    for _ in range(height):
        filter_type = raw[cursor]
        cursor += 1
        scanline = bytearray(raw[cursor : cursor + stride])
        cursor += stride

        for i, value in enumerate(scanline):
            left = scanline[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
            up = prev[i]
            up_left = prev[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
            if filter_type == 0:
                reconstructed = value
            elif filter_type == 1:
                reconstructed = value + left
            elif filter_type == 2:
                reconstructed = value + up
            elif filter_type == 3:
                reconstructed = value + ((left + up) // 2)
            elif filter_type == 4:
                reconstructed = value + paeth(left, up, up_left)
            else:
                raise ValueError(f"unsupported PNG filter {filter_type}")
            scanline[i] = reconstructed & 0xFF

        rows.append(bytes(scanline))
        prev = scanline

    pixels: list[tuple[int, int, int, int]] = []
    for row in rows:
        for i in range(0, len(row), bytes_per_pixel):
            pixels.append((row[i], row[i + 1], row[i + 2], row[i + 3]))
    return width, height, pixels


def audit_sample_path(path: Path, tmp_dir: Path, max_dimension: int = 512) -> Path:
    width, height, _, _ = read_png_header(path)
    if max(width, height) <= max_dimension:
        return path

    sample = tmp_dir / path.name
    command = [
        "sips",
        "-s",
        "format",
        "png",
        "--resampleHeightWidthMax",
        str(max_dimension),
        str(path),
        "--out",
        str(sample),
    ]
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return sample


def paeth(left: int, up: int, up_left: int) -> int:
    estimate = left + up - up_left
    left_distance = abs(estimate - left)
    up_distance = abs(estimate - up)
    up_left_distance = abs(estimate - up_left)
    if left_distance <= up_distance and left_distance <= up_left_distance:
        return left
    if up_distance <= up_left_distance:
        return up
    return up_left


def parse_svg_aspect_ratio(path: Path | None) -> float | None:
    if path is None or not path.exists():
        return None
    text = path.read_text(encoding="utf-8", errors="ignore")
    view_box = re.search(r"viewBox=[\"']\s*([\-0-9.]+)\s+([\-0-9.]+)\s+([\-0-9.]+)\s+([\-0-9.]+)\s*[\"']", text)
    if view_box:
        width = float(view_box.group(3))
        height = float(view_box.group(4))
        if width > 0 and height > 0:
            return width / height

    width_match = re.search(r"\bwidth=[\"']([0-9.]+)", text)
    height_match = re.search(r"\bheight=[\"']([0-9.]+)", text)
    if width_match and height_match:
        width = float(width_match.group(1))
        height = float(height_match.group(1))
        if width > 0 and height > 0:
            return width / height
    return None


def source_svg_for(render_asset: Path) -> Path | None:
    name = render_asset.name
    if name.endswith(".svg.png"):
        source = render_asset.with_name(name[:-4])
        return source if source.exists() else None
    source = render_asset.with_suffix(".svg")
    return source if source.exists() else None


def logical_name(path: Path) -> str:
    return path.name.split(".", 1)[0]


def is_white(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > LOW_ALPHA_THRESHOLD and red >= WHITE_THRESHOLD and green >= WHITE_THRESHOLD and blue >= WHITE_THRESHOLD


def is_visible_nonwhite(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha <= LOW_ALPHA_THRESHOLD:
        return False
    return not (red >= WHITE_THRESHOLD and green >= WHITE_THRESHOLD and blue >= WHITE_THRESHOLD)


def dominant_color(pixels: list[tuple[int, int, int, int]]) -> str | None:
    visible = [pixel for pixel in pixels if pixel[3] > LOW_ALPHA_THRESHOLD]
    if not visible:
        return None
    buckets = Counter(
        (
            (pixel[0] // 16) * 16,
            (pixel[1] // 16) * 16,
            (pixel[2] // 16) * 16,
            (pixel[3] // 16) * 16,
        )
        for pixel in visible
    )
    red, green, blue, alpha = buckets.most_common(1)[0][0]
    return f"rgba({red},{green},{blue},{alpha})"


def audit_png(path: Path) -> dict[str, Any]:
    source = source_svg_for(path)
    source_aspect = parse_svg_aspect_ratio(source)
    record: dict[str, Any] = {
        "iconName": logical_name(path),
        "filePath": str(path),
        "sourceSvgPath": str(source) if source else None,
        "renderAssetPath": str(path),
        "width": 0,
        "height": 0,
        "alphaNonZeroRatio": 0.0,
        "nonWhitePixelRatio": 0.0,
        "nonTransparentPixelCount": 0,
        "dominantColor": None,
        "hasWhiteBackground": False,
        "isAllWhite": False,
        "isAllTransparent": False,
        "aspectRatio": None,
        "sourceViewBoxAspectRatio": source_aspect,
        "status": "fail",
        "failures": [],
    }

    try:
        width, height, _, _ = read_png_header(path)
        with tempfile.TemporaryDirectory(prefix="finspan-icon-audit-") as tmp_dir:
            _, _, pixels = read_png_rgba(audit_sample_path(path, Path(tmp_dir)))
    except Exception as error:  # noqa: BLE001 - report every decode failure.
        record["failures"].append(f"decode:{error}")
        return record

    total = max(len(pixels), 1)
    visible = [pixel for pixel in pixels if pixel[3] > LOW_ALPHA_THRESHOLD]
    nonwhite = [pixel for pixel in pixels if is_visible_nonwhite(pixel)]
    white = [pixel for pixel in pixels if is_white(pixel)]
    alpha_ratio = len(visible) / total
    nonwhite_ratio = len(nonwhite) / total
    white_ratio = len(white) / total
    aspect = width / height if height else None

    record.update(
        {
            "width": width,
            "height": height,
            "alphaNonZeroRatio": round(alpha_ratio, 6),
            "nonWhitePixelRatio": round(nonwhite_ratio, 6),
            "nonTransparentPixelCount": len(visible),
            "dominantColor": dominant_color(pixels),
            "hasWhiteBackground": alpha_ratio > 0.97 and white_ratio > 0.75,
            "isAllWhite": alpha_ratio > 0.97 and nonwhite_ratio < 0.01,
            "isAllTransparent": len(visible) == 0,
            "aspectRatio": round(aspect, 6) if aspect else None,
        }
    )

    failures: list[str] = []
    if width <= 0 or height <= 0:
        failures.append("empty dimensions")
    if min(width, height) < MIN_RENDER_DIMENSION or max(width, height) < MIN_MAX_DIMENSION:
        failures.append("render asset too small")
    if record["isAllTransparent"]:
        failures.append("all transparent")
    if record["isAllWhite"]:
        failures.append("all or nearly all white")
    if record["hasWhiteBackground"]:
        failures.append("opaque white background")
    if nonwhite_ratio <= 0.002:
        failures.append("too few visible non-white pixels")
    if source_aspect and aspect and not math.isclose(aspect, source_aspect, rel_tol=0.08, abs_tol=0.08):
        failures.append("aspect ratio does not match source viewBox")

    record["failures"] = failures
    record["status"] = "ok" if not failures else "fail"
    return record


def main() -> int:
    args = with_cli_args()
    icon_dir = args.icon_dir
    render_assets = sorted(icon_dir.glob("*.png"))
    records = [audit_png(path) for path in render_assets]
    failures = [record for record in records if record["status"] != "ok"]
    report = {
        "iconDirectory": str(icon_dir),
        "totalRenderAssets": len(records),
        "ok": len(records) - len(failures),
        "fail": len(failures),
        "records": records,
    }

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")

    if args.json_output:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(
            f"Card icon renderability: {report['ok']} ok / {report['totalRenderAssets']} total; "
            f"{report['fail']} failed"
        )
        print(f"Report: {args.report}")
        for record in failures[:40]:
            failures_text = ", ".join(record["failures"])
            print(f"FAIL {record['iconName']} {Path(record['filePath']).name}: {failures_text}")
        if len(failures) > 40:
            print(f"... {len(failures) - 40} additional failures omitted")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
