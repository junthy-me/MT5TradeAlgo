## Why

当前前置条件下跌公式仍然按 `(a+b1+b2)` 计算，且始终默认启用，这会让操作者难以按策略意图单独控制 `Pre0-P0` 的过滤强度，也会在不需要前置条件时继续影响模式识别和图表标注。同时，历史骨架已经约束了 `Pre0-P0`、`P0-P1`、`P1-P2`、`P2-P3` 的段内端点极值，但 `P3-P4` 仍缺少同类约束，导致 `P3` 可能不是触发段内真正的极大值点。

## What Changes

- 将前置条件下跌幅度公式从 `InpPreCondPriorDeclineMinDropRatioOfStructure * (a+b1+b2)` 改为 `InpPreCondPriorDeclineMinDropRatioOfStructure * (a+b1)`。
- 新增运行时开关 `InpPreCondEnable`，默认值为 `false`；只有显式启用时才评估 `Pre0-P0` 前置条件。
- 当 `InpPreCondEnable=false` 时，不再寻找 `Pre0`，也不在图表上绘制 `Pre0` 及其相关下跌标注。
- 当 `InpPreCondEnable=true` 时，继续执行 `Pre0-P0` 前置条件，并保留 `Pre0` 图表标注。
- 为 `P3-P4` 触发段新增端点极值约束：`P3` 必须达到 `P3->P4` 整段的最高点，默认允许并列极值。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mt5-kline-pattern-detection`: 调整 `Pre0-P0` 前置下跌公式、增加可禁用的前置条件开关，并为 `P3-P4` 线段补充端点极值约束。
- `mt5-strategy-runtime-controls`: 新增 `InpPreCondEnable` 输入项并定义其默认值与启停语义。
- `mt5-pattern-chart-annotations`: 明确 `Pre0` 及其相关数值标注仅在前置条件启用且匹配通过时绘制。

## Impact

- 受影响代码主要集中在 `mt5/P4PatternStrategy.mq5` 的前置条件评估、实时 `P4` 触发验证、模式快照生成与图表标注流程。
- `README.md` 中关于前置条件公式、默认值和图表说明需要同步更新。
- 不引入新的外部依赖，但会改变默认配置下的候选匹配数量与图表显示内容。
