# Unified Board/Card Interaction Flow

This document defines the staged presentation model for board, card, and dock-driven interaction. The current primary action center is `BottomRewardDock`: reward entry, pending action, `playFish` confirmation, skip, staged undo, GAME END candidates, and external AllPlayers rewards should appear in the bottom dock first. The permanent right-side reward / pending / play-fish confirmation panel is no longer part of the main board layout. This does not change `GameEngine`, Ability Engine, rules, card JSON, randomness, scoring, online rooms, Nautoma, or saved-state migration.

## Why Unify

`playFish` payment, fish ability rewards, printed dive rewards, and coral reef rewards all use staged interaction:

1. Show the current source.
2. Show what must be paid, chosen, or resolved.
3. Highlight legal board/card/reef sources or targets.
4. Let the player stage a local selection.
5. Submit an existing `PlayerCommand` only after the staged selection is complete.

Historically too much of this lived in the right-side panel. That wastes board space and makes payment, reward, and dive flows feel unrelated. The current target direction is bottom-dock entry first, with board/card highlights as supporting context. Full card icon tap / hit-test is paused as the primary interaction because ability icons are small, some icon runs are compound semantics, external rewards often have no visible source card, and stable hit metadata still needs more work.

## Presentation Model

The first shared model is presentation-only:

- `BoardCardInteractionTask`
- `BoardCardInteractionStep`
- `BoardCardInteractionToken`
- `BoardCardInteractionSource`
- `BoardCardInteractionSourceOption`
- `BoardCardInteractionTarget`
- `BoardCardInteractionAction`
- `BoardCardInteractionControlState`
- `BoardCardInteractionTaxonomy`
- `CompactResourceHUDState`
- `IncomingRewardDockState`
- `BottomRewardDockState`
- `BottomRewardDockToken`
- `BottomRewardDockAction`
- `BottomRewardDockDisplayMode`

It can represent sources from hand cards, visible fish cards, dive sites/zones, reefs/board markers, and pending effect nodes. It can represent steps for payment source, reward token, target slot/fish/reef, hand card, discard card, confirm, skip, and fallback. It intentionally does not validate rules or mutate `GameState`; final legality remains in `GameEngine`.

## Inline Taxonomy

Inline interaction is now modeled across independent dimensions:

- `InlineEntrySurface`: `cardAbilityIcon`, `boardZoneIcon`, `incomingRewardDock`, `gameEndDock`, or `noInlineEntry`.
- `ContinuationSurface`: `directCommit`, `boardTarget`, `handPicker`, `discardOverlay`, `playFishFlow`, `paymentFlow`, `reefTarget`, or `fallbackPanel`.
- `CommitReversibility`: `stagedOnlyUndo`, `committedUndoSupported`, or `noCommittedUndo`.
- `SourceVisibility`: `ownVisibleSourceCard`, `opponentSourceCard`, `boardZoneOrDiveSite`, `gameEndSourceCard`, or `externalPendingReward`.

This matters because `needs picker / overlay` is not the same as `cannot inline`. It means an inline entry can launch a picker or overlay continuation. `irreversible / no undo` is also not the same as `cannot inline`; it only means `<-` cannot undo after command submission.

For the current MVP, `cardAbilityIcon` is treated as an auxiliary highlight / future shortcut, not the required first click. Ability icon groups containing `ArrowDown`, such as `FishEgg + ArrowDown + Predator`, are highlighted as one semantic group; `ArrowDown` is not a standalone action.

## Token Roles

Cost / requirement tokens and reward / ability tokens have opposite interaction direction.

Cost / requirement token:

- Primary role is progress display.
- Player clicks legal sources directly on board / hand / reef.
- The system auto-matches the source to an unmet cost when unambiguous.
- The token changes to completed / dim after the source is selected.
- Clicking the same selected source again unstages it.
- If one source can satisfy multiple costs and cannot be inferred safely, use fallback.

Reward / ability token:

- Can be the active entry point.
- Player clicks the reward token on the source fish / board marker.
- The selected token becomes visually active.
- Board / hand / reef highlights valid targets.
- Target selection submits the existing pending effect command.

Do not model every interaction as “click icon, then click target.” That is right for rewards, but wrong for `playFish` costs.

## playFish Staged Flow

1. Player selects or drags a hand fish card.
2. The fish card cost / requirement icons show progress only.
3. Unmet cost icons are active-looking, completed icons are dim / checked, impossible icons are disabled with a reason.
4. Board slots, board resource tokens, hand cards, visible fish, and reef/coral sources are highlighted if they are legal staged sources.
5. Player directly clicks a legal source:
   - discard-card payment: click a hand card;
   - egg payment: click an egg token;
   - young payment: click a young token;
   - school payment, if rules later require it: click a school token;
   - consume / cover shorter fish: click the legal visible fish on the board;
   - coral payment only if a future rule makes coral a consumed payment source.
6. The ViewModel auto-matches the source to the earliest unambiguous unmet cost.
7. Clicking the same selected source removes that staged source and marks the cost incomplete again.
8. If a source could satisfy multiple costs, or the model lacks enough metadata, the bottom dock opens the relevant overlay / picker instead of occupying the right side.
9. Target slot selection is staged separately.
10. When required sources and target slot are complete, the bottom dock `->` is enabled.
11. `->` submits `PlayerCommand.playFish`.
12. The bottom dock `<-` only removes unsubmitted staged selection or cancels the staged play.

Special cases:

- Hand card cost is a cost token, not a first-click button.
- Egg / young / school costs are paid by direct board token selection.
- Consume / cover shorter fish is paid by direct legal visible fish selection.
- Coral requirement is normally a gate, not a payment source. It displays satisfied / unsatisfied only.
- No-cost fish only require a legal target slot before `->` becomes enabled.

## Bottom Reward Dock

`BottomRewardDock` is the primary action center for the current implementation. Display modes are `hidden`, `handleOnly`, `compact`, and `expanded`. Idle board state may show only a handle or nothing; active pending work opens compact mode; tapping the dock expands details without consuming the right edge of the board.

The dock carries:

- current pending reward tokens;
- current ability reward tokens;
- dive / zone reward tokens when no stable board marker exists;
- GAME END candidate abilities;
- AllPlayers or opponent-source external rewards;
- staged `playFish` summary and confirm state;
- `->` confirm / skip / finish controls;
- `<-` staged undo / cancel controls;
- fallback reason text and overlay / sheet entry points.

The old right-side reward list, pending action list, and playFish confirmation panel have been removed from the main board layout. Complex continuations still exist, but the dock is the entry point that opens a discard overlay, hand picker, playFish staged flow, or debug / helper sheet.

## Ability Staged Flow

The inline audit still preserves the legacy reference counts A inline candidates 73, B needs picker/overlay 51, C irreversible/no undo 91, D not enough metadata 0, but those are no longer used as a single inline/no-inline decision. The new audit records entry surface, continuation surface, committed undo, and source visibility separately. Card inline remains auxiliary for now; dock entry is primary.

- `placeEgg`: click egg reward icon, then highlight legal fish/slots.
- `hatchEgg`: click hatch icon, then highlight legal egg-bearing slots.
- `gainCoral`: click coral reward icon, then highlight legal reef.
- simple move: click move icon, then choose source and target.
- `scatterSchool`: partial inline; choose source school and any legal young targets, then submit or skip remaining.
- `recoverFromDiscardOrDraw`: choose the recover token in the bottom dock; continue through discard overlay when discard targets exist, or direct draw fallback when none are available. After draw, no committed undo.
- `consumeFishFromHand`: choose the consume token in the bottom dock; continue through hand picker, then board target.
- `playFishForFree` / `playFishFromHand`: choose the play-fish token in the bottom dock; continue through hand picker into staged `playFish`. Paid play also includes payment flow.
- `drawFish`: choose draw in the bottom dock; direct commit; no committed undo.
- `GAME END`: use game-end dock candidates; direct score or target continuation depending on effect; no committed undo.
- `AllPlayers`: source player may see a source card highlight, but target players use the bottom incoming reward dock. One target player's skip / staged undo does not affect other players.

Fallback remains required for:

- hand picker;
- discard pile picker;
- recover from discard or draw;
- consume fish from hand;
- play fish from ability;
- AllPlayers effects;
- GAME END;
- insufficient metadata or ambiguous mapping.

## Incoming / External Rewards

External rewards cannot rely only on source fish card highlighting. A target player may be resolving an AllPlayers reward from another player's fish, a hidden or off-board source, a board/dive-site marker, or a later GAME END candidate. `IncomingRewardDockState` remains the presentation-only source summary model for those cases, and it is surfaced through `BottomRewardDock`.

The dock carries:

- source player avatar / color / name;
- source fish mini summary: fish name, card id, trigger text;
- visible reward icons using `GameTokenIconResolver`;
- continuation hints such as `handPicker`, `discardOverlay`, `boardTarget`, `directCommit`, or `fallbackPanel`;
- fallback reason text and an overlay / sheet entry point when the current MVP needs a picker or complex helper;
- `->` / `<-` controls scoped to the current player's own pending reward.

The dock appears only while there is an external pending reward and disappears after completion or skip. It does not submit commands by itself; it is an entry surface and staged presentation model.

## Dive / Zone Reward Flow

Dive rewards should eventually move toward board markers, but current board reward markers are not stable enough to be the primary entry surface. For now, dive / zone rewards enter through the bottom dock:

1. The active printed reward / zone step is summarized in the bottom dock.
2. Choosing a dock reward token activates that reward step.
3. Legal targets or payment sources highlight in board / hand / reef.
4. Selecting a target/source submits the existing dive reward resolution.
5. Dock `->` skips the current optional reward.
6. Complex cases open overlay / sheet / picker from the dock.

Twilight coral payment mapping remains:

- blue reef reward: pay one egg source;
- purple reef reward: pay one young source;
- green reef reward: discard one hand card.

These are payment-source selections. The coral reward marker is the entry point; payment is chosen by clicking the legal source.

## Controls

`->` means the forward action for the current staged task:

- staged `playFish` complete: confirm `PlayerCommand.playFish`;
- active pending effect: `PendingEffectIntent.skipEffect` / `skipEffectNode`, or `skipRemaining` / `skipEffectExecution`;
- active dive reward: skip current optional reward through existing pending choice / effect intent;
- fallback panel: open or focus the fallback action.

`<-` means staged-only undo:

- remove selected reward icon;
- remove selected source;
- remove selected target;
- return from target step to reward/source step.

`<-` never means committed undo. It cannot undo draw, hidden information, submitted `GameEvent`, another player's AllPlayers step, or GAME END scoring.

## Fallback Policy

Do not use the right-side panel as a permanent fallback. Complex cases should remain accessible through the bottom dock, which opens the relevant overlay / sheet / picker for:

- draw;
- card picker;
- discard pile picker;
- hand picker;
- complex `playFish`;
- consume fish from hand;
- AllPlayers;
- GAME END;
- hidden information;
- ambiguous source-to-cost matching;
- insufficient metadata;
- temporary debug / complex helper popovers.

The current implementation removes the permanent right-side reward / pending / play-fish confirmation panel from the main board layout, adds `BottomRewardDock`, keeps card inline as source / group highlight only, and keeps all command submission on existing paths. Full card ability tapping, full inline `playFish`, full inline dive reward, engine undo, Ability Engine changes, rule changes, card JSON changes, BoardLayout, online rooms, Nautoma, and saved-state migration remain out of scope.
