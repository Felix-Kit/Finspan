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

- 39 条 GAME END abilities 中已实现 33 条。
- scoring-only 10 条已实现。
- executable 23 条已实现。
- 仍 unsupported / future work 6 条：
  - Honeycomb Scaly Dragonfish
  - Speckled Butterflyfish
  - Tripodfish
  - Blackmouth Angler
  - Sixgill Sawshark
  - Yokozuna Slickhead

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
- 真实 base game 全量能力尚未完全映射。

## 下一阶段计划

### P0 当前 UI 修复

- 去掉底部白色背景条。
- 手牌居中。
- 弃牌堆空时完全隐藏，有牌时悬浮在手牌右侧。
- empty slot 不显示 unknown fish。
- 右侧行动玩家摘要精简。
- 顶部行动摘要 toast 化。

### P1 GAME END sweep 复查

- 复查 33 条已实现 GAME END ability。
- 补代表性真实卡端到端测试。
- 确认 scoring-only / executable / unsupported 三种状态。
- 确认 GAME END 打出新鱼后动态扫描。

### P2 剩余 GAME END future work

- Honeycomb Scaly Dragonfish / Speckled Butterflyfish：move young / move school 类。
- Tripodfish / Blackmouth Angler / Sixgill Sawshark / Yokozuna Slickhead：复杂 mixed 类。

### P3 S&R 成就和周目标

- S&R achievement tiles。
- Side A / Side B。
- Side B 前三周随机 tile。
- 最高分 +3。
- 第 4 周 GAME END 说明格。

### P4 `recoverFromDiscardOrDraw`

- 弃牌堆只读详情升级为可选择模式。
- pending choice 进入弃牌选择模式。
- 弃牌为空时 fallback draw deck。

### P5 BoardLayout 和真实背景板

- 从 AI / Figma 标注 SVG rect。
- 生成 `BoardLayout.json`。
- 背景图 aspectFit mapping。
- debug overlay。
- 后续逐步迁移 slot / coral reef / diver area。

### P6 真实卡牌渲染继续 QA

- `FishCardFaceView` 视觉 QA。
- compact / normal / detail 可以后置，不要过早复杂化。
- empty slot / forage / real fish / unknown cardId 明确区分。

### P7 多玩家 / 联机 / 产品化

- 点击对手头像查看 board。
- 本地多人完整流程。
- 局域网联机。
- reconnect / 房间恢复。
- App icon / launch screen / debug menu。

## 当前建议下一步

1. 先修 UI bug：底部 dock、手牌居中、弃牌堆隐藏、empty slot 占位。
2. 然后复查 GAME END sweep 的已实现 / unsupported 列表并补代表性测试。
3. 再推进 `recoverFromDiscardOrDraw` 与弃牌堆选择模式联动。
