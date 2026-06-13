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
- 本地 `CardAssets` 已包含 fish image、icon、background / band 素材。
- `CardRenderMetrics` 已用本地背景素材尺寸推导统一卡牌比例。
- `FishCardFaceView` 已提供最小近似牌面。
- 手牌、弃牌堆和 ocean slot 已使用同一鱼牌牌面组件 / 比例。

### 12. Major GameBoard HUD Polish

- 顶部 HUD、玩家头像、当前行动摘要、周目标四格、周目标详情面板已接入。
- 右侧行动确认区已接入。
- 日志已改为折叠 / sheet 查看。
- 已支持强制结束当前对局返回主页。
- 已支持弃牌堆只读查看。

### 13. Ability Registry

- `AbilityRegistry` / `AbilityResolver` 已落地。
- Fish A / Fish B / Fish C sample ability 已迁移到 registry / resolver。
- 当前 runtime JSON 中 215 张真实鱼牌能力已全部映射。
- Ability Engine v2 core bridge 已开始接入：`AbilityIR` / `EffectGraph` / `EffectNode` / `PendingEffectSet` 已用于描述现有 pending choice。
- v2 预留 trace / replay 字段，但本阶段不实现完整 replay、timeline 或 debug UI。

## 下一阶段计划

### P0 Ability Engine v2 Core consolidation

- 继续把 AllPlayers、compound effect pool、conditional bonus、Blackmouth source-site condition 和 GAME END executable abilities 收敛到统一 effect-node 模型。
- 将更多 engine pending resolution 入口迁移到 `PendingEffectSet.available`。
- 保留 legacy `PendingChoice` adapter，等 v2 choices 完全稳定后再清理 step-specific fields。

### P1 GameBoardViewModel pending UI stabilization

- 让 ViewModel 优先读取 current execution id、source player、target player、available / blocked / completed / skipped effects。
- 减少 ViewModel 对 ability type、step index 和特殊 pipeline 的判断。
- 保持 UI 小步稳定，不做大规模卡牌 UI 重构。

### P2 `recoverFromDiscardOrDraw`

- 弃牌堆只读详情升级为可选择模式。
- pending choice 进入弃牌选择模式。
- 弃牌为空时 fallback draw deck。

### P3 当前 UI 修复

- 去掉底部白色背景条。
- 手牌居中。
- 弃牌堆空时完全隐藏，有牌时悬浮在手牌右侧。
- empty slot 不显示 unknown fish。
- 右侧行动玩家摘要精简。
- 顶部行动摘要 toast 化。

### P4 BoardLayout 和真实背景板

- 从 AI / Figma 标注 SVG rect。
- 生成 `BoardLayout.json`。
- 背景图 aspectFit mapping。
- debug overlay。
- 后续逐步迁移 slot / coral reef / diver area。

### P5 S&R 成就和周目标

- S&R achievement tiles。
- Side A / Side B。
- Side B 前三周随机 tile。
- 最高分 +3。
- 第 4 周 GAME END 说明格。

### P6 多玩家 / 联机 / 产品化

- 点击对手头像查看 board。
- 本地多人完整流程。
- 局域网联机。
- reconnect / 房间恢复。
- App icon / launch screen / debug menu。

### P7 v2.1 trace / replay / debug timeline

- 使用 v2 已预留的 `executionId`、`effectNodeId`、`sourcePlayerId`、`targetPlayerId` 和 `decisionIndex`。
- 增加 replay / trace 输出和 debug timeline。
- 不在 v2 core consolidation 阶段提前实现 full replay。

### Later 真实卡牌渲染继续 QA

- `FishCardFaceView` 视觉 QA。
- compact / normal / detail 可以后置，不要过早复杂化。
- empty slot / forage / real fish / unknown cardId 明确区分。

## 当前建议下一步

1. 先推进 Ability Engine v2 Core consolidation。
2. 然后稳定 GameBoardViewModel pending UI。
3. 再推进 `recoverFromDiscardOrDraw` 与弃牌堆选择模式联动。
