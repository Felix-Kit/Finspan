# Ability Coverage Audit

Last updated: 2026-06-12.

This audit is generated from runtime card JSON in `Finspan/Resources/Cards` using:

```bash
python3 tools/scripts/audit_ability_coverage.py
```

The script reads `AbilityRegistry.swift` to distinguish ability ids that still have an `unsupported.*` name but are actually mapped in the current registry.

## Summary

- Total real cards scanned: 215.
- Cards with ability data: 215.
- Currently mapped ability cards: 88.
- Mixed ability cards: 0.
- Unsupported ability cards: 127.
- Unmapped ability cards: 0.

Ability Coverage Pass 1 raised mapped real-card ability coverage from 45 to 88 cards. Unsupported cards dropped from 170 to 127.

## By Trigger

- `whenPlayed`: 90.
- `ifActivated`: 86.
- `gameEnd`: 39.

## GAME END Coverage

Current GAME END sweep status remains:

- 39 GAME END abilities total.
- 33 implemented.
- 10 scoring-only implemented through final scoring.
- 23 executable implemented through the existing ability / pending choice flow.
- 6 future work:
  - Honeycomb Scaly Dragonfish
  - Speckled Butterflyfish
  - Tripodfish
  - Blackmouth Angler
  - Sixgill Sawshark
  - Yokozuna Slickhead

## Pattern Groups

Current raw token pattern counts:

- `all players`: 7.
- `consume shorter fish from hand`: 9.
- `draw fish`: 3.
- `gain coral`: 31.
- `hatch egg`: 33.
- `move young/school`: 24.
- `place egg on each matching fish`: 26.
- `place egg single target`: 9.
- `place young`: 9.
- `play fish for free`: 7.
- `play fish paying cost`: 14.
- `scatter school`: 7.
- `scoring-only GAME END`: 10.
- `unknown / unsupported`: 26.

Pass 1 now maps these low-ambiguity generic patterns through `AbilityPatternParser`:

- Repeated `[DrawCard]` tokens, currently 1 to 4 cards, to `drawFish(count:)`.
- Repeated `[FishHatch]` tokens to repeated `hatchEgg` effect units.
- Repeated `[FishEgg]` tokens to repeated single-target egg placement.
- Repeated `[YoungFish]` tokens to repeated young placement.
- `[FishEgg][ArrowDown]...` matching-fish filters to on-each egg placement:
  - top row / estuary
  - bottom row / deepwater
  - blue / purple / green dive site
  - small / medium / large fish
  - predator fish
- Simple repeated coral token strings using `[BlueCoral]`, `[PurpleCoral]`, `[GreenCoral]`, and `[AnyCoral]` to coral gain effects.

Patterns still deferred for rule confirmation:

- `AllPlayers` effects, because local authoritative multiplayer semantics need explicit event ordering.
- Compound draw/discard/hatch/move sequences, because they need partial resolution and skip semantics.
- Consume fish count patterns such as `[ConsumeFish1]` and `[ConsumeFish1][ConsumeFish1]`.
- Move young / school patterns using `[SchoolFeederMove]`, including distance, blocking, and destination constraints.
- Complex play-fish-from-hand or free-play filters beyond the already implemented GAME END subset.
- Conditional coral requirements inside an ability, such as Blackmouth Angler and Yokozuna Slickhead.
- Mixed young plus consume / move patterns such as Sixgill Sawshark.
- Recover-from-discard-or-draw remains supported by the engine for known mapped abilities, but the current JSON audit did not expose a broad raw token pattern that can be safely auto-mapped in this pass.

## Representative Current Mapped Cards

- Blue Lanternfish, `base.starter.127`, WHEN PLAYED, `[DrawCard][DrawCard][DrawCard][DrawCard]`, mapped to draw 4.
- Atlantic Sailfish, `base.main.010`, WHEN PLAYED, `[DrawCard][DrawCard][DrawCard]`, mapped by generic parser to draw 3.
- Sarcastic Fringehead, `sr.main.190`, IF ACTIVATED, `[DrawCard][DrawCard]`, mapped by generic parser to draw 2.
- Abyssal Spiderfish, `base.main.003`, WHEN PLAYED, `[FishHatch][FishHatch][FishHatch]`, mapped by generic parser to three hatch steps.
- Atlantic Wolffish, `base.main.013`, IF ACTIVATED, `[FishHatch]`, mapped by generic parser to hatch 1.
- Atlantic Mackerel, `base.main.009`, IF ACTIVATED, `[FishEgg][FishEgg]`, mapped by generic parser to two single-target egg placements.
- Giant Devil Ray, `base.main.049`, WHEN PLAYED, `[YoungFish][YoungFish]`, mapped by generic parser to two young placements.
- Arabian Carpetshark, `base.main.006`, IF ACTIVATED, `[FishEgg][ArrowDown][Predator] on each`, mapped by generic parser to on-each predator egg placement.
- Filetail Catshark, `sr.main.152`, IF ACTIVATED, `[FishFromHandConsume]`, mapped to consume fish from hand.
- Longnose Hawkfish, `sr.main.171`, IF ACTIVATED, `[BlueCoral]`, mapped to gain blue coral.
- Indian Sail-fin Surgeonfish, `sr.main.165`, IF ACTIVATED, `[BlueCoral][PurpleCoral]`, mapped by generic parser to blue plus purple coral.
- European Anchovy, `base.main.041`, GAME END, `[FishEgg][ArrowDown][Estuary]`, mapped to top row on-each egg placement.
- Ocean Sunfish, `base.main.081`, GAME END, `[FishEgg][ArrowDown][FishLengthLarge] on each`, mapped to on-each large fish egg placement.
- Faceless Cusk, `base.main.044`, GAME END, `[FishFromHand][ArrowDown][PlayFishBottomRow]`, mapped to paid play fish from hand into bottom row.
- Common Bluestripe Snapper, `sr.main.147`, GAME END, `[BlueCoral][BlueCoral][BlueCoral]`, mapped to gain 3 blue coral.
- Tasseled Scorpionfish, `sr.main.202`, GAME END scoring-only, mapped to game end score condition.

## Representative Deferred Cards

- Giant Hatchetfish, `base.main.050`, IF ACTIVATED, `(all players) [DrawCard][AllPlayers]`, deferred for multiplayer sequencing.
- Spookfish, `base.main.111`, IF ACTIVATED, `(all players) [FishEgg][AllPlayers]`, deferred for multiplayer target ordering.
- Footballfish, `base.main.048`, IF ACTIVATED, `[SchoolFeederMove]`, deferred for movement constraints.
- Snaggletooth, `base.main.107`, IF ACTIVATED, `[SchoolFeederMove][SchoolFeederMove]`, deferred for repeated movement semantics.
- Tripodfish, `base.main.117`, GAME END, `[ConsumeFish1][ConsumeFish1]`, deferred for consume-count semantics.
- Blackmouth Angler, `sr.main.141`, GAME END, `[FreePlayFishFromHand] if no [AnyCoral] in this fish's dive site`, deferred for coral-site condition modeling.
- Yokozuna Slickhead, `sr.main.209`, GAME END, `[FishFromHand][ArrowDown][AnyCoral]...`, deferred for coral-gated placement.
- Sixgill Sawshark, `sr.main.193`, GAME END, `[YoungFish][FishFromHandConsume]`, deferred as a mixed young plus consume ability.

## Notes

- Normal user room setup should default to real base-game data; sample data remains an explicit debug/test option.
- This document is an audit and planning artifact. It does not imply newly implemented abilities beyond the current registry.
