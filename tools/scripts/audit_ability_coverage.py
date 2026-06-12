#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CARD_FILES = [
    ROOT / "Finspan/Resources/Cards/base_main_fish_cards.json",
    ROOT / "Finspan/Resources/Cards/base_starter_fish_cards.json",
    ROOT / "Finspan/Resources/Cards/sharks_reefs_main_fish_cards.json",
    ROOT / "Finspan/Resources/Cards/sharks_reefs_starter_fish_cards.json",
]
REGISTRY_FILE = ROOT / "Finspan/Core/Rules/AbilityRegistry.swift"


def load_registry_ids() -> set[str]:
    text = REGISTRY_FILE.read_text(encoding="utf-8")
    return set(re.findall(r'"((?:unsupported|sample|sr|base)\.[^"]+)"', text))


def load_cards() -> list[dict]:
    cards: list[dict] = []
    for path in CARD_FILES:
        with path.open("r", encoding="utf-8") as handle:
            for card in json.load(handle):
                card = dict(card)
                card["_file"] = str(path.relative_to(ROOT))
                cards.append(card)
    return cards


def ability_status(card: dict, registry_ids: set[str]) -> str:
    ids = card.get("abilityIds") or []
    if not ids:
        return "unmapped"
    mapped = [ability_id for ability_id in ids if ability_id in registry_ids]
    if len(mapped) == len(ids):
        return "mapped"
    if mapped:
        return "mixed"
    if all(str(ability_id).startswith("unsupported.") for ability_id in ids):
        return "unsupported"
    return "unmapped"


def pattern_for(text: str) -> str:
    checks = [
        ("scoring-only GAME END", ["[Wave]", "if "]),
        ("draw fish", ["FishDraw"]),
        ("place egg on each matching fish", ["FishEgg", "on each"]),
        ("place egg on one/matching fish", ["FishEgg", "ArrowDown"]),
        ("hatch egg", ["FishHatch"]),
        ("place young", ["YoungFish"]),
        ("move young/school", ["SchoolFeederMove"]),
        ("recover from discard or draw", ["FishFromDiscard", "FishDraw"]),
        ("play fish paying cost", ["FishFromHand", "ArrowDown"]),
        ("play fish for free", ["FreePlayFishFromHand"]),
        ("consume shorter fish from hand", ["FishFromHandConsume"]),
        ("scatter school", ["UnSchoolFish"]),
        ("gain coral", ["Coral"]),
        ("all players", ["AllPlayers"]),
        ("compound abilities", [";"]),
    ]
    for label, tokens in checks:
        if all(token in text for token in tokens):
            return label
    if text:
        return "unknown / unsupported"
    return "no ability text"


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit real Finspan card ability coverage.")
    parser.add_argument("--summary-only", action="store_true")
    args = parser.parse_args()

    cards = load_cards()
    registry_ids = load_registry_ids()
    ability_cards = [card for card in cards if card.get("abilityText") or card.get("abilityIds")]
    status_counts = Counter(ability_status(card, registry_ids) for card in ability_cards)
    trigger_counts = Counter(card.get("abilityTrigger") or "none" for card in ability_cards)
    pattern_counts = Counter(pattern_for(card.get("abilityText") or "") for card in ability_cards)

    print("# Ability Coverage Audit")
    print()
    print("Generated from runtime JSON in `Finspan/Resources/Cards`.")
    print()
    print(f"- Total cards: {len(cards)}")
    print(f"- Cards with ability data: {len(ability_cards)}")
    print(f"- Mapped ability cards: {status_counts['mapped']}")
    print(f"- Mixed ability cards: {status_counts['mixed']}")
    print(f"- Unsupported ability cards: {status_counts['unsupported']}")
    print(f"- Unmapped ability cards: {status_counts['unmapped']}")
    print()
    print("## By Trigger")
    print()
    for trigger, count in sorted(trigger_counts.items()):
        print(f"- {trigger}: {count}")
    print()
    print("## By Raw Token Pattern")
    print()
    for pattern, count in sorted(pattern_counts.items()):
        print(f"- {pattern}: {count}")

    if args.summary_only:
        return

    grouped: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    for card in ability_cards:
        grouped[
            (
                card.get("abilityTrigger") or "none",
                pattern_for(card.get("abilityText") or ""),
                ability_status(card, registry_ids),
            )
        ].append(card)

    print()
    print("## Representative Cards")
    print()
    for (trigger, pattern, status), group in sorted(grouped.items()):
        print(f"### {trigger} · {pattern} · {status}")
        print()
        for card in group[:8]:
            ability_ids = ", ".join(card.get("abilityIds") or [])
            print(
                f"- `{card.get('id')}` {card.get('name')} | "
                f"`{ability_ids or 'none'}` | {card.get('abilityText') or ''}"
            )
        if len(group) > 8:
            print(f"- ... {len(group) - 8} more")
        print()


if __name__ == "__main__":
    main()
