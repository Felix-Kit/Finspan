#!/usr/bin/env python3
"""Extract finsearch card renderer facts from a saved webpage bundle."""

from __future__ import annotations

import ast
import json
import re
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WEBPAGE_ROOT = Path("/Users/work/Finspan/references/webpage")
OUTPUT_PATH = REPO_ROOT / "tools/generated/assets/card_renderer_analysis.json"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_json_cards(js: str) -> list[dict]:
    match = re.search(r"4656:e=>\{\"use strict\";e\.exports=JSON\.parse\('(.+?)'\)\}", js)
    if not match:
        return []
    js_string_literal = "'" + match.group(1) + "'"
    json_text = ast.literal_eval(js_string_literal)
    return json.loads(json_text)


def extract_context_keys(js: str, module_id: int) -> list[str]:
    pattern = rf"{module_id}:\(e,t,n\)=>\{{var o=\{{(.+?)\}};function i"
    match = re.search(pattern, js)
    if not match:
        return []
    return re.findall(r'"(\./[^"]+)"\s*:', match.group(1))


def extract_static_media_exports(js: str, extensions: tuple[str, ...]) -> list[str]:
    escaped_exts = "|".join(re.escape(ext) for ext in extensions)
    pattern = rf'static/media/[^"]+(?:{escaped_exts})'
    return sorted(set(re.findall(pattern, js)))


def extract_css_rule(css: str, selector: str) -> str | None:
    pattern = re.escape(selector) + r"\{([^{}]*)\}"
    match = re.search(pattern, css)
    if not match:
        return None
    return match.group(1)


def image_dimensions(path: Path) -> dict[str, int] | None:
    if not path.exists():
        return None
    result = subprocess.run(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    width_match = re.search(r"pixelWidth:\s*(\d+)", result.stdout)
    height_match = re.search(r"pixelHeight:\s*(\d+)", result.stdout)
    if not width_match or not height_match:
        return None
    return {
        "width": int(width_match.group(1)),
        "height": int(height_match.group(1)),
    }


def main() -> None:
    webpage_root = DEFAULT_WEBPAGE_ROOT
    files_dir = webpage_root / "Finspan Card Search_files"
    html_path = webpage_root / "Finspan Card Search.html"
    js_path = files_dir / "main.3f6711eb.js"
    css_path = files_dir / "main.f74b3868.css"

    js = read_text(js_path)
    css = read_text(css_path)
    html = read_text(html_path)
    cards = extract_json_cards(js)

    card_backgrounds = [
        "base.f121413876c92b0271f4.webp",
        "blue.b9baf436df4033049f53.webp",
        "purple.c493ffc8ca41cab3da6f.webp",
        "green.374d1a75825b118218bc.webp",
    ]
    ability_backgrounds = [
        "IfActivated.f4ec95e03e7c3189135e.png",
        "GameEnd.1c86787c5a74319ee78f.png",
    ]
    dimensions = {}
    for filename in card_backgrounds + ability_backgrounds:
        path = REPO_ROOT / "Finspan/Resources/CardAssets/backgrounds" / filename
        dimensions[filename] = image_dimensions(path)

    css_selectors = [
        ".card",
        ".name",
        ".name .title",
        ".name .latin",
        ".cost",
        ".cost img",
        ".zones",
        ".zones img",
        ".points",
        ".length",
        ".ability-container",
        ".ability-container .ability",
        ".description",
        ".silhouette",
        ".corner-overlay",
        ".top-left",
        ".bottom-right",
    ]

    analysis = {
        "sourceFiles": {
            "html": str(html_path),
            "javascript": str(js_path),
            "css": str(css_path),
            "sourceMapsFound": sorted(str(path) for path in webpage_root.rglob("*.map")),
        },
        "savedWebpageFileCounts": {
            "topLevelFiles": len(list(files_dir.glob("*"))),
            "webp": len(list(files_dir.glob("*.webp"))),
            "svg": len(list(files_dir.glob("*.svg"))),
            "font": len(list(files_dir.glob("*.woff")))
            + len(list(files_dir.glob("*.otf")))
            + len(list(files_dir.glob("*.ttf"))),
        },
        "bundleFacts": {
            "cardDataCount": len(cards),
            "mainCards": sum(1 for card in cards if card.get("group") == "main"),
            "starterCards": sum(1 for card in cards if card.get("group") == "starter"),
            "baseCards": sum(1 for card in cards if card.get("expansion") == "base"),
            "sharksAndReefsCards": sum(1 for card in cards if card.get("expansion") == "sr"),
            "fishImageContextKeys": extract_context_keys(js, 9230),
            "iconContextKeys": extract_context_keys(js, 6669),
            "backgroundWebpContextKeys": extract_context_keys(js, 8488),
            "backgroundPngContextKeys": extract_context_keys(js, 1881),
        },
        "rendererFunctionNamesFromMinifiedBundle": {
            "D": "React card component",
            "b": "tag icons next to title",
            "y": "cost icons",
            "v": "zone icons and coral requirements",
            "C": "zone class string from sunlight/twilight/midnight",
            "w": "length bucket icon",
            "x": "card background from data.band or base",
            "A": "ability token parser",
            "F": "ability strip renderer",
            "E": "starter corner overlays",
        },
        "cssRules": {selector: extract_css_rule(css, selector) for selector in css_selectors},
        "assetDimensions": dimensions,
        "htmlContainsPreRenderedCards": 'class="card"' in html,
        "htmlLength": len(html),
        "jsLength": len(js),
        "cssLength": len(css),
        "staticMediaExports": extract_static_media_exports(js, (".webp", ".png", ".svg")),
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(analysis, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH}")
    print(
        "Cards:",
        analysis["bundleFacts"]["cardDataCount"],
        "fish images:",
        len(analysis["bundleFacts"]["fishImageContextKeys"]),
        "icons:",
        len(analysis["bundleFacts"]["iconContextKeys"]),
    )


if __name__ == "__main__":
    main()
