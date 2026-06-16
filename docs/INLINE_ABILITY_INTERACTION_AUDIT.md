# Inline Ability Interaction Audit

This audit is design-only. It does not replace the existing right-side pending/reward UI and does not change Ability Engine behavior.

## Current Pending Metadata

- Source fish card id: available through `PendingEffectSet.sourceCardId`; `AbilityEngineV2Adapter.sourceCardId(for:)` bridges legacy `PendingChoice` progress/source data.
- Current reward token: partially available through `EffectRewardTokenRequirement.tokenKind/count/source` on each available `EffectNode`.
- Mapping reward token back to a specific card-face icon: not currently stable. `CardAbilityPresentation` renders token placements, but elements do not yet carry an effect node id, token source range, or hit-test id.
- Legal target slots/fish: available in ViewModel-derived pending target data and v2 `EffectTargetRequirement`, with final legality still validated by `GameEngine`.
- Reversible vs irreversible: not explicit metadata today. It must be added before committed undo is safe.
- `skipEffectExecution`/`PendingEffectIntent.skipRemaining` can back the `→` control for ending/skipping the current fish ability remainder.
- There is no engine-level `←` command today. A safe design needs staged ViewModel undo first, and engine transaction/undo metadata only for committed reversible steps.

## Classification Summary

- Total cards audited: 215
- A inline candidates: 73
- B needs picker/overlay: 51
- C irreversible/no undo: 91
- D not enough metadata: 0
- Inline supported yes/partial/no: {'no': 58, 'yes': 66, 'partial': 91}
- Requires overlay yes/no: {'no': 113, 'yes': 102}
- Undo supported yes/partial/no: {'no': 91, 'partial': 58, 'yes': 66}

## Suitable For Inline Interaction

- `placeEgg`, `placeEggOnMatchingFish`, `placeYoung`, `hatchEgg`, `moveYoungOrSchool`, and ability-driven `gainCoral` are the best candidates.
- `scatterSchool` is a partial candidate because it needs source plus one-or-more target selection, but it can still be expressed as staged icon + board highlighting.
- MVP recommendation: `placeEgg`, `hatchEgg`, `gainCoral`, simple move, and `→` skip current fish. Keep right-side context visible during MVP.

## Needs Picker Or Overlay

- `recoverFromDiscardOrDraw`, `consumeFishFromHand`, `playFishForFree`, and `playFishFromHand` require hand/discard/card picker or play-fish payment flow.
- These can use a hybrid approach: clicking a card-face icon selects the effect, then the existing pending UI or a focused overlay handles card selection/payment.

## Irreversible Or No Undo

- `drawFish`, deck/recover flows after deck choice, hidden information, all-player flows after another player has acted, and `gameEndScore` should not support committed undo.
- For these, `←` should only cancel local staged selection before command submission.

## `→` Mapping

- If a compound fish ability is active, map `→` to `PendingEffectIntent.skipRemaining` and then `PlayerCommand.skipEffectExecution`.
- If one optional effect node is active, map `→` to `PendingEffectIntent.skipEffect` and then `PlayerCommand.skipEffectNode`.
- For legacy single optional choices, keep the existing `.skip` pending-choice resolution fallback.

## `←` Boundary

- Safe now: undo unsubmitted ViewModel staged selection, such as selected reward icon, selected source slot, selected target slot, or selected hand card before command submission.
- Not safe now: undo committed `GameEvent` output. There is no event-level inverse model or pending transaction boundary.
- Future minimum engine design: add `EffectReversibility`, `PendingEffectUndoStack`, and either an engine-level transaction command or explicit inverse events for reversible local resource moves only.
- Never undo draw/deck order, hidden information, all-player after another player has acted, triggered follow-up fish abilities, or GAME END scoring.

## Hit Area Design

- Add stable ids to `CardAbilityPresentation` icon elements: `abilityElementId`, optional `effectNodeId`, token name, token occurrence index, and source token range.
- Add `PendingAbilityInlineController` to map current `PendingEffectSet.available` nodes to those ids.
- Add `InteractiveCardAbilityOverlay` over the zoomed/active card face only; small hand/discard/ocean cards should not become primary hit targets.
- Add `PendingAbilityTokenHitArea` for minimum tappable areas without changing card layout.
- Reuse `BoardLegalTargetHighlighter`-style view state to highlight legal slots/fish; engine remains final validator.
- Add `PendingAbilityUndoModel` for staged-only `←` in MVP.

## Fallback Policy

- Do not delete the right-side pending/reward UI now.
- Keep fallback for draw, discard choice, hand picker, discard pile picker, play-fish flows, all-player flows, GAME END, hidden information, and uncertain metadata.
- Hybrid first phase is preferred: card-face icon selection for simple local resource effects, with right-side minimal step info and existing skip controls retained.

## Representative Records

- `base.main.001` Abyssal Anglerfish | gameEnd | C.irreversibleNoUndo | inline no | undo no | gameEndScore
- `base.main.002` Abyssal Halosaur | whenPlayed | B.needsPickerOverlay | inline no | undo partial | playFishFromHand
- `base.main.003` Abyssal Spiderfish | whenPlayed | A.inlineCandidate | inline yes | undo yes | hatchEgg
- `base.main.004` Angelshark | gameEnd | C.irreversibleNoUndo | inline no | undo no | gameEndScore
- `base.main.005` Angler | ifActivated | A.inlineCandidate | inline yes | undo yes | moveYoungOrSchool
- `base.main.006` Arabian Carpetshark | whenPlayed | A.inlineCandidate | inline yes | undo yes | placeEggOnMatchingFish
- `base.main.007` Atlantic Bluefin Tuna | whenPlayed | C.irreversibleNoUndo | inline no | undo no | drawFish, recoverFromDiscardOrDraw
- `base.main.008` Atlantic Bonito | gameEnd | C.irreversibleNoUndo | inline no | undo no | gameEndScore
- `base.main.009` Atlantic Mackerel | ifActivated | A.inlineCandidate | inline yes | undo yes | placeEgg
- `base.main.010` Atlantic Sailfish | whenPlayed | C.irreversibleNoUndo | inline no | undo no | drawFish
- `base.main.011` Atlantic Salmon | gameEnd | C.irreversibleNoUndo | inline no | undo no | gameEndScore, playFishFromHand
- `base.main.012` Atlantic Sturgeon | ifActivated | B.needsPickerOverlay | inline no | undo partial | recoverFromDiscardOrDraw
- `base.main.013` Atlantic Wolffish | ifActivated | A.inlineCandidate | inline yes | undo yes | hatchEgg
- `base.main.014` Banggai Cardinalfish | ifActivated | A.inlineCandidate | inline yes | undo yes | hatchEgg
- `base.main.015` Barramundi | ifActivated | A.inlineCandidate | inline yes | undo yes | placeEgg
- `base.main.016` Bearded Seadevil | whenPlayed | C.irreversibleNoUndo | inline partial | undo no | placeEggOnMatchingFish
- `base.main.017` Bigeye Tuna | ifActivated | A.inlineCandidate | inline yes | undo yes | placeEgg
- `base.main.018` Bigeye Smooth-Head | whenPlayed | A.inlineCandidate | inline yes | undo yes | placeEggOnMatchingFish
- `base.main.019` Binocular Fish | gameEnd | C.irreversibleNoUndo | inline partial | undo no | gameEndScore, placeEggOnMatchingFish
- `base.main.020` Black Cardinalfish | whenPlayed | A.inlineCandidate | inline yes | undo yes | hatchEgg, moveYoungOrSchool
- `base.main.021` Black Hagfish | whenPlayed | B.needsPickerOverlay | inline partial | undo partial | recoverFromDiscardOrDraw, placeYoung
- `base.main.022` Black Swallower | whenPlayed | B.needsPickerOverlay | inline no | undo partial | playFishFromHand
- `base.main.023` Blob Sculpin | gameEnd | C.irreversibleNoUndo | inline no | undo no | gameEndScore, playFishFromHand
- `base.main.024` Blue Tang | whenPlayed | A.inlineCandidate | inline yes | undo yes | placeYoung, moveYoungOrSchool

Full per-card output is in `tools/generated/card_rendering/inline_ability_interaction_audit.json`.
