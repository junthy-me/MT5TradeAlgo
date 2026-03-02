# mt5-pattern-trade-management Specification

## Purpose
TBD - created by archiving change add-mt5-kline-pattern-strategy. Update Purpose after archive.
## Requirements
### Requirement: 基于完整匹配形态触发买入交易
策略 SHALL 仅在收到完整匹配的模式快照后创建买入交易机会。交易参考入场价 SHALL 为匹配得到的 P4 价格，并且策略 SHALL 在发单前推导 `hard_loss_price = P0` 点位值与 `profit_price = entry_price + InpProfitC * (b1+b2+a)`。此外，对于同一个 `symbol + timeframe` 的当前 `P4` 所属未收盘 K 线周期，策略 SHALL 最多只允许一次成功创建新的由 EA 管理的多头仓位；只有在开仓流程最终确认新仓位已经存在并被纳入 EA 管理后，策略才 SHALL 将该 bar 标记为已消耗。如果本次尝试在创建受管仓位之前被噪声过滤、风控检查或经纪商拒单阻止，策略 SHALL 不锁定当前 bar，并允许同一 bar 后续新的有效尝试继续进入开仓流程。与此同时，如果多个不同的 `P4` K 线柱与更早某个已成功骨架在 `P0/P1/P2/P3` 中任意一个同角色历史点位重叠，即 `P0==P0 || P1==P1 || P2==P2 || P3==P3`，则策略 SHALL 在该骨架首次成功创建受管仓位之前允许这些后续 `P4` K 线柱继续尝试；一旦某个 `P4` K 线柱已经为该共享骨架成功创建过受管仓位，后续共享同一骨架的 `P4` K 线柱即使仍满足条件，也 SHALL 被直接阻止。不同角色点位即使落在同一根 K 线柱上，也 SHALL NOT 视为共享骨架命中。

#### Scenario: 交易价位由 P4、P0 和整体结构振幅推导
- **WHEN** 检测器输出一条完整模式匹配
- **THEN** 策略使用匹配得到的 P4 价格、P0 点位值以及 `a`、`b1`、`b2` 推导入场价、强止损价和止盈价

#### Scenario: 同一 P4 当前 bar 仅首次成功开仓
- **WHEN** 某个 `symbol + timeframe` 在当前未收盘 `P4` bar 内已经成功创建过一笔由 EA 管理的新仓位
- **THEN** 策略不会在该 bar 剩余时间内再次为同一 `symbol + timeframe` 提交新的买单

#### Scenario: 同一 P4 当前 bar 内失败尝试不锁定 bar
- **WHEN** 某次候选入场在当前未收盘 `P4` bar 内通过了模式匹配，但在受管仓位创建完成前被噪声过滤、风控检查或经纪商拒单阻止
- **THEN** 策略保持该 `P4` bar 可再次尝试开仓，并允许后续仍在该 bar 内的有效候选继续进入开仓流程

#### Scenario: 只共享一个同角色历史点位也视为共享骨架
- **WHEN** 当前候选 `P4` 所依赖的 `P0/P1/P2/P3` 与更早某个已成功骨架相比，仅有其中一个同角色历史点位时间相同
- **THEN** 策略仍将它们视为共享骨架，而不要求四个历史点位全部相同

#### Scenario: 跨角色共享同一根 K 线柱不视为共享骨架
- **WHEN** 当前候选骨架中的某个历史点位时间仅与更早已成功骨架的不同角色点位时间相同，例如当前 `P1` 时间等于更早骨架的 `P2` 时间
- **THEN** 策略不会仅因为这类跨角色时间相同就把它们视为共享骨架

#### Scenario: 共享任一点位的骨架在首次成功后后续 P4 bar 不再下单
- **WHEN** 当前候选 `P4` 与更早某个已经成功创建受管仓位的骨架在 `P0/P1/P2/P3` 中任意一个历史点位重叠，且当前已经进入更晚的 `P4` K 线柱
- **THEN** 策略不会再为该共享骨架的后续 `P4` K 线柱提交新的买单

### Requirement: 仅在入场后确认条件满足时激活弱止损
策略 SHALL 在入场时保持弱止损未激活。只有在入场后走势形成 `S_P4P5` 和 `S_P5P6` 且 `e >= n * (c + d)` 时，策略才 SHALL 激活 `soft_loss_price`，其中 `soft_loss_price = softLossC * Price_P5`。本变更对应的运行时默认参数 SHALL 将 `InpSoftLossN` 设为 `0.65`。

#### Scenario: 满足 SetSoftLoss 条件后启用弱止损
- **WHEN** 一个由 EA 管理的持仓在开仓后观测到 P5 和 P6，且 `S_P4P5`、`S_P5P6` 已匹配并满足 `e >= n * (c + d)`
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

### Requirement: 止盈后进入盈利观察期并阻止新的买单
策略 SHALL 在某个 `symbol + timeframe` 的 EA 管理买单因 `profit_target` 成功平仓后，立即为该 `symbol + timeframe` 启动盈利观察期。盈利观察期 SHALL 从该次盈利平仓所在的当前 bar 开始生效，并覆盖该 bar 的剩余时间以及其后连续 `InpProfitObservationBars` 根完整 K 线；在此期间，策略 SHALL 不再为该 `symbol + timeframe` 提交新的买单。盈利观察期仅 SHALL 由 `profit_target` 平仓触发，`hard_stop`、`soft_stop`、手动平仓或非 EA 平仓 SHALL NOT 启动该门控。策略在观察期阻止入场时也 SHALL 输出独立日志，说明这是止盈后观察期阻止，而不是 `P4` 同 bar 锁、共享骨架成功锁或持仓上限导致的阻止。

#### Scenario: 止盈后当前 bar 与后续观察窗口内阻止新买单
- **WHEN** 某个 `symbol + timeframe` 的 EA 管理买单刚刚因 `profit_target` 成功平仓，且当前扫描仍处于该盈利平仓所在 bar 或之后 `InpProfitObservationBars` 根完整 bar 之内
- **THEN** 策略不会再为该 `symbol + timeframe` 提交新的买单

#### Scenario: 非止盈平仓不触发观察期
- **WHEN** 某个由 EA 管理的持仓因 `hard_stop`、`soft_stop` 或其他非 `profit_target` 原因平仓
- **THEN** 策略不会因此启动盈利观察期

#### Scenario: 观察窗口结束后恢复允许入场
- **WHEN** 当前 `symbol + timeframe` 已经超过最近一次 `profit_target` 平仓所在 bar 之后的 `InpProfitObservationBars` 根完整 K 线
- **THEN** 策略恢复允许该 `symbol + timeframe` 的新买单继续进入后续入场门控

### Requirement: 记录匹配变量和交易生命周期日志
策略 SHALL 在每次发起交易时输出匹配点位价格、点位时间、空间变量、时间变量以及衍生交易价位。策略在持仓平仓时也 SHALL 记录出场原因和实际成交价格。

#### Scenario: 开仓日志包含完整模式快照
- **WHEN** 策略基于一次匹配形态提交买单
- **THEN** 日志输出包含用于本次决策的点位信息、空间变量、时间变量和衍生风控价位

#### Scenario: 平仓日志记录出场原因
- **WHEN** 策略关闭一个由 EA 管理的持仓
- **THEN** 日志输出包含此次平仓是由强止损、弱止损还是止盈触发，以及实际平仓成交价
