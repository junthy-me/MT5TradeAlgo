## Why

当前策略把 `Pre0P0`、`P0P1`、`P1P2`、`P2P3` 和 `P3P4` 上的整段极值约束硬编码在检测流程里，无法按回测场景单独放松某一段的端点极值要求。这使得使用者无法系统比较“严格骨架”与“部分放宽骨架”在命中率和交易质量上的差异，也无法仅保留 `P3` 触发段极值控制而关闭部分历史段约束。

## What Changes

- 新增运行时参数 `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4`，使用固定顺序的 5 位逗号分隔布尔字符串来控制各相邻线段是否启用整段极值约束。
- 修改模式检测规则，使 `Pre0P0`、`P0P1`、`P1P2`、`P2P3` 四段可按配置决定是否检查两个端点的整段极值。
- 修改实时触发规则，使 `P3P4` 可按配置决定是否检查 `P3` 在 `P3->P4` 线段中的整段极值，并明确 `P4` 不受该位控制。
- 修改运行时参数契约，要求策略对该字符串参数执行严格解析，并在配置非法时显式报错而不是静默回退。

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `mt5-kline-pattern-detection`: 将历史骨架与实时触发段的整段极值检查从固定启用改为按段配置，并明确 `P3P4` 仅控制 `P3`。
- `mt5-strategy-runtime-controls`: 新增相邻段整段极值配置参数，并定义其格式、默认值和非法配置处理规则。

## Impact

- Affected specs: `openspec/specs/mt5-kline-pattern-detection/spec.md`, `openspec/specs/mt5-strategy-runtime-controls/spec.md`
- Affected code: `mt5/P4PatternStrategy.mq5`, related `.ini` configs, and `README.md`
- No external dependencies are added.
