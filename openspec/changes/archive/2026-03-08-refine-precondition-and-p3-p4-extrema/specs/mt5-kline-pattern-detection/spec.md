## MODIFIED Requirements

### Requirement: 仅在 CondA、CondB、CondC、CondF 与新增结构约束满足时确认完整匹配
策略 SHALL 仅在以下条件全部满足时将某个形态视为完整匹配：`b1 = x * b2` 且落在配置的 `x` 系数范围内，`r1 = c / (a+b1+b2)` 且满足 `r1 >= InpP3P4DropMinRatioOfStructure`，`t4 < z * (t1 + t2 + t3)`，每个相邻点的中间 bar 数都同时满足 `InpAdjustPointMinSpanKNumber <= SpanKNumber <= InpAdjustPointMaxSpanKNumber`，`a >= InpP1P2AValueSpaceMinPriceLimit`，`P1-P2` 线段包含的 K 线数量（含 `P1` 与 `P2` 本身）大于或等于 `InpP1P2AValueTimeMinKNumberLimit`，`InpBSumValueMaxRatioOfAValue * a >= (b1+b2) >= InpBSumValueMinRatioOfAValue * a`，以及所有启用的 pattern preconditions 都通过。这里的 pattern preconditions SHALL 受 `InpPreCondEnable` 控制：当 `InpPreCondEnable=false` 时，策略 SHALL 跳过 `Pre0-P0` 前置条件并直接视为通过；当 `InpPreCondEnable=true` 时，策略 SHALL 在 `P0` 之前最近 `InpPreCondPriorDeclineLookbackBars` 根 K 线内寻找 `Pre0`，要求 `Pre0-P0` 的跌幅大于 `InpPreCondPriorDeclineMinDropRatioOfStructure * (a+b1)`，并要求 `Pre0` 必须达到该段最高点、`P0` 必须达到该段最低点，默认同样允许并列极值。对于实时触发段，策略 SHALL 额外要求 `P3` 达到 `P3->P4` 整段的最高点；若段内其他 bar 或 `P4` 所在 bar 也出现与 `P3` 相同的 high，仍 SHALL 视为通过。

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

#### Scenario: 前置条件关闭时不要求 Pre0
- **WHEN** `InpPreCondEnable=false` 且某个候选序列已经满足 `CondA`、`CondB`、`CondC`、`CondF` 与现有结构约束
- **THEN** 检测器不会因为缺少 `Pre0` 而拒绝该候选，并继续按剩余条件决定是否输出完整匹配

#### Scenario: 启用前置条件时按 a+b1 计算最小跌幅
- **WHEN** `InpPreCondEnable=true` 且某个 `Pre0-P0` 候选区间的跌幅不大于 `InpPreCondPriorDeclineMinDropRatioOfStructure * (a+b1)`
- **THEN** 该前置下跌先决条件失败，且检测器不会将该候选输出为可交易匹配

#### Scenario: Pre0-P0 线段内部出现更低 low 时拒绝先决条件
- **WHEN** `InpPreCondEnable=true` 且某个 `Pre0-P0` 候选区间内部存在低于 `P0.low` 的更低 low
- **THEN** 该前置下跌先决条件失败，且检测器不会将该候选输出为可交易匹配

#### Scenario: Pre0-P0 线段内部出现更高 high 时拒绝先决条件
- **WHEN** `InpPreCondEnable=true` 且某个 `Pre0-P0` 候选区间内部存在高于 `Pre0.high` 的更高 high
- **THEN** 该前置下跌先决条件失败，且检测器不会将该候选输出为可交易匹配

#### Scenario: P3-P4 段内部出现更高 high 时拒绝触发
- **WHEN** 某个候选序列已经满足其他历史结构条件，但 `P3->P4` 段内部存在高于 `P3.high` 的更高 high
- **THEN** 检测器拒绝该次 `P4` 触发，且不会将该序列输出为可交易匹配

#### Scenario: P3-P4 段出现并列高点时仍允许触发
- **WHEN** 某个候选序列的 `P3->P4` 段内最高 high 与 `P3.high` 相同，且其他条件全部满足
- **THEN** 检测器仍然允许该次 `P4` 触发，并将该序列输出为完整模式匹配

#### Scenario: 全部约束与先决条件通过时输出完整匹配
- **WHEN** 某个候选序列在当前输入配置下同时满足 `CondA`、`CondB`、`CondC`、`CondF`、现有结构约束和全部启用的 pattern preconditions
- **THEN** 检测器将该序列标记为完整模式匹配，并将其提供给交易处理逻辑

#### Scenario: 部分匹配不得用于交易
- **WHEN** 某个候选序列的 `CondA`、`CondB`、`CondC`、`CondF`、任一现有结构约束或任一启用的 pattern precondition 失败
- **THEN** 检测器不会将该序列输出为可交易匹配
