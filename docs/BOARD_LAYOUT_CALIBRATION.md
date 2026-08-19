# Board Layout Calibration

本阶段已接入 Board UI Foundation Pass 1，目标是为后续真实 board background image 做稳定坐标基础，而不是现在就做 PDF extraction 或完整自动识别。

## 当前实现

- `Finspan/Features/GameBoard/BoardLayout.swift` 定义 `BoardLayout`、`BoardLayoutSlot`、`BoardNormalizedRect` 和 `BoardNormalizedPoint`。
- `Finspan/Resources/BoardLayout/placeholder_board_layout.json` 是当前手工 placeholder layout，包含 18 个 base ocean slot。
- `BoardLayoutMapper.boardImageRect(in:imageAspectRatio:)` 负责 aspectFit 计算。
- `BoardLayoutMapper.mapBoardNormalizedRect` / `mapBoardNormalizedPoint` 负责把 normalized 坐标映射到 fitted board image rect。
- `BoardLayoutCalibrationOverlay` 在 DEBUG 下显示 slotRect / cardRect / hitRect / highlightRect 和 slot id，使用同一套 mapper。

## 渲染原则

真实 board background image 接入后，背景图负责棋盘和 slot 美术。SwiftUI 不再重复画实体 slot 外观，只叠加：

- 透明 hit target；
- 鱼牌；
- egg / young / school board resource token；
- coral reef badge；
- 后续 diver marker；
- 柔和 glow / tint / inner highlight。

正常路径不使用硬边框高光。高光应保持轻量、半透明，并与背景 slot 美术融合。

GameBoard UI Cleanup Pass 1 后，placeholder board canvas 下的 empty slot 也遵循这个原则：正常空槽位只保留透明 hit target / 柔和 tint，不显示 unknown fish card 或卡牌式占位。Forage fish slot 继续显示 forage fish，真实鱼槽继续显示真实鱼牌。unknown card 只代表数据错误或 debug fallback，不是普通空槽位 UI。

Ability Target Interaction Polish 保持同一套 mapper，同时固定 board canvas 的命中顺序：`highlightRect` 柔和高光在底层，`cardRect` 鱼牌只负责视觉，`hitRect` 透明 slot target 位于其上；若牌上资源可作为支付来源，则同一 `cardRect` 内的 resource-token hit target 再置于最上层。这样目标点击不会被卡面截获，资源 token 仍可直接选择，也没有新增另一套坐标转换。

底部 hand area 不属于 board normalized layout；它现在使用与棋盘融合的海洋 glass backdrop，手牌独立居中，弃牌堆作为 trailing overlay 显示。FloatingActionPair 也不写入 BoardLayout，它通过 `FloatingActionPairLayoutMetrics` 避开 hand area、弃牌堆和 system home indicator。

## Layout 字段语义

每个 slot 使用 normalized 坐标：

- `slotRect`：对齐背景图上的 slot 美术；
- `cardRect`：鱼牌实际显示区域，可略小于 slotRect；
- `hitRect`：点击 / 拖放热区，可略大；
- `highlightRect`：柔和高光区域；
- `resourceAnchor`：slot 级资源锚点预留；
- `coralAnchor`：珊瑚显示锚点；
- `diverAnchor`：潜水员标记锚点预留。

所有 overlay 坐标必须通过 `BoardLayoutMapper`，不要在鱼牌、高光、hit target 或 debug overlay 中各自实现坐标转换。

## 当前边界

- 当前使用 placeholder background，保证 app 可运行。
- 当前不做 PDF board extraction。
- 当前不做完整 BoardLayout 校准。
- 当前不修改 AbilityEngine、GameEngine、GameState reducer 结构或 fish card JSON。
- 当前不恢复右侧常驻面板。

## 验证

当前 focused tests 覆盖：

- aspectFit board image rect；
- normalized rect / point 映射；
- placeholder layout 18 个 slot；
- layout JSON decode；
- DEBUG overlay 不修改 `GameState`，不发送 `PlayerCommand`；
- BoardLayout 不影响 staged `playFish` 和 resource payment staging。
- empty slot 不渲染 unknown fish card；
- FloatingActionPair / bottom hand cleanup 只影响 presentation，不修改 `GameState` 或发送 `PlayerCommand`。
- board-target ability 与 resource payment 共用 mapper 后仍保持独立、稳定的 hit-test 层级。

Board Interaction Regression Pass 继续固定 BoardLayout foundation 的边界：normal empty / forage / real fish slot 三态在 presentation 中保持区分；overlay / picker / toast / player perspective 的回归测试不扩大 BoardLayout 范围；当前仍不做 PDF extraction、不导入真实 board background asset、不做完整坐标校准。
