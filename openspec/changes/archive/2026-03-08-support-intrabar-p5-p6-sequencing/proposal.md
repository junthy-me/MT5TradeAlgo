## Why

当前 `P5/P6` 激活逻辑仍基于已收盘 K 线的 `low/high` 扫描，因此既不能让 `P4/P5/P6` 落在同一根 K 线上，也无法严格证明 `tP4 < tP5 < tP6`。这会让一部分肉眼上已经形成的后续结构被遗漏，同时也让同 bar 场景存在时间顺序歧义。

## What Changes

- **BREAKING** 将 `P5/P6` 的检测语义从 bar 级后验扫描改为持仓后的 tick 级顺序追踪，要求 `P5` 只能来自 `P4` 之后的 tick，`P6` 只能来自 `P5` 之后的 tick。
- 允许 `P4`、`P5`、`P6` 出现在同一根 K 线上，只要三者对应的 tick 时间严格满足 `tP4 < tP5 < tP6`。
- 保留“首次满足激活条件后一次性冻结弱止损与止盈”的行为，但激活依据改为 tick 序列中满足时序的 `P5/P6` 事件。
- 更新图形与日志语义，使 `P5/P6` 的时间含义明确为激活所依据的事件时间，而不是单纯 bar 开始时间。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mt5-pattern-trade-management`: post-entry `P5/P6` activation changes from closed-bar scanning to tick-ordered sequencing, enabling same-bar `P4/P5/P6` while enforcing strict chronological order.

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5` post-entry state management, `P5/P6` activation, chart annotation timestamps, and related logging.
- Affected behavior: `P5/P6` activation timing in live trading and backtests will change because same-bar structures can now qualify when their tick order is valid.
- No new runtime inputs are required.
