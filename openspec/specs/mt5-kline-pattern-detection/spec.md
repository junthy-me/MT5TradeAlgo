# mt5-kline-pattern-detection Specification

## Purpose
TBD - created by archiving change add-mt5-kline-pattern-strategy. Update Purpose after archive.
## Requirements
### Requirement: 从 MT5 K 线数据中识别 PRD 定义的 P0-P6 多头模式
策略 SHALL 针对每个已配置的交易品种和周期分析已收盘的 bar，并识别满足 PRD 空间结构和时间结构的 P0 到 P6 候选点位。检测器 SHALL 为每个候选序列计算 `a`、`b1`、`b2`、`c`、`d`、`e`、`r1`、`r2`、`sspanmin`、`t1` 到 `t6`、`trigger_pattern_total_time_minute` 和 `tspanmin`。

#### Scenario: 候选序列生成标准化模式快照
- **WHEN** 某个交易品种拥有足够的已收盘 bar 来构成一组候选 P0-P6 序列
- **THEN** 检测器会产出一份包含点位时间、点位价格、空间变量和时间变量的模式快照

### Requirement: 强制执行可配置的点位取值与单段跨度规则
策略 SHALL 支持 `InpAdjustPointMinSpanKNumber` 和 `InpAdjustPointMaxSpanKNumber` 共同限制相邻点之间的单段跨度，其中 `SpanKNumber` SHALL 定义为“起点与终点之间中间间隔的 K 线数量”，即不包含起点和终点所在 K 线。该最小/最大跨度区间 SHALL 同时作用于 `P0->P1`、`P1->P2`、`P2->P3` 和 `P3->P4` 四段。与此同时，策略 SHALL 使用角色化点位规则来确定 `P0-P6` 的价格来源，而 SHALL NOT 再暴露 `PointValueTypeEnum` 作为统一点位取值模式。对于历史骨架中的 `P0->P1`、`P1->P2`、`P2->P3` 三段，策略还 SHALL 验证端点达到该段应有的整段极值：`P0->P1` 中 `P0` 必须达到整段最低点、`P1` 必须达到整段最高点；`P1->P2` 中 `P1` 必须达到整段最高点、`P2` 必须达到整段最低点；`P2->P3` 中 `P2` 必须达到整段最低点、`P3` 必须达到整段最高点。默认口径 SHALL 允许并列极值，即端点只需要达到该段极值，而不要求是唯一极值。任何小于最小跨度、超过最大跨度或不满足上述历史线段极值约束的候选序列 SHALL 被拒绝。

#### Scenario: 相邻点中间 bar 数不足时拒绝该序列
- **WHEN** 某个候选序列中的任意相邻点对之间中间间隔的 K 线数量小于 `InpAdjustPointMinSpanKNumber`
- **THEN** 检测器拒绝该序列，且不会报告有效模式匹配

#### Scenario: 相邻点中间 bar 数超限时拒绝该序列
- **WHEN** 某个候选序列中的任意相邻点对之间中间间隔的 K 线数量超过 `InpAdjustPointMaxSpanKNumber`
- **THEN** 检测器拒绝该序列，且不会报告有效模式匹配

#### Scenario: 使用单段最小跨度默认值
- **WHEN** 操作人员未显式覆盖 `InpAdjustPointMinSpanKNumber`
- **THEN** 检测器使用默认值 `5` 作为每段相邻点之间中间间隔 K 线数量的最小值

#### Scenario: 使用单段最大跨度默认值
- **WHEN** 操作人员未显式覆盖 `InpAdjustPointMaxSpanKNumber`
- **THEN** 检测器使用默认值 `35` 作为每段相邻点之间中间间隔 K 线数量的最大值

#### Scenario: 相邻两点时跨度记为 0
- **WHEN** 两个相邻点落在相邻的两根 K 线上，中间没有任何额外 K 线
- **THEN** 检测器将这两个点之间的 `SpanKNumber` 解释为 `0`

#### Scenario: 检测器仅使用角色化点位规则
- **WHEN** 本策略为候选序列计算 `P0-P6` 点位价格
- **THEN** 检测器固定按角色化规则取值，而不会再读取统一的 `PointValueTypeEnum` 配置

#### Scenario: P0-P1 线段内部出现更低 low 时拒绝骨架
- **WHEN** 某个候选骨架的 `P0-P1` 线段内部存在低于 `P0.low` 的更低 low
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: P1-P2 线段内部出现更高 high 时拒绝骨架
- **WHEN** 某个候选骨架的 `P1-P2` 线段内部存在高于 `P1.high` 的更高 high
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: 并列极值默认允许
- **WHEN** 某条历史线段的端点已经达到该段最高点或最低点，但段内其他 bar 也存在相同 high 或 low
- **THEN** 检测器仍然允许该线段通过极值校验

### Requirement: 仅在 CondA、CondB、CondC、CondF 与新增结构约束满足时确认完整匹配
策略 SHALL 仅在以下条件全部满足时将某个形态视为完整匹配：`b1 = x * b2` 且落在配置的 `x` 系数范围内，`r1 = c / (a+b1+b2)` 且满足 `r1 >= InpP3P4DropMinRatioOfStructure`，`t4 < z * (t1 + t2 + t3)`，每个相邻点的中间 bar 数都同时满足 `InpAdjustPointMinSpanKNumber <= SpanKNumber <= InpAdjustPointMaxSpanKNumber`，`a >= InpP1P2AValueSpaceMinPriceLimit`，`P1-P2` 线段包含的 K 线数量（含 `P1` 与 `P2` 本身）大于或等于 `InpP1P2AValueTimeMinKNumberLimit`，`InpBSumValueMaxRatioOfAValue * a >= (b1+b2) >= InpBSumValueMinRatioOfAValue * a`，以及所有启用的 pattern preconditions 都通过。这里的 pattern preconditions SHALL 包括 `Pre0-P0` 线段端点极值约束：`Pre0` 必须达到该段最高点，`P0` 必须达到该段最低点，默认同样允许并列极值。

#### Scenario: a 的空间约束不足时拒绝该骨架
- **WHEN** 某个候选骨架已经计算出 `a`，但 `a < InpP1P2AValueSpaceMinPriceLimit`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: a 的时间约束不足时拒绝该骨架
- **WHEN** 某个候选骨架的 `P1-P2` 线段包含的 K 线数量（含 `P1` 与 `P2`）小于 `InpP1P2AValueTimeMinKNumberLimit`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: 任一线段不满足最小跨度时拒绝该骨架
- **WHEN** 某个候选骨架已经满足其他结构条件，但其 `P0->P1`、`P1->P2`、`P2->P3` 或 `P3->P4` 中至少一段的中间 bar 数小于 `InpAdjustPointMinSpanKNumber`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: 任一线段超过最大跨度时拒绝该骨架
- **WHEN** 某个候选骨架已经满足其他结构条件，但其 `P0->P1`、`P1->P2`、`P2->P3` 或 `P3->P4` 中至少一段的中间 bar 数大于 `InpAdjustPointMaxSpanKNumber`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: b1+b2 相对 a 的比例不足时拒绝该骨架
- **WHEN** 某个候选骨架已经计算出 `a`、`b1` 和 `b2`，但 `(b1+b2) < InpBSumValueMinRatioOfAValue * a`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: b1+b2 相对 a 的比例超上限时拒绝该骨架
- **WHEN** 某个候选骨架已经计算出 `a`、`b1` 和 `b2`，但 `(b1+b2) > InpBSumValueMaxRatioOfAValue * a`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: Pre0-P0 线段内部出现更低 low 时拒绝先决条件
- **WHEN** 某个 `Pre0-P0` 候选区间内部存在低于 `P0.low` 的更低 low
- **THEN** 该前置下跌先决条件失败，且检测器不会将该候选输出为可交易匹配

#### Scenario: Pre0-P0 线段内部出现更高 high 时拒绝先决条件
- **WHEN** 某个 `Pre0-P0` 候选区间内部存在高于 `Pre0.high` 的更高 high
- **THEN** 该前置下跌先决条件失败，且检测器不会将该候选输出为可交易匹配

#### Scenario: 先决条件失败时拒绝该候选
- **WHEN** 某个候选序列已经满足 `CondA`、`CondB`、`CondC`、`CondF` 与现有结构约束，但至少一条启用的 pattern precondition 失败
- **THEN** 检测器仍然拒绝该候选，且不会将其输出为可交易匹配

#### Scenario: 全部约束与先决条件通过时输出完整匹配
- **WHEN** 某个候选序列在当前输入配置下同时满足 `CondA`、`CondB`、`CondC`、`CondF`、现有结构约束和全部启用的 pattern preconditions
- **THEN** 检测器将该序列标记为完整模式匹配，并将其提供给交易处理逻辑

#### Scenario: 部分匹配不得用于交易
- **WHEN** 某个候选序列的 `CondA`、`CondB`、`CondC`、`CondF`、任一现有结构约束或任一启用的 pattern precondition 失败
- **THEN** 检测器不会将该序列输出为可交易匹配
