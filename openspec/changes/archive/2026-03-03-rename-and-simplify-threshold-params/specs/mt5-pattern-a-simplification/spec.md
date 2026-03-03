## MODIFIED Requirements

### Requirement: 匹配条件不得再让 a 单独作为独立门槛
策略 SHALL 保留 `a` 的计算与日志输出，但不得再通过 `a` 单独定义独立匹配门槛。`CondB` SHALL 改为 `r1 >= InpMinP3P4DropRatioOfStructure`，`CondD` SHALL 被移除。

#### Scenario: 使用新的 CondB 规则
- **WHEN** 某个候选序列计算出 `r1`
- **THEN** 策略使用 `r1 >= InpMinP3P4DropRatioOfStructure` 判断 `CondB` 是否通过，而不是使用旧的 `r1/r2` 区间判断

#### Scenario: 不再执行 CondD 判断
- **WHEN** 某个候选序列已经计算出 `c` 与 `a`
- **THEN** 策略不会再执行 `c < m*a` 形式的 `CondD` 判断

### Requirement: 入场阶段不得再执行 b1+b2 买价百分比噪声过滤
策略 SHALL 删除基于 `a / buyPrice` 的 `CondG`，也 SHALL 删除基于 `((b1+b2) / buyPrice) * 100` 的 `CondH`。候选入场信号进入发单阶段后，策略 SHALL NOT 再因为 `b1+b2` 相对买价的百分比阈值而阻止开仓。

#### Scenario: 不再执行 CondH 过滤
- **WHEN** 某个候选入场信号进入发单前检查阶段
- **THEN** 策略不会再将 `((b1+b2) / buyPrice) * 100` 与任何输入阈值比较来决定是否阻止开仓

#### Scenario: 不再暴露 b1+b2 噪声过滤参数
- **WHEN** 操作人员查看或配置策略输入参数
- **THEN** 策略不会再暴露 `NoiseFilter_bSumValueCompBuyPricePercent`

### Requirement: 参数与日志必须反映新的比例参数语义
策略 SHALL 删除不再使用的旧参数，并将 `InpRatioC` 重命名为 `InpMinP3P4DropRatioOfStructure`。策略在日志中继续打印 `a` 作为调试字段，同时继续展示 `CondB` 的实际值与阈值。运行时默认 `InpProfitC` SHALL 为 `0.6`。

#### Scenario: 参数集更新
- **WHEN** 操作人员查看或配置策略输入参数
- **THEN** 策略暴露 `InpMinP3P4DropRatioOfStructure`，并不再暴露 `InpRatioC`

#### Scenario: 日志展示新的 CondB 阈值语义
- **WHEN** 策略输出入场日志
- **THEN** 日志包含 `r1` 与 `InpMinP3P4DropRatioOfStructure`，且不再输出已删除的 `CondH` 阈值字段

#### Scenario: 止盈默认系数更新
- **WHEN** 操作人员未显式覆盖止盈系数
- **THEN** 策略使用默认 `InpProfitC = 0.6`
