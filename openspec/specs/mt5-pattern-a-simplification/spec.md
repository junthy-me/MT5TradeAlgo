## ADDED Requirements

### Requirement: 匹配条件不得再让 a 单独作为独立门槛
策略 SHALL 保留 `a` 的计算与日志输出，但不得再通过 `a` 单独定义独立匹配门槛。`CondB` SHALL 改为 `r1 >= InpRatioC`，`CondD` SHALL 被移除。

#### Scenario: 使用新的 CondB 规则
- **WHEN** 某个候选序列计算出 `r1`
- **THEN** 策略使用 `r1 >= InpRatioC` 判断 `CondB` 是否通过，而不是使用旧的 `r1/r2` 区间判断

#### Scenario: 不再执行 CondD 判断
- **WHEN** 某个候选序列已经计算出 `c` 与 `a`
- **THEN** 策略不会再执行 `c < m*a` 形式的 `CondD` 判断

### Requirement: 入场噪声过滤必须改为基于 b1+b2 的买价百分比
策略 SHALL 删除基于 `a / buyPrice` 的 `CondG`，并将 `CondH` 改为 `((b1+b2) / buyPrice) * 100 >= NoiseFilter_bSumValueCompBuyPricePercent`。

#### Scenario: 使用新的 CondH 规则
- **WHEN** 某个候选入场信号在准备提交买单时已经计算出 `b1`、`b2` 与 `buyPrice`
- **THEN** 策略使用 `((b1+b2) / buyPrice) * 100` 与 `NoiseFilter_bSumValueCompBuyPricePercent` 比较，决定新的 `CondH` 是否通过

#### Scenario: 不再执行 CondG 过滤
- **WHEN** 某个候选入场信号进入噪声过滤阶段
- **THEN** 策略不会再执行基于 `a / buyPrice` 的 `CondG` 判断

### Requirement: 参数与日志必须反映 a 的新角色
策略 SHALL 删除不再使用的旧参数，新增 `InpRatioC` 与 `NoiseFilter_bSumValueCompBuyPricePercent`，并在日志中继续打印 `a` 作为调试字段，同时补充新的 `CondB` 与 `CondH` 判定明细。

#### Scenario: 参数集更新
- **WHEN** 操作人员查看或配置策略输入参数
- **THEN** 策略暴露新的 `InpRatioC` 与 `NoiseFilter_bSumValueCompBuyPricePercent`，并不再暴露已废弃的旧参数

#### Scenario: 日志保留 a 并展示新规则
- **WHEN** 策略输出入场日志或过滤失败日志
- **THEN** 日志继续包含 `a` 的调试信息，并展示新的 `CondB`、`CondH` 计算口径与阈值
