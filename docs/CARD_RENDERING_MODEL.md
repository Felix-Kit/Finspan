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

Update: a saved finsearch webpage was later inspected at
`/Users/work/Finspan/references/webpage/`. The detailed reverse-engineering
notes are in `docs/FINSEARCH_RENDERER_REVERSE_ENGINEERING.md`.

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

The current local download summary is recorded in
`tools/generated/assets/asset_download_summary.json`:

- fish image: 215
- icons: 57
- backgrounds / bands: 13
- previews: 0

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

The saved finsearch CSS explicitly sets `.card { aspect-ratio: 61/40; }`. That
display ratio is `1.525`, which differs from the full-card background pixel
ratio `4394 / 2976 = 1.476478494623656`. The current SwiftUI metrics use the
asset-derived ratio; matching the webpage more closely will require deciding
whether to switch visible card layout to the CSS ratio while still using the
asset dimensions for background image references.

## Minimal Runtime Card Face Model

Until the exact finsearch rendering code is available, the app uses a conservative
local approximation:

- one shared aspect ratio derived from the full card background assets
- `CardRenderMetrics` stores the shared source dimensions, aspect ratio, and
  fixed hand-card dimensions
- `FishCardFaceView` renders the current minimal fish-card face
- compact cost and point areas near the top
- card name and scientific name near the top-left
- fish image in the center-left, resolved from local asset files by source id
- length, zones, and tags near the lower area
- ability trigger/text in a right-side panel
- required dive-site color as a local color accent

This is intentionally a display layer only. It does not implement or interpret
real fish abilities.

The floating hand, discard pile preview/detail, and ocean slots now use this
same card aspect ratio and minimal face model. This keeps visible cards visually
consistent while the app still lacks the full finsearch composition algorithm.

The saved finsearch renderer confirms that the website does not use full
pre-rendered card images. It composes cards as React DOM:

- `.card` uses a full-card background chosen from `card.band || "base"`.
- fish image maps from card `id` to `./<id>.webp`.
- cost, zone, tag, length, and ability icons are semantic SVG tokens.
- ability text uses bracket tokens such as `[FishEgg]` and `[Wave]`, which are
  replaced with icons and grouped icon runs.
- `IfActivated` and `GameEnd` ability strips use PNG strip backgrounds.
- blue / purple / green are full-card background choices, not a separate
  right-side color strip.

## Known Gaps

- Exact finsearch card composition rules are unavailable in this repository.
- Text wrapping, font family, icon placement, and masking are approximate.
- Fish image anchoring/cropping is approximate.
- Icon-to-rule semantic mapping is not complete.
- A future import step should either preserve the original renderer metadata or
  generate a reviewed local layout schema.

## TODO

- Add compact / normal / detail rendering modes.
- Decide whether visible SwiftUI card layout should adopt the webpage CSS ratio
  `61/40` instead of the current asset-derived ratio.
- Replace the current approximate card face with a CSS-coordinate-inspired
  SwiftUI layout using normalized `cqw` values from the reverse-engineering doc.
- Improve icon positioning and icon-to-field mapping.
- Add ability text tokenization for bracket icon tokens.
- Improve fish image crop, anchor, and mask handling.
- Add real visual QA against reviewed source cards.
- Keep the runtime fully offline by using only `Finspan/Resources/CardAssets/`.
