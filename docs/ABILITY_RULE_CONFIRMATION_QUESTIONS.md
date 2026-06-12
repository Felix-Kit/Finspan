# Ability Rule Confirmation Questions

Last updated: 2026-06-12.

This document tracks the rule questions that still block the remaining unsupported real-card abilities. It is derived from:

- [ABILITY_COVERAGE_AUDIT.md](/Users/work/Projects/Finspan/docs/ABILITY_COVERAGE_AUDIT.md)
- `python3 tools/scripts/audit_ability_coverage.py`

## Overview

Current real-card coverage:

- Total real cards with ability data: 215
- Currently mapped: 104
- Currently unsupported: 111

Remaining unsupported cards overlap across several rule-question buckets. The main buckets are:

- `AllPlayers`: 34 cards contain `[AllPlayers]`
- mixed `SchoolFeederMove` sequences: 24 cards
- compound draw / discard / hatch / move sequences without `AllPlayers`: 39 cards
- consume count using `[ConsumeFish1]`: 10 cards
- mixed young + consume / move: 4 cards
- coral-gated play-from-hand: 3 cards
- broader conditional coral requirement / conditional second clause: 19 cards
- residual unknown / unsupported token groups after current parser coverage: 25 cards

Recommended implementation priority:

1. coral-gated play-from-hand and conditional coral requirement
2. consume count and mixed young + consume
3. mixed `SchoolFeederMove` sequences
4. residual unknown groups such as pure `Discard`
5. `AllPlayers`

`AllPlayers` is last on purpose because it needs multiplayer sequencing policy, not because it is rare.

## AllPlayers

Representative cards:

- `base.main.050` Giant Hatchetfish, `ifActivated`, `(all players) [DrawCard][AllPlayers]`
- `base.main.108` Snipe Eel, `ifActivated`, `(all players) [FishEgg][AllPlayers]`
- `base.main.071` Little Skate, `ifActivated`, `(all players) [SchoolFeederMove][AllPlayers]`
- `base.main.016` Bearded Seadevil, `whenPlayed`, `(all players) [FishEgg][ArrowDown][FishLengthSmall] on each [AllPlayers]`
- `base.main.036` Deepsea Lizardfish, `whenPlayed`, `(all players) [FishHatch][SchoolFeederMove][AllPlayers]`
- `sr.main.161` Great Barracuda, `whenPlayed`, `(all players) [BlueCoral][BlueCoral][AllPlayers]`
- `sr.main.191` Shortfin Mako, `whenPlayed`, `(all players) [FishFromHandConsume][FishFromHandConsume][AllPlayers]`

Why deferred:

- Current local-authoritative engine can model per-player resolution, but `AllPlayers` still needs explicit ordering and skip policy before adding generic support.

Questions to confirm:

- `AllPlayers` is all players must resolve, or each player may independently skip?
- Resolution order is active player first then turn order, or table order from first player marker, or some other order?
- Each player chooses targets independently from only their own ocean / hand / discard, or can effects target other players?
- If a player has no legal target, is that player auto-skipped or does the whole ability stop?
- For draw / egg / hatch / movement / coral gain, should each player fully resolve their own effect before the next player starts?

## Mixed SchoolFeederMove

Representative cards:

- `base.main.051` Giant Hawkfish, `[FishHatch][SchoolFeederMove]`
- `base.main.101` Shortspine African Angler, `[SchoolFeederMove][DrawCard][DrawCard]`
- `base.main.096` Rope Fish, `[SchoolFeederMove][SchoolFeederMove][SchoolFeederMove] / [DrawCard]`
- `base.main.024` Blue Tang, `[SchoolFeederMove][YoungFish]`
- `base.main.036` Deepsea Lizardfish, `(all players) [FishHatch][SchoolFeederMove][AllPlayers]`

Why deferred:

- Pure repeated `[SchoolFeederMove]` is already mapped. The remaining cards combine movement with hatch, draw, discard, young placement, branch choice, or `AllPlayers`.

Questions to confirm:

- Tokens execute strictly left-to-right, or can the player choose order inside a compound ability?
- Every step may be skipped independently, or only the whole ability may be skipped?
- If one step cannot resolve, do later steps still execute?
- `/` means choose one branch, or resolve either side in player-chosen order, or something else?
- Repeated movement may move the same resource multiple times in the same ability, or each move must start from a fresh source?
- Mixed movement plus hatch / draw / discard should become one compound pending-choice queue with sequential steps?

## Consume Count

Representative cards:

- `base.main.034` Creolefish, `[ConsumeFish1]`
- `base.main.099` Sargassum Fish, `[ConsumeFish1][ConsumeFish1]`
- `base.main.117` Tripodfish, `gameEnd`, `[ConsumeFish1][ConsumeFish1]`
- `sr.main.140` Basking Shark, `[ConsumeFish1]`

Why deferred:

- Current engine supports `FishFromHandConsume`, but `[ConsumeFish1]` is a separate token family and should not be guessed into the same behavior without rule confirmation.

Questions to confirm:

- `[ConsumeFish1]` means choose one shorter fish from hand to consume, or one visible fish in the ocean, or a different source entirely?
- Repeated `[ConsumeFish1][ConsumeFish1]` means the same fish may consume twice with separate target choices?
- If the first consume has no legal target, does the second still try to resolve?
- `[ConsumeFish1]` is completely separate from normal cover-shorter-fish play rules?
- A consumed target becomes `ConsumedFish` under the source fish rather than entering discard?

## Coral-Gated Play From Hand

Representative cards:

- `sr.main.182` Reef Triggerfish, `whenPlayed`, `[FishFromHand][ArrowDown][AnyCoral][AnyCoral][AnyCoral] (in a dive site with at least 3)`
- `sr.main.141` Blackmouth Angler, `gameEnd`, `[FreePlayFishFromHand] if no [AnyCoral] in this fish's dive site`
- `sr.main.209` Yokozuna Slickhead, `gameEnd`, `[FishFromHand][ArrowDown][AnyCoral][AnyCoral][AnyCoral][AnyCoral][AnyCoral] (in a dive site with at least 5)`

Why deferred:

- Low-ambiguity paid/free play is already mapped. These cards add site-level coral predicates that must be modeled separately from ordinary fish costs.

Questions to confirm:

- `[FishFromHand][ArrowDown][AnyCoral]` means play into any dive site that currently has enough coral, or play a fish whose own requirement references coral, or both?
- `if no [AnyCoral] in this fish's dive site` checks the source fish's current dive site, or the target dive site for the fish being played?
- Free play and paid play both still enforce ordinary coral requirement on the played fish?
- Coral-gated placement is separate from the S&R reef-fish coral requirement already encoded in fish costs?

## Mixed Young + Consume / Move

Representative cards:

- `base.main.062` Honeycomb Scaly Dragonfish, `[YoungFish][SchoolFeederMove]`
- `sr.main.179` Portuguese Dogfish, `[YoungFish][FishFromHandConsume]`
- `sr.main.193` Sixgill Sawshark, `gameEnd`, `[YoungFish][FishFromHandConsume]`
- `base.main.024` Blue Tang, `[SchoolFeederMove][YoungFish]`

Why deferred:

- These cards likely want a compound queue, but the ordering and skip semantics should be confirmed first.

Questions to confirm:

- `[YoungFish][FishFromHandConsume]` is sequential, or choose-one, or any-order?
- If the young placement cannot resolve, does consume still proceed?
- If the consume cannot resolve, does the prior young placement remain?
- `[YoungFish][SchoolFeederMove]` creates a single compound pending queue with two steps?

## Unknown / Unsupported

This bucket is no longer treated as one flat blob. The remaining unresolved raw groups are:

- pure `Discard`: 7 cards
- pure `[Discard][Discard]`: 1 card
- pure `[Discard][Discard][Discard]`: 2 cards
- pure `[Discard][Discard][Discard][Discard]`: 1 card
- pure `[Discard][Discard][Discard][Discard][Discard]`: 1 card
- pure `[ConsumeFish1]`: 6 cards
- pure `[ConsumeFish1][ConsumeFish1]`: 3 cards
- mixed draw + discard: 2 cards
- mixed egg + draw: 2 cards

Representative cards:

- `base.main.012` Atlantic Sturgeon, `[Discard]`
- `base.main.026` Bluestreak Cleaner Wrasse, `[Discard][Discard]`
- `base.main.086` Paintspotted Moray, `[Discard][Discard][Discard]`
- `base.main.091` Pilotfish, `[Discard][Discard][Discard][Discard]`
- `sr.starter.211` African Coelacanth, `[Discard][Discard][Discard][Discard][Discard]`
- `base.main.007` Atlantic Bluefin Tuna, `[DrawCard][DrawCard][Discard][Discard]`
- `base.starter.129` Smoothcheek Lanternfish, `[FishEgg][FishEgg][DrawCard][DrawCard]`
- `base.starter.131` Mandarinfish, `[DrawCard][DrawCard][DrawCard][FishEgg]`

What likely needs parser work later:

- pure repeated `Discard` probably looks structurally similar to already-mapped repeated draw / hatch / egg / young, but only after discard-from-hand semantics are confirmed
- mixed draw + discard and egg + draw look like deterministic compound queues, not unknown syntax

What looks like true rule-confirmation work:

- `[ConsumeFish1]`
- mixed `AllPlayers`
- coral-gated placement
- any branch-choice text using `/`

## Free Play Principle

This is already fixed in implementation and should not be reopened:

- `FreePlayFishFromHand = waive cost only`
- Free play does **not** waive legality
- Free play still enforces:
  - allowed zones
  - required dive site
  - slot legality
  - cover-shorter-fish legality
  - coral requirement
- Successful free play still triggers the played fish's `WHEN PLAYED` ability
