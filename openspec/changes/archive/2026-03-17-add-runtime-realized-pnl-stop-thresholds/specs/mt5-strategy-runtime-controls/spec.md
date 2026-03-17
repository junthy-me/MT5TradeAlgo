## MODIFIED Requirements

### Requirement: 支持可配置的多品种运行时输入项
策略 SHALL 暴露 `InpSymbols`、`InpTF`、`InpTimerMillSec`、`InpMagic`、`InpComment`、`InpFixedLots`、`InpMaxPositionsPerSymbol`、`InpSlippagePoints`、`InpProfitObservationBars`、`InpStopObservationBars`、`InpLookbackBars`、`InpAdjustPointMinSpanKNumber`、`InpAdjustPointMaxSpanKNumber`、`InpCondAXMin`、`InpCondAXMax`、`InpP3P4MoveMinRatioOfStructure`、`InpP1P2AValueSpaceMinPriceLimit`、`InpP1P2AValueTimeMinKNumberLimit`、`InpBSumValueMinRatioOfAValue`、`InpBSumValueMaxRatioOfAValue`、`InpTradeDirectionMode`、`InpPreCondEnable`、`InpPreCondPriorMoveLookbackBars`、`InpPreCondPriorMoveMinRatioOfStructure`、`InpPreCondPriorMoveMinBarsBetweenPre0AndP0`、`InpP5AnchoredProfitC`、`InpMaxProfitStopMoney` 和 `InpMaxLossStopMoney` 等运行时输入参数。`InpTradeDirectionMode` SHALL 支持 `LONG_ONLY`、`SHORT_ONLY` 和 `BOTH` 三种取值，且默认值 SHALL 为 `LONG_ONLY`。`InpTF` 默认值 SHALL 为 `PERIOD_M30`。`InpLookbackBars` 默认值 SHALL 为 `150`。`InpAdjustPointMinSpanKNumber` 默认值 SHALL 为 `0`，`InpAdjustPointMaxSpanKNumber` 默认值 SHALL 为 `20`。`InpP1P2AValueSpaceMinPriceLimit` 默认值 SHALL 为 `5.0`，`InpP1P2AValueTimeMinKNumberLimit` 默认值 SHALL 为 `5`。`InpBSumValueMaxRatioOfAValue` 默认值 SHALL 为 `5.0`。策略运行时 SHALL 要求账户使用 `RETAIL_HEDGING` 模式；当账户为 `RETAIL_NETTING`、`EXCHANGE` 或其他非 hedging 模式时，策略 SHALL 在初始化阶段显式报错并拒绝启动。`InpPreCondEnable` 默认值 SHALL 为 `true`，并 SHALL 控制是否启用方向感知的 `Pre0-P0` 前置 move 条件；当其为 `false` 时，策略 SHALL 跳过 `Pre0` 搜索与相关过滤；当其为 `true` 时，策略 SHALL 启用 `Pre0-P0` 前置 move 规则。`InpPreCondPriorMoveLookbackBars` 默认值 SHALL 为 `20`。`InpPreCondPriorMoveMinRatioOfStructure` 默认值 SHALL 为 `0.45`。`InpPreCondPriorMoveMinBarsBetweenPre0AndP0` 默认值 SHALL 为 `0`。`InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 默认值 SHALL 为 `"false,false,false,false,false"`。`InpP5AnchoredProfitC` 默认值 SHALL 为 `2.0`。`InpMaxProfitStopMoney` 和 `InpMaxLossStopMoney` 默认值 SHALL 都为 `0`，且 `0` SHALL 表示对应停止阈值被禁用。策略 SHALL NOT 再暴露 `InpP3P4DropMinRatioOfStructure`、`InpPreCondPriorDeclineLookbackBars`、`InpPreCondPriorDeclineMinDropRatioOfStructure` 或 `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0` 作为运行时输入参数，而 SHALL 使用对应的方向中性名称。

#### Scenario: 运行时解析配置的品种列表
- **WHEN** 操作人员提供的 `InpSymbols` 中包含一个或多个以分号分隔的交易品种
- **THEN** 策略将其解析为独立的品种项，并将每个非空品种加入扫描队列

#### Scenario: 默认周期使用 M30
- **WHEN** 操作人员未显式覆盖 `InpTF`
- **THEN** 策略使用默认值 `PERIOD_M30`

#### Scenario: 方向模式默认保持 LONG_ONLY
- **WHEN** 操作人员未显式覆盖 `InpTradeDirectionMode`
- **THEN** 策略使用默认值 `LONG_ONLY`

#### Scenario: 默认回看窗口使用 150 根 K 线
- **WHEN** 操作人员未显式覆盖 `InpLookbackBars`
- **THEN** 策略使用默认值 `150`

#### Scenario: 默认相邻点最小跨度使用 0
- **WHEN** 操作人员未显式覆盖 `InpAdjustPointMinSpanKNumber`
- **THEN** 策略使用默认值 `0`

#### Scenario: 默认相邻点最大跨度使用 20
- **WHEN** 操作人员未显式覆盖 `InpAdjustPointMaxSpanKNumber`
- **THEN** 策略使用默认值 `20`

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
- **THEN** 策略使用默认值 `20`

#### Scenario: 使用前置 move 最小结构比例默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorMoveMinRatioOfStructure`
- **THEN** 策略使用默认值 `0.45`

#### Scenario: 使用 Pre0 与 P0 最小 bar 间隔默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorMoveMinBarsBetweenPre0AndP0`
- **THEN** 策略使用默认值 `0`

#### Scenario: 默认关闭全部整段极值约束
- **WHEN** 操作人员未显式覆盖 `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4`
- **THEN** 策略使用默认值 `"false,false,false,false,false"`

#### Scenario: 默认 P5 锚定止盈系数使用 2
- **WHEN** 操作人员未显式覆盖 `InpP5AnchoredProfitC`
- **THEN** 策略使用默认值 `2.0`

#### Scenario: 默认禁用最大盈利停止阈值
- **WHEN** 操作人员未显式覆盖 `InpMaxProfitStopMoney`
- **THEN** 策略使用默认值 `0`

#### Scenario: 默认禁用最大亏损停止阈值
- **WHEN** 操作人员未显式覆盖 `InpMaxLossStopMoney`
- **THEN** 策略使用默认值 `0`

#### Scenario: 盈利停止阈值为 0 时禁用对应门控
- **WHEN** 操作人员将 `InpMaxProfitStopMoney` 设为 `0`
- **THEN** 策略不会因为累计已实现盈利达到某个正金额而停止新的自动开仓

#### Scenario: 亏损停止阈值为 0 时禁用对应门控
- **WHEN** 操作人员将 `InpMaxLossStopMoney` 设为 `0`
- **THEN** 策略不会因为累计已实现亏损达到某个正金额而停止新的自动开仓

#### Scenario: 运行时不再提供旧的偏多头输入名
- **WHEN** 操作人员查看或配置本策略的运行时输入项
- **THEN** 策略只暴露方向中性的 move 命名，而不会再提供旧的 `decline` 或 `drop` 输入名
