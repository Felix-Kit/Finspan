# Ability Rule Confirmation Questions

Last updated: 2026-06-12.

This document tracks the rule questions still blocking unsupported real-card abilities.

## Current Status

- Pass 2D before: 131 mapped / 84 unsupported
- Pass 2D after: 153 mapped / 62 unsupported

Already confirmed and implemented:

- `[Discard]` means recover from discard pile to hand; shortfall draws from deck.
- `[ConsumeFish1]` chooses any visible consumer fish, then consumes one shorter fish from hand.
- `FreePlayFishFromHand` waives cost only, not legality.
- `[ArrowDown]` binds condition / scope to the preceding benefit.
- Non-`AllPlayers` bracket abilities do not have fixed left-to-right order.
- Non-`AllPlayers` mixed bracket abilities now resolve from an any-order remaining effect pool.
- Blackmouth Angler checks the source fish's current dive site for coral.
- Blackmouth Angler only allows the free-play target in that same source dive site.

## Still Open

### AllPlayers

Representative real cards:

- `base.main.036` Deepsea Lizardfish
- `base.main.050` Giant Hatchetfish
- `base.main.071` Little Skate
- `base.main.108` Snipe Eel
- `sr.main.161` Great Barracuda
- `sr.main.191` Shortfin Mako

Still unanswered:

- Resolution order across players
- Whether each player resolves fully before the next player starts
- Auto-skip behavior when a player has no legal target
- How per-player pending choices should be surfaced and resumed

### Branch Choice `/`

Representative deferred real cards should be validated against runtime JSON case by case before implementation.

Current note:

- `base.main.096` is not Rope Fish in runtime JSON.
- `base.main.096` is `Red Scorpionfish` with `[SchoolFeederMove]`.
- Do not use Rope Fish / `base.main.096` as a representative branch-choice card in tests or audits.

Still unanswered:

- Does `/` always mean choose exactly one branch?
- When is the branch locked in?
- Can a branch be skipped after partial progress?
- Are all branches optional by default?

## Deferred Until Confirmed

- `AllPlayers` wrappers
- `/` branch-choice abilities
- any runtime patterns whose semantics still require confirmation
