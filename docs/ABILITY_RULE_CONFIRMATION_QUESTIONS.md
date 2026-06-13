# Ability Rule Confirmation Questions

Last updated: 2026-06-13.

This document tracks the rule questions still blocking unsupported real-card abilities.

## Current Status

- Pass 2D before: 131 mapped / 84 unsupported
- Pass 2D after: 153 mapped / 62 unsupported
- Pass 2E before: 153 mapped / 62 unsupported
- Pass 2E after: 199 mapped / 16 unsupported
- Pass 2F before: 199 mapped / 16 unsupported
- Pass 2F after: 215 mapped / 0 unsupported
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
- `also, if [ColorCoral]xN in this dive site: ...` is a conditional extra benefit, not an alternative benefit.
- The base benefit is resolved or skipped first.
- Skipping the base benefit still checks the bonus condition.
- The bonus condition checks the source fish's current dive site.
- The bonus condition uses the specific coral color icons in `abilityText`; it is not inferred from fish band or card color.
- The colored coral count is a minimum threshold.

## Still Open

No current runtime card remains unsupported after Pass 2F.

### Colored Coral Conditional Bonus

Representative real cards:

- `sr.main.138` Armored Searobin
- `sr.main.139` Atlantic Thornyhead
- `sr.main.144` Bluering Angelfish
- `sr.main.157` Furry Coffinfish
- `sr.main.158` Ghostly Seadevil
- `sr.starter.212` Atlantic Barracudina
- `sr.starter.213` Blue Antimora
- `sr.starter.214` Fanfin Anglerfish

Confirmed and implemented in Pass 2F:

- The first benefit can be resolved or skipped before checking the extra benefit.
- The extra benefit checks the source fish's current dive site after the first benefit has been handled.
- If the required specified-color coral count is present, the extra benefit can be resolved or skipped independently.
- If the condition is not met, only the extra benefit is unavailable; the first benefit is unaffected.
- If the source fish is covered, hidden, or cannot be located, the extra benefit is unavailable / skippable without creating invalid state.

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

- any future `/` branch-choice abilities only if they appear in runtime JSON
- any runtime patterns whose semantics still require confirmation
