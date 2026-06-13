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
- Twilight printed bonus 后可选择支付 egg / young / hand card 获得 coral。
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
- 已支持弃牌堆只读查看。
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
- legacy `PendingChoice` 仍保留为 compatibility shell，继续承载 saved-state compatibility、`PendingChoiceResolvedEvent` reducer shell、follow-up target / payment / discard-selection choices 和现有 `PendingChoiceResolution` fallback。
- v2 当前是 adapter / consolidation 层，不改变既有玩法结果，也不实现完整 replay / debug timeline。
- 未来 runtime JSON 新增或变更的未知能力仍应保持可表示、可跳过，不应导致崩溃。

### 卡牌素材与牌面渲染

- 已添加 finsearch 卡牌素材离线下载脚本：`tools/scripts/download_finsearch_assets.py`。
- 本地素材已导入 `Finspan/Resources/CardAssets/`。
- `tools/generated/cards/` 已包含拆分后的 card JSON 生成结果。
- `tools/generated/assets/asset_download_summary.json` 已记录素材下载结果和本地资源计数。
- `CardRenderMetrics` 已落地，使用本地 finsearch 背景素材推导出的统一卡牌比例。
- `FishCardFaceView` 已落地。
- 手牌、弃牌堆和 ocean slot 当前仍共用同一完整卡牌牌面。
- 当前牌面仍是近似渲染，不是完整 finsearch 复刻。

## 当前仍需修复 / 待做

### UI bug 修复

- 去掉底部白色背景条。
- 让手牌真正居中。
- 弃牌堆空时完全隐藏。
- empty slot 不显示 unknown fish card。
- 右侧行动玩家面板需要继续精简。
- 顶部行动摘要应改成自动消失的 toast。

### 规则与功能

- Ability Engine v2 cleanup：下一步进入 saved-state migration 和 legacy field cleanup 规划；legacy adapter 继续保持行为稳定，直到旧本地房间和旧 pending-choice payload 有明确迁移路径。
- GameBoardViewModel pending UI stabilization：继续减少 ViewModel 对具体 ability type / step order 的依赖。
- `recoverFromDiscardOrDraw` 与弃牌堆选择模式联动。
- S&R achievements。
- Side B weekly bonus +3。
- 真实 board 背景和 slot 对齐系统。
- BoardLayout / SVG marker / JSON layout pipeline。
- 点击对手头像查看对手 board。
- Nautoma 后置。
- 联机 / reconnect / 房间恢复后置。

## 当前建议下一步

1. 先推进 Ability Engine v2 saved-state migration / legacy field cleanup 规划，同时继续保留 legacy adapter 作为回退。
2. 再推进 `recoverFromDiscardOrDraw` 与弃牌堆选择模式联动。
3. 之后修 UI bug：底部 dock、手牌居中、弃牌堆隐藏、empty slot 占位。
