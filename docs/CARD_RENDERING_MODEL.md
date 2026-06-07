# Finsearch Card Rendering Model

This note records what can be inferred from the local finsearch export without
making the app depend on finsearch at runtime.

## Source Files Inspected

- `tools/raw/finsearch/finsearch_assets_manifest.json`
- `tools/raw/finsearch/finsearch_cards_raw.json`
- `tools/raw/finsearch/finspan_cards_normalized_draft.json`
- `tools/raw/finsearch/CARD_DATA_SCHEMA_DRAFT.md`

The export does not currently include the finsearch site HTML, JavaScript, or
CSS files. Exact DOM structure, CSS coordinates, fonts, masks, and text wrapping
rules therefore cannot be copied directly in this stage.

## Asset Groups

The asset manifest contains 285 assets:

- 215 fish images
- 57 icons
- 13 background or card-band assets

The downloaded local app assets are stored under:

- `Finspan/Resources/CardAssets/fish`
- `Finspan/Resources/CardAssets/icons`
- `Finspan/Resources/CardAssets/backgrounds`
- `Finspan/Resources/CardAssets/previews`

The app runtime must use these local files only. Remote finsearch URLs are a
development import source, not a runtime dependency.

## Key Dimensions

The full card background/color-band assets share the same dimensions:

- `base.*`: 4394 x 2976
- `blue.*`: 4394 x 2976
- `purple.*`: 4394 x 2976
- `green.*`: 4394 x 2976

This gives the shared fish-card width/height aspect ratio:

```text
4394 / 2976 = 1.476478494623656
```

The ability strip assets are separate UI regions rather than the full card face:

- `IfActivated.*`: 472 x 295
- `GameEnd.*`: 472 x 295

`webpage.*` is a page background asset at 1440 x 2960 and should not be used as
the card aspect ratio source.

## Minimal Runtime Card Face Model

Until the exact finsearch rendering code is available, the app uses a conservative
local approximation:

- one shared aspect ratio derived from the full card background assets
- compact cost and point areas near the top
- card name and scientific name near the top-left
- fish image in the center-left, resolved from local asset files by source id
- length, zones, and tags near the lower area
- ability trigger/text in a right-side panel
- required dive-site color as a local color accent

This is intentionally a display layer only. It does not implement or interpret
real fish abilities.

## Known Gaps

- Exact finsearch card composition rules are unavailable in this repository.
- Text wrapping, font family, icon placement, and masking are approximate.
- Fish image anchoring/cropping is approximate.
- Icon-to-rule semantic mapping is not complete.
- A future import step should either preserve the original renderer metadata or
  generate a reviewed local layout schema.
