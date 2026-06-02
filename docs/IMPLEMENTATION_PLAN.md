# Finspan Base Game Minimum Playable Implementation Plan

## Architecture Check

The project is mostly ready to enter base game rule implementation. The important source-of-truth flow already exists:

- UI sends `PlayerCommand`.
- `LocalAuthoritativeRoomService` acts as the local authoritative service.
- `GameEngine` validates commands and produces event drafts.
- `AuthoritativeEventFactory` assigns sequence, timestamp, room id, and random seed.
- `GameState` advances through `GameEvent`.
- UI reads from `RoomService` and does not directly mutate `GameRoom` or `GameState`.

Current risks before implementing base game rules:

- Domain card data was too thin. Fish cards need costs, requirements, and abilities before `playFish` can be implemented without hard-coding rules.
- Resource modeling must not assume a fixed base-game-only list. Use `ResourceKind` so future expansions can add resources.
- Rules are currently centered on one `GameRuleSet`; keep it small and delegate expansion behavior through `Ruleset` / `RuleModule` as rules grow.
- UI currently contains direct user-visible strings. Before polishing, move user-facing Simplified Chinese copy into a centralized place.
- `GameState` still lacks many base game facts needed for a playable loop, such as player boards, hands, deck/discard zones, resources, divers, weeks, and scoring facts.
- Event payloads are intentionally minimal. Add event payload fields only for synchronized game facts, not UI state.

These risks do not block starting the base game minimum playable version, as long as the next rules work is data-driven and event-sourced.

## 1. Basic Domain Model

Goal: add only the facts needed by the base game minimum loop.

- Define fish card data using `Card`, `Cost`, `Requirement`, and `AbilityDefinition`.
- Define player board state, hand, deck, discard, played fish, resources, and diver positions.
- Keep every model `Codable`, `Equatable`, and `Sendable` where practical.
- Keep `GameConfig.enabledExpansions` intact, even while only `baseGame` is active.
- Avoid adding Sharks & Reefs behavior. Only ensure the model can represent future extensions.

## 2. Deterministic Setup

Goal: local authoritative setup produces replayable game facts.

- `LocalAuthoritativeRoomService` controls `randomSeed`.
- Add deterministic deck creation and shuffle from seed.
- Emit setup-related `GameEvent` values for shuffled deck, initial hands, starting player, and initial board facts.
- Ensure rebuilding `GameState` from event log recreates the same setup.

## 3. Minimal `playFish`

Goal: one active player can play a valid fish card through Command/Event.

- UI sends `PlayerCommand.playFish`.
- `GameEngine` validates active player, card ownership, `Cost`, and `Requirement`.
- Engine emits event drafts such as fish played and resources spent.
- `GameState` updates only by applying resulting `GameEvent` values.
- Do not implement full fish abilities yet. Ability data can exist but most effects can be unsupported until needed.

## 4. Minimal `dive`

Goal: one active player can perform a basic dive action.

- UI sends `PlayerCommand.dive`.
- Validate active player and legal destination using current board facts.
- Emit event facts for diver movement and any minimal resource/card gain needed for the first loop.
- Do not implement advanced ability interactions.

## 5. End Of Week

Goal: preserve the existing six-turn week cadence and add minimal week cleanup.

- Continue emitting `turnEnded`.
- Every six turns emit `weekEnded`.
- Add base cleanup/reset facts as events.
- Keep scoring and achievements separate from cleanup logic.

## 6. End Of Game Scoring

Goal: produce deterministic final score facts.

- Add `ScoreCategory` and `ScoreBreakdown` use in scoring output.
- Emit final scoring events and `gameEnded`.
- Keep score categories data-driven so expansions can add categories later.
- Do not hard-code DLC score categories in base game.

## 7. UI Integration

Goal: expose the minimum playable loop without putting rules in SwiftUI.

- Keep SwiftUI views as command senders and state renderers.
- Move user-facing copy to centralized Simplified Chinese strings before UI grows.
- Add simple hand, board, player resources, current action, and scoring displays.
- Keep UI animation, sheets, and coordinates local-only; never synchronize them as game facts.

## 8. Later Sharks & Reefs DLC

Out of scope for the current phase.

Future support should come through:

- `Expansion.sharksAndReefs`
- `GameConfig.enabledExpansions`
- `SharksAndReefsRuleModule`
- Additional `ResourceKind` values
- Additional `Requirement`, `Cost`, `AbilityDefinition`, `AchievementDefinition`, and `ScoreCategory` data
- Board overlay facts represented as game facts, not UI-only state

## 9. Later Nautoma

Out of scope for the current phase.

Future support should come through:

- `Expansion.nautoma`
- `NautomaRuleModule`
- Command generation for automated behavior
- Rule-module hooks that can alter setup, turn order, scoring, and action selection without changing SwiftUI rules

## Recommended Next Step

Implement the base game setup domain next: deck model, deterministic shuffle, initial hand events, and reducer coverage. Do not implement fish abilities until `playFish` can validate a plain card through `Cost` and `Requirement`.
