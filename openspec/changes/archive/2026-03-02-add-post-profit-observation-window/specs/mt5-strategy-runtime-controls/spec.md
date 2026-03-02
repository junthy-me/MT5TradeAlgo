## MODIFIED Requirements

### Requirement: 支持可配置的多品种运行时输入项
策略 SHALL 暴露 `InpSymbols`、`InpTF`、`InpTimerMillSec`、`InpMagic`、`InpComment`、`InpFixedLots`、`InpMaxPositionsPerSymbol`、`InpSlippagePoints` 和 `InpProfitObservationBars` 等运行时输入参数。`InpSymbols` SHALL 接受以分号分隔的交易品种列表，且运行时 SHALL 在解析后忽略空白项。`InpProfitObservationBars` SHALL 使用 bar 数量而非分钟数表示止盈后观察窗口长度；当其为 `0` 时，策略 SHALL 视为禁用该观察窗口；当其为正整数时，策略 SHALL 在对应 `symbol + timeframe` 的最近一次 `profit_target` 平仓后，按该 bar 数长度执行观察期门控。

#### Scenario: 运行时解析配置的品种列表
- **WHEN** 操作人员提供的 `InpSymbols` 中包含一个或多个以分号分隔的交易品种
- **THEN** 策略将其解析为独立的品种项，并将每个非空品种加入扫描队列

#### Scenario: 将观察窗口长度配置为 30 根 K 线
- **WHEN** 操作人员将 `InpProfitObservationBars` 设为 `30`
- **THEN** 策略把止盈后观察窗口解释为按当前 `InpTF` 周期计数的 30 根 K 线

#### Scenario: 将观察窗口显式关闭
- **WHEN** 操作人员将 `InpProfitObservationBars` 设为 `0`
- **THEN** 策略不再因为 `profit_target` 平仓而阻止后续新的买单入场
