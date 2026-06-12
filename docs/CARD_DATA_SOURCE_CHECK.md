# Card Data Source Check

Last updated: 2026-06-13.

This audit answers one narrow question: what is the app's current runtime card
data source of truth, and does it still match the locally saved finsearch
webpage snapshot under `references/webpage`?

The comparison is scriptable and repeatable:

```bash
python3 tools/scripts/check_card_data_against_webpage.py
```

The script writes a machine-readable report to
`build/reports/card_data_source_check.json`.

## Executive Conclusion

- The app runtime does not read `references/webpage` directly.
- The app runtime reads the four bundled JSON files in
  `Finspan/Resources/Cards/`.
- The saved finsearch webpage snapshot contains the upstream card data inside
  `references/webpage/Finspan Card Search_files/main.3f6711eb.js`, webpack
  module `4656`.
- The current runtime JSON and the saved webpage bundle match across all 215
  real cards for the audited identity, display, rules, and asset-link fields.
- Base + Sharks & Reefs still totals 215 real cards:
  - base: 135
  - Sharks & Reefs: 80
  - main: 200
  - starter: 15
- `Rope Fish` is not present in the saved webpage card data and is not present
  in the runtime JSON.
- `base.main.096` is `Red Scorpionfish` in both sources, with ability text
  `[SchoolFeederMove]`.

## Runtime Source Of Truth

Normal gameplay runtime card loading comes from bundled JSON only:

- `Finspan/Core/Data/BaseGameCardCatalog.swift`
  - loads `base_main_fish_cards.json`
  - loads `base_starter_fish_cards.json`
- `Finspan/Core/Data/SharksAndReefsCardCatalog.swift`
  - loads `sharks_reefs_main_fish_cards.json`
  - loads `sharks_reefs_starter_fish_cards.json`
- `Finspan/Core/Data/GameDataMode.swift`
  - `CardCatalogFactory.makeCatalog(for: .baseGame, enabledExpansions: [])`
    returns `BaseGameCardCatalog()`
  - `CardCatalogFactory.makeCatalog(for: .baseGame, enabledExpansions: [.sharksAndReefs])`
    returns `CompositeCardCatalog([BaseGameCardCatalog(), SharksAndReefsCardCatalog()])`
- `Finspan/Rooms/Services/LocalAuthoritativeRoomService.swift`
  - injects the real catalog into `GameEngine` and `DeterministicSetupBuilder`
  - does not read webpage snapshot files
- `Finspan/Core/Rules/DeterministicSetupBuilder.swift`
  - seeds setup hands and decks from `catalog.starterFishCards.map(\.id)` and
    `catalog.fishCards.map(\.id)`

Runtime card identity in setup and saved game state:

- hand / deck / discard / consumed fish store canonical runtime `Card.id`
- canonical format is:
  - `base.main.001`
  - `base.starter.126`
  - `sr.main.173`
  - `sr.starter.211`
- `sourceId` still exists in the JSON data, but it is not the runtime primary
  key for hands, decks, discard, or consumed fish
- `CardIdentityResolver` and `GameStateCardIdentityMigration` only use
  `sourceId`-style aliases for backward compatibility migration

Sample catalog status:

- `SampleCardCatalog()` still exists for explicit sample mode and some default
  init parameters
- normal base game room creation uses `CardCatalogFactory` and the bundled real
  JSON catalog
- the current normal room path does not silently read `SampleCardCatalog()`

## Webpage Source Of Truth

The saved webpage snapshot is an offline upstream reference, not a runtime
dependency.

Confirmed source files:

- `references/webpage/Finspan Card Search.html`
- `references/webpage/Finspan Card Search_files/main.3f6711eb.js`
- `references/webpage/Finspan Card Search_files/main.f74b3868.css`

The real webpage card data lives inside:

- `main.3f6711eb.js`
- webpack module `4656`
- encoded as `JSON.parse('...')`

This bundle contains the full 215-card array, not just first-screen DOM text.

Existing extraction tooling status:

- `tools/raw/finsearch/extract_finsearch_cards.py`
  - already exists
  - extracts raw cards and asset manifest from the saved webpage bundle
- `tools/raw/finsearch/finsearch_cards_raw.json`
  - existing raw extraction snapshot
- `tools/raw/finsearch/finspan_cards_normalized_draft.json`
  - existing draft normalized snapshot
- There is not yet a single maintained end-to-end pipeline that regenerates the
  four runtime JSON files in `Finspan/Resources/Cards/` from `references/webpage`
  automatically.

Recommendation:

- keep the new checker as the current guardrail
- later add an explicit reproducible import pipeline from webpage bundle to
  runtime JSON, to prevent future manual drift

## Field-Level Comparison Result

The new checker compares every shared card across these normalized fields:

- canonical id
- `sourceId` / numeric id
- expansion / set
- main vs starter
- English name
- scientific name
- trigger
- raw ability text
- parsed ability tokens
- printed points
- fish length
- derived small / medium / large length bucket
- allowed zones
- required dive-site color
- tags and tag counts
- normalized costs
- coral requirement / cost payload
- logical fish image asset filename

Current result:

- runtime cards: 215
- webpage cards: 215
- shared cards: 215
- runtime-only cards: 0
- webpage-only cards: 0
- field mismatches: 0

Mismatch counts by audited field:

- `source_id`: 0
- `numeric_id`: 0
- `expansion`: 0
- `group`: 0
- `name`: 0
- `scientific_name`: 0
- `trigger`: 0
- `ability_text`: 0
- `ability_tokens`: 0
- `printed_points`: 0
- `length_cm`: 0
- `length_bucket`: 0
- `allowed_zones`: 0
- `required_dive_site_color`: 0
- `tags`: 0
- `tag_counts`: 0
- `costs`: 0
- `coral_requirement_or_cost`: 0
- `fish_image_asset`: 0

## Asset Findings

Logical fish-image coverage:

- webpage bundle references 215 fish images
- local app runtime assets contain 215 fish images under
  `Finspan/Resources/CardAssets/fish`
- runtime logical fish image coverage mismatch: 0

Saved webpage snapshot physical fish files:

- the saved browser snapshot physically includes only 30 numeric fish `.webp`
  files
- this is a saved-page artifact, not a card-data mismatch
- the bundle still references all 215 fish images logically

Interpretation:

- `references/webpage` is sufficient as an upstream data source because the JS
  bundle embeds all 215 card records
- the saved page's physical image subset should not be confused with card data
  loss

## Runtime Vs Webpage Schema

Fields retained or normalized into runtime JSON:

- canonical id
- source numeric id
- expansion / group
- name
- scientific name
- printed points
- length
- zones
- band-to-dive-site-color mapping
- normalized costs
- tags
- trigger
- raw ability text

Fields that exist in webpage raw data but are not preserved 1:1 in every
runtime JSON file:

- `description`
- raw `band` string as a separate field
- bundled asset hash strings
- raw camelCase webpage field names such as `cardCost`, `youngCost`,
  `abilityType`

Fields added by runtime JSON that do not exist in the raw webpage schema:

- canonical id strings such as `base.main.001`
- normalized `costs`
- `abilityIds`
- localized wrappers for some Sharks & Reefs text fields
- Sharks & Reefs `rawSource` provenance blocks

Notable shape difference:

- base runtime JSON is a cleaned, runtime-oriented schema
- Sharks & Reefs runtime JSON still preserves a richer provenance shape through
  `rawSource` and `visual`

## Representative Card Validation

Representative cards explicitly checked against runtime JSON and webpage bundle:

- `base.main.024` Blue Tang: present and matched
- `base.main.051` Giant Hawkfish: present and matched
- `base.main.062` Honeycomb Scaly Dragonfish: present and matched
- `base.main.101` Shortspine African Angler: present and matched
- `base.main.117` Tripodfish: present and matched
- `sr.main.141` Blackmouth Angler: present and matched
- `sr.main.179` Portuguese Dogfish: present and matched
- `sr.main.193` Sixgill Sawshark: present and matched
- `sr.main.209` Yokozuna Slickhead: present and matched

Ability audit docs checked:

- `docs/ABILITY_COVERAGE_AUDIT.md`
- `docs/ABILITY_RULE_CONFIRMATION_QUESTIONS.md`
- `docs/GAME_END_ABILITY_COVERAGE.md`

Doc validation result:

- representative ids missing from runtime JSON: 0
- representative ids missing from webpage extraction: 0
- representative name mismatches: 0
- representative ability-text mismatches: 0

No representative-card corrections were required in those three docs during
this audit pass.

## Rope Fish / base.main.096

Final conclusion:

- `Rope Fish` does not exist in the saved webpage card array
- `Rope Fish` does not exist in the runtime JSON card array
- `base.main.096` is `Red Scorpionfish` in the webpage bundle
- `base.main.096` is `Red Scorpionfish` in runtime JSON
- `base.main.096` ability text is `[SchoolFeederMove]` in both sources

Most likely cause of the earlier Rope Fish reference:

- documentation error or earlier manual audit mistake
- not current runtime/webpage drift
- not a current JSON import mismatch

## Final Assessment

Current confidence level is high that the shipped runtime card JSON is still
aligned with the locally saved finsearch webpage source for all 215 real cards.

What is confirmed:

- app runtime source of truth is `Finspan/Resources/Cards/*.json`
- webpage upstream source of truth is the saved bundle module `4656`
- runtime JSON and webpage card data are fully aligned on the audited fields
- base + Sharks & Reefs still equals 215 real cards
- representative audit docs currently reference real cards correctly

What still deserves future tooling:

- a maintained one-step regeneration path from saved webpage bundle to runtime
  JSON, instead of relying on manual normalization plus spot audits
