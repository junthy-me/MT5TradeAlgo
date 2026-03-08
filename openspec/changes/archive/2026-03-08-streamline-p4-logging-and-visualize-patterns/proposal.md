## Why

当前 EA 的运行日志覆盖了大量阻止原因、观察窗口和持仓管理细节，默认输出噪声过高。对于真正关心买点的人来说，最重要的是“这次 P4 买点到底匹配到了哪组 Pre0-P0-P1-P2-P3-P4，以及后续是否走出了 P5/P6 和对应止损位”，而仅靠长日志文本很难快速还原出具体模式。

## What Changes

- 收缩默认日志输出，只保留与成功 `P4` 买点直接相关的关键信息打印。
- 重新组织买点日志格式，重点明确输出本次成交所使用的 `P0-P4` 各点时间与价格。
- 为每次成功买入的模式在图表上绘制可见标注，让操作者能直接看到该笔单使用的是哪组 `Pre0-P0-P1-P2-P3-P4`，并在后续首次激活时补出 `P5/P6`。
- 在图表上补充关键结构高度标注，包括 `Pre0-P0` 下跌值、`b1`、`a`、`b2` 和 `c`，以及强止损/弱止损位置。
- 新增图形标注的生命周期规则，确保对象命名、重复买点和多次入场时的可追踪性清晰可控。

## Capabilities

### New Capabilities
- `mt5-pattern-chart-annotations`: 为每次成功触发的 `P4` 买点在图表上绘制 `Pre0-P4` 模式标注、固定点位配色和关键高度值，并在首次合格 `P5/P6` 激活后补出 `P5/P6` 与止损位，支持通过图形对象直观看到对应买入所用的模式。

### Modified Capabilities
- `mt5-pattern-trade-management`: 默认日志输出从“全量生命周期明细”收缩为“成功 P4 买点摘要”，并要求买点日志明确列出 `P0-P4` 点位信息。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5`, `README.md`
- Affected systems: MT5 Experts log output, attached chart object rendering
- No external dependencies expected; implementation relies on native MT5 chart object APIs
