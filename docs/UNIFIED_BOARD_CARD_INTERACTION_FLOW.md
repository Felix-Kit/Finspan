# Unified Board/Card Interaction Flow

This document defines the staged presentation model for future board/card inline interaction. It does not replace the current right-side pending/reward fallback UI and does not change `GameEngine`, Ability Engine, rules, card JSON, randomness, scoring, online rooms, Nautoma, or saved-state migration.

## Why Unify

`playFish` payment, fish ability rewards, printed dive rewards, and coral reef rewards all use staged interaction:

1. Show the current source.
2. Show what must be paid, chosen, or resolved.
3. Highlight legal board/card/reef sources or targets.
4. Let the player stage a local selection.
5. Submit an existing `PlayerCommand` only after the staged selection is complete.

Historically too much of this lived in the right-side panel. That wastes board space and makes payment, reward, and dive flows feel unrelated. The target direction is board/card inline selection with compact fallback panels. This pass adds the pure presentation vocabulary and a Compact Resource HUD first, because full inline ability UI before BoardLayout would create avoidable rework.

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
- `CompactResourceHUDState`

It can represent sources from hand cards, visible fish cards, dive sites/zones, reefs/board markers, and pending effect nodes. It can represent steps for payment source, reward token, target slot/fish/reef, hand card, discard card, confirm, skip, and fallback. It intentionally does not validate rules or mutate `GameState`; final legality remains in `GameEngine`.

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
8. If a source could satisfy multiple costs, or the model lacks enough metadata, fallback to the existing payment panel.
9. Target slot selection is staged separately.
10. When required sources and target slot are complete, `->` is enabled.
11. `->` submits `PlayerCommand.playFish`.
12. `<-` only removes unsubmitted staged selection.

Special cases:

- Hand card cost is a cost token, not a first-click button.
- Egg / young / school costs are paid by direct board token selection.
- Consume / cover shorter fish is paid by direct legal visible fish selection.
- Coral requirement is normally a gate, not a payment source. It displays satisfied / unsatisfied only.
- No-cost fish only require a legal target slot before `->` becomes enabled.

## Ability Staged Flow

The inline audit classified 215 cards as A inline candidates 73, B needs picker/overlay 51, C irreversible/no undo 91, D not enough metadata 0. This model supports staged local resource effects first:

- `placeEgg`: click egg reward icon, then highlight legal fish/slots.
- `hatchEgg`: click hatch icon, then highlight legal egg-bearing slots.
- `gainCoral`: click coral reward icon, then highlight legal reef.
- simple move: click move icon, then choose source and target.
- `scatterSchool`: partial inline; choose source school and any legal young targets, then submit or skip remaining.

Fallback remains required for:

- draw and other hidden information;
- hand picker;
- discard pile picker;
- recover from discard or draw;
- consume fish from hand;
- play fish from ability;
- AllPlayers effects;
- GAME END;
- insufficient metadata or ambiguous mapping.

## Dive / Zone Reward Flow

Dive rewards should move toward board markers instead of the right panel:

1. The active printed reward icon on the board is highlighted.
2. Clicking a reward icon activates that reward step.
3. Legal targets or payment sources highlight in board / hand / reef.
4. Selecting a target/source submits the existing dive reward resolution.
5. `->` skips the current optional reward.
6. Complex cases fallback.

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

Keep the right-side pending / reward UI and overlays for:

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
- insufficient metadata.

The current first implementation only adds the shared presentation model and Compact Resource HUD. Full inline ability interaction, full inline `playFish`, full inline dive reward, engine undo, Ability Engine changes, BoardLayout, online rooms, Nautoma, and saved-state migration remain out of scope.
