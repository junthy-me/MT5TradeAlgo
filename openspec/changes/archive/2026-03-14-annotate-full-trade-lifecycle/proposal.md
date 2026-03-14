## Why

当前图表标注还没有把单笔交易完整生命周期内的结构点、结构值和风控线一次性、稳定地可视化出来，操作者需要结合日志和已有图形才能还原完整模式结构。现在需要在不改动交易核心逻辑的前提下，把每次成交对应的 `Pre0/P0/P1/P2/P3/P4/P5/P6`、`a/b1/b2/c/d/e`、强止损线和弱止损线完整标注到图上，并让相同点位在不同交易中始终使用固定颜色，降低人工识别成本。

## What Changes

- 扩展图表标注范围，在每次成交后为该交易绘制完整生命周期点位 `Pre0`、`P0`、`P1`、`P2`、`P3`、`P4`、`P5`、`P6`。
- 扩展结构值标注，在图上显示该交易对应的 `a`、`b1`、`b2`、`c`、`d`、`e`。
- 扩展风控可视化，在图上标注强止损线和弱止损线，并与交易对象命名空间绑定。
- 规定点位颜色契约：`Pre0`、`P0`、`P1`、`P2`、`P3`、`P4`、`P5`、`P6` 使用固定且彼此不同的颜色，并在不同交易间保持一致。
- 明确该 change 只允许修改绘图与标注行为，**不会**改动模式匹配、下单、止盈止损或其他核心交易逻辑。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mt5-pattern-chart-annotations`: 扩展成交后图表标注的覆盖范围、固定颜色映射和完整生命周期结构值/止损线可视化要求。

## Impact

- Affected specs: `openspec/specs/mt5-pattern-chart-annotations/spec.md`
- Affected code: `mt5/P4PatternStrategy.mq5` 中的 chart annotation、对象命名、颜色映射和文本/线条绘制辅助函数
- No API or dependency changes
- No intended changes to entry, exit, risk management, or pattern-matching behavior
