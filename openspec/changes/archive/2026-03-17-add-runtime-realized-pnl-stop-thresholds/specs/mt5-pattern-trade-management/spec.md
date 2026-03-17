## ADDED Requirements

### Requirement: 达到运行期累计已实现盈亏阈值后停止新的自动开仓
策略 SHALL 在本次 EA 运行期内维护一组全局已实现盈亏金额统计，该统计范围 SHALL 仅包含由本 EA 管理、并且已经成功关闭的交易结果。策略 SHALL 以账户货币累计 `gross_profit_money`、`gross_loss_money` 和 `net_realized_money = gross_profit_money - gross_loss_money`，并仅 SHALL 以这些“已闭仓已实现”金额作为运行期停止门控的判断依据，而 SHALL NOT 把未平仓浮盈浮亏纳入统计。若 `InpMaxProfitStopMoney > 0` 且 `net_realized_money >= InpMaxProfitStopMoney`，策略 SHALL 进入“停止新的自动开仓”状态；若 `InpMaxLossStopMoney > 0` 且 `gross_loss_money - gross_profit_money >= InpMaxLossStopMoney`，策略 SHALL 同样进入该状态。进入该状态后，策略 SHALL 在本次运行剩余时间内拒绝任何新的受管开仓，但 SHALL 继续按既有强止损、弱止损、止盈和观察窗口逻辑管理已有持仓，且该状态 SHALL NOT 自动恢复。

#### Scenario: 达到最大盈利停止阈值后拒绝新的自动开仓
- **WHEN** 本 EA 本次运行内的 `net_realized_money` 首次达到或超过 `InpMaxProfitStopMoney`，且 `InpMaxProfitStopMoney > 0`
- **THEN** 策略停止新的自动开仓

#### Scenario: 达到最大亏损停止阈值后拒绝新的自动开仓
- **WHEN** 本 EA 本次运行内的 `gross_loss_money - gross_profit_money` 首次达到或超过 `InpMaxLossStopMoney`，且 `InpMaxLossStopMoney > 0`
- **THEN** 策略停止新的自动开仓

#### Scenario: 停止状态不影响已有持仓继续退出
- **WHEN** 策略已经进入“停止新的自动开仓”状态，但账户中仍存在由本 EA 管理的未平仓持仓
- **THEN** 策略继续按强止损、弱止损和当前生效止盈价管理这些已有持仓

#### Scenario: 停止状态在本次运行内不会自动恢复
- **WHEN** 策略已经因达到最大盈利停止阈值或最大亏损停止阈值进入停止状态
- **THEN** 即使后续已有仓位继续平仓并改变累计结果，策略也不会在本次运行内重新允许新的自动开仓

### Requirement: 触发运行期停止时记录原因和摘要日志
策略 SHALL 在运行期停止门控首次触发时打印一次结构化原因日志和一次结构化摘要日志。原因日志 SHALL 明确区分 `max_profit_threshold` 与 `max_loss_threshold` 两种停止原因。摘要日志 SHALL 至少包含触发原因、`gross_profit_money`、`gross_loss_money`、`net_realized_money`、`InpMaxProfitStopMoney`、`InpMaxLossStopMoney`、`matched_patterns`、`closed_trades`、`winning_trades` 和 `losing_trades`。这两条日志都 SHALL 只在停止状态首次触发时打印一次；其后已有持仓继续平仓时，策略 MAY 继续输出常规 `EXIT` 日志，但 SHALL NOT 重复打印运行期停止摘要。

#### Scenario: 盈利阈值触发时打印停止原因和摘要
- **WHEN** 策略首次因达到最大盈利停止阈值进入停止状态
- **THEN** 策略打印一次 `max_profit_threshold` 原因日志和一次停止摘要日志

#### Scenario: 亏损阈值触发时打印停止原因和摘要
- **WHEN** 策略首次因达到最大亏损停止阈值进入停止状态
- **THEN** 策略打印一次 `max_loss_threshold` 原因日志和一次停止摘要日志

#### Scenario: 已停止后不得重复打印停止摘要
- **WHEN** 策略已经打印过运行期停止原因和摘要日志
- **THEN** 后续轮询和已有仓位平仓不会再次打印这两条停止日志
