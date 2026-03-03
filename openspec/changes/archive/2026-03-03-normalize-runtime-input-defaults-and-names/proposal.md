## Why

当前 EA 的部分输入参数默认值偏离最新使用习惯，且两个比例参数名仍把“Min”放在前缀位置，读起来不够统一。需要把默认值与命名整理到当前约定，避免回测配置、日志解释和后续文档继续沿用旧表述。

## What Changes

- **BREAKING** 将 `InpMaxPositionsPerSymbol` 默认值从 `10` 调整为 `1`。
- **BREAKING** 将 `InpLookbackBars` 默认值从 `120` 调整为 `300`。
- **BREAKING** 将 `InpAdjustPointMaxSpanKNumber` 默认值从 `5` 调整为 `10`。
- **BREAKING** 将 `InpMinP3P4DropRatioOfStructure` 重命名为 `InpP3P4DropMinRatioOfStructure`，保持 `r1 = c / (a+b1+b2)` 的最小阈值语义不变。
- **BREAKING** 将 `InpMinP5P6ReboundRatioOfP3P5Drop` 重命名为 `InpP5P6ReboundMinRatioOfP3P5Drop`，保持 `e / (c+d)` 的最小阈值语义不变。
- 同步更新规格、实现、日志和仓库内回测参数示例，避免继续暴露旧名称或旧默认值。

## Capabilities

### New Capabilities

### Modified Capabilities

- `mt5-strategy-runtime-controls`: 更新运行时输入面板中的持仓上限与历史回看默认值。
- `mt5-kline-pattern-detection`: 更新点跨度默认值，并把 P3-P4 结构跌幅阈值参数改为统一命名。
- `mt5-pattern-a-simplification`: 将历史骨架与日志语义中的 P3-P4 结构阈值参数名切换为统一命名。
- `mt5-pattern-trade-management`: 将弱止损激活使用的 P5-P6 反弹比例参数名切换为统一命名。

## Impact

- Affected code: [mt5/P4PatternStrategy.mq5](/Users/junthy/Work/MT5TradeAlgo/mt5/P4PatternStrategy.mq5)
- Affected specs: `openspec/specs/mt5-strategy-runtime-controls/spec.md`, `openspec/specs/mt5-kline-pattern-detection/spec.md`, `openspec/specs/mt5-pattern-a-simplification/spec.md`, `openspec/specs/mt5-pattern-trade-management/spec.md`
- Affected configs: 仓库内引用旧参数名或依赖旧默认值的回测 `.ini` / 文档示例需要同步更新
