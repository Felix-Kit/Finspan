# Card Rendering Live Measurements

Generated: 2026-06-16T03:55:25.968Z

Source of truth: local render of `references/webpage_live/index.html` through Chromium/Playwright. The local server maps `/finsearch/*` to the mirrored live assets so computed CSS matches the published finsearch paths.

## Summary

| Card | Card frame px | Ability panel px | Panel cqw | Right gap cqw | Blocks | Brush mode |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| base.main.014 Banggai Cardinalfish | 375.328125 x 246.796875 | 104.53125 x 244.78125 | 71.883 / 27.851 | 0.266 | 1 | IfActivated; size cover; pos 0% 0%; repeat repeat; origin padding-box; clip border-box |
| base.main.057 Great White Shark | 375.328125 x 246.796875 | 104.53125 x 244.78125 | 71.883 / 27.851 | 0.266 | 1 | none; size cover; pos 0% 0%; repeat repeat; origin padding-box; clip border-box |
| base.main.016 Bearded Seadevil | 375.328125 x 246.796875 | 104.53125 x 244.78125 | 71.883 / 27.851 | 0.266 | 1 | none; size cover; pos 0% 0%; repeat repeat; origin padding-box; clip border-box |
| sr.starter.212 Atlantic Barracudina | 375.328125 x 246.796875 | 104.53125 x 244.78125 | 71.883 / 27.851 | 0.266 | 2 | IfActivated; size cover; pos 0% 0%; repeat repeat; origin padding-box; clip border-box |
| sr.main.161 Great Barracuda | 375.328125 x 246.796875 | 104.53125 x 244.78125 | 71.883 / 27.851 | 0.266 | 1 | none; size cover; pos 0% 0%; repeat repeat; origin padding-box; clip border-box |
| base.main.001 Abyssal Anglerfish | 375.328125 x 246.796875 | 104.53125 x 244.78125 | 71.883 / 27.851 | 0.266 | 1 | GameEnd; size cover; pos 0% 0%; repeat repeat; origin padding-box; clip border-box |
| base.main.056 Great Northern Tilefish | 375.328125 x 246.796875 | 104.53125 x 244.78125 | 71.883 / 27.851 | 0.266 | 1 | IfActivated; size cover; pos 0% 0%; repeat repeat; origin padding-box; clip border-box |

## Brush Background Findings

- Live ability blocks use CSS `background-image` on `.ability`, not a foreground `img`.
- Computed `background-size` is `cover`.
- Computed `background-position` is `0% 0%`.
- Computed `background-repeat` is `repeat` because CSS does not override the default, but `background-size: cover` makes the single brush image cover each block frame.
- Computed `background-origin` is `padding-box`; computed `background-clip` is `border-box`.
- No representative block reports a transform or rotation on the brush element.
- The correct Swift mapping is therefore an unrotated, top-leading cover/crop of the same brush raster, with the block frame measured from live layout.

## Card Details

### base.main.014 Banggai Cardinalfish

- Card frame: {"x":99,"y":273.640625,"width":375.328125,"height":246.796875,"top":273.640625,"right":474.328125,"bottom":520.4375,"left":99}
- Ability container: {"frame":{"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875},"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875,"cqw":{"left":71.883,"top":0.266,"width":27.851,"height":65.218,"rightGap":0.266,"bottomGap":0.271},"style":{"display":"flex","flexDirection":"column","gap":"7.46656px","height":"241.062px","justifyContent":"center","minWidth":"104.532px","paddingTop":"3.73328px","position":"relative","right":"104.532px","transform":"none","zIndex":"auto"}}
- Swift pre-fix estimated panel frame: {"left":369.236,"top":277.394,"width":105.092,"height":242.364,"rightGap":0,"cqw":{"left":72,"top":1,"width":28,"height":64.574,"rightGap":0}}

| Block | Classes | Frame px | Frame cqw | Content inset cqw | Background | Rendered brush | Padding px |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | ability | 104.53125 x 104.5 @ 368.796875, 346.640625 | x 71.883; y 19.45; w 27.851; h 27.842 | t 4.446; b 6.44; l 2.922; r 2.922 | IfActivated; cover; 0% 0%; repeat; origin padding-box; clip border-box; transform none | 167.2 x 104.5; crop r 62.669; b 0 | t 11.1998; r 0; b 18.6664; l 0 |
- Ability icons: FishHatch@77.545,31.901 16.523x8.951

### base.main.057 Great White Shark

- Card frame: {"x":99,"y":273.640625,"width":375.328125,"height":246.796875,"top":273.640625,"right":474.328125,"bottom":520.4375,"left":99}
- Ability container: {"frame":{"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875},"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875,"cqw":{"left":71.883,"top":0.266,"width":27.851,"height":65.218,"rightGap":0.266,"bottomGap":0.271},"style":{"display":"flex","flexDirection":"column","gap":"7.46656px","height":"241.062px","justifyContent":"center","minWidth":"104.532px","paddingTop":"3.73328px","position":"relative","right":"104.532px","transform":"none","zIndex":"auto"}}
- Swift pre-fix estimated panel frame: {"left":369.236,"top":277.394,"width":105.092,"height":242.364,"rightGap":0,"cqw":{"left":72,"top":1,"width":28,"height":64.574,"rightGap":0}}

| Block | Classes | Frame px | Frame cqw | Content inset cqw | Background | Rendered brush | Padding px |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | ability | 104.53125 x 180.234375 @ 368.796875, 308.765625 | x 71.883; y 9.358; w 27.851; h 48.02 | t 2.981; b -4.13; l 1.69; r 1.69 | none; cover; 0% 0%; repeat; origin padding-box; clip border-box; transform none | none | t 11.1998; r 0; b 18.6664; l 0 |
- ArrowDown: {"icon":{"index":1,"className":"ArrowDown","alt":"ArrowDown","src":"http://127.0.0.1:4173/finsearch/static/media/ArrowDown.6d19faad0ef0c8eedd9b.svg","frame":{"x":391.421875,"y":376.671875,"width":59.265625,"height":55.984375,"top":376.671875,"right":450.6875,"bottom":432.65625,"left":391.421875},"cqw":{"left":77.911,"top":27.451,"width":15.79,"height":14.916,"rightGap":6.299,"bottomGap":23.388},"style":{"height":"55.9844px","width":"59.2656px","maxHeight":"none","maxWidth":"none","marginTop":"-18.6664px","marginRight":"0px","marginBottom":"-18.6664px","marginLeft":"0px","position":"static","bottom":"auto","filter":"none","zIndex":"1","objectFit":"fill","transform":"none"},"marginCqw":{"top":-4.973,"right":0,"bottom":-4.973,"left":0}},"previousIcon":{"index":0,"className":"FishEgg","alt":"FishEgg","src":"http://127.0.0.1:4173/finsearch/static/media/FishEgg.47c0854a65b931607a5f.svg","frame":{"x":391.421875,"y":358.015625,"width":59.265625,"height":33.59375,"top":358.015625,"right":450.6875,"bottom":391.609375,"left":391.421875},"cqw":{"left":77.911,"top":22.48,"width":15.79,"height":8.951,"rightGap":6.299,"bottomGap":34.324},"style":{"height":"33.5938px","width":"59.2656px","maxHeight":"none","maxWidth":"none","marginTop":"0px","marginRight":"0px","marginBottom":"0px","marginLeft":"0px","position":"static","bottom":"auto","filter":"none","zIndex":"auto","objectFit":"fill","transform":"none"},"marginCqw":{"top":0,"right":0,"bottom":0,"left":0}},"nextIcon":{"index":2,"className":"Predator","alt":"Predator","src":"http://127.0.0.1:4173/finsearch/static/media/Predator.a0c36e62cbb3e0d8c25e.svg","frame":{"x":391.421875,"y":417.71875,"width":59.265625,"height":33.59375,"top":417.71875,"right":450.6875,"bottom":451.3125,"left":391.421875},"cqw":{"left":77.911,"top":38.387,"width":15.79,"height":8.951,"rightGap":6.299,"bottomGap":18.417},"style":{"height":"33.5938px","width":"59.2656px","maxHeight":"none","maxWidth":"none","marginTop":"0px","marginRight":"0px","marginBottom":"0px","marginLeft":"0px","position":"static","bottom":"auto","filter":"none","zIndex":"auto","objectFit":"fill","transform":"none"},"marginCqw":{"top":0,"right":0,"bottom":0,"left":0}},"topOverlapPx":14.9375,"bottomOverlapPx":14.9375,"topOverlapCqw":3.98,"bottomOverlapCqw":3.98}
- Ability icons: FishEgg@77.911,22.48 15.79x8.951; ArrowDown@77.911,27.451 15.79x14.916; Predator@77.911,38.387 15.79x8.951; AllPlayers@77.424,52.558 16.764x8.951

### base.main.016 Bearded Seadevil

- Card frame: {"x":99,"y":273.640625,"width":375.328125,"height":246.796875,"top":273.640625,"right":474.328125,"bottom":520.4375,"left":99}
- Ability container: {"frame":{"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875},"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875,"cqw":{"left":71.883,"top":0.266,"width":27.851,"height":65.218,"rightGap":0.266,"bottomGap":0.271},"style":{"display":"flex","flexDirection":"column","gap":"7.46656px","height":"241.062px","justifyContent":"center","minWidth":"104.532px","paddingTop":"3.73328px","position":"relative","right":"104.532px","transform":"none","zIndex":"auto"}}
- Swift pre-fix estimated panel frame: {"left":369.236,"top":277.394,"width":105.092,"height":242.364,"rightGap":0,"cqw":{"left":72,"top":1,"width":28,"height":64.574,"rightGap":0}}

| Block | Classes | Frame px | Frame cqw | Content inset cqw | Background | Rendered brush | Padding px |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | ability | 104.53125 x 185.84375 @ 368.796875, 305.96875 | x 71.883; y 8.613; w 27.851; h 49.515 | t 2.981; b -3.38; l 1.569; r 1.574 | none; cover; 0% 0%; repeat; origin padding-box; clip border-box; transform none | none | t 11.1998; r 0; b 18.6664; l 0 |
- ArrowDown: {"icon":{"index":1,"className":"ArrowDown","alt":"ArrowDown","src":"http://127.0.0.1:4173/finsearch/static/media/ArrowDown.6d19faad0ef0c8eedd9b.svg","frame":{"x":374.6875,"y":373.875,"width":92.734375,"height":55.984375,"top":373.875,"right":467.421875,"bottom":429.859375,"left":374.6875},"cqw":{"left":73.452,"top":26.706,"width":24.708,"height":14.916,"rightGap":1.84,"bottomGap":24.133},"style":{"height":"55.9844px","width":"92.7344px","maxHeight":"none","maxWidth":"none","marginTop":"-18.6664px","marginRight":"0px","marginBottom":"-18.6664px","marginLeft":"0px","position":"static","bottom":"auto","filter":"none","zIndex":"1","objectFit":"fill","transform":"none"},"marginCqw":{"top":-4.973,"right":0,"bottom":-4.973,"left":0}},"previousIcon":{"index":0,"className":"FishEgg","alt":"FishEgg","src":"http://127.0.0.1:4173/finsearch/static/media/FishEgg.47c0854a65b931607a5f.svg","frame":{"x":374.6875,"y":355.21875,"width":92.734375,"height":33.59375,"top":355.21875,"right":467.421875,"bottom":388.8125,"left":374.6875},"cqw":{"left":73.452,"top":21.735,"width":24.708,"height":8.951,"rightGap":1.84,"bottomGap":35.069},"style":{"height":"33.5938px","width":"92.7344px","maxHeight":"none","maxWidth":"none","marginTop":"0px","marginRight":"0px","marginBottom":"0px","marginLeft":"0px","position":"static","bottom":"auto","filter":"none","zIndex":"auto","objectFit":"fill","transform":"none"},"marginCqw":{"top":0,"right":0,"bottom":0,"left":0}},"nextIcon":{"index":2,"className":"FishLengthSmall","alt":"FishLengthSmall","src":"http://127.0.0.1:4173/finsearch/static/media/FishLengthSmall.3e492f67da0ac3eaf601.svg","frame":{"x":374.6875,"y":414.921875,"width":92.734375,"height":44.796875,"top":414.921875,"right":467.421875,"bottom":459.71875,"left":374.6875},"cqw":{"left":73.452,"top":37.642,"width":24.708,"height":11.935,"rightGap":1.84,"bottomGap":16.178},"style":{"height":"44.7969px","width":"92.7344px","maxHeight":"none","maxWidth":"none","marginTop":"0px","marginRight":"0px","marginBottom":"-5.59992px","marginLeft":"0px","position":"static","bottom":"auto","filter":"none","zIndex":"auto","objectFit":"fill","transform":"none"},"marginCqw":{"top":0,"right":0,"bottom":-1.492,"left":0}},"topOverlapPx":14.9375,"bottomOverlapPx":14.9375,"topOverlapCqw":3.98,"bottomOverlapCqw":3.98}
- Ability icons: FishEgg@73.452,21.735 24.708x8.951; ArrowDown@73.452,26.706 24.708x14.916; FishLengthSmall@73.452,37.642 24.708x11.935; AllPlayers@77.424,52.558 16.764x8.951

### sr.starter.212 Atlantic Barracudina

- Card frame: {"x":99,"y":273.640625,"width":375.328125,"height":246.796875,"top":273.640625,"right":474.328125,"bottom":520.4375,"left":99}
- Ability container: {"frame":{"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875},"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875,"cqw":{"left":71.883,"top":0.266,"width":27.851,"height":65.218,"rightGap":0.266,"bottomGap":0.271},"style":{"display":"flex","flexDirection":"column","gap":"7.46656px","height":"241.062px","justifyContent":"center","minWidth":"104.532px","paddingTop":"3.73328px","position":"relative","right":"104.532px","transform":"none","zIndex":"auto"}}
- Swift pre-fix estimated panel frame: {"left":369.236,"top":277.394,"width":105.092,"height":242.364,"rightGap":0,"cqw":{"left":72,"top":1,"width":28,"height":64.574,"rightGap":0}}

| Block | Classes | Frame px | Frame cqw | Content inset cqw | Background | Rendered brush | Padding px |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | ability squished | 104.53125 x 67.53125 @ 368.796875, 302.640625 | x 71.883; y 7.727; w 27.851; h 17.993 | t 1.986; b 1.986; l 2.922; r 2.922 | IfActivated; cover; 0% 0%; repeat; origin padding-box; clip border-box; transform none | 108.05 x 67.531; crop r 3.519; b 0 | t 7.46656; r 0; b 7.46656; l 0 |
| 2 | ability also-if | 104.53125 x 132.4375 @ 368.796875, 377.625 | x 71.883; y 27.705; w 27.851; h 35.286 | t 2.981; b 4.396; l 0.991; r 0.991 | IfActivated; cover; 0% 0%; repeat; origin padding-box; clip border-box; transform none | 211.9 x 132.438; crop r 107.369; b 0 | t 11.1998; r 3.73328; b 11.1998; l 3.73328 |
- also-if gap: {"px":7.453125,"cqw":1.986}
- Ability icons: FishHatch@77.545,14.783 16.523x8.951; GreenCoral@76.595,34.765 18.421x4.263; GreenCoral@76.595,39.028 18.421x4.263; GreenCoral@76.595,43.291 18.421x4.263; SchoolFeederMove@82.328,51.634 6.961x6.961

### sr.main.161 Great Barracuda

- Card frame: {"x":99,"y":273.640625,"width":375.328125,"height":246.796875,"top":273.640625,"right":474.328125,"bottom":520.4375,"left":99}
- Ability container: {"frame":{"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875},"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875,"cqw":{"left":71.883,"top":0.266,"width":27.851,"height":65.218,"rightGap":0.266,"bottomGap":0.271},"style":{"display":"flex","flexDirection":"column","gap":"7.46656px","height":"241.062px","justifyContent":"center","minWidth":"104.532px","paddingTop":"3.73328px","position":"relative","right":"104.532px","transform":"none","zIndex":"auto"}}
- Swift pre-fix estimated panel frame: {"left":369.236,"top":277.394,"width":105.092,"height":242.364,"rightGap":0,"cqw":{"left":72,"top":1,"width":28,"height":64.574,"rightGap":0}}

| Block | Classes | Frame px | Frame cqw | Content inset cqw | Background | Rendered brush | Padding px |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | ability | 104.53125 x 138.8125 @ 368.796875, 329.484375 | x 71.883; y 14.879; w 27.851; h 36.984 | t 2.981; b -9.646; l 1.69; r 1.636 | none; cover; 0% 0%; repeat; origin padding-box; clip border-box; transform none | none | t 11.1998; r 0; b 18.6664; l 0 |
- Ability icons: BlueCoral@81.333,28 8.951x8.951; BlueCoral@81.333,37.942 8.951x8.951; AllPlayers@81.333,52.558 16.764x8.951

### base.main.001 Abyssal Anglerfish

- Card frame: {"x":99,"y":273.640625,"width":375.328125,"height":246.796875,"top":273.640625,"right":474.328125,"bottom":520.4375,"left":99}
- Ability container: {"frame":{"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875},"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875,"cqw":{"left":71.883,"top":0.266,"width":27.851,"height":65.218,"rightGap":0.266,"bottomGap":0.271},"style":{"display":"flex","flexDirection":"column","gap":"7.46656px","height":"241.062px","justifyContent":"center","minWidth":"104.532px","paddingTop":"3.73328px","position":"relative","right":"104.532px","transform":"none","zIndex":"auto"}}
- Swift pre-fix estimated panel frame: {"left":369.236,"top":277.394,"width":105.092,"height":242.364,"rightGap":0,"cqw":{"left":72,"top":1,"width":28,"height":64.574,"rightGap":0}}

| Block | Classes | Frame px | Frame cqw | Content inset cqw | Background | Rendered brush | Padding px |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | ability | 104.53125 x 120.53125 @ 368.796875, 338.625 | x 71.883; y 17.314; w 27.851; h 32.114 | t 2.981; b 4.971; l 0; r 0 | GameEnd; cover; 0% 0%; repeat; origin padding-box; clip border-box; transform none | 192.85 x 120.531; crop r 88.319; b 0 | t 11.1998; r 0; b 18.6664; l 0 |
- Ability icons: @80.33,24.866 10.395x8.951

### base.main.056 Great Northern Tilefish

- Card frame: {"x":99,"y":273.640625,"width":375.328125,"height":246.796875,"top":273.640625,"right":474.328125,"bottom":520.4375,"left":99}
- Ability container: {"frame":{"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875},"x":368.796875,"y":274.640625,"width":104.53125,"height":244.78125,"top":274.640625,"right":473.328125,"bottom":519.421875,"left":368.796875,"cqw":{"left":71.883,"top":0.266,"width":27.851,"height":65.218,"rightGap":0.266,"bottomGap":0.271},"style":{"display":"flex","flexDirection":"column","gap":"7.46656px","height":"241.062px","justifyContent":"center","minWidth":"104.532px","paddingTop":"3.73328px","position":"relative","right":"104.532px","transform":"none","zIndex":"auto"}}
- Swift pre-fix estimated panel frame: {"left":369.236,"top":277.394,"width":105.092,"height":242.364,"rightGap":0,"cqw":{"left":72,"top":1,"width":28,"height":64.574,"rightGap":0}}

| Block | Classes | Frame px | Frame cqw | Content inset cqw | Background | Rendered brush | Padding px |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | ability | 104.53125 x 119.78125 @ 368.796875, 339 | x 71.883; y 17.414; w 27.851; h 31.914 | t 2.981; b 4.971; l 2.922; r 2.922 | IfActivated; cover; 0% 0%; repeat; origin padding-box; clip border-box; transform none | 191.65 x 119.781; crop r 87.119; b 0 | t 11.1998; r 0; b 18.6664; l 0 |
- Ability icons: FishHatch@77.545,25.465 16.523x8.951; FishHatch@77.545,35.407 16.523x8.951

## Fix Guidance

- Use measured live cqw frames for `CardAbilityPanelMetrics` instead of undocumented offsets.
- Render brush backgrounds with live `cover` semantics and top-leading alignment; do not cap-inset stretch the raster.
- Keep ArrowDown metrics tied to measured `.ArrowDown { height: 15cqw; margin: -5cqw 0; }` and representative overlap results.

## Applied Swift Mapping

- `CardAbilityPanelMetrics.live` now uses the measured container frame: left `71.883cqw`, top `0.266cqw`, width `27.851cqw`, height `65.218cqw`, right gap `0.266cqw`, block gap `1.986cqw`.
- `CardAbilityBrushMetrics.live` now records `assetContentMode = coverTopLeading`, `backgroundPosition = 0% 0%`, `backgroundRepeat = repeat`, `capInsetCqw = 0`, and `cornerRadiusCqw = 0`.
- `CardAbilityBrushBackgroundView` maps CSS background cover with top-leading alignment by calculating the cover-scaled image size from the measured block frame and clipping to that frame.
- Swift applies the brush as a block `.background`, not a `ZStack` content child, because live CSS background images do not participate in ability block layout.
- `CardAbilityBlockMetrics` uses measured minimum heights: standard `27.842cqw`, squished `17.993cqw`, also-if `35.286cqw`.
- DEBUG card face status can show the live measured frame, current Swift frame, and delta when `tools/generated/card_rendering/live_measurements.json` is present.

