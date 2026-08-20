# 当前状态

本文档反映当前 `main` 分支的真实进度。项目已经从基础可玩循环进入 Sharks & Reefs 部分接入、GAME END 扫尾和 UI 细化阶段。

## 已完成

### 核心规则循环

- `playFish` / `dive` / pending choice 已接入 Command / Event / Reducer 流程。
- `DiveResolutionQueue` 已落地，潜水奖励按队列逐步解析。
- 已支持 `placeEgg` / `hatchEgg` / `moveYoungOrSchool`。
- 已支持 school 自动形成：同一槽位 3 个 young 且无 school 时形成 1 个 school。
- End of Week / Week Flow 已接入。
- 周目标计分 pass 已接入；A 面保持既有计分，B 面前三周按 base score 最高者额外 +3（并列都加），第 4 周不加。
- 最终计分与最终结算界面已接入。
- 已支持 `consumedFish`，鱼可以覆盖更短鱼。
- 已支持 `coverShorterFish` cost。
- 已支持 reward pool，用于显示和选择当前 pending choice / 奖励解析可用收益。

### Sharks & Reefs 基础接入

- Lobby 已可勾选 Sharks & Reefs。
- 多人房间创建人数已限定为 2–5 人；1 人配置不再出现在多人房间表单，Nautoma 仍保留为主界面的独立单人模式入口。
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
- UI Polish Pass 1A 已接入 `GameBoardAnimation` 统一 quick / standard / slow、hand selection、dock、token、overlay 和 board perspective 动画参数；当前仅影响 SwiftUI presentation，不修改规则状态或 command 提交时机。
- 手牌选中现在以稳定 `cardId` 身份轻微上浮、放大、加强阴影并提高 zIndex；再次点击会平滑取消回位。不可交互点击 / 非法拖放给短促 nudge 反馈，不让整排手牌重排。
- 拖动手牌时保留浮起感；合法 drop target 使用轻量 scale / glow / border 高亮。取消拖动或非法 drop 会平滑回到手牌区；`PlayerCommand.playFish` 仍只在确认时提交。
- `FloatingActionPairView` 已接入：纯 `←` staged undo / cancel 与 `→` confirm / continue / skip 改为两个 52pt 圆角方块按钮，需要时浮在 board 右下 / 中下安全区，不贴系统 home indicator，不遮挡手牌，不恢复右侧常驻面板。
- 纯确认 / 取消不再触发底部 dock。普通 staged `playFish`、支付完成后的确认、简单 pending forward / skip 使用 FloatingActionPair；按钮仍调用既有 ViewModel confirm / cancel path，`PlayerCommand.playFish` 的提交时机不变，`←` 只撤回未提交 staged selection，不做 engine-level undo。
- `BottomRewardDock` 职责已收窄为 pending reward token list、ability reward source summary、dive / zone reward、GAME END candidate、AllPlayers 外部收益、overlay / picker 入口和复杂选择摘要；只有 controls、没有 token / source / summary / warning / fallback 内容时 dock 隐藏。
- `BottomRewardDock` hidden / handleOnly / compact / expanded 切换使用统一底部滑入 + fade transition；dock token 出现 / 消失使用 scale + opacity，选中 token 使用轻量 scale / highlight，且 token identity 继续由稳定 `token.id` 驱动。
- 右侧 reward / pending / playFish confirm 面板已从主棋盘 layout 移除，不再常驻占用右侧空间。
- 复杂 fallback 不再通过右侧常驻栏承载；由 bottom dock 拉起 overlay / sheet / picker / debug helper。
- `BottomDockOverlayRoute` / `BottomDockOverlayState` 已接入，用于统一 dock fallback continuation：弃牌堆选择、手牌选择、playFish staging、reef target、debug fallback 和 GAME END candidate。
- discard pile overlay、recover selection、hand picker、consumeFishFromHand picker、playFishForFree / playFishFromHand picker 现在使用 dim fade + panel slide/fade；关闭 overlay 只撤回未提交 staged selection，不影响已经提交的 `GameEvent`。
- `recoverFromDiscardOrDraw` 的 dock token 现在会在有可恢复弃牌时打开现有弃牌堆 recover selection overlay；弃牌为空时仍由 dock 走 draw fallback，draw 后不支持 committed undo。
- `consumeFishFromHand` 的 dock token 现在打开 hand picker，再继续到 board target 选择吞噬者；非法手牌由 hand picker 显示 disabled / reason。
- `playFishForFree` / `playFishFromHand` 的 dock token 现在打开 hand picker，再进入 staged `playFish` flow；免费出牌不要求支付，paid play 继续使用现有直接资源 / 手牌支付选择，纯 `→` / `←` 由 FloatingActionPair 表达。
- `drawFish` 可由 dock token direct commit；GAME END candidate 和 AllPlayers target-player external reward 继续由 bottom dock 承载 source summary、reward token 和 skip / staged undo。
- Unified Board/Card Interaction Flow Design 已落地为 presentation model：新增 `BoardCardInteractionTask` / `Step` / `Token` / `SourceOption` / `Target` / `ControlState`，用于表达未来 board/card inline staged selection。该模型不接规则引擎、不修改 `GameState`，最终合法性仍在 `GameEngine`。
- Inline 交互分类已从单轴 A/B/C/D 调整为四维模型：`InlineEntrySurface`、`ContinuationSurface`、`CommitReversibility`、`SourceVisibility`。`needs picker / overlay` 不再等于不能 inline；`irreversible / no undo` 也不再等于不能 inline，只表示提交后不能用 `<-` 撤回。
- 新增 `IncomingRewardDockState` presentation model，用于 AllPlayers 目标玩家、不可见 source card、board / dive-site marker 或 GAME END dock 等外部 pending reward 的来源摘要；实际入口由 `BottomRewardDock` 承载。
- 已明确区分 cost / requirement token 与 reward / ability token：`playFish` cost icon 是进度展示，玩家直接点击 board / hand / reef 上的合法来源；ability reward icon 才是主动入口。
- Compact Resource HUD 已接入顶部 HUD，只用真实 live-derived token icon 显示鱼卵、幼鱼和鱼群计数。手牌数量留在手牌区域，三色珊瑚移到各 dive-site column 的 twilight / reef 区域附近。
- board slot 鱼牌上的 egg / young / school 已从左侧 size-class 区域迁到中央 fish artwork / background region。token 可覆盖鱼图，但共享 normalized layout 保证视觉图标和透明 hit target 都留在 card / slot bounds 内，并避开 points、length、tag、名称、flavor 和右侧 ability 区。
- board resource token 继续使用 live-derived CardAssets，无 badge / 底板；视觉尺寸从 7.5cqw 提高到 9cqw，最多五枚按紧凑错位布局展开。payment staged selection 仍由 slot 层同中心的透明 hit target 发送，手牌和弃牌卡面不注入 board token。
- 玩家板上的初始 2 枚鱼卵和 1 枚幼鱼现在与后续资源完全共用 live token 呈现：直接叠加本地 `FishEgg` / `YoungFish` / `SchoolFish` 素材及透明点击区，不再为背景内的印刷起始提示单独校准或绘制圆角资源槽。资源锚点位于所属鱼牌／槽位的中央 artwork 区域；背景 PNG 保持原始、经校验的玩家板美术。
- Player Mat Background Pass 已接入：Base 玩家面板由规则书干净样例手工分离为本地离线 `base_player_mat.png`，使用实体纵向面板比例；`player_mat_layout.json` 按面板像素校准 18 个 slot / card / hit / highlight rect，所有 overlay 继续复用 `BoardLayoutMapper` 的同一套 aspectFit 映射。
- 独立 PNG 棋盘资源现在通过 bundle 文件 URL 加载并缓存，不再误用只查 Asset Catalog 的 `Image(name)`。若背景文件缺失或解码失败，棋盘会自动显示渐变背景、可见空槽轮廓和独立 forage fish 卡面，不会再次退化成整板空白。
- 每张出牌卡现在以完整鱼牌比例覆盖印刷 slot：`cardRect` 不再在 16:9 placeholder slot 内二次缩小。空槽只保留透明 hit target / 柔和 tint；面板印刷的 Catalina Goby、Showy Bristlemouth、Glasshead Grenadier 直接由背景显示，真实出牌继续叠加 `FishCardFaceView`。
- S&R 继续使用与 Base 完全相同的面板尺寸和 18-slot 布局，只在 Twilight 上方按 normalized rect 叠加本地 `sharks_reefs_coral_overlay.png`；动态珊瑚进度使用轻量 overlay，不另造一张尺寸不同的棋盘。
- DEBUG calibration overlay 仍可显示 slotRect / cardRect / hitRect / highlightRect 与 slot id，但只在启动参数 `-showBoardCalibration` 或环境变量 `FINSPAN_SHOW_BOARD_CALIBRATION=1` 时开启，不污染普通 Debug 试玩界面。
- GameBoard UI Cleanup Pass 1 已完成第一轮明显 UI bug 修复：根视图使用海洋渐变背景，底部手牌区使用融入棋盘的 glass backdrop，不再出现突兀白色底条。
- 手牌区继续以稳定 `cardId` 为 identity 居中渲染；选中 / 拖动只改变同一张卡的 offset / scale / zIndex，不让整排手牌因弃牌堆或 selection 重排。
- 弃牌堆为空时完全不显示、不占位；有弃牌时作为右侧 trailing overlay 悬浮在手牌区域旁，不把手牌主体推偏，点击仍进入弃牌堆查看 / recover selection overlay。
- board canvas 空 ocean slot 只显示轻量透明 hit target / tint，不再显示 unknown fish card 或正常运行时的卡牌占位；forage fish slot 仍显示 forage fish，真实鱼槽仍显示真实鱼牌。unknown card 仅保留为数据错误 / debug fallback 语义。
- `FloatingActionPairView` layout metrics 已继续校准：两个 52pt 方块按钮保持在 board 右下 / 中下安全区，使用 `bottomClearance` / `trailingClearance` / `handAvoidanceHeight` 避开 hand area、弃牌堆和 system home indicator；overlay / picker 打开时全局按钮隐藏。
- 顶部行动摘要已走 `hudToastViewState` toast：重要事件短暂顶部显示并自动淡出，完整事件日志仍由日志按钮 / sheet 查看；pending / error 提示保留为轻量状态条，不恢复右侧常驻面板。
- Board Interaction Regression Pass 已补强 presentation 验收：手牌居中 / 弃牌堆 trailing overlay、不占位隐藏、discard overlay 关闭不提交命令、empty / forage / real slot 三态渲染、hand picker overlay 隐藏全局 FloatingActionPair、toast 与完整事件日志互不影响、对手面板切换不发送 `PlayerCommand` / 不修改 `GameState`。
- Ability Target Interaction Polish 已把普通 `placeEgg` / `placeYoung` / `hatchEgg` / matching-fish egg pending 自动推进到棋盘选目标阶段：单一明确收益不再要求先点一次 dock token，合法 slot 直接高亮；复合能力仍先选择 effect，避免 UI 替玩家决定顺序。
- 新增 `BoardInteractionPromptViewState`，把“请选择高亮目标 / 来源 / 手牌”等中性步骤提示与真正的非法点击错误分开；无效目标只短暂显示明确错误，不再把正常操作指引染成红色。
- board canvas 的透明 slot hit target 现在位于非交互卡面之上，资源 token payment hit target 再独立置顶；能力目标点击与资源支付不再被卡面层截获。完成 pending 后，ViewModel 会按最新 authoritative pending state 清理旧 token / target staging；不会撤回已提交事件。
- egg / young / school token 的插入 / 选择继续使用稳定 token id，并增加轻量 scale + opacity 动画；产卵成功后的棋子反馈不再硬切。
- 右侧资源统计大面板已压缩掉；右侧 pending / reward / action / playFish confirm 面板已从主 layout 移除。
- `GameTokenIconResolver` / `GameTokenIconView` 已新增，非卡面 UI 的 egg / young / school / fish / coral / draw / discard / consume / hatch / move / zone token 可复用现有 CardAssets icon resolver，尺寸由 HUD / board layout 控制，不由 PNG intrinsic size 控制。
- 顶部 HUD 已重做，包含玩家头像、当前行动摘要、设置入口和日志入口。
- 主棋盘右上角已接入四个横向并排的小方块周目标入口；入口只显示 token icon、微型周数 / 分值角标和完成状态，不显示完整标题。当前周 icon 放大并用黄色描边高亮。
- 点击任意周入口会打开全 4 周 scoreboard，并高亮被点击周；每周一个 section，header 按“第 X 周、图标、标题”排列，section 内按玩家显示归一化横向 score bar，最高分及并列最高高亮，不采用单行平铺所有玩家的布局。
- `WeeklyGoalScoreboardState` / section / player score bar / status presentation model 已接入。已结算周读取 `weeklyAchievementResults` frozen snapshot，不随当前 board 或 viewing player 改变；当前周和未来周由 ViewModel 基于当前 board 计算只读 projection，不写入 `GameState`。
- Weekly Achievement Board MVP 已接入：`GameConfig.weeklyGoalSetup` 现在可表达 Base / Sharks & Reefs board set、A 面 / B 面、B 面随机或手动前三周 tile。
- Base / S&R Side A 固定第 1-3 周目标和第 4 周 GAME END 说明格已建模；Base Side B 按周使用 Base pool，S&R Side B 按周使用 Base + S&R 合并池，第四周不从 pool 选。
- Lobby 创建房间支持选择 achievement board set 和 A/B 面；A 面会直接预览第 1–3 周固定目标及第 4 周终局说明。启用 S&R 时默认 S&R A 面，也可切回 Base board。B 面 random 使用 setup seed deterministic 选择，manual selection 禁止跨周池，S&R board 可选同周 Base 或 S&R tile。
- 游戏内周目标 HUD / scoreboard 现在使用 resolved weekly goal tile，未实现计分 tile 显示“计分待接入”。周目标 icon 通过 `WeeklyGoalIconToken` -> `GameTokenIconResolver` 使用 live-derived assets，不再用 emoji / SF Symbol / 文本符号作为正常路径。
- 已将实体周目标参考图压缩存入 `docs/references/weekly_goals/`，仅作为 UI 和人工录入参考；文案和 tile 归类仍可后续校对。
- 日志已改为折叠 / 弹出查看。
- 已支持强制结束当前对局并返回主页。
- 已支持弃牌堆 normal 只读查看，以及 `recoverFromDiscardOrDraw` pending effect 下的弃牌选择模式。
- `recoverFromDiscardOrDraw` 弃牌选择模式已接入 `PendingEffectSet` / `PendingEffectIntent`：可选择具体弃牌恢复，也可主动选择改为抽牌；弃牌为空时仍 fallback draw deck。
- 手牌点击性能审计已完成一轮低风险优化：`GameBoardViewModel` 缓存按 cardId 生成的静态 `FishCardFaceViewState`，减少选牌时重复 catalog lookup / ability token parse；选牌仍只改变 UI selection，不修改 `GameState`。
- 查看对手 board 时 ocean / bottom area 使用局部淡入 / 平移过渡；`BottomRewardDock`、pending、staged `playFish` 和 AllPlayers / GAME END 上下文不因 `viewingPlayerId` 切换而丢失。
- 本轮没有恢复右侧常驻面板，没有修改 `AbilityEngine` / `GameEngine` / card JSON。

### 数据与卡牌

- `BaseGameCardCatalog` 已支持从本地 JSON 加载。
- `Finspan/Resources/Cards/base_main_fish_cards.json` 已包含 base main fish 125 张。
- `Finspan/Resources/Cards/base_starter_fish_cards.json` 已包含 base starter fish 10 张。
- 正常 Lobby 只提供 reviewed `baseGame` 数据源。
- `SampleCardCatalog` / `.sample` factory path 仍保留给单元测试和显式开发 fixture，不进入普通房间创建 UI。

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
- DEBUG card face 增加 icon / layout render status 面板：在 Lobby → 牌库 → 所有牌中点击卡面右上角 `i` / `!` 可查看 card id、source id、icon count、failed icons、missing assets、fish image / flavor text、render asset type、ability block count、block type、token placement、S&R badge、starter corner、AllPlayers shadow 和 also-if block count。
- 牌面底部英文 flavor text 已恢复：215 张卡的 live description 被抽取为 `Finspan/Resources/CardAssets/card_face_descriptions.json` 渲染 metadata，不修改 `Finspan/Resources/Cards/*.json`，S&R 仍优先使用自身 `rawSource.description`。
- 鱼牌牌面文案保持 English / raw source：name、scientific name、ability text、trigger title 和 flavor text 不使用中文牌面文案；App 外层中文 UI 不受影响。
- FishCardFaceView Ability Layout + Badge Fidelity Pass 已完成：新增 `CardAbilityPresentation`，ability token 不再统一 HStack；Great White Shark 的 `FishEgg` / `ArrowDown` / `Predator` 生成 arrow-flow icon group，`AllPlayers` 使用 live drop-shadow style；IF ACTIVATED `also, if` 被拆成主 brush block 和条件 brush block，中间保留 gap。
- Trigger / ability brush 正常路径使用 live `IfActivated` / `GameEnd` strip asset，不再用纯色矩形替代；DEBUG 下 asset 缺失才显示红色 outline fallback。
- S&R 牌显示右下角 `SRLogo` expansion badge；base 牌不显示。
- Starter 牌显示左上 / 右下 clipped gray corner overlay；该角标来自 live CSS `.corner-overlay`，不是 `StarterIcon` 图片。`StarterIcon` 仍作为 live 搜索 / filter asset 保留。
- FishCardFaceView Live DOM Measurement + Ability Brush Correctness Pass 已完成：新增 `tools/scripts/measure_live_card_dom.mjs`，用 Playwright / Chromium 本地渲染 `references/webpage_live/index.html`，生成 `tools/generated/card_rendering/live_measurements.json` 和 `docs/CARD_RENDERING_LIVE_MEASUREMENTS.md`。
- `CardAbilityLayoutMetrics` 现在使用 live DOM measured frame，而不是仅凭 CSS 整数估算：Banggai Cardinalfish ability container 为 left 71.883cqw、top 0.266cqw、width 27.851cqw、height 65.218cqw、right gap 0.266cqw。
- IF ACTIVATED / GAME END / also-if brush 根因已确认：live 是 `.ability` 的 CSS `background-image`，computed `background-size: cover`、`background-position: 0% 0%`、默认 `background-repeat: repeat`，无 rotation；Swift 之前的 cap-inset stretch 与 live 不一致。
- `CardAbilityBrushBackgroundView` 已改为 unrotated top-leading cover/crop，匹配 live background semantics，不用纯色正常 fallback。
- AllPlayers Ability Overlay 修复已完成：live CSS 的 `.AllPlayers` 实际相对整个 `.ability-container` 绝对定位，并不属于橙色 / 黄色 brush block。Swift 现在由 `CardAbilityPresentation.bottomOverlayIcons` 在 ability container 底部独立叠放，brush content 会过滤该图标，因此 Paraliparis 以及全部 34 张 AllPlayers 卡不会再被底部图标撑高背景。
- `CardAbilityIconLayoutMetrics` 已按 live CSS 收口能力图标高度：DrawCard / Discard / Consume / FishFromHand 为 8cqw、SchoolFeederMove 12.5cqw、UnSchoolFish 16cqw、AnyCoral 12cqw、YoungFish 6.5cqw、AllPlayers 9cqw；能力图标保持原始宽高比，plus-row 使用 7cqw 高 / 8cqw 宽上限。
- live DOM 代表卡新增 `base.main.087` Paraliparis；测量确认 brush bottom 为 47.292cqw、AllPlayers top 为 52.558cqw，两者明确分离。测量脚本会等待全部图片 decode，并用已审计的同名 runtime PNG 代理本地 mirror 中 namespace 不完整的 SVG，避免把 broken-image alt text 误当成图标尺寸。
- Inline Ability Interaction audit 已更新为四维分类：`tools/scripts/audit_inline_ability_interaction.py` 输出每张卡的 `inlineEntrySurface`、`continuationSurface`、`commitReversibility`、`sourceVisibility`、`requiresFallback`、`requiresOverlay` 和 `canStartInline`。
- 215 张卡 legacy 分类仍为 A inline candidates 73、B needs picker/overlay 51、C irreversible/no undo 91、D not enough metadata 0；新口径下 card ability icon entry 215、incoming reward dock entry 34、GAME END dock entry 39、D not enough metadata 0。
- 当前暂停 card inline 作为主交互。`BottomRewardDock` 是 reward / pending 信息和复杂 continuation 的主入口；纯 playFish confirm / cancel 由 `FloatingActionPairView` 承载。card inline 只保留 source/highlight/group hint，`ArrowDown` 前后 token 作为组合语义整体高亮，不单独可点。
- 外部收益优先由 `IncomingRewardDockState` 提供 source 摘要，并通过 bottom dock 展示。`recoverFromDiscardOrDraw`、`consumeFishFromHand`、`playFishForFree` / `playFishFromHand`、`drawFish`、GAME END 和 AllPlayers 都已在 audit / model 中按新口径表达。
- `→` 可映射到 `PendingEffectIntent.skipRemaining` / `skipEffectExecution` 或单节点 `skipEffectNode`；`←` 当前只适合撤回未提交的 ViewModel staged selection，不能撤回已提交 `GameEvent`。
- Player Board Perspective 已完成：`activePlayerId` / `localPlayerId` / `viewingPlayerId` 在 presentation 层分离，顶部玩家头像可切换正在查看的 board，`activePlayerId` 仍只由规则状态决定。
- 查看对手 board 时显示该玩家 ocean / resources / reef / source highlight，但 board 为只读：不能向对手 board 出牌，不能选择对手资源作为自己的 payment source，也不能在对手 board 上解决自己的 pending target。
- 查看对手时手牌仍显示本地/当前行动玩家自己的手牌，并显示“正在查看对手，手牌仍为你自己的手牌”，避免误认为看到了对手手牌。
- `BottomRewardDock` 和 `FloatingActionPair` 不因 `viewingPlayerId` 切换而丢失 pending / playFish / GAME END / AllPlayers 上下文；当 pending 必须回到自己 board 选目标或支付来源时，dock / error prompt 显示返回自己面板提示。dock source summary 可跳到 AllPlayers 或 GAME END 来源玩家 board，并在可定位时高亮来源鱼。
- DEBUG 牌库卡面状态面板继续扩展：现在可显示 brush asset、brush orientation、brush content mode、background position/repeat、ability panel frame、live measured frame、Swift delta、arrow-flow metrics 和 also-if gap，便于在模拟器中核对 pixel alignment。
- Great White Shark 是 QA 样例，不是 special case：`base.main.057` 映射到 `57.*.webp`，`FishEgg` / `ArrowDown` / `Predator` / `AllPlayers` 均解析到 live-derived PNG render asset，cost 显示 `YoungFish` / `ConsumeFish`，length 600 cm 映射到 `FishLengthLarge`，ability presentation 使用 arrow-flow 而非 flat row。
- Great Northern Tilefish、Banggai Cardinalfish、Bearded Seadevil、Great Barracuda、Atlantic Barracudina 和 Paraliparis 也纳入代表卡审计，覆盖 If Activated brush block、arrow-flow overlap、AllPlayers container overlay、S&R coral requirement / coral token、also-if split block、S&R badge、starter corner、不同 zone 和 flavor text。
- DEBUG 牌库 QA 搜索已接入：Lobby → 牌库 → 所有牌，可按 English name、canonical card id、sourceId、trigger 或 token 稳定预览代表卡，不依赖随机发牌。
- Pass 2 全量 215 张真实卡 ability / cost / zone / tag / points / length token 审计结果：missing asset / fallback count 0。
- Icon renderability focused tests 覆盖 Great White Shark、Great Northern Tilefish、Great Barracuda 和全量 215 张真实卡；代表卡 renderability failures 为 0。
- 手牌、弃牌堆和 ocean slot 当前仍共用同一完整卡牌牌面。
- 当前牌面已完成 Pass 2 结构补齐、icon renderability pipeline fix、ability layout / badge / starter corner pass、live DOM measured brush correctness，以及 AllPlayers container overlay / icon sizing regression pass；仍不是完整 finsearch 像素级复刻。详见 `docs/CARD_RENDERING_FIDELITY.md` 和 `docs/CARD_RENDERING_LIVE_MEASUREMENTS.md`。

## 当前仍需修复 / 待做

### UI polish 后续

- bottom dock 的 picker / sheet fallback 已完成第一轮动画 polish；后续仍可继续优化尺寸、手牌遮挡和更明确的错误提示，但主路径已经不回到常驻右侧栏。
- 真实设备上仍可继续微调 FloatingActionPair 与不同手牌数量、弃牌堆和 overlay 的相对位置；当前已通过 presentation metrics 避开 hand area 和 home indicator。

### 规则与功能

- Ability Engine v2 saved-state migration / legacy cleanup 后置：当前不是正式发布阶段，legacy adapter 继续保持行为稳定，直到旧本地房间和旧 pending-choice payload 有明确迁移路径。
- GameBoardViewModel pending UI stabilization 后续：单一 board-target ability 已完成直接进入目标阶段；下一步只继续收敛 move / consume / play-from-hand 等多阶段 source / target / payment / discard-selection 的 metadata fallback，不把规则判断搬进 SwiftUI。
- Weekly Achievement Board 后续：继续人工校对 Base / S&R Side B tile 文案和图标；marker 状态尚未建模，因此“上方有标记的鱼 / 上方没有标记的鱼”仍未接入；“幼鱼”tile 文案与现有 young resource 语义仍需复核。
- Base 真实 board 背景和第一轮人工 slot 校准已接入；后续仍需在不同 iPad 尺寸上做像素级视觉 QA，并按实机截图微调少量 rect，而不是重建另一套转换逻辑。
- 自动 PDF layer extraction / slot recognition pipeline 仍未实现；当前资产是一次性、可追溯的手工分离结果，运行时不读取 PDF 或远程素材。
- Nautoma 后置。
- 联机 / reconnect / 房间恢复后置。

## 当前建议下一步

1. 继续做 Player Board Perspective 细节打磨，重点是 source highlight 的可见性、返回自己快捷入口位置和 GAME END 多玩家浏览体验。
2. 继续做 FloatingActionPair / bottom dock fallback 的交互细节打磨，重点是实机位置微调、overlay 尺寸、手牌遮挡和更明确的错误提示。
3. 继续按真实设备试玩打磨多阶段 ability flow，重点是 move / consume / play-from-hand 的 source → target → payment 节奏；单一产卵 / 幼鱼 / 孵化目标流已不再需要冗余 token 点击。
4. 后续再考虑 card icon shortcut；在 FloatingActionPair / bottom dock 体验稳定、BoardLayout 校准完成前不要推进完整 card inline ability tap。
5. 继续 Base / S&R 玩家面板的实机视觉 QA，重点微调 card edge、S&R coral strip 和 bottom bonus overlay；保持同一 `BoardLayoutMapper`。
