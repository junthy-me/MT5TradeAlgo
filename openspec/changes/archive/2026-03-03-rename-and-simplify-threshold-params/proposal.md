## Why

当前 EA 的若干输入参数名称过于抽象，只有结合代码公式才能理解其含义。同时，`InpMaxAdjustPointSpan` 与 `NoiseFilter_bSumValueCompBuyPricePercent` 这两条过滤规则已经不再符合当前使用方式，继续保留只会增加调参与解释成本。

## What Changes

- **BREAKING** 删除 `InpMaxAdjustPointSpan` 输入参数，并移除基于“相邻线段数量”的形态过滤。
- **BREAKING** 将 `InpRatioC` 重命名为更明确的 `InpMinP3P4DropRatioOfStructure`，语义保持为 `r1 = c / (a+b1+b2)` 的最小阈值。
- **BREAKING** 将 `InpSoftLossN` 重命名为更明确的 `InpMinP5P6ReboundRatioOfP3P5Drop`，语义保持为 `e / (c+d)` 的最小阈值。
- **BREAKING** 将 `InpProfitC` 默认值从 `1.8` 调整为 `0.6`。
- **BREAKING** 删除 `NoiseFilter_bSumValueCompBuyPricePercent` 输入参数，并移除基于 `(b1+b2) / buyPrice` 的入场噪声过滤。
- 同步更新日志、规格文档和历史参数说明，避免继续暴露废弃参数名。

## Capabilities

### New Capabilities

### Modified Capabilities

- `mt5-kline-pattern-detection`: 移除相邻线段数量过滤，只保留单段跨度限制，并更新完整匹配条件描述。
- `mt5-pattern-a-simplification`: 重命名 `CondB` 与弱止损相关参数，删除 `CondH` 噪声过滤与对应参数要求。
- `mt5-pattern-trade-management`: 将弱止损激活比例参数名称更新为新名称，并保持现有激活公式。

## Impact

- Affected code: [mt5/P4PatternStrategy.mq5](/Users/junthy/Work/MT5TradeAlgo/mt5/P4PatternStrategy.mq5)
- Affected specs: `openspec/specs/mt5-kline-pattern-detection/spec.md`, `openspec/specs/mt5-pattern-a-simplification/spec.md`, `openspec/specs/mt5-pattern-trade-management/spec.md`
- Affected configs: 现有 `.ini` 回测配置若仍使用旧参数名，需要改成新参数名并移除废弃字段
