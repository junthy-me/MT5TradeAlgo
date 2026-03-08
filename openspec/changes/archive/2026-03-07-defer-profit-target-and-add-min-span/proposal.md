## Why

当前策略在 `P4` 入场时就会设置基于 `InpProfitC` 的初始止盈位，这让部分持仓在结构尚未走出合格 `P5/P6` 之前就提前止盈，和“等待后续结构确认再进入第二阶段管理”的目标不一致。与此同时，历史骨架的 `SpanKNumber` 目前按点位索引差计算，仍然把两端点所在 K 线计入跨度，不符合“只统计中间间隔 K 线数量”的新口径。

## What Changes

- **BREAKING** 移除 `InpProfitC`，取消 `P4` 入场时的初始止盈位；开仓时只设置 `hard_loss_price = P0`。
- **BREAKING** 调整持仓退出节奏：只有在持仓首次出现合格 `P5/P6` 候选集合后，策略才同时激活 `soft_loss_price` 和 `profit_price`；若始终没有合格 `P5/P6`，该持仓将只由强止损管理。
- 保留 `InpP5AnchoredProfitC` 作为唯一止盈系数输入，并把它的语义收敛为“首次合格 `P5/P6` 激活后的唯一止盈公式系数”。
- 新增最小跨度输入项 `InpAdjustPointMinSpanKNumber`，默认值为 `5`。
- **BREAKING** 将 `InpAdjustPointMaxSpanKNumber` 默认值从 `10` 调整为 `30`。
- **BREAKING** 将 `SpanKNumber` 的计算口径改为“仅统计相邻点之间中间间隔的 K 线数量”，即不包含起点和终点所在 K 线。
- 将新的最小/最大跨度区间统一应用到 `P0->P1`、`P1->P2`、`P2->P3`、`P3->P4` 四段，并同步更新 cached 搜索、legacy exact 搜索和最终结构过滤逻辑。

## Capabilities

### New Capabilities

### Modified Capabilities
- `mt5-pattern-trade-management`: 修改入场后持仓管理语义，移除初始止盈，改为首次合格 `P5/P6` 后才同时激活弱止损和唯一止盈位。
- `mt5-kline-pattern-detection`: 修改历史骨架各段跨度的定义口径和区间限制，使其按“中间 bar 数”计算，并对 `P0->P1` 到 `P3->P4` 四段统一施加最小/最大跨度约束。
- `mt5-strategy-runtime-controls`: 移除 `InpProfitC`，新增 `InpAdjustPointMinSpanKNumber`，调整 `InpAdjustPointMaxSpanKNumber` 默认值，并更新相关输入项的默认值和业务语义。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5` 的模式快照构建、历史骨架搜索、实时触发、入场前 stale 过滤、持仓管理和输入校验逻辑。
- Affected specs: `openspec/specs/mt5-pattern-trade-management/spec.md`, `openspec/specs/mt5-kline-pattern-detection/spec.md`, `openspec/specs/mt5-strategy-runtime-controls/spec.md`
- Runtime behavior: 新开仓将不再具有初始止盈，部分持仓会更长时间仅由强止损管理；候选骨架将过滤掉过短线段，同时允许更长的结构进入检测。
