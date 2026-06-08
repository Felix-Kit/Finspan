# Finspan UI and Real Data Enhancement Plan

当前项目已经完成本地权威基础循环，进入 UI 与真实数据增强阶段。后续工作应继续保持规则引擎、房间服务和 SwiftUI 展示层分离。

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

## 已完成阶段

### 1. 基础架构

- Local room flow 已使用 `LocalAuthoritativeRoomService`。
- Command / Event / Reducer 架构已落地。
- `GameConfig.enabledExpansions` 保留。
- 规则、房间服务、SwiftUI 基本边界已建立。

### 2. Deterministic Setup

- 本地权威 setup 已可通过 seed 和 catalog 构造。
- `randomSeed` 与事件序列仍由 room service 控制。
- sample 数据和 base game 数据已经通过 catalog mode 分离。

### 3. Minimal `playFish`

- `PlayerCommand.playFish` 已接入。
- 出牌目标、支付和覆盖更短鱼等核心校验在规则层处理。
- 已支持弃牌支付、资源支付、`coverShorterFish` cost。
- 覆盖鱼会保留为 `consumedFish`，并与可见鱼规则区分。

### 4. Minimal `dive`

- `PlayerCommand.dive` 已接入。
- printed dive site bonuses 已按步骤解析。
- `DiveResolutionQueue` 已负责顺序解析，不会一次性生成所有选择。

### 5. Pending Choice 和奖励解析

- pending choice 架构已落地。
- 已支持 `placeEgg` / `hatchEgg` / `moveYoungOrSchool`。
- 已支持 school 自动形成。
- reward pool UI 已用于当前奖励可选项和目标选择。

### 6. Week Flow 和 Final Scoring

- End of Week / Week Flow 已接入。
- Side A 周目标最小计分已接入。
- Final scoring 已接入。
- 最终结算 UI 已接入。

### 7. Catalog Mode 和 Base Game JSON Catalog

- `GameDataMode` / catalog mode 已接入 lobby 和 room service。
- `SampleCardCatalog` 保留用于 sample flow。
- `BaseGameCardCatalog` 已从本地 JSON 加载 base game card data。
- base main fish 125 张和 base starter fish 10 张已导入本地资源。

### 8. Card Assets Import 和最小牌面渲染

- finsearch 素材已作为开发期导入来源，不作为运行时远程依赖。
- 本地 `CardAssets` 已包含 fish image、icon、background / band 素材。
- `CardRenderMetrics` 已用本地背景素材尺寸推导统一卡牌比例。
- `FishCardFaceView` 已提供最小近似牌面。
- 手牌、弃牌堆和 ocean slot 已使用同一鱼牌牌面组件 / 比例。

### 9. Major GameBoard HUD Polish

- 顶部 HUD、玩家头像、当前行动摘要、周目标四格、周目标详情面板已接入。
- 右侧行动确认区已接入。
- 日志已改为折叠 / sheet 查看。
- 已支持强制结束当前对局返回主页。
- 已支持弃牌堆只读查看。

### 10. Ability Registry

- `AbilityRegistry` / `AbilityResolver` 已落地。
- Fish A / Fish B / Fish C sample ability 已迁移到 registry / resolver。
- 真实 base game 全量能力尚未映射。

## 下一阶段计划

### 1. 接入弃牌堆选择模式

目标：让 `recoverFromDiscardOrDraw` 可以使用弃牌堆面板完成选择。

- 当前弃牌堆详情主要是只读查看。
- 下一步应让 pending choice 进入弃牌堆选择模式。
- 选择弃牌后仍必须发送对应 `PlayerCommand`，由 `GameEngine` 校验并产出 `GameEvent`。
- 弃牌堆为空时保留从牌堆抽牌的 fallback。

### 2. 优化 `FishCardFaceView` 展示密度

目标：建立 compact / normal / detail 三种展示密度。

- compact：用于 ocean slot、小型预览和堆叠手牌。
- normal：用于当前手牌、弃牌堆列表和常规面板。
- detail：用于将来的卡牌详情、能力阅读和视觉 QA。
- 三种模式共享 `CardRenderMetrics` 和本地素材路径，不引入远程运行时依赖。

### 3. 真实能力映射优先级规划

目标：逐步接入真实鱼牌能力，而不是一次性写入所有能力。

- 先按已有能力效果类型归类，复用 `AbilityRegistry` / `AbilityResolver`。
- 优先映射可复用、低风险、已经有 pending choice 支撑的能力。
- 未支持能力继续显示“能力暂未接入”类型的可跳过状态。
- 不在 SwiftUI 中按 card id 写规则逻辑。

### 4. 多玩家 Board 查看

目标：点击对手头像查看对手 board。

- ViewModel 可计算查看对象和只读 board view state。
- 规则层不因查看对手 board 产生事件。
- 当前玩家行动和支付选择仍以 active player / local player 规则为准。

### 5. S&R 扩展预留

目标：保持 base game 稳定，同时为 Sharks & Reefs 后续模块留接口。

- 不把 S&R 规则混进 base game。
- 后续通过 `SharksAndReefsRuleModule`、扩展 `ResourceKind`、`Requirement`、`Cost`、`AbilityDefinition`、`ScoreCategory` 等接入。
- S&R 数据和素材导入应独立、可复现。

### 6. Nautoma 后置

目标：Nautoma 不作为普通玩家 board 的简单复制。

- 后续通过 `NautomaRuleModule` 接入自动行为和简化 solo 规则。
- 在 base game loop 稳定、真实能力映射更完整后再启动。

### 7. 联机 / 服务器后置

目标：未来把本地权威服务替换为服务器权威房间。

- 当前保持 `LocalAuthoritativeRoomService` 的事件源模型。
- 后续再实现房间列表、reconnect、恢复事件日志、服务器同步和冲突处理。
- Host 仍只是管理权限，不是权威规则源。

## 当前建议下一步

优先实现 `recoverFromDiscardOrDraw` 与弃牌堆选择模式联动。完成后再推进 `FishCardFaceView` 的 compact / normal / detail 展示密度，然后逐步规划真实鱼牌能力映射。
