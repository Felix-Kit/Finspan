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

Pass 2 / renderability note: the 57 live SVG icons also have same-name PNG
derivatives under `Finspan/Resources/CardAssets/icons/`. SwiftUI icon rendering
intentionally prefers these PNG derivatives because loose SVG files in the app
bundle are not a reliable `Image(resourceName)` source on iOS and cannot be
validated through the same `UIImage(contentsOfFile:)` runtime path. The SVG
files remain the live source asset; the PNG files are render assets derived
from that source.

The first PNG derivative batch was generated through Quick Look thumbnails and
resolved successfully, but the actual pixels were opaque near-white 512 x 512
blocks. The fixed pipeline is:

```text
live SVG source -> tools/scripts/render_card_icon_assets.py -> transparent high-res PNG render asset -> iOS bundle -> CardFaceIconAssetView
```

`tools/scripts/render_card_icon_assets.py` uses macOS `sips` and defaults to a
1536 px maximum dimension. `tools/scripts/audit_card_icon_renderability.py`
audits the generated PNGs for decode success, dimensions, alpha coverage,
non-white pixels, white backgrounds, all-transparent images, and source SVG
viewBox aspect ratio. Current result: 57 / 57 render PNGs pass.

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
- ability presentation in a right-side panel generated from raw English ability
  text before SwiftUI rendering; SwiftUI does not parse ability text inside
  `body`
- right-side ability panel metrics are centralized in `CardAbilityLayoutMetrics`
  and mapped from live CSS: 28cqw panel width / right offset, 1cqw top
  padding, full-height centered block container, and 2cqw multi-block gap
- English flavor / description text in the bottom live `.description` area
- IF ACTIVATED uses the local `IfActivated` brush/strip background per ability
  block
- GAME END uses the local `GameEnd` brush/strip background per ability block
- brush backgrounds use `CardAbilityBrushBackgroundView`, keep the live
  horizontal strip orientation, and use stretch resizing instead of
  `.scaledToFill()` clipping; pure color is not a normal fallback path
- WHEN PLAYED remains a transparent icon-composition area
- ability token parsing covers the current runtime base-game and S&R tokens,
  including `[FishFromHand]`, `[ArrowDown]`, `[PlayFishBottomRow]`,
  `[FishEgg]`, `[YoungFish]`, `[SchoolFish]`, `[Wave]`, `[AllPlayers]`,
  flipper icons, length icons, coral icons, and consume/discard/draw/hatch
  tokens
- consecutive icon runs follow the live renderer composition model: plus groups
  become horizontal ability rows, coral runs become horizontal coral groups, and
  arrow runs such as Great White Shark become vertical arrow-flow groups
- arrow-flow overlap is centralized in `CardAbilityArrowFlowMetrics`: default
  icon height 9cqw, ArrowDown height 15cqw, icon-group gap 1cqw, ArrowDown
  margin -5cqw, effective Swift stack spacing -4cqw, and no extra vertical
  offset
- `also, if` IF ACTIVATED abilities are split into a squished main brush block
  and a separate also-if brush block with a live-like gap
- `AllPlayers` uses a card-specific drop-shadow style matching the live CSS
  filter
- S&R cards display the live `SRLogo` expansion badge at the lower-right
- starter cards display two clipped gray corner overlays based on live CSS
  `.corner-overlay`; `StarterIcon` is retained as a search/filter live asset,
  not used for the fish-card corner decoration

All card-face icons use explicit SwiftUI frames from `CardRenderMetrics` and
`.resizable().scaledToFit()`. PNG intrinsic size is intentionally ignored for
layout; high resolution is used only so the icon remains sharp at the live
display size. Loading failure is visible in DEBUG as a red fallback marker and
is not silently rendered as a white placeholder.

This is intentionally a display layer only. It does not implement or interpret
real fish abilities. The presentation builder reads raw English card-face text
and metadata only to decide card-face composition, not gameplay behavior.

The current DEBUG card-face panel reports both renderability and layout
metadata: brush asset, brush orientation/content mode, ability panel frame,
arrow-flow metrics, also-if gap, card id, source id, block types, token
placements, S&R badge, starter corner, AllPlayers shadow, and missing/failing
icon counts.

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
