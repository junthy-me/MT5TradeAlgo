## Context

当前模式筛选已具备 `b1+b2` 相对 `a` 的最小比例约束，但缺少上限约束，导致某些左右结构过度扩张的候选仍可通过历史骨架筛选并进入后续流程。此次变更需要在不恢复旧 `CondD`、不改变实时 `P4` 触发逻辑的前提下，为 `b1+b2` 增加相对 `a` 的最大比例边界，并通过统一参数面暴露给运行时。

## Goals / Non-Goals

**Goals:**
- 将 `b1+b2` 约束统一为区间规则：`InpBSumValueMaxRatioOfAValue*a >= (b1+b2) >= InpBSumValueMinRatioOfAValue*a`
- 新增 `InpBSumValueMaxRatioOfAValue`，默认值为 `5.0`
- 在主检测逻辑、简化语义规格、运行时参数规格中保持一致定义
- 让回测与线上运行在未显式配置新参数时也具备稳定默认行为

**Non-Goals:**
- 不修改 `CondA/CondB/CondC/CondF` 的既有定义
- 不恢复任何已移除的买价百分比噪声过滤
- 不调整止盈、弱止损、观察窗口等交易管理逻辑

## Decisions

### 1. 区间约束继续放在历史结构筛选路径
沿用当前 `b1+b2` 最小比例的生效位置，在历史骨架和完整匹配判定链路中执行区间约束，不引入新的实时入场阶段检查点。这样可复用已有变量与判定上下文，避免分散逻辑。

### 2. 新参数采用与现有命名一致的语义
新增参数命名为 `InpBSumValueMaxRatioOfAValue`，与 `InpBSumValueMinRatioOfAValue` 对称，便于理解为同一约束的上/下边界；默认值设置为 `5.0`，确保旧配置在未补参数时仍能运行。

### 3. 参数校验采用“有序区间”策略
运行时初始化阶段增加约束：`InpBSumValueMinRatioOfAValue > 0` 且 `InpBSumValueMaxRatioOfAValue >= InpBSumValueMinRatioOfAValue`。若不满足，策略应拒绝启动或输出明确错误，防止产生反向区间。

### 4. 日志保持可解释性最小增量
保留 `a`、`b1`、`b2`、`b1+b2` 输出字段，并在判定失败原因中区分“低于下限”与“高于上限”，便于回测对照，不引入额外复杂日志结构。

## Risks / Trade-offs

- [候选数量可能进一步下降，影响信号密度] -> Mitigation: 默认上限给到 `5.0`，先以宽松上界上线，再用回测逐步收紧。
- [新旧参数组合可能出现非法区间] -> Mitigation: 增加初始化校验并在参数说明中强调 `max >= min`。
- [跨品种下相同比例上限的有效性可能不一致] -> Mitigation: 保持参数可调，后续如需分品种模板再通过独立 change 处理。
