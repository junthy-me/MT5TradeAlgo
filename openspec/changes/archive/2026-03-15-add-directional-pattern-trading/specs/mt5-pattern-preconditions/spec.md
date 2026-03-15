## MODIFIED Requirements

### Requirement: 支持 Pre0 到 P0 的前置下跌先决条件
策略 SHALL 支持一个方向感知的 `PriorMove` 先决条件规则。对任一候选骨架，策略 SHALL 在 `P0` 之前最近 `InpPreCondPriorMoveLookbackBars` 根 K 线中搜索候选 `Pre0`，并要求 `Pre0` 与 `P0` 之间不包含端点的中间 K 线数量大于或等于 `InpPreCondPriorMoveMinBarsBetweenPre0AndP0`。对于多头候选，`Pre0` SHALL 取候选区间的最高点，并且仅当 `(Pre0High - P0Low) > InpPreCondPriorMoveMinRatioOfStructure * (a + b1)` 且 `Pre0->P0` 线段满足“`Pre0` 达到整段最高点、`P0` 达到整段最低点”时，该规则才视为通过。对于空头候选，`Pre0` SHALL 取候选区间的最低点，并且仅当 `(P0High - Pre0Low) > InpPreCondPriorMoveMinRatioOfStructure * (a + b1)` 且 `Pre0->P0` 线段满足“`Pre0` 达到整段最低点、`P0` 达到整段最高点”时，该规则才视为通过。若存在多个合格 `Pre0`，策略 SHALL 记录当前方向上 move 最强的那个结果。

#### Scenario: 多头候选存在合格的前置上端点时通过
- **WHEN** 当前多头骨架在搜索窗口内存在一个 `Pre0`，其高点到 `P0` 的下行 move 满足最小结构比例，且 `Pre0/P0` 之间的中间 K 线数量满足最小要求
- **THEN** `PriorMove` 规则通过，并记录该 `Pre0`

#### Scenario: 空头候选存在合格的前置下端点时通过
- **WHEN** 当前空头骨架在搜索窗口内存在一个 `Pre0`，其低点到 `P0` 的上行 move 满足最小结构比例，且 `Pre0/P0` 之间的中间 K 线数量满足最小要求
- **THEN** `PriorMove` 规则通过，并记录该 `Pre0`

#### Scenario: 搜索窗口内不存在合格的方向性 Pre0 时失败
- **WHEN** 当前骨架在搜索窗口内没有任何 `Pre0` 同时满足最小 move 比例、最小中间 K 线间隔和该方向要求的端点极值约束
- **THEN** `PriorMove` 规则失败

#### Scenario: 多个 Pre0 同时满足时记录当前方向上 move 最强的结果
- **WHEN** 搜索窗口内存在多个 `Pre0` 都满足 `PriorMove` 规则
- **THEN** 策略记录多头方向上最高的 `Pre0` 或空头方向上最低的 `Pre0` 作为该次规则命中的结果
