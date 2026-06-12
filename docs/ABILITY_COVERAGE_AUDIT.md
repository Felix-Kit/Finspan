# Ability Coverage Audit

Last updated: 2026-06-13.

Generated from runtime card JSON in `Finspan/Resources/Cards` with:

```bash
python3 tools/scripts/audit_ability_coverage.py
```

## Summary

- Total real cards scanned: 215
- Cards with ability data: 215
- Pass 2D before: 131 mapped / 84 unsupported
- Pass 2D after: 153 mapped / 62 unsupported
- Pass 2E before: 153 mapped / 62 unsupported
- Pass 2E after: 199 mapped / 16 unsupported
- Mixed ability cards: 0
- Unmapped ability cards: 0
- Runtime ability texts containing `/`: 0
- Runtime `AllPlayers` ability cards: 34

Coverage history:

- Initial audit: 45 mapped / 170 unsupported
- Pass 1: 88 mapped / 127 unsupported
- Pass 2A: 103 mapped / 112 unsupported
- Pass 2B Preflight: 104 mapped / 111 unsupported
- Pass 2C: 131 mapped / 84 unsupported
- Pass 2D: 153 mapped / 62 unsupported
- Pass 2E: 199 mapped / 16 unsupported

## Trigger Counts

- `whenPlayed`: 90
- `ifActivated`: 86
- `gameEnd`: 39

## Pattern Groups

Current raw token pattern counts from runtime JSON after Pass 2E:

- `all players · draw fish`: 4
- `all players · gain coral`: 5
- `all players · hatch egg`: 4
- `all players · move young/school`: 5
- `all players · place egg on each matching fish`: 8
- `all players · place egg single target`: 3
- `all players · consume fish from hand`: 1
- `all players · mixed compound effect pool`: 2
- `all players · mixed hatch + move`: 1
- `all players · mixed scatter + consume`: 1
- `mixed coral compound`: 9
- `mixed compound effect pool`: 13
- Other mapped base patterns remain covered by prior passes.
- Remaining unsupported cards: 16, all using `also, if [Coral][Coral][Coral] in this dive site: ...` conditional text.

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

## Pass 2E Additions

Pass 2E maps these new real-card patterns:

- `AllPlayers` wrappers for supported inner benefits.
- Per-player AllPlayers resolution order starts with the source player and continues by table order.
- Each target player resolves against their own hand, ocean, discard pile, and coral reefs.
- Skipping one target player's benefit skips only that player and does not affect later players.
- AllPlayers mixed benefits reuse the Pass 2D compound effect pool for each target player.
- Runtime JSON has 0 ability texts containing `/`, so branch choice is not a current mainline unsupported category.
- Low-risk parser aliases now map existing effects from real JSON:
  - `[FishFromHandConsume]` as hand-fish consume
  - `[UnSchoolFish]` as scatter school
  - simple coral + supported effect compound pools

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
- `[AllPlayers]` wraps the preceding benefit pool and gives each player an independent chance to resolve or skip that benefit.
- Runtime JSON contains no `/` abilityText, so no branch-choice ability is implemented in Pass 2E.

## Representative Mapped Cards

- `base.main.024` Blue Tang, `[SchoolFeederMove][YoungFish]`
- `base.main.051` Giant Hawkfish, `[FishHatch][SchoolFeederMove]`
- `base.main.062` Honeycomb Scaly Dragonfish, `[YoungFish][SchoolFeederMove]`
- `base.main.101` Shortspine African Angler, `[SchoolFeederMove][DrawCard][DrawCard]`
- `sr.main.141` Blackmouth Angler, `[FreePlayFishFromHand] if no [AnyCoral] in this fish's dive site`
- `sr.main.179` Portuguese Dogfish, `[YoungFish][FishFromHandConsume]`
- `sr.main.193` Sixgill Sawshark, `[YoungFish][FishFromHandConsume]`
- `base.main.109` Speckled Butterflyfish, `[FishHatch][FishHatch][FishHatch][SchoolFeederMove]`
- `base.main.050` Giant Hatchetfish, `(all players) [DrawCard][AllPlayers]`
- `base.main.016` Bearded Seadevil, `(all players) [FishEgg][ArrowDown][FishLengthSmall] on each [AllPlayers]`
- `sr.main.161` Great Barracuda, `(all players) [BlueCoral][BlueCoral][AllPlayers]`
- `sr.main.162` Great Hammerhead, `(all players) [UnSchoolFish][FishFromHandConsume][AllPlayers]`
- `sr.main.191` Shortfin Mako, `(all players) [FishFromHandConsume][FishFromHandConsume][AllPlayers]`

## Still Deferred

These remain intentionally unsupported in Pass 2E:

- `also, if [BlueCoral][BlueCoral][BlueCoral] in this dive site: ...`
- `also, if [PurpleCoral][PurpleCoral][PurpleCoral] in this dive site: ...`
- `also, if [GreenCoral][GreenCoral][GreenCoral] in this dive site: ...`
- Any future `/` branch-like ability if runtime JSON later introduces one.

Representative deferred cards:

- `sr.main.138` Armored Searobin, `[Discard] also, if [BlueCoral][BlueCoral][BlueCoral] in this dive site: [DrawCard]`
- `sr.main.139` Atlantic Thornyhead, `[FishHatch] also, if [GreenCoral][GreenCoral][GreenCoral] in this dive site: [FishEgg]`
- `sr.main.144` Bluering Angelfish, `[FishEgg] also, if [PurpleCoral][PurpleCoral][PurpleCoral] in this dive site: [ConsumeFish1]`
- `sr.starter.212` Atlantic Barracudina, `[FishHatch] also, if [GreenCoral][GreenCoral][GreenCoral] in this dive site: [SchoolFeederMove]`
- `sr.starter.214` Fanfin Anglerfish, `[FishEgg] also, if [PurpleCoral][PurpleCoral][PurpleCoral] in this dive site: [GreenCoral]`

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

1. Confirm `also, if 3 same-color coral in this dive site` conditional timing and scope.
2. Keep `/` branch-choice modeling out of scope unless runtime JSON introduces a real slash ability.
3. Continue validating unknown semantics strictly against runtime JSON before mapping.
