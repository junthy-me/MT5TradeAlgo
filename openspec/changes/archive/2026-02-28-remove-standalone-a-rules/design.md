## Context

当前策略保留了 `a`、`b1`、`b2` 等空间变量，但 `a` 还被单独用于 `CondD`、`CondG`、`CondH` 门槛以及强止损/止盈价格推导。这使策略在 `a` 较小或局部结构较密集时容易出现额外边界情况，也使参数语义分散。此次调整的目标不是删除 `a` 变量，而是让 `a` 退出“单独支配规则”的位置，只保留其作为结构变量和调试信息的角色。

## Goals / Non-Goals

**Goals:**
- 保留原有点位、空间变量和时间变量定义不变。
- 让 `a` 不再单独参与独立条件判断和独立止损/止盈尺度推导。
- 让匹配条件与噪声过滤更多依赖整体结构量，如 `r1` 和 `b1+b2`。
- 删除废弃参数并补充新的日志字段，保持调试可追踪。

**Non-Goals:**
- 不改变 P0-P6 点位定义。
- 不删除 `a` 的计算或日志输出。
- 不改变持仓管理主流程与 P5/P6 弱止损激活机制。

## Decisions

### 1. CondB 改为单阈值 `r1 >= InpRatioC`
`CondB` 不再使用 `r1/r2` 区间判断，而是直接要求 `r1 >= InpRatioC`，其中 `InpRatioC` 默认值为 `0.4`。

原因：
- 避免通过 `r2` 让 `a` 继续间接充当独立门槛。
- 条件更直接，参数更容易解释。

备选方案：
- 保持原有 `r1/r2` 范围。否决原因是仍然保留了对 `a` 的复杂依赖。

### 2. 删除 CondD 与 CondG，并重写 CondH
- `CondD` 删除，不再要求 `c < m*a`
- `CondG` 删除
- `CondH` 改为 `((b1+b2)/buyPrice) * 100 >= NoiseFilter_bSumValueCompBuyPricePercent`

原因：
- 删除 `a` 作为单独门槛的直接使用。
- 用 `b1+b2` 表达历史结构两侧的整体尺度，更符合“整体结构强度”直觉。

### 3. 强止损价直接锚定 P0，止盈价基于整体结构振幅
- `hardLossPrice = P0 点位值`
- `profitPrice = entryPrice + InpProfitC * (b1+b2+a)`
- `InpProfitC` 默认值改为 `1.8`

原因：
- 强止损直接锚定历史结构低点，规则更稳定、更易解释。
- 止盈价不再只看 `a`，而是使用整个历史结构振幅。

### 4. `a` 继续保留为调试变量
日志继续打印 `a`、`P1/P2` 等字段，但这些信息仅用于观察，不再单独决定策略是否触发或风控价格如何计算。

### 5. 删除废弃参数并替换为新参数
删除：
- `InpCondBYMin`
- `InpCondBYMax`
- `InpCondDM`
- `InpHardLossC`
- `NoiseFilter_aValueCompBuyPricePercent`
- `NoiseFilter_maxBValueCompAValueProd`

新增或调整：
- `InpRatioC`，默认 `0.4`
- `NoiseFilter_bSumValueCompBuyPricePercent`，默认 `0.5`
- `InpProfitC` 默认值改为 `1.8`

## Risks / Trade-offs

- [删除 `a` 的单独门槛后，入场信号数量可能增加] -> Mitigation: 通过新的 `CondH` 和回测重新观察噪声过滤效果。
- [强止损改为 P0 后，部分交易的止损距离可能显著变大] -> Mitigation: 在日志和回测中重点观察止损距离分布。
- [CondB 改为单阈值会改变参数语义] -> Mitigation: 新增参数名并明确默认值，避免沿用旧参数造成误解。
- [旧参数删除会影响现有测试配置] -> Mitigation: 在变更说明和实现中同步更新参数清单。
