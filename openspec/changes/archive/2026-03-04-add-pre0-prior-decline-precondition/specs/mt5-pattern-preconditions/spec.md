## ADDED Requirements

### Requirement: 在形态确认前执行可扩展的先决条件模块
策略 SHALL 在当前 `P0-P4` 候选被视为有效之前执行一个可扩展的 pattern preconditions 模块。该模块 SHALL 支持挂载多个独立规则，并以“所有启用规则都通过”为总通过条件。任一规则失败时，当前候选 SHALL 被视为无效，不得继续作为有效形态进入后续流程。

#### Scenario: 所有启用规则通过时保留候选
- **WHEN** 当前 `P0-P4` 候选通过了 pattern preconditions 模块中的所有启用规则
- **THEN** 策略保留该候选，并允许其继续进入后续完整匹配流程

#### Scenario: 任一启用规则失败时拒绝候选
- **WHEN** 当前 `P0-P4` 候选在 pattern preconditions 模块中至少有一条启用规则失败
- **THEN** 策略将该候选视为无效，且不会把它继续用于后续完整匹配或交易判断

### Requirement: 支持 Pre0 到 P0 的前置下跌先决条件
策略 SHALL 支持一个名为 `PriorDecline` 的先决条件规则。对任一候选骨架，策略 SHALL 在 `P0` 之前最近 `InpPreCondPriorDeclineLookbackBars` 根 K 线中搜索候选 `Pre0`。`Pre0` SHALL 取候选 K 线的最高点，并且仅当同时满足以下条件时，该规则才视为通过：存在至少一个候选 `Pre0` 使得 `(Pre0High - P0Price) > InpPreCondPriorDeclineMinDropRatioOfStructure * (a + b1 + b2)`，且 `Pre0` 与 `P0` 之间不包含端点的中间 K 线数量大于或等于 `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0`。

#### Scenario: 存在满足最小跌幅与最小中间间隔的 Pre0
- **WHEN** 当前骨架在 `P0` 之前的搜索窗口内至少存在一个 `Pre0`，其高点到 `P0` 的跌幅满足最小结构比例，且 `Pre0/P0` 之间的中间 K 线数量满足最小要求
- **THEN** `PriorDecline` 规则通过

#### Scenario: 搜索窗口内不存在合格的 Pre0
- **WHEN** 当前骨架在 `P0` 之前的搜索窗口内没有任何 `Pre0` 同时满足最小跌幅与最小中间 K 线间隔
- **THEN** `PriorDecline` 规则失败

#### Scenario: 多个 Pre0 同时满足时采用最高高点作为记录结果
- **WHEN** `P0` 之前的搜索窗口内有多个 `Pre0` 都满足 `PriorDecline` 规则
- **THEN** 策略将其中最高高点对应的 `Pre0` 作为该次规则命中的记录结果
