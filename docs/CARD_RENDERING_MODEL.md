# Finspan Card Rendering Model

This note records the current presentation-layer model for card rendering. It
does not describe or implement game rules.

Update: Fidelity work should now use `docs/CARD_RENDERING_FIDELITY.md` as the
primary rendering audit. The online finsearch HTML / JS / CSS / asset graph is
the source of truth; this older model note is retained for historical context.

## Source Files Inspected

- `tools/raw/finsearch/finsearch_assets_manifest.json`
- `tools/raw/finsearch/finsearch_cards_raw.json`
- `tools/raw/finsearch/finspan_cards_normalized_draft.json`
- `tools/raw/finsearch/CARD_DATA_SCHEMA_DRAFT.md`

Update: a saved finsearch webpage was later inspected at
`references/webpage`. The detailed reverse-engineering notes are in
`docs/FINSEARCH_RENDERER_REVERSE_ENGINEERING.md`.

## Asset Groups

The older asset manifest contained 285 assets. The live audit in
`references/webpage_live/asset_index.json` now records 288 live assets,
including fonts:

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

This gives the shared fish-card width/height asset ratio:

```text
4394 / 2976 = 1.476478494623656
```

The ability strip assets are separate UI regions rather than the full card face:

- `IfActivated.*`: 472 x 295
- `GameEnd.*`: 472 x 295

The saved finsearch CSS explicitly sets `.card { aspect-ratio: 61/40; }`. That
display ratio is `1.525`, which differs from the full-card background pixel
ratio `4394 / 2976 = 1.476478494623656`. SwiftUI `CardRenderMetrics.cardAspectRatio`
now uses the CSS ratio `61/40`; the asset-derived ratio remains available only
as source background metadata.

## Current SwiftUI Card Face Model

The current card face is a conservative SwiftUI approximation of the finsearch
DOM card structure:

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
- ability token parsing covers the current runtime base-game and S&R tokens,
  including `[FishFromHand]`, `[ArrowDown]`, `[PlayFishBottomRow]`,
  `[FishEgg]`, `[YoungFish]`, `[SchoolFish]`, `[Wave]`, `[AllPlayers]`,
  flipper icons, length icons, coral icons, and consume/discard/draw/hatch
  tokens

This is intentionally a display layer only. It does not implement or interpret
real fish abilities.

The floating hand, discard pile preview/detail, and ocean slots all use this
same complete card face and adapt by outer frame / scale only. This stage does
not implement separate compact / normal / detail rendering modes. Resting hand
cards now expose about 68% of their height, and selected hand cards are pulled
out from the same stack without a negative bottom offset clipping the card.

## Rendering Boundaries

- Only real fish cards and unknown-card fallback use `FishCardFaceView`.
- Empty slots must not use `FishCardFaceView`.
- Forage fish should render as an independent placeholder / printed forage
  view, not as an unknown fish card.
- Hand / slot / discard pile are presentation variants of the same complete
  face, but the empty slot state should stay visually distinct.

## Known UI Bugs

- Empty slot曾错误显示 unknown fish card.
- Bottom card dock still needs the white background strip removed.
- Discard pile empty state should be hidden instead of appearing as an empty
  box.

## Still True

- The top HUD remains compressed: the log button sits next to settings in the
  upper-left controls, while weekly goal boxes remain in the upper right.
- The runtime should stay offline by using only `Finspan/Resources/CardAssets/`.
