# Ability Engine v2 Design

Last updated: 2026-06-13.

This document describes the Ability Engine v2 core migration and Cleanup Pass 1.
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
model for `GameBoardViewModel`. Legacy `PendingChoice` still exists as the
compatibility shell for command payloads and target-selection workflows.

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

The engine still resolves existing `PendingChoiceResolution` values. Direct
`resolve effect node` / `skip effect node` commands are intentionally deferred
until a later v2 cleanup pass.

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

- Move reward pool token generation and target prompts to v2 target requirement
  metadata.
- Teach engine resolution to accept effect-node choices directly.
- Add v2.1 trace / replay / debug timeline using the reserved ids.
- Remove legacy step-specific pending fields only after v2 choices are fully
  authoritative and tested.
