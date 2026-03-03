## MODIFIED Requirements

### Requirement: 仅在 CondA、CondB、CondC、CondF 与新增结构约束满足时确认完整匹配
策略 SHALL 仅在以下条件全部满足时将某个形态视为完整匹配：`b1 = x * b2` 且落在配置的 `x` 系数范围内，`r1 = c / (a+b1+b2)` 且满足 `r1 >= InpMinP3P4DropRatioOfStructure`，`t4 < z * (t1 + t2 + t3)`，每个相邻点跨度都小于或等于 `AdjustPointMaxSpanKNumber`，`a >= InpP1P2AValueSpaceMinPriceLimit`，`P1-P2` 线段包含的 K 线数量（含 `P1` 与 `P2` 本身）大于或等于 `InpP1P2AValueTimeMinKNumberLimit`，以及 `(b1+b2) >= InpBSumValueMinRatioOfAValue * a`。

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
