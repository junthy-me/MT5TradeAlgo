## MODIFIED Requirements

### Requirement: 支持可配置的多品种运行时输入项
策略 SHALL 暴露 `InpSymbols`、`InpTF`、`InpTimerMillSec`、`InpMagic`、`InpComment`、`InpFixedLots`、`InpMaxPositionsPerSymbol`、`InpSlippagePoints`、`InpProfitObservationBars`、`InpStopObservationBars`、`InpLookbackBars`、`InpAdjustPointMinSpanKNumber`、`InpAdjustPointMaxSpanKNumber`、`InpCondAXMin`、`InpCondAXMax`、`InpP3P4MoveMinRatioOfStructure`、`InpP1P2AValueSpaceMinPriceLimit`、`InpP1P2AValueTimeMinKNumberLimit`、`InpBSumValueMinRatioOfAValue`、`InpBSumValueMaxRatioOfAValue`、`InpTradeDirectionMode`、`InpPreCondEnable`、`InpPreCondPriorMoveLookbackBars`、`InpPreCondPriorMoveMinRatioOfStructure`、`InpPreCondPriorMoveMinBarsBetweenPre0AndP0` 和 `InpP5AnchoredProfitC` 等运行时输入参数。`InpTradeDirectionMode` SHALL 支持 `LONG_ONLY`、`SHORT_ONLY` 和 `BOTH` 三种取值，且默认值 SHALL 为 `LONG_ONLY`。`InpPreCondEnable` SHALL 控制是否启用方向感知的 `Pre0-P0` 前置 move 条件；当其为 `false` 时，策略 SHALL 跳过 `Pre0` 搜索与相关过滤；当其为 `true` 时，策略 SHALL 启用 `Pre0-P0` 前置 move 规则。策略 SHALL NOT 再暴露 `InpP3P4DropMinRatioOfStructure`、`InpPreCondPriorDeclineLookbackBars`、`InpPreCondPriorDeclineMinDropRatioOfStructure` 或 `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0` 作为运行时输入参数，而 SHALL 使用对应的方向中性名称。

#### Scenario: 运行时解析配置的品种列表
- **WHEN** 操作人员提供的 `InpSymbols` 中包含一个或多个以分号分隔的交易品种
- **THEN** 策略将其解析为独立的品种项，并将每个非空品种加入扫描队列

#### Scenario: 方向模式默认保持 LONG_ONLY
- **WHEN** 操作人员未显式覆盖 `InpTradeDirectionMode`
- **THEN** 策略使用默认值 `LONG_ONLY`

#### Scenario: 使用前置 move 搜索窗口默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorMoveLookbackBars`
- **THEN** 策略使用默认值 `30`

#### Scenario: 使用前置 move 最小结构比例默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorMoveMinRatioOfStructure`
- **THEN** 策略使用默认值 `0.45`

#### Scenario: 使用 CondA 下限默认值
- **WHEN** 操作人员未显式覆盖 `InpCondAXMin`
- **THEN** 策略使用默认值 `0.75`

#### Scenario: 使用 CondA 上限默认值
- **WHEN** 操作人员未显式覆盖 `InpCondAXMax`
- **THEN** 策略使用默认值 `1.25`

#### Scenario: 使用 P3-P4 move 最小结构比例默认值
- **WHEN** 操作人员未显式覆盖 `InpP3P4MoveMinRatioOfStructure`
- **THEN** 策略使用默认值 `0.44`

#### Scenario: 使用 Pre0 与 P0 最小 bar 间隔默认值
- **WHEN** 操作人员未显式覆盖 `InpPreCondPriorMoveMinBarsBetweenPre0AndP0`
- **THEN** 策略使用默认值 `0`

#### Scenario: 运行时不再提供旧的偏多头输入名
- **WHEN** 操作人员查看或配置本策略的运行时输入项
- **THEN** 策略只暴露方向中性的 move 命名，而不会再提供旧的 `decline` 或 `drop` 输入名

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
