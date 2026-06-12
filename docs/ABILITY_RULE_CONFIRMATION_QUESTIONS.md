# Ability Rule Confirmation Questions

Last updated: 2026-06-13.

This document tracks the rule questions still blocking unsupported real-card abilities.

## Current Status

- Pass 2D before: 131 mapped / 84 unsupported
- Pass 2D after: 153 mapped / 62 unsupported
- Pass 2E before: 153 mapped / 62 unsupported
- Pass 2E after: 199 mapped / 16 unsupported
- Runtime ability texts containing `/`: 0

Already confirmed and implemented:

- `[Discard]` means recover from discard pile to hand; shortfall draws from deck.
- `[ConsumeFish1]` chooses any visible consumer fish, then consumes one shorter fish from hand.
- `FreePlayFishFromHand` waives cost only, not legality.
- `[ArrowDown]` binds condition / scope to the preceding benefit.
- Non-`AllPlayers` bracket abilities do not have fixed left-to-right order.
- Non-`AllPlayers` mixed bracket abilities now resolve from an any-order remaining effect pool.
- Blackmouth Angler checks the source fish's current dive site for coral.
- Blackmouth Angler only allows the free-play target in that same source dive site.
- `[AllPlayers]` gives the preceding benefit pool to every player independently.
- AllPlayers resolves from the source player, then table order.
- A target player skipping or having no legal target does not skip later players.

## Still Open

### Coral Threshold "also, if" Conditions

Representative real cards:

- `sr.main.138` Armored Searobin
- `sr.main.139` Atlantic Thornyhead
- `sr.main.144` Bluering Angelfish
- `sr.main.157` Furry Coffinfish
- `sr.main.158` Ghostly Seadevil
- `sr.starter.212` Atlantic Barracudina
- `sr.starter.213` Blue Antimora
- `sr.starter.214` Fanfin Anglerfish

Still unanswered:

- Does the first benefit before `also` always happen even if the coral threshold is not met?
- Is the threshold checked in the source fish's dive site?
- Is the threshold checked before or after resolving the first benefit?
- If the conditional second benefit has no legal target, does only that second benefit skip?
- Should this be modeled as a two-part ability with a conditional optional follow-up?

### Slash / Branch Choice

Runtime JSON currently has no ability text containing `/`.

Current note:

- `base.main.096` is not Rope Fish in runtime JSON.
- `base.main.096` is `Red Scorpionfish` with `[SchoolFeederMove]`.
- Do not use Rope Fish / `base.main.096` as a representative card in tests or audits.

Branch-choice questions are no longer a mainline blocker. If a future runtime JSON update introduces real slash ability text, validate the exact cards first before implementing:

- Does `/` always mean choose exactly one branch?
- When is the branch locked in?
- Can a branch be skipped after partial progress?
- Are all branches optional by default?

## Deferred Until Confirmed

- `also, if 3 same-color coral in this dive site` conditional benefits
- any future `/` branch-choice abilities only if they appear in runtime JSON
- any runtime patterns whose semantics still require confirmation
