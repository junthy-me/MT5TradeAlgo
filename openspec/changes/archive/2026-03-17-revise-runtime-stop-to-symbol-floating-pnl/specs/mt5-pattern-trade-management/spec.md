## MODIFIED Requirements

### Requirement: 达到运行期累计已实现盈亏阈值后停止新的自动开仓
策略 SHALL 为每个 `symbol + timeframe` 维护一组运行期金额状态，并以该品种“已实现盈亏 + 当前浮动盈亏”的总结果作为 stop 判断依据。已实现部分 SHALL 仅包含由本 EA 管理、并且已经成功关闭的该品种交易结果，按账户货币累计 `gross_realized_profit_money`、`gross_realized_loss_money` 和 `net_realized_money = gross_realized_profit_money - gross_realized_loss_money`。浮动部分 SHALL 来自该品种当前所有由本 EA 管理的未平仓仓位实时金额，记为 `floating_money`。策略 SHALL 计算 `total_net_money = net_realized_money + floating_money`。若 `InpMaxProfitStopMoney > 0` 且 `total_net_money >= InpMaxProfitStopMoney`，策略 SHALL 触发该品种的最大盈利 stop；若 `InpMaxLossStopMoney > 0` 且 `-total_net_money >= InpMaxLossStopMoney`，策略 SHALL 触发该品种的最大亏损 stop。任一 stop 触发时，策略 SHALL 立即尝试平掉该品种全部由本 EA 管理的未平仓仓位，并在本次运行剩余时间内拒绝该品种新的受管开仓。该 stopped 状态 SHALL NOT 自动恢复。

#### Scenario: 达到最大盈利停止阈值后平掉当前品种全部受管仓位
- **WHEN** 某个 `symbol + timeframe` 的 `total_net_money` 首次达到或超过 `InpMaxProfitStopMoney`，且 `InpMaxProfitStopMoney > 0`
- **THEN** 策略立即尝试平掉该品种全部由本 EA 管理的未平仓仓位，并停止该品种新的自动开仓

#### Scenario: 达到最大亏损停止阈值后平掉当前品种全部受管仓位
- **WHEN** 某个 `symbol + timeframe` 的 `-total_net_money` 首次达到或超过 `InpMaxLossStopMoney`，且 `InpMaxLossStopMoney > 0`
- **THEN** 策略立即尝试平掉该品种全部由本 EA 管理的未平仓仓位，并停止该品种新的自动开仓

#### Scenario: 浮动盈亏参与 stop 判断
- **WHEN** 某个品种的已实现盈亏尚未达到阈值，但加上当前未平仓仓位的浮动盈亏后 `total_net_money` 达到对应 stop 阈值
- **THEN** 策略仍然触发该品种 stop，并按规则尝试平掉该品种全部受管仓位

#### Scenario: 某个品种 stopped 后不影响其他品种继续运行
- **WHEN** 某个交易品种已经进入 stopped 状态
- **THEN** 策略仅拒绝该品种新的受管开仓，其他未触发 stop 的配置品种仍可继续按原规则检测与交易

#### Scenario: stopped 状态在本次运行内不会自动恢复
- **WHEN** 某个品种已经因达到最大盈利停止阈值或最大亏损停止阈值进入 stopped 状态
- **THEN** 即使其后该品种仓位都已平掉，策略也不会在本次运行内重新允许该品种新的自动开仓

### Requirement: 触发运行期停止时记录原因和摘要日志
策略 SHALL 在某个品种运行期 stop 首次触发时打印一次结构化原因日志和一次结构化摘要日志。原因日志 SHALL 明确区分 `max_profit_threshold` 与 `max_loss_threshold` 两种停止原因，并给出 `symbol`。摘要日志 SHALL 至少包含 `symbol`、触发原因、`gross_realized_profit_money`、`gross_realized_loss_money`、`net_realized_money`、`floating_money`、`total_net_money`、`InpMaxProfitStopMoney` 和 `InpMaxLossStopMoney`。这两条日志都 SHALL 只在该品种 stopped 状态首次触发时打印一次；其后该品种已有仓位继续关闭时，策略 MAY 继续输出常规 `EXIT` 日志，但 SHALL NOT 重复打印该品种运行期 stop 摘要。

#### Scenario: 盈利阈值触发时打印按品种 stop 原因和摘要
- **WHEN** 某个品种首次因达到最大盈利停止阈值进入 stopped 状态
- **THEN** 策略打印一次该品种的 `max_profit_threshold` 原因日志和一次 stop 摘要日志

#### Scenario: 亏损阈值触发时打印按品种 stop 原因和摘要
- **WHEN** 某个品种首次因达到最大亏损停止阈值进入 stopped 状态
- **THEN** 策略打印一次该品种的 `max_loss_threshold` 原因日志和一次 stop 摘要日志

#### Scenario: 已 stopped 后不得重复打印 stop 摘要
- **WHEN** 某个品种已经打印过运行期 stop 原因和摘要日志
- **THEN** 后续轮询和该品种已有仓位平仓不会再次打印这两条 stop 日志
