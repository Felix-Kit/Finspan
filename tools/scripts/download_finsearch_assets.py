#!/usr/bin/env python3
"""Download finsearch card assets into local app resources.

This is a development-time importer. Runtime Swift code must not depend on
finsearch URLs; downloaded files are copied into Finspan/Resources/CardAssets.
"""

from __future__ import annotations

import argparse
import http.client
import json
import re
import struct
import sys
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = REPO_ROOT / "tools/raw/finsearch/finsearch_assets_manifest.json"
SUMMARY_PATH = REPO_ROOT / "tools/generated/assets/asset_download_summary.json"
OUTPUT_DIRECTORIES = {
    "fishImage": REPO_ROOT / "Finspan/Resources/CardAssets/fish",
    "icon": REPO_ROOT / "Finspan/Resources/CardAssets/icons",
    "background": REPO_ROOT / "Finspan/Resources/CardAssets/backgrounds",
    "preview": REPO_ROOT / "Finspan/Resources/CardAssets/previews",
}
RUNTIME_RESOURCE_DIRS = [
    REPO_ROOT / "Finspan/Resources/Cards",
    REPO_ROOT / "Finspan/Resources/CardAssets",
]
REMOTE_MARKERS = [b"http://", b"https://", b"navarog.github.io", b"finsearch"]
SVG_REMOTE_ATTRIBUTE_PATTERN = re.compile(
    r"""\s+xmlns(?::[A-Za-z0-9_-]+)?=(["'])https?://[^"']+\1"""
)


def classify_asset(item: dict[str, Any]) -> str:
    kind = str(item.get("kind") or "").lower()
    filename = str(item.get("filename") or "")
    lower = filename.lower()

    if kind == "fishimage":
        return "fishImage"
    if kind == "icon" or lower.endswith(".svg"):
        return "icon"
    if kind in {"cardbackgroundorband", "background"}:
        return "background"
    if any(token in lower for token in ["base.", "blue.", "purple.", "green.", "gameend.", "ifactivated.", "webpage."]):
        return "background"
    if any(token in lower for token in ["preview", "fullcard", "cardpreview"]):
        return "preview"
    if lower.endswith((".webp", ".png")):
        return "background"
    return "icon"


def output_path_for(item: dict[str, Any]) -> Path:
    category = classify_asset(item)
    return OUTPUT_DIRECTORIES[category] / str(item["filename"])


def png_dimensions(data: bytes) -> tuple[int, int] | None:
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", data[16:24])


def webp_dimensions(data: bytes) -> tuple[int, int] | None:
    if len(data) < 30 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        return None

    offset = 12
    while offset + 8 <= len(data):
        chunk = data[offset:offset + 4]
        size = struct.unpack("<I", data[offset + 4:offset + 8])[0]
        payload = data[offset + 8:offset + 8 + size]

        if chunk == b"VP8X" and len(payload) >= 10:
            width = 1 + int.from_bytes(payload[4:7], "little")
            height = 1 + int.from_bytes(payload[7:10], "little")
            return width, height
        if chunk == b"VP8 " and len(payload) >= 10:
            # Lossy bitstream frame header stores width/height after 0x9d012a.
            marker_index = payload.find(b"\x9d\x01\x2a")
            if marker_index >= 0 and marker_index + 7 <= len(payload):
                width = struct.unpack("<H", payload[marker_index + 3:marker_index + 5])[0] & 0x3FFF
                height = struct.unpack("<H", payload[marker_index + 5:marker_index + 7])[0] & 0x3FFF
                return width, height
        if chunk == b"VP8L" and len(payload) >= 5:
            bits = int.from_bytes(payload[1:5], "little")
            width = (bits & 0x3FFF) + 1
            height = ((bits >> 14) & 0x3FFF) + 1
            return width, height

        offset += 8 + size + (size % 2)
    return None


def image_dimensions(path: Path) -> tuple[int, int] | None:
    try:
        data = path.read_bytes()
    except OSError:
        return None
    lower = path.name.lower()
    if lower.endswith(".png"):
        return png_dimensions(data)
    if lower.endswith(".webp"):
        return webp_dimensions(data)
    return None


def scan_runtime_resources_for_remote_urls() -> dict[str, Any]:
    matches: list[str] = []
    for directory in RUNTIME_RESOURCE_DIRS:
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if not path.is_file():
                continue
            try:
                data = path.read_bytes()
            except OSError:
                continue
            if any(marker in data for marker in REMOTE_MARKERS):
                matches.append(str(path.relative_to(REPO_ROOT)))
    return {
        "found": bool(matches),
        "matches": matches,
    }


def runtime_asset_file_counts() -> dict[str, int]:
    return {
        key: sum(1 for path in directory.glob("*") if path.is_file())
        for key, directory in OUTPUT_DIRECTORIES.items()
    }


def infer_card_aspect_ratio(background_dimensions: dict[str, dict[str, int]]) -> float | None:
    for preferred in [
        "base.f121413876c92b0271f4.webp",
        "base.35519da28cd2f346a2ed.png",
    ]:
        dims = background_dimensions.get(preferred)
        if dims and dims["height"] > 0:
            return dims["width"] / dims["height"]
    for name, dims in sorted(background_dimensions.items()):
        lower = name.lower()
        if lower.startswith("base.") and dims["height"] > 0:
            return dims["width"] / dims["height"]
    return None


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "Finspan asset importer"})
    with urllib.request.urlopen(request, timeout=30) as response:
        destination.write_bytes(response.read())
    sanitize_svg(destination)


def sanitize_svg(path: Path) -> None:
    if path.suffix.lower() != ".svg" or not path.exists():
        return
    text = path.read_text(errors="ignore")
    sanitized = SVG_REMOTE_ATTRIBUTE_PATTERN.sub("", text)
    if sanitized != text:
        path.write_text(sanitized)


def sanitize_existing_svgs() -> None:
    for directory in OUTPUT_DIRECTORIES.values():
        if not directory.exists():
            continue
        for path in directory.rglob("*.svg"):
            sanitize_svg(path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Download finsearch assets into local resources.")
    parser.add_argument("--dry-run", action="store_true", help="Print planned downloads without fetching files.")
    parser.add_argument("--force", action="store_true", help="Redownload files even when they already exist.")
    args = parser.parse_args()

    items = json.loads(MANIFEST_PATH.read_text())
    for directory in OUTPUT_DIRECTORIES.values():
        directory.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.parent.mkdir(parents=True, exist_ok=True)

    downloaded = 0
    skipped = 0
    failed_assets: list[dict[str, str]] = []
    by_kind: Counter[str] = Counter()

    for item in items:
        category = classify_asset(item)
        by_kind[category] += 1
        destination = output_path_for(item)
        url = item.get("suggestedUrl")
        if not url:
            failed_assets.append({"filename": item.get("filename", ""), "reason": "missing suggestedUrl"})
            continue

        if destination.exists() and not args.force:
            skipped += 1
            print(f"skip existing {destination.relative_to(REPO_ROOT)}")
            continue

        if args.dry_run:
            print(f"would download {url} -> {destination.relative_to(REPO_ROOT)}")
            continue

        try:
            download(url, destination)
            downloaded += 1
            print(f"downloaded {destination.relative_to(REPO_ROOT)}")
        except (urllib.error.URLError, TimeoutError, OSError, http.client.IncompleteRead) as error:
            failed_assets.append({"filename": item.get("filename", ""), "url": url, "reason": str(error)})
            print(f"failed {url}: {error}", file=sys.stderr)

    sanitize_existing_svgs()

    background_dimensions: dict[str, dict[str, int]] = {}
    for path in OUTPUT_DIRECTORIES["background"].glob("*"):
        dims = image_dimensions(path)
        if dims:
            background_dimensions[path.name] = {"width": dims[0], "height": dims[1]}

    inferred_ratio = infer_card_aspect_ratio(background_dimensions)
    runtime_counts = runtime_asset_file_counts()
    summary = {
        "dryRun": args.dry_run,
        "totalAssets": len(items),
        "downloadedCount": downloaded,
        "skippedExistingCount": skipped,
        "presentAfterRunCount": sum(runtime_counts.values()),
        "failedCount": len(failed_assets),
        "byKind": dict(sorted(by_kind.items())),
        "runtimeAssetFileCounts": runtime_counts,
        "outputDirectories": {
            key: str(path.relative_to(REPO_ROOT))
            for key, path in OUTPUT_DIRECTORIES.items()
        },
        "failedAssets": failed_assets,
        "remoteUrlFoundInRuntimeResources": scan_runtime_resources_for_remote_urls(),
        "backgroundAssetDimensions": background_dimensions,
        "inferredCardAspectRatio": inferred_ratio,
    }
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
    print(f"summary: {SUMMARY_PATH.relative_to(REPO_ROOT)}")

    if failed_assets and not args.dry_run:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
