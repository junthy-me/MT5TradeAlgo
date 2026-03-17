## Why

当前策略只按单笔持仓的强止损、弱止损和止盈管理风险，缺少“本次算法运行内累计已实现盈亏达到阈值后停止继续开新仓”的全局门控。这会让策略在已经达到阶段性盈利目标后继续暴露新增风险，或在累计亏损达到可接受上限后仍继续扩大损失。

## What Changes

- 新增基于本 EA 已闭仓已实现金额的全局停止开仓门控，分别支持最大盈利停止阈值和最大亏损停止阈值。
- 达到任一阈值后，只停止新的自动开仓；已有持仓继续按原有强止损、弱止损和止盈逻辑管理直到出场。
- 为运行时停止增加原因日志和摘要日志，明确说明为何停止以及停止时的累计结果。
- 保持 stop 为一次性状态，本次运行内不自动恢复。

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `mt5-strategy-runtime-controls`: 增加运行期已实现盈亏停止阈值输入参数，并定义其启停默认语义。
- `mt5-pattern-trade-management`: 增加基于本 EA 已闭仓已实现金额的全局停止开仓门控，以及触发后的运行时摘要日志行为。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5`
- Affected specs: `openspec/specs/mt5-strategy-runtime-controls/spec.md`, `openspec/specs/mt5-pattern-trade-management/spec.md`
- Affected docs: `README.md`
