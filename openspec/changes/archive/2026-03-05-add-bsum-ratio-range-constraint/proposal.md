## Why

当前策略仅对 `b1+b2` 设置了相对 `a` 的最小比例约束，缺少上限约束，导致部分左右结构过度扩张的骨架仍可能进入后续匹配与交易流程。需要补齐 `b1+b2` 的区间限制，使结构筛选在强度和尺度上都可控且可解释。

## What Changes

- 将 `b1+b2` 结构约束从“仅下限”升级为“上下限区间”：
  `InpBSumValueMaxRatioOfAValue * a >= (b1+b2) >= InpBSumValueMinRatioOfAValue * a`
- 新增运行时输入参数 `InpBSumValueMaxRatioOfAValue`
- 设定 `InpBSumValueMaxRatioOfAValue` 默认值为 `5.0`
- 更新历史骨架筛选与完整匹配相关规格，明确该上限约束与现有下限约束共同生效

## Capabilities

### New Capabilities

### Modified Capabilities

- `mt5-kline-pattern-detection`: 将 `b1+b2` 相对 `a` 的约束改为上下限区间，补充“超上限拒绝”的行为定义
- `mt5-pattern-a-simplification`: 明确历史骨架阶段的 `b1+b2` 约束为区间规则（最小+最大比例），并继续限定在历史骨架阶段
- `mt5-strategy-runtime-controls`: 新增 `InpBSumValueMaxRatioOfAValue` 运行时参数并定义默认值 `5.0`

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5`
- Affected specs:
  - `openspec/specs/mt5-kline-pattern-detection/spec.md`
  - `openspec/specs/mt5-pattern-a-simplification/spec.md`
  - `openspec/specs/mt5-strategy-runtime-controls/spec.md`
- Affected configs: 回测参数集（`.set` / `.ini`）可新增 `InpBSumValueMaxRatioOfAValue`，未配置时使用默认值 `5.0`
