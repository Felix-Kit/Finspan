# AGENTS.md

## Project Context

This project is the Finspan board game iPad app.

Use Swift and SwiftUI. Treat the app as an interactive multiplayer board game, not a single-player toy or UI-only prototype.

The app is currently developed as a local-authoritative iPad prototype, but the architecture must remain compatible with future online rooms where a cloud server is the source of truth.

## Current Implementation State

The project currently has a working base-game prototype with:

* Local room flow using `LocalAuthoritativeRoomService`
* Command / Event / Reducer architecture
* Deterministic setup
* Sample / baseGame data-source switching
* BaseGameCardCatalog loading local JSON card data
* 18-slot ocean layout
* Bottom bonus strip separate from ocean slots
* Play fish action
* Dive action
* Pending choice architecture
* DiveResolutionQueue
* Printed dive site bonuses resolved step-by-step
* Recover from discard pile or draw pile
* Move young or school
* School auto-formation
* End of week flow
* Side A weekly achievement scoring
* Final scoring
* Final score result UI
* Board resource tokens
* Unified play fish payment UI
* Floating stacked hand UI
* Drag-to-play interaction
* Play fish covering shorter fish / forage fish
* Consumed fish tracking
* Read-only discard pile viewer
* Local card assets under `Finspan/Resources/CardAssets/`
* Minimal fish card face rendering through `FishCardFaceView`
* Shared card rendering metrics through `CardRenderMetrics`
* AbilityRegistry / AbilityResolver
* Minimal sample fish ability framework:

  * WHEN PLAYED
  * IF ACTIVATED
  * CompoundAbilityProgress
  * Fish A / Fish B / Fish C sample abilities

Do not regress any of these existing behaviors unless explicitly asked.

## Core Architecture Rules

* Keep the rules engine, room system, and SwiftUI interface separated.
* The future cloud server is the source of truth for a game room.
* The Host is only a player with management permissions, not the authoritative game server.
* The first version must use `LocalAuthoritativeRoomService` to simulate server behavior locally.
* UI must never directly mutate `GameState`.
* UI may only express player intent by sending a `PlayerCommand`.
* `GameEngine` receives a command, validates whether it is legal, and emits `GameEvent` values.
* `GameState` may only be updated by applying `GameEvent` values.
* All randomness must be controlled by the room service, including values such as `randomSeed`, `shuffledDeck`, and event sequence.
* Do not hard-code Finspan rules inside SwiftUI views.
* Keep domain rules deterministic and easy to test.
* Do not add `Date()`, `UUID()`, `Int.random()`, `shuffle()`, or other uncontrolled randomness inside `GameEngine`, reducers, or SwiftUI views.

## Rule Modeling Rules

* Implement base game rules first, but model design must leave extension points for expansions.
* Do not hard-code resources as egg / young / school. Use `ResourceKind`.
* Do not hard-code fish card play conditions. Use a list of `Requirement` values.
* Do not hard-code costs. Use a list of `Cost` values.
* Do not hard-code fish abilities inside SwiftUI views or one giant switch.
* Model abilities as `AbilityDefinition` values with trigger, conditions, effects, and display metadata.
* Do not hard-code scoring items. Use `ScoreCategory` and `ScoreBreakdown`.
* Do not hard-code achievements in scattered rule code. Use `AchievementDefinition`.
* `GameConfig` must preserve `enabledExpansions`.
* `Ruleset` / `RuleModule` must support adding later modules such as `SharksAndReefsRuleModule` and `NautomaRuleModule`.
* The current phase implements `baseGame`. DLC-related types may be placeholders, but must not affect the minimum base game loop.

## Play Fish Rules

* A fish may be played onto an empty slot or onto an occupied slot.
* If playing onto an occupied slot, the new fish must be longer than the visible fish currently in that slot.
* Occupied targets may be visible `fishCard` or `forageFish`.
* Forage fish are real visible fish for play and dive purposes.
* Do not treat forage fish length as always 0.
* Current sample forage fish lengths:

  * Catalina Goby: 1 cm
  * Showy Bristlemouth: 3 cm
  * Glasshead Grenadier: 9 cm
* When a fish covers another fish, the previously visible fish becomes `ConsumedFish`.
* Existing consumed fish in the same slot must remain preserved.
* Resources on the slot stay on the slot after covering.
* Consumed fish do not count as visible fish.
* Consumed fish must not trigger dive bonuses.
* Consumed fish must not count for visible-fish weekly achievements such as rows of fish.
* Consumed fish score 1 point each at final scoring.
* UI may preview whether a slot is playable, but `GameEngine` must perform final validation.

## Ocean Layout Rules

* The base game sample ocean has 3 dive sites:

  * blue
  * purple
  * green
* Each dive site has 6 ocean slots indexed by `rowIndex`.
* `rowIndex` mapping:

  * 0: Sunlight 1 / top row
  * 1: Sunlight 2
  * 2: Sunlight 3
  * 3: Twilight
  * 4: Midnight 1
  * 5: Midnight 2 / bottom row
* The full ocean slot count is 18.
* `rowIndex 5` is still a normal ocean slot.
* The bottom bonus area is not an ocean slot.
* The bottom bonus strip is a separate UI/model view state below the 18 ocean slots.
* Do not create fake `OceanSlotAddress` values for bottom bonus areas.

## Resource Token Rules

* UI should display egg / young / school as board resource tokens, not only text.
* UI must not directly mutate slot resources.
* Resource token selection is temporary UI state used to construct `PlayerCommand`.
* True resource changes must happen only through `GameEvent` and reducer logic.
* Egg:

  * A slot should normally have at most 1 egg.
  * Egg placement targets must have fish and no egg.
* Young:

  * Young may have multiple tokens in one slot.
  * If a slot has 3 young and no school, it must automatically form 1 school.
* School:

  * A slot may have at most 1 school.
  * Do not allow UI or rules to create a second school in the same slot.
* If GameState has an illegal resource state, SwiftUI should not silently fix it.
* Illegal resource correction belongs in rules / reducer logic, not views.

## Dive Resolution Rules

* Dive resolution must be sequential.
* Do not generate all dive pending choices at once.
* A dive should build a `DiveResolutionQueue`.
* Only the current queue step should create an active pending choice.
* Resolving or skipping the current pending choice advances the queue.
* Active player must not advance until the queue is complete.
* Week end must not trigger until pending choices and active dive queue are complete.
* Dive queue order:

  * Sunlight printed dive site bonus
  * Sunlight IF ACTIVATED fish abilities
  * Twilight printed dive site bonus
  * Twilight IF ACTIVATED fish abilities
  * Midnight printed dive site bonus
  * Midnight IF ACTIVATED fish abilities
  * Bottom bonus
* Forage fish and consumed fish do not have fish abilities.
* Only visible `fishCard` values may generate fish ability steps.

## Ability System Rules

* Current ability system is minimal and sample-driven.
* Sample abilities currently exist for:

  * Fish A: IF ACTIVATED draw 1 fish card
  * Fish B: IF ACTIVATED compound ability: place 2 eggs and hatch 1 egg in any order
  * Fish C: WHEN PLAYED draw 1 fish card
* Do not implement all real fish cards in one large change.
* Do not hard-code ability behavior by checking sample card IDs inside `GameEngine`.
* Prefer an extensible `AbilityRegistry` / `AbilityResolver` approach for the next ability-system refactor.
* Unsupported abilities should not crash the game.
* Unsupported abilities should be representable and skippable, with UI text such as “能力暂未接入”.
* Compound abilities must support:

  * multiple effect units
  * any-order resolution when allowed
  * partial execution
  * ending / skipping remaining benefits
* GAME END abilities are currently only modeled or placeholder unless explicitly requested.

## UI Rules

* The app targets Chinese users. All user-visible interface copy must use Simplified Chinese.
* Swift type names, file names, function names, enum cases, and test names must stay in English.
* User-visible copy should not mix Chinese and English casually.
* Avoid scattering large amounts of hard-coded Chinese strings throughout SwiftUI views. Prefer centralized copy management.
* SwiftUI views must stay focused on presentation and user intent collection.
* Do not put rules validation or state mutation logic into SwiftUI views.
* `GameBoardViewModel` may compute preview state, availability, display text, and temporary UI selection state.
* Final legality still belongs to `GameEngine`.

## Hand and Payment UI Rules

* The floating hand should remain stacked near the bottom.
* Do not reintroduce a large white dock behind the hand cards.
* Selecting a hand card should make that same card appear pulled out from the hand stack.
* Do not draw a separate duplicate enlarged card unless explicitly requested.
* Discard payment should be selected directly from the hand cards.
* Resource payment should be selected directly from board resource tokens.
* The unified play fish payment panel should summarize:

  * selected fish
  * target slot
  * discard-card payment progress
  * egg payment progress
  * young payment progress
* Drag-to-play should only select the card and target slot.
* Drag-to-play must not directly mutate `GameState`.
* Confirming play fish must still send `PlayerCommand.playFish`.

## Data Layer Rules

* Keep sample card data separate from real base-game data.
* `SampleCardCatalog` should remain usable for local development.
* `BaseGameCardCatalog` should load reviewed local JSON data.
* Default sample flow and baseGame flow must both remain usable.
* Do not tie app runtime functionality to scraping external sites or loading finsearch remote URLs.
* Finsearch may be used only as a development-time import source.
* Card images and metadata sourced from finsearch or other external assets must be imported through an explicit, reproducible process.
* Runtime card assets must be offline local files under `Finspan/Resources/CardAssets/`.

## DLC / Expansion Rules

* Base game behavior must remain stable.
* `SharksAndReefsRuleModule` and `NautomaRuleModule` should be future modules, not mixed into base-game rules.
* Sharks & Reefs may add coral, sharks, reef overlays, new requirements, new costs, and new ability effects.
* Nautoma uses a simplified solo ruleset and should not be modeled as a normal player with a full ocean mat unless explicitly requested.
* DLC placeholders may exist, but must not alter base-game loop.

## Testing Rules

* Prefer testable pure Swift logic before building UI.
* Add or update tests for every rule behavior change.
* For UI-heavy changes, add `GameBoardViewModelTests` for view state, availability, and command construction.
* `build-for-testing` must pass after each change.
* Do not run `test` against `generic/platform=iOS Simulator`.
* If no concrete simulator is available, only run `build-for-testing` and report that tests were not executed.
* If concrete simulator tests hang at CoreSimulator / handshake, stop instead of repeatedly retrying.
* Summaries must honestly report whether tests actually ran.

## Development Workflow

* Before every large change, explain the implementation plan first.
* After every change, summarize which files changed, why they changed, and the recommended next step.
* Keep local changes small and commit stable checkpoints frequently.
* After a stable feature is completed, commit and push before starting the next major feature.
* Keep domain rules deterministic and easy to test.
* Design local services so they can later be replaced by Pass & Play, local nearby networking, Game Center, online rooms, Sharks & Reefs expansion support, and Nautoma solo mode.

## Current Recommended Next Step

Next recommended task:

Connect `recoverFromDiscardOrDraw` pending choices to the discard pile selection mode.

Constraints for the next task:

* Do not change current behavior.
* Do not modify UI unless necessary for compile fixes.
* Do not modify random logic.
* Keep sample flow and baseGame flow working.
* Do not modify final scoring.
* Do not implement Sharks & Reefs or Nautoma.
