# mt5-strategy-runtime-controls Specification

## Purpose
TBD - created by archiving change add-mt5-kline-pattern-strategy. Update Purpose after archive.
## Requirements
### Requirement: 支持可配置的多品种运行时输入项
策略 SHALL 暴露 `InpSymbols`、`InpTF`、`InpTimerMillSec`、`InpMagic`、`InpComment`、`InpFixedLots`、`InpMaxPositionsPerSymbol`、`InpSlippagePoints`、`InpProfitObservationBars`、`InpStopObservationBars`、`InpLookbackBars`、`InpAdjustPointMinSpanKNumber`、`InpAdjustPointMaxSpanKNumber`、`InpP1P2AValueSpaceMinPriceLimit`、`InpP1P2AValueTimeMinKNumberLimit`、`InpBSumValueMinRatioOfAValue`、`InpBSumValueMaxRatioOfAValue`、`InpPreCondPriorDeclineLookbackBars`、`InpPreCondPriorDeclineMinDropRatioOfStructure`、`InpPreCondPriorDeclineMinBarsBetweenPre0AndP0` 和 `InpP5AnchoredProfitC` 等运行时输入参数。`InpSymbols` SHALL 接受以分号分隔的交易品种列表，且运行时 SHALL 在解析后忽略空白项。`InpProfitObservationBars` SHALL 使用 bar 数量表示止盈后观察窗口长度；当其为 `0` 时，策略 SHALL 视为禁用止盈观察窗口；当其为正整数时，策略 SHALL 在对应 `symbol + timeframe` 的最近一次 `profit_target` 平仓后，按该 bar 数长度执行观察期门控。`InpStopObservationBars` SHALL 使用相同的 bar 计数语义表示止损后观察窗口长度；当其为 `0` 时，策略 SHALL 视为禁用止损观察窗口；当其为正整数时，策略 SHALL 在对应 `symbol + timeframe` 的最近一次 `hard_stop` 或 `soft_stop` 平仓后，按该 bar 数长度执行观察期门控。`InpAdjustPointMinSpanKNumber` 和 `InpAdjustPointMaxSpanKNumber` SHALL 共同定义相邻点之间中间间隔 K 线数量的最小/最大区间。`InpP5AnchoredProfitC` SHALL 作为首次 `P5/P6` 激活后唯一止盈公式的系数输入。策略 SHALL NOT 再暴露 `InpProfitC` 作为运行时输入参数。

#### Scenario: 运行时解析配置的品种列表
- **WHEN** 操作人员提供的 `InpSymbols` 中包含一个或多个以分号分隔的交易品种
- **THEN** 策略将其解析为独立的品种项，并将每个非空品种加入扫描队列

#### Scenario: 使用单品种持仓上限默认值
- **WHEN** 操作人员未显式覆盖 `InpMaxPositionsPerSymbol`
- **THEN** 策略使用默认值 `1`

#### Scenario: 使用历史回看默认值
- **WHEN** 操作人员未显式覆盖 `InpLookbackBars`
- **THEN** 策略使用默认值 `300`

#### Scenario: 使用最小跨度默认值
- **WHEN** 操作人员未显式覆盖 `InpAdjustPointMinSpanKNumber`
- **THEN** 策略使用默认值 `5`

#### Scenario: 使用最大跨度默认值
- **WHEN** 操作人员未显式覆盖 `InpAdjustPointMaxSpanKNumber`
- **THEN** 策略使用默认值 `35`

#### Scenario: 使用前置下跌搜索窗口默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorDeclineLookbackBars`
- **THEN** 策略使用默认值 `30`

#### Scenario: 使用 CondA 下限默认值
- **WHEN** 操作人员未显式覆盖 `InpCondAXMin`
- **THEN** 策略使用默认值 `0.5`

#### Scenario: 使用 CondA 上限默认值
- **WHEN** 操作人员未显式覆盖 `InpCondAXMax`
- **THEN** 策略使用默认值 `2.0`

#### Scenario: 使用前置下跌最小结构比例默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorDeclineMinDropRatioOfStructure`
- **THEN** 策略使用默认值 `0.7`

#### Scenario: 使用 Pre0 与 P0 最小 bar 间隔默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0`
- **THEN** 策略使用默认值 `0`

#### Scenario: 使用 a 的最小空间默认值
- **WHEN** 操作人员未显式覆盖 `InpP1P2AValueSpaceMinPriceLimit`
- **THEN** 策略使用默认值 `0`

#### Scenario: 使用 a 的最小时间默认值
- **WHEN** 操作人员未显式覆盖 `InpP1P2AValueTimeMinKNumberLimit`
- **THEN** 策略使用默认值 `1`

#### Scenario: 使用 bSum 相对 a 的最小比例默认值
- **WHEN** 操作人员未显式覆盖 `InpBSumValueMinRatioOfAValue`
- **THEN** 策略使用默认值 `1.5`

#### Scenario: 使用 bSum 相对 a 的最大比例默认值
- **WHEN** 操作人员未显式覆盖 `InpBSumValueMaxRatioOfAValue`
- **THEN** 策略使用默认值 `5.0`

#### Scenario: 将止盈观察窗口长度配置为 30 根 K 线
- **WHEN** 操作人员将 `InpProfitObservationBars` 设为 `30`
- **THEN** 策略把止盈后观察窗口解释为按当前 `InpTF` 周期计数的 30 根 K 线

#### Scenario: 将止盈观察窗口显式关闭
- **WHEN** 操作人员将 `InpProfitObservationBars` 设为 `0`
- **THEN** 策略不再因为 `profit_target` 平仓而阻止后续新的买单入场

#### Scenario: 将止损观察窗口长度配置为 30 根 K 线
- **WHEN** 操作人员将 `InpStopObservationBars` 设为 `30`
- **THEN** 策略把止损后观察窗口解释为按当前 `InpTF` 周期计数的 30 根 K 线

#### Scenario: 将止损观察窗口显式关闭
- **WHEN** 操作人员将 `InpStopObservationBars` 设为 `0`
- **THEN** 策略不再因为 `hard_stop` 或 `soft_stop` 平仓而阻止后续新的买单入场

#### Scenario: 使用 P5 锚定止盈系数默认值
- **WHEN** 操作人员未显式覆盖 `InpP5AnchoredProfitC`
- **THEN** 策略使用默认值 `0.7`

#### Scenario: 运行时不再提供初始止盈系数输入
- **WHEN** 操作人员查看或配置本策略的运行时输入项
- **THEN** 策略不再提供 `InpProfitC` 作为可配置参数

### Requirement: 在定时器循环中扫描已配置品种
策略 SHALL 按照配置的定时器间隔，在所选周期上轮询每个已配置交易品种并执行模式识别，而不是依赖单一图表品种的 tick 到达来驱动检测。

#### Scenario: 定时器触发时遍历全部品种
- **WHEN** 定时器事件触发
- **THEN** 策略遍历每个已配置交易品种，并为该品种执行模式检测和交易管理

### Requirement: 强制执行 EA 专属订单标识和持仓上限
策略 SHALL 为 EA 创建的所有订单和持仓附加配置的 magic number 与 comment，并且在执行 `InpMaxPositionsPerSymbol` 限制时，仅 SHALL 统计由该 EA 管理的持仓。一旦某个品种的 EA 管理持仓数量达到配置上限，策略 SHALL 拒绝为该品种继续开新仓。

#### Scenario: 达到持仓上限时阻止新开仓
- **WHEN** 某个交易品种已经拥有 `InpMaxPositionsPerSymbol` 个由 EA 管理的未平仓持仓
- **THEN** 策略不会再为该品种提交新的买单

#### Scenario: 非 EA 持仓不参与 EA 限额统计
- **WHEN** 账户中存在同一品种的手动持仓或来自其他 magic number 的持仓
- **THEN** 策略在计算 `InpMaxPositionsPerSymbol` 限制时排除这些非本 EA 持仓

### Requirement: 按配置手数和滑点提交订单
策略 SHALL 使用 `InpFixedLots` 作为订单手数，并使用 `InpSlippagePoints` 作为允许滑点设置，来提交所有由 EA 管理的市价订单。

#### Scenario: 开仓请求使用配置的执行参数
- **WHEN** 策略提交一笔新的买单
- **THEN** 该请求使用配置的固定手数、滑点容忍度、magic number 和订单备注
