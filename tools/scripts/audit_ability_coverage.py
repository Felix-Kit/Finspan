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


def ability_text(card: dict) -> str:
    value = card.get("abilityText") or ""
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(str(item) for item in value)
    if isinstance(value, dict):
        for key in ("raw", "text", "display"):
            if isinstance(value.get(key), str):
                return value[key]
        return json.dumps(value, ensure_ascii=False, sort_keys=True)
    return str(value)


def ability_status(card: dict, registry_ids: set[str]) -> str:
    ids = card.get("abilityIds") or []
    if not ids:
        return "unmapped"
    parser_mapped = pattern_parser_maps(ability_text(card))
    mapped = [
        ability_id
        for ability_id in ids
        if ability_id in registry_ids or parser_mapped
    ]
    if len(mapped) == len(ids):
        return "mapped"
    if mapped:
        return "mixed"
    if all(str(ability_id).startswith("unsupported.") for ability_id in ids):
        return "unsupported"
    return "unmapped"


def normalize_pattern(text: str) -> str:
    return re.sub(r"\s+", "", text).replace("（", "(").replace("）", ")")


def pure_repeated_token_count(pattern: str, token: str, max_count: int = 4) -> int | None:
    for count in range(1, max_count + 1):
        if pattern == token * count:
            return count
    return None


def egg_placement_filter(pattern: str) -> str | None:
    prefix = "[FishEgg][ArrowDown]"
    if not pattern.startswith(prefix):
        return None
    remainder = pattern[len(prefix):].replace("(oneach)", "").replace("oneach", "")
    mapping = {
        "[Estuary]": "topRow",
        "[PlayFishBottomRow]": "bottomRow",
        "[Predator]": "predator",
        "[FishLengthSmall]": "small",
        "[FishLengthMedium]": "medium",
        "[FishLengthLarge]": "large",
        "[FlipperBlue]": "blue",
        "[FlipperPurple]": "purple",
        "[FlipperGreen]": "green",
    }
    return mapping.get(remainder)


def paid_play_placement(pattern: str) -> str | None:
    prefix = "[FishFromHand][ArrowDown]"
    if not pattern.startswith(prefix):
        return None
    remainder = pattern[len(prefix):]
    mapping = {
        "[Estuary]": "topRow",
        "[PlayFishTopRow]": "topRow",
        "[PlayFishBottomRow]": "bottomRow",
        "[Deepwater]": "bottomRow",
        "[Sun]": "sunlight",
        "[FlipperBlue]": "blue",
        "[FlipperPurple]": "purple",
        "[FlipperGreen]": "green",
        "[AnyCoral][AnyCoral][AnyCoral](inadivesitewithatleast3)": "coralAtLeast3",
        "[AnyCoral][AnyCoral][AnyCoral][AnyCoral][AnyCoral](inadivesitewithatleast5)": "coralAtLeast5",
    }
    return mapping.get(remainder)


def free_play_filter(pattern: str) -> str | None:
    prefix = "[FreePlayFishFromHand]"
    if not pattern.startswith(prefix):
        return None
    if pattern == "[FreePlayFishFromHand]ifno[AnyCoral]inthisfish'sdivesite":
        return None
    remainder = pattern[len(prefix):].replace("only", "")
    mapping = {
        "": "any",
        "[FishLengthSmall]": "small",
        "[FishLengthMedium]": "medium",
        "[FishLengthLarge]": "large",
        "[Bioluminescent]": "bioluminescent",
        "[Camouflage]": "camouflage",
    }
    return mapping.get(remainder)


def pure_coral_gain(pattern: str) -> bool:
    remaining = pattern
    tokens = ("[BlueCoral]", "[PurpleCoral]", "[GreenCoral]", "[AnyCoral]")
    matched = False
    while remaining:
        for token in tokens:
            if remaining.startswith(token):
                matched = True
                remaining = remaining[len(token):]
                break
        else:
            return False
    return matched


def ordered_card_gain_compound(pattern: str) -> bool:
    remaining = pattern
    effects: list[str] = []
    while remaining:
        for token, label in (
            ("[DrawCard]", "draw"),
            ("[Discard]", "recover"),
            ("[FishEgg]", "egg"),
        ):
            if remaining.startswith(token):
                effects.append(label)
                remaining = remaining[len(token):]
                break
        else:
            return False
    return len(effects) > 1 and ("recover" in effects or ("draw" in effects and "egg" in effects))


def mixed_compound_effects(pattern: str) -> list[str] | None:
    if pattern == "[FreePlayFishFromHand]ifno[AnyCoral]inthisfish'sdivesite":
        return ["free-play-source-site-no-coral"]

    remaining = pattern
    effects: list[str] = []
    token_map = (
        ("[BlueCoral]", "coral"),
        ("[PurpleCoral]", "coral"),
        ("[GreenCoral]", "coral"),
        ("[AnyCoral]", "coral"),
        ("[DrawCard]", "draw"),
        ("[Discard]", "recover"),
        ("[FishEgg]", "egg"),
        ("[FishHatch]", "hatch"),
        ("[YoungFish]", "young"),
        ("[SchoolFeederMove]", "move"),
        ("[UnSchoolFish]", "scatter"),
        ("[FishFromHandConsume]", "consume"),
    )
    while remaining:
        for token, label in token_map:
            if remaining.startswith(token):
                effects.append(label)
                remaining = remaining[len(token):]
                break
        else:
            return None

    if len(effects) <= 1 or len(set(effects)) <= 1:
        return None
    return effects


def all_players_inner_pattern(pattern: str) -> str | None:
    if not pattern.startswith("(allplayers)") or not pattern.endswith("[AllPlayers]"):
        return None
    inner = pattern[len("(allplayers)") : -len("[AllPlayers]")]
    return inner or None


def colored_coral_conditional_bonus_parts(pattern: str) -> tuple[str, str, str, int] | None:
    separator = "also,if"
    suffix = "inthisdivesite:"
    if separator not in pattern or suffix not in pattern:
        return None
    base, rest = pattern.split(separator, 1)
    coral_pattern, bonus = rest.split(suffix, 1)
    if not base or not bonus:
        return None
    remaining = coral_pattern
    color: str | None = None
    count = 0
    token_map = (
        ("[BlueCoral]", "blue"),
        ("[PurpleCoral]", "purple"),
        ("[GreenCoral]", "green"),
    )
    while remaining:
        for token, token_color in token_map:
            if remaining.startswith(token):
                if color is not None and color != token_color:
                    return None
                color = token_color
                count += 1
                remaining = remaining[len(token):]
                break
        else:
            return None
    if color is None or count <= 0:
        return None
    return base, bonus, color, count


def pattern_parser_maps_normalized(pattern: str) -> bool:
    if not pattern or ";" in pattern or "/" in pattern:
        return False
    if parts := colored_coral_conditional_bonus_parts(pattern):
        base, bonus, _, _ = parts
        return pattern_parser_maps_normalized(base) and pattern_parser_maps_normalized(bonus)
    if pure_repeated_token_count(pattern, "[DrawCard]", max_count=5) is not None:
        return True
    if pure_repeated_token_count(pattern, "[Discard]", max_count=5) is not None:
        return True
    if mixed_compound_effects(pattern) is not None:
        return True
    if pure_repeated_token_count(pattern, "[FishHatch]") is not None:
        return True
    if pure_repeated_token_count(pattern, "[FishEgg]") is not None:
        return True
    if pure_repeated_token_count(pattern, "[YoungFish]") is not None:
        return True
    if pure_repeated_token_count(pattern, "[SchoolFeederMove]") is not None:
        return True
    if pure_repeated_token_count(pattern, "[UnSchoolFish]", max_count=2) is not None:
        return True
    if pure_repeated_token_count(pattern, "[ConsumeFish1]", max_count=2) is not None:
        return True
    if pure_repeated_token_count(pattern, "[FishFromHandConsume]", max_count=2) is not None:
        return True
    if paid_play_placement(pattern) is not None:
        return True
    if free_play_filter(pattern) is not None:
        return True
    if egg_placement_filter(pattern) is not None:
        return True
    return pure_coral_gain(pattern)


def pattern_parser_maps(text: str) -> bool:
    pattern = normalize_pattern(text)
    if inner := all_players_inner_pattern(pattern):
        return pattern_parser_maps_normalized(inner)
    return pattern_parser_maps_normalized(pattern)


def pattern_label_for_normalized(pattern: str, text: str) -> str:
    if parts := colored_coral_conditional_bonus_parts(pattern):
        _, _, color, count = parts
        return f"colored coral conditional bonus ({color} x{count})"
    if pure_repeated_token_count(pattern, "[DrawCard]", max_count=5) is not None:
        return "draw fish"
    if pure_repeated_token_count(pattern, "[Discard]", max_count=5) is not None:
        return "recover from discard or draw"
    mixed_effects = mixed_compound_effects(pattern)
    if mixed_effects is not None:
        if mixed_effects == ["free-play-source-site-no-coral"]:
            return "free play from source dive site with no coral"
        effect_set = set(mixed_effects)
        if effect_set == {"young", "consume"}:
            return "mixed young + consume"
        if effect_set == {"young", "move"}:
            return "mixed young + move"
        if effect_set == {"hatch", "move"}:
            return "mixed hatch + move"
        if effect_set == {"move", "draw"}:
            return "mixed move + draw"
        if effect_set == {"egg", "hatch"}:
            return "mixed egg + hatch"
        if effect_set == {"scatter", "consume"}:
            return "mixed scatter + consume"
        if "coral" in effect_set:
            return "mixed coral compound"
        if "scatter" in effect_set:
            return "mixed scatter compound"
        return "mixed compound effect pool"
    if pure_repeated_token_count(pattern, "[FishHatch]") is not None:
        return "hatch egg"
    if pure_repeated_token_count(pattern, "[FishEgg]") is not None:
        return "place egg single target"
    if pure_repeated_token_count(pattern, "[YoungFish]") is not None:
        return "place young"
    if pure_repeated_token_count(pattern, "[SchoolFeederMove]") is not None:
        return "move young/school"
    if pure_repeated_token_count(pattern, "[UnSchoolFish]", max_count=2) is not None:
        return "scatter school"
    if pure_repeated_token_count(pattern, "[ConsumeFish1]", max_count=2) is not None:
        return "consume shorter fish from hand"
    if pure_repeated_token_count(pattern, "[FishFromHandConsume]", max_count=2) is not None:
        return "consume fish from hand"
    if paid_play_placement(pattern) is not None:
        return "play fish paying cost"
    if free_play_filter(pattern) is not None:
        return "play fish for free"
    if egg_placement_filter(pattern) is not None:
        return "place egg on each matching fish"
    if pure_coral_gain(pattern):
        return "gain coral"
    checks = [
        ("scoring-only GAME END", ["[Wave]", "if "]),
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
        ("compound abilities", [";"]),
    ]
    for label, tokens in checks:
        if all(token in text for token in tokens):
            return label
    if text:
        return "unknown / unsupported"
    return "no ability text"


def pattern_for(text: str) -> str:
    pattern = normalize_pattern(text)
    if inner := all_players_inner_pattern(pattern):
        return "all players · " + pattern_label_for_normalized(inner, text)
    return pattern_label_for_normalized(pattern, text)


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit real Finspan card ability coverage.")
    parser.add_argument("--summary-only", action="store_true")
    args = parser.parse_args()

    cards = load_cards()
    registry_ids = load_registry_ids()
    ability_cards = [card for card in cards if ability_text(card) or card.get("abilityIds")]
    slash_cards = [card for card in ability_cards if "/" in ability_text(card)]
    all_players_cards = [card for card in ability_cards if "[AllPlayers]" in ability_text(card)]
    status_counts = Counter(ability_status(card, registry_ids) for card in ability_cards)
    trigger_counts = Counter(card.get("abilityTrigger") or "none" for card in ability_cards)
    pattern_counts = Counter(pattern_for(ability_text(card)) for card in ability_cards)

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
    print(f"- Ability cards containing `/`: {len(slash_cards)}")
    print(f"- AllPlayers ability cards: {len(all_players_cards)}")
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

    print()
    print("## Slash Ability Cards")
    print()
    if slash_cards:
        for card in slash_cards:
            print(f"- `{card.get('id')}` {card.get('name')} | {ability_text(card)}")
    else:
        print("- None found in runtime JSON.")

    grouped: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    for card in ability_cards:
        grouped[
            (
                card.get("abilityTrigger") or "none",
                pattern_for(ability_text(card)),
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
                f"`{ability_ids or 'none'}` | {ability_text(card)}"
            )
        if len(group) > 8:
            print(f"- ... {len(group) - 8} more")
        print()


if __name__ == "__main__":
    main()
