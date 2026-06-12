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
- Currently mapped ability cards: 45.
- Mixed ability cards: 0.
- Unsupported ability cards: 170.
- Unmapped ability cards: 0.

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

Patterns that look suitable for unified future implementation:

- Draw fish card patterns such as `[DrawCard]`, `[DrawCard][DrawCard]`, and draw/discard compounds.
- Single and repeated hatch patterns such as `[FishHatch]`.
- Place egg on each matching fish patterns such as `[FishEgg][ArrowDown][Predator] on each`.
- Place egg by row/dive-site patterns such as `[FishEgg][ArrowDown][Estuary]`.
- Move young/school patterns using `[SchoolFeederMove]`.
- Play fish from hand into row/dive-site patterns using `[FishFromHand][ArrowDown]`.
- Consume shorter fish from hand patterns using `[FishFromHandConsume]`.
- S&R coral gain patterns using `[BlueCoral]`, `[PurpleCoral]`, `[GreenCoral]`, or `[AnyCoral]`.
- Free play filtered fish patterns using `[FreePlayFishFromHand]`.

Patterns that need rule confirmation before broad implementation:

- `AllPlayers` effects, because local authoritative multiplayer semantics need explicit event ordering.
- Compound draw/discard/hatch/move sequences, because they need partial resolution and skip semantics.
- Consume fish count patterns such as `[ConsumeFish1][ConsumeFish1]`.
- Conditional coral requirements inside an ability, such as Blackmouth Angler and Yokozuna Slickhead.
- Mixed young plus consume / move patterns such as Sixgill Sawshark.

## Representative Current Mapped Cards

- Blue Lanternfish, `base.starter.127`, WHEN PLAYED, `[DrawCard][DrawCard][DrawCard][DrawCard]`, mapped to draw 4.
- Filetail Catshark, `sr.main.152`, IF ACTIVATED, `[FishFromHandConsume]`, mapped to consume fish from hand.
- Longnose Hawkfish, `sr.main.171`, IF ACTIVATED, `[BlueCoral]`, mapped to gain blue coral.
- European Anchovy, `base.main.041`, GAME END, `[FishEgg][ArrowDown][Estuary]`, mapped to top row on-each egg placement.
- Ocean Sunfish, `base.main.081`, GAME END, `[FishEgg][ArrowDown][FishLengthLarge] on each`, mapped to on-each large fish egg placement.
- Faceless Cusk, `base.main.044`, GAME END, `[FishFromHand][ArrowDown][PlayFishBottomRow]`, mapped to paid play fish from hand into bottom row.
- Common Bluestripe Snapper, `sr.main.147`, GAME END, `[BlueCoral][BlueCoral][BlueCoral]`, mapped to gain 3 blue coral.
- Tasseled Scorpionfish, `sr.main.202`, GAME END scoring-only, mapped to game end score condition.

## Notes

- Normal user room setup should default to real base-game data; sample data remains an explicit debug/test option.
- This document is an audit and planning artifact. It does not imply newly implemented abilities beyond the current registry.
