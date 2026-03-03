## MODIFIED Requirements

### Requirement: 仅在入场后确认条件满足时激活弱止损
策略 SHALL 在入场时保持弱止损未激活。只有在入场后走势形成 `S_P4P5` 和 `S_P5P6` 且 `e >= n * (c + d)` 时，策略才 SHALL 激活 `soft_loss_price`，其中 `soft_loss_price = softLossC * Price_P5`。本变更对应的运行时默认参数 SHALL 将 `InpMinP5P6ReboundRatioOfP3P5Drop` 设为 `0.65`。

#### Scenario: 满足 SetSoftLoss 条件后启用弱止损
- **WHEN** 一个由 EA 管理的持仓在开仓后观测到 P5 和 P6，且 `S_P4P5`、`S_P5P6` 已匹配并满足 `e >= n * (c + d)`
- **THEN** 策略按 `softLossC * Price_P5` 激活弱止损价位

#### Scenario: 后续结构不足时弱止损保持未激活
- **WHEN** 一个由 EA 管理的持仓尚未同时满足两个 SetSoftLoss 条件
- **THEN** 策略继续管理该持仓，且弱止损价位保持未激活
