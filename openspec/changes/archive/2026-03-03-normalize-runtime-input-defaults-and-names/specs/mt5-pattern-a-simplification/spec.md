## MODIFIED Requirements

### Requirement: 参数与日志必须反映 a 的新结构约束语义
策略 SHALL 删除不再使用的旧参数，并将当前使用的 `InpMinP3P4DropRatioOfStructure` 进一步统一重命名为 `InpP3P4DropMinRatioOfStructure`。策略 SHALL 暴露 `InpP1P2AValueSpaceMinPriceLimit`、`InpP1P2AValueTimeMinKNumberLimit` 和 `InpBSumValueMinRatioOfAValue` 三个新的运行时参数，并在匹配日志中继续输出 `a`、`b1`、`b2` 与 `P1-P2` 线段跨度，便于解释这些结构约束的实际命中情况。运行时默认 `InpProfitC` SHALL 为 `0.6`。

#### Scenario: 参数集更新
- **WHEN** 操作人员查看或配置策略输入参数
- **THEN** 策略暴露 `InpP3P4DropMinRatioOfStructure`、`InpP1P2AValueSpaceMinPriceLimit`、`InpP1P2AValueTimeMinKNumberLimit` 和 `InpBSumValueMinRatioOfAValue`，并不再暴露 `InpRatioC` 或 `InpMinP3P4DropRatioOfStructure`

#### Scenario: 日志保留解释新约束所需字段
- **WHEN** 策略输出匹配日志
- **THEN** 日志包含 `a`、`b1`、`b2` 以及 `P1-P2` 线段跨度等字段，足以解释为何某个骨架通过或失败

#### Scenario: 止盈默认系数更新
- **WHEN** 操作人员未显式覆盖止盈系数
- **THEN** 策略使用默认 `InpProfitC = 0.6`
