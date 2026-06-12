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
- Currently mapped ability cards: 104.
- Mixed ability cards: 0.
- Unsupported ability cards: 111.
- Unmapped ability cards: 0.

Ability Coverage Pass 1 raised mapped real-card ability coverage from 45 to 88 cards. Unsupported cards dropped from 170 to 127.
Ability Coverage Pass 2A raised mapped real-card ability coverage from 88 to 103 cards. Unsupported cards dropped from 127 to 112.
Pass 2B Preflight only made one low-risk parser fix: pure repeated `[DrawCard]` now covers 5 cards as well, raising mapped coverage from 103 to 104 cards and lowering unsupported cards from 112 to 111.

## By Trigger

- `whenPlayed`: 90.
- `ifActivated`: 86.
- `gameEnd`: 39.

## Pass 2B Preflight

Pass 2B Preflight did not open a new implementation sweep. It produced a rule-confirmation checklist for the remaining deferred groups:

- [ABILITY_RULE_CONFIRMATION_QUESTIONS.md](/Users/work/Projects/Finspan/docs/ABILITY_RULE_CONFIRMATION_QUESTIONS.md)

The current recommendation is:

1. Confirm coral-gated play-from-hand and related conditional coral checks.
2. Confirm `[ConsumeFish1]` semantics before implementing consume-count cards.
3. Confirm mixed `SchoolFeederMove` sequencing and branch-choice cards.
4. Confirm `AllPlayers` ordering only after the single-player / local-authoritative semantics are explicit.

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

Pass 2A now maps these additional low-ambiguity generic patterns through `AbilityPatternParser`:

- Pure repeated `[SchoolFeederMove]` tokens to repeated `moveYoungOrSchool` effect units.
- Low-ambiguity paid play-from-hand placement patterns to `playFishFromHand(costMode: .payCost)`:
  - top row / estuary
  - bottom row / deepwater
  - sunlight row
  - blue / purple / green dive site
- Low-ambiguity free play-from-hand patterns to `playFishForFree`:
  - any fish
  - small / medium / large fish
  - bioluminescent fish
  - camouflage fish

`FreePlayFishFromHand` remains intentionally strict:

- it waives cost only
- it does not waive legality
- free play still enforces allowed zones, required dive site, slot legality, cover-shorter-fish legality, and coral requirement
- the played fish still triggers its `WHEN PLAYED` ability on success

Pass 2B Preflight also extended the already-supported repeated draw parser from 4 cards to 5 cards, which maps Megamouth Shark without introducing new rule semantics.

Patterns still deferred for rule confirmation:

- `AllPlayers` effects, because local authoritative multiplayer semantics need explicit event ordering.
- Compound draw/discard/hatch/move sequences, because they need partial resolution and skip semantics.
- Consume fish count patterns such as `[ConsumeFish1]` and `[ConsumeFish1][ConsumeFish1]`.
- Mixed move young / school patterns where `[SchoolFeederMove]` is combined with hatch, draw, discard, or other effects.
- Complex play-fish-from-hand or free-play filters beyond the low-ambiguity generic parser set.
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
- Footballfish, `base.main.048`, IF ACTIVATED, `[SchoolFeederMove]`, mapped by generic parser to one move young / school step.
- Snaggletooth, `base.main.107`, IF ACTIVATED, `[SchoolFeederMove][SchoolFeederMove]`, mapped by generic parser to two sequential move young / school steps.
- Abyssal Halosaur, `base.main.002`, WHEN PLAYED, `[FishFromHand][ArrowDown][PlayFishBottomRow]`, mapped by generic parser to paid play fish from hand into bottom row.
- Red Lionfish, `base.main.095`, IF ACTIVATED, `[FishFromHand][ArrowDown][Sun]`, mapped by generic parser to paid play fish from hand into sunlight row.
- Megamouth Shark, `sr.main.173`, WHEN PLAYED, `[DrawCard][DrawCard][DrawCard][DrawCard][DrawCard]`, mapped by generic parser to draw 5.
- Lollipop Catshark, `sr.main.170`, IF ACTIVATED, `[FreePlayFishFromHand]`, mapped by generic parser to free play any fish from hand.
- Shortnose Demon Catshark, `sr.main.192`, IF ACTIVATED, `[FreePlayFishFromHand][FishLengthSmall] only`, mapped by generic parser to free play a small fish.
- Dwarf Lanternshark, `sr.main.150`, IF ACTIVATED, `[FreePlayFishFromHand][Bioluminescent] only`, mapped by generic parser to free play a bioluminescent fish.
- Swell Shark, `sr.main.200`, IF ACTIVATED, `[FreePlayFishFromHand][Camouflage] only`, mapped by generic parser to free play a camouflage fish.
- Common Bluestripe Snapper, `sr.main.147`, GAME END, `[BlueCoral][BlueCoral][BlueCoral]`, mapped to gain 3 blue coral.
- Tasseled Scorpionfish, `sr.main.202`, GAME END scoring-only, mapped to game end score condition.

## Representative Deferred Cards

- Giant Hatchetfish, `base.main.050`, IF ACTIVATED, `(all players) [DrawCard][AllPlayers]`, deferred for multiplayer sequencing.
- Spookfish, `base.main.111`, IF ACTIVATED, `(all players) [FishEgg][AllPlayers]`, deferred for multiplayer target ordering.
- Giant Hawkfish, `base.main.051`, WHEN PLAYED, `[FishHatch][SchoolFeederMove]`, deferred as mixed movement plus hatch sequencing.
- Shortspine African Angler, `base.main.101`, WHEN PLAYED, `[SchoolFeederMove][DrawCard][DrawCard]`, deferred as mixed movement plus draw sequencing.
- Rope Fish, `base.main.096`, WHEN PLAYED, `[SchoolFeederMove][SchoolFeederMove][SchoolFeederMove] / [DrawCard]`, deferred as branch-choice movement / draw sequencing.
- Tripodfish, `base.main.117`, GAME END, `[ConsumeFish1][ConsumeFish1]`, deferred for consume-count semantics.
- Blackmouth Angler, `sr.main.141`, GAME END, `[FreePlayFishFromHand] if no [AnyCoral] in this fish's dive site`, deferred for coral-site condition modeling.
- Reef Triggerfish, `sr.main.182`, WHEN PLAYED, `[FishFromHand][ArrowDown][AnyCoral] if no [AnyCoral] in target fish's dive site`, deferred for coral-gated placement.
- Yokozuna Slickhead, `sr.main.209`, GAME END, `[FishFromHand][ArrowDown][AnyCoral]...`, deferred for coral-gated placement.
- Sixgill Sawshark, `sr.main.193`, GAME END, `[YoungFish][FishFromHandConsume]`, deferred as a mixed young plus consume ability.

## Recommended Next Ability Pass

The next pass should avoid card-face visual work and focus on rule semantics that need confirmation:

1. Use [ABILITY_RULE_CONFIRMATION_QUESTIONS.md](/Users/work/Projects/Finspan/docs/ABILITY_RULE_CONFIRMATION_QUESTIONS.md) to confirm coral-gated play-from-hand and conditional coral checks.
2. Confirm consume-count cards such as Tripodfish before implementing repeated consume effects.
3. Confirm mixed `[SchoolFeederMove]` sequences, especially whether movement plus hatch/draw/discard is ordered, branch-based, or any-order.
4. Confirm `AllPlayers` ordering and whether each player may independently skip or must resolve in turn order.

## Notes

- Normal user room setup should default to real base-game data; sample data remains an explicit debug/test option.
- This document is an audit and planning artifact. It does not imply newly implemented abilities beyond the current registry.
