## Why

当前 `InpMaxProfitStopMoney` / `InpMaxLossStopMoney` 只按“全局已闭仓已实现盈亏”工作，既不包含浮盈浮亏，也不会在触发时主动处理当前品种的持仓。这无法满足“达到阶段性盈利或亏损阈值后，立即按当前品种总盈亏结果收口风险”的需求。

## What Changes

- **BREAKING** 将运行期 stop 的统计口径从“全局已实现盈亏”改为“按品种统计的已实现盈亏 + 当前浮动盈亏”。
- **BREAKING** 将运行期 stop 的触发行为从“只阻止新开仓”改为“触发后立即平掉当前品种全部已开受管仓位，并阻止该品种在本次运行内继续自动开仓”。
- 将 stop 原因日志和摘要日志改为按品种输出，并增加浮动盈亏与总盈亏字段。
- README 和相关 specs 同步到新的 stop 语义。

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `mt5-strategy-runtime-controls`: `InpMaxProfitStopMoney` 和 `InpMaxLossStopMoney` 的语义改为按品种的总盈亏阈值，且保持 `0` 表示禁用。
- `mt5-pattern-trade-management`: 运行期 stop 改为按品种统计已实现+浮动盈亏，触发时平掉当前品种全部受管仓位，并阻止该品种继续开仓。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5`
- Affected specs: `openspec/specs/mt5-strategy-runtime-controls/spec.md`, `openspec/specs/mt5-pattern-trade-management/spec.md`
- Affected docs: `README.md`
