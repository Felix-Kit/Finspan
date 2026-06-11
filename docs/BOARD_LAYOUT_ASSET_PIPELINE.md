# Board Layout Asset Pipeline

This document records the recommended workflow for board layout assets and
runtime coordinate data. It is intentionally separate from rules logic.

## Goal

Produce a runtime-safe pipeline where:

- source art can be reviewed in SVG / PNG / PSD / PDF form
- layout rectangles can be edited visually
- runtime only depends on PNG assets plus a generated `BoardLayout.json`
- SwiftUI can render board regions without parsing design files at runtime

## Recommended Input Assets

- PDF: for source review and manual annotation
- PSD: if available, for layered production art
- PNG: for raster overlays and quick visual checks
- SVG: for editable layout overlays and rectangle annotations

The runtime should not depend on the annotated SVG directly. It should depend on
the exported raster background and the generated layout JSON.

## Suggested Naming

Use stable, descriptive rectangle ids:

- `slot_blue_sunlight_0`
- `slot_blue_sunlight_1`
- `slot_blue_sunlight_2`
- `slot_blue_twilight_0`
- `slot_blue_midnight_0`
- `coral_reef_blue`
- `coral_reef_purple`
- `coral_reef_green`
- `diver_area`
- `discard_pile_area`
- `hand_area`
- `hud_area`

If more precise subregions are needed, keep the same pattern:

- `action_panel_area`
- `player_summary_area`
- `top_toast_area`

## Suggested Pipeline

1. Review the source board art in a design tool or image editor.
2. Add annotation rectangles with the stable ids above.
3. Export the annotated overlay as SVG or another review artifact.
4. Generate `BoardLayout.json` from the annotation layer.
5. Export the final board art as PNG.
6. Load only the PNG and `BoardLayout.json` at runtime.
7. Keep coordinate mapping code in SwiftUI / view-state conversion, not in
   rules logic.

## Coordinate Mapping

Treat board regions as aspect-fit anchored rectangles inside the final art
image.

- Store the source image size in the layout JSON.
- Store each rectangle in source-image coordinates.
- Convert source coordinates to runtime coordinates after aspect-fit scaling.
- Keep safe-area handling in the view layer, not in the layout data.

## Runtime Responsibilities

- SwiftUI reads `BoardLayout.json`.
- SwiftUI uses the JSON to position slot overlays, coral reefs, discard area,
  and other board regions.
- The game engine should not care about pixel coordinates.
- The rules layer should not parse or render SVG.

## Future Use

This pipeline can later support:

- board background alignment
- slot rect tuning
- coral reef overlays
- diver / action zones
- discard pile dock positioning

The key constraint is to keep the runtime dependency set small and offline:
PNG art plus generated JSON only.
