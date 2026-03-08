# mt5-pattern-trade-management Specification

## Purpose
TBD - created by archiving change add-mt5-kline-pattern-strategy. Update Purpose after archive.
## Requirements
### Requirement: 基于完整匹配形态触发买入交易
策略 SHALL 仅在收到完整匹配的模式快照后创建买入交易机会。交易参考入场价 SHALL 为匹配得到的 P4 价格，并且策略 SHALL 在发单前仅推导 `hard_loss_price = P0` 点位值，而 SHALL NOT 在入场阶段生成任何已激活的止盈价。对于同一个 `symbol + timeframe` 的当前 `P4` 所属未收盘 K 线周期，策略 SHALL 最多只允许一次成功创建新的由 EA 管理的多头仓位；只有在开仓流程最终确认新仓位已经存在并被纳入 EA 管理后，策略才 SHALL 将该 bar 标记为已消耗。如果本次尝试在创建受管仓位之前被噪声过滤、风控检查或经纪商拒单阻止，策略 SHALL 不锁定当前 bar，并允许同一 bar 后续新的有效尝试继续进入开仓流程。与此同时，如果多个不同的 `P4` K 线柱与更早某个已成功骨架在 `P0/P1/P2/P3` 中任意一个同角色历史点位重叠，即 `P0==P0 || P1==P1 || P2==P2 || P3==P3`，则策略 SHALL 在该骨架首次成功创建受管仓位之前允许这些后续 `P4` K 线柱继续尝试；一旦某个 `P4` K 线柱已经为该共享骨架成功创建过受管仓位，后续共享同一骨架的 `P4` K 线柱即使仍满足条件，也 SHALL 被直接阻止。不同角色点位即使落在同一根 K 线柱上，也 SHALL NOT 视为共享骨架命中。

#### Scenario: 交易价位由 P4 与 P0 推导入场和强止损
- **WHEN** 检测器输出一条完整模式匹配
- **THEN** 策略使用匹配得到的 P4 价格与 P0 点位值推导入场价和强止损价，且开仓时不激活止盈价

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
策略 SHALL 在入场时保持弱止损和止盈都未激活。只有在持仓首次出现满足 `e >= n * (c + d)` 的合格 `P5/P6` 候选集合时，策略才 SHALL 执行一次性激活流程：从该时刻全部合格 `P5` 候选中选择价格最低的 `selectedP5`，按 `soft_loss_price = InpSoftLossC * selectedP5` 激活弱止损，并同时按 `profit_price = selectedP5 + InpP5AnchoredProfitC * (a+b1+b2)` 激活唯一止盈价。一旦完成这次首次激活，策略 SHALL 冻结该持仓的 `selectedP5`、`soft_loss_price` 和 `profit_price`，后续新的 `P5/P6` 组合 SHALL NOT 再次改写这些价位。

#### Scenario: 首次满足条件时同时激活弱止损和唯一止盈价
- **WHEN** 一个由 EA 管理的持仓首次观测到合格 `P5/P6` 候选集合，且满足 `e >= n * (c + d)`
- **THEN** 策略从该时刻全部合格 `P5` 候选中选择价格最低的 `selectedP5`，并一次性同时设置弱止损价与唯一止盈价

#### Scenario: 多个合格 P5 候选时选择最低价 P5
- **WHEN** 一个由 EA 管理的持仓在首次满足激活条件的时刻存在多个都可构成合格 `P5/P6` 的 `P5` 候选
- **THEN** 策略选择其中价格最低的 `P5` 作为 `selectedP5`

#### Scenario: 首次激活后后续新的 P5P6 组合不再改写价位
- **WHEN** 某个持仓已经完成首次 `P5/P6` 激活并冻结了 `selectedP5`
- **THEN** 策略不会因为后续新的 `P5/P6` 组合再次调整该持仓的弱止损价或止盈价

#### Scenario: 后续结构不足时弱止损和止盈保持未激活
- **WHEN** 一个由 EA 管理的持仓尚未首次满足 `P5/P6` 激活条件
- **THEN** 策略继续仅按强止损管理该持仓，且弱止损价与止盈价都保持未激活

### Requirement: 在强止损、弱止损或止盈触发时平仓
策略 SHALL 在当前价格触及或穿越有效强止损、有效弱止损或当前生效的止盈价时，以当前市场可执行价格关闭 EA 管理的持仓。如果强止损和弱止损同时有效，则任意一个触发都 SHALL 足以进入平仓流程。强止损 SHALL 从持仓创建时立即生效；弱止损和止盈价 SHALL 只有在首次 `P5/P6` 激活完成后才生效。

#### Scenario: 强止损触发平仓
- **WHEN** 某个由 EA 管理的多头持仓的当前价格触及或跌破 `hard_loss_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: 唯一止盈价触发平仓
- **WHEN** 某个持仓已经完成首次 `P5/P6` 激活，且当前价格触及或突破其生效中的 `profit_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: 弱止损激活后触发平仓
- **WHEN** 弱止损已经激活，且当前价格触及或跌破 `soft_loss_price`
- **THEN** 策略以当前可执行市场价为该持仓提交平仓订单

#### Scenario: 未激活止盈时不得触发 profit_target
- **WHEN** 某个由 EA 管理的持仓尚未完成首次 `P5/P6` 激活
- **THEN** 策略不会仅因为当前价格上涨而按 `profit_target` 关闭该持仓

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

### Requirement: 记录匹配变量和交易生命周期日志
策略 SHALL 在每次成功创建由 EA 管理的买入持仓时输出一条精简的 `P4` 买点摘要日志。该摘要日志 SHALL 聚焦本次买点所使用的模式，并明确包含 `symbol`、`ticket`、`p4_bar`、成交价、`hard_loss_price` 以及 `P0/P1/P2/P3/P4` 各点的时间与价格。默认输出 SHALL NOT 再为入场阻止、观察窗口阻止、共享骨架阻止、首次 `P5/P6` 激活和平仓生命周期打印详细的常规摘要日志；这些非买点日志如果保留，也 MUST 不影响“成功买点日志是默认主输出”的原则。

#### Scenario: 成功买入时输出精简 P4 买点摘要
- **WHEN** 策略成功创建一笔由 EA 管理的买入持仓
- **THEN** 策略输出一条精简日志，明确给出本次买点对应的 `P0-P4` 时间与价格

#### Scenario: 默认不再输出入场阻止类详细日志
- **WHEN** 某个候选因为观察窗口、共享骨架、同 bar 锁或持仓上限而未能进入成功买入
- **THEN** 策略默认不再为这些常规阻止原因输出详细摘要日志

#### Scenario: 默认不再输出常规持仓生命周期摘要日志
- **WHEN** 某个持仓进入首次 `P5/P6` 激活、`hard_stop`、`soft_stop` 或 `profit_target` 生命周期事件
- **THEN** 策略默认不再为这些常规生命周期事件输出详细摘要日志

#### Scenario: 多次成功买入分别输出独立买点摘要
- **WHEN** 同一品种周期后续又出现新的成功买入
- **THEN** 每一笔成功买入都输出各自独立的一条 `P4` 买点摘要日志，且日志中的 `P0-P4` 信息与对应成交保持一致
