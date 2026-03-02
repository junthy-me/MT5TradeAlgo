## Why

回测显示，震荡行情中买单止盈后，随后一段时间内再次开多往往更容易遭遇回落。当前策略在 `profit_target` 平仓后仍可立即重新开多，缺少一个专门抑制止盈后追多的观察期门控。

## What Changes

- 新增“盈利后观察期”规则：当某个 `symbol + timeframe` 的 EA 管理买单因 `profit_target` 平仓后，策略立即进入一个按 bar 计数的观察窗口。
- 新增运行时输入参数 `InpProfitObservationBars`，用于配置观察窗口长度，默认按 30 根 K 线处理。
- 观察窗口内阻止新的买单入场；窗口仅由 `profit_target` 平仓触发，`hard_stop`、`soft_stop` 或非 EA 平仓不会触发该门控。
- 为观察期拦截增加独立日志，区分它与 `P4` 同 bar 锁、共享骨架成功锁以及持仓上限阻止。

## Capabilities

### New Capabilities

### Modified Capabilities
- `mt5-pattern-trade-management`: 为 `profit_target` 平仓后的再入场添加按 bar 计数的观察期约束与日志语义。
- `mt5-strategy-runtime-controls`: 新增 `InpProfitObservationBars` 运行时输入项，并定义其对 `symbol + timeframe` 级观察窗口的控制语义。

## Impact

- 影响 [P4PatternStrategy.mq5](/Users/junthy/Work/MT5TradeAlgo/mt5/P4PatternStrategy.mq5) 的持仓平仓路径、品种运行时状态和入场门控顺序。
- 影响交易日志，新增盈利后观察期阻止原因。
- 影响 OpenSpec 主 specs：`mt5-pattern-trade-management` 与 `mt5-strategy-runtime-controls`。
