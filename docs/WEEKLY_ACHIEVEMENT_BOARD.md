# Weekly Achievement Board

本轮实现 Weekly Achievement Board MVP：Base / Sharks & Reefs 成就板、A 面 / B 面、前三周 tile pool、房间创建选择和游戏内展示。实体参考图已放在 `docs/references/weekly_goals/`，只作为 UI 和人工录入参考，不作为运行时规则来源。

## 实体参考

- `base_side_a.jpg`：Base 成就 A 面。
- `base_side_b.jpg`：Base 成就 B 面。
- `sharks_reefs_side_a.jpg`：Sharks & Reefs 成就 A 面。
- `sharks_reefs_side_b.jpg`：Sharks & Reefs 成就 B 面。
- `weekly_goal_tiles_1.jpg` / `weekly_goal_tiles_2.jpg`：左侧 Base tile pool，右侧 Sharks & Reefs tile pool。

这些图片已压缩成开发参考 JPEG。后续文案和 tile 归类仍需人工校对；代码里看不清或需要确认的 tile 使用 `needsReview` / `isImplementedForScoring = false` 标记。

## 数据模型

核心模型在 `WeeklyGoalDefinitions.swift`：

- `AchievementBoardSet`：`base` / `sharksAndReefs`。
- `AchievementBoardSide`：`sideA` / `sideB`。
- `WeeklyGoalWeek`：第 1 至第 4 周。
- `WeeklyGoalSetupConfig`：进入 `GameConfig` 的房间配置，包含 board set、side、selection mode 和手动选择 tile id。
- `WeeklyGoalDefinition`：单个周目标 tile，包含中文标题、说明、icon tokens、分值、scoring rule、来源图片备注、是否已接入计分、是否需要复核。
- `WeeklyGoalSlot` / `WeeklyGoalPool` / `AchievementBoard`：presentation 和配置层使用的 board / slot / pool 结构。

第 4 周固定为 GAME END 说明格，不进入任何 tile pool。

## A 面 / B 面

Base A 面固定：

- 第 1 周：鱼卵和/或幼鱼。
- 第 2 周：整排的鱼。
- 第 3 周：鱼群。
- 第 4 周：GAME END 固定说明。

Sharks & Reefs A 面前三周同样固定，但 board scoring notes 额外显示：

- 珊瑚每个 1 分。
- 完成珊瑚礁的奖励分数。

Base B 面和 Sharks & Reefs B 面只从各自 set 的前三周 pool 选择，不混池。每一周只从对应周 pool 选择 1 个 tile。

## 房间创建

Lobby 创建房间新增 achievement board set 选择：

- 未启用 S&R：默认 Base A 面，只能使用 Base board。
- 启用 S&R：默认 S&R A 面，可以切换 Base board 或 S&R board。
- Side A：固定四格，不需要选择 tile。
- Side B：支持 seeded random 或房主手动选择前三周 tile。

随机选择由 `WeeklyGoalCatalog.resolveGoals(... randomSeed:)` 使用 deterministic `SeededRandom` 完成，不在 SwiftUI `body` 中 random。

手动选择会校验：

- 必须选择第 1 / 2 / 3 周。
- 不允许跨周池。
- 不允许 Base board 选择 S&R tile，或 S&R board 选择 Base tile。
- 未启用 S&R 时不能选择 S&R board。

`LocalAuthoritativeRoomService` 仍通过既有 setup builder 把 resolved weekly goals 写入 setup / `GameState`，所有玩家看到同一组周目标。

## 游戏内展示

游戏内顶部周目标 HUD 继续提供四格入口，但每格使用实体板语义：

- 第 1 / 2 / 3 / 4 周固定 2x2 结构。
- A 面显示固定 tile。
- B 面显示房间 setup resolved 的 tile。
- 第 4 周显示 GAME END 固定说明。
- 当前周高亮。
- 已结算周显示完成状态。
- 未实现计分的 tile 显示“计分待接入”。

详情面板显示每周说明、当前投影 / 已结算分、各玩家得分和第 4 周 GAME END 说明。

## 图标

周目标 tile 不使用 emoji / SF Symbol / 临时色块作为正常图标。`WeeklyGoalIconToken` 在 ViewModel 中映射到 `GameTokenIconKind`，再由 `GameTokenIconResolver` / `GameTokenIconView` 渲染 live-derived CardAssets。

当前覆盖的 logical token 包括鱼卵、幼鱼、鱼群、鱼、小/中/大型鱼、捕食者、被吞食的鱼、抽牌/弃牌、透光/暮光/深海、三色珊瑚、任意珊瑚、完成珊瑚礁、GAME END 和分数波浪。

## 计分状态

本轮保持现有低风险计分：

- 鱼卵 / 幼鱼数量。
- 整排的鱼。
- 鱼群。
- 珊瑚数量。
- 弃牌堆卡牌数量。
- 透光带中的鱼。
- 被吞食的鱼。

以下 tile 已建模并展示，但暂标记计分待接入，避免在没有卡牌目录或规则校对时猜测：

- 小型 / 中型 / 大型鱼。
- 捕食者标签。
- 上方有 / 没有标记的鱼。
- 若发动卡牌。
- 每 2 / 3 枚鱼卵。
- 不同标签。
- printed points 高 / 低区间鱼。
- 完成珊瑚礁奖励作为周目标 tile 的特殊计分。

Final scoring 中既有 coral 每个 1 分、complete reef bonus、GAME END ability scoring 不变。

## 非目标

本轮没有改 Ability Engine，没有大改 GameEngine 规则，没有改 fish card JSON，没有恢复右侧常驻面板，没有做 BoardLayout、联机、Nautoma 或 saved-state migration。

当前 ability coverage 仍要求保持 215 mapped / 0 unsupported，GAME END remaining unsupported 保持 0。
