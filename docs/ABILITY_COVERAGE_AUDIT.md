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
- Pass 2F before: 199 mapped / 16 unsupported
- Pass 2F after: 215 mapped / 0 unsupported
- Mixed ability cards: 0
- Unmapped ability cards: 0
- Runtime ability texts containing `/`: 0
- Runtime `AllPlayers` ability cards: 34
- Ability Engine v2 core migration has started as an adapter layer over existing `PendingChoice`; it does not add new mapped abilities or change gameplay results.

Coverage history:

- Initial audit: 45 mapped / 170 unsupported
- Pass 1: 88 mapped / 127 unsupported
- Pass 2A: 103 mapped / 112 unsupported
- Pass 2B Preflight: 104 mapped / 111 unsupported
- Pass 2C: 131 mapped / 84 unsupported
- Pass 2D: 153 mapped / 62 unsupported
- Pass 2E: 199 mapped / 16 unsupported
- Pass 2F: 215 mapped / 0 unsupported

## Trigger Counts

- `whenPlayed`: 90
- `ifActivated`: 86
- `gameEnd`: 39

## Pattern Groups

Current raw token pattern counts from runtime JSON after Pass 2F:

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
- `colored coral conditional bonus (blue x3)`: 5
- `colored coral conditional bonus (green x3)`: 5
- `colored coral conditional bonus (purple x3)`: 6
- `mixed coral compound`: 9
- `mixed compound effect pool`: 13
- Other mapped base patterns remain covered by prior passes.
- Remaining unsupported cards: 0.

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

## Pass 2F Additions

Pass 2F maps the remaining S&R `IF ACTIVATED` colored coral conditional bonus abilities:

- `[Discard] also, if [BlueCoral][BlueCoral][BlueCoral] in this dive site: [DrawCard]`
- `[FishHatch] also, if [GreenCoral][GreenCoral][GreenCoral] in this dive site: [FishEgg]`
- `[FishEgg] also, if [PurpleCoral][PurpleCoral][PurpleCoral] in this dive site: [ConsumeFish1]`
- Equivalent real-card variants where the base or bonus is another supported effect such as `SchoolFeederMove`, `FishHatch`, `FishFromHandConsume`, or a coral gain.

Representative real cards:

- `sr.main.138` Armored Searobin, `[Discard] also, if [BlueCoral][BlueCoral][BlueCoral] in this dive site: [DrawCard]`
- `sr.main.139` Atlantic Thornyhead, `[FishHatch] also, if [GreenCoral][GreenCoral][GreenCoral] in this dive site: [FishEgg]`
- `sr.main.144` Bluering Angelfish, `[FishEgg] also, if [PurpleCoral][PurpleCoral][PurpleCoral] in this dive site: [ConsumeFish1]`
- `sr.main.157` Furry Coffinfish, `[Discard] also, if [BlueCoral][BlueCoral][BlueCoral] in this dive site: [SchoolFeederMove]`
- `sr.starter.212` Atlantic Barracudina, `[FishHatch] also, if [GreenCoral][GreenCoral][GreenCoral] in this dive site: [SchoolFeederMove]`
- `sr.starter.214` Fanfin Anglerfish, `[FishEgg] also, if [PurpleCoral][PurpleCoral][PurpleCoral] in this dive site: [GreenCoral]`

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
- `also, if [ColorCoral]xN in this dive site: ...` is a conditional extra benefit, not an alternative benefit.
- The base benefit is resolved or skipped first.
- Skipping the base benefit does not skip the whole ability; the colored coral condition is still checked afterward.
- The colored coral requirement checks the source fish's current dive site.
- The requirement uses the specific coral color icons in `abilityText`, and the count is a minimum threshold.
- If the source fish is covered, hidden, or cannot be located, the bonus benefit is unavailable / skippable rather than producing invalid state.
- Runtime JSON contains no `/` abilityText, so no branch-choice ability is implemented in Pass 2F.

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
- `sr.main.138` Armored Searobin, `[Discard] also, if [BlueCoral][BlueCoral][BlueCoral] in this dive site: [DrawCard]`
- `sr.main.139` Atlantic Thornyhead, `[FishHatch] also, if [GreenCoral][GreenCoral][GreenCoral] in this dive site: [FishEgg]`
- `sr.main.144` Bluering Angelfish, `[FishEgg] also, if [PurpleCoral][PurpleCoral][PurpleCoral] in this dive site: [ConsumeFish1]`
- `sr.starter.212` Atlantic Barracudina, `[FishHatch] also, if [GreenCoral][GreenCoral][GreenCoral] in this dive site: [SchoolFeederMove]`
- `sr.starter.214` Fanfin Anglerfish, `[FishEgg] also, if [PurpleCoral][PurpleCoral][PurpleCoral] in this dive site: [GreenCoral]`

## Still Deferred

- No current runtime card remains unsupported after Pass 2F.
- Any future `/` branch-like ability remains deferred unless runtime JSON introduces a real slash ability and its semantics are confirmed from that real data.

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

1. Continue Ability Engine v2 consolidation around `AbilityIR`, `EffectGraph`, and `PendingEffectSet`.
2. Keep `/` branch-choice modeling out of scope unless runtime JSON introduces a real slash ability.
3. Continue validating unknown semantics strictly against runtime JSON before mapping.
