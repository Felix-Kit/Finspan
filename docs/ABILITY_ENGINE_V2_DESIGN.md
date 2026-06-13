# Ability Engine v2 Design

Last updated: 2026-06-13.

This document describes the Ability Engine v2 core migration. It is an
architecture consolidation pass, not a rules expansion.

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

- Move more ViewModel action construction to `PendingEffectSet.available`.
- Teach engine resolution to accept effect-node choices directly.
- Add v2.1 trace / replay / debug timeline using the reserved ids.
- Remove legacy step-specific pending fields only after v2 choices are fully
  authoritative and tested.
