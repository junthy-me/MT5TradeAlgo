## MODIFIED Requirements

### Requirement: 仅在 CondA、CondB、CondC、CondF 与新增结构约束满足时确认完整匹配
策略 SHALL 仅在以下条件全部满足时将某个形态视为完整匹配：`b1 = x * b2` 且落在配置的 `x` 系数范围内，`r1 = c / (a+b1+b2)` 且满足 `r1 >= InpP3P4DropMinRatioOfStructure`，`t4 < z * (t1 + t2 + t3)`，每个相邻点跨度都小于或等于 `InpAdjustPointMaxSpanKNumber`，`a >= InpP1P2AValueSpaceMinPriceLimit`，`P1-P2` 线段包含的 K 线数量（含 `P1` 与 `P2` 本身）大于或等于 `InpP1P2AValueTimeMinKNumberLimit`，`(b1+b2) >= InpBSumValueMinRatioOfAValue * a`，以及所有启用的 pattern preconditions 都通过。

#### Scenario: a 的空间约束不足时拒绝该骨架
- **WHEN** 某个候选骨架已经计算出 `a`，但 `a < InpP1P2AValueSpaceMinPriceLimit`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: a 的时间约束不足时拒绝该骨架
- **WHEN** 某个候选骨架的 `P1-P2` 线段包含的 K 线数量（含 `P1` 与 `P2`）小于 `InpP1P2AValueTimeMinKNumberLimit`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: b1+b2 相对 a 的比例不足时拒绝该骨架
- **WHEN** 某个候选骨架已经计算出 `a`、`b1` 和 `b2`，但 `(b1+b2) < InpBSumValueMinRatioOfAValue * a`
- **THEN** 检测器拒绝该骨架，且不会将其输出为完整模式匹配

#### Scenario: 先决条件失败时拒绝该候选
- **WHEN** 某个候选序列已经满足 `CondA`、`CondB`、`CondC`、`CondF` 与现有结构约束，但至少一条启用的 pattern precondition 失败
- **THEN** 检测器仍然拒绝该候选，且不会将其输出为可交易匹配

#### Scenario: 全部约束与先决条件通过时输出完整匹配
- **WHEN** 某个候选序列在当前输入配置下同时满足 `CondA`、`CondB`、`CondC`、`CondF`、现有结构约束和全部启用的 pattern preconditions
- **THEN** 检测器将该序列标记为完整模式匹配，并将其提供给交易处理逻辑

#### Scenario: 部分匹配不得用于交易
- **WHEN** 某个候选序列的 `CondA`、`CondB`、`CondC`、`CondF`、任一现有结构约束或任一启用的 pattern precondition 失败
- **THEN** 检测器不会将该序列输出为可交易匹配
