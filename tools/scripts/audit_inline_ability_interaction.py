#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

from audit_ability_coverage import ability_text, load_cards, normalize_pattern, pattern_for


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_JSON = ROOT / "tools/generated/card_rendering/inline_ability_interaction_audit.json"
OUTPUT_MD = ROOT / "docs/INLINE_ABILITY_INTERACTION_AUDIT.md"

INLINE_EFFECTS = {
    "placeEgg",
    "placeEggOnMatchingFish",
    "placeYoung",
    "hatchEgg",
    "moveYoungOrSchool",
    "gainCoral",
}
INLINE_PARTIAL_EFFECTS = {
    "scatterSchool",
}
OVERLAY_EFFECTS = {
    "recoverFromDiscardOrDraw",
    "consumeFishFromHand",
    "playFishForFree",
    "playFishFromHand",
}
IRREVERSIBLE_EFFECTS = {
    "drawFish",
    "gameEndScore",
}


def english_name(card: dict) -> str:
    value = card.get("name")
    if isinstance(value, dict):
        return value.get("en") or value.get("raw") or value.get("zh") or ""
    return str(value or "")


def trigger(card: dict) -> str:
    return str(card.get("abilityTrigger") or "none")


def tokens(text: str) -> list[str]:
    return re.findall(r"\[([^\]]+)\]", text or "")


def effect_types_for(card: dict) -> list[str]:
    text = ability_text(card)
    normalized = normalize_pattern(text)
    raw_tokens = tokens(text)
    effects: list[str] = []

    def add(effect: str) -> None:
        if effect not in effects:
            effects.append(effect)

    if trigger(card) == "gameEnd" or "Wave" in raw_tokens:
        add("gameEndScore")
    if "DrawCard" in raw_tokens:
        add("drawFish")
    if "Discard" in raw_tokens or "FishFromDiscard" in raw_tokens or "FishDraw" in raw_tokens:
        add("recoverFromDiscardOrDraw")
    if "FishEgg" in raw_tokens:
        if "ArrowDown" in raw_tokens or "oneach" in normalized:
            add("placeEggOnMatchingFish")
        else:
            add("placeEgg")
    if "YoungFish" in raw_tokens:
        add("placeYoung")
    if "FishHatch" in raw_tokens:
        add("hatchEgg")
    if "SchoolFeederMove" in raw_tokens:
        add("moveYoungOrSchool")
    if "UnSchoolFish" in raw_tokens:
        add("scatterSchool")
    if any(token in raw_tokens for token in ("BlueCoral", "PurpleCoral", "GreenCoral", "AnyCoral")):
        add("gainCoral")
    if any(token in raw_tokens for token in ("FishFromHandConsume", "ConsumeFish1")):
        add("consumeFishFromHand")
    if "FreePlayFishFromHand" in raw_tokens:
        add("playFishForFree")
    if "FishFromHand" in raw_tokens:
        add("playFishFromHand")
    if not effects and text.strip():
        add("unknown")
    return effects


def classify(card: dict) -> dict:
    text = ability_text(card)
    card_tokens = tokens(text)
    effects = effect_types_for(card)
    all_players = "AllPlayers" in card_tokens or "(allplayers)" in normalize_pattern(text)
    unknown = "unknown" in effects
    has_irreversible = bool(set(effects) & IRREVERSIBLE_EFFECTS) or all_players
    has_overlay = bool(set(effects) & OVERLAY_EFFECTS)
    has_inline = bool(set(effects) & INLINE_EFFECTS)
    has_partial_inline = bool(set(effects) & INLINE_PARTIAL_EFFECTS)

    if unknown:
        primary = "D.notEnoughMetadata"
        inline_supported = "no"
        requires_overlay = "yes"
        undo_supported = "no"
        why = "Ability text does not map cleanly to current v2 effect metadata."
        recommended = "Keep existing pending UI fallback until effect metadata is explicit."
    elif has_irreversible:
        primary = "C.irreversibleNoUndo"
        inline_supported = "partial" if has_inline or has_partial_inline else "no"
        requires_overlay = "yes" if has_overlay or all_players else "no"
        undo_supported = "no"
        reasons = []
        if set(effects) & IRREVERSIBLE_EFFECTS:
            reasons.append("contains draw/deck-order or GAME END scoring effects")
        if all_players:
            reasons.append("targets all players and can cross local-player boundaries")
        if has_inline:
            reasons.append("also contains local resource effects that could be inline before the irreversible step")
        why = "; ".join(reasons)
        recommended = "Use fallback or hybrid UI; do not offer committed undo past irreversible steps."
    elif has_overlay:
        primary = "B.needsPickerOverlay"
        inline_supported = "partial" if has_inline or has_partial_inline else "no"
        requires_overlay = "yes"
        undo_supported = "partial"
        why = "Effect requires hand/discard/card/placement picker state beyond a single card-face icon hit area."
        recommended = "Use existing pending UI or a modal/side overlay; card icon may only launch the picker."
    elif has_inline or has_partial_inline:
        primary = "A.inlineCandidate"
        inline_supported = "yes" if has_inline and not has_partial_inline else "partial"
        requires_overlay = "no"
        undo_supported = "partial" if has_partial_inline else "yes"
        why = "Effect maps to visible board resource/slot targets and can be represented by card-face reward icons."
        recommended = "Inline card icon interaction with board target highlighting; keep a skip control."
    else:
        primary = "D.notEnoughMetadata"
        inline_supported = "no"
        requires_overlay = "yes"
        undo_supported = "no"
        why = "No actionable effect metadata was inferred."
        recommended = "Keep existing pending UI fallback."

    return {
        "cardId": card.get("id"),
        "sourceId": card.get("sourceId"),
        "englishName": english_name(card),
        "trigger": trigger(card),
        "abilityText": text,
        "tokens": card_tokens,
        "effectTypes": effects,
        "patternLabel": pattern_for(text),
        "primaryCategory": primary,
        "inlineSupported": inline_supported,
        "requiresOverlay": requires_overlay,
        "undoSupported": undo_supported,
        "why": why,
        "recommendedUI": recommended,
    }


def markdown(records: list[dict], stats: dict) -> str:
    lines: list[str] = []
    lines.append("# Inline Ability Interaction Audit")
    lines.append("")
    lines.append("This audit is design-only. It does not replace the existing right-side pending/reward UI and does not change Ability Engine behavior.")
    lines.append("")
    lines.append("## Current Pending Metadata")
    lines.append("")
    lines.append("- Source fish card id: available through `PendingEffectSet.sourceCardId`; `AbilityEngineV2Adapter.sourceCardId(for:)` bridges legacy `PendingChoice` progress/source data.")
    lines.append("- Current reward token: partially available through `EffectRewardTokenRequirement.tokenKind/count/source` on each available `EffectNode`.")
    lines.append("- Mapping reward token back to a specific card-face icon: not currently stable. `CardAbilityPresentation` renders token placements, but elements do not yet carry an effect node id, token source range, or hit-test id.")
    lines.append("- Legal target slots/fish: available in ViewModel-derived pending target data and v2 `EffectTargetRequirement`, with final legality still validated by `GameEngine`.")
    lines.append("- Reversible vs irreversible: not explicit metadata today. It must be added before committed undo is safe.")
    lines.append("- `skipEffectExecution`/`PendingEffectIntent.skipRemaining` can back the `→` control for ending/skipping the current fish ability remainder.")
    lines.append("- There is no engine-level `←` command today. A safe design needs staged ViewModel undo first, and engine transaction/undo metadata only for committed reversible steps.")
    lines.append("")
    lines.append("## Classification Summary")
    lines.append("")
    lines.append(f"- Total cards audited: {stats['total']}")
    lines.append(f"- A inline candidates: {stats['categories'].get('A.inlineCandidate', 0)}")
    lines.append(f"- B needs picker/overlay: {stats['categories'].get('B.needsPickerOverlay', 0)}")
    lines.append(f"- C irreversible/no undo: {stats['categories'].get('C.irreversibleNoUndo', 0)}")
    lines.append(f"- D not enough metadata: {stats['categories'].get('D.notEnoughMetadata', 0)}")
    lines.append(f"- Inline supported yes/partial/no: {stats['inlineSupported']}")
    lines.append(f"- Requires overlay yes/no: {stats['requiresOverlay']}")
    lines.append(f"- Undo supported yes/partial/no: {stats['undoSupported']}")
    lines.append("")
    lines.append("## Suitable For Inline Interaction")
    lines.append("")
    lines.append("- `placeEgg`, `placeEggOnMatchingFish`, `placeYoung`, `hatchEgg`, `moveYoungOrSchool`, and ability-driven `gainCoral` are the best candidates.")
    lines.append("- `scatterSchool` is a partial candidate because it needs source plus one-or-more target selection, but it can still be expressed as staged icon + board highlighting.")
    lines.append("- MVP recommendation: `placeEgg`, `hatchEgg`, `gainCoral`, simple move, and `→` skip current fish. Keep right-side context visible during MVP.")
    lines.append("")
    lines.append("## Needs Picker Or Overlay")
    lines.append("")
    lines.append("- `recoverFromDiscardOrDraw`, `consumeFishFromHand`, `playFishForFree`, and `playFishFromHand` require hand/discard/card picker or play-fish payment flow.")
    lines.append("- These can use a hybrid approach: clicking a card-face icon selects the effect, then the existing pending UI or a focused overlay handles card selection/payment.")
    lines.append("")
    lines.append("## Irreversible Or No Undo")
    lines.append("")
    lines.append("- `drawFish`, deck/recover flows after deck choice, hidden information, all-player flows after another player has acted, and `gameEndScore` should not support committed undo.")
    lines.append("- For these, `←` should only cancel local staged selection before command submission.")
    lines.append("")
    lines.append("## `→` Mapping")
    lines.append("")
    lines.append("- If a compound fish ability is active, map `→` to `PendingEffectIntent.skipRemaining` and then `PlayerCommand.skipEffectExecution`.")
    lines.append("- If one optional effect node is active, map `→` to `PendingEffectIntent.skipEffect` and then `PlayerCommand.skipEffectNode`.")
    lines.append("- For legacy single optional choices, keep the existing `.skip` pending-choice resolution fallback.")
    lines.append("")
    lines.append("## `←` Boundary")
    lines.append("")
    lines.append("- Safe now: undo unsubmitted ViewModel staged selection, such as selected reward icon, selected source slot, selected target slot, or selected hand card before command submission.")
    lines.append("- Not safe now: undo committed `GameEvent` output. There is no event-level inverse model or pending transaction boundary.")
    lines.append("- Future minimum engine design: add `EffectReversibility`, `PendingEffectUndoStack`, and either an engine-level transaction command or explicit inverse events for reversible local resource moves only.")
    lines.append("- Never undo draw/deck order, hidden information, all-player after another player has acted, triggered follow-up fish abilities, or GAME END scoring.")
    lines.append("")
    lines.append("## Hit Area Design")
    lines.append("")
    lines.append("- Add stable ids to `CardAbilityPresentation` icon elements: `abilityElementId`, optional `effectNodeId`, token name, token occurrence index, and source token range.")
    lines.append("- Add `PendingAbilityInlineController` to map current `PendingEffectSet.available` nodes to those ids.")
    lines.append("- Add `InteractiveCardAbilityOverlay` over the zoomed/active card face only; small hand/discard/ocean cards should not become primary hit targets.")
    lines.append("- Add `PendingAbilityTokenHitArea` for minimum tappable areas without changing card layout.")
    lines.append("- Reuse `BoardLegalTargetHighlighter`-style view state to highlight legal slots/fish; engine remains final validator.")
    lines.append("- Add `PendingAbilityUndoModel` for staged-only `←` in MVP.")
    lines.append("")
    lines.append("## Fallback Policy")
    lines.append("")
    lines.append("- Do not delete the right-side pending/reward UI now.")
    lines.append("- Keep fallback for draw, discard choice, hand picker, discard pile picker, play-fish flows, all-player flows, GAME END, hidden information, and uncertain metadata.")
    lines.append("- Hybrid first phase is preferred: card-face icon selection for simple local resource effects, with right-side minimal step info and existing skip controls retained.")
    lines.append("")
    lines.append("## Representative Records")
    lines.append("")
    for record in records[:24]:
        lines.append(
            f"- `{record['cardId']}` {record['englishName']} | {record['trigger']} | "
            f"{record['primaryCategory']} | inline {record['inlineSupported']} | undo {record['undoSupported']} | "
            f"{', '.join(record['effectTypes'])}"
        )
    lines.append("")
    lines.append("Full per-card output is in `tools/generated/card_rendering/inline_ability_interaction_audit.json`.")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    cards = sorted(load_cards(), key=lambda card: str(card.get("id")))
    records = [classify(card) for card in cards]
    stats = {
        "total": len(records),
        "categories": dict(Counter(record["primaryCategory"] for record in records)),
        "inlineSupported": dict(Counter(record["inlineSupported"] for record in records)),
        "requiresOverlay": dict(Counter(record["requiresOverlay"] for record in records)),
        "undoSupported": dict(Counter(record["undoSupported"] for record in records)),
        "effectTypes": dict(Counter(effect for record in records for effect in record["effectTypes"])),
    }
    payload = {
        "generatedFrom": "Finspan/Resources/Cards/*.json",
        "note": "Design audit only; no runtime behavior changes.",
        "stats": stats,
        "records": records,
    }
    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    OUTPUT_MD.write_text(markdown(records, stats), encoding="utf-8")
    print(f"Inline ability interaction audit: {stats['total']} cards")
    print(f"Categories: {stats['categories']}")
    print(f"Wrote {OUTPUT_JSON.relative_to(ROOT)}")
    print(f"Wrote {OUTPUT_MD.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
