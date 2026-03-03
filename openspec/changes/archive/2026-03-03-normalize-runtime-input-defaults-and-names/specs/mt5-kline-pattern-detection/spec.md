## MODIFIED Requirements

### Requirement: 强制执行可配置的点位取值与单段跨度规则
策略 SHALL 支持 `InpAdjustPointMaxSpanKNumber` 来限制相邻点之间最多跨越的 K 线数量。与此同时，策略 SHALL 使用角色化点位规则来确定 `P0-P6` 的价格来源，而 SHALL NOT 再暴露 `PointValueTypeEnum` 作为统一点位取值模式。任何超过配置跨度的候选序列 SHALL 被拒绝。

#### Scenario: 相邻点跨度超限时拒绝该序列
- **WHEN** 某个候选序列中的任意相邻点对跨越的 K 线数量超过 `InpAdjustPointMaxSpanKNumber`
- **THEN** 检测器拒绝该序列，且不会报告有效模式匹配

#### Scenario: 使用单段跨度默认值
- **WHEN** 操作人员未显式覆盖 `InpAdjustPointMaxSpanKNumber`
- **THEN** 检测器使用默认值 `10` 作为每段相邻点之间允许跨越的最大 K 线数量

#### Scenario: 检测器仅使用角色化点位规则
- **WHEN** 本策略为候选序列计算 `P0-P6` 点位价格
- **THEN** 检测器固定按角色化规则取值，而不会再读取统一的 `PointValueTypeEnum` 配置

### Requirement: 仅在 CondA、CondB、CondC、CondF 与新增结构约束满足时确认完整匹配
策略 SHALL 仅在以下条件全部满足时将某个形态视为完整匹配：`b1 = x * b2` 且落在配置的 `x` 系数范围内，`r1 = c / (a+b1+b2)` 且满足 `r1 >= InpP3P4DropMinRatioOfStructure`，`t4 < z * (t1 + t2 + t3)`，每个相邻点跨度都小于或等于 `InpAdjustPointMaxSpanKNumber`，`a >= InpP1P2AValueSpaceMinPriceLimit`，`P1-P2` 线段包含的 K 线数量（含 `P1` 与 `P2` 本身）大于或等于 `InpP1P2AValueTimeMinKNumberLimit`，以及 `(b1+b2) >= InpBSumValueMinRatioOfAValue * a`。

#### Scenario: a 的空间约束不足时拒绝该骨架
- **WHEN** 某个候选骨架已经计算出 `a`，但 `a < InpP1P2AValueSpaceMinPriceLimit`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: a 的时间约束不足时拒绝该骨架
- **WHEN** 某个候选骨架的 `P1-P2` 线段包含的 K 线数量（含 `P1` 与 `P2`）小于 `InpP1P2AValueTimeMinKNumberLimit`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: b1+b2 相对 a 的比例不足时拒绝该骨架
- **WHEN** 某个候选骨架已经计算出 `a`、`b1` 和 `b2`，但 `(b1+b2) < InpBSumValueMinRatioOfAValue * a`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: 全部约束通过时输出完整匹配
- **WHEN** 某个候选序列在当前输入配置下同时满足 CondA、CondB、CondC、CondF 与三条新增结构约束
- **THEN** 检测器将该序列标记为完整模式匹配，并将其提供给交易处理逻辑

#### Scenario: 部分匹配不得用于交易
- **WHEN** 某个候选序列的 CondA、CondB、CondC、CondF 或任一新增结构约束失败
- **THEN** 检测器不会将该序列输出为可交易匹配
