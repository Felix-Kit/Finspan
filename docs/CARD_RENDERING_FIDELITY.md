# Card Rendering Fidelity

本文件记录 Finsearch card renderer reverse engineering 和
`FishCardFaceView` Fidelity Pass 1 / Pass 1.5 / Pass 2。这里描述的是展示层，不描述或改变游戏规则。

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

Swift resolver 层把 web renderer model 映射到可缓存的 view state：

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

Pass 1.5 修正了“资源已导入但未完整应用”的 wiring 问题：

- `IfActivated` / `GameEnd` trigger strip 被限制在 ability panel 宽度内，layout metadata 明确区分 full-card width、ability panel width 和 trigger strip width；背景使用 stretch + clipping，不再横向溢出到鱼图区域。
- cost / requirement 区域统一由 `FishCardFaceViewState.costIcons` 驱动，base cost、egg、young、consume、school fish、NoCost 和 S&R coral requirement 都走 `CardSymbolAssetResolver`。
- zone 区域统一由 `zoneIcons` 驱动，`Sun` / `Dusk` / `Night` 和 live `midnight == 2` 的 `PlayFishBottomRow` 都走真实 asset；`PlayFishBottomRow` 只作为显示层 live source mapping，不改变 `OceanZone` 规则语义。
- points 区域新增 `pointsIcon` view-state 字段，分数图标使用 live `Wave` asset，不再在 View 内硬编码无 resolver 图标。
- length 区域继续使用 `FishLengthSmall` / `FishLengthMedium` / `FishLengthLarge`，并通过 resolver 确认真实 SVG。
- card face 内的 name、scientific name、ability text 和 trigger title 使用 English / raw source；外层 App UI 仍可继续使用中文。
- ability token sequence 基于 raw ability text 解析，`FishCardFaceView` 渲染 resolver 后的 icon sequence，未知 token 会进入 `MissingCardAsset`。

`WhenPlayed` 目前保持透明 ability 区；`IfActivated` 和 `GameEnd` 使用 live trigger strip asset 和 Swift panel style。

Pass 2 继续以 live finsearch 为 source of truth，修正“view state 已有字段但 SwiftUI 没有真实渲染”的问题：

- live SVG icon 现在有同名 PNG 派生资源，`CardSymbolAssetResolver` 对 icon lookup 优先返回 PNG / WebP，再 fallback SVG。这样 cost、zone、Wave、FishLength 和 ability token 在 iOS runtime 中通过 `UIImage(contentsOfFile:)` 渲染，不再依赖 loose SVG 被 `Image(resourceName)` 正确识别。
- `FishCardFaceViewState` 新增 `flavorText`，base / S&R 215 张卡的英文 description 从 live JS 抽取为 `Finspan/Resources/CardAssets/card_face_descriptions.json`；S&R 如已有 `rawSource.description` 则优先使用原 JSON 字段。这个 metadata 只用于牌面渲染，不改变 `Resources/Cards/*.json` 或规则。
- `FishCardFaceView` 新增 live `.description` 区域：left 22cqw、top 50cqw、width 50cqw、`Lexus Roman Optical` italic、2.5cqw，恢复底部英文 flavor text。
- ability icon sequence 已进入 resolver-backed view state；Pass 2 当时仍是近似布局，后续 Pass 已改为 live token composition model，不再把所有连续 icon 简化为统一横排。
- `Panforte Pro`、`Dolce`、`Lexus Roman Optical` 分别落到 title / scientific name / flavor text；points、length、trigger 和 ability copy 继续使用 live title font family。
- Great White Shark、Great Northern Tilefish、Great Barracuda 是本轮代表卡审计样例，不是 special case。

## Icon Renderability Pipeline

Pass 2 后又完成了一轮 Fish Card Icon Vector / Renderability Pipeline Fix。根因不是 resolver 缺映射，而是旧 `.svg.png` 衍生图由 Quick Look thumbnail 路径生成：文件能解析，但像素内容是 512 x 512 的不透明近白背景，App 实际加载后就表现为白色方块。

当前策略：

- `references/webpage_live/` 和 `Finspan/Resources/CardAssets/icons/*.svg` 仍是 icon source of truth。
- iOS runtime 不把 loose SVG 当作主要 SwiftUI image。原因是 `Image(resourceName)` 对 app bundle loose SVG 不稳定，也无法提供统一的 `UIImage(contentsOfFile:)` runtime decode / pixel audit 路径。
- render asset 使用 same-name high-resolution PNG：`*.svg -> *.svg.png`。
- 生成脚本是 `tools/scripts/render_card_icon_assets.py`，使用 macOS `sips` 从相邻 SVG 导出透明 PNG，默认最大边 1536 px。
- 审计脚本是 `tools/scripts/audit_card_icon_renderability.py`，会读取真实 PNG 尺寸，从 PNG 派生临时审计样本并检查 alpha、non-white pixels、白底、全透明、尺寸和 SVG viewBox aspect ratio。
- `CardSymbolAssetResolver` 继续按 `png / webp / svg` 优先级解析 icon，因此 SwiftUI 正常路径使用 PNG render asset，SVG 只保留为 source / last fallback。
- `CardFaceIconAssetView` 统一渲染 cost / requirement、playable zones、Wave、FishLength、ability tokens、tag / coral icons；正常图标使用 `.renderingMode(.original)`、`.resizable()`、`.scaledToFit()` 和明确 frame。
- 图标显示尺寸来自 live-inspired `CardRenderMetrics.CardFaceLayout` 和各区域 frame，不来自 PNG intrinsic pixel size。
- DEBUG 下 icon 加载失败显示红色边框和 `?`，不再静默画白色 fallback。卡面右上角 DEBUG status button 可打开当前卡 icon render summary。

本轮像素审计结果：

- render PNG assets: 57
- ok: 57
- failed: 0
- 重点 icon `ArrowDown`、`FishEgg`、`YoungFish`、`SchoolFish`、`DrawCard`、`Discard`、`FishHatch`、`ConsumeFish`、`Predator`、`AllPlayers`、`Wave`、`FishLengthSmall` / `Medium` / `Large`、`Sun` / `Dusk` / `Night`、`BlueCoral` / `PurpleCoral` / `GreenCoral` / `AnyCoral`、`PlayFishBottomRow` 都通过非白块 / 非透明 / bundle decode 检查。

代表卡 runtime summary：

- `base.main.057` Great White Shark：`FishEgg` / `ArrowDown` / `Predator` / `AllPlayers` 均指向可渲染 PNG；Wave、FishLengthLarge、fish image、flavor text 都可用。
- `base.main.056` Great Northern Tilefish：`FishHatch` token 可渲染；If Activated strip 和 flavor text 可用。
- `sr.main.161` Great Barracuda：coral requirement、`BlueCoral`、`AllPlayers`、Wave、FishLengthLarge 均可渲染。

## Ability Layout / Badge Fidelity Pass

本轮修复的是 ability composition、brush blocks、expansion badge 和 starter corner，不是重新做 icon renderability。白块问题仍由上一节的 PNG render asset pipeline 解决。

Live renderer 中的 ability model 来自 `references/webpage_live/static/js/main.3f6711eb.js` 和 `main.f74b3868.css`：

- `A(text)` 按 raw ability text token 化。普通 token 渲染为 icon；连续 icon 会形成 `.icon-group`；只有 `[A] + [B]` 这类 plus group 才进入 `.ability-row` 横排。
- `F(card)` 为 ability panel 生成 block。普通 IF ACTIVATED / GAME END 是一个 `.ability` brush block；`IF ACTIVATED` 中包含 `also, if` 时拆成主 `.ability.squished` 和条件 `.ability.also-if` 两个 brush blocks，中间由 `.ability-container` gap 分隔。
- `.ability .ArrowDown` 使用更高 icon height 和负 margin 形成 vertical flow。
- `.ability .AllPlayers` 使用 `filter: drop-shadow(0 0 4px #404040)`，并在 block 底部绝对定位。
- S&R 牌在右下角显示 `.expansion-logo`，asset 为 `SRLogo`。
- Starter 牌的角标不是 `StarterIcon` 图片，而是 `.corner-overlay` CSS clipped gray triangles，左上和右下各一个。

Swift 当前映射：

- 新增 `CardAbilityPresentation` / `CardAbilityBlock` / `CardAbilityElement`，由 `GameBoardViewModel` 和 `CardLibraryViewModel` 在构造 `FishCardFaceViewState` 时生成。`FishCardFaceView` 只渲染 presentation model，不在 `body` 中重新 parse ability text。
- Great White Shark 的 `(all players) [FishEgg][ArrowDown][Predator] on each [AllPlayers]` 通过通用 icon-run 规则生成 `arrowFlow` group：`FishEgg`、`ArrowDown`、`Predator` 竖向连接；`on each` 保持文本元素；`AllPlayers` 使用 bottom placement 和 live drop-shadow style。没有按 `base.main.057` 写 special case。
- `sr.starter.212` Atlantic Barracudina 的 `also, if [GreenCoral][GreenCoral][GreenCoral] in this dive site: [SchoolFeederMove]` 被拆成两个 brush blocks；第二个 block 是 `alsoIf` layout，三枚 `GreenCoral` 形成 horizontal coral group。
- IF ACTIVATED / GAME END / also-if block 的 background 都使用 live trigger strip asset，不再用纯色 `Rectangle` 作为正常路径。DEBUG 下只有 asset 缺失时才显示红色 outline fallback。
- `CardFaceIconAssetView` 增加 `CardAbilityIconStyle.allPlayersShadow`，只影响 `AllPlayers`，不改变普通 icon。
- `FishCardFaceViewState.expansionBadgeIcon` 对 `sr.*` 牌返回 `SRLogo`；base 牌不显示 S&R badge。
- `FishCardFaceViewState.hasStarterCornerDecorations` 对 `.starter.` card id 为 true；SwiftUI 用 clipped gray vector triangles 还原 live CSS corner overlay。`StarterIcon` 仍作为搜索 / filter live asset 保留并通过 renderability audit，但不用于牌面 corner。
- DEBUG card face status 面板扩展 ability layout / badge 信息：ability block count、block type、background asset、token placement、S&R logo、starter corner、AllPlayers shadow、trigger brush mode 和 also-if block count。

Focused tests 覆盖：

- `FishCardAbilityLayoutTests`
- `CardExpansionBadgeTests`
- `StarterCardCornerTests`
- 既有 `FishCardRenderingFidelityTests` 和 `FishCardIconRenderabilityTests`

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

- `PlayFishTopRow` 和 `PlayFishAny` 是已建模 logical token，但当前 215 张真实卡没有使用它们；如果未来数据出现且 live asset 仍无独立素材，会进入 missing report。
- 未知 ability token 会显示 `?` fallback，并以原 token 名进入 `MissingCardAsset`。
- 如果某个 live asset 后续缺失，Swift 会显示最小 fallback text，但该缺失会进入 `missingAssets`，不能被当作完成状态。

Pass 1.5 对 215 张真实卡做了 source-id / static icon / ability token 审计：

- cards: 215
- ability token references: 554
- unique token names: 33
- missing asset / fallback count: 0

Pass 2 对 215 张真实卡做了 ability / cost / zone / tag / points / length token 可渲染资源审计：

- cards: 215
- unique ability token names: 33
- missing asset / fallback count: 0
- live icon PNG derivative count: 57
- renderability failures: 0

## Great White Shark

Great White Shark 是 QA 样例，不是 special case。它已从旧近似渲染提升到 live ability presentation mapping：

- real JSON 中保持 `base.main.057`，`visualAssetName` 仍为 `null`，不修改 card JSON。
- Swift 通过 canonical card id 推导 source id 57，fish image 解析到 live `57.*.webp`。
- ability token `[FishEgg][ArrowDown][Predator][AllPlayers]` 全部解析为 live-derived PNG render asset。
- ability layout 不再是 flat horizontal row：`FishEgg` / `ArrowDown` / `Predator` 进入 `arrowFlow` icon group，`AllPlayers` 进入 bottom placement 并带 live drop-shadow style。
- length 600 cm 映射到 `FishLengthLarge`。
- cost 使用 `YoungFish` 和 web `ConsumeFish` mapping。
- trigger title 使用 `WHEN PLAYED` 英文牌面文案；background / font 全部走 resolver view state。
- flavor text 使用 live description: `Known by scientists as simply the “white shark,” this famous predator is, itself, occasionally preyed upon by orca whales.`

## Representative Cards

Pass 2 固定审计这些代表卡：

- `base.main.057` Great White Shark：sourceId 57 fish image、young + consume cost、Sun / Dusk / Night zones、Wave points、FishLengthLarge、WHEN PLAYED token sequence、English flavor text。
- `base.main.056` Great Northern Tilefish：sourceId 56 fish image、draw + egg cost、Sun / Dusk zones、green band、IF ACTIVATED trigger strip brush block、FishHatch token pair、English flavor text。
- `sr.main.161` Great Barracuda：sourceId 161 fish image、draw + consume + coral requirement icons、Sun zone、Wave points、FishLengthLarge、S&R expansion badge、BlueCoral / AllPlayers token sequence、English flavor text。
- `sr.starter.212` Atlantic Barracudina：S&R starter badge / corner、IF ACTIVATED `also, if` split brush blocks、GreenCoral horizontal group、SchoolFeederMove bonus token。

## QA Preview

不需要靠随机发牌检查代表卡。DEBUG build 中打开：

1. Lobby。
2. `牌库`。
3. 切换到 `所有牌`。
4. 使用顶部 DEBUG 搜索框按 English name、canonical card id、sourceId、trigger title 或 token 搜索。

可稳定搜索：

- `Great White Shark` / `base.main.057` / `57`
- `If Activated`
- `Game End`
- `AnyCoral` / `BlueCoral` / `GreenCoral` / `PurpleCoral`
- `FishLengthSmall` / `FishLengthMedium` / `FishLengthLarge`

视觉目标是“明显像网页”，不是像素级完成。

## Current Gap to Live Renderer

Pass 2 后仍有这些差距：

- exact cqw positioning、line-height、font weight 和 text wrapping 尚未逐项像素对齐。
- ability text 内容来自本地 JSON 的 English / raw source；ability block / icon-run / also-if / badge / corner 已按 live CSS/JS model 分区，但 inline wrapping 仍不是完整 HTML renderer。
- fish silhouette 的 opacity、blend mode 和裁切仍需截图对照。
- trigger strip 和 ability panel 的像素级 padding、negative margin、absolute placement 仍需后续 screenshot pass 精调。
- `PlayFishTopRow` / `PlayFishAny` 仍需确认是组合图标、逻辑 token、旧 token 名，还是 live renderer 无独立素材。
- Swift renderer 仍不是 HTML renderer；不会用 `WKWebView` 渲染每张卡。

## Ability Status

本轮不修改 card JSON、Ability Engine、规则、final scoring 或 deterministic/random 逻辑。

保持：

- Ability Engine v2 Core complete。
- 215 mapped / 0 unsupported。
- GAME END remaining unsupported 0。

## Remaining Fidelity Work

后续建议：

1. 用 live card screenshot 对 Great White Shark、If Activated、Game End 三类卡做像素级坐标表。
2. 把 title、scientific name、points、length、ability text 的 font size / line-height / wrapping 收敛到 live CSS。
3. 对 fish silhouette 的 frame、opacity、blend 和 clipping 做截图回归。
4. 明确 `PlayFishTopRow` / `PlayFishAny` 是网页无独立素材、复合图标、还是旧 token 名称误差。
5. 给 `MissingCardAsset` 做 debug report UI 或开发期导出脚本。
