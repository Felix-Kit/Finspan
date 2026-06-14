# Card Rendering Fidelity

本文件记录 Finsearch card renderer reverse engineering 和
`FishCardFaceView` Fidelity Pass 1。这里描述的是展示层，不描述或改变游戏规则。

## Source of Truth

卡牌牌面复刻的真相来源优先级是：

1. 线上网页 `https://navarog.github.io/finsearch/` 实际加载的 HTML / JS / CSS / asset。
2. 线上 card renderer 的 token、icon、layout、font、background 和 fish image 映射。
3. `references/webpage/` 只作为旧缓存对照，不是绝对真相。
4. `Finspan/Resources/CardAssets/` 是 app 当前离线资源现状，不是绝对真相。
5. 旧 `FishCardFaceView` 只是最小可用近似实现，不能反向决定目标样式。

Runtime 仍必须离线使用 app bundle 内的 `Finspan/Resources/CardAssets/`，不能在运行时依赖 finsearch 远程 URL。线上网页只用于开发期审计和导入。

## Live Mirror

本轮已把线上网页资源镜像到 `references/webpage_live/`：

- `index.html`
- `static/js/main.3f6711eb.js`
- `static/css/main.f74b3868.css`
- `static/media/`
- `fonts/`
- `manifest.json`
- `asset_urls.txt`
- `asset_index.json`
- `reports/resource_diff.json`

Live asset count 为 288：

- `webp`: 222
- `svg`: 57
- `png`: 6
- `woff`: 1
- `otf`: 2

其中 110 个 asset 在 GitHub Pages 单独请求时需要用既有本地缓存补齐，但文件名和引用关系来自 live JS / CSS。

## Live Renderer Findings

线上 HTML 实际加载：

- JS: `/finsearch/static/js/main.3f6711eb.js`
- CSS: `/finsearch/static/css/main.f74b3868.css`

线上 CSS 字体：

- `Panforte Pro`: `Panforte-Pro.ttf.fac46a4fc984691c5461.woff`
- `Dolce`: `Dolce-Medium.5a8c804bd86540fd1771.otf`
- `Lexus Roman Optical`: `LexusRomanOpti-RegularIt.7bead565996221395db0.otf`

这些字体已导入 `Finspan/Resources/CardAssets/fonts/` 并在 app 启动时注册。当前没有发现 live renderer 引用但本地缺失的字体。如果系统无法注册某个字体，SwiftUI `.custom` 会自然 fallback 到系统字体；这种 fallback 不是目标状态。

线上 renderer 的核心映射：

- fish image: `card.id -> ./<card.id>.webp`，运行时 Swift 以 canonical source id 映射到本地 `<sourceId>.*.webp`。
- card background: `card.band || "base" -> ./<band>.webp`，band 包含 `base` / `blue` / `purple` / `green`。
- trigger band: `IfActivated` / `GameEnd` 使用对应 PNG strip。
- cost icon: `cardCost -> DrawCard`，`eggCost -> FishEgg`，`youngCost -> YoungFish`，`consuming -> ConsumeFish`，`schoolFishCost -> SchoolFish`，无 cost 使用 `NoCost`。
- zone icon: sunlight 使用 `Sun`，twilight 使用 `Dusk`，midnight 使用 `Night`；第二个 midnight 行另有 `PlayFishBottomRow` token。
- tag icon: `Predator`、`Bioluminescent`、`Camouflage`、`Electric`、`Venomous`。
- length icon: `<50` 使用 `FishLengthSmall`，`<150` 使用 `FishLengthMedium`，其余使用 `FishLengthLarge`。
- layout: `.card` 使用 `aspect-ratio: 61/40`；fish silhouette 位于左 22cqw / 上 19cqw，最大约 48cqw x 34cqw；points 位于约 37cqw；length 位于约 48cqw；ability 区约 30cqw 宽。

## Web-to-Swift Mapping

本轮新增 Swift resolver 层，把 web renderer model 映射到可缓存的 view state：

- `CardAssetResolver`
- `CardSymbolAssetResolver`
- `AbilityTokenAssetResolver`
- `FishImageAssetResolver`
- `CardTriggerStyleResolver`
- `CardFontStyleResolver`

`GameBoardViewModel` 和 `CardLibraryViewModel` 负责构造静态 `FishCardFaceViewState`。`FishCardFaceView` 只读取 view state 展示，不在 `body` 内解析 ability text，不扫描 bundle。

已接入的 token / icon 包括：

- `ArrowDown`
- `FishEgg`
- `YoungFish`
- `SchoolFish`
- `SchoolFeederMove`
- `DrawCard`
- `Discard`
- `FishHatch`
- `ConsumeFish1`
- `FishFromHand`
- `FreePlayFishFromHand`
- `AllPlayers`
- `Predator`
- `Sun` / `Sunlit`
- `Dusk` / `Twilight`
- `Night` / `Midnight`
- `BlueCoral`
- `PurpleCoral`
- `GreenCoral`
- `AnyCoral`
- `FishLengthSmall`
- `FishLengthMedium`
- `FishLengthLarge`
- `PlayFishBottomRow`
- `WhenPlayed`
- `IfActivated`
- `GameEnd`

`WhenPlayed` 目前保持透明 ability 区；`IfActivated` 和 `GameEnd` 使用 live trigger strip asset 和 Swift panel style。

## Resource Diff

`references/webpage_live/reports/resource_diff.json` 是本轮的机器可读差异报告。

`references/webpage/` 与 live 相比缺少 19 个资源：

- `Panforte-Pro.ttf.fac46a4fc984691c5461.woff`
- `Dolce-Medium.5a8c804bd86540fd1771.otf`
- `LexusRomanOpti-RegularIt.7bead565996221395db0.otf`
- `base.35519da28cd2f346a2ed.png`
- `base.f121413876c92b0271f4.webp`
- `blue.160a8f1c605b70b33352.png`
- `blue.b9baf436df4033049f53.webp`
- `green.4eaff11c554f88333ead.png`
- `green.374d1a75825b118218bc.webp`
- `purple.cd7cf06ece46fee1d80c.png`
- `purple.c493ffc8ca41cab3da6f.webp`
- `webpage.e8dc55dd9f8fa0caffc8.webp`
- `IfActivated.0c5d4ca8421590f6e8ef.webp`
- `IfActivated.f4ec95e03e7c3189135e.png`
- `GameEnd.027482f9c0439f2d1f17.webp`
- `GameEnd.1c86787c5a74319ee78f.png`
- `StarterIcon.e2156ba9467aa2981d59.svg`
- `TuckedCardSolo.7ccba819848db9a4cfe2.svg`
- `SRLogo.6fb02c8f2b92fa17505a.svg`

`Finspan/Resources/CardAssets/` 与 live 288 个 asset 文件名相比当前缺失 0 个。Pass 1 已把 live fonts 导入 app bundle。

## Fallbacks

Fallback 只能作为最后兜底，并通过 `MissingCardAsset` 进入 view state 供审计：

- `PlayFishTopRow` 和 `PlayFishAny` 是已建模 logical token，但本轮未在 live asset 中找到对应独立素材。
- 未知 ability token 会显示 `UnknownToken` fallback，并保留原 token 信息。
- 如果某个 live asset 后续缺失，Swift 会显示最小 fallback text，但该缺失会进入 `missingAssets`，不能被当作完成状态。

## Great White Shark

Great White Shark 已从旧近似渲染提升到 Pass 1 web mapping：

- real JSON 中保持 `base.main.057`，`visualAssetName` 仍为 `null`，不修改 card JSON。
- Swift 通过 canonical card id 推导 source id 57，fish image 解析到 live `57.*.webp`。
- ability token `[FishEgg][ArrowDown][Predator][AllPlayers]` 全部解析为 SVG asset。
- length 600 cm 映射到 `FishLengthLarge`。
- cost 使用 `YoungFish` 和 web `ConsumeFish` mapping。
- trigger / background / font 全部走 resolver view state。

视觉目标是“明显像网页”，不是像素级完成。

## Current Gap to Live Renderer

Pass 1 仍有这些差距：

- exact cqw positioning、line-height、font weight 和 text wrapping 尚未逐项像素对齐。
- ability text 中英文内容仍来自本地 JSON，不从 finsearch DOM 复制排版。
- fish silhouette 的 opacity、blend mode 和裁切仍需截图对照。
- trigger strip 和 ability panel 的叠放关系仍需 Pass 2 精调。
- `PlayFishTopRow` / `PlayFishAny` 仍是 reported fallback。
- Swift renderer 仍不是 HTML renderer；不会用 `WKWebView` 渲染每张卡。

## Ability Status

本轮不修改 card JSON、Ability Engine、规则、final scoring 或 deterministic/random 逻辑。

保持：

- Ability Engine v2 Core complete。
- 215 mapped / 0 unsupported。
- GAME END remaining unsupported 0。

## Pass 2 Next Steps

下一轮建议：

1. 用 live card screenshot 对 Great White Shark、If Activated、Game End 三类卡做像素级坐标表。
2. 把 title、scientific name、points、length、ability text 的 font size / line-height / wrapping 收敛到 live CSS。
3. 对 fish silhouette 的 frame、opacity、blend 和 clipping 做截图回归。
4. 明确 `PlayFishTopRow` / `PlayFishAny` 是网页无独立素材、复合图标、还是旧 token 名称误差。
5. 给 `MissingCardAsset` 做 debug report UI 或开发期导出脚本。
