## MODIFIED Requirements

### Requirement: 从 MT5 K 线数据中识别 PRD 定义的 P0-P6 多头模式
策略 SHALL 针对每个已配置的交易品种和周期分析已收盘的 bar，并根据 `InpTradeDirectionMode` 识别当前启用方向的 `P0-P6` 候选点位。`LONG_ONLY` SHALL 仅保留多头模式，`SHORT_ONLY` SHALL 仅保留空头镜像模式，`BOTH` SHALL 同时评估两种方向。检测器 SHALL 为每个候选序列生成标准化模式快照，并显式记录其 `direction`、点位时间、点位价格、空间变量和时间变量。

#### Scenario: LONG_ONLY 模式下仅输出多头候选
- **WHEN** `InpTradeDirectionMode=LONG_ONLY`
- **THEN** 检测器只会输出满足多头结构的完整匹配，而不会输出空头镜像候选

#### Scenario: SHORT_ONLY 模式下仅输出空头候选
- **WHEN** `InpTradeDirectionMode=SHORT_ONLY`
- **THEN** 检测器只会输出满足空头镜像结构的完整匹配，而不会输出多头候选

#### Scenario: BOTH 模式下快照必须携带方向
- **WHEN** `InpTradeDirectionMode=BOTH` 且某个交易品种同时存在多头与空头候选
- **THEN** 检测器分别输出对应方向的模式快照，且每份快照都包含明确的 `direction`

### Requirement: 强制执行可配置的点位取值与单段跨度规则
策略 SHALL 继续使用 `InpAdjustPointMinSpanKNumber` 和 `InpAdjustPointMaxSpanKNumber` 共同限制相邻点之间的单段跨度，其中 `SpanKNumber` SHALL 定义为起点与终点之间中间间隔的 K 线数量。策略 SHALL 按方向固定点位角色，而 SHALL NOT 再允许通过统一的取价模式覆盖这种方向角色规则：多头模式中 `P0/P2/P5` 取低点、`P1/P3/P6` 取高点、`P4` 取实时 `ask`；空头镜像模式中 `P0/P2/P5` 取高点、`P1/P3/P6` 取低点、`P4` 取实时 `bid`。对于历史骨架中的每一条线段，策略 SHALL 按当前方向验证端点达到该段应有的整段极值，并默认允许并列极值。

#### Scenario: 多头模式使用低高低高角色映射
- **WHEN** 检测器在 `LONG_ONLY` 或 `BOTH` 模式下评估多头候选
- **THEN** 它使用 `P0/P2/P5=low`、`P1/P3/P6=high` 和 `P4=ask` 的角色映射来计算点位价格

#### Scenario: 空头模式使用高低高低角色映射
- **WHEN** 检测器在 `SHORT_ONLY` 或 `BOTH` 模式下评估空头候选
- **THEN** 它使用 `P0/P2/P5=high`、`P1/P3/P6=low` 和 `P4=bid` 的角色映射来计算点位价格

#### Scenario: 空头历史骨架也必须满足端点极值约束
- **WHEN** 某个空头候选的任一历史线段内部存在高于起点高点或低于终点低点的反向极值，导致端点不再是该段应有极值
- **THEN** 检测器拒绝该空头骨架，且不会将其输出为完整模式匹配

### Requirement: 仅在 CondA、CondB、CondC、CondF 与新增结构约束满足时确认完整匹配
策略 SHALL 仅在以下条件全部满足时将某个形态视为完整匹配：`b1 = x * b2` 且落在配置的 `x` 系数范围内，`r1 = c / (a+b1+b2)` 且满足 `r1 >= InpP3P4MoveMinRatioOfStructure`，`t4 < z * (t1 + t2 + t3)`，每个相邻点的中间 bar 数都同时满足 `InpAdjustPointMinSpanKNumber <= SpanKNumber <= InpAdjustPointMaxSpanKNumber`，`a >= InpP1P2AValueSpaceMinPriceLimit`，`P1-P2` 线段包含的 K 线数量（含 `P1` 与 `P2` 本身）大于或等于 `InpP1P2AValueTimeMinKNumberLimit`，`InpBSumValueMaxRatioOfAValue * a >= (b1+b2) >= InpBSumValueMinRatioOfAValue * a`，以及所有启用的 pattern preconditions 都通过。这里的 pattern preconditions SHALL 受 `InpPreCondEnable` 控制：当 `InpPreCondEnable=false` 时，策略 SHALL 跳过 `Pre0-P0` 前置条件并直接视为通过；当 `InpPreCondEnable=true` 时，策略 SHALL 在 `P0` 之前最近 `InpPreCondPriorMoveLookbackBars` 根 K 线内寻找 `Pre0`，要求 `Pre0-P0` 的方向性 move 大于 `InpPreCondPriorMoveMinRatioOfStructure * (a+b1)`，并要求 `Pre0` 与 `P0` 达到该段按当前方向应有的整段极值。对于实时触发段，策略 SHALL 额外要求 `P3` 达到 `P3->P4` 整段按当前方向的端点极值；若段内其他 bar 或 `P4` 所在 bar 出现与 `P3` 相同的并列极值，仍 SHALL 视为通过。当多个候选在同一时刻都能触发时，策略 SHALL 优先选择 `P3` 时间更晚的候选；若 `P3` 时间相同，则多头 SHALL 选择更低的 `P4`，空头 SHALL 选择更高的 `P4`。

#### Scenario: 多头实时触发段内部出现更高 high 时拒绝触发
- **WHEN** 某个多头候选已经满足其他历史结构条件，但 `P3->P4` 段内部存在高于 `P3.high` 的更高 high
- **THEN** 检测器拒绝该次多头 `P4` 触发，且不会将该序列输出为可交易匹配

#### Scenario: 空头实时触发段内部出现更低 low 时拒绝触发
- **WHEN** 某个空头候选已经满足其他历史结构条件，但 `P3->P4` 段内部存在低于 `P3.low` 的更低 low
- **THEN** 检测器拒绝该次空头 `P4` 触发，且不会将该序列输出为可交易匹配

#### Scenario: 同一 P3 时间下按方向选择更优的 P4
- **WHEN** 两个候选具有相同的 `P3` 时间且其他条件均成立
- **THEN** 检测器在多头方向选择更低的 `P4`，并在空头方向选择更高的 `P4`

#### Scenario: 全部约束与先决条件通过时输出方向化完整匹配
- **WHEN** 某个候选序列在当前输入配置下满足本 requirement 的全部结构约束、方向约束和启用的 pattern preconditions
- **THEN** 检测器将该序列标记为对应方向的完整模式匹配，并将其提供给交易处理逻辑
