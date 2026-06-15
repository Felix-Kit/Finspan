# 当前状态

本文档反映当前 `main` 分支的真实进度。项目已经从基础可玩循环进入 Sharks & Reefs 部分接入、GAME END 扫尾和 UI 细化阶段。

## 已完成

### 核心规则循环

- `playFish` / `dive` / pending choice 已接入 Command / Event / Reducer 流程。
- `DiveResolutionQueue` 已落地，潜水奖励按队列逐步解析。
- 已支持 `placeEgg` / `hatchEgg` / `moveYoungOrSchool`。
- 已支持 school 自动形成：同一槽位 3 个 young 且无 school 时形成 1 个 school。
- End of Week / Week Flow 已接入。
- Side A 周目标最小计分已接入。
- 最终计分与最终结算界面已接入。
- 已支持 `consumedFish`，鱼可以覆盖更短鱼。
- 已支持 `coverShorterFish` cost。
- 已支持 reward pool，用于显示和选择当前 pending choice / 奖励解析可用收益。

### Sharks & Reefs 基础接入

- Lobby 已可勾选 Sharks & Reefs。
- `GameConfig.enabledExpansions` 已接入。
- base + S&R 合并牌库已接入。
- S&R main / starter JSON 已进入 runtime `Finspan/Resources/Cards/`。
- S&R 单独 catalog 和 base+S&R catalog 数量已验证。

### Coral reef 系统

- `OceanState.coralReefs` 已接入。
- 启用 S&R 时每位玩家初始化 blue / purple / green reef。
- `coralCount` / `maxCoral` / `completionBonus` 已建模。
- GameBoard 已显示 coral reef。
- Twilight printed bonus 后的 coral reward 已按当前 dive site 固定支付来源：blue 支付 egg 获得 blue coral，purple 支付 young 获得 purple coral，green 弃 1 张手牌获得 green coral。
- coral 不超过 `maxCoral`。

### S&R 出牌规则

- reef fish 的 coral requirement 已从 `coralRequirementOrCost` 转换为 `Requirement`。
- coral requirement 校验已接入 `playFish` validation。
- coral requirement preview / UI 提示已接入。

### S&R 能力

- `gainCoral` ability 已接入。
- `scatterSchool` / 打散鱼群已接入。
- `consume fish from hand` 已接入。
- `play fish for free` 已接入。
- Blue Lanternfish draw 4 已接入。
- GAME END S&R coral executable abilities 已接入。

### GAME END 阶段

- 第 4 周结束后进入 `GamePhase.endGamePending`。
- `activateGameEndAbility` / `finishGameEndAbilities` 已接入。
- GAME END ability discovery 基于 visible fish 动态扫描。
- `activatedGameEndAbilitySourceIds` 已用于防止重复发动。
- resolve / skip 都会标记 source handled。
- `finishGameEndAbilities` 后进入 final scoring。
- GAME END phase / ViewModel / final scoring focused tests 曾通过。

### GAME END ability sweep

- 39 条 GAME END abilities 中已实现 39 条。
- scoring-only 10 条已实现。
- executable 29 条已实现。
- GAME END remaining unsupported: 0。
- Pass 2F 后整体 ability coverage 为 215 mapped / 0 unsupported。
- S&R `also, if [ColorCoral]x3 in this dive site: ...` 指定颜色珊瑚条件额外收益已接入。

### S&R / GAME END scoring

- coral 每个 1 分。
- complete reef bonus 使用 `CoralReefState.completionBonus`。
- GAME END scoring-only abilities 计入 `ScoreCategory.gameEnd`。
- GAME END points 不计入 printed fish points。
- 未启用 S&R 时 final score UI 不显示 coral / completeReefBonus。

### 交互与棋盘 UI

- 已支持拖拽出牌。
- 已支持统一支付 UI，弃牌支付和资源支付都在同一出牌确认流程中汇总。
- 已支持右侧行动确认区，用于出牌、pending choice、奖励选择和移动资源确认。
- 顶部 HUD 已重做，包含玩家头像、当前行动摘要、设置入口和日志入口。
- 周目标四格和详情面板已接入。
- 日志已改为折叠 / 弹出查看。
- 已支持强制结束当前对局并返回主页。
- 已支持弃牌堆 normal 只读查看，以及 `recoverFromDiscardOrDraw` pending effect 下的弃牌选择模式。
- `recoverFromDiscardOrDraw` 弃牌选择模式已接入 `PendingEffectSet` / `PendingEffectIntent`：可选择具体弃牌恢复，也可主动选择改为抽牌；弃牌为空时仍 fallback draw deck。
- 手牌点击性能审计已完成一轮低风险优化：`GameBoardViewModel` 缓存按 cardId 生成的静态 `FishCardFaceViewState`，减少选牌时重复 catalog lookup / ability token parse；选牌仍只改变 UI selection，不修改 `GameState`。
- 底部手牌 / 弃牌堆 dock 已在优化中。

### 数据与卡牌

- `BaseGameCardCatalog` 已支持从本地 JSON 加载。
- `Finspan/Resources/Cards/base_main_fish_cards.json` 已包含 base main fish 125 张。
- `Finspan/Resources/Cards/base_starter_fish_cards.json` 已包含 base starter fish 10 张。
- 已支持 `baseGame` / `sample` 数据源切换。
- `SampleCardCatalog` 仍保留用于本地开发和 sample flow。

### 能力系统

- `AbilityRegistry` / `AbilityResolver` 已落地。
- Fish A / Fish B / Fish C sample ability 已迁移到 registry / resolver 模型。
- 当前 runtime JSON 中 215 张真实鱼牌能力已全部映射。
- Ability Engine v2 core bridge 已开始接入：`PendingChoice` 可通过 `v2PendingEffectSet` 暴露统一的 execution / effect-node 状态。
- Ability Engine v2 Cleanup Pass 1 已完成：`GameBoardViewModel` 的 pending action 按钮和通用进度摘要优先读取 `PendingEffectSet.available` / completed / skipped。
- Ability Engine v2 Cleanup Pass 2 已完成：v2 action button / simple target selection 现在携带 `PendingEffectIntent` 和 `effectNodeId`，再通过 adapter 映射到现有 `PendingChoiceResolution`。
- Ability Engine v2 Cleanup Pass 3A 已完成：`EffectNodeMetadata` 已能描述 reward token、target requirement、payment requirement、resource requirement 和复杂 staged selection prompt；reward pool / prompt display 优先读取 v2 metadata，再 fallback 到 legacy。
- Ability Engine v2 Cleanup Pass 3B 已完成：新增 `resolveEffectNode` / `skipEffectNode` / `skipEffectExecution` command，安全的简单 resolve / skip 现在可原生进入 `GameEngine`，复杂 staged payload 继续 fallback 到 legacy `PendingChoiceResolution`。
- Ability Engine v2 Cleanup Pass 4 已完成：scatter school、consume-from-hand、free-play / paid-play final payload、coral payment 和 draw reward token action 已能通过 native effect-node payload 进入 engine；legacy `PendingChoiceResolution` 仍作为 reducer/event compatibility shell。
- Ability Engine v2 Cleanup Pass 5 已完成：move young / school source-target flow 已迁到 native `EffectMoveResourcePayload`，compound reward-token action selection 已迁到 native `EffectRewardTokenPayload` intent。
- Ability Engine v2 Completion Audit 已完成：v2 Core 可以标记为 complete。新游戏 pending actions 默认通过 `PendingEffectSet` / `PendingEffectIntent` / `EffectNodeMetadata` / native effect-node command 进入 engine。
- GameBoardViewModel Pending UI Stabilization Pass 1 已完成：pending 面板标题、可选 / 已完成 / 已跳过 / 暂不可用摘要和 action buttons 优先读取 `PendingEffectSet` / `EffectNodeMetadata`，compound legacy progress 只作为旧状态 fallback。
- legacy `PendingChoice` 仍保留为 compatibility shell，继续承载 saved-state compatibility、`PendingChoiceResolvedEvent` reducer shell、follow-up target / payment / discard-selection choices 和现有 `PendingChoiceResolution` fallback。
- v2 Core complete 不代表删除 legacy：saved-state migration、legacy field cleanup、native effect-node event 替换和 v2.1 replay / debug timeline 仍后置。
- 未来 runtime JSON 新增或变更的未知能力仍应保持可表示、可跳过，不应导致崩溃。

### 卡牌素材与牌面渲染

- 已添加 finsearch 卡牌素材离线下载脚本：`tools/scripts/download_finsearch_assets.py`。
- 本地素材已导入 `Finspan/Resources/CardAssets/`。
- 本轮已直接审计线上 `https://navarog.github.io/finsearch/`，确认 card renderer source of truth 是 live HTML / JS / CSS / asset，而不是旧 Swift 近似实现。
- 已新增 `references/webpage_live/` live mirror，包含 HTML、`main.3f6711eb.js`、`main.f74b3868.css`、288 个 live asset、字体和资源差异报告。
- `references/webpage/` 只作为旧缓存对照；当前与 live 相比缺少字体、trigger strip、card background 等 19 个资源。
- `Finspan/Resources/CardAssets/` 当前与 live asset 文件名相比缺失 0 个，已补入 `Panforte Pro`、`Dolce`、`Lexus Roman Optical` 字体文件。
- `tools/generated/cards/` 已包含拆分后的 card JSON 生成结果。
- `tools/generated/assets/asset_download_summary.json` 已记录素材下载结果和本地资源计数。
- `CardRenderMetrics` 已落地，使用本地 finsearch 背景素材推导出的统一卡牌比例。
- `CardAssetResolver` / `CardSymbolAssetResolver` / `AbilityTokenAssetResolver` / `FishImageAssetResolver` / `CardTriggerStyleResolver` / `CardFontStyleResolver` 已接入，用于把 web renderer mapping 转成可缓存的 Swift view state。
- `FishCardFaceView` 已完成 Fidelity Pass 1：fish image 按 sourceId 映射，ability token 使用 SVG/icon，ArrowDown、长度、光层、触发条和字体走 live asset resolver。
- `FishCardFaceView` Fidelity Pass 1.5 已完成，范围是 asset wiring correctness，不是像素级 Pass 2：trigger strip 宽度被限制在 ability panel 内，cost / requirement icons、zone icons、`Wave` points icon、`FishLengthSmall` / `Medium` / `Large` 和 ability token sequence 都走 resolver view state。
- `FishCardFaceView` Fidelity Pass 2 已完成当前一轮结构补齐：live SVG icon 生成同名 PNG 派生资源，icon resolver 优先返回可渲染 PNG，cost / zone / points / length / ability token 不再依赖 loose SVG 作为 SwiftUI image。
- Fish Card Icon Vector / Renderability Pipeline Fix 已完成：旧 Quick Look `.svg.png` 白底缩略图已由 `sips` 生成的透明高分辨率 PNG render asset 替换；SVG source 仍保留为 source of truth。
- 新增 `tools/scripts/render_card_icon_assets.py` 和 `tools/scripts/audit_card_icon_renderability.py`。当前审计结果为 57 / 57 icon PNG 可解码、非纯白、非全透明、无白底、aspect ratio 匹配 SVG viewBox。
- `FishCardFaceView` 的 cost / requirement、playable zone、Wave、FishLength、ability token、tag / coral icon 已统一走 `CardFaceIconAssetView`；显示尺寸来自 `CardRenderMetrics` / explicit frame，不来自 PNG intrinsic size。
- DEBUG card face 增加 icon render status 面板：在 Lobby → 牌库 → 所有牌中点击卡面右上角 `i` / `!` 可查看 card id、source id、icon count、failed icons、missing assets、fish image / flavor text 和 render asset type。
- 牌面底部英文 flavor text 已恢复：215 张卡的 live description 被抽取为 `Finspan/Resources/CardAssets/card_face_descriptions.json` 渲染 metadata，不修改 `Finspan/Resources/Cards/*.json`，S&R 仍优先使用自身 `rawSource.description`。
- 鱼牌牌面文案保持 English / raw source：name、scientific name、ability text、trigger title 和 flavor text 不使用中文牌面文案；App 外层中文 UI 不受影响。
- Great White Shark 是 QA 样例，不是 special case：`base.main.057` 映射到 `57.*.webp`，`FishEgg` / `ArrowDown` / `Predator` / `AllPlayers` 均解析到 live-derived PNG render asset，cost 显示 `YoungFish` / `ConsumeFish`，length 600 cm 映射到 `FishLengthLarge`。
- Great Northern Tilefish 和 Great Barracuda 也纳入 Pass 2 代表卡审计，覆盖 If Activated、S&R coral requirement / coral token、不同 zone 和 flavor text。
- DEBUG 牌库 QA 搜索已接入：Lobby → 牌库 → 所有牌，可按 English name、canonical card id、sourceId、trigger 或 token 稳定预览代表卡，不依赖随机发牌。
- Pass 2 全量 215 张真实卡 ability / cost / zone / tag / points / length token 审计结果：missing asset / fallback count 0。
- Icon renderability focused tests 覆盖 Great White Shark、Great Northern Tilefish、Great Barracuda 和全量 215 张真实卡；代表卡 renderability failures 为 0。
- 手牌、弃牌堆和 ocean slot 当前仍共用同一完整卡牌牌面。
- 当前牌面已完成 Pass 2 结构补齐，但仍不是完整 finsearch 像素级复刻。详见 `docs/CARD_RENDERING_FIDELITY.md`。

## 当前仍需修复 / 待做

### UI bug 修复

- 去掉底部白色背景条。
- 让手牌真正居中。
- 弃牌堆空时完全隐藏。
- empty slot 不显示 unknown fish card。
- 右侧行动玩家面板需要继续精简。
- 顶部行动摘要应改成自动消失的 toast。

### 规则与功能

- Ability Engine v2 saved-state migration / legacy cleanup 后置：当前不是正式发布阶段，legacy adapter 继续保持行为稳定，直到旧本地房间和旧 pending-choice payload 有明确迁移路径。
- GameBoardViewModel pending UI stabilization 后续：继续把 no-target prompt、follow-up target / payment / discard-selection choices 的显示逻辑收敛到 metadata fallback helper。
- S&R achievements。
- Side B weekly bonus +3。
- 真实 board 背景和 slot 对齐系统。
- BoardLayout / SVG marker / JSON layout pipeline。
- 点击对手头像查看对手 board。
- Nautoma 后置。
- 联机 / reconnect / 房间恢复后置。

## 当前建议下一步

1. 做 FishCardFaceView 后续像素级 layout pass：在 renderability pipeline 正确的基础上，用 live screenshot 做 font / spacing / fish silhouette 对照。
2. 继续做 GameBoardViewModel pending UI 小步稳定，重点是 target / payment / discard-selection prompt fallback。
3. 再修 UI bug：底部 dock、手牌居中、弃牌堆隐藏、empty slot 占位。
