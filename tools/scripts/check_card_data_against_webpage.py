#!/usr/bin/env python3
"""Compare runtime card JSON against the saved finsearch webpage bundle."""

from __future__ import annotations

import argparse
import ast
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WEBPAGE_ROOT = REPO_ROOT / "references/webpage"
DEFAULT_RUNTIME_CARDS_ROOT = REPO_ROOT / "Finspan/Resources/Cards"
DEFAULT_REPORT_PATH = REPO_ROOT / "build/reports/card_data_source_check.json"
DOCS_TO_VALIDATE = [
    REPO_ROOT / "docs/ABILITY_COVERAGE_AUDIT.md",
    REPO_ROOT / "docs/ABILITY_RULE_CONFIRMATION_QUESTIONS.md",
    REPO_ROOT / "docs/GAME_END_ABILITY_COVERAGE.md",
]
RUNTIME_JSON_FILENAMES = [
    "base_main_fish_cards.json",
    "base_starter_fish_cards.json",
    "sharks_reefs_main_fish_cards.json",
    "sharks_reefs_starter_fish_cards.json",
]
TAG_FIELDS = [
    "Bioluminescent",
    "Camouflage",
    "Electric",
    "Predator",
    "Venomous",
]
TRIGGER_MAP = {
    "WhenPlayed": "whenPlayed",
    "IfActivated": "ifActivated",
    "GameEnd": "gameEnd",
}


def relative_path(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def empty_to_none(value: object) -> object:
    if value == "":
        return None
    return value


def length_bucket(length_cm: int | None) -> str | None:
    if length_cm is None:
        return None
    if length_cm < 50:
        return "small"
    if length_cm < 150:
        return "medium"
    return "large"


def trailing_numeric_id(card_id: str) -> int | None:
    match = re.search(r"(\d+)$", card_id)
    if not match:
        return None
    return int(match.group(1))


def canonical_card_id(expansion: str, group: str, source_id: int) -> str:
    return f"{expansion}.{group}.{source_id:03d}"


def extract_tokens(text: str | None) -> list[str]:
    if not text:
        return []
    return re.findall(r"\[([^\]]+)\]", text)


def normalize_runtime_text(value: object) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        return value or None
    if isinstance(value, dict):
        for key in ("raw", "en", "zh"):
            text = value.get(key)
            if isinstance(text, str) and text:
                return text
        return None
    return None


def normalize_runtime_name(value: object) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return value.get("en") or value.get("zh") or ""
    return ""


def normalize_webpage_costs(raw_card: dict) -> list[dict[str, object]]:
    costs: list[dict[str, object]] = []
    if raw_card.get("cardCost"):
        costs.append({"kind": "discardCards", "count": raw_card["cardCost"]})
    if raw_card.get("eggCost"):
        costs.append({"kind": "resource", "resource": "egg", "count": raw_card["eggCost"]})
    if raw_card.get("youngCost"):
        costs.append({"kind": "resource", "resource": "young", "count": raw_card["youngCost"]})
    if raw_card.get("schoolFishCost"):
        costs.append({"kind": "resource", "resource": "school", "count": raw_card["schoolFishCost"]})
    if raw_card.get("consuming"):
        costs.append({"kind": "coverShorterFish", "count": raw_card["consuming"]})
    if raw_card.get("coralCost") is not None:
        costs.append({"kind": "coralRequirementOrCost", "count": raw_card["coralCost"]})
    return costs


def normalize_runtime_costs(raw_card: dict) -> list[dict[str, object]]:
    costs: list[dict[str, object]] = []
    for cost in raw_card.get("costs", []):
        normalized = {
            "kind": cost["kind"],
            "count": cost.get("count"),
        }
        if "resource" in cost:
            normalized["resource"] = cost.get("resource")
        costs.append(normalized)
    return costs


def normalize_webpage_card(
    raw_card: dict,
    *,
    fish_asset_ids_in_bundle: set[int],
    fish_asset_ids_saved_in_snapshot: set[int],
    local_fish_asset_ids: set[int],
) -> dict[str, object]:
    source_id = int(raw_card["id"])
    expansion = raw_card["expansion"]
    group = raw_card["group"]
    name = raw_card["name"]
    ability_text = empty_to_none(raw_card.get("ability"))
    tags = {tag.lower(): int(raw_card[tag]) for tag in TAG_FIELDS if raw_card.get(tag)}
    allowed_zones = [
        zone
        for zone in ("sunlight", "twilight", "midnight")
        if raw_card.get(zone)
    ]

    return {
        "canonical_id": canonical_card_id(expansion, group, source_id),
        "source_id": source_id,
        "numeric_id": source_id,
        "expansion": expansion,
        "group": group,
        "name": name,
        "scientific_name": empty_to_none(raw_card.get("latin")),
        "trigger": TRIGGER_MAP.get(raw_card.get("abilityType"), raw_card.get("abilityType")),
        "ability_text": ability_text,
        "ability_tokens": extract_tokens(ability_text if isinstance(ability_text, str) else None),
        "printed_points": raw_card.get("points"),
        "length_cm": raw_card.get("length"),
        "length_bucket": length_bucket(raw_card.get("length")),
        "allowed_zones": allowed_zones,
        "required_dive_site_color": empty_to_none(raw_card.get("band")),
        "tags": sorted(tags),
        "tag_counts": tags,
        "costs": normalize_webpage_costs(raw_card),
        "coral_requirement_or_cost": raw_card.get("coralCost"),
        "fish_image_asset": f"{source_id}.webp",
        "fish_image_referenced_by_bundle": source_id in fish_asset_ids_in_bundle,
        "fish_image_saved_in_snapshot": source_id in fish_asset_ids_saved_in_snapshot,
        "fish_image_present_in_local_assets": source_id in local_fish_asset_ids,
        "raw_ability_type": raw_card.get("abilityType"),
        "raw": raw_card,
    }


def normalize_runtime_card(raw_card: dict, *, local_fish_asset_ids: set[int]) -> dict[str, object]:
    source_id = raw_card.get("sourceId") or trailing_numeric_id(raw_card["id"])
    fish_image_asset = None
    if raw_card.get("visualAssetName"):
        fish_image_asset = f"{raw_card['visualAssetName']}.webp"
    elif isinstance(raw_card.get("visual"), dict) and raw_card["visual"].get("fishImageAsset"):
        fish_image_asset = raw_card["visual"]["fishImageAsset"]
    elif source_id is not None:
        fish_image_asset = f"{source_id}.webp"

    tags = {
        tag["kind"]: tag.get("count", 1)
        for tag in raw_card.get("tags", [])
    }
    ability_text = normalize_runtime_text(raw_card.get("abilityText"))
    expansion = raw_card.get("set")
    if expansion is None:
        expansion = "sr" if raw_card.get("expansion") == "sharks_reefs" else raw_card.get("expansion")

    return {
        "canonical_id": raw_card["id"],
        "source_id": source_id,
        "numeric_id": source_id,
        "expansion": expansion,
        "group": raw_card.get("group"),
        "name": normalize_runtime_name(raw_card.get("name")),
        "scientific_name": empty_to_none(raw_card.get("scientificName")),
        "trigger": raw_card.get("abilityTrigger"),
        "ability_text": ability_text,
        "ability_tokens": extract_tokens(ability_text),
        "printed_points": raw_card.get("printedPoints"),
        "length_cm": raw_card.get("lengthCm"),
        "length_bucket": length_bucket(raw_card.get("lengthCm")),
        "allowed_zones": raw_card.get("allowedZones", []),
        "required_dive_site_color": raw_card.get("requiredDiveSiteColor"),
        "tags": sorted(tags),
        "tag_counts": tags,
        "costs": normalize_runtime_costs(raw_card),
        "coral_requirement_or_cost": next(
            (
                cost.get("count")
                for cost in raw_card.get("costs", [])
                if cost.get("kind") == "coralRequirementOrCost"
            ),
            None,
        ),
        "fish_image_asset": fish_image_asset,
        "fish_image_present_in_local_assets": (source_id in local_fish_asset_ids) if source_id is not None else False,
        "raw": raw_card,
    }


def load_runtime_cards(runtime_cards_root: Path) -> tuple[list[dict], dict[str, int]]:
    cards: list[dict] = []
    counts: dict[str, int] = {}
    for filename in RUNTIME_JSON_FILENAMES:
        path = runtime_cards_root / filename
        if not path.exists():
            raise FileNotFoundError(f"Missing runtime card JSON: {path}")
        decoded = json.loads(path.read_text(encoding="utf-8"))
        counts[filename] = len(decoded)
        cards.extend(decoded)
    return cards, counts


def discover_webpage_candidates(webpage_root: Path) -> list[dict[str, object]]:
    candidates: list[dict[str, object]] = []
    for path in sorted(webpage_root.rglob("*.js")):
        text = path.read_text(encoding="utf-8", errors="ignore")
        module_matches = list(
            re.finditer(
                r"(?P<module>\d+):e=>\{\"use strict\";e\.exports=JSON\.parse\('(?P<payload>.+?)'\)\}",
                text,
            )
        )
        if not module_matches:
            continue

        for match in module_matches:
            try:
                json_text = ast.literal_eval("'" + match.group("payload") + "'")
                cards = json.loads(json_text)
            except Exception as error:  # pragma: no cover - defensive CLI handling
                candidates.append(
                    {
                        "path": path,
                        "module": int(match.group("module")),
                        "card_count": 0,
                        "error": str(error),
                    }
                )
                continue

            if isinstance(cards, list) and cards and isinstance(cards[0], dict):
                candidates.append(
                    {
                        "path": path,
                        "module": int(match.group("module")),
                        "card_count": len(cards),
                        "cards": cards,
                    }
                )
    return candidates


def extract_bundle_media_fish_ids(js_text: str) -> set[int]:
    media_names = set(re.findall(r"static/media/([^\"']+)", js_text))
    fish_ids: set[int] = set()
    for name in media_names:
        filename = Path(name).name
        stem = filename.split(".", maxsplit=1)[0]
        if stem.isdigit() and filename.endswith(".webp"):
            fish_ids.add(int(stem))
    return fish_ids


def collect_saved_snapshot_fish_ids(webpage_root: Path) -> set[int]:
    fish_ids: set[int] = set()
    for path in webpage_root.rglob("*.webp"):
        stem = path.name.split(".", maxsplit=1)[0]
        if stem.isdigit():
            fish_ids.add(int(stem))
    return fish_ids


def collect_local_runtime_fish_ids(repo_root: Path) -> set[int]:
    fish_dir = repo_root / "Finspan/Resources/CardAssets/fish"
    fish_ids: set[int] = set()
    for path in fish_dir.glob("*.webp"):
        stem = path.name.split(".", maxsplit=1)[0]
        if stem.isdigit():
            fish_ids.add(int(stem))
    return fish_ids


def compare_fields(
    runtime_cards: dict[str, dict[str, object]],
    webpage_cards: dict[str, dict[str, object]],
) -> dict[str, list[dict[str, object]]]:
    fields = [
        "source_id",
        "numeric_id",
        "expansion",
        "group",
        "name",
        "scientific_name",
        "trigger",
        "ability_text",
        "ability_tokens",
        "printed_points",
        "length_cm",
        "length_bucket",
        "allowed_zones",
        "required_dive_site_color",
        "tags",
        "tag_counts",
        "costs",
        "coral_requirement_or_cost",
        "fish_image_asset",
    ]
    mismatches: dict[str, list[dict[str, object]]] = {field: [] for field in fields}
    for card_id in sorted(runtime_cards.keys() & webpage_cards.keys()):
        runtime_card = runtime_cards[card_id]
        webpage_card = webpage_cards[card_id]
        for field in fields:
            if runtime_card[field] != webpage_card[field]:
                mismatches[field].append(
                    {
                        "card_id": card_id,
                        "runtime": runtime_card[field],
                        "webpage": webpage_card[field],
                    }
                )
    return mismatches


def validate_doc_references(
    runtime_cards: dict[str, dict[str, object]],
    webpage_cards: dict[str, dict[str, object]],
) -> dict[str, object]:
    results: dict[str, object] = {"docs": {}}
    total_missing_runtime = 0
    total_missing_webpage = 0
    total_name_mismatches = 0
    total_ability_mismatches = 0

    for doc_path in DOCS_TO_VALIDATE:
        lines = doc_path.read_text(encoding="utf-8").splitlines()
        referenced_ids: list[dict[str, object]] = []
        missing_runtime: list[dict[str, object]] = []
        missing_webpage: list[dict[str, object]] = []
        name_mismatches: list[dict[str, object]] = []
        ability_mismatches: list[dict[str, object]] = []

        for line_number, line in enumerate(lines, start=1):
            ids = sorted(set(re.findall(r"\b(?:base|sr)\.(?:main|starter)\.\d{3}\b", line)))
            for card_id in ids:
                record = {
                    "line": line_number,
                    "card_id": card_id,
                    "text": line.strip(),
                }
                referenced_ids.append(record)
                runtime_card = runtime_cards.get(card_id)
                webpage_card = webpage_cards.get(card_id)
                if runtime_card is None:
                    missing_runtime.append(record)
                    total_missing_runtime += 1
                    continue
                if webpage_card is None:
                    missing_webpage.append(record)
                    total_missing_webpage += 1

                name_match = re.search(
                    rf"`{re.escape(card_id)}`\s+([A-Z][A-Za-z0-9'&/ -]+)",
                    line,
                )
                if name_match:
                    stated_name = name_match.group(1).strip()
                    if stated_name != runtime_card["name"]:
                        name_mismatches.append(
                            {
                                **record,
                                "stated_name": stated_name,
                                "runtime_name": runtime_card["name"],
                            }
                        )
                        total_name_mismatches += 1

                ability_match = re.search(r",\s*`([^`]*\[[^`]+\][^`]*)`", line)
                if ability_match:
                    stated_ability = ability_match.group(1).strip()
                    runtime_ability = runtime_card["ability_text"] or ""
                    if stated_ability != runtime_ability:
                        ability_mismatches.append(
                            {
                                **record,
                                "stated_ability": stated_ability,
                                "runtime_ability": runtime_ability,
                            }
                        )
                        total_ability_mismatches += 1

        results["docs"][relative_path(doc_path)] = {
            "referenced_id_count": len(referenced_ids),
            "missing_in_runtime": missing_runtime,
            "missing_in_webpage": missing_webpage,
            "name_mismatches": name_mismatches,
            "ability_mismatches": ability_mismatches,
        }

    results["summary"] = {
        "missing_in_runtime": total_missing_runtime,
        "missing_in_webpage": total_missing_webpage,
        "name_mismatches": total_name_mismatches,
        "ability_mismatches": total_ability_mismatches,
    }
    return results


def counts_by(cards: list[dict[str, object]], key: str) -> dict[str, int]:
    return dict(sorted(Counter(str(card[key]) for card in cards).items()))


def collect_special_cases(
    runtime_cards: dict[str, dict[str, object]],
    webpage_cards: dict[str, dict[str, object]],
    webpage_root: Path,
) -> dict[str, object]:
    rope_fish_in_runtime = [
        card["canonical_id"]
        for card in runtime_cards.values()
        if card["name"] == "Rope Fish"
    ]
    rope_fish_in_webpage = [
        card["canonical_id"]
        for card in webpage_cards.values()
        if card["name"] == "Rope Fish"
    ]
    rope_fish_text_hits: list[str] = []
    for path in webpage_root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in {".html", ".js", ".css", ".json", ".txt", ".md"}:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        if "Rope Fish" in text:
            rope_fish_text_hits.append(relative_path(path))

    card_096_runtime = runtime_cards.get("base.main.096")
    card_096_webpage = webpage_cards.get("base.main.096")

    return {
        "rope_fish": {
            "runtime_card_ids": rope_fish_in_runtime,
            "webpage_card_ids": rope_fish_in_webpage,
            "webpage_text_hits": rope_fish_text_hits,
        },
        "base_main_096": {
            "runtime_name": card_096_runtime["name"] if card_096_runtime else None,
            "runtime_ability_text": card_096_runtime["ability_text"] if card_096_runtime else None,
            "runtime_source_id": card_096_runtime["source_id"] if card_096_runtime else None,
            "webpage_name": card_096_webpage["name"] if card_096_webpage else None,
            "webpage_ability_text": card_096_webpage["ability_text"] if card_096_webpage else None,
            "webpage_source_id": card_096_webpage["source_id"] if card_096_webpage else None,
        },
    }


def same_name_different_id(cards: dict[str, dict[str, object]]) -> list[dict[str, object]]:
    ids_by_name: dict[str, list[str]] = defaultdict(list)
    for card_id, card in cards.items():
        ids_by_name[str(card["name"])].append(card_id)
    return [
        {"name": name, "card_ids": sorted(card_ids)}
        for name, card_ids in sorted(ids_by_name.items())
        if len(card_ids) > 1
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--webpage-root", type=Path, default=DEFAULT_WEBPAGE_ROOT)
    parser.add_argument("--runtime-cards-root", type=Path, default=DEFAULT_RUNTIME_CARDS_ROOT)
    parser.add_argument("--report-out", type=Path, default=DEFAULT_REPORT_PATH)
    args = parser.parse_args()

    webpage_root = args.webpage_root.resolve()
    runtime_cards_root = args.runtime_cards_root.resolve()
    report_out = args.report_out.resolve()

    runtime_raw_cards, runtime_file_counts = load_runtime_cards(runtime_cards_root)
    candidates = discover_webpage_candidates(webpage_root)
    if not candidates:
        print("Failed: no webpage card-data candidate JS bundles found.", file=sys.stderr)
        return 1

    successful_candidates = [candidate for candidate in candidates if candidate.get("card_count", 0) > 0]
    if not successful_candidates:
        print("Failed: found JS candidates, but none could be decoded into card data.", file=sys.stderr)
        return 1

    selected_candidate = max(successful_candidates, key=lambda candidate: int(candidate["card_count"]))
    js_path = Path(selected_candidate["path"])
    js_text = js_path.read_text(encoding="utf-8", errors="ignore")
    webpage_raw_cards = selected_candidate["cards"]

    fish_asset_ids_in_bundle = extract_bundle_media_fish_ids(js_text)
    fish_asset_ids_saved_in_snapshot = collect_saved_snapshot_fish_ids(webpage_root)
    local_fish_asset_ids = collect_local_runtime_fish_ids(REPO_ROOT)

    runtime_cards_list = [
        normalize_runtime_card(card, local_fish_asset_ids=local_fish_asset_ids)
        for card in runtime_raw_cards
    ]
    webpage_cards_list = [
        normalize_webpage_card(
            card,
            fish_asset_ids_in_bundle=fish_asset_ids_in_bundle,
            fish_asset_ids_saved_in_snapshot=fish_asset_ids_saved_in_snapshot,
            local_fish_asset_ids=local_fish_asset_ids,
        )
        for card in webpage_raw_cards
    ]

    runtime_cards = {card["canonical_id"]: card for card in runtime_cards_list}
    webpage_cards = {card["canonical_id"]: card for card in webpage_cards_list}

    runtime_only_cards = sorted(runtime_cards.keys() - webpage_cards.keys())
    webpage_only_cards = sorted(webpage_cards.keys() - runtime_cards.keys())
    field_mismatches = compare_fields(runtime_cards, webpage_cards)
    doc_validation = validate_doc_references(runtime_cards, webpage_cards)
    special_cases = collect_special_cases(runtime_cards, webpage_cards, webpage_root)

    local_missing_fish_assets = sorted(
        card_id
        for card_id, card in runtime_cards.items()
        if not card["fish_image_present_in_local_assets"]
    )

    bundle_missing_fish_refs = sorted(
        card_id
        for card_id, card in webpage_cards.items()
        if not card["fish_image_referenced_by_bundle"]
    )

    summary = {
        "runtime_total_cards": len(runtime_cards),
        "webpage_total_cards": len(webpage_cards),
        "shared_cards": len(runtime_cards.keys() & webpage_cards.keys()),
        "runtime_only_cards": len(runtime_only_cards),
        "webpage_only_cards": len(webpage_only_cards),
        "field_mismatch_counts": {
            field: len(entries)
            for field, entries in field_mismatches.items()
        },
        "representative_doc_issues": doc_validation["summary"],
        "runtime_counts_by_expansion": counts_by(runtime_cards_list, "expansion"),
        "runtime_counts_by_group": counts_by(runtime_cards_list, "group"),
        "webpage_counts_by_expansion": counts_by(webpage_cards_list, "expansion"),
        "webpage_counts_by_group": counts_by(webpage_cards_list, "group"),
        "bundle_fish_asset_refs": len(fish_asset_ids_in_bundle),
        "saved_snapshot_fish_assets": len(fish_asset_ids_saved_in_snapshot),
        "local_runtime_fish_assets": len(local_fish_asset_ids),
        "local_missing_fish_assets": len(local_missing_fish_assets),
        "bundle_missing_fish_refs": len(bundle_missing_fish_refs),
    }

    report = {
        "paths": {
            "repo_root": str(REPO_ROOT),
            "webpage_root": str(webpage_root),
            "runtime_cards_root": str(runtime_cards_root),
            "selected_webpage_js": str(js_path),
            "selected_webpage_module": selected_candidate["module"],
            "report_out": str(report_out),
        },
        "runtime_source_files": runtime_file_counts,
        "webpage_candidate_files": [
            {
                "path": relative_path(Path(candidate["path"])),
                "module": candidate.get("module"),
                "card_count": candidate.get("card_count", 0),
                "error": candidate.get("error"),
            }
            for candidate in candidates
        ],
        "summary": summary,
        "runtime_only_cards": runtime_only_cards,
        "webpage_only_cards": webpage_only_cards,
        "field_mismatches": field_mismatches,
        "local_asset_checks": {
            "bundle_fish_asset_ids": sorted(fish_asset_ids_in_bundle),
            "saved_snapshot_fish_asset_ids": sorted(fish_asset_ids_saved_in_snapshot),
            "local_runtime_fish_asset_ids": sorted(local_fish_asset_ids),
            "local_missing_fish_assets": local_missing_fish_assets,
            "bundle_missing_fish_refs": bundle_missing_fish_refs,
        },
        "id_name_cross_checks": {
            "same_name_different_runtime_ids": same_name_different_id(runtime_cards),
            "same_name_different_webpage_ids": same_name_different_id(webpage_cards),
        },
        "doc_validation": doc_validation,
        "special_cases": special_cases,
    }

    report_out.parent.mkdir(parents=True, exist_ok=True)
    report_out.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    mismatch_total = sum(len(entries) for entries in field_mismatches.values())
    doc_issue_total = sum(int(value) for value in doc_validation["summary"].values())
    failed = any(
        [
            runtime_only_cards,
            webpage_only_cards,
            mismatch_total,
            doc_issue_total,
            local_missing_fish_assets,
            bundle_missing_fish_refs,
        ]
    )

    print(f"Using webpage source: {relative_path(js_path)} (module {selected_candidate['module']})")
    print(f"Runtime cards: {len(runtime_cards)}")
    print(f"Webpage cards: {len(webpage_cards)}")
    print(f"Shared cards: {len(runtime_cards.keys() & webpage_cards.keys())}")
    print(f"Runtime-only cards: {len(runtime_only_cards)}")
    print(f"Webpage-only cards: {len(webpage_only_cards)}")
    print(f"Field mismatches: {mismatch_total}")
    print(
        "Doc reference issues:",
        sum(int(value) for value in doc_validation["summary"].values()),
    )
    print(
        "Fish assets:",
        f"bundle refs {len(fish_asset_ids_in_bundle)},",
        f"saved snapshot files {len(fish_asset_ids_saved_in_snapshot)},",
        f"local runtime assets {len(local_fish_asset_ids)}",
    )
    print(
        "Rope Fish:",
        "absent from runtime and webpage card data"
        if not special_cases["rope_fish"]["runtime_card_ids"] and not special_cases["rope_fish"]["webpage_card_ids"]
        else "present",
    )
    print(
        "base.main.096:",
        f"{special_cases['base_main_096']['runtime_name']} / {special_cases['base_main_096']['runtime_ability_text']}",
    )
    print(f"Wrote report: {relative_path(report_out)}")

    if failed:
        print("Card data source check found discrepancies. See the JSON report for details.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
