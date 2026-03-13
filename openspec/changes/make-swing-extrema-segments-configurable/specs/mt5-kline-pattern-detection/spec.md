## MODIFIED Requirements

### Requirement: 强制执行可配置的点位取值与单段跨度规则
策略 SHALL 继续使用 `InpAdjustPointMinSpanKNumber` 和 `InpAdjustPointMaxSpanKNumber` 共同限制相邻点之间的单段跨度，其中 `SpanKNumber` SHALL 定义为起点与终点之间中间间隔的 K 线数量。策略 SHALL 按方向固定点位角色，而 SHALL NOT 再允许通过统一的取价模式覆盖这种方向角色规则：多头模式中 `P0/P2/P5` 取低点、`P1/P3/P6` 取高点、`P4` 取实时 `ask`；空头镜像模式中 `P0/P2/P5` 取高点、`P1/P3/P6` 取低点、`P4` 取实时 `bid`。策略 SHALL 根据 `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 对相邻线段的整段极值约束逐段启用或禁用，参数顺序 SHALL 固定为 `Pre0P0`、`P0P1`、`P1P2`、`P2P3`、`P3P4`。当 `P0P1`、`P1P2` 或 `P2P3` 对应配置位为 `true` 时，策略 SHALL 按当前方向验证该线段两个端点都达到该段应有的整段极值，并默认允许并列极值；当对应配置位为 `false` 时，策略 SHALL 跳过该线段的整段极值检查。

#### Scenario: 多头模式使用低高低高角色映射
- **WHEN** 检测器在 `LONG_ONLY` 或 `BOTH` 模式下评估多头候选
- **THEN** 它使用 `P0/P2/P5=low`、`P1/P3/P6=high` 和 `P4=ask` 的角色映射来计算点位价格

#### Scenario: 空头模式使用高低高低角色映射
- **WHEN** 检测器在 `SHORT_ONLY` 或 `BOTH` 模式下评估空头候选
- **THEN** 它使用 `P0/P2/P5=high`、`P1/P3/P6=low` 和 `P4=bid` 的角色映射来计算点位价格

#### Scenario: 禁用 P0P1 线段整段极值约束
- **WHEN** `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 的 `P0P1` 位置为 `false`
- **THEN** 检测器不会因为 `P0` 或 `P1` 未达到 `P0->P1` 线段的整段极值而拒绝该候选

#### Scenario: 启用 P2P3 时空头骨架仍必须满足端点极值约束
- **WHEN** `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 的 `P2P3` 位置为 `true` 且某个空头候选的 `P2->P3` 线段内部存在破坏端点极值的反向极值
- **THEN** 检测器拒绝该空头骨架，且不会将其输出为完整模式匹配

### Requirement: 仅在 CondA、CondB、CondC、CondF 与新增结构约束满足时确认完整匹配
策略 SHALL 仅在以下条件全部满足时将某个形态视为完整匹配：`b1 = x * b2` 且落在配置的 `x` 系数范围内，`r1 = c / (a+b1+b2)` 且满足 `r1 >= InpP3P4MoveMinRatioOfStructure`，`t4 < z * (t1 + t2 + t3)`，每个相邻点的中间 bar 数都同时满足 `InpAdjustPointMinSpanKNumber <= SpanKNumber <= InpAdjustPointMaxSpanKNumber`，`a >= InpP1P2AValueSpaceMinPriceLimit`，`P1-P2` 线段包含的 K 线数量（含 `P1` 与 `P2` 本身）大于或等于 `InpP1P2AValueTimeMinKNumberLimit`，`InpBSumValueMaxRatioOfAValue * a >= (b1+b2) >= InpBSumValueMinRatioOfAValue * a`，以及所有启用的 pattern preconditions 都通过。这里的 pattern preconditions SHALL 受 `InpPreCondEnable` 控制：当 `InpPreCondEnable=false` 时，策略 SHALL 跳过 `Pre0-P0` 前置条件并直接视为通过；当 `InpPreCondEnable=true` 时，策略 SHALL 在 `P0` 之前最近 `InpPreCondPriorMoveLookbackBars` 根 K 线内寻找 `Pre0`，要求 `Pre0-P0` 的方向性 move 大于 `InpPreCondPriorMoveMinRatioOfStructure * (a+b1)`，并仅在 `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 的 `Pre0P0` 位置为 `true` 时，要求 `Pre0` 与 `P0` 达到该段按当前方向应有的整段极值。对于实时触发段，策略 SHALL 仅在该参数的 `P3P4` 位置为 `true` 时，额外要求 `P3` 达到 `P3->P4` 整段按当前方向的端点极值；若段内其他 bar 或 `P4` 所在 bar 出现与 `P3` 相同的并列极值，仍 SHALL 视为通过。无论 `P3P4` 的取值为何，策略 SHALL NOT 要求 `P4` 达到该线段另一端的整段极值。当多个候选在同一时刻都能触发时，策略 SHALL 优先选择 `P3` 时间更晚的候选；若 `P3` 时间相同，则多头 SHALL 选择更低的 `P4`，空头 SHALL 选择更高的 `P4`。

#### Scenario: 关闭 Pre0P0 线段极值后前置条件只保留 move 约束
- **WHEN** `InpPreCondEnable=true` 且 `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 的 `Pre0P0` 位置为 `false`
- **THEN** 检测器只根据 `Pre0-P0` 的方向性 move 和 bar 间隔评估前置条件，而不会因为 `Pre0` 或 `P0` 未达到该段整段极值而拒绝候选

#### Scenario: 启用 P3P4 时只验证 P3
- **WHEN** `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 的 `P3P4` 位置为 `true`
- **THEN** 检测器只验证 `P3` 是否达到 `P3->P4` 线段按当前方向应有的整段极值，而不会要求 `P4` 达到该线段另一端的整段极值

#### Scenario: 关闭 P3P4 后实时触发不再执行 P3 整段极值检查
- **WHEN** `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` 的 `P3P4` 位置为 `false` 且某个候选满足其他完整匹配条件
- **THEN** 检测器不会因为 `P3->P4` 线段内部存在破坏 `P3` 端点极值的价格而拒绝该次触发

#### Scenario: 全部约束与先决条件通过时输出方向化完整匹配
- **WHEN** 某个候选序列在当前输入配置下满足本 requirement 的全部结构约束、方向约束和启用的 pattern preconditions
- **THEN** 检测器将该序列标记为对应方向的完整模式匹配，并将其提供给交易处理逻辑
