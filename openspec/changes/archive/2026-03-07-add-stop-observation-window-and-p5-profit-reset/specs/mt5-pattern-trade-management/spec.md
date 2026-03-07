## MODIFIED Requirements

### Requirement: 仅在入场后确认条件满足时激活弱止损
策略 SHALL 在入场时保持弱止损未激活。只有在持仓首次出现满足 `e >= n * (c + d)` 的合格 `P5/P6` 候选集合时，策略才 SHALL 执行一次性激活流程：从该时刻全部合格 `P5` 候选中选择价格最低的 `selectedP5`，按 `soft_loss_price = InpSoftLossC * selectedP5` 激活弱止损，并同时将止盈价改写为 `profit_price = selectedP5 + InpP5AnchoredProfitC * (a+b1+b2)`。一旦完成这次首次激活，策略 SHALL 冻结该持仓的 `selectedP5`、`soft_loss_price` 和 `profit_price`，后续新的 `P5/P6` 组合 SHALL NOT 再次改写这些价位。

#### Scenario: 首次满足条件时同时激活弱止损并改写止盈价
- **WHEN** 一个由 EA 管理的持仓首次观测到合格 `P5/P6` 候选集合，且满足 `e >= n * (c + d)`
- **THEN** 策略从该时刻全部合格 `P5` 候选中选择价格最低的 `selectedP5`，并一次性同时设置弱止损价与 `P5` 锚定止盈价

#### Scenario: 多个合格 P5 候选时选择最低价 P5
- **WHEN** 一个由 EA 管理的持仓在首次满足激活条件的时刻存在多个都可构成合格 `P5/P6` 的 `P5` 候选
- **THEN** 策略选择其中价格最低的 `P5` 作为 `selectedP5`

#### Scenario: 首次激活后后续新的 P5P6 组合不再改写价位
- **WHEN** 某个持仓已经完成首次 `P5/P6` 激活并冻结了 `selectedP5`
- **THEN** 策略不会因为后续新的 `P5/P6` 组合再次调整该持仓的弱止损价或止盈价

#### Scenario: 后续结构不足时弱止损与止盈重设保持未激活
- **WHEN** 一个由 EA 管理的持仓尚未首次满足 `P5/P6` 激活条件
- **THEN** 策略继续沿用初始止盈价管理该持仓，且弱止损价位保持未激活

### Requirement: 在强止损、弱止损或止盈触发时平仓
策略 SHALL 在当前价格触及或穿越有效强止损、有效弱止损或当前生效的止盈价时，以当前市场可执行价格关闭 EA 管理的持仓。如果强止损和弱止损同时有效，则任意一个触发都 SHALL 足以进入平仓流程。止盈价在首次 `P5/P6` 激活前 SHALL 使用入场阶段推导的初始止盈价，在首次 `P5/P6` 激活后 SHALL 改为使用 `P5` 锚定止盈价。

#### Scenario: 强止损触发平仓
- **WHEN** 某个由 EA 管理的多头持仓的当前价格触及或跌破 `hard_loss_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: 初始止盈价触发平仓
- **WHEN** 某个持仓尚未完成首次 `P5/P6` 激活，且当前价格触及或突破其入场阶段推导的初始 `profit_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: P5 锚定止盈价触发平仓
- **WHEN** 某个持仓已经完成首次 `P5/P6` 激活，且当前价格触及或突破其 `P5` 锚定止盈价
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: 弱止损激活后触发平仓
- **WHEN** 弱止损已经激活，且当前价格触及或跌破 `soft_loss_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

### Requirement: 止盈或止损后进入观察期并阻止新的买单
策略 SHALL 为每个 `symbol + timeframe` 分别维护止盈观察窗口和止损观察窗口。某个由 EA 管理的买单因 `profit_target` 成功平仓后，策略 SHALL 立即启动止盈观察窗口；某个由 EA 管理的买单因 `hard_stop` 或 `soft_stop` 成功平仓后，策略 SHALL 立即启动止损观察窗口。两种观察窗口都 SHALL 从对应平仓所在的当前 bar 开始生效，并覆盖该 bar 的剩余时间以及其后连续配置 bar 数量的完整 K 线。在任意一个观察窗口尚未结束期间，策略 SHALL 不再为该 `symbol + timeframe` 提交新的买单。观察窗口只 SHALL 影响新的买单入场，已有持仓的止盈止损管理 SHALL NOT 因观察窗口而停用。策略在观察期阻止入场时也 SHALL 输出独立日志，明确说明是止盈观察窗口还是止损观察窗口导致的阻止。

#### Scenario: 止盈观察窗口有效时阻止新买单
- **WHEN** 某个 `symbol + timeframe` 仍处于最近一次 `profit_target` 平仓触发的止盈观察窗口内
- **THEN** 策略不会再为该 `symbol + timeframe` 提交新的买单

#### Scenario: 止损观察窗口有效时阻止新买单
- **WHEN** 某个 `symbol + timeframe` 仍处于最近一次 `hard_stop` 或 `soft_stop` 平仓触发的止损观察窗口内
- **THEN** 策略不会再为该 `symbol + timeframe` 提交新的买单

#### Scenario: 双观察窗口并联时任一有效都阻止新买单
- **WHEN** 某个 `symbol + timeframe` 同时存在止盈观察窗口和止损观察窗口，且其中任意一个仍未结束
- **THEN** 策略仍然阻止该 `symbol + timeframe` 的新买单进入后续开仓流程

#### Scenario: 观察窗口不影响已有持仓继续退出
- **WHEN** 某个 `symbol + timeframe` 正处于止盈观察窗口或止损观察窗口内，但账户中仍有该品种的其他由 EA 管理的未平仓持仓
- **THEN** 策略继续按强止损、弱止损和当前生效止盈价管理这些已有持仓

#### Scenario: 观察窗口结束后恢复允许入场
- **WHEN** 当前 `symbol + timeframe` 已经同时超过最近一次止盈观察窗口和止损观察窗口所覆盖的 bar 范围
- **THEN** 策略恢复允许该 `symbol + timeframe` 的新买单继续进入后续入场门控
