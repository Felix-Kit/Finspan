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
- `sample` flow 和 `baseGame` flow 都要保留。

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
- `SampleCardCatalog` 保留用于 sample flow。
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
- card face 内 name、scientific name、ability text、trigger title 和 flavor text 使用 English / raw source；外层中文 UI 继续保留。
- 215 张卡的 live description 已作为 `Finspan/Resources/CardAssets/card_face_descriptions.json` 渲染 metadata 接入，不修改 runtime card JSON。
- Great White Shark、Great Northern Tilefish、Great Barracuda 仅作为 QA 样例，不写 special case；代表卡的 token sequence、cost / requirement、zone、length、Wave、fish image 和 flavor text 都通过通用 resolver / view-state mapping 生效。
- DEBUG 牌库 QA 搜索已接入：Lobby → 牌库 → 所有牌，可按 English name、canonical card id、sourceId、trigger 或 token 稳定预览代表卡。
- Pass 2 全量 215 张真实卡 ability / cost / zone / tag / points / length token 审计 missing asset / fallback count 为 0。
- 旧 Swift renderer 仍只作为现状对照；后续不应基于旧近似布局零散补丁，而应按 live finsearch CSS/JS/asset → Swift view state → rendering sections 推进。
- 手牌、弃牌堆和 ocean slot 已使用同一鱼牌牌面组件 / 比例。

### 12. Major GameBoard HUD Polish

- 顶部 HUD、玩家头像、当前行动摘要、周目标四格、周目标详情面板已接入。
- 右侧行动确认区已接入。
- 日志已改为折叠 / sheet 查看。
- 已支持强制结束当前对局返回主页。
- 已支持弃牌堆 normal 只读查看和 `recoverFromDiscardOrDraw` 选择模式。
- 手牌点击卡顿已完成一轮低风险定位和优化：卡面静态 view state 按 cardId 缓存，避免选牌时重复构造完整 `FishCardFaceViewState`。

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

### P3 FishCardFaceView Fidelity Pass 2

- Pass 1.5 asset wiring correctness 已完成，Pass 2 不再处理“资源已导入但没有显示”的基础问题。
- 用 live renderer screenshot 对 Great White Shark、If Activated、Game End 三类卡做像素级对照。
- 收敛 title、scientific name、points、length、ability text 的 font size / line-height / wrapping。
- 调整 fish image frame、opacity、blend、clipping。
- 继续保留 card face static view state cache，不在 SwiftUI `body` 内 parse ability text 或扫描 bundle。
- 保持 Ability Engine v2 Core complete、215 mapped / 0 unsupported、GAME END remaining unsupported 0。

### P4 当前 UI 修复

- 去掉底部白色背景条。
- 手牌居中。
- 弃牌堆空时完全隐藏，有牌时悬浮在手牌右侧。
- empty slot 不显示 unknown fish。
- 右侧行动玩家摘要精简。
- 顶部行动摘要 toast 化。

### P5 BoardLayout 和真实背景板

- 从 AI / Figma 标注 SVG rect。
- 生成 `BoardLayout.json`。
- 背景图 aspectFit mapping。
- debug overlay。
- 后续逐步迁移 slot / coral reef / diver area。

### P6 S&R 成就和周目标

- S&R achievement tiles。
- Side A / Side B。
- Side B 前三周随机 tile。
- 最高分 +3。
- 第 4 周 GAME END 说明格。

### P7 多玩家 / 联机 / 产品化

- 点击对手头像查看 board。
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

1. 先做 FishCardFaceView Fidelity Pass 2 的像素级 layout / font / spacing 修正。
2. 再稳定 GameBoardViewModel pending UI。
3. 之后修 UI bug：底部 dock、手牌居中、弃牌堆隐藏、empty slot 占位。
