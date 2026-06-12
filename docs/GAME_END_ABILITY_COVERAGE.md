# GAME END Ability Coverage

Last updated: 2026-06-12.

This document records the current GAME END sweep against runtime JSON in
`Finspan/Resources/Cards`.

## Summary

- Total GAME END abilities in runtime JSON: 39
- Implemented scoring-only: 10
- Implemented executable: 29
- Remaining unsupported after Pass 2D: 0

## Pass 2D Highlights

Pass 2D completed the remaining executable GAME END adapters by covering:

- `base.main.062` Honeycomb Scaly Dragonfish
- `base.main.109` Speckled Butterflyfish
- `sr.main.141` Blackmouth Angler
- `sr.main.193` Sixgill Sawshark

Key semantics now covered:

- non-`AllPlayers` mixed bracket abilities resolve through an any-order compound effect pool
- `[ArrowDown]` condition / scope still binds to the preceding benefit
- Blackmouth Angler uses source-site no-coral gating and same-dive-site free play

## Representative Executable GAME END Mappings

- `base.main.019` Binocular Fish:
  `placeEggOnMatchingFish(lengthBucket(.small), onEachEligibleFish)`
- `base.main.011` Atlantic Salmon:
  `playFishFromHand(topRow, payCost)`
- `base.main.117` Tripodfish:
  `consumeFishFromHand x2`
- `sr.main.149` Dusky Shark:
  `playFishForFree(lengthBucket(.medium))`
- `sr.main.156` Frilled Shark:
  `playFishForFree(lengthBucket(.medium))`
- `base.main.062` Honeycomb Scaly Dragonfish:
  mixed `young + move` compound effect pool
- `base.main.109` Speckled Butterflyfish:
  mixed `hatch + move` compound effect pool
- `sr.main.141` Blackmouth Angler:
  `playFishForFree(filter: .any, placement: .sameDiveSiteAsSource, sourceCondition: .sourceDiveSiteHasNoCoral, count: 1)`
- `sr.main.193` Sixgill Sawshark:
  mixed `young + consume` compound effect pool

## Scoring-Only GAME END

These remain auto-scored rather than surfaced as clickable actions:

- `base.main.001` Abyssal Anglerfish
- `base.main.004` Angelshark
- `base.main.008` Atlantic Bonito
- `base.main.030` Clown Anemonefish
- `base.main.031` Common Fangtooth
- `base.main.032` Cookiecutter Shark
- `base.main.070` Leafy Seadragon
- `base.main.085` Pale Chimaera
- `sr.main.202` Tasseled Scorpionfish
- `sr.main.206` Variegated Lizardfish

## Notes

- There are no remaining unsupported GAME END cards after Pass 2D.
- `AllPlayers` is still deferred globally, but no runtime GAME END card currently requires a separate unmapped `AllPlayers` adapter beyond existing coverage decisions.
