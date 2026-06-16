# Inline Ability Interaction Audit

This audit is design-only. It does not replace the existing right-side pending/reward UI and does not change Ability Engine behavior.

The audit now separates inline entry, continuation, committed undo, and source visibility. `needs picker/overlay` does not mean `cannot inline`; it means the inline entry continues through a picker or overlay. `irreversible/no undo` does not mean `cannot inline`; it only means `<-` cannot undo after command submission.

## Current Pending Metadata

- Source fish card id: available through `PendingEffectSet.sourceCardId`; `AbilityEngineV2Adapter.sourceCardId(for:)` bridges legacy `PendingChoice` progress/source data.
- Current reward token: partially available through `EffectRewardTokenRequirement.tokenKind/count/source` on each available `EffectNode`.
- Mapping reward token back to a specific card-face icon: not currently stable. `CardAbilityPresentation` renders token placements, but elements do not yet carry an effect node id, token source range, or hit-test id.
- Legal target slots/fish: available in ViewModel-derived pending target data and v2 `EffectTargetRequirement`, with final legality still validated by `GameEngine`.
- Reversible vs irreversible: not explicit metadata today. It must be added before committed undo is safe.
- `skipEffectExecution`/`PendingEffectIntent.skipRemaining` can back the `→` control for ending/skipping the current fish ability remainder.
- There is no engine-level `←` command today. A safe design needs staged ViewModel undo first, and engine transaction/undo metadata only for committed reversible steps.
- First unified presentation model exists as `BoardCardInteractionTask` / `BoardCardInteractionStep` / `BoardCardInteractionToken` / `BoardCardInteractionControlState`.
- `IncomingRewardDockState` is the presentation model for external pending rewards where the current player cannot rely on a visible source fish card.

## Classification Summary

- Total cards audited: 215
- Legacy A inline candidates: 73
- Legacy B needs picker/overlay: 51
- Legacy C irreversible/no undo: 91
- Legacy D not enough metadata: 0
- cardIcon entry count: 215
- boardIcon entry count: 0
- incomingRewardDock entry count: 34
- gameEndDock entry count: 39
- directCommit count: 83
- boardTarget count: 139
- handPicker count: 47
- discardOverlay count: 26
- playFishFlow count: 21
- paymentFlow count: 14
- noCommittedUndo count: 61
- stagedOnlyUndo count: 154
- fallbackRequired count: 102

## Four Independent Dimensions

- `inlineEntrySurface`: `cardAbilityIcon`, `boardZoneIcon`, `incomingRewardDock`, `gameEndDock`, or `noInlineEntry`.
- `continuationSurface`: `directCommit`, `boardTarget`, `handPicker`, `discardOverlay`, `playFishFlow`, `paymentFlow`, `reefTarget`, or `fallbackPanel`.
- `commitReversibility`: `stagedOnlyUndo`, `committedUndoSupported`, or `noCommittedUndo`.
- `sourceVisibility`: `ownVisibleSourceCard`, `opponentSourceCard`, `boardZoneOrDiveSite`, `gameEndSourceCard`, or `externalPendingReward`.

## Representative Reclassification

- `recoverFromDiscardOrDraw`: `cardAbilityIcon` entry, `discardOverlay` or `directCommit` continuation, staged undo before command, no committed undo after draw.
- `consumeFishFromHand`: `cardAbilityIcon` entry, `handPicker` plus `boardTarget` continuation, staged undo before command.
- `playFishForFree` / `playFishFromHand`: `cardAbilityIcon` entry, `handPicker` plus `playFishFlow`; paid play also carries `paymentFlow`.
- `drawFish`: `cardAbilityIcon` or `incomingRewardDock` entry, `directCommit` continuation, `noCommittedUndo`.
- `GAME END`: `gameEndDock` or visible `cardAbilityIcon` entry, `directCommit` or target continuation depending on effect, `noCommittedUndo`.
- `AllPlayers`: source player uses `cardAbilityIcon`; target players use `incomingRewardDock`. Each target player skip / staged undo is scoped to their own pending step.

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
- Keep fallback for complex explanations, discard choice, hand picker, discard pile picker, play-fish flows, all-player flows, GAME END, hidden information, and uncertain metadata.
- The target direction is card/dock entry first, with right-side UI reduced to fallback / debug / complex helper.
- External rewards prefer `IncomingRewardDock` because the target player may not have a visible source fish card to tap.

## Representative Records

- `base.main.001` Abyssal Anglerfish | gameEnd | entry cardAbilityIcon, gameEndDock | continuation directCommit | undo noCommittedUndo | gameEndScore
- `base.main.002` Abyssal Halosaur | whenPlayed | entry cardAbilityIcon | continuation handPicker, playFishFlow, paymentFlow | undo stagedOnlyUndo | playFishFromHand
- `base.main.003` Abyssal Spiderfish | whenPlayed | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | hatchEgg
- `base.main.004` Angelshark | gameEnd | entry cardAbilityIcon, gameEndDock | continuation directCommit | undo noCommittedUndo | gameEndScore
- `base.main.005` Angler | ifActivated | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | moveYoungOrSchool
- `base.main.006` Arabian Carpetshark | whenPlayed | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | placeEggOnMatchingFish
- `base.main.007` Atlantic Bluefin Tuna | whenPlayed | entry cardAbilityIcon | continuation directCommit, discardOverlay | undo noCommittedUndo | drawFish, recoverFromDiscardOrDraw
- `base.main.008` Atlantic Bonito | gameEnd | entry cardAbilityIcon, gameEndDock | continuation directCommit | undo noCommittedUndo | gameEndScore
- `base.main.009` Atlantic Mackerel | ifActivated | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | placeEgg
- `base.main.010` Atlantic Sailfish | whenPlayed | entry cardAbilityIcon | continuation directCommit | undo noCommittedUndo | drawFish
- `base.main.011` Atlantic Salmon | gameEnd | entry cardAbilityIcon, gameEndDock | continuation directCommit, handPicker, playFishFlow, paymentFlow | undo noCommittedUndo | gameEndScore, playFishFromHand
- `base.main.012` Atlantic Sturgeon | ifActivated | entry cardAbilityIcon | continuation discardOverlay, directCommit | undo stagedOnlyUndo | recoverFromDiscardOrDraw
- `base.main.013` Atlantic Wolffish | ifActivated | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | hatchEgg
- `base.main.014` Banggai Cardinalfish | ifActivated | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | hatchEgg
- `base.main.015` Barramundi | ifActivated | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | placeEgg
- `base.main.016` Bearded Seadevil | whenPlayed | entry cardAbilityIcon, incomingRewardDock | continuation boardTarget | undo stagedOnlyUndo | placeEggOnMatchingFish
- `base.main.017` Bigeye Tuna | ifActivated | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | placeEgg
- `base.main.018` Bigeye Smooth-Head | whenPlayed | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | placeEggOnMatchingFish
- `base.main.019` Binocular Fish | gameEnd | entry cardAbilityIcon, gameEndDock | continuation directCommit, boardTarget | undo noCommittedUndo | gameEndScore, placeEggOnMatchingFish
- `base.main.020` Black Cardinalfish | whenPlayed | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | hatchEgg, moveYoungOrSchool
- `base.main.021` Black Hagfish | whenPlayed | entry cardAbilityIcon | continuation discardOverlay, directCommit, boardTarget | undo stagedOnlyUndo | recoverFromDiscardOrDraw, placeYoung
- `base.main.022` Black Swallower | whenPlayed | entry cardAbilityIcon | continuation handPicker, playFishFlow, paymentFlow | undo stagedOnlyUndo | playFishFromHand
- `base.main.023` Blob Sculpin | gameEnd | entry cardAbilityIcon, gameEndDock | continuation directCommit, handPicker, playFishFlow, paymentFlow | undo noCommittedUndo | gameEndScore, playFishFromHand
- `base.main.024` Blue Tang | whenPlayed | entry cardAbilityIcon | continuation boardTarget | undo stagedOnlyUndo | placeYoung, moveYoungOrSchool

Full per-card output is in `tools/generated/card_rendering/inline_ability_interaction_audit.json`.
