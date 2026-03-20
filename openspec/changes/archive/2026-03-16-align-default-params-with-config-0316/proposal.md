## Why

当前 EA 源码中的默认输入值和 2026-03-16 使用的基线配置快照 `/Users/junthy/Desktop/config_0316.png` 不一致。继续保留旧默认值会让新挂载或未显式导入 ini 的运行环境偏离当前实际使用参数，增加回测和实盘复现成本。

## What Changes

- 将 EA 的默认输入值对齐到 `config_0316.png` 中当前可见的配置快照。
- 同步更新默认值相关的运行时规格和 README 参数表，避免源码、文档和测试界面口径漂移。
- 保持参数名、校验逻辑和交易行为公式不变，只调整默认值。

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `mt5-strategy-runtime-controls`: 更新多项运行时输入的默认值，使其与 `config_0316.png` 保持一致。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5`
- Affected specs: `openspec/specs/mt5-strategy-runtime-controls/spec.md`
- Affected docs: `README.md`
