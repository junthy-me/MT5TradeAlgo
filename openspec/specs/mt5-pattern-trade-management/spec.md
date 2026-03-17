# mt5-pattern-trade-management Specification

## Purpose
TBD - created by archiving change add-mt5-kline-pattern-strategy. Update Purpose after archive.
## Requirements
### Requirement: 基于完整匹配形态触发买入交易
策略 SHALL 仅在收到完整匹配的模式快照后创建与该快照方向一致的交易机会。多头匹配 SHALL 创建新的由 EA 管理的多头仓位，空头镜像匹配 SHALL 创建新的由 EA 管理的空头仓位。交易参考入场价 SHALL 为匹配得到的 `P4` 价格，并且策略 SHALL 在发单前仅推导 `hard_loss_price = P0` 点位值，而 SHALL NOT 在入场阶段生成任何已激活的止盈价。对于同一个 `symbol + timeframe` 的当前 `P4` 所属未收盘 K 线周期，策略 SHALL 最多只允许一次成功创建新的由 EA 管理的仓位；该限制 SHALL 在 `LONG_ONLY`、`SHORT_ONLY` 和 `BOTH` 三种模式下共享生效，而不是按方向拆分。与此同时，如果多个不同的 `P4` K 线柱与更早某个已成功骨架在 `P0/P1/P2/P3` 中任意一个同角色历史点位重叠，则策略 SHALL 在该骨架首次成功创建受管仓位之前允许这些后续 `P4` K 线柱继续尝试；一旦某个 `P4` K 线柱已经为该共享骨架成功创建过受管仓位，后续共享同一骨架的 `P4` K 线柱即使方向不同，也 SHALL 被直接阻止。

#### Scenario: 多头完整匹配创建买入交易
- **WHEN** 检测器输出一条多头完整模式匹配
- **THEN** 策略创建新的由 EA 管理的多头仓位，并使用 `P4` 与 `P0` 推导参考入场价和强止损价

#### Scenario: 空头完整匹配创建卖出交易
- **WHEN** 检测器输出一条空头完整模式匹配
- **THEN** 策略创建新的由 EA 管理的空头仓位，并使用 `P4` 与 `P0` 推导参考入场价和强止损价

#### Scenario: 当前 P4 bar 的成功开仓限制在多空之间共享
- **WHEN** 某个 `symbol + timeframe` 已经在当前未收盘 `P4` bar 内成功创建过一笔由 EA 管理的新仓位
- **THEN** 策略不会在该 bar 剩余时间内再次为同一 `symbol + timeframe` 提交新的多头或空头仓位

#### Scenario: 共享骨架成功锁在多空之间共享
- **WHEN** 当前候选与更早某个已经成功创建受管仓位的骨架在 `P0/P1/P2/P3` 中任意一个历史点位重叠
- **THEN** 策略不会再为该共享骨架的后续 `P4` K 线柱提交新的多头或空头仓位

### Requirement: 仅在入场后确认条件满足时激活弱止损
策略 SHALL 在入场时保持弱止损和止盈都未激活。入场完成后，策略 SHALL 基于该持仓之后的 tick 序列追踪 `P5/P6`，并只 SHALL 接受满足严格时间顺序 `tP4 < tP5 < tP6` 的事件组合。只有在持仓首次出现满足 `e >= InpP5P6ReboundMinRatioOfP3P5Drop * (c + d)` 的合格 `P5/P6` 候选集合时，策略才 SHALL 执行一次性激活流程：多头持仓从该时刻全部合格 `P5` 候选中选择价格最低的 `selectedP5`，空头持仓选择价格最高的 `selectedP5`；随后策略按 `soft_loss_price = InpSoftLossC * selectedP5` 激活弱止损，并同时按多头 `profit_price = selectedP5 + InpP5AnchoredProfitC * (a+b1+b2)`、空头 `profit_price = selectedP5 - InpP5AnchoredProfitC * (a+b1+b2)` 激活唯一止盈价。一旦完成这次首次激活，策略 SHALL 冻结该持仓的 `selectedP5`、`soft_loss_price` 和 `profit_price`，后续新的 `P5/P6` 组合 SHALL NOT 再次改写这些价位。

#### Scenario: 多头首次激活时选择最低价 P5
- **WHEN** 一个由 EA 管理的多头持仓首次观测到多个都可构成合格 `P5/P6` 的 `P5` 候选
- **THEN** 策略选择其中价格最低的 `P5` 作为 `selectedP5`

#### Scenario: 空头首次激活时选择最高价 P5
- **WHEN** 一个由 EA 管理的空头持仓首次观测到多个都可构成合格 `P5/P6` 的 `P5` 候选
- **THEN** 策略选择其中价格最高的 `P5` 作为 `selectedP5`

#### Scenario: 空头首次激活时按向下镜像公式生成止盈
- **WHEN** 一个由 EA 管理的空头持仓首次满足 `P5/P6` 激活条件
- **THEN** 策略使用 `selectedP5 - InpP5AnchoredProfitC * (a+b1+b2)` 生成唯一止盈价

#### Scenario: 后续结构不足时弱止损和止盈保持未激活
- **WHEN** 一个由 EA 管理的持仓尚未首次满足 `P5/P6` 激活条件
- **THEN** 策略继续仅按强止损管理该持仓，且弱止损价与止盈价都保持未激活

### Requirement: 在强止损、弱止损或止盈触发时平仓
策略 SHALL 在当前价格触及或穿越有效强止损、有效弱止损或当前生效的止盈价时，以当前市场可执行价格关闭 EA 管理的持仓。多头持仓 SHALL 以当前 `bid` 作为退出比较侧：`bid <= hard_loss_price` 或 `bid <= soft_loss_price` 时触发止损，`bid >= profit_price` 时触发止盈。空头持仓 SHALL 以当前 `ask` 作为退出比较侧：`ask >= hard_loss_price` 或 `ask >= soft_loss_price` 时触发止损，`ask <= profit_price` 时触发止盈。强止损 SHALL 从持仓创建时立即生效；弱止损和止盈价 SHALL 只有在首次 `P5/P6` 激活完成后才生效。

#### Scenario: 多头强止损触发平仓
- **WHEN** 某个由 EA 管理的多头持仓的当前 `bid` 触及或跌破 `hard_loss_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: 空头强止损触发平仓
- **WHEN** 某个由 EA 管理的空头持仓的当前 `ask` 触及或突破 `hard_loss_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: 空头唯一止盈价触发平仓
- **WHEN** 某个空头持仓已经完成首次 `P5/P6` 激活，且当前 `ask` 触及或跌破其生效中的 `profit_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: 未激活止盈时不得触发 profit_target
- **WHEN** 某个由 EA 管理的持仓尚未完成首次 `P5/P6` 激活
- **THEN** 策略不会仅因为当前价格朝有利方向运动而按 `profit_target` 关闭该持仓

### Requirement: 止盈或止损后进入观察期并阻止新的买单
策略 SHALL 为每个 `symbol + timeframe` 分别维护止盈观察窗口和止损观察窗口。某个由 EA 管理的仓位因 `profit_target` 成功平仓后，策略 SHALL 立即启动止盈观察窗口；某个由 EA 管理的仓位因 `hard_stop` 或 `soft_stop` 成功平仓后，策略 SHALL 立即启动止损观察窗口。两种观察窗口都 SHALL 从对应平仓所在的当前 bar 开始生效，并覆盖该 bar 的剩余时间以及其后连续配置 bar 数量的完整 K 线。在任意一个观察窗口尚未结束期间，策略 SHALL 不再为该 `symbol + timeframe` 提交新的受管仓位，且这一门控在多头与空头之间共享。观察窗口只 SHALL 影响新的入场，已有持仓的止盈止损管理 SHALL NOT 因观察窗口而停用。

#### Scenario: 多头止盈观察窗口会阻止后续空头入场
- **WHEN** 某个 `symbol + timeframe` 仍处于最近一次多头 `profit_target` 平仓触发的止盈观察窗口内
- **THEN** 策略不会再为该 `symbol + timeframe` 提交新的空头或多头仓位

#### Scenario: 空头止损观察窗口会阻止后续多头入场
- **WHEN** 某个 `symbol + timeframe` 仍处于最近一次空头 `hard_stop` 或 `soft_stop` 平仓触发的止损观察窗口内
- **THEN** 策略不会再为该 `symbol + timeframe` 提交新的多头或空头仓位

#### Scenario: 观察窗口不影响已有持仓继续退出
- **WHEN** 某个 `symbol + timeframe` 正处于止盈观察窗口或止损观察窗口内，但账户中仍有该品种的其他由 EA 管理的未平仓持仓
- **THEN** 策略继续按强止损、弱止损和当前生效止盈价管理这些已有持仓

### Requirement: 达到运行期累计已实现盈亏阈值后停止新的自动开仓
策略 SHALL 为每个 `symbol + timeframe` 维护一组运行期金额状态，并以该品种“已实现盈亏 + 当前浮动盈亏”的总结果作为 stop 判断依据。已实现部分 SHALL 仅包含由本 EA 管理、并且已经成功关闭的该品种交易结果，按账户货币累计 `gross_realized_profit_money`、`gross_realized_loss_money` 和 `net_realized_money = gross_realized_profit_money - gross_realized_loss_money`。浮动部分 SHALL 来自该品种当前所有由本 EA 管理的未平仓仓位实时金额，记为 `floating_money`，并 SHALL 按 `profit + swap + commission` 口径累计。策略 SHALL 计算 `total_net_money = net_realized_money + floating_money`。若 `InpMaxProfitStopMoney > 0` 且 `total_net_money >= InpMaxProfitStopMoney`，策略 SHALL 触发该品种的最大盈利 stop；若 `InpMaxLossStopMoney > 0` 且 `-total_net_money >= InpMaxLossStopMoney`，策略 SHALL 触发该品种的最大亏损 stop。任一 stop 触发时，策略 SHALL 立即尝试平掉该品种全部由本 EA 管理的未平仓仓位，并在本次运行剩余时间内拒绝该品种新的受管开仓。该 stopped 状态 SHALL NOT 自动恢复。

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

### Requirement: 记录匹配变量和交易生命周期日志
策略 SHALL 在每次成功创建由 EA 管理的仓位时输出一条精简的 `P4` 入场摘要日志。该摘要日志 SHALL 聚焦本次入场所使用的模式，并明确包含 `symbol`、`ticket`、`direction`、`p4_bar`、成交价、`hard_loss_price` 以及 `P0/P1/P2/P3/P4` 各点的时间与价格。默认输出 SHALL NOT 再为入场阻止、观察窗口阻止、共享骨架阻止、首次 `P5/P6` 激活和平仓生命周期打印详细的常规摘要日志；这些非入场日志如果保留，也 MUST 不影响“成功入场日志是默认主输出”的原则。

#### Scenario: 成功多头入场时输出带方向的摘要日志
- **WHEN** 策略成功创建一笔由 EA 管理的多头仓位
- **THEN** 策略输出一条精简日志，明确给出 `direction=long` 以及本次入场对应的 `P0-P4` 时间与价格

#### Scenario: 成功空头入场时输出带方向的摘要日志
- **WHEN** 策略成功创建一笔由 EA 管理的空头仓位
- **THEN** 策略输出一条精简日志，明确给出 `direction=short` 以及本次入场对应的 `P0-P4` 时间与价格
