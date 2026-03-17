## Why

当前 `PriorMove` 前置条件的最小 move 比例使用 `(a + b1)` 作为结构分母，这会低估包含第二段回撤/反弹 `b2` 的完整结构尺度。对于同一组 `P0-P4` 骨架，阈值偏小会让部分前置 move 在相对结构上被判得过松，和当前结构定义不一致。

## What Changes

- 将 `PriorMove` 前置条件最小 move 比例的结构分母从 `(a + b1)` 调整为 `(a + b1 + b2)`。
- 同步更新多头与空头方向下的规则描述、示例公式和相关文档口径。
- 保持 `Pre0` 搜索窗口、方向极值约束、最小间隔和 strongest `Pre0` 选择逻辑不变。

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `mt5-pattern-preconditions`: `PriorMove` 前置条件的结构比例分母改为 `a + b1 + b2`。

## Impact

- Affected specs: `openspec/specs/mt5-pattern-preconditions/spec.md`
- Affected code: `mt5/P4PatternStrategy.mq5`
- Affected docs: `README.md`
