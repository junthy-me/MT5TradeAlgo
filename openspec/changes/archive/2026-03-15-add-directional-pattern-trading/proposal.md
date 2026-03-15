## Why

当前 `P4PatternStrategy` 只能识别上涨骨架并执行做多，无法对同一结构的空头镜像形态进行匹配和交易。这使策略只能覆盖单边场景，也把大量已经在代码中固化为“下跌、低点、买入”的语义散落在检测、风控、标注和配置层，后续扩展做空时容易出现规则漂移和命名误导。

## What Changes

- 为策略新增方向模式输入 `InpTradeDirectionMode`，支持 `LONG_ONLY`、`SHORT_ONLY`、`BOTH` 三种取值，并将其同时作用于模式检测与交易执行。
- 将 `P0-P6` 模式识别扩展为方向感知版本：在保留现有多头规则的同时，新增其空头镜像形态的点位角色、极值约束、实时 `P4` 触发和候选优先级规则。
- 将交易管理扩展为同时支持做多和做空，要求做空沿用与做多一致的强止损、弱止损、`P5/P6` 激活、止盈和共享骨架/观察窗口门控，只是价格比较方向与价位推导按镜像规则反转。
- 明确多空继续共享现有运行时风控门控，包括 `InpMaxPositionsPerSymbol`、`P4` bar 锁、共享骨架成功锁，以及止盈/止损观察窗口，而不是拆成独立的多头/空头计数口径。
- **BREAKING**: 将当前带有多头偏置语义的输入项和相关文档术语改为方向中性命名，例如把“prior decline / drop”一类名称改为“prior move”，把仅描述下跌触发的结构阈值改为统一的方向性 move 语义，并同步更新配置文件、README 和 OpenSpec 文案。
- 将图表标注和日志摘要扩展为方向感知输出，使成功入场、`P5/P6` 激活和关键结构值既能表达多头买点，也能表达空头卖点。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `mt5-kline-pattern-detection`: 修改模式检测要求，使其支持 `LONG_ONLY / SHORT_ONLY / BOTH` 三种方向模式，并对多头与空头镜像形态统一使用方向感知的点位角色、结构变量和中性术语。
- `mt5-pattern-preconditions`: 修改前置条件要求，使 `Pre0-P0` 规则从“前置下跌”扩展为方向感知的“前置 move”规则，并统一记录与命名口径。
- `mt5-pattern-trade-management`: 修改交易管理要求，使策略能基于镜像空头模式做空，并明确多空共享当前入场门控、观察窗口和持仓上限规则。
- `mt5-pattern-chart-annotations`: 修改图表标注要求，使模式图、关键数值、`P4` 强调标记和后续 `P5/P6` 激活标注都能表达多头与空头两种方向。
- `mt5-strategy-runtime-controls`: 新增 `InpTradeDirectionMode` 输入，并将当前带有多头偏置的运行时参数名称与默认值说明改为方向中性语义。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5` 的历史骨架搜索、实时 `P4` 触发、前置条件评估、订单执行、持仓管理、日志与图表标注路径都将改为方向感知实现。
- Affected configs/docs: `mt5/configs/*.ini`、`README.md` 以及引用旧参数名或旧多头术语的说明文档都需要同步更新。
- Affected specs: `openspec/specs/mt5-kline-pattern-detection/spec.md`, `openspec/specs/mt5-pattern-preconditions/spec.md`, `openspec/specs/mt5-pattern-trade-management/spec.md`, `openspec/specs/mt5-pattern-chart-annotations/spec.md`, `openspec/specs/mt5-strategy-runtime-controls/spec.md`
