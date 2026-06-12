# Ability Coverage Audit

Last updated: 2026-06-12.

Generated from runtime card JSON in `Finspan/Resources/Cards` using:

```bash
python3 tools/scripts/audit_ability_coverage.py
```

The script reads `AbilityRegistry.swift` to distinguish ability ids that still have an `unsupported.*` name but are actually mapped by the current registry or generic parser.

## Summary

- Total real cards scanned: 215.
- Cards with ability data: 215.
- Currently mapped ability cards: 131.
- Mixed ability cards: 0.
- Unsupported ability cards: 84.
- Unmapped ability cards: 0.

Coverage history:

- Initial audit: 45 mapped / 170 unsupported.
- Pass 1: 88 mapped / 127 unsupported.
- Pass 2A: 103 mapped / 112 unsupported.
- Pass 2B Preflight: 104 mapped / 111 unsupported.
- Pass 2C: 131 mapped / 84 unsupported.

## By Trigger

- `whenPlayed`: 90.
- `ifActivated`: 86.
- `gameEnd`: 39.

## Pattern Groups

Current raw token pattern counts:

- `all players`: 7.
- `compound card gain`: 4.
- `consume shorter fish from hand`: 18.
- `draw fish`: 4.
- `gain coral`: 31.
- `hatch egg`: 33.
- `move young/school`: 24.
- `place egg on each matching fish`: 26.
- `place egg single target`: 9.
- `place young`: 9.
- `play fish for free`: 7.
- `play fish paying cost`: 14.
- `recover from discard or draw`: 12.
- `scatter school`: 7.
- `scoring-only GAME END`: 10.

## Implemented Generic Patterns

Pass 1 maps these low-ambiguity patterns through `AbilityPatternParser`:

- Repeated `[DrawCard]` tokens to `drawFish(count:)`.
- Repeated `[FishHatch]` tokens to repeated hatch steps.
- Repeated `[FishEgg]` tokens to repeated single-target egg placement.
- Repeated `[YoungFish]` tokens to repeated young placement.
- `[FishEgg][ArrowDown]...` matching-fish filters to on-each egg placement.
- Simple coral token strings using `[BlueCoral]`, `[PurpleCoral]`, `[GreenCoral]`, and `[AnyCoral]`.

Pass 2A maps:

- Pure repeated `[SchoolFeederMove]`.
- Low-ambiguity paid play-from-hand placement patterns.
- Low-ambiguity free play-from-hand patterns.

Pass 2C maps:

- Pure repeated `[Discard]` through `[Discard]` x5 to `recoverFromDiscardOrDraw`.
- Ordered card-gain compounds:
  - `[DrawCard][DrawCard][Discard][Discard]`
  - `[FishEgg][FishEgg][DrawCard][DrawCard]`
  - `[DrawCard][DrawCard][DrawCard][FishEgg]`
  - structurally equivalent pure `[DrawCard]` / `[Discard]` / `[FishEgg]` sequences.
- `[ConsumeFish1]` and `[ConsumeFish1][ConsumeFish1]` to repeated `consumeFishFromHand`.
- Coral-gated paid play-from-hand:
  - `[FishFromHand][ArrowDown][AnyCoral][AnyCoral][AnyCoral]`
  - `[FishFromHand][ArrowDown][AnyCoral]` x5

Confirmed semantics:

- `[Discard]` means recover from discard pile to hand; if the discard pile is short, draw the remaining cards from the fish deck. It is not discard-from-hand.
- `[ConsumeFish1]` lets the player choose any visible fish in their ocean as the consumer, then consume one shorter fish from hand under that consumer.
- `[ArrowDown]` marks condition / scope. For coral-gated hand play, the target dive site must itself have the required coral count.
- `FreePlayFishFromHand = waive cost only, not waive legality`.

## GAME END Coverage

Current GAME END status:

- 39 GAME END abilities total.
- 35 implemented.
- 10 scoring-only implemented through final scoring.
- 25 executable implemented through the ability / pending choice flow.
- 4 future work:
  - Honeycomb Scaly Dragonfish
  - Speckled Butterflyfish
  - Blackmouth Angler
  - Sixgill Sawshark

Pass 2C moved these GAME END abilities out of future work:

- Tripodfish, `[ConsumeFish1][ConsumeFish1]`, now uses repeated consume.
- Yokozuna Slickhead, `[FishFromHand][ArrowDown][AnyCoral]` x5, now uses coral-gated paid play.

Blackmouth Angler remains deferred because `[FreePlayFishFromHand] if no [AnyCoral] in this fish's dive site` needs a source-dive-site condition on free play. That is separate from target-dive-site coral-gated paid play.

## Representative Current Mapped Cards

- Blue Lanternfish, `base.starter.127`, WHEN PLAYED, `[DrawCard][DrawCard][DrawCard][DrawCard]`, mapped to draw 4.
- Megamouth Shark, `sr.main.173`, WHEN PLAYED, `[DrawCard]` x5, mapped to draw 5.
- Abyssal Spiderfish, `base.main.003`, WHEN PLAYED, `[FishHatch][FishHatch][FishHatch]`, mapped to three hatch steps.
- Atlantic Mackerel, `base.main.009`, IF ACTIVATED, `[FishEgg][FishEgg]`, mapped to two single-target egg placements.
- Giant Devil Ray, `base.main.049`, WHEN PLAYED, `[YoungFish][YoungFish]`, mapped to two young placements.
- Arabian Carpetshark, `base.main.006`, IF ACTIVATED, `[FishEgg][ArrowDown][Predator] on each`, mapped to on-each predator egg placement.
- European Anchovy, `base.main.041`, GAME END, `[FishEgg][ArrowDown][Estuary]`, mapped to top row on-each egg placement.
- Footballfish, `base.main.048`, IF ACTIVATED, `[SchoolFeederMove]`, mapped to one move young / school step.
- Snaggletooth, `base.main.107`, IF ACTIVATED, `[SchoolFeederMove][SchoolFeederMove]`, mapped to two sequential move steps.
- Abyssal Halosaur, `base.main.002`, WHEN PLAYED, `[FishFromHand][ArrowDown][PlayFishBottomRow]`, mapped to paid play into bottom row.
- Red Lionfish, `base.main.095`, IF ACTIVATED, `[FishFromHand][ArrowDown][Sun]`, mapped to paid play into sunlight.
- Lollipop Catshark, `sr.main.170`, IF ACTIVATED, `[FreePlayFishFromHand]`, mapped to free play.
- Shortnose Demon Catshark, `sr.main.192`, IF ACTIVATED, `[FreePlayFishFromHand][FishLengthSmall] only`, mapped to free play a small fish.
- Atlantic Sturgeon, `base.main.012`, IF ACTIVATED, `[Discard]`, mapped to recover 1.
- Paintspotted Moray, `base.main.086`, WHEN PLAYED, `[Discard][Discard][Discard]`, mapped to recover 3.
- African Coelacanth, `sr.starter.211`, WHEN PLAYED, `[Discard]` x5, mapped to recover 5.
- Atlantic Bluefin Tuna, `base.main.007`, WHEN PLAYED, `[DrawCard][DrawCard][Discard][Discard]`, mapped to ordered draw 2 then recover 2.
- Smoothcheek Lanternfish, `base.starter.129`, WHEN PLAYED, `[FishEgg][FishEgg][DrawCard][DrawCard]`, mapped to ordered egg 2 then draw 2.
- Mandarinfish, `base.starter.131`, WHEN PLAYED, `[DrawCard][DrawCard][DrawCard][FishEgg]`, mapped to ordered draw 3 then egg 1.
- Creolefish, `base.main.034`, IF ACTIVATED, `[ConsumeFish1]`, mapped to one consume opportunity.
- Sargassum Fish, `base.main.099`, IF ACTIVATED, `[ConsumeFish1][ConsumeFish1]`, mapped to two consume opportunities.
- Tripodfish, `base.main.117`, GAME END, `[ConsumeFish1][ConsumeFish1]`, mapped to two consume opportunities.
- Reef Triggerfish, `sr.main.182`, WHEN PLAYED, `[FishFromHand][ArrowDown][AnyCoral]` x3, mapped to paid play into a dive site with at least 3 coral.
- Yokozuna Slickhead, `sr.main.209`, GAME END, `[FishFromHand][ArrowDown][AnyCoral]` x5, mapped to paid play into a dive site with at least 5 coral.
- Common Bluestripe Snapper, `sr.main.147`, GAME END, `[BlueCoral][BlueCoral][BlueCoral]`, mapped to gain 3 blue coral.
- Tasseled Scorpionfish, `sr.main.202`, GAME END scoring-only, mapped to a final-score condition.

## Representative Deferred Cards

- Giant Hatchetfish, `base.main.050`, IF ACTIVATED, `(all players) [DrawCard][AllPlayers]`, deferred for multiplayer sequencing.
- Spookfish, `base.main.111`, IF ACTIVATED, `(all players) [FishEgg][AllPlayers]`, deferred for multiplayer target ordering.
- Giant Hawkfish, `base.main.051`, WHEN PLAYED, `[FishHatch][SchoolFeederMove]`, deferred as mixed movement plus hatch sequencing.
- Shortspine African Angler, `base.main.101`, WHEN PLAYED, `[SchoolFeederMove][DrawCard][DrawCard]`, deferred as mixed movement plus draw sequencing.
- Rope Fish, `base.main.096`, WHEN PLAYED, `[SchoolFeederMove][SchoolFeederMove][SchoolFeederMove] / [DrawCard]`, deferred as branch-choice movement / draw sequencing.
- Blackmouth Angler, `sr.main.141`, GAME END, `[FreePlayFishFromHand] if no [AnyCoral] in this fish's dive site`, deferred for source-site condition modeling.
- Sixgill Sawshark, `sr.main.193`, GAME END, `[YoungFish][FishFromHandConsume]`, deferred as a mixed young plus consume ability.

## Recommended Next Ability Pass

1. Confirm and implement source-site conditional free play, starting with Blackmouth Angler.
2. Confirm mixed `[SchoolFeederMove]` sequencing with hatch / draw / discard.
3. Confirm branch-choice `/` cards, especially Rope Fish.
4. Design `AllPlayers` resolution order and per-player pending queues before mapping multiplayer effects.

## Notes

- Normal user room setup defaults to real base-game data; sample data remains an explicit debug/test option.
- This document is an audit and planning artifact. It should be regenerated after each ability pass.
