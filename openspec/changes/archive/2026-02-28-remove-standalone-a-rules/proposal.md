## Why

当前 MT5 P4 模式策略在多个条件判断、噪声过滤和风控价格推导中单独使用 `a` 作为独立尺度，这会引入较多边界情况并增加策略理解与维护复杂度。现在需要将策略简化为“保留 `a` 作为空间变量与调试信息，但不再让 `a` 单独参与独立条件判断或独立风控定价”。

## What Changes

- 调整匹配条件，使 `CondB` 改为基于 `r1` 的单阈值条件，删除 `CondD`，删除 `CondG`，并将 `CondH` 改为基于 `(b1+b2)` 与买价的百分比过滤。
- 调整风控与价格推导，使强止损价直接等于 `P0` 点位值，止盈价改为基于 `(b1+b2+a)` 的整体结构振幅推导。
- 保留 `a` 的计算、时间变量和日志输出，但不再将 `a` 作为独立规则门槛或独立止损/止盈尺度。
- 删除本次变更废弃的参数，并新增替代参数 `InpRatioC`、`NoiseFilter_bSumValueCompBuyPricePercent`，同时调整 `InpProfitC` 默认值。

## Capabilities

### New Capabilities
- `mt5-pattern-a-simplification`: 为 MT5 P4 模式策略定义“去掉 a 的单独使用”后的匹配条件、风控推导、日志和参数规则。

### Modified Capabilities
- None.

## Impact

- 影响 MT5 EA 的条件判定、噪声过滤、止损止盈推导、输入参数和日志输出。
- 影响回测结果与已有参数配置，需要重新验证入场分布、止损止盈命中率和日志字段含义。
