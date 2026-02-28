## ADDED Requirements

### Requirement: 基于完整匹配形态触发买入交易
策略 SHALL 仅在收到完整匹配的模式快照后创建买入交易机会。交易参考入场价 SHALL 为匹配得到的 P4 价格，并且策略 SHALL 在发单前推导 `hard_loss_price = entry_price - hardlossC * a` 与 `profit_price = entry_price + profitC * a`。

#### Scenario: 交易价位由 P4 和 a 推导
- **WHEN** 检测器输出一条完整模式匹配
- **THEN** 策略使用匹配得到的 P4 价格和计算出的 `a` 区间推导入场价、强止损价和止盈价

### Requirement: 仅在入场后确认条件满足时激活弱止损
策略 SHALL 在入场时保持弱止损未激活。只有在入场后走势形成 `S_P4P5` 和 `S_P5P6` 且 `(e - d) >= n * c` 时，策略才 SHALL 激活 `soft_loss_price`，其中 `soft_loss_price = softLossC * Price_P5`。

#### Scenario: 满足 SetSoftLoss 条件后启用弱止损
- **WHEN** 一个由 EA 管理的持仓在开仓后观测到 P5 和 P6，且 `S_P4P5`、`S_P5P6` 已匹配并满足 `(e - d) >= n * c`
- **THEN** 策略按 `softLossC * Price_P5` 激活弱止损价位

#### Scenario: 后续结构不足时弱止损保持未激活
- **WHEN** 一个由 EA 管理的持仓尚未同时满足两个 SetSoftLoss 条件
- **THEN** 策略继续管理该持仓，且弱止损价位保持未激活

### Requirement: 在强止损、弱止损或止盈触发时平仓
策略 SHALL 在当前价格触及或穿越有效强止损、有效弱止损或止盈价时，以当前市场可执行价格关闭 EA 管理的持仓。如果强止损和弱止损同时有效，则任意一个触发都 SHALL 足以进入平仓流程。

#### Scenario: 强止损触发平仓
- **WHEN** 某个由 EA 管理的多头持仓的当前价格触及或跌破 `hard_loss_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: 止盈触发平仓
- **WHEN** 某个由 EA 管理的多头持仓的当前价格触及或突破 `profit_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: 弱止损激活后触发平仓
- **WHEN** 弱止损已经激活，且当前价格触及或跌破 `soft_loss_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

### Requirement: 记录匹配变量和交易生命周期日志
策略 SHALL 在每次发起交易时输出匹配点位价格、点位时间、空间变量、时间变量以及衍生交易价位。策略在持仓平仓时也 SHALL 记录出场原因和实际成交价格。

#### Scenario: 开仓日志包含完整模式快照
- **WHEN** 策略基于一次匹配形态提交买单
- **THEN** 日志输出包含用于本次决策的点位信息、空间变量、时间变量和衍生风控价位

#### Scenario: 平仓日志记录出场原因
- **WHEN** 策略关闭一个由 EA 管理的持仓
- **THEN** 日志输出包含此次平仓是由强止损、弱止损还是止盈触发，以及实际平仓成交价
