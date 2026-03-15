## Context

当前 `mt5/P4PatternStrategy.mq5` 的核心路径默认了“上涨骨架 -> `P4` 回落 -> 买入 -> 后续 `P5/P6` 激活”的单一方向语义。这个假设不仅体现在 `trade.Buy(...)` 上，也体现在以下层面：

- 历史骨架点位角色固定为 `P0/P2/P5=low`、`P1/P3/P6=high`
- `P4` 实时触发固定使用 `ask`，并以“`P4 < P3`、`c = P3 - P4`”判定成立
- `P5/P6` 跟踪固定为“先创新低 `P5`，再反弹形成 `P6`”
- 强止损、弱止损、止盈的比较方向固定基于多头持仓
- 前置条件、参数、日志和图表标注大量使用 `decline`、`drop`、`buy`、`low/high at P5` 等多头偏置命名

这意味着如果直接为做空复制一套分支逻辑，检测、风控、日志和配置命名会迅速分叉，后续很难保证多空两套规则保持真正镜像。另一方面，用户已经确认本次变更必须满足三项约束：

- 新增方向开关，取值为 `LONG_ONLY / SHORT_ONLY / BOTH`
- 多空继续共享现有运行时风控门控
- 当前偏多头的输入命名和文档术语需要改成方向中性

因此，这次更适合先在设计层引入统一的方向抽象，再让 specs 和实现沿这个抽象展开。

## Goals / Non-Goals

**Goals:**

- 让同一套模式搜索与持仓管理框架同时支持多头模式和空头镜像模式
- 用单一 `PatternDirection` 抽象复用 `a/b1/b2/c/d/e` 等结构变量，而不是复制两套独立公式
- 新增运行时方向开关 `InpTradeDirectionMode`，并让它同时控制检测与下单
- 保持 `InpMaxPositionsPerSymbol`、观察窗口、`P4` bar 锁和共享骨架成功锁继续按 `symbol + timeframe` 共享
- 将偏多头的参数名、日志术语和文档语义改成方向中性命名，同时明确兼容性影响

**Non-Goals:**

- 不引入新的形态家族，只支持当前 `P0-P6` 结构的空头镜像版本
- 不把多空拆成各自独立的持仓上限、观察窗口或共享骨架状态
- 不在本次设计里重做仓位管理、手数计算或组合级风控
- 不为了做空支持而放弃现有 exact compare、缓存搜索或图表标注机制

## Decisions

### 1. 用单一方向抽象贯穿模式检测和交易管理

设计中引入显式方向枚举，例如：

- `PATTERN_DIRECTION_LONG`
- `PATTERN_DIRECTION_SHORT`

并把它写入 `PatternSnapshot` 和相关运行时状态。多头为 `dir = +1`，空头为 `dir = -1`，统一使用方向归一化后的结构变量：

- `b1 = dir * (P2 - P0)`
- `a = dir * (P1 - P2)`
- `b2 = dir * (P3 - P1)`
- `c = dir * (P3 - P4)`
- `d = dir * (P4 - P5)`
- `e = dir * (P6 - P5)`

这样长短两个方向都能继续使用“这些量必须为正值”的既有约束表达。

原因：

- 可以最大程度复用当前 `CondA / CondB / CondC / bSum / P5P6` 规则，避免把同一业务公式写成两套。
- 后续 spec 和日志可以围绕“方向归一化后的结构量”描述，而不是把每条规则写成多空两份。

备选方案：

- 为 long 和 short 分别实现两套 `BuildHistoricalBackbone`、`EvaluateRealtimePattern...`、`ManageOpenPositions`。
  否决原因：实现面看似直接，但后续每次改规则都要双改，长期更容易漂移。

### 2. 方向只改变角色映射和比较方向，不改变策略阶段结构

虽然做空是新增能力，但整体状态机继续保留当前分层：

- 历史骨架 `P0-P3`
- 实时 `P4` 触发
- 入场后跟踪 `P5/P6`
- 首次激活弱止损和唯一止盈
- 强止损 / 弱止损 / 止盈退出

方向变化体现在这些点上：

- 点位角色：多头为 `low/high/low/high/...`，空头镜像为 `high/low/high/low/...`
- 实时触发价格侧：多头 `P4=ask`，空头 `P4=bid`
- 出场比较侧：多头持仓按 `bid` 判断，空头持仓按 `ask` 判断
- `P5/P6` 候选：多头选更低 `P5`，空头选更高 `P5`
- 候选优先级：多头同 `P3` 时选更低 `P4`，空头选更高 `P4`

原因：

- 保留当前阶段结构，可以把这次复杂度集中在“方向化”上，而不是连状态机一起改。
- 共享相同的管理阶段，也更符合“做空逻辑和做多一致，只不过点位相反”的要求。

备选方案：

- 为做空设计另一套不同的 `P5/P6` 状态机。
  否决原因：需求没有要求新状态机，只要求镜像对称。

### 3. 通过角色访问器封装 high/low 取价和极值约束

当前代码已经把点位角色固定在 `GetRoleLow()` / `GetRoleHigh()` 以及若干 `SegmentHasAscendingEndpointExtrema()` 这类 helper 上。本次不应把方向判断散落到每个调用点，而应新增方向感知的角色访问器与线段判定 helper，例如：

- `GetPointPriceByRole(direction, pointLabel, rate)`
- `SegmentHasDirectionalEndpointExtrema(direction, startRole, endRole, ...)`
- `GetRealtimeEntryReferencePrice(direction, tick)`
- `GetManagedExitReferencePrice(direction, tick)`

原因：

- 这能把“方向差异”压缩到少数基础 helper 中，降低主流程分支数量。
- 历史骨架、前置条件、实时 `P3->P4` 极值验证都依赖相同的端点极值语义，适合共享底层工具。

备选方案：

- 在每个调用点分别写 `if(long) high else low`。
  否决原因：容易漏改，也会让 specs 难以对应实现结构。

### 4. 运行时方向开关采用单一参数 `InpTradeDirectionMode`

新增输入 `InpTradeDirectionMode`，支持：

- `LONG_ONLY`
- `SHORT_ONLY`
- `BOTH`

它控制两个层面：

- 哪些方向的候选会被历史搜索和实时触发保留
- 最终允许向交易层提交哪些方向的入场请求

默认值保持 `LONG_ONLY`。

原因：

- 这样能保持当前默认行为不变，降低升级后回测和线上行为突变的风险。
- 单一参数同时作用于检测和执行，可以避免出现“检测到 short 但运行时仍只允许 long 下单”这类割裂状态。

备选方案：

- 分成“检测方向参数”和“交易方向参数”两套开关。
  否决原因：配置复杂度更高，且本次没有这样的需求。

### 5. 多空继续共享现有风控门控和运行时状态口径

本次不会把以下状态拆成按方向隔离：

- `InpMaxPositionsPerSymbol`
- `lastSuccessfulEntryBarTime`
- `lastProfitTargetExitBarTime`
- `lastStopExitBarTime`
- backbone success lock

也就是说，当方向模式是 `BOTH` 时，同一 `symbol + timeframe` 下多空信号仍然共享这些门控。

原因：

- 这是用户明确确认的设计约束。
- 共享门控能保持当前风险口径最接近现状，避免同一品种在短时间内被多空同时放大交易频率。

备选方案：

- 按 `symbol + direction` 分别维护门控状态。
  否决原因：会显著改变当前策略节奏，不属于本次范围。

### 5.1 `BOTH` 模式暂时只输出一个最终候选

在 `BOTH` 模式下，当前实现会同时评估多头和空头候选，但在检测阶段只保留一个最终候选快照继续流入后续交易门控，而不是把两个方向的最终候选都保留下来再由交易层裁决。

原因：

- 这能保持当前实现和运行时状态结构更简单，避免在本次变更里把“检测结果集合”扩展成多候选流水线。
- 现有共享门控已经按 `symbol + timeframe` 生效，先保留单候选输出不会改变当前交易层的节奏。

权衡：

- 这种做法会丢失“另一个方向其实也成立过”的检测事实，`BOTH` 模式下的可审计性弱于双快照方案。
- 如果未来需要更强的回测解释性或实盘排障能力，可以再把检测层扩展为保留双方向快照，并交由交易层统一应用共享门控。

### 6. 命名迁移采用“参数、字段、文档一起改”的显式 breaking 方案

当前存在大量偏多头命名，例如：

- `InpPreCondPriorDeclineLookbackBars`
- `InpPreCondPriorDeclineMinDropRatioOfStructure`
- `pre0Drop`
- `InpP3P4DropMinRatioOfStructure`

本次设计选择直接迁移到中性命名，例如：

- `InpPreCondPriorMoveLookbackBars`
- `InpPreCondPriorMoveMinExtentRatioOfStructure`
- `pre0MoveExtent`
- `InpP3P4MoveMinRatioOfStructure`

具体命名以 specs 为准，但原则是：

- 不再在输入名中固化 `decline / drop / buy`
- 文档和日志里优先使用 `move`、`entry`、`direction`
- 图表强调标记不再只叫 `BUY`

原因：

- 如果只在实现内部做方向抽象，而外部接口还保留“decline/drop/buy”命名，用户配置和认知会持续偏斜。
- 这类名称迁移属于规范层面的契约变更，应该在 change 中明确为 breaking。

备选方案：

- 保留旧参数名，只在 README 里解释“做空时它代表反向含义”。
  否决原因：短期省事，但长期会让参数语义越来越难懂。

### 7. 图表和日志继续复用同一条路径，但必须携带 direction

当前 `DrawEntryPatternAnnotation()` 和 `LogEntry()/LogP5Activation()` 已经集中在少数函数里，这适合继续复用，但要做两类调整：

- 视觉对象改成方向感知，例如 `P4` 强调标记使用买入或卖出图形，数值标注和对象前缀带上 `direction`
- 日志字段和对象命名不再隐含“buy”，至少明确输出 `direction=long|short`

原因：

- 这条路径天然集中，改对一次就能覆盖默认摘要输出和图上标注。
- 如果日志不携带方向，`BOTH` 模式下的审计价值会明显下降。

备选方案：

- 让 short 不画图，只保留交易功能。
  否决原因：与当前策略重视可视化复盘的方向不一致。

## Risks / Trade-offs

- [方向抽象改动面广，容易在某条旧路径残留多头假设] -> Mitigation: specs 逐层覆盖检测、前置条件、交易、标注和运行时输入，并在实现阶段保留 exact compare 与定向回测验证。
- [参数重命名会影响现有 `.ini` 和使用者习惯] -> Mitigation: 在 change 中明确为 breaking change，并在 README / configs 中同步迁移，避免文档和运行参数脱节。
- [`BOTH` 模式下多空共享门控可能让部分镜像机会被同 bar 或观察窗口拦截] -> Mitigation: 在 specs 中明确这是有意保留的风险控制语义，而不是实现缺陷。
- [`BOTH` 模式当前只输出一个最终候选，导致另一方向的检测结果不可见] -> Mitigation: 当前先接受这个实现复杂度取舍，并在 specs / README 中明确记录；后续如果需要提升可审计性，再优化为双快照输出。
- [空头的 `P5/P6` 选择规则如果没有完全镜像，容易出现止盈止损方向反了的问题] -> Mitigation: 所有 `d/e/profit/soft stop` 公式都以方向归一化变量表达，并在设计和 spec 中明确“多头取最低 `P5`，空头取最高 `P5`”。
- [图表和日志命名调整可能影响现有排障习惯] -> Mitigation: 保留 `P0-P6` 主体结构不变，只在方向和中性命名上增量调整。

## Migration Plan

1. 基于 proposal 先更新 delta specs，明确方向抽象、共享门控和中性命名的 requirement。
2. 在实现阶段先引入方向枚举、方向模式输入和底层角色 helper，再逐步改检测、前置条件、交易和标注路径。
3. 同步迁移 `mt5/configs/*.ini`、`README.md` 和日志术语，确保新参数名成为唯一权威口径。
4. 通过编译、定向回测和多空镜像场景验证，确认 `LONG_ONLY` 保持兼容、`SHORT_ONLY` 和 `BOTH` 行为符合预期。

Rollback:

- 若实现阶段发现方向抽象导致结果大面积漂移，可暂时保留 `InpTradeDirectionMode=LONG_ONLY` 作为默认且唯一启用路径，并回滚未完成的中性命名改动。
- 若参数迁移影响过大，可在实现前重新评估是否需要保留短期兼容别名；当前设计默认不保留别名。

## Open Questions

- 中性命名的最终字段名需要在 specs 阶段逐项定稿，尤其是 `drop` 与 `decline` 相关参数应统一采用 `move`、`extent` 还是 `distance` 这组术语。
- `BOTH` 模式下是否需要在日志或图表上进一步增强方向区分，例如不同颜色或不同箭头形状；当前设计认为需要，但具体表现形式留到 specs 固化。
