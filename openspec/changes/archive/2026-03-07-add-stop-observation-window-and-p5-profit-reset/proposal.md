## Why

当前策略只在 `profit_target` 平仓后启动观察窗口，而 `hard_stop` 和 `soft_stop` 后可以立刻重新开仓。这会让止损后的震荡阶段继续重复入场，和已经为止盈场景建立的节奏控制不一致。与此同时，持仓在首次形成合格 `P5/P6` 后目前只会激活弱止损，不会同步把止盈目标切换到更保守的 `P5` 锚定口径，导致后续退出管理缺少第二阶段利润收敛规则。

## What Changes

- 为 `hard_stop` 和 `soft_stop` 新增按 bar 计数的止损后观察窗口，并保持与止盈观察窗口相同的作用域和生效时机。
- 将入场门控扩展为同时检查止盈观察窗口和止损观察窗口，只要任意一个窗口尚未结束，就阻止该 `symbol + timeframe` 的新买单。
- 新增独立参数控制止损观察窗口长度，默认值设为 `30`，并允许设置为 `0` 显式关闭。
- 在持仓首次出现合格 `P5/P6` 集合时，除激活弱止损外，同时把止盈价改写为基于所选 `P5` 的锚定止盈价。
- 新增独立的 `P5` 锚定止盈系数参数，默认值设为 `0.7`，不复用初始入场阶段的 `InpProfitC`。
- 明确 `selectedP5` 选择规则：在首次满足 `P5/P6` 激活条件的时刻，从当时全部合格 `P5` 候选中选择价格最低的 `P5`，并在首次改写后冻结，不再被后续新的 `P5/P6` 组合继续改写。

## Capabilities

### New Capabilities

### Modified Capabilities

- `mt5-pattern-trade-management`: 修改观察窗口触发范围，并为首次 `P5/P6` 激活加入 `P5` 锚定止盈重设规则。
- `mt5-strategy-runtime-controls`: 新增止损观察窗口长度参数与 `P5` 锚定止盈系数参数，并定义默认值和禁用语义。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5` 的品种运行时状态、入场门控、持仓管理和 `P5/P6` 激活路径。
- Affected specs: `openspec/specs/mt5-pattern-trade-management/spec.md`, `openspec/specs/mt5-strategy-runtime-controls/spec.md`
- Runtime behavior: 止损后再入场节奏会收紧；首次 `P5/P6` 激活后，弱止损和止盈目标都会切换到第二阶段管理口径。
