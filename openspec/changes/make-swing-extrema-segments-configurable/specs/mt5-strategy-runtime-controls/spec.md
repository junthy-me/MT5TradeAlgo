## MODIFIED Requirements

### Requirement: 支持可配置的多品种运行时输入项
策略 SHALL 暴露 `InpSymbols`、`InpTF`、`InpTimerMillSec`、`InpMagic`、`InpComment`、`InpFixedLots`、`InpMaxPositionsPerSymbol`、`InpSlippagePoints`、`InpProfitObservationBars`、`InpStopObservationBars`、`InpLookbackBars`、`InpAdjustPointMinSpanKNumber`、`InpAdjustPointMaxSpanKNumber`、`InpCondAXMin`、`InpCondAXMax`、`InpP3P4MoveMinRatioOfStructure`、`InpP1P2AValueSpaceMinPriceLimit`、`InpP1P2AValueTimeMinKNumberLimit`、`InpBSumValueMinRatioOfAValue`、`InpBSumValueMaxRatioOfAValue`、`InpTradeDirectionMode`、`InpPreCondEnable`、`InpPreCondPriorMoveLookbackBars`、`InpPreCondPriorMoveMinRatioOfStructure`、`InpPreCondPriorMoveMinBarsBetweenPre0AndP0`、`InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 和 `InpP5AnchoredProfitC` 等运行时输入参数。`InpTradeDirectionMode` SHALL 支持 `LONG_ONLY`、`SHORT_ONLY` 和 `BOTH` 三种取值，且默认值 SHALL 为 `LONG_ONLY`。`InpPreCondEnable` SHALL 控制是否启用方向感知的 `Pre0-P0` 前置 move 条件；当其为 `false` 时，策略 SHALL 跳过 `Pre0` 搜索与相关过滤；当其为 `true` 时，策略 SHALL 启用 `Pre0-P0` 前置 move 规则。`InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` SHALL 使用固定顺序的 5 位逗号分隔布尔字符串，依次表示 `Pre0P0`、`P0P1`、`P1P2`、`P2P3`、`P3P4` 是否启用对应线段的整段极值约束。布尔值 SHALL 大小写不敏感，并允许值两侧出现空格。策略 SHALL NOT 再暴露 `InpP3P4DropMinRatioOfStructure`、`InpPreCondPriorDeclineLookbackBars`、`InpPreCondPriorDeclineMinDropRatioOfStructure` 或 `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0` 作为运行时输入参数，而 SHALL 使用对应的方向中性名称。

#### Scenario: 运行时解析配置的品种列表
- **WHEN** 操作人员提供的 `InpSymbols` 中包含一个或多个以分号分隔的交易品种
- **THEN** 策略将其解析为独立的品种项，并将每个非空品种加入扫描队列

#### Scenario: 方向模式默认保持 LONG_ONLY
- **WHEN** 操作人员未显式覆盖 `InpTradeDirectionMode`
- **THEN** 策略使用默认值 `LONG_ONLY`

#### Scenario: 相邻段极值配置默认全启用
- **WHEN** 操作人员未显式覆盖 `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4`
- **THEN** 策略使用默认值 `"true,true,true,true,true"`

#### Scenario: 合法的相邻段极值配置可被解析
- **WHEN** 操作人员将 `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 设为 `"true,false,true,true,true"`
- **THEN** 策略将其解析为 `Pre0P0=true`、`P0P1=false`、`P1P2=true`、`P2P3=true`、`P3P4=true`

#### Scenario: 非法的相邻段极值配置会阻止启动
- **WHEN** `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 不能被解析为恰好 5 个合法布尔值
- **THEN** 策略在初始化时显式报错并拒绝启动

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
