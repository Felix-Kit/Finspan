# Ability Engine v2 Design

Last updated: 2026-06-13.

This document describes the Ability Engine v2 core migration and Cleanup Passes 1-4.
It is an architecture consolidation pass, not a rules expansion.

## Current Coverage Baseline

- Runtime source of truth: `Finspan/Resources/Cards`.
- Webpage source check: `tools/scripts/check_card_data_against_webpage.py`.
- Current runtime card coverage: 215 mapped / 0 unsupported.
- GAME END abilities: 39 total, 10 scoring-only, 29 executable, 0 unsupported.
- Runtime ability texts containing `/`: 0.
- Branch choice is not a current mainline implementation target.
- `AllPlayers` abilities are implemented.
- S&R colored coral conditional abilities are implemented.
- Rope Fish is not present in runtime JSON or the saved webpage source.
- `base.main.096` is Red Scorpionfish.

## Goal

Ability Engine v2 consolidates existing execution paths into a shared model:

- `AbilityIR`
- `EffectGraph`
- `EffectNode`
- `EffectCondition`
- `PendingEffectSet`

The current pass keeps behavior unchanged. It introduces a bridge from legacy
`PendingChoice` into `PendingEffectSet`, so existing command validation and
reducers continue to produce the same game results while UI and future debug
tools can start reading a unified execution shape.

Cleanup Pass 1 makes `PendingEffectSet` the primary pending action display
model for `GameBoardViewModel`. Cleanup Pass 2 adds `PendingEffectIntent` as the
generic resolve / skip intent model and bridges it back to existing
`PendingChoiceResolution` values. Cleanup Pass 3A extends `EffectNodeMetadata`
so reward tokens, payment summaries, target requirements, and staged prompt
requirements can be described by v2 metadata. Cleanup Pass 3B adds native
effect-node command entry points for safe simple resolve / skip flows while
retaining legacy `PendingChoiceResolution` as the compatibility fallback for
complex staged payloads. Cleanup Pass 4 migrates the main staged payloads into
native effect-node payloads while keeping the same legacy reducer event shell.

## Unified Execution Shape

The target execution flow is:

```text
AbilityIR -> EffectGraph -> PendingEffectSet -> player selection -> GameEvent -> reducer -> recomputed PendingEffectSet
```

The engine owns effect availability and ordering. UI should read:

- current execution id
- source card id
- source ability id
- source player id
- target player id, when applicable
- available effect nodes
- blocked effect nodes
- completed effect nodes
- skipped effect nodes

UI should not need to understand whether the current ability is `AllPlayers`,
a compound pool, a conditional bonus, Blackmouth Angler, or GAME END.

## v2 Core Model

`AbilityIR` identifies one ability execution and owns an `EffectGraph`.

`EffectGraph` stores effect nodes and dependency edges. It can express:

- unordered compound effects through nodes without dependencies
- ordered effects through node dependencies
- condition-gated bonus effects through dependency plus condition nodes
- source-site conditions through source conditions
- AllPlayers fan-out through scoped effects

`PendingEffectSet` is the runtime bridge for the currently actionable portion of
an execution. It exposes:

- `executionId`
- `effectNodeId`
- `sourceCardId`
- `sourceAbilityId`
- `sourcePlayerId`
- `targetPlayerId`
- `trigger`
- `decisionIndex`
- `parentExecutionId`
- `debugLabel`
- `debugDescription`

These fields are intentionally lightweight trace hooks for v2.1. This pass does
not implement full replay, a debug timeline, graph visualization, or trace UI.

## Current Adapter Boundary

Legacy `PendingChoice` remains in place. It now has:

- an optional persisted `pendingEffectSet`
- a computed `v2PendingEffectSet` bridge

The bridge maps existing stable flows into v2 concepts:

- compound effect pool -> unordered or ordered effect nodes
- AllPlayers -> scoped execution with source player and active target player
- colored coral conditional bonus -> base node plus condition-gated bonus node
- Blackmouth Angler -> free-play node with source-site no-coral and source-fish visibility conditions
- GAME END executable abilities -> normal ability graph with `gameEnd` trigger

Legacy fields such as `compoundAbilityProgress`, `allPlayersProgress`, and
`conditionalBonusProgress` are intentionally retained for this pass. A later v2
cleanup can remove step-specific fields once `PendingEffectSet` fully drives
resolution and UI.

## Cleanup Pass 1 Boundary

`GameBoardViewModel` now consumes `PendingEffectSet` first for the generic
pending action panel:

- available effect nodes become the primary source for basic pending action
  buttons such as draw, compound draw/recover, place egg, place young, and hatch
- AllPlayers pending state displays the active target player from v2 target
  player metadata
- progress summary reads available / completed / skipped counts from
  `PendingEffectSet`
- each v2-derived action carries an `effectNodeId` for future trace / replay

Legacy `PendingChoice` fields are still used for:

- `kind` and `expectedInput` target-selection prompts
- reward pool token generation
- source / target slot selection
- coral payment selection
- scatter school, consume-from-hand, free-play, and play-from-hand staged target
  flows
- the final `PendingChoiceResolution` payload sent through existing commands

The synchronization is one-way in this pass:

```text
legacy PendingChoice / optional stored PendingEffectSet -> v2PendingEffectSet -> ViewModel action display
```

The engine still resolves legacy `PendingChoiceResolution` values for complex
staged payloads. Native effect-node commands are available for safe simple
resolve / skip flows, and both paths intentionally produce the same
`pendingChoiceResolved` events.

## Cleanup Pass 2 Boundary

Cleanup Pass 2 introduces `PendingEffectIntent`, an effect-node based intent
layer for pending actions:

- `resolveEffect(executionId:effectNodeId:payload:)`
- `skipEffect(executionId:effectNodeId:)`
- `skipRemaining(executionId:)`

`GameBoardViewModel` now carries these intents on v2-derived pending action
buttons and on the right action panel's primary action. When the user taps an
action, the ViewModel validates the intent against the current
`PendingEffectSet.available` nodes, then uses `AbilityEngineV2Adapter` to map
the intent to the existing `PendingChoiceResolution` command payload.

The adapter is intentionally thin. It does not own rule semantics; it only
checks that the referenced execution / effect node is still available and maps
safe v2 intents to existing engine-supported resolutions.

Migrated resolve / skip paths:

- draw fish
- recover-from-discard-or-draw deck fallback
- recover discard card selection
- place egg / place young / hatch target-slot selection for simple choices
- compound effect selection for draw / recover / place egg / place young / hatch
- single-effect skip
- compound skip remaining

Migrated target requirement paths:

- `placeEgg`
- `placeYoung`
- `hatchEgg`
- `recoverFromDiscardOrDraw` discard-card selection

Still legacy / deferred staged flows:

- native engine resolution for reward token choices
- full staged selection payload resolution
- native `PlayerCommand` support for effect-node resolution

The resulting flow is:

```text
PendingEffectSet.available -> PendingEffectIntent -> adapter -> PendingChoiceResolution -> GameEngine
```

This keeps gameplay unchanged while letting the UI carry `executionId`,
`effectNodeId`, `sourcePlayerId`, and `targetPlayerId` through the action layer.
Those ids remain lightweight trace hooks only; v2.1 full replay, debug timeline,
and graph viewer are not implemented.

## Cleanup Pass 3A Boundary

Cleanup Pass 3A moves the description layer for complex prompts into
`EffectNodeMetadata` while keeping the existing engine command path:

```text
EffectNode -> metadata -> ViewModel prompt / reward token -> PendingChoiceResolution -> GameEngine
```

New metadata fields:

- `targetRequirement`
- `paymentRequirement`
- `resourceRequirement`
- `rewardTokenRequirement`
- `stagedSelection`

Reward token display now starts from v2 metadata for:

- draw fish
- recover-from-discard-or-draw
- place egg
- place young
- hatch egg
- move young / school
- gain coral and coral payment token summaries
- scatter school
- consume fish from hand
- play fish for free
- play fish from hand

Staged prompt metadata now describes:

- scatter school source and young target selection
- consume-from-hand consumer fish and hand fish selection
- free-play hand fish and target slot selection
- paid play hand fish, target slot, and payment stages
- coral payment source / discard-card stages

This pass deliberately does not change how those choices resolve. The ViewModel
still maps selections to existing `PendingChoiceResolution` values, and
`GameEngine` validation remains the source of truth. Native
`PlayerCommand.resolveEffectNode` / `skipEffectNode` support is deferred to a
later cleanup pass.

Still legacy / deferred after Pass 3A:

- staged selection payloads still use `RewardSelectionMode`
- coral payment source selection still resolves through legacy coral
  `PendingChoiceResolution`
- scatter / consume / free-play / paid-play staged choices still use legacy
  staged progress fields
- reward pool token actions still dispatch legacy resolutions
- v2.1 full replay, debug timeline, and graph viewer are not implemented

## Cleanup Pass 3B Boundary

Cleanup Pass 3B adds native effect-node command entry points:

- `PlayerCommand.resolveEffectNode`
- `PlayerCommand.skipEffectNode`
- `PlayerCommand.skipEffectExecution`

The native engine entry validates:

- the referenced `executionId` still matches a current pending execution
- the referenced `effectNodeId` is still available for resolve / single-effect
  skip
- `sourcePlayerId` and `targetPlayerId` match the current
  `PendingEffectSet`
- existing pending-choice ownership and legality still pass through
  `GameEngine` validation

Native-capable effects now enter through the v2 command path and are converted
inside `GameEngine` to the same internal pending-choice resolution events:

- draw fish
- recover-from-discard-or-draw deck fallback
- recover selected discard card
- place egg / place young / hatch target-slot choices
- simple compound effect selection for draw / recover / egg / young / hatch
- single effect skip
- skip remaining / finish compound execution
- AllPlayers current target skip
- GAME END executable skip / handled marking

Complex staged flows remain legacy fallback:

- scatter school staged source / target payloads
- consume-from-hand staged consumer / hand-card payloads
- free-play and paid-play from hand staged payloads
- play-from-hand target plus payment payloads
- coral payment resolution
- reward token action resolution when no native payload is ready

The current flow is now:

```text
PendingEffectSet.available -> PendingEffectIntent -> native PlayerCommand when safe -> GameEngine
PendingEffectSet.available -> PendingEffectIntent -> legacy PendingChoiceResolution fallback for staged payloads -> GameEngine
```

Cleanup Pass 3B still does not implement v2.1 replay, a debug timeline, a graph
viewer, or native staged payload dispatch.

## Cleanup Pass 4 Boundary

Cleanup Pass 4 keeps the `resolveEffectNode` / `skipEffectNode` command path and
adds native payloads for the previously staged flows:

- `EffectScatterSchoolPayload` carries the source school slot and all target
  young slots.
- `EffectConsumeFishFromHandPayload` carries the consumer fish slot and consumed
  hand card id.
- `EffectPlayCardPayload` carries the hand card id, target slot, payment, and
  optional cover target.
- `EffectCoralPaymentPayload` carries egg / young / discard coral payment.
- `EffectRewardTokenPayload` carries reward-token kind and count for native
  reward actions where the payload is complete.

Native coverage after Pass 4:

- draw / recover / egg / young / hatch simple effects
- compound effect selection and skip remaining
- scatter school full source plus target placement
- consume-from-hand full consumer plus hand-card selection
- free-play and paid-play final card / target / payment payloads
- coral payment via egg, young, or discard
- draw reward token action
- AllPlayers skip and GAME END executable skip

The reducer still receives `PendingChoiceResolvedEvent` with
`PendingChoiceResolution` compatibility payloads. This is intentional: Pass 4
migrates command intent and validation payload shape first, without deleting the
legacy event shell or step-specific fields.

Legacy Still Required:

- old `resolvePendingChoice` command support for saved state, tests, and
  compatibility with existing pending choices
- move young / school source-target flow until it has a rich native payload
- `recoverFromDiscardOrDraw` discard-pile selection UI polish
- reward token actions whose selections still require additional UI state
- legacy pending fields used to rebuild follow-up choices and preserve saved
  local room compatibility

Safe To Remove Later:

- scatter-school staged source / target progress dispatch once saved-state
  migration no longer needs it
- consume-from-hand staged consumer / hand-card progress dispatch once all UI
  callers use `EffectConsumeFishFromHandPayload`
- free-play / paid-play staged hand-card and target dispatch once native payload
  callers cover every path
- coral payment legacy resolution entry points after native payload coverage is
  proven in ViewModel tests

Blocked By Future Work:

- native effect-node event type that replaces `PendingChoiceResolvedEvent`
- complete staged payload native migration for move young / school and any
  multi-step reward action not yet represented as one payload
- v2.1 trace / replay / debug timeline using the reserved execution and node ids

Cleanup Pass 4 still does not implement v2.1 replay, a debug timeline, or a
graph viewer.

## Behavior Guarantees

This pass must not change gameplay results:

- no new abilities are added
- no card JSON changes are made
- card identity remains canonical `Card.id`
- existing `AllPlayers` behavior remains per-player and isolated
- existing compound pool behavior remains any-order where previously supported
- colored coral conditional bonus still resolves base first, then optional bonus
- Blackmouth Angler still checks the source fish's current dive site
- GAME END scoring-only logic remains unchanged

## Next Steps

- Finish the remaining staged native payloads, especially move young / school
  and any reward-token action that still needs multi-step UI state.
- Stabilize GameBoardViewModel pending UI around v2 metadata and native payloads.
- Add v2.1 trace / replay / debug timeline using the reserved ids.
- Remove legacy step-specific pending fields only after v2 choices are fully
  authoritative and saved-state compatibility has a migration path.
