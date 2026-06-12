# Ability Coverage Audit

Last updated: 2026-06-12.

Generated from runtime card JSON in `Finspan/Resources/Cards` with:

```bash
python3 tools/scripts/audit_ability_coverage.py
```

## Summary

- Total real cards scanned: 215
- Cards with ability data: 215
- Pass 2D before: 131 mapped / 84 unsupported
- Pass 2D after: 153 mapped / 62 unsupported
- Mixed ability cards: 0
- Unmapped ability cards: 0

Coverage history:

- Initial audit: 45 mapped / 170 unsupported
- Pass 1: 88 mapped / 127 unsupported
- Pass 2A: 103 mapped / 112 unsupported
- Pass 2B Preflight: 104 mapped / 111 unsupported
- Pass 2C: 131 mapped / 84 unsupported
- Pass 2D: 153 mapped / 62 unsupported

## Trigger Counts

- `whenPlayed`: 90
- `ifActivated`: 86
- `gameEnd`: 39

## Pattern Groups

Current raw token pattern counts from runtime JSON:

- `all players`: 7
- `consume shorter fish from hand`: 18
- `draw fish`: 4
- `free play from source dive site with no coral`: 1
- `gain coral`: 31
- `hatch egg`: 23
- `mixed compound effect pool`: 13
- `mixed egg + hatch`: 2
- `mixed hatch + move`: 4
- `mixed move + draw`: 2
- `mixed young + consume`: 2
- `mixed young + move`: 2
- `move young/school`: 18
- `place egg on each matching fish`: 26
- `place egg single target`: 9
- `place young`: 4
- `play fish for free`: 6
- `play fish paying cost`: 14
- `recover from discard or draw`: 12
- `scatter school`: 7
- `scoring-only GAME END`: 10

## Pass 2D Additions

Pass 2D maps these new real-card patterns:

- Blackmouth Angler source-site conditional free play:
  - `[FreePlayFishFromHand] if no [AnyCoral] in this fish's dive site`
  - canonical mapping:
    `playFishForFree(filter: .any, placement: .sameDiveSiteAsSource, sourceCondition: .sourceDiveSiteHasNoCoral, count: 1)`
- Non-`AllPlayers` mixed bracket abilities now use a compound effect pool.
- Players may resolve remaining bracketed benefits in any order.
- Current legality is recomputed after each completed effect.
- Skipping finishes the remaining optional pool; completed effects do not roll back.
- `[ArrowDown]` still binds condition / scope to the immediately preceding benefit.

Supported mixed patterns in this pass:

- `young + consume`
- `young + move`
- `hatch + move`
- `move + draw`
- `egg + hatch`
- existing low-ambiguity mixed draw / recover / egg pools now use the same any-order compound model

## Confirmed Semantics

- `[Discard]` means recover from discard pile to hand; if short, draw the remainder from deck.
- `[ConsumeFish1]` lets the player choose any visible fish in their ocean as the consumer, then consume one shorter fish from hand under that consumer.
- `FreePlayFishFromHand` waives cost only; it does not waive legality.
- Free play still enforces:
  - allowed zones
  - required dive site
  - target slot legality
  - cover-shorter-fish legality
  - coral requirements
- Blackmouth Angler checks the source fish's current dive site for coral.
- Blackmouth Angler only allows the free-play target in that same dive site.
- If the source fish is covered, hidden, or cannot be located, Blackmouth Angler becomes unavailable / skippable rather than producing an invalid unknown state.

## Representative Mapped Cards

- `base.main.024` Blue Tang, `[SchoolFeederMove][YoungFish]`
- `base.main.051` Giant Hawkfish, `[FishHatch][SchoolFeederMove]`
- `base.main.062` Honeycomb Scaly Dragonfish, `[YoungFish][SchoolFeederMove]`
- `base.main.101` Shortspine African Angler, `[SchoolFeederMove][DrawCard][DrawCard]`
- `sr.main.141` Blackmouth Angler, `[FreePlayFishFromHand] if no [AnyCoral] in this fish's dive site`
- `sr.main.179` Portuguese Dogfish, `[YoungFish][FishFromHandConsume]`
- `sr.main.193` Sixgill Sawshark, `[YoungFish][FishFromHandConsume]`
- `base.main.109` Speckled Butterflyfish, `[FishHatch][FishHatch][FishHatch][SchoolFeederMove]`

## Still Deferred

These remain intentionally unsupported in Pass 2D:

- `AllPlayers` wrappers
- `/` branch-choice abilities
- patterns whose semantics are still not confirmed by runtime data + rules review

Representative deferred cards:

- `base.main.036` Deepsea Lizardfish, `(all players) [FishHatch][SchoolFeederMove][AllPlayers]`
- `base.main.050` Giant Hatchetfish, `(all players) [DrawCard][AllPlayers]`
- `base.main.111` Spookfish, deferred branch / unresolved semantics
- `sr.main.191` Shortfin Mako, `(all players) [FishFromHandConsume][FishFromHandConsume][AllPlayers]`

## Runtime Data Corrections

- `base.main.096` is `Red Scorpionfish`, not Rope Fish.
- Runtime JSON for `base.main.096` is `[SchoolFeederMove]`.
- Rope Fish should not be used as a representative runtime card in current audit docs or tests unless the actual JSON source changes.

## GAME END Snapshot

- Total GAME END abilities: 39
- Implemented scoring-only: 10
- Implemented executable: 29
- Remaining unsupported GAME END abilities in Pass 2D: 0

## Recommended Next Pass

1. Design multiplayer resolution order for `AllPlayers`.
2. Add explicit `/` branch-choice modeling.
3. Continue validating unknown semantics strictly against runtime JSON before mapping.
