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
ratio `4394 / 2976 = 1.476478494623656`. SwiftUI `CardRenderMetrics.cardAspectRatio`
now uses the CSS ratio `61/40`; the asset-derived ratio remains available only
as source background metadata.

## Minimal Runtime Card Face Model

The app now uses a conservative SwiftUI approximation of the finsearch DOM card
structure:

- one shared visible aspect ratio from finsearch CSS: `61/40`
- `CardRenderMetrics` stores source dimensions, source ratio, CSS card ratio,
  and fixed hand-card dimensions
- `FishCardFaceView` renders one complete card face used by hand, ocean slots,
  and discard pile
- local full-card background chosen from base / blue / purple / green
- fish image in the CSS-inspired silhouette area, resolved from local asset
  files by source id
- fish name and scientific name in the top name area
- cost icons in the upper-left area
- zone icons in the left-side vertical area
- printed points, length, and size-class icons in CSS-inspired lower-left areas
- tag icons near the title when present
- ability trigger/text in a right-side panel
- IF ACTIVATED uses the local `IfActivated` tan brush/strip background
- GAME END uses the local `GameEnd` yellow brush/strip background
- WHEN PLAYED remains a transparent icon-composition area
- ability token parsing covers the current runtime base-game tokens, including
  `[FishFromHand]`, `[ArrowDown]`, `[PlayFishBottomRow]`, `[FishEgg]`,
  `[YoungFish]`, `[SchoolFish]`, `[Wave]`, `[AllPlayers]`, flipper icons,
  length icons, and consume/discard/draw/hatch tokens

This is intentionally a display layer only. It does not implement or interpret
real fish abilities.

The floating hand, discard pile preview/detail, and ocean slots all use this
same complete card face and adapt by outer frame / scale only. This stage does
not implement separate compact / normal / detail rendering modes. Resting hand
cards now expose about 68% of their height, and selected hand cards are pulled
out from the same stack without a negative bottom offset clipping the card.

The top HUD was also compressed: the log button now sits next to the settings
button in the upper-left controls, while weekly goal boxes remain in the upper
right.

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
- SwiftUI layout now keeps the main CSS cqw coordinates in `CardRenderMetrics`:
  cost top 3, zones top 11.5, silhouette left/top 22/19, points top 37,
  length top 48, and ability width 30.

## Known Gaps

- Some exact finsearch card composition rules are still approximated in SwiftUI.
- Text wrapping, font family, icon placement, and masking are approximate.
- Fish image anchoring/cropping is approximate.
- Icon-to-rule semantic mapping covers current base-game display tokens, but is
  not a complete rules mapping.
- The saved source maps and original font files are still unavailable.
- A future import step should either preserve the original renderer metadata or
  generate a reviewed local layout schema.

## TODO

- Add compact / normal / detail rendering modes later if the single complete
  face becomes too dense for very small slots.
- Improve icon positioning and special icon-group layouts beyond the current
  Abyssal Halosaur / Bluespine Unicornfish / Clown Anemonefish focused cases.
- Expand ability text tokenization for expansion-only tokens as those cards
  become runtime data.
- Improve fish image crop, anchor, and mask handling.
- Add real visual QA against reviewed source cards.
- Revisit fonts if the original finsearch font files become available.
- Keep the runtime fully offline by using only `Finspan/Resources/CardAssets/`.
