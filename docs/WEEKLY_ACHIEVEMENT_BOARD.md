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

Base B 面只使用 Base 前三周 pool。启用 Sharks & Reefs 并选择 S&R board 时，每周 pool 是同一周的 Base tile + S&R tile 合并池；不会排除 Base tile，也不会跨周混池。每一周只从对应周 pool 选择 1 个 tile。

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
- Base board 不允许选择 S&R tile；S&R board 允许在对应周的 Base + S&R 合并池中选择。
- 未启用 S&R 时不能选择 S&R board。

`LocalAuthoritativeRoomService` 仍通过既有 setup builder 把 resolved weekly goals 写入 setup / `GameState`，所有玩家看到同一组周目标。

## 游戏内展示

游戏内主棋盘右上角提供四个横向并排的小方块入口，每格使用实体板语义：

- 第 1 / 2 / 3 / 4 周入口只显示 token icon、微型周数 / 分值角标和完成状态，不显示完整中文标题，也不是完整详情卡。
- A 面显示固定 tile。
- B 面显示房间 setup resolved 的 tile。
- 第 4 周显示 GAME END 固定说明。
- 当前周 icon 放大到 1.15 倍，并以黄色描边高亮。
- 已结算周显示完成状态。
- 未实现计分的 tile 显示“计分待接入”。

点击任意入口后打开全 4 周 scoreboard，被点击周 section 使用强调描边。scoreboard 每周一个 section，header 按“第 X 周 -> 图标 -> 标题”横向对齐；section 内每个玩家一条横向 score bar，按该周最高总分归一化，0 分仍显示数值，最高分和并列最高都高亮。该布局不把所有玩家压成一行文本。第 4 周显示固定 GAME END 说明，不参与 B 面 +3。

`WeeklyGoalScoreboardState`、`WeeklyGoalScoreboardSectionState`、`WeeklyGoalPlayerScoreBarState` 和 `WeeklyGoalScoreStatus` 都是 presentation model。已结算周从 `GameState.weeklyAchievementResults` 读取周结算时冻结的结果，不根据当前 board 重算，也不受 viewing player 切换影响。当前周和未来周由 `GameBoardViewModel` 使用当前 board 计算 projection；projection 不写回 `GameState`。未实现 tile 显示“计分待接入”。

## 资源展示调整

- 顶部 Compact Resource HUD 只显示鱼卵、幼鱼和鱼群。
- 三色珊瑚从顶部 HUD 移到各 dive-site column 的 twilight 区域前，继续使用 `GameTokenIconResolver` 的 live-derived icon。
- ocean slot 上的鱼卵 / 幼鱼 / 鱼群通过共享 normalized layout 直接叠放在鱼牌中央 fish artwork / background region，可覆盖鱼图，但不覆盖鱼名、tag、能力、分数、长度、flavor 或 zone icon，也不越过 card / slot bounds。token 无外框 badge，透明 hit target 跟随相同中心坐标。
- 资源选择仍是 ViewModel staged selection，最终变更继续通过既有 command/event/reducer 路径。

## Runtime 数据源

正常 Lobby 只提供 reviewed `baseGame` 数据源。`SampleCardCatalog` 和 `.sample` factory path 仍保留给单元测试与显式开发 fixture，不进入普通房间创建 UI。

## 图标

周目标 tile 不使用 emoji / SF Symbol / 临时色块作为正常图标。`WeeklyGoalIconToken` 在 ViewModel 中映射到 `GameTokenIconKind`，再由 `GameTokenIconResolver` / `GameTokenIconView` 渲染 live-derived CardAssets。

当前覆盖的 logical token 包括鱼卵、幼鱼、鱼群、鱼、小/中/大型鱼、捕食者、被吞食的鱼、抽牌/弃牌、透光/暮光/深海、三色珊瑚、任意珊瑚、完成珊瑚礁、GAME END 和分数波浪。

## 计分状态

当前已接入：

- 鱼卵 / 幼鱼数量。
- 整排的鱼。
- 鱼群。
- 珊瑚数量。
- 弃牌堆卡牌数量。
- 透光带中的鱼。
- 被吞食的鱼。
- 小型 / 中型 / 大型 visible fish，使用卡牌长度和既有 `<50 / 50..<150 / >=150` 分类；consumed fish 不计。
- visible fish 的 Predator tag 和 IF ACTIVATED trigger。
- 每 2 / 3 枚鱼卵，使用 `floor(totalEggs / groupSize)`。
- visible fish 上 Predator / Bioluminescent / Camouflage / Electric / Venomous 五种不同 tag。
- visible fish 的 printed points `> 4` 和 `1...3` 区间，不混入 GAME END / coral points。
- 已完成 coral reef 的 `completionBonus`，作为独立 weekly score。

仍未接入 / 需复核：

- “上方有标记的鱼 / 上方没有标记的鱼”：当前没有真实 marker state，不能用 egg / young / school 冒充 marker。
- “幼鱼”tile：现有 icon / 文案与 young resource 的确切计分语义仍需人工校对。
- “若发动卡牌”、不同标签和完成珊瑚礁已按明确 metadata 接入，但保留 `needsReview` 以继续核对实体 tile 文案。

B 面第 1 / 2 / 3 周按 base score 选最高玩家额外 +3，并列最高都 +3；A 面和第 4 周不加。`WeeklyAchievementResult.points` 冻结 total，scoreboard 通过 `quantity * pointsPerUnit` 展示 base，再计算 +3 breakdown；projection 使用同一 scorer，但只存在于 presentation 层。

`tools/scripts/audit_weekly_goal_scoring.py` 可在无 simulator 环境下报告 tile 总数、已实现 / 未实现 / needsReview 数量及对应 ids；剩余未实现项不会使非严格审计失败。

Final scoring 中既有 coral 每个 1 分、complete reef bonus、GAME END ability scoring 不变。

## 非目标

本轮没有改 Ability Engine，没有大改 GameEngine 规则，没有改 fish card JSON，没有恢复右侧常驻面板，没有做 BoardLayout、联机、Nautoma 或 saved-state migration。

当前 ability coverage 保持 215 mapped / 0 unsupported，GAME END remaining unsupported 保持 0。此次改动未修改 Ability Engine 或 fish card JSON，也未恢复右侧常驻面板。
