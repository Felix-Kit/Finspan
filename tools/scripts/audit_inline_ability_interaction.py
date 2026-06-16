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
NO_COMMITTED_UNDO_EFFECTS = {
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


def append_unique(values: list[str], value: str) -> None:
    if value not in values:
        values.append(value)


def legacy_category(effects: list[str], all_players: bool) -> str:
    unknown = "unknown" in effects
    has_no_committed_undo = bool(set(effects) & NO_COMMITTED_UNDO_EFFECTS) or all_players
    has_overlay = bool(set(effects) & OVERLAY_EFFECTS)
    has_inline = bool(set(effects) & INLINE_EFFECTS)
    has_partial_inline = bool(set(effects) & INLINE_PARTIAL_EFFECTS)

    if unknown:
        return "D.notEnoughMetadata"
    if has_no_committed_undo:
        return "C.irreversibleNoUndo"
    if has_overlay:
        return "B.needsPickerOverlay"
    if has_inline or has_partial_inline:
        return "A.inlineCandidate"
    return "D.notEnoughMetadata"


def classify(card: dict) -> dict:
    text = ability_text(card)
    card_tokens = tokens(text)
    effects = effect_types_for(card)
    all_players = "AllPlayers" in card_tokens or "(allplayers)" in normalize_pattern(text)
    unknown = "unknown" in effects
    legacy = legacy_category(effects, all_players)
    entry_surfaces: list[str] = []
    continuation_surfaces: list[str] = []
    source_visibility_options: list[str] = []
    reasons: list[str] = []

    if unknown:
        append_unique(entry_surfaces, "noInlineEntry")
        append_unique(continuation_surfaces, "fallbackPanel")
        append_unique(source_visibility_options, "ownVisibleSourceCard")
        why = "Ability text does not map cleanly to current v2 effect metadata."
        recommended = "Keep existing pending UI fallback until effect metadata is explicit."
        requires_fallback = True
        requires_overlay = True
        can_start_inline = False
    else:
        append_unique(entry_surfaces, "cardAbilityIcon")
        append_unique(source_visibility_options, "ownVisibleSourceCard")
        can_start_inline = True
        requires_fallback = False
        requires_overlay = False

        if trigger(card) == "gameEnd" or "gameEndScore" in effects:
            append_unique(entry_surfaces, "gameEndDock")
            append_unique(source_visibility_options, "gameEndSourceCard")
            reasons.append("GAME END can use a dock or visible source-card entry, but committed scoring is not undoable")

        if all_players:
            append_unique(entry_surfaces, "incomingRewardDock")
            append_unique(source_visibility_options, "externalPendingReward")
            append_unique(source_visibility_options, "opponentSourceCard")
            reasons.append("AllPlayers source player can use the card icon; target players use an incoming reward dock")
            requires_fallback = True

        if "drawFish" in effects:
            append_unique(continuation_surfaces, "directCommit")
            reasons.append("drawFish can start inline and commit directly, but has no committed undo")
        if "gameEndScore" in effects:
            append_unique(continuation_surfaces, "directCommit")
        if "recoverFromDiscardOrDraw" in effects:
            append_unique(continuation_surfaces, "discardOverlay")
            append_unique(continuation_surfaces, "directCommit")
            reasons.append("recoverFromDiscardOrDraw starts inline, then continues through discard overlay or direct draw fallback")
            requires_overlay = True
            requires_fallback = True
        if "consumeFishFromHand" in effects:
            append_unique(continuation_surfaces, "handPicker")
            append_unique(continuation_surfaces, "boardTarget")
            reasons.append("consumeFishFromHand starts inline, then needs a hand picker and board target")
            requires_overlay = True
            requires_fallback = True
        if "playFishForFree" in effects:
            append_unique(continuation_surfaces, "handPicker")
            append_unique(continuation_surfaces, "playFishFlow")
            reasons.append("playFishForFree starts inline, then enters hand picker and staged playFish flow")
            requires_overlay = True
            requires_fallback = True
        if "playFishFromHand" in effects:
            append_unique(continuation_surfaces, "handPicker")
            append_unique(continuation_surfaces, "playFishFlow")
            append_unique(continuation_surfaces, "paymentFlow")
            reasons.append("playFishFromHand starts inline, then enters hand picker plus staged playFish/payment flow")
            requires_overlay = True
            requires_fallback = True

        if any(effect in effects for effect in ("placeEgg", "placeEggOnMatchingFish", "placeYoung", "hatchEgg", "moveYoungOrSchool", "scatterSchool")):
            append_unique(continuation_surfaces, "boardTarget")
            reasons.append("local resource effects can continue through board target highlighting")
        if "gainCoral" in effects:
            append_unique(continuation_surfaces, "reefTarget")
            reasons.append("gainCoral can continue through reef target selection")

        if not continuation_surfaces:
            append_unique(continuation_surfaces, "fallbackPanel")
            requires_fallback = True
            reasons.append("no continuation surface was inferred")

        if "gameEndScore" in effects or "drawFish" in effects:
            commit_reversibility = "noCommittedUndo"
        else:
            commit_reversibility = "stagedOnlyUndo"

        if all_players and commit_reversibility != "noCommittedUndo":
            commit_reversibility = "stagedOnlyUndo"

        why = "; ".join(reasons) if reasons else "Effect can start from an inline entry surface and continue through staged presentation."
        recommended = recommendation_for(entry_surfaces, continuation_surfaces, commit_reversibility, requires_fallback, all_players)

    if unknown:
        commit_reversibility = "noCommittedUndo"

    source_visibility = (
        "gameEndSourceCard" if "gameEndSourceCard" in source_visibility_options
        else source_visibility_options[0]
    )

    return {
        "cardId": card.get("id"),
        "sourceId": card.get("sourceId"),
        "name": english_name(card),
        "trigger": trigger(card),
        "abilityText": text,
        "tokens": card_tokens,
        "effectTypes": effects,
        "patternLabel": pattern_for(text),
        "legacyCategory": legacy,
        "inlineEntrySurface": entry_surfaces,
        "continuationSurface": continuation_surfaces,
        "commitReversibility": commit_reversibility,
        "sourceVisibility": source_visibility,
        "sourceVisibilityOptions": source_visibility_options,
        "requiresFallback": requires_fallback,
        "requiresOverlay": requires_overlay,
        "canStartInline": can_start_inline,
        "why": why,
        "recommendedUI": recommended,
    }


def recommendation_for(
    entry_surfaces: list[str],
    continuation_surfaces: list[str],
    commit_reversibility: str,
    requires_fallback: bool,
    all_players: bool,
) -> str:
    parts: list[str] = []
    if "incomingRewardDock" in entry_surfaces:
        parts.append("Use card icon for the source player and IncomingRewardDock for target players.")
    elif "gameEndDock" in entry_surfaces:
        parts.append("Use GameEndDock or the visible source-card icon as the entry.")
    elif "cardAbilityIcon" in entry_surfaces:
        parts.append("Use the card ability icon as the inline entry.")
    else:
        parts.append("Use right-side fallback.")

    if "discardOverlay" in continuation_surfaces:
        parts.append("Continue in discard overlay, with direct draw fallback when no discard target is available.")
    if "handPicker" in continuation_surfaces:
        parts.append("Continue with hand picker.")
    if "playFishFlow" in continuation_surfaces:
        parts.append("Then enter staged playFish flow.")
    if "boardTarget" in continuation_surfaces:
        parts.append("Highlight legal board targets.")
    if "reefTarget" in continuation_surfaces:
        parts.append("Highlight legal reef targets.")
    if "directCommit" in continuation_surfaces:
        parts.append("Allow direct commit where no picker is needed.")
    if commit_reversibility == "noCommittedUndo":
        parts.append("Do not offer committed undo after submission.")
    else:
        parts.append("Allow only staged undo before command submission.")
    if all_players:
        parts.append("Each target player resolves or skips their own pending reward independently.")
    if requires_fallback:
        parts.append("Keep right-side fallback available for current MVP.")
    return " ".join(parts)


def markdown(records: list[dict], stats: dict) -> str:
    lines: list[str] = []
    lines.append("# Inline Ability Interaction Audit")
    lines.append("")
    lines.append("This audit is design-only. It does not replace the existing right-side pending/reward UI and does not change Ability Engine behavior.")
    lines.append("")
    lines.append("The audit now separates inline entry, continuation, committed undo, and source visibility. `needs picker/overlay` does not mean `cannot inline`; it means the inline entry continues through a picker or overlay. `irreversible/no undo` does not mean `cannot inline`; it only means `<-` cannot undo after command submission.")
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
    lines.append("- First unified presentation model exists as `BoardCardInteractionTask` / `BoardCardInteractionStep` / `BoardCardInteractionToken` / `BoardCardInteractionControlState`.")
    lines.append("- `IncomingRewardDockState` is the presentation model for external pending rewards where the current player cannot rely on a visible source fish card.")
    lines.append("")
    lines.append("## Classification Summary")
    lines.append("")
    lines.append(f"- Total cards audited: {stats['total']}")
    lines.append(f"- Legacy A inline candidates: {stats['legacyCategories'].get('A.inlineCandidate', 0)}")
    lines.append(f"- Legacy B needs picker/overlay: {stats['legacyCategories'].get('B.needsPickerOverlay', 0)}")
    lines.append(f"- Legacy C irreversible/no undo: {stats['legacyCategories'].get('C.irreversibleNoUndo', 0)}")
    lines.append(f"- Legacy D not enough metadata: {stats['legacyCategories'].get('D.notEnoughMetadata', 0)}")
    lines.append(f"- cardIcon entry count: {stats['inlineEntrySurface'].get('cardAbilityIcon', 0)}")
    lines.append(f"- boardIcon entry count: {stats['inlineEntrySurface'].get('boardZoneIcon', 0)}")
    lines.append(f"- incomingRewardDock entry count: {stats['inlineEntrySurface'].get('incomingRewardDock', 0)}")
    lines.append(f"- gameEndDock entry count: {stats['inlineEntrySurface'].get('gameEndDock', 0)}")
    lines.append(f"- directCommit count: {stats['continuationSurface'].get('directCommit', 0)}")
    lines.append(f"- boardTarget count: {stats['continuationSurface'].get('boardTarget', 0)}")
    lines.append(f"- handPicker count: {stats['continuationSurface'].get('handPicker', 0)}")
    lines.append(f"- discardOverlay count: {stats['continuationSurface'].get('discardOverlay', 0)}")
    lines.append(f"- playFishFlow count: {stats['continuationSurface'].get('playFishFlow', 0)}")
    lines.append(f"- paymentFlow count: {stats['continuationSurface'].get('paymentFlow', 0)}")
    lines.append(f"- noCommittedUndo count: {stats['commitReversibility'].get('noCommittedUndo', 0)}")
    lines.append(f"- stagedOnlyUndo count: {stats['commitReversibility'].get('stagedOnlyUndo', 0)}")
    lines.append(f"- fallbackRequired count: {stats['requiresFallback'].get('true', 0)}")
    lines.append("")
    lines.append("## Four Independent Dimensions")
    lines.append("")
    lines.append("- `inlineEntrySurface`: `cardAbilityIcon`, `boardZoneIcon`, `incomingRewardDock`, `gameEndDock`, or `noInlineEntry`.")
    lines.append("- `continuationSurface`: `directCommit`, `boardTarget`, `handPicker`, `discardOverlay`, `playFishFlow`, `paymentFlow`, `reefTarget`, or `fallbackPanel`.")
    lines.append("- `commitReversibility`: `stagedOnlyUndo`, `committedUndoSupported`, or `noCommittedUndo`.")
    lines.append("- `sourceVisibility`: `ownVisibleSourceCard`, `opponentSourceCard`, `boardZoneOrDiveSite`, `gameEndSourceCard`, or `externalPendingReward`.")
    lines.append("")
    lines.append("## Representative Reclassification")
    lines.append("")
    lines.append("- `recoverFromDiscardOrDraw`: `cardAbilityIcon` entry, `discardOverlay` or `directCommit` continuation, staged undo before command, no committed undo after draw.")
    lines.append("- `consumeFishFromHand`: `cardAbilityIcon` entry, `handPicker` plus `boardTarget` continuation, staged undo before command.")
    lines.append("- `playFishForFree` / `playFishFromHand`: `cardAbilityIcon` entry, `handPicker` plus `playFishFlow`; paid play also carries `paymentFlow`.")
    lines.append("- `drawFish`: `cardAbilityIcon` or `incomingRewardDock` entry, `directCommit` continuation, `noCommittedUndo`.")
    lines.append("- `GAME END`: `gameEndDock` or visible `cardAbilityIcon` entry, `directCommit` or target continuation depending on effect, `noCommittedUndo`.")
    lines.append("- `AllPlayers`: source player uses `cardAbilityIcon`; target players use `incomingRewardDock`. Each target player skip / staged undo is scoped to their own pending step.")
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
    lines.append("- Keep fallback for complex explanations, discard choice, hand picker, discard pile picker, play-fish flows, all-player flows, GAME END, hidden information, and uncertain metadata.")
    lines.append("- The target direction is card/dock entry first, with right-side UI reduced to fallback / debug / complex helper.")
    lines.append("- External rewards prefer `IncomingRewardDock` because the target player may not have a visible source fish card to tap.")
    lines.append("")
    lines.append("## Representative Records")
    lines.append("")
    for record in records[:24]:
        lines.append(
            f"- `{record['cardId']}` {record['name']} | {record['trigger']} | "
            f"entry {', '.join(record['inlineEntrySurface'])} | continuation {', '.join(record['continuationSurface'])} | "
            f"undo {record['commitReversibility']} | {', '.join(record['effectTypes'])}"
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
        "legacyCategories": dict(Counter(record["legacyCategory"] for record in records)),
        "inlineEntrySurface": dict(Counter(surface for record in records for surface in record["inlineEntrySurface"])),
        "continuationSurface": dict(Counter(surface for record in records for surface in record["continuationSurface"])),
        "commitReversibility": dict(Counter(record["commitReversibility"] for record in records)),
        "sourceVisibility": dict(Counter(record["sourceVisibility"] for record in records)),
        "requiresFallback": dict(Counter(str(record["requiresFallback"]).lower() for record in records)),
        "requiresOverlay": dict(Counter(str(record["requiresOverlay"]).lower() for record in records)),
        "canStartInline": dict(Counter(str(record["canStartInline"]).lower() for record in records)),
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
    print(f"Legacy categories: {stats['legacyCategories']}")
    print(f"Entry surfaces: {stats['inlineEntrySurface']}")
    print(f"Continuation surfaces: {stats['continuationSurface']}")
    print(f"Commit reversibility: {stats['commitReversibility']}")
    print(f"Fallback required: {stats['requiresFallback']}")
    print(f"Wrote {OUTPUT_JSON.relative_to(ROOT)}")
    print(f"Wrote {OUTPUT_MD.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
