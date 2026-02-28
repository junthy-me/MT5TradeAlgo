## Why

当前弱止损激活条件从 `(e - d) >= n * c` 调整为 `e >= n * (c + d)`，这是一次明确的交易规则变更，需要被正式记录进 OpenSpec，而不是只停留在实现层。与此同时，`InpSoftLossN` 的默认值也从 `0.5` 调整为 `0.65`，需要让默认配置与规格说明保持一致。

## What Changes

- 修改弱止损激活条件：由 `(e - d) >= n * c` 改为 `e >= n * (c + d)`。
- 将 `InpSoftLossN` 的默认值从 `0.5` 调整为 `0.65`。
- 保持弱止损价位公式不变，仍为 `soft_loss_price = softLossC * Price_P5`。
- 更新交易管理规格和验证任务，使弱止损激活条件、默认参数和实现保持一致。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mt5-pattern-trade-management`: 修改弱止损的激活条件和默认参数语义，保留弱止损价位公式不变。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5` 中 `InpSoftLossN` 默认值和 `UpdateSoftStopState()` 的弱止损激活判断。
- Affected behavior: 弱止损从“反弹净超出量覆盖 `c` 的比例”改为“`P5P6` 高度覆盖 `P3P4 + P4P5` 总高度的比例”。
- Validation: 需要验证新的激活条件按 `e >= InpSoftLossN * (c + d)` 生效，且默认参数 `0.65` 在回测中能正常工作。
