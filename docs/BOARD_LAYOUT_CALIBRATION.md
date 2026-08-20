# Board Layout Calibration

The player board now uses the physical mat artwork and one normalized interaction map. The rulebooks were used only as visual source references; the app does not parse PDFs at runtime and no rule behavior is inferred from the image.

## Bundled artwork

- `Finspan/Resources/BoardAssets/base_player_mat_clean.png` is the 1850 × 3454 Base player mat with the three printed setup-resource marker cells removed. The untouched `base_player_mat.png` remains as the source artifact.
- `Finspan/Resources/BoardAssets/sharks_reefs_coral_overlay_aligned.png` is the physical S&R coral strip isolated from the user-provided S&R page 4 reference, resized to 1755 × 181 and backed with matching mat pixels so transparency cannot expose a mismatched layer. The original extracted strip remains available as a source artifact.
- `board_token_egg_orange.png` and `board_token_young_yellow.png` are transparent physical-piece sprites used by both setup and later resource placement. They add no badge or rounded container.
- Base and S&R use the same overall mat size and the same 18 slot rectangles. S&R conditionally layers the coral strip above Twilight.
- Runtime uses only these bundled local resources. It does not load a rulebook or Finsearch URL.
- These PNG files are standalone bundle resources rather than Asset Catalog image sets. `BoardImageAssetResolver` resolves their bundle URLs and caches decoded images; `Image(name)` must not be used for this artwork.

The current import is manual and traceable. Automatic PDF layer extraction, automatic slot recognition, perspective correction tooling, and a visual drag editor remain future work.

## Coordinate source

`Finspan/Resources/BoardLayout/player_mat_layout.json` contains:

- the physical image aspect ratio;
- the Base background asset name;
- whether forage fish are already printed in the background;
- the optional S&R coral overlay asset and rect;
- 18 `BoardLayoutSlot` entries.

Each slot uses normalized coordinates:

- `slotRect`: the complete printed slot outline;
- `cardRect`: the actual played-card frame, centered inside the small outline tolerance and preserving the fish-card ratio;
- `hitRect`: a slightly larger tap / drop region;
- `highlightRect`: the soft tint / glow region;
- `resourceAnchor`: the central artwork anchor for live board-resource tokens in a slot;
- `coralAnchor`: the center of the six printed coral spaces for that dive-site column;
- `diverAnchor`: the diver marker anchor.

All of these values map through `BoardLayoutMapper`. Card faces, transparent hit targets, highlights, resource hit targets, coral overlays, and DEBUG calibration must not implement separate aspect-fit math.

## Render stack

The board canvas is ordered from back to front:

1. Base physical player-mat image.
2. Optional S&R coral strip.
3. Soft highlight tint / glow.
4. Played fish card visual.
5. Transparent slot hit target.
6. Board resource-token hit targets.
7. Individual earned coral pieces and future diver markers.

The background owns printed slot outlines, zone art, three forage fish, and bottom-strip art. SwiftUI does not redraw those physical elements.

Normal empty slots render no card-like placeholder. When a physical background is present, Catalina Goby, Showy Bristlemouth, and Glasshead Grenadier use the printed mat artwork; their underlying `forageFish` state remains unchanged. Real played fish still render through `FishCardFaceView` and cover the slot.

Egg, young, and school are never redrawn as rounded resource cells on the player mat. Initial setup pieces and later resources use the same resolver-backed local token artwork at `resourceAnchor`, with a transparent, co-located payment hit target. Egg uses the orange translucent jelly piece, young uses the opaque yellow thick piece, and school keeps the existing local school artwork. The clean background removes the three former printed resource marker cells rather than trying to align live pieces with baked placeholders.

If the physical background cannot be found or decoded, the canvas deliberately falls back to the ocean gradient, dashed empty-slot outlines, and rendered forage-fish card faces. Hit targets and normalized mapping remain active, so a packaging mistake cannot make the entire interactive board invisible.

## S&R overlay

S&R does not use a wider, shorter, or otherwise separate slot map. The coral strip uses `coralOverlayRect` in the same normalized image space; its bottom edge is exactly `1909 / 3454`, the printed Twilight slot top. The aligned strip is opaque-backed, so the Base artwork cannot leak through its watercolor areas. `BoardCoralTokenLayout` maps `CoralReefState.coralCount` to up to six individual coral icons centered on the printed spaces; zero coral renders nothing and no numeric `0/6` badge is drawn. Rules and `CoralReefState` remain authoritative elsewhere.

## DEBUG calibration

`BoardLayoutCalibrationOverlay` can show `slotRect`, `cardRect`, `hitRect`, `highlightRect`, and slot ids using the same mapper. It is disabled during normal Debug play and can be enabled with either:

- launch argument `-showBoardCalibration`;
- environment variable `FINSPAN_SHOW_BOARD_CALIBRATION=1`.

The overlay does not mutate `GameState` and does not send `PlayerCommand`.

## Verification

Focused tests cover:

- aspect-fit mapping;
- normalized rect / point containment;
- decoding all 18 physical slots;
- physical card rect ratio and near-full slot coverage;
- bundled Base and S&R artwork inputs;
- resolving and decoding standalone board PNG files from the hosted app bundle;
- printed-forage versus real-card render policy;
- DEBUG overlay purity;
- staged playFish and resource-payment behavior remaining independent of layout.

The next calibration step is visual QA on multiple iPad sizes. Any edge adjustment must update the normalized JSON rather than add ad-hoc offsets in SwiftUI.
