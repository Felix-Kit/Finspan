# 当前状态

本文档反映当前 `main` 分支的真实进度。当前项目已经从“最小可玩基础循环”进入 UI 与真实数据增强阶段。

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

### 交互与棋盘 UI

- 已支持拖拽出牌。
- 已支持统一支付 UI，弃牌支付和资源支付都在同一出牌确认流程中汇总。
- 已支持右侧行动确认区，用于出牌、pending choice、奖励选择和移动资源确认。
- 顶部 HUD 已重做，包含玩家头像、当前行动摘要、设置入口和日志入口。
- 周目标四格和详情面板已接入。
- 日志已改为折叠 / 弹出查看。
- 已支持强制结束当前对局并返回主页。
- 已支持弃牌堆只读查看。
- 手牌继续保持底部浮动堆叠显示，不再使用大型白色手牌底座。

### 数据与卡牌

- `BaseGameCardCatalog` 已支持从本地 JSON 加载。
- `Finspan/Resources/Cards/base_main_fish_cards.json` 已包含 base main fish 125 张。
- `Finspan/Resources/Cards/base_starter_fish_cards.json` 已包含 base starter fish 10 张。
- 已支持 `baseGame` / `sample` 数据源切换。
- `SampleCardCatalog` 仍保留用于本地开发和 sample flow。

### 能力系统

- `AbilityRegistry` / `AbilityResolver` 已落地。
- Fish A / Fish B / Fish C sample ability 已迁移到 registry / resolver 模型。
- 当前真实鱼牌能力仍不是全量映射；未接入能力应保持可表示、可跳过，不能导致崩溃。

### 卡牌素材与牌面渲染

- 已添加 finsearch 卡牌素材离线下载脚本：`tools/scripts/download_finsearch_assets.py`。
- 本地素材已导入 `Finspan/Resources/CardAssets/`：
  - fish image: 215
  - icons: 57
  - backgrounds / bands: 13
- `tools/generated/cards/` 已包含拆分后的 card JSON 生成结果。
- `tools/generated/assets/asset_download_summary.json` 已记录素材下载结果和本地资源计数。
- `CardRenderMetrics` 已落地，使用本地 finsearch 背景素材推导出的统一卡牌比例。
- `FishCardFaceView` 已落地。
- 手牌、弃牌堆和 ocean slot 已使用同一最小鱼牌牌面显示。
- 当前牌面是最小近似渲染，不是完整 finsearch 复刻。

## 未做 / 待做

- 真实全量鱼牌能力映射。
- `recoverFromDiscardOrDraw` 与弃牌堆选择面板联动；当前弃牌堆详情主要是只读查看。
- 更完整的 `FishCardFaceView` 细节 / detail 模式。
- `FishCardFaceView` 的 compact / normal / detail 三种展示密度。
- 点击对手头像查看对手 board。
- 真实房间恢复 / reconnect / 房间列表。
- Sharks & Reefs 规则。
- Nautoma。
- 服务器 / 联机同步。
- PDF 解析。
- 完整 finsearch 级别卡牌拼装算法。

## 当前建议下一步

1. 优先做 `recoverFromDiscardOrDraw` 与弃牌堆选择模式联动。
2. 然后做 `FishCardFaceView` 的 compact / normal / detail 三种展示密度。
3. 再逐步映射真实鱼牌能力。
4. S&R / Nautoma / 联机后置。
