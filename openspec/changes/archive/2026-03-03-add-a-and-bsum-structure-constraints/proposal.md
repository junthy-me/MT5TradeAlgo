## Why

当前策略已经移除了大部分围绕 `a` 的独立过滤，但实际使用中仍然需要排除 `P1-P2` 下跌幅度过小、持续时间过短，或 `b1+b2` 相对 `a` 过弱的骨架。现在需要把这些更细的历史结构约束正式收敛为可配置规则，而不是继续靠经验解释。

## What Changes

- 为 `a` 增加最小空间约束：`a >= InpP1P2AValueSpaceMinPriceLimit`
- 为 `a` 增加最小时间约束：`P1-P2` 线段包含的 K 线数（含两端）`>= InpP1P2AValueTimeMinKNumberLimit`
- 为 `b1+b2` 增加相对 `a` 的结构约束：`b1+b2 >= InpBSumValueMinRatioOfAValue * a`
- 新增对应运行时输入参数及默认值：`5`、`3`、`2`
- 更新规格，明确这些约束发生在历史骨架筛选阶段，而不是实时 `P4` 触发阶段

## Capabilities

### New Capabilities

### Modified Capabilities

- `mt5-kline-pattern-detection`: 在完整匹配前新增 `a` 的最小空间/时间约束和 `b1+b2` 相对 `a` 的最小比例约束
- `mt5-pattern-a-simplification`: 调整 `a` 的角色定义，允许在历史骨架阶段重新作为有限的结构过滤条件使用
- `mt5-strategy-runtime-controls`: 新增三项控制上述约束的运行时输入参数及默认值

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5`
- Affected specs: `openspec/specs/mt5-kline-pattern-detection/spec.md`, `openspec/specs/mt5-pattern-a-simplification/spec.md`, `openspec/specs/mt5-strategy-runtime-controls/spec.md`
- Affected configs: 回测 `.ini` 需要新增三个参数，或依赖 EA 默认值运行
