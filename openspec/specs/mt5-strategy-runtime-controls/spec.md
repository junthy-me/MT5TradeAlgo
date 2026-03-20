# mt5-strategy-runtime-controls Specification

## Purpose
TBD - created by archiving change add-mt5-kline-pattern-strategy. Update Purpose after archive.
## Requirements
### Requirement: 支持可配置的多品种运行时输入项
策略 SHALL 暴露 `InpSymbols`、`InpTF`、`InpTimerMillSec`、`InpMagic`、`InpComment`、`InpFixedLots`、`InpMaxPositionsPerSymbol`、`InpSlippagePoints`、`InpProfitObservationBars`、`InpStopObservationBars`、`InpLookbackBars`、`InpAdjustPointMinSpanKNumber`、`InpAdjustPointMaxSpanKNumber`、`InpCondAXMin`、`InpCondAXMax`、`InpP3P4MoveMinRatioOfStructure`、`InpP1P2AValueSpaceMinPriceLimit`、`InpP1P2AValueTimeMinKNumberLimit`、`InpBSumValueMinRatioOfAValue`、`InpBSumValueMaxRatioOfAValue`、`InpTradeDirectionMode`、`InpPreCondEnable`、`InpPreCondPriorMoveLookbackBars`、`InpPreCondPriorMoveMinRatioOfStructure`、`InpPreCondPriorMoveMinBarsBetweenPre0AndP0`、`InpP5AnchoredProfitC`、`InpMaxProfitStopMoney` 和 `InpMaxLossStopMoney` 等运行时输入参数。`InpSymbols` 默认值 SHALL 为 `"XAUUSDm"`。`InpTradeDirectionMode` SHALL 支持 `LONG_ONLY`、`SHORT_ONLY` 和 `BOTH` 三种取值，且默认值 SHALL 为 `LONG_ONLY`。`InpFixedLots` 默认值 SHALL 为 `0.05`。`InpTF` 默认值 SHALL 为 `PERIOD_M30`。`InpLookbackBars` 默认值 SHALL 为 `150`。`InpAdjustPointMinSpanKNumber` 默认值 SHALL 为 `0`，`InpAdjustPointMaxSpanKNumber` 默认值 SHALL 为 `20`。`InpP3P4MoveMinRatioOfStructure` 默认值 SHALL 为 `0.75`。`InpP1P2AValueSpaceMinPriceLimit` 默认值 SHALL 为 `5.0`，`InpP1P2AValueTimeMinKNumberLimit` 默认值 SHALL 为 `5`。`InpBSumValueMaxRatioOfAValue` 默认值 SHALL 为 `5.0`。策略运行时 SHALL 要求账户使用 `RETAIL_HEDGING` 模式；当账户为 `RETAIL_NETTING`、`EXCHANGE` 或其他非 hedging 模式时，策略 SHALL 在初始化阶段显式报错并拒绝启动。`InpPreCondEnable` 默认值 SHALL 为 `true`，并 SHALL 控制是否启用方向感知的 `Pre0-P0` 前置 move 条件；当其为 `false` 时，策略 SHALL 跳过 `Pre0` 搜索与相关过滤；当其为 `true` 时，策略 SHALL 启用 `Pre0-P0` 前置 move 规则。`InpPreCondPriorMoveLookbackBars` 默认值 SHALL 为 `30`。`InpPreCondPriorMoveMinRatioOfStructure` 默认值 SHALL 为 `1.1`。`InpPreCondPriorMoveMinBarsBetweenPre0AndP0` 默认值 SHALL 为 `0`。`InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 默认值 SHALL 为 `"true,true,false,false,false"`。`InpP5AnchoredProfitC` 默认值 SHALL 为 `2.0`。`InpMaxProfitStopMoney` 和 `InpMaxLossStopMoney` 默认值 SHALL 都为 `0`，且 `0` SHALL 表示对应品种的运行期总盈亏停止阈值被禁用。策略 SHALL NOT 再暴露 `InpP3P4DropMinRatioOfStructure`、`InpPreCondPriorDeclineLookbackBars`、`InpPreCondPriorDeclineMinDropRatioOfStructure` 或 `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0` 作为运行时输入参数，而 SHALL 使用对应的方向中性名称。

#### Scenario: 运行时解析配置的品种列表
- **WHEN** 操作人员提供的 `InpSymbols` 中包含一个或多个以分号分隔的交易品种
- **THEN** 策略将其解析为独立的品种项，并将每个非空品种加入扫描队列

#### Scenario: 默认品种使用 XAUUSDm
- **WHEN** 操作人员未显式覆盖 `InpSymbols`
- **THEN** 策略使用默认值 `"XAUUSDm"`

#### Scenario: 默认周期使用 M30
- **WHEN** 操作人员未显式覆盖 `InpTF`
- **THEN** 策略使用默认值 `PERIOD_M30`

#### Scenario: 方向模式默认保持 LONG_ONLY
- **WHEN** 操作人员未显式覆盖 `InpTradeDirectionMode`
- **THEN** 策略使用默认值 `LONG_ONLY`

#### Scenario: 默认固定手数使用 0.05
- **WHEN** 操作人员未显式覆盖 `InpFixedLots`
- **THEN** 策略使用默认值 `0.05`

#### Scenario: 默认回看窗口使用 150 根 K 线
- **WHEN** 操作人员未显式覆盖 `InpLookbackBars`
- **THEN** 策略使用默认值 `150`

#### Scenario: 默认相邻点最小跨度使用 0
- **WHEN** 操作人员未显式覆盖 `InpAdjustPointMinSpanKNumber`
- **THEN** 策略使用默认值 `0`

#### Scenario: 默认相邻点最大跨度使用 20
- **WHEN** 操作人员未显式覆盖 `InpAdjustPointMaxSpanKNumber`
- **THEN** 策略使用默认值 `20`

#### Scenario: 默认 CondB 阈值使用 0.75
- **WHEN** 操作人员未显式覆盖 `InpP3P4MoveMinRatioOfStructure`
- **THEN** 策略使用默认值 `0.75`

#### Scenario: 默认 a 最小价格幅度使用 5
- **WHEN** 操作人员未显式覆盖 `InpP1P2AValueSpaceMinPriceLimit`
- **THEN** 策略使用默认值 `5.0`

#### Scenario: 默认 P1 到 P2 最小总 K 线数使用 5
- **WHEN** 操作人员未显式覆盖 `InpP1P2AValueTimeMinKNumberLimit`
- **THEN** 策略使用默认值 `5`

#### Scenario: 默认 bsum 最大倍数使用 5
- **WHEN** 操作人员未显式覆盖 `InpBSumValueMaxRatioOfAValue`
- **THEN** 策略使用默认值 `5.0`

#### Scenario: 非 hedging 账户会阻止启动
- **WHEN** 策略初始化时检测到账户模式不是 `RETAIL_HEDGING`
- **THEN** 策略显式报错并拒绝启动

#### Scenario: 前置 move 条件默认启用
- **WHEN** 操作人员未显式覆盖 `InpPreCondEnable`
- **THEN** 策略使用默认值 `true`

#### Scenario: 使用前置 move 搜索窗口默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorMoveLookbackBars`
- **THEN** 策略使用默认值 `30`

#### Scenario: 使用前置 move 最小结构比例默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorMoveMinRatioOfStructure`
- **THEN** 策略使用默认值 `1.1`

#### Scenario: 使用 Pre0 与 P0 最小 bar 间隔默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorMoveMinBarsBetweenPre0AndP0`
- **THEN** 策略使用默认值 `0`

#### Scenario: 默认启用 Pre0P0 与 P0P1 的整段极值约束
- **WHEN** 操作人员未显式覆盖 `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4`
- **THEN** 策略使用默认值 `"true,true,false,false,false"`

#### Scenario: 默认 P5 锚定止盈系数使用 2
- **WHEN** 操作人员未显式覆盖 `InpP5AnchoredProfitC`
- **THEN** 策略使用默认值 `2.0`

#### Scenario: 默认禁用当前品种最大盈利停止阈值
- **WHEN** 操作人员未显式覆盖 `InpMaxProfitStopMoney`
- **THEN** 策略使用默认值 `0`

#### Scenario: 默认禁用当前品种最大亏损停止阈值
- **WHEN** 操作人员未显式覆盖 `InpMaxLossStopMoney`
- **THEN** 策略使用默认值 `0`

#### Scenario: 盈利停止阈值为 0 时禁用对应门控
- **WHEN** 操作人员将 `InpMaxProfitStopMoney` 设为 `0`
- **THEN** 策略不会因为某个品种的已实现盈亏加浮动盈亏达到某个正金额而触发该品种 stop

#### Scenario: 亏损停止阈值为 0 时禁用对应门控
- **WHEN** 操作人员将 `InpMaxLossStopMoney` 设为 `0`
- **THEN** 策略不会因为某个品种的已实现盈亏加浮动盈亏达到某个负金额而触发该品种 stop

#### Scenario: 运行时不再提供旧的偏多头输入名
- **WHEN** 操作人员查看或配置本策略的运行时输入项
- **THEN** 策略只暴露方向中性的 move 命名，而不会再提供旧的 `decline` 或 `drop` 输入名

### Requirement: 在定时器循环中扫描已配置品种
策略 SHALL 按照配置的定时器间隔，在所选周期上轮询每个已配置交易品种并执行模式识别，而不是依赖单一图表品种的 tick 到达来驱动检测。

#### Scenario: 定时器触发时遍历全部品种
- **WHEN** 定时器事件触发
- **THEN** 策略遍历每个已配置交易品种，并为该品种执行模式检测和交易管理

### Requirement: 强制执行 EA 专属订单标识和持仓上限
策略 SHALL 为 EA 创建的所有订单和持仓附加配置的 magic number 与 comment，并且在执行 `InpMaxPositionsPerSymbol` 限制时，仅 SHALL 统计由该 EA 管理的持仓。一旦某个品种的 EA 管理持仓数量达到配置上限，策略 SHALL 拒绝为该品种继续开新仓；该限制在多头与空头之间 SHALL 共享，而不是分别统计。

#### Scenario: 达到持仓上限时阻止任意方向的新开仓
- **WHEN** 某个交易品种已经拥有 `InpMaxPositionsPerSymbol` 个由 EA 管理的未平仓持仓
- **THEN** 策略不会再为该品种提交新的多头或空头仓位

#### Scenario: 非 EA 持仓不参与 EA 限额统计
- **WHEN** 账户中存在同一品种的手动持仓或来自其他 magic number 的持仓
- **THEN** 策略在计算 `InpMaxPositionsPerSymbol` 限制时排除这些非本 EA 持仓

### Requirement: 按配置手数和滑点提交订单
策略 SHALL 使用 `InpFixedLots` 作为订单手数，并使用 `InpSlippagePoints` 作为允许滑点设置，来提交所有由 EA 管理的市价订单。对于多头匹配，策略 SHALL 提交买入订单；对于空头匹配，策略 SHALL 提交卖出订单。

#### Scenario: 多头匹配提交买入请求
- **WHEN** 策略提交一笔新的多头仓位
- **THEN** 该请求使用配置的固定手数、滑点容忍度、magic number 和订单备注，并按买入方向提交

#### Scenario: 空头匹配提交卖出请求
- **WHEN** 策略提交一笔新的空头仓位
- **THEN** 该请求使用配置的固定手数、滑点容忍度、magic number 和订单备注，并按卖出方向提交
