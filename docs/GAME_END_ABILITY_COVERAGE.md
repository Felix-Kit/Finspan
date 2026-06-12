# GAME END Ability Coverage

This document records the current end-game ability sweep against the local card
data. It is a coverage log, not a rules spec.

## Summary

- Total GAME END abilities found in base + S&R JSON: 39
- Implemented scoring-only: 10
- Implemented executable: 25
- Remaining unsupported / future work: 4

## Scoring-Only Abilities

These are auto-scored in final scoring and do not create clickable GAME END
actions.

| Fish | sourceId | abilityId | Raw abilityText | Status | Mapping |
| --- | --- | --- | --- | --- | --- |
| Abyssal Anglerfish | base.main.001 | unsupported.base.gameEnd.card_001 | `3 [Wave] if no tokens on this fish` | implemented | `gameEndScore(noTokensOnThisFish, 3)` |
| Angelshark | base.main.004 | unsupported.base.gameEnd.card_004 | `10 [Wave] if 3+ consumed fish under this one` | implemented | `gameEndScore(consumedFishUnderThisFishAtLeast(3), 10)` |
| Atlantic Bonito | base.main.008 | unsupported.base.gameEnd.card_008 | `6 [Wave] if 2+ consumed fish under this one` | implemented | `gameEndScore(consumedFishUnderThisFishAtLeast(2), 6)` |
| Clown Anemonefish | base.main.030 | unsupported.base.gameEnd.card_030 | `6 [Wave] if exactly 2 young on this fish` | implemented | `gameEndScore(youngOnThisFishExactly(2), 6)` |
| Common Fangtooth | base.main.031 | unsupported.base.gameEnd.card_031 | `3 [Wave] if 1+ consumed fish under this one` | implemented | `gameEndScore(consumedFishUnderThisFishAtLeast(1), 3)` |
| Cookiecutter Shark | base.main.032 | unsupported.base.gameEnd.card_032 | `5 [Wave] if this fish is in bottom row` | implemented | `gameEndScore(bottomRow, 5)` |
| Leafy Seadragon | base.main.070 | unsupported.base.gameEnd.card_070 | `3 [Wave] if school on this fish` | implemented | `gameEndScore(schoolOnThisFish, 3)` |
| Pale Chimaera | base.main.085 | unsupported.base.gameEnd.card_085 | `10 [Wave] if egg + young + school on this fish` | implemented | `gameEndScore(eggYoungAndSchoolOnThisFish, 10)` |
| Tasseled Scorpionfish | sr.main.202 | unsupported.sr.gameEnd.card_202 | `5 [Wave] if 3+ coral in all dive sites` | implemented | `gameEndScore(allDiveSitesHaveCoralAtLeast(3), 5)` |
| Variegated Lizardfish | sr.main.206 | unsupported.sr.gameEnd.card_206 | `3 [Wave] if at least 5 coral in a dive site` | implemented | `gameEndScore(anyDiveSiteHasCoralAtLeast(5), 3)` |

## Executable Abilities

These create pending choice flow or directly apply existing reusable effects.

### Matching Egg Placement

| Fish | sourceId | abilityId | Raw abilityText | Status | Mapping |
| --- | --- | --- | --- | --- | --- |
| Binocular Fish | base.main.019 | unsupported.base.gameEnd.card_019 | `[FishEgg][ArrowDown][FishLengthSmall] on each` | implemented | `placeEggOnMatchingFish(lengthBucket(.small), onEachEligibleFish)` |
| Chinese Trumpetfish | base.main.028 | unsupported.base.gameEnd.card_028 | `[FishEgg][ArrowDown][FishLengthMedium] on each` | implemented | `placeEggOnMatchingFish(lengthBucket(.medium), onEachEligibleFish)` |
| European Anchovy | base.main.041 | unsupported.base.gameEnd.card_041 | `[FishEgg][ArrowDown][Estuary]` | implemented | `placeEggOnMatchingFish(topRow, onEachEligibleFish)` |
| Largetooth Flounder | base.main.069 | unsupported.base.gameEnd.card_069 | `[FishEgg][ArrowDown][FlipperGreen]` | implemented | `placeEggOnMatchingFish(diveSite(.green), chooseOneEligibleFish)` |
| Mariana Snailfish | base.main.077 | unsupported.base.gameEnd.card_077 | `[FishEgg][ArrowDown][PlayFishBottomRow] on each` | implemented | `placeEggOnMatchingFish(bottomRow, onEachEligibleFish)` |
| Ocean Sunfish | base.main.081 | unsupported.base.gameEnd.card_081 | `[FishEgg][ArrowDown][FishLengthLarge] on each` | implemented | `placeEggOnMatchingFish(lengthBucket(.large), onEachEligibleFish)` |
| Pudgy Cusk-Eel | base.main.093 | unsupported.base.gameEnd.card_093 | `[FishEgg][ArrowDown][FlipperBlue] on each` | implemented | `placeEggOnMatchingFish(diveSite(.blue), onEachEligibleFish)` |
| Sloan's Viperfish | base.main.105 | unsupported.base.gameEnd.card_105 | `[FishEgg][ArrowDown][Predator] on each` | implemented | `placeEggOnMatchingFish(tag(predator), onEachEligibleFish)` |
| Yellowtail Snapper | base.main.125 | unsupported.base.gameEnd.card_125 | `[FishEgg][ArrowDown][FlipperPurple] on each` | implemented | `placeEggOnMatchingFish(diveSite(.purple), onEachEligibleFish)` |

### Paid Play From Hand

| Fish | sourceId | abilityId | Raw abilityText | Status | Mapping |
| --- | --- | --- | --- | --- | --- |
| Atlantic Salmon | base.main.011 | unsupported.base.gameEnd.card_011 | `[FishFromHand][ArrowDown][Estuary]` | implemented | `playFishFromHand(topRow, payCost)` |
| Blob Sculpin | base.main.023 | unsupported.base.gameEnd.card_023 | `[FishFromHand][ArrowDown][FlipperGreen]` | implemented | `playFishFromHand(diveSite(.green), payCost)` |
| Crocodilefish | base.main.035 | unsupported.base.gameEnd.card_035 | `[FishFromHand][ArrowDown][FlipperBlue]` | implemented | `playFishFromHand(diveSite(.blue), payCost)` |
| Faceless Cusk | base.main.044 | unsupported.base.gameEnd.card_044 | `[FishFromHand][ArrowDown][PlayFishBottomRow]` | implemented | `playFishFromHand(bottomRow, payCost)` |
| Giant Trevally | base.main.054 | unsupported.base.gameEnd.card_054 | `[FishFromHand][ArrowDown][FlipperPurple]` | implemented | `playFishFromHand(diveSite(.purple), payCost)` |
| Striped Marlin | base.main.115 | unsupported.base.gameEnd.card_115 | `[FishFromHand][ArrowDown][Sun]` | implemented | `playFishFromHand(sunlight, payCost)` |
| Yokozuna Slickhead | sr.main.209 | unsupported.sr.gameEnd.card_209 | `[FishFromHand][ArrowDown][AnyCoral]...` | implemented | `playFishFromHand(diveSiteWithCoralAtLeast(5), payCost)` |

### S&R Executable Effects

| Fish | sourceId | abilityId | Raw abilityText | Status | Mapping |
| --- | --- | --- | --- | --- | --- |
| Broadnose Sevengill Shark | sr.main.146 | unsupported.sr.gameEnd.card_146 | `[UnSchoolFish][UnSchoolFish]` | implemented | `scatterSchool x2` |
| Common Bluestripe Snapper | sr.main.147 | unsupported.sr.gameEnd.card_147 | `[BlueCoral][BlueCoral][BlueCoral]` | implemented | `gainCoral(.blue, 3)` |
| Dusky Shark | sr.main.149 | unsupported.sr.gameEnd.card_149 | `[FreePlayFishFromHand][FishLengthMedium] only` | implemented | `playFishForFree(lengthBucket(.medium))` |
| Fire Dartfish | sr.main.153 | unsupported.sr.gameEnd.card_153 | `[PurpleCoral][PurpleCoral][PurpleCoral]` | implemented | `gainCoral(.purple, 3)` |
| Frilled Shark | sr.main.156 | unsupported.sr.gameEnd.card_156 | `[FreePlayFishFromHand][FishLengthMedium] only` | implemented | `playFishForFree(lengthBucket(.medium))` |
| Mimic Goatfish | sr.main.174 | unsupported.sr.gameEnd.card_174 | `[AnyCoral][AnyCoral]` | implemented | `gainCoral(.any, 2)` |
| Red-lipped Batfish | sr.main.181 | unsupported.sr.gameEnd.card_181 | `[BlueCoral][PurpleCoral][GreenCoral]` | implemented | `gainCoral(.blue/.purple/.green)` |
| Tripodfish | base.main.117 | unsupported.base.gameEnd.card_117 | `[ConsumeFish1][ConsumeFish1]` | implemented | `consumeFishFromHand x2` |
| Yellow Clown Goby | sr.main.208 | unsupported.sr.gameEnd.card_208 | `[GreenCoral][GreenCoral][GreenCoral]` | implemented | `gainCoral(.green, 3)` |

## Unsupported / Future Work

These are still represented as unsupported GAME END abilities.

| Fish | sourceId | abilityId | Raw abilityText | Status | Reason |
| --- | --- | --- | --- | --- | --- |
| Honeycomb Scaly Dragonfish | base.main.062 | unsupported.base.gameEnd.card_062 | `[YoungFish][SchoolFeederMove]` | future work | mixed move-young / move-school behavior needs a dedicated adapter |
| Speckled Butterflyfish | base.main.109 | unsupported.base.gameEnd.card_109 | `[FishHatch][FishHatch][FishHatch][SchoolFeederMove]` | future work | mixed hatch + school move sequence is not modeled yet |
| Blackmouth Angler | sr.main.141 | unsupported.sr.gameEnd.card_141 | `[FreePlayFishFromHand] if no [AnyCoral] in this fish's dive site` | future work | condition + free play path still needs a safe generic adapter |
| Sixgill Sawshark | sr.main.193 | unsupported.sr.gameEnd.card_193 | `[YoungFish][FishFromHandConsume]` | future work | mixed young / consume flow not modeled |

## Notes

- Scoring-only abilities are surfaced as automatic GAME END scoring, not as
  clickable actions.
- Executable abilities remain visible in GAME END phase and can be resolved or
  skipped.
- Newly played GAME END fish can be discovered dynamically because the phase
  rescans visible fish after each resolve / skip.
- The four future-work cards are intentionally left unsupported for now instead
  of forcing a brittle one-off implementation.
