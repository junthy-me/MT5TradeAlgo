## Why

当前 `InpTSpanMinConf` 通过限制 `min(t1, t2, t3)` 的分钟数来过滤过密集的历史结构，但它既不覆盖 `P3-P4`，也强依赖周期长度，和“关键线段挨得太近容易受噪声干扰”的真实意图并不一致。与此同时，`InpPointValueType` 已经不再实际控制 `P0-P6` 的点位取值，继续保留只会误导使用者。

## What Changes

- 用新的 `InpMaxAdjustPointSpan` 替换 `InpTSpanMinConf`，将历史骨架过滤规则改为限制 `P0-P1`、`P1-P2`、`P2-P3`、`P3-P4` 四个线段中“相邻线段”的最大数量。
- 明确定义“相邻线段”为组成该线段的两点对应 bar span 恰好等于 `1`，即两个点位落在连续 K 线柱上。
- 将完整匹配条件中的 `CondE` 从基于 `tspanmin` 的分钟过滤改为基于相邻线段计数的结构拥挤度过滤。
- **BREAKING** 废弃并移除 `InpPointValueType` / `PointValueTypeEnum`，统一明确本策略的 `P0-P6` 仅按角色化点位规则取值。
- 更新规格表述、示例和任务，使相邻线段计数规则与角色化点位语义成为唯一有效定义。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mt5-kline-pattern-detection`: 将完整匹配中的历史结构过滤从 `tspanmin` 分钟阈值改为“相邻线段数量上限”，并移除对 `PointValueTypeEnum` 的依赖。
- `mt5-role-based-point-pricing`: 删除“角色化点位优先于统一点位取值模式”的过渡性语义，收敛为 `P0-P6` 仅使用角色化点位取值。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5` 中 `InpTSpanMinConf`、`InpPointValueType`、`PointValueTypeEnum`、`CondE` 与历史骨架过滤逻辑。
- Affected behavior: 历史模式是否被视为完整匹配，将由“分钟阈值”改为“4 段中最多允许多少段相邻”；点位取值将不再暴露无效的统一模式配置。
- Validation: 需要验证 `InpMaxAdjustPointSpan` 能按 `P0-P1`、`P1-P2`、`P2-P3`、`P3-P4` 的相邻段数量过滤模式，并确认移除 `InpPointValueType` 后所有点位仍按角色化规则取值。
