## Why

当前策略只根据 `P0-P4` 本身的结构关系判断候选是否有效，但缺少“该结构出现之前是否已经存在足够明确的前置下跌背景”的验证。这会让部分局部形态在缺乏先决趋势支撑时仍被当作有效信号，需要新增一个可扩展的 precondition 模块来先做背景筛选。

## What Changes

- **BREAKING** 在 `P0-P4` 形态被视为有效之前，新增一个先决条件模块；只有当该模块通过时，当前匹配才可继续进入后续完整匹配与交易流程。
- 新增第一个先决条件规则：在 `P0` 之前的限定回看窗口内，必须存在一个候选 `Pre0` K 线，其最高点到 `P0` 的跌幅满足最小结构比例门槛，且 `Pre0` 与 `P0` 之间满足最小 K 线间隔。
- 将该模块设计为可扩展结构，后续可以继续挂载多个先决条件，而不是把所有逻辑硬编码进单一 `Cond`。
- 新增 3 个运行时输入参数及默认值：
  - `InpPreCondPriorDeclineLookbackBars = 20`
  - `InpPreCondPriorDeclineMinDropRatioOfStructure = 0.7`
  - `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0 = 0`
- 同步更新规格、设计和日志语义，明确 `Pre0` 使用候选 K 线的最高点参与判断。

## Capabilities

### New Capabilities

- `mt5-pattern-preconditions`: 定义可扩展的先决条件模块，以及首个 `Pre0 -> P0` 前置下跌规则

### Modified Capabilities

- `mt5-kline-pattern-detection`: 在确认当前 `P0-P4` / 完整匹配有效前，必须执行并通过先决条件模块
- `mt5-strategy-runtime-controls`: 暴露首个前置下跌先决条件所需的运行时输入参数和默认值

## Impact

- Affected code: [mt5/P4PatternStrategy.mq5](/Users/junthy/Work/MT5TradeAlgo/mt5/P4PatternStrategy.mq5)
- Affected specs: `openspec/specs/mt5-kline-pattern-detection/spec.md`, `openspec/specs/mt5-strategy-runtime-controls/spec.md`, new `openspec/specs/mt5-pattern-preconditions/spec.md`
- Affected configs: 回测 `.ini` / `.set` 如需显式配置该规则，需要新增 3 个参数；未显式配置时走默认值
