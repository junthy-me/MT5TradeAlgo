## Why

当前策略只要通过 CondA 到 CondF 就会尝试按 P4 参考价入场，但这仍可能让振幅过小或结构不够清晰的噪声形态进入交易流程。为降低噪声数据带来的误触发，需要在下买单前增加两条额外过滤条件，确保 `a` 与买价、以及 `b1/b2` 与 `a` 的关系达到最小强度要求。

## What Changes

- 新增两条入场前噪声过滤条件，并将其作为完整买入前置条件的一部分。
- 新增参数 `NoiseFilter_aValueCompBuyPricePercent`，用于约束 `(a / 买价) >= x%`，默认值为 `1`。
- 新增参数 `NoiseFilter_maxBValueCompAValueProd`，用于约束 `max(b1, b2) >= y * a`，默认值为 `1.5`。
- 调整入场判定规则，使策略只有在原有 CondA 到 CondF 通过且两条噪声过滤条件同时满足时才允许提交买单。
- 增加噪声过滤条件的日志输出，便于观察被过滤掉的候选信号及其原因。

## Capabilities

### New Capabilities
- `mt5-entry-noise-filters`: 为 MT5 P4 模式策略增加入场前噪声过滤条件、参数配置和日志输出，确保振幅过小或结构过弱的候选形态不会触发买单。

### Modified Capabilities

无。

## Impact

- 影响 MT5 EA 的入场前校验逻辑和输入参数定义。
- 影响模式快照或交易决策结构，需要补充新的条件标记和阈值参数。
- 影响日志内容，需要输出新增噪声过滤条件的计算值和是否通过。
