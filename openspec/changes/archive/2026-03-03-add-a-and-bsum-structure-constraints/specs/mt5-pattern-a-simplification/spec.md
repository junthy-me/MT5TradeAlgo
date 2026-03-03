## REMOVED Requirements

### Requirement: 匹配条件不得再让 a 单独作为独立门槛
**Reason**: 本变更明确允许 `a` 在历史骨架阶段重新参与最小空间、最小时间和 `b1+b2` 相对 `a` 的比例筛选。
**Migration**: 后续应将 `a` 的角色理解为“不得再用于旧的 `c < m*a` 风控和价格推导，但可用于历史结构质量约束”。

## ADDED Requirements

### Requirement: 历史骨架阶段允许使用 a 的最小结构约束
策略 SHALL 在历史骨架筛选阶段使用 `a` 的最小空间约束、最小时间约束以及 `b1+b2` 相对 `a` 的最小比例约束来过滤候选结构。该使用范围 SHALL 限定在历史骨架阶段，而 SHALL NOT 恢复旧的 `CondD` 或其它基于 `a` 的即时入场风控规则。

#### Scenario: a 作为历史骨架空间与时间下限
- **WHEN** 某个候选骨架已经计算出 `a` 与 `P1-P2` 线段跨度
- **THEN** 策略使用 `InpP1P2AValueSpaceMinPriceLimit` 与 `InpP1P2AValueTimeMinKNumberLimit` 判断该骨架是否保留

#### Scenario: b1+b2 相对 a 的比例作为结构强度约束
- **WHEN** 某个候选骨架已经计算出 `a`、`b1` 与 `b2`
- **THEN** 策略使用 `(b1+b2) >= InpBSumValueMinRatioOfAValue * a` 判断该骨架是否具备足够的左右结构展开

#### Scenario: 不恢复旧的 CondD
- **WHEN** 某个候选序列进入实时 `P4` 评估阶段
- **THEN** 策略不会重新执行 `c < m*a` 形式的旧 `CondD` 判断

### Requirement: 参数与日志必须反映 a 的新结构约束语义
策略 SHALL 暴露 `InpP1P2AValueSpaceMinPriceLimit`、`InpP1P2AValueTimeMinKNumberLimit` 和 `InpBSumValueMinRatioOfAValue` 三个新的运行时参数，并在匹配日志中继续输出 `a`、`b1`、`b2` 与 `P1-P2` 线段跨度，便于解释这些结构约束的实际命中情况。

#### Scenario: 参数集更新
- **WHEN** 操作人员查看或配置策略输入参数
- **THEN** 策略暴露三项新的 a/bSum 结构约束参数及其默认值

#### Scenario: 日志保留解释新约束所需字段
- **WHEN** 策略输出匹配日志
- **THEN** 日志包含 `a`、`b1`、`b2` 以及 `P1-P2` 线段跨度等字段，足以解释为何某个骨架通过或失败
