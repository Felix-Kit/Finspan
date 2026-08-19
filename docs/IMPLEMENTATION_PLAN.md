# Finspan Implementation Plan

当前项目已经完成本地权威基础循环，并进入 Sharks & Reefs 部分接入、GAME END 扫尾和 UI 细化阶段。后续工作仍应保持规则引擎、房间服务和 SwiftUI 展示层分离。

## 架构原则

- UI 只能表达玩家意图并发送 `PlayerCommand`。
- `LocalAuthoritativeRoomService` 仍是当前本地权威服务，用来模拟未来服务器权威房间。
- 权威流程保持为：UI → `PlayerCommand` → RoomService → `GameEngine` → `GameEvent` → `GameState`。
- UI 不直接修改 `GameState`。
- `GameEngine` 负责合法性校验并产出事件草稿。
- `GameState` 只能通过应用 `GameEvent` 前进。
- deterministic setup / `randomSeed` 不能破坏。
- 随机性仍由 room service 控制，不能在 `GameEngine`、reducer 或 SwiftUI 中引入未受控随机。
- rule logic 不写进 SwiftUI；SwiftUI 只做状态展示、临时选择和命令构造。
- `baseGame` 是正常 Lobby runtime；`sample` factory path 只保留给测试和显式开发 fixture。

## 当前已完成

### 1. 基础架构

- Local room flow 已使用 `LocalAuthoritativeRoomService`。
- Command / Event / Reducer 架构已落地。
- `GameConfig.enabledExpansions` 已接入。
- 规则、房间服务、SwiftUI 基本边界已建立。

### 2. Deterministic Setup

- 本地权威 setup 已可通过 seed 和 catalog 构造。
- `randomSeed` 与事件序列仍由 room service 控制。
- sample 数据和 base game 数据已经通过 catalog mode 分离。

### 3. Base Game and Sharks & Reefs Core

- Sharks & Reefs 已部分接入。
- base + S&R 合并牌库已接入。
- `OceanState.coralReefs` 已接入。
- coral reef、coral requirement、coral reward 和 coral 计分都已建模。
- Twilight printed coral reward 已按当前 dive site 固定支付来源：blue=egg、purple=young、green=hand card，coral 只加到当前 dive site 对应 reef。
- S&R 相关 gainCoral / scatterSchool / consumeFishFromHand / playFishForFree / GAME END coral executable abilities 已接入。

### 4. Minimal `playFish`

- `PlayerCommand.playFish` 已接入。
- 出牌目标、支付和覆盖更短鱼等核心校验在规则层处理。
- 已支持弃牌支付、资源支付、`coverShorterFish` cost。
- 覆盖鱼会保留为 `consumedFish`，并与可见鱼规则区分。

### 5. Minimal `dive`

- `PlayerCommand.dive` 已接入。
- printed dive site bonuses 已按步骤解析。
- `DiveResolutionQueue` 已负责顺序解析，不会一次性生成所有选择。

### 6. Pending Choice 和奖励解析

- pending choice 架构已落地。
- 已支持 `placeEgg` / `hatchEgg` / `moveYoungOrSchool`。
- 已支持 school 自动形成。
- reward pool UI 已用于当前奖励可选项和目标选择。

### 7. Week Flow 和 Final Scoring

- End of Week / Week Flow 已接入。
- Side A 周目标最小计分已接入。
- Final scoring 已接入。
- 最终结算 UI 已接入。

### 8. GAME END 阶段

- 第 4 周结束后进入 `GamePhase.endGamePending`。
- `activateGameEndAbility` / `finishGameEndAbilities` 已接入。
- GAME END ability discovery 基于 visible fish 动态扫描。
- `activatedGameEndAbilitySourceIds` 用于防止重复发动。
- resolve / skip 都会标记 source handled。
- `finishGameEndAbilities` 后进入 final scoring。

### 9. GAME END ability sweep

- 39 条 GAME END abilities 中已实现 39 条。
- scoring-only 10 条已实现。
- executable 29 条已实现。
- GAME END remaining unsupported: 0。
- Pass 2F 后整体 ability coverage 为 215 mapped / 0 unsupported。
- S&R `also, if [ColorCoral]x3 in this dive site: ...` 指定颜色珊瑚条件额外收益已接入。

### 10. Catalog Mode 和 Base Game JSON Catalog

- `GameDataMode` / catalog mode 已接入 lobby 和 room service。
- `SampleCardCatalog` 保留用于测试 / 显式开发 fixture，不进入正常 Lobby。
- `BaseGameCardCatalog` 已从本地 JSON 加载 base game card data。
- base main fish 125 张和 base starter fish 10 张已导入本地资源。

### 11. Card Assets Import 和最小牌面渲染

- finsearch 素材已作为开发期导入来源，不作为运行时远程依赖。
- 线上 `https://navarog.github.io/finsearch/` 的 HTML / JS / CSS / asset 是 card rendering source of truth。
- `references/webpage_live/` 已生成 live mirror 和 `reports/resource_diff.json`；`references/webpage/` 只作为旧缓存对照，不是绝对真相。
- 本地 `CardAssets` 已包含 live fish image、icon、background / band 和 font 素材；当前与 live 288 个 asset 文件名相比缺失 0 个。
- `CardRenderMetrics` 已用本地背景素材尺寸推导统一卡牌比例。
- `CardAssetResolver` / `CardSymbolAssetResolver` / `AbilityTokenAssetResolver` / `FishImageAssetResolver` / `CardTriggerStyleResolver` / `CardFontStyleResolver` 已接入。
- `FishCardFaceView` 已完成 Fidelity Pass 1：fish image 按 sourceId 映射，ability token 使用 SVG/icon，trigger strip、length、zone、tag 和 font 走 resolver。
- `FishCardFaceView` Fidelity Pass 1.5 已完成：修正 asset wiring correctness，trigger strip 限定在 ability panel 宽度内，cost / requirement icons、zone icons、`Wave` points icon、`FishLengthSmall` / `Medium` / `Large` 和 ability token sequence 均由 resolver-backed view state 驱动。
- `FishCardFaceView` Fidelity Pass 2 已完成当前结构补齐：live SVG icon 已生成同名 PNG 派生资源，icon resolver 优先使用可渲染 PNG；SwiftUI 牌面不再把 loose SVG resource 当成主要显示路径。
- Fish Card Icon Vector / Renderability Pipeline Fix 已完成：SVG 仍是 source of truth，iOS runtime 使用 `sips` 生成的透明 high-res PNG render asset。旧白块根因是 Quick Look thumbnail 派生 PNG 带不透明白底，而不是 resolver 找不到文件。
- `tools/scripts/audit_card_icon_renderability.py` 已接入，验证 57 / 57 icon PNG 可解码、非纯白、非全透明、无白底，并保持 SVG viewBox aspect ratio。`CardIconRenderabilityAnalyzer` 在 Swift 测试和 DEBUG 面板中验证 bundle runtime decode。
- `FishCardFaceView` 现在通过统一 `CardFaceIconAssetView` 渲染 cost / requirement、zone、Wave、FishLength、ability token、tag / coral icon；显示尺寸由 live-inspired `CardRenderMetrics` frame 控制，不由 PNG intrinsic size 控制。
- DEBUG 牌库卡面右上角可打开 icon / layout render status 面板，用于定位当前卡的 failed icon、missing asset、fish image、flavor text、render asset type、ability block count、token placement、S&R badge、starter corner、AllPlayers shadow 和 also-if block count。
- card face 内 name、scientific name、ability text、trigger title 和 flavor text 使用 English / raw source；外层中文 UI 继续保留。
- 215 张卡的 live description 已作为 `Finspan/Resources/CardAssets/card_face_descriptions.json` 渲染 metadata 接入，不修改 runtime card JSON。
- FishCardFaceView Ability Layout + Badge Fidelity Pass 已完成：`CardAbilityPresentation` 在 view-state 构造阶段生成，SwiftUI 不在 `body` 中 parse ability text；ability token 不再统一 HStack，Great White Shark 使用 arrow-flow icon group，IF ACTIVATED `also, if` 拆成多个 brush blocks，AllPlayers 使用 live drop-shadow style。
- FishCardFaceView Live DOM Measurement + Ability Brush Correctness Pass 已完成：`tools/scripts/measure_live_card_dom.mjs` 用 Playwright / Chromium 真实渲染 `references/webpage_live/index.html`，生成 `tools/generated/card_rendering/live_measurements.json` 和 `docs/CARD_RENDERING_LIVE_MEASUREMENTS.md`。
- `CardAbilityLayoutMetrics` 已从 live DOM measurement 更新：ability container left 71.883cqw、top 0.266cqw、width 27.851cqw、height 65.218cqw、right gap 0.266cqw；also-if gap 1.986cqw。
- IF ACTIVATED / GAME END / also-if brush 已确认使用 CSS `background-image`，computed `background-size: cover`、`background-position: 0% 0%`、默认 `background-repeat: repeat`、无 rotation；SwiftUI 已改为 top-leading cover/crop，不再使用 cap-inset stretch 或纯色正常 fallback。
- Inline Ability Interaction audit 已更新为多维分类：`tools/scripts/audit_inline_ability_interaction.py` 对 215 张真实卡输出 entry surface、continuation surface、commit reversibility、source visibility、overlay/fallback 和 can-start-inline 字段，并生成 `docs/INLINE_ABILITY_INTERACTION_AUDIT.md` 与 `tools/generated/card_rendering/inline_ability_interaction_audit.json`。
- Legacy A/B/C/D 统计仍保留：A inline candidates 73、B needs picker/overlay 51、C irreversible/no undo 91、D not enough metadata 0；但 B 不再表示不能 inline，C 也不再表示不能 inline。
- 新口径确认：`recoverFromDiscardOrDraw` 可从 card icon 进入并继续到 discard overlay / direct draw；`consumeFishFromHand` 可从 card icon 进入并继续到 hand picker + board target；`playFishForFree` / `playFishFromHand` 可从 card icon 进入 hand picker + staged playFish flow；`drawFish` 可 direct commit 但 no committed undo；GAME END 可通过 gameEnd dock / card icon；AllPlayers source player 用 card icon，target players 用 incoming reward dock。
- 当前暂停 card inline 作为主交互；`BottomRewardDock` 是 pending reward、ability reward、dive / zone reward、GAME END candidate、AllPlayers 外部收益和复杂 overlay / picker continuation 的信息入口。普通 staged `playFish` 的纯 confirm / cancel 由 `FloatingActionPairView` 承载。
- 右侧 reward / pending / playFish confirm 面板已从主棋盘 layout 移除；复杂 fallback 由 bottom dock 拉起 overlay / sheet / picker / debug helper，不再通过右侧常驻栏占位。
- S&R expansion badge 已接入：`sr.*` 牌显示右下角 `SRLogo`，base 牌不显示。
- Starter corner 已接入：`.starter.` 牌显示左上 / 右下 clipped gray corner overlay；这是 live CSS `.corner-overlay` 的 SwiftUI vector 还原，不使用 `StarterIcon` 作为牌面角标。
- Great White Shark、Great Northern Tilefish、Great Barracuda、Atlantic Barracudina 仅作为 QA 样例，不写 special case；代表卡的 token sequence、brush block、also-if conditional、badge/corner、cost / requirement、zone、length、Wave、fish image 和 flavor text 都通过通用 resolver / view-state mapping 生效。
- DEBUG 牌库 QA 搜索已接入：Lobby → 牌库 → 所有牌，可按 English name、canonical card id、sourceId、trigger 或 token 稳定预览代表卡。
- Pass 2 全量 215 张真实卡 ability / cost / zone / tag / points / length token 审计 missing asset / fallback count 为 0。
- 旧 Swift renderer 仍只作为现状对照；后续不应基于旧近似布局零散补丁，而应按 live finsearch CSS/JS/asset → Swift view state → rendering sections 推进。
- 手牌、弃牌堆和 ocean slot 已使用同一鱼牌牌面组件 / 比例。

### 12. Major GameBoard HUD Polish

- 顶部 HUD、玩家头像、当前行动摘要、右上角四个纯图标周目标入口和全 4 周 scoreboard 已接入。
- 右侧行动确认区已从主棋盘 layout 移除。
- `BottomRewardDock` 已接入底部 overlay：空闲时 hidden，有 reward / source / summary / warning / fallback 内容时 compact，点击可 expanded；承载 reward token list、pending source summary、GAME END candidate、AllPlayers external reward 和 overlay / picker 入口。纯 `playFish` confirm、`→` 和 `←` 不再作为 control-only dock 出现。
- UI Polish Pass 1A 已接入 `GameBoardAnimation`，统一 hand selection、drag return、dock、token、overlay 和 opponent board perspective 的 quick / standard / slow 动画参数。
- 手牌选中 / 取消现在只基于稳定 `cardId` 做轻量上浮、放大、阴影和 zIndex 变化；非法点击或非法 drop 使用短促 nudge，不触发整排手牌重排。
- 拖拽出牌保持浮起感；合法 drop target 使用轻量 scale / glow / border 高亮；拖拽取消平滑回到手牌区，`PlayerCommand.playFish` 提交时机不变。
- `BottomRewardDock` hidden / handleOnly / compact / expanded 切换使用底部滑入 + 淡入；dock token 出现 / 消失使用 scale + opacity，选中 token 轻量放大，高亮仍由稳定 token id 驱动。`FloatingActionPairView` 的 `→` / `←` controls 有独立 press feedback。
- `BottomDockOverlayRoute` / `BottomDockOverlayState` 已接入，用于由 bottom dock 统一拉起 discard pile selection、hand card picker、playFish staging、reef target picker、debug fallback 和 GAME END candidate helper。
- discard pile overlay、recover selection、hand picker、consumeFishFromHand picker、playFishForFree / playFishFromHand picker 已接入 dim fade + panel slide/fade；关闭 overlay 只清理未提交 staged selection，不影响已提交 `GameEvent`。
- `recoverFromDiscardOrDraw` 的 dock flow 已稳定：recover token 打开弃牌堆 recover selection overlay；Draw Instead 走现有 draw fallback；弃牌为空时 dock 直接显示 draw fallback。
- `consumeFishFromHand` 的 dock flow 已稳定为 hand picker first，再继续到 board consumer target；不在 dock 内塞复杂选择。
- `playFishForFree` / `playFishFromHand` 的 dock flow 已稳定为 hand picker -> staged `playFish`；free play 不要求支付，paid play 继续进入 payment selection，纯确认 / 取消由 `FloatingActionPairView` 承载。
- `drawFish` direct commit、GAME END candidate activation / finish、AllPlayers target-player external reward 继续由 dock 表达；提交后没有 committed undo。
- Compact Resource HUD 已瘦身为鱼卵、幼鱼、鱼群；珊瑚使用 live-derived CardAssets icon 显示在 twilight / reef 区域附近。
- 右侧资源统计大面板已从 right-side fallback 区抽离；right-side pending / reward / action / playFish confirm 面板不再占主布局。
- 新增 `GameTokenIconResolver` / `GameTokenIconView`，让非卡面 UI 复用 `CardSymbolAssetResolver` / live-derived PNG icon，不使用 SF Symbol、emoji、临时色块或纯文字作为 token 正常路径。
- Unified staged interaction presentation model 已新增，覆盖 hand card、source fish、dive site / zone、reef / board marker、pending effect node，以及 payment source、reward token、target、confirm、skip、fallback 等 step。
- Unified staged interaction presentation model 已扩展四维 taxonomy：`InlineEntrySurface`、`ContinuationSurface`、`CommitReversibility`、`SourceVisibility`。该模型仍是 presentation-only，不接 `GameEngine`，不修改 `GameState`，不改变 `PlayerCommand` 语义。
- 新增 `IncomingRewardDockState` / source summary / dock token / dock action，用于外部 pending reward 的 source 摘要；目标玩家看不到 source fish card 时，`BottomRewardDock` 承载 source player、source fish、trigger、reward icons、fallback reason 和 `->` / `<-` controls。
- `playFish` inline 设计方向已确定：cost / requirement icon 只显示进度，支付来源通过直接点击 board / hand / reef 上的合法资源来选择；reward / ability icon 才作为主动入口。
- `->` 表达 confirm / skip / fallback forward action；`<-` 只表达未提交 staged selection undo，不表达已提交事件 undo。
- 日志已改为折叠 / sheet 查看。
- 已支持强制结束当前对局返回主页。
- 已支持弃牌堆 normal 只读查看和 `recoverFromDiscardOrDraw` 选择模式。
- 手牌点击卡顿已完成一轮低风险定位和优化：卡面静态 view state 按 cardId 缓存，避免选牌时重复构造完整 `FishCardFaceViewState`。
- 查看对手 board 增加局部淡入 / 平移过渡；`BottomRewardDock`、pending、staged `playFish` 和 AllPlayers / GAME END 上下文保留。
- 本轮仍不恢复右侧常驻面板，不修改 `AbilityEngine` / `GameEngine` / card JSON。

### 13. Ability Registry

- `AbilityRegistry` / `AbilityResolver` 已落地。
- Fish A / Fish B / Fish C sample ability 已迁移到 registry / resolver。
- 当前 runtime JSON 中 215 张真实鱼牌能力已全部映射。
- Ability Engine v2 core bridge 已开始接入：`AbilityIR` / `EffectGraph` / `EffectNode` / `PendingEffectSet` 已用于描述现有 pending choice。
- Ability Engine v2 Cleanup Pass 1 已完成：`PendingEffectSet` 是 `GameBoardViewModel` pending action display 的 primary model；legacy `PendingChoice` 保留为 compatibility shell。
- Ability Engine v2 Cleanup Pass 2 已完成：`PendingEffectIntent` / `effectNodeId` 已进入 ViewModel action choice，simple resolve / skip / target selection 通过 adapter 映射回现有 `PendingChoiceResolution`。
- Ability Engine v2 Cleanup Pass 3A 已完成：`EffectNodeMetadata` 已扩展 target / payment / resource / reward token / staged selection metadata，reward pool token display 和复杂 staged prompt display 已开始从 v2 metadata 派生。
- Ability Engine v2 Cleanup Pass 3B 已完成：`resolveEffectNode` / `skipEffectNode` / `skipEffectExecution` command 已接入，安全的 simple effects 可原生进入 engine。
- Ability Engine v2 Cleanup Pass 4 已完成：scatter school、consume-from-hand、free-play / paid-play final payload、coral payment 和 draw reward token action 已迁到 native effect-node payload；legacy adapter 仍保留为 compatibility shell。
- Ability Engine v2 Cleanup Pass 5 已完成：move young / school source-target payload 和 compound reward-token action selection 已迁到 native effect-node payload；legacy adapter 边界进一步缩小。
- Ability Engine v2 Completion Audit 已完成：v2 Core 可以标记为 complete；legacy `PendingChoice` / `PendingChoiceResolvedEvent` / `resolvePendingChoice` 仍保留为 compatibility shell 和 saved-state fallback。
- GameBoardViewModel Pending UI Stabilization Pass 1 已完成：pending title / progress / action presentation 优先读取 `PendingEffectSet` / `EffectNodeMetadata`，legacy progress 只作为 compatibility fallback。
- v2 预留 trace / replay 字段，但本阶段不实现完整 replay、timeline 或 debug UI。

## 下一阶段计划

### P0 Ability Engine v2 Core complete / compatibility audit

- 已完成。保持 v2 Core complete 状态，不继续在本阶段扩展规则或删除 legacy compatibility shell。
- `PendingEffectSet` / `PendingEffectIntent` / `EffectNodeMetadata` / native effect-node commands 是新游戏 pending action 的默认路径。
- legacy `PendingChoice` adapter 保留到 saved-state migration 有明确方案后再清理。

### P1 `recoverFromDiscardOrDraw` discard-pile selection UI

- 已完成。弃牌堆详情支持 normal mode 和 recover selection mode。
- recover selection mode 可点击具体弃牌并通过 `resolveEffectNode` / `.selectedDiscardCard` 恢复。
- 玩家可主动选择 Draw Instead，通过 `resolveEffectNode` / `.none` 抽牌。
- 弃牌为空时仍 fallback draw deck。

### P2 GameBoardViewModel pending UI stabilization

- Pass 1 已完成：ViewModel pending 面板优先读取 current execution id、source player、target player、available / blocked / completed / skipped effects。
- Pass 1 已完成：compound / Blackmouth / GAME END / colored coral conditional 的基础 action summary 由 effect-node label 驱动，不再显示旧的 count-only v2 progress。
- 后续继续减少 target prompt、payment prompt、discard-selection prompt 对 legacy `PendingChoice.kind` / `expectedInput` 的依赖。
- 保持 UI 小步稳定，不做大规模卡牌 UI 重构。

### P3 FishCardFaceView Fidelity Pass 2 / Renderability / Layout

- Pass 1.5 asset wiring correctness 已完成。
- Pass 2 结构补齐已完成。
- Icon renderability pipeline fix 已完成：不再把 resolver success 当作可见性证明，新增 PNG 像素审计和 runtime bundle decode 测试。
- Ability layout / brush / badge / starter corner pass 已完成：live JS/CSS 的 icon-run、ability-row、also-if split block、AllPlayers drop-shadow、S&R logo 和 starter corner overlay 已进入 Swift presentation model。
- Live DOM measured ability brush correctness pass 已完成：right-side panel frame、brush cover/top-left background mode、also-if gap、ArrowDown overlap 和 AllPlayers bottom placement 已从真实 DOM / computed style 映射。
- AllPlayers container overlay regression pass 已完成：34 张含 `[AllPlayers]` 的牌统一把图标放在 ability container 底部，不再让图标参与 IF ACTIVATED / GAME END brush block 高度；Paraliparis 已加入 live DOM 代表卡。
- 能力 icon class 尺寸已对齐 live CSS，并保持 PNG / SVG 原始宽高比；plus-row 同步应用 live max-height / max-width，避免 DrawCard、Discard、Consume、UnSchoolFish 和 AnyCoral 等组合忽大忽小。
- Inline ability interaction 当前完成 refined taxonomy、dock presentation model 和 floating control surface，但本阶段暂停 card inline 作为主交互。`BottomRewardDock` 先承载 reward / pending 信息和复杂 continuation；纯 `playFish` confirm / cancel 由 `FloatingActionPairView` 承载。card source / ability icon group 只做辅助高亮。包含 `ArrowDown` 的能力按组合语义整体高亮，不把 `ArrowDown` 单独作为可点入口。
- Unified Board/Card Interaction Flow Design 已完成第一步：新增 `docs/UNIFIED_BOARD_CARD_INTERACTION_FLOW.md`、pure presentation model、四维 taxonomy、`IncomingRewardDockState` 和 `BottomRewardDockState`；当前不实现完整 card inline ability tap、完整 inline `playFish`、完整 inline dive reward 或 engine-level undo。
- 后续继续在真实设备 / Simulator 牌库对极长文案、五图标组合和 S&R 特殊 coral group 做截图级微调；本轮已完成 Great White Shark、If Activated、Game End、also-if、AllPlayers / Paraliparis 的结构级对照。
- 收敛 title、scientific name、points、length、ability text 的 font size / line-height / wrapping，以及 icon sub-pixel offset 的微调。
- 调整 fish image frame、opacity、blend、clipping。
- 继续保留 card face static view state cache，不在 SwiftUI `body` 内 parse ability text 或扫描 bundle。
- 保持 Ability Engine v2 Core complete、215 mapped / 0 unsupported、GAME END remaining unsupported 0。

### P4 当前 UI 修复

- 已完成第一轮 cleanup：去掉底部白色背景条，改用与棋盘融合的海洋渐变 / glass backdrop。
- 已完成第一轮 cleanup：手牌主体保持视觉居中；弃牌堆不再参与同一个 HStack 挤压手牌。
- 已完成第一轮 cleanup：弃牌堆空时完全隐藏且不占位；有牌时作为 trailing overlay 悬浮在手牌右侧，点击仍打开弃牌堆查看 / recover selection overlay。
- 已完成第一轮 cleanup：normal empty ocean slot 不显示 unknown fish card，只保留透明 / 柔和 tint hit target；forage fish 和真实鱼牌仍按各自 card face 渲染。
- 右侧行动玩家摘要已由 Compact Resource HUD 和 BottomRewardDock 替代；bottom dock fallback 的 overlay / sheet / picker 已完成第一轮动画 polish，后续继续细化尺寸和错误提示，而不是恢复右侧常驻栏。
- 右侧 reward / pending / playFish confirm 面板没有恢复；fallback 通过 dock-launched overlay / sheet / picker / debug helper 承载。
- 纯 `→` confirm / continue / skip 和 `←` staged cancel / undo 已从 BottomRewardDock 拆出到 `FloatingActionPairView`。两个方块按钮只在 staged / pending context 需要时出现，避开 home indicator 和手牌；没有 token / source / summary / warning / fallback 内容时不显示 dock。
- `BottomRewardDock` 后续只承载 reward token、pending/source summary、GAME END candidate、AllPlayers external reward 和 overlay / picker 入口；不要再把普通 `playFish` 确认做成底部悬浮 dock。
- 顶部行动摘要已 toast 化：重要事件短暂显示后自动淡出；完整日志仍通过日志 sheet 查看。
- FloatingActionPair 已新增 layout metrics，用 `bottomClearance`、`trailingClearance` 和 `handAvoidanceHeight` 避开 hand area、弃牌堆和 system home indicator；overlay / picker 打开时全局按钮隐藏，避免重复控制。
- Board Interaction Regression Pass 已补测试固定这些 presentation 边界：discard overlay 关闭只撤回未提交选择且不提交命令；hand picker / discard overlay 打开时不重复显示全局 FloatingActionPair；toast 展示 / 自动隐藏不改变完整日志或 `GameState`；viewing opponent 只改变 presentation，不发送 `PlayerCommand`，且不能在对手 board 上选择目标或支付来源。
- Ability Target Interaction Polish 已完成单一空间目标流的减步：`placeEgg` / `placeYoung` / `hatchEgg` / matching-fish egg 在只有一个明确 reward entry 时自动进入 board-target staging，直接高亮合法 slot；compound ability 仍停留在 effect choice。
- `BoardInteractionPromptViewState` 统一表达 choose reward / board target / source / hand / discard / payment 阶段，中性指引与 `errorMessage` 分离；skip / finish 的 FloatingActionPair 按钮显示明确文字，不再统一显示含糊的 `→`。
- board canvas 以同一 BoardLayout mapping 分层呈现 highlight、非交互 card face、slot hit target 和最上层 resource-token hit target；pending authoritative state 更新后清理过期 reward staging，资源 token 插入使用轻量动画。

### P5 BoardLayout 和真实背景板

- Pass 1 已完成：新增 `BoardLayout` / `BoardLayoutSlot` / `BoardNormalizedRect` / `BoardNormalizedPoint`，并提供 manual placeholder `Finspan/Resources/BoardLayout/placeholder_board_layout.json`。
- Pass 1 已完成：新增 `BoardLayoutMapper.boardImageRect(in:imageAspectRatio:)`、normalized rect / point mapping helper；board overlay 坐标统一从同一套 aspectFit transform 派生。
- Pass 1 已完成：DEBUG calibration overlay 可显示 slotRect / cardRect / hitRect / highlightRect 和 slot id，且不发送 `PlayerCommand`、不修改 `GameState`。
- 当前仍使用 placeholder board background；后续从 AI / Figma / SVG 标注真实 rect，校准 `BoardLayout.json`，再接入真实 board background image。
- 背景图带 slot 美术后，SwiftUI 只叠加透明 hit target、鱼牌、资源 token、coral、diver 和柔和 glow / tint highlight，不重复画实体 slot 外观，不使用硬边框高光。
- 本阶段不做 PDF board extraction、不做完整 BoardLayout、不做服务器 / Nautoma / S&R 新规则。

### P6 S&R 成就和周目标

- Weekly Achievement Board MVP 已完成第一步：Base / Sharks & Reefs board set、Side A / Side B、B 面前三周分池 tile、第四周固定 GAME END 说明格已建模。
- S&R B 面已修正为按周使用 Base + S&R 合并池；random / manual 都复用该池，仍由 setup seed 保证 deterministic 且禁止跨周选择。
- 主棋盘右上角使用四个横向小方块作为周目标入口；入口不显示完整标题，当前周 icon 放大并高亮。点击任意入口打开全 4 周 scoreboard，被点击周与当前周分别保留高亮语义。
- 鱼牌 board-resource token 已从左侧 size-class 区域移到中央 fish artwork / background region，可覆盖鱼图但避开 points、length、tag、名称、flavor 和右侧 ability 区。共享 normalized metrics 同时约束 9cqw 图标和 11cqw 透明 hit target，不越过 card / slot bounds；点击仍只构造 staged payment selection。
- Lobby 创建房间已接入 board set / side / selection mode。未启用 S&R 时默认 Base A；启用 S&R 时默认 S&R A，也可选择 Base board。
- B 面 random selection 由 setup seed deterministic 解析；manual selection 按 week pool 校验，不允许跨周池或跨 board set。
- scoreboard 每周一个 section，section 内为所有玩家的归一化横向 score bar；已结算周读取 frozen result，当前 / 未来周只在 presentation 层计算 projection。
- 游戏内周目标 HUD / scoreboard 使用 resolved weekly goal tile，并通过 `GameTokenIconResolver` 渲染周目标 token icon。
- 已接入计分：鱼卵 / 幼鱼、整排鱼、鱼群、珊瑚、弃牌堆、透光带鱼、被吞食鱼、小 / 中 / 大型鱼、捕食者、IF ACTIVATED 卡、每 2 / 3 枚鱼卵、五种不同 tag、printed points 高低区间、完成珊瑚礁奖励。
- B 面第 1-3 周 base score 最高者 +3，并列都加；A 面及第 4 周不加。冻结结果和 projection 都显示 base / +3 / total breakdown。
- 尚未接入：“上方有标记的鱼 / 上方没有标记的鱼”（无真实 marker state）和文案仍需复核的“幼鱼”tile；`audit_weekly_goal_scoring.py` 非严格模式报告这些剩余项。
- 后续继续人工校对 `docs/references/weekly_goals/` 中的实体参考图和中文文案。

### P7 多玩家 / 联机 / 产品化

- 点击对手头像查看 board 已完成：GameBoardViewModel presentation 层分离 `activePlayerId`、`localPlayerId` 和 `viewingPlayerId`，头像切换只改变展示，不发送规则命令、不修改 `GameState`。
- 对手 board 为只读展示；自己的 pending / staged `playFish` / GAME END / AllPlayers 上下文仍由 `BottomRewardDock` 承载。需要回到自己 board 选目标或支付来源时，dock 显示返回提示。
- AllPlayers 和 GAME END 的 dock source summary 可跳转到来源玩家 board，并在可定位时高亮来源鱼。
- 本地多人完整流程。
- 局域网联机。
- reconnect / 房间恢复。
- App icon / launch screen / debug menu。

### P8 Saved-state migration / legacy cleanup

- 为旧 active room / saved local room 中的 legacy pending-choice payload 制定迁移策略。
- 标记 move / reward-token / scatter / consume / play / coral payment 的 legacy staged progress fields 为 cleanup candidates，等待 saved-state migration 后删除。
- 继续保持既有规则结果和 deterministic command / event / reducer 流程。

### P9 v2.1 trace / replay / debug timeline

- 使用 v2 已预留的 `executionId`、`effectNodeId`、`sourcePlayerId`、`targetPlayerId` 和 `decisionIndex`。
- 增加 replay / trace 输出和 debug timeline。
- 不在 v2 core consolidation 阶段提前实现 full replay。

### Later 真实卡牌渲染继续 QA

- `FishCardFaceView` 视觉 QA。
- compact / normal / detail 可以后置，不要过早复杂化。
- empty slot / forage / real fish / unknown cardId 明确区分。

## 当前建议下一步

1. 继续 polish BottomRewardDock 的 overlay / sheet / picker 体验，重点是尺寸、手牌遮挡和错误提示。
2. 再稳定 GameBoardViewModel pending UI，继续减少 target / payment / discard-selection prompt fallback 分散逻辑。
3. 如需推进 inline ability interaction，先把 card icon 当作 shortcut / highlight，不作为主交互路径。
4. 之后修 UI bug：手牌居中、弃牌堆隐藏、empty slot 占位。
