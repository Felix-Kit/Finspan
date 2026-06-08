# Finsearch Renderer Reverse Engineering

This document records what can be confirmed from the locally saved finsearch
webpage at `/Users/work/Finspan/references/webpage/`. It is analysis only; the
saved webpage files should remain reference material and should not be moved into
app runtime resources.

## Source Files Inspected

- `/Users/work/Finspan/references/webpage/Finspan Card Search.html`
- `/Users/work/Finspan/references/webpage/Finspan Card Search_files/main.3f6711eb.js`
- `/Users/work/Finspan/references/webpage/Finspan Card Search_files/main.f74b3868.css`
- `/Users/work/Finspan/references/webpage/Finspan Card Search_files/*.webp`
- `/Users/work/Finspan/references/webpage/Finspan Card Search_files/*.svg`
- `Finspan/Resources/CardAssets/backgrounds/*`
- `tools/generated/assets/asset_download_summary.json`
- Generated analysis summary: `tools/generated/assets/card_renderer_analysis.json`

The saved webpage does not include `.map` files. Both JS and CSS reference source
maps (`main.3f6711eb.js.map`, `main.f74b3868.css.map`), but those files are not
present in the saved reference directory.

## HTML / JS / CSS Paths

- HTML shell: `/Users/work/Finspan/references/webpage/Finspan Card Search.html`
- React bundle: `/Users/work/Finspan/references/webpage/Finspan Card Search_files/main.3f6711eb.js`
- CSS bundle: `/Users/work/Finspan/references/webpage/Finspan Card Search_files/main.f74b3868.css`

The saved HTML includes prerendered first-screen card DOM under `#root`, and the
JS bundle can render the full card list client-side.

## Rendering Model

Finsearch cards are componentized DOM / React compositions. They are not canvas
drawings, not SVG-only cards, and not complete card preview images.

Each fish card is a `<div class="card">` with a background image and child DOM
nodes for title, scientific name, costs, zones, points, length, ability, fish
silhouette, description, optional expansion logo, and starter corner overlays.

The minified card component is named `D` in the saved bundle. Supporting
functions are:

- `b(card)`: renders tag icons next to the title.
- `y(card)`: renders cost icons.
- `v(card)`: renders zone icons and coral requirements.
- `C(card)`: builds zone class suffixes such as `s`, `st`, `m`, `stm`.
- `w(length)`: chooses small / medium / large fish length icon.
- `x(card)`: chooses the card background from `card.band || "base"`.
- `A(text)`: parses ability text and replaces bracket tokens with icons.
- `F(card)`: renders ability strip content and strip background.
- `E(card)`: renders starter-card corner overlays.

## Card Data

The JS bundle embeds card data as `JSON.parse(...)` in webpack module `4656`.
The analyzed bundle contains 215 cards:

- 200 main cards
- 15 starter cards
- 135 base cards
- 80 Sharks & Reefs cards

The card data includes fields used directly by the renderer:

- `id`
- `group`
- `name`
- `latin`
- `cardCost`
- `eggCost`
- `youngCost`
- `consuming`
- `schoolFishCost`
- `sunlight`
- `twilight`
- `midnight`
- `points`
- `length`
- `abilityType`
- `ability`
- `Bioluminescent`
- `Camouflage`
- `Electric`
- `Predator`
- `Venomous`
- `band`
- `description`
- `expansion`
- `coralCost`

## Background Assets

The renderer has two background require contexts:

- WebP card backgrounds: `n(8488)("./<band>.webp")`
- PNG card / strip backgrounds: `n(1881)("./<name>.png")`

Confirmed full-card background files:

- `base.f121413876c92b0271f4.webp`
- `blue.b9baf436df4033049f53.webp`
- `purple.c493ffc8ca41cab3da6f.webp`
- `green.374d1a75825b118218bc.webp`

Confirmed PNG equivalents also exist:

- `base.35519da28cd2f346a2ed.png`
- `blue.160a8f1c605b70b33352.png`
- `purple.cd7cf06ece46fee1d80c.png`
- `green.4eaff11c554f88333ead.png`

The CSS sets `.card { aspect-ratio: 61/40; background-size: cover; }`.
The local full-card background assets are `4394 x 2976`, ratio
`1.476478494623656`. CSS `61/40` is `1.525`, so the webpage ratio is explicitly
set in CSS and is not exactly the same as the asset pixel ratio.

Confirmed ability strip backgrounds:

- `IfActivated.f4ec95e03e7c3189135e.png`
- `GameEnd.1c86787c5a74319ee78f.png`
- WebP variants also exist in the bundle context, but the ability renderer uses
  the PNG context for `IfActivated` and `GameEnd`.

Local dimensions:

- Full-card backgrounds: `4394 x 2976`
- Ability strip backgrounds: `472 x 295`

## Background Selection

Card background selection is source-confirmed:

```js
const x = card => {
  const band = card.band || "base"
  return requireBackgroundWebp("./" + band + ".webp")
}
```

This means `base`, `blue`, `purple`, and `green` are not overlaid color bands in
the DOM. They are full-card background images selected by `card.band`, with
`base` as the fallback.

## Fish Image Mapping

Fish silhouette mapping is source-confirmed:

```js
<img className="silhouette" src={requireFish("./" + card.id + ".webp")} />
```

Webpack module `9230` contains keys `./1.webp` through `./215.webp`. The file
hashes are produced by the bundler, but the logical mapping is card `id` to
`<id>.webp`.

The saved webpage folder only contains the first-screen fish images because of
browser save behavior, but the app already has the full downloaded local fish
asset set under `Finspan/Resources/CardAssets/fish`.

## Icon Mapping

Icon mapping is source-confirmed through webpack module `6669`, which maps icon
names to SVG files. Renderer code requests icons by semantic names:

- Cost: `DrawCard`, `FishEgg`, `YoungFish`, `ConsumeFish`, `SchoolFish`, `NoCost`
- Zone: `Sun`, `Dusk`, `Night`, `PlayFishBottomRow`
- Tag: `Predator`, `Bioluminescent`, `Camouflage`, `Electric`, `Venomous`
- Ability: any supported bracket token, such as `FishHatch`, `ArrowDown`,
  `AllPlayers`, `AnyCoral`, `FlipperBlue`, `FlipperGreen`, `FlipperPurple`

Cost mapping is source-confirmed:

- `cardCost` → `DrawCard`
- `eggCost` → `FishEgg`
- `youngCost` → `YoungFish`
- `consuming` → `ConsumeFish`
- `schoolFishCost` → `SchoolFish`
- no costs → `NoCost`

Zone mapping is source-confirmed:

- `sunlight` → `Sun`
- `twilight` → `Dusk`
- `midnight` → `Night`
- `midnight == 2` → `PlayFishBottomRow`

Tag mapping is source-confirmed:

- `Predator`
- `Bioluminescent`
- `Camouflage`
- `Electric`
- `Venomous`

The renderer repeats icons according to numeric field values.

## Ability Token Mapping

Ability text uses bracket tokens such as `[FishEgg]`, `[ArrowDown]`, and
`[Wave]`. The parser function `A` splits ability text with regexes and renders:

- bracket token `[IconName]` as `<img class="<IconName>" src=<IconName.svg>>`
- `N [Wave]` as a special `.ability-points` row with the wave icon
- adjacent icon runs as `.icon-group`, with generated classes such as
  `FishHatch-3` or `FishFromHand-1 ArrowDown-1 PlayFishBottomRow-1`
- plain text as `<div class="ability-text">`

The search field uses the same bracket-token convention and validates tokens
against this explicit list:

```text
DrawCard, FishEgg, FishHatch, YoungFish, SchoolFeederMove, SchoolFish,
FishFromHand, FishFromHandConsume, ConsumeFish, Discard, AllPlayers, ArrowDown,
Estuary, FishLengthSmall, FishLengthMedium, FishLengthLarge, FlipperBlue,
FlipperGreen, FlipperPurple, PlayFishBottomRow, Predator, Wave, AnyCoral,
BlueCoral, GreenCoral, PurpleCoral, UnSchoolFish, FreePlayFishFromHand
```

## Layout Regions

All card-local sizing uses CSS container query width units (`cqw`) because
`.card` has `container-type: inline-size`. These are effectively percentages of
card width.

### Background

- `.card`
- `aspect-ratio: 61/40`
- `background-size: cover`
- `border: 1px solid #000`
- `border-radius: 4%/6.1%`
- `overflow: hidden`
- `position: relative`

### Cost Area

- `.cost`
- `position: absolute`
- `left: 0`
- `top: 3cqw`
- `min-width: 6.5cqw`
- `max-height: 18cqw`
- `padding: 1cqw 1.5cqw 1cqw 3cqw`
- `background-color: #ffffffb3`
- `border-radius: 0 5cqw 5cqw 0`
- flex row with wrapping and `gap: 1cqw`
- icons: `height: 4.4cqw`, `max-width: 6.4cqw`

### Zone Area

- `.zones`
- `position: absolute`
- `left: 0`
- `top: 11.5cqw`
- `height: 22.5cqw`
- `padding: 1cqw 1.5cqw 1cqw 3cqw`
- `background-color: #ffffffb3`
- `border-radius: 0 5cqw 5cqw 0`
- flex column with `gap: 1cqw`
- icons: `height: 5.6cqw`
- zone classes control vertical distribution:
  - `.zones.s`, `.zones.st`: `justify-content: flex-start`
  - `.zones.t`: `justify-content: center`
  - `.zones.m`, `.zones.tm`: `justify-content: flex-end`
  - `.zones.stm`, `.zones.sm`: `justify-content: space-between`

### Name Area

- `.name`
- flex column centered
- `margin-top: 3.5cqw`
- `.name .title`: `font-family: Panforte Pro`, `font-size: 5.8cqw`,
  `font-weight: 600`, `line-height: 1em`, `max-width: 48cqw`,
  `text-align: center`, `text-transform: uppercase`

Tag icons beside the title are placed in `.text-icon-container` with
`position: absolute`. JS measures the first line of the title with
`document.createRange()` and `ResizeObserver`, then sets:

```css
left: calc(50cqw + 0.5 * <first-line-title-width>px)
```

### Scientific Name Area

- `.name .latin`
- `font-family: Dolce`
- `font-size: 5cqw`
- `line-height: 1em`

Despite the user-facing concept being scientific name, the source field is named
`latin`.

### Fish Image Area

- `.silhouette`
- `position: absolute`
- `left: 22cqw`
- `top: 19cqw`
- `max-width: 48cqw`
- `max-height: 34cqw`

No per-card crop metadata was found. Browser layout uses `img` intrinsic aspect
ratio constrained by max width and height.

### Length / Size Area

- `.length`
- `position: absolute`
- `left: 0`
- `top: 48cqw`
- `margin-left: 4cqw`
- `width: 7.95cqw`
- `font-family: Panforte Pro`
- `font-size: 5cqw`
- `font-weight: 600`
- `line-height: .65em`
- length icon: `height: 11cqw`, `opacity: .5`
- length bucket: `< 50` small, `< 150` medium, otherwise large

### Printed Points Area

- `.points`
- `position: absolute`
- `left: 0`
- `top: 37cqw`
- `margin-left: 3cqw`
- `height: 7cqw`
- `font-family: Panforte Pro`
- `font-size: 7cqw`
- `font-weight: 600`
- wave icon fills height and is shifted with `right: 2.5cqw`, `top: 2cqw`

### Tag Area

There is no separate tag strip. Tags render next to the title as `.text-icon`
images:

- `height: .9em`
- first icon `margin-left: 2cqw`
- later icons `margin-left: 1cqw`

### Ability Area

- `.ability-container`
- `position: relative`
- `right: 28cqw`
- `min-width: 28cqw`
- `height: calc(100% - 1cqw)`
- `padding-top: 1cqw`
- flex column centered with `gap: 2cqw`

The `.ability` block:

- `background-size: cover`
- `display: flex`
- `flex-direction: column`
- `align-items: center`
- `justify-content: space-around`
- `font-size: 4.1cqw`
- `line-height: 1em`
- `min-height: 20cqw`
- `padding: 3cqw 0 5cqw`
- `width: 100%`

Ability text uses `.ability-text`; trigger labels add `.bold`.

### Dive Site Color Band

There is no separate `requiredDiveSiteColor` overlay in the finsearch DOM. The
color is represented by choosing the full-card background with `card.band`
(`blue`, `purple`, `green`) or falling back to `base`.

## Source-Confirmed Facts

- Cards are React DOM compositions.
- The card component is `.card` with child DOM elements, not a complete preview
  image.
- Full-card background is selected by `card.band || "base"`.
- Fish image maps by card `id` to `./<id>.webp`.
- Cost, zone, tag, and ability icons are semantic SVG names resolved through
  webpack require contexts.
- Ability text bracket tokens are parsed into image elements.
- CSS uses `cqw` container query units for card-local coordinates.
- CSS card aspect ratio is `61/40`.
- Local full-card background asset dimensions are `4394 x 2976`.

## Inferred From Assets

- The background image pixel ratio probably reflects source art dimensions, but
  the webpage does not use that pixel ratio as CSS aspect ratio.
- The app's existing `4394 / 2976` ratio is asset-derived; finsearch display
  ratio should use `61 / 40` if visual parity with the webpage is the goal.
- Since no crop metadata was found, fish image placement appears to rely on
  pre-cropped silhouette assets plus CSS max constraints.

## Still Unknown

- Original unminified React component names.
- Original source comments and design intent.
- Exact source-map mappings, because `.map` files are absent.
- Original font files were referenced by CSS but were not present in the saved
  browser cache directory.
- Whether source images were manually cropped before bundling.
- Any card-specific layout overrides beyond data fields visible in the bundle.

## Gap vs Current SwiftUI `FishCardFaceView`

Current SwiftUI rendering is a minimal approximation. Main gaps:

- It does not use the finsearch full-card background assets as the actual card
  background.
- It uses the asset-derived aspect ratio, while finsearch CSS uses `61/40`.
- It does not use `cqw`-equivalent region coordinates.
- It does not render title-adjacent tag icons.
- It does not render cost / zone / length / point icons with the same mappings
  and sizes.
- It does not parse ability bracket tokens into icon runs.
- It does not use `IfActivated` / `GameEnd` strip backgrounds for ability rows.
- It models `requiredDiveSiteColor` as a right accent strip, while finsearch uses
  a selected full-card background band.
- It does not include description text, starter corner overlays, or S&R logo.
- It uses system fonts rather than Panforte Pro, Dolce, and Lexus Roman Optical.

## Recommended SwiftUI Refactor

1. Add a renderer view model that preserves renderer fields separate from rule
   logic: `id`, `band`, `group`, `name`, `latin`, costs, zones, points, length,
   tags, `abilityType`, tokenized ability, description, and expansion.
2. Change `CardRenderMetrics` to support both ratios:
   - source asset ratio `4394 / 2976`
   - finsearch display ratio `61 / 40`
3. Build a reusable layout model using normalized card-width coordinates derived
   from CSS `cqw` values.
4. Replace the current ad hoc background with local full-card background images.
5. Resolve fish image by card id / source id prefix, preserving current offline
   local asset lookup.
6. Add semantic icon resolver for cost, zone, tag, length, and ability token
   icons.
7. Tokenize ability strings into text, point rows, icons, and icon groups before
   rendering.
8. Implement compact / normal / detail modes by choosing which confirmed regions
   are visible, not by changing rules data.
9. Keep all of this in presentation code and view-state construction. No rule
   validation or ability behavior should move into SwiftUI.
