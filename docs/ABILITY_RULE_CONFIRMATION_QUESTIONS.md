# Ability Rule Confirmation Questions

Last updated: 2026-06-12.

This document tracks rule questions that still block unsupported real-card abilities. It is derived from:

- [ABILITY_COVERAGE_AUDIT.md](/Users/work/Projects/Finspan/docs/ABILITY_COVERAGE_AUDIT.md)
- `python3 tools/scripts/audit_ability_coverage.py`

## Overview

Current real-card coverage after Pass 2C:

- Total real cards with ability data: 215.
- Currently mapped: 131.
- Currently unsupported: 84.

Confirmed and implemented in Pass 2C:

- `[Discard]` means recover from discard pile to hand. If the discard pile has fewer cards than the token count, draw the remainder from the fish deck.
- `[Discard]` is not discard-from-hand.
- `[ConsumeFish1]` means choose any visible fish in your ocean as the consumer, then consume one shorter fish from hand under that consumer.
- Repeated `[ConsumeFish1]` tokens are independent consume opportunities, and each opportunity may choose a different consumer.
- `[ArrowDown]` marks a condition / scope. For coral-gated hand play, the target dive site must itself satisfy the coral count.
- `FreePlayFishFromHand = waive cost only, not waive legality`.

Remaining question buckets:

1. `AllPlayers` sequencing.
2. Mixed `SchoolFeederMove` with hatch / draw / discard / young.
3. Branch-choice cards using `/`.
4. Source-site conditional free play, especially Blackmouth Angler.
5. Mixed young plus consume / move.

## AllPlayers

Representative cards:

- `base.main.050` Giant Hatchetfish, `ifActivated`, `(all players) [DrawCard][AllPlayers]`
- `base.main.108` Snipe Eel, `ifActivated`, `(all players) [FishEgg][AllPlayers]`
- `base.main.071` Little Skate, `ifActivated`, `(all players) [SchoolFeederMove][AllPlayers]`
- `base.main.016` Bearded Seadevil, `whenPlayed`, `(all players) [FishEgg][ArrowDown][FishLengthSmall] on each [AllPlayers]`
- `base.main.036` Deepsea Lizardfish, `whenPlayed`, `(all players) [FishHatch][SchoolFeederMove][AllPlayers]`
- `sr.main.161` Great Barracuda, `whenPlayed`, `(all players) [BlueCoral][BlueCoral][AllPlayers]`
- `sr.main.191` Shortfin Mako, `whenPlayed`, `(all players) [FishFromHandConsume][FishFromHandConsume][AllPlayers]`

Confirmed partial semantics:

- `[FishEgg][ArrowDown][FishLengthMedium] on each` means place an egg on each eligible medium fish.
- The `[AllPlayers]` multiplayer resolution wrapper is still deferred.

Questions to confirm:

- Must all players resolve, or may each player independently skip?
- Resolution order: active player first in turn order, first-player-marker order, or another order?
- Does each player choose targets only from their own ocean / hand / discard?
- If one player has no legal target, is that player auto-skipped?
- Should one player fully resolve their effect before the next player starts?

## Mixed SchoolFeederMove

Representative cards:

- `base.main.051` Giant Hawkfish, `[FishHatch][SchoolFeederMove]`
- `base.main.101` Shortspine African Angler, `[SchoolFeederMove][DrawCard][DrawCard]`
- `base.main.096` Rope Fish, `[SchoolFeederMove][SchoolFeederMove][SchoolFeederMove] / [DrawCard]`
- `base.main.024` Blue Tang, `[SchoolFeederMove][YoungFish]`
- `base.main.036` Deepsea Lizardfish, `(all players) [FishHatch][SchoolFeederMove][AllPlayers]`

Already implemented:

- Pure `[SchoolFeederMove]` and repeated pure `[SchoolFeederMove]`.

Questions to confirm:

- Do mixed tokens execute strictly left-to-right?
- Can every step be skipped independently, or only the whole ability?
- If one movement step cannot resolve, do later draw / hatch / young steps still execute?
- Can repeated movement move the same young / school more than once?
- Should movement plus hatch / draw / discard become one sequential compound pending queue?

## Branch Choice `/`

Representative card:

- `base.main.096` Rope Fish, `[SchoolFeederMove][SchoolFeederMove][SchoolFeederMove] / [DrawCard]`

Questions to confirm:

- Does `/` mean choose exactly one branch?
- If so, when does the player choose branch: before resolving any step?
- Can the player switch branch after a failed or skipped step?
- Are both branches optional?

## Source-Site Conditional Free Play

Representative card:

- `sr.main.141` Blackmouth Angler, `gameEnd`, `[FreePlayFishFromHand] if no [AnyCoral] in this fish's dive site`

Already implemented nearby:

- Reef Triggerfish: paid play into a target dive site with at least 3 coral.
- Yokozuna Slickhead: GAME END paid play into a target dive site with at least 5 coral.
- Free play still waives cost only and does not waive legality.

Questions to confirm:

- For Blackmouth Angler, the condition checks the source fish's current dive site, not the target dive site. Please confirm.
- If the source dive site has no coral, may the played fish go to any legal slot, or only the source fish's dive site?
- If the source fish moves or is covered before GAME END resolution, is its current visible slot still the source-site reference?

## Mixed Young + Consume / Move

Representative cards:

- `base.main.062` Honeycomb Scaly Dragonfish, `[YoungFish][SchoolFeederMove]`
- `sr.main.179` Portuguese Dogfish, `[YoungFish][FishFromHandConsume]`
- `sr.main.193` Sixgill Sawshark, `gameEnd`, `[YoungFish][FishFromHandConsume]`
- `base.main.024` Blue Tang, `[SchoolFeederMove][YoungFish]`

Already implemented nearby:

- Pure `[YoungFish]` and repeated `[YoungFish]`.
- `FishFromHandConsume`.
- `[ConsumeFish1]`.
- Pure `[SchoolFeederMove]`.

Questions to confirm:

- Are mixed young + consume / move abilities strictly sequential?
- If the young placement cannot resolve, does the consume or move step still proceed?
- If the consume step cannot resolve, does the prior young placement remain?
- Should these abilities use the same sequential compound pending queue as Pass 2C card-gain compounds?

## Still Deferred

Do not map these until the questions above are answered:

- `AllPlayers` effects.
- Mixed `SchoolFeederMove` sequences.
- Branch-choice `/` cards.
- Blackmouth Angler source-site conditional free play.
- Mixed young plus consume / move cards.

## Free Play Principle

This is fixed in implementation and should not be reopened:

- `FreePlayFishFromHand = waive cost only`
- Free play does not waive legality.
- Free play still enforces:
  - allowed zones
  - required dive site
  - slot legality
  - cover-shorter-fish legality
  - coral requirement
- Successful free play still triggers the played fish's `WHEN PLAYED` ability.
