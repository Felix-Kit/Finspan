# Finspan Card Data Schema Draft

Generated from the saved `navarog.github.io/finsearch` page.

## Extracted source data

- `finsearch_cards_raw.json`: the original card array extracted from `main.3f6711eb.js`.
- `finspan_cards_normalized_draft.json`: a draft app-friendly schema. Review before using as final game data.
- `finsearch_assets_manifest.json`: static media filenames referenced by the JS bundle, with suggested original URLs.

## Card counts

- Base main fish: 125 (`id` 1-125)
- Base starter fish: 10 (`id` 126-135)
- Sharks & Reefs main fish: 75 (`id` 136-210)
- Sharks & Reefs starter fish: 5 (`id` 211-215)

## Important notes

1. The uploaded saved page only included some currently loaded fish images, but the JS bundle references filenames for all fish images. Use `finsearch_assets_manifest.json` to download missing assets later.
2. Ability text is icon-coded, e.g. `[FishEgg][ArrowDown][Predator]`. Keep this raw text while progressively mapping to `AbilityRegistry` entries.
3. The draft `sizeClassDraft` is only a rough placeholder based on length. The official size icon should be mapped from original icon data if available, not trusted from this approximation.
4. `coralCost` appears for Sharks & Reefs cards and needs later disambiguation as requirement/cost depending on card context.
5. Do not place website scraping in the app runtime. Use this as an offline import source.
