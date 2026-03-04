## Context

当前策略在历史骨架阶段主要检查 `CondA`、单段跨度和 `a/bSum` 结构约束，在实时 `P4` 阶段再检查 `CondB` 与 `CondC`。这意味着一组 `P0-P4` 即使本身满足局部结构关系，只要前面没有足够清晰的先行下跌背景，仍可能被视为有效候选。

用户希望新增一个“先决条件模块”，其结果专门用于判定当前 `P0-P4` 结构是否具备成立背景，并且这个模块未来可能继续扩展多个条件。因此这次设计不应只塞入单个额外 `if`，而要先定义一个可扩展的 precondition 入口。

## Goals / Non-Goals

**Goals:**
- 在 `P0-P4` 候选进入完整匹配前，新增统一的 precondition 判断入口
- 实现首个 `PriorDecline` 规则：`Pre0 -> P0` 需要满足最小下跌空间和最小 bar 间隔
- 为该规则新增 3 个运行时参数，并给出清晰、可读的名称
- 让后续新增其他 preconditions 时不需要重写匹配主流程

**Non-Goals:**
- 不改变 `P0-P6` 点位定义和角色取值规则
- 不改变 `CondA`、`CondB`、`CondC`、止盈或弱止损公式
- 不在本次变更里实现第二个或更多 precondition 规则

## Decisions

### 1. 将 precondition 评估放在历史骨架阶段

`PriorDecline` 只依赖：

- `P0` 的索引与价格
- 已经算出的 `a + b1 + b2`
- `P0` 之前的历史 K 线

这些信息在 `BuildHistoricalBackbone()` 内已经齐备，因此最合适的位置是在骨架加入缓存前先执行 precondition。这样失败的骨架不会继续进入实时 `P4` 评估。

备选方案：
- 在 `EvaluateRealtimePatternFromBackbone()` 再检查
  否决原因：那时才拒绝会让无效骨架进入缓存，放大无效候选数量，也不符合“先决条件”的语义。

### 2. 先定义可扩展模块，再落地首个 `PriorDecline` 规则

实现层应抽出统一入口，例如“评估所有 pattern preconditions”，再让 `PriorDecline` 成为第一个子规则。即使当前只有一条规则，也要把聚合接口和单规则接口区分开。

备选方案：
- 直接在 `BuildHistoricalBackbone()` 里内联一个 `Pre0` 判断
  否决原因：后续第二条规则会继续堆叠条件，模块边界会很快变脏。

### 3. `PriorDecline` 使用存在性判断，日志采用最强命中的 `Pre0`

规则语义是“在 `P0` 前 `x` 根 K 线内，存在某个 `Pre0`”。因此通过条件应按“是否存在至少一个合格候选”判断。  
为了让日志和调试输出具备确定性，当多个候选都满足条件时，采用最高高点对应的那根 K 线作为最终记录的 `Pre0`。

备选方案：
- 固定选择离 `P0` 最近的合格 K 线
  否决原因：它不一定代表最强的前置下跌，解释性较弱。

### 4. 参数命名采用 `InpPreCondPriorDecline...` 前缀

本次采用以下输入名：

- `InpPreCondPriorDeclineLookbackBars = 20`
- `InpPreCondPriorDeclineMinDropRatioOfStructure = 0.7`
- `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0 = 0`

命名原则：

- `PreCond` 明确属于先决条件模块
- `PriorDecline` 对应“前置下跌”语义
- 后缀分别表达回看窗口、相对结构最小跌幅、`Pre0/P0` 最小间隔

备选方案：
- `InpPre0...` 系列
  否决原因：过度绑定当前规则，未来有第二条 precondition 时缺少统一归类前缀。

### 5. bar 数间隔按“不包含端点的中间 K 线数量”解释

该参数只统计 `Pre0` 与 `P0` 之间的中间 K 线数量，不包含 `Pre0` 和 `P0` 自身。因此实现口径应为：

```text
(i0 - pre0Index - 1) >= InpPreCondPriorDeclineMinBarsBetweenPre0AndP0
```

默认值 `0` 表示允许 `Pre0` 与 `P0` 相邻，只要两者之间没有额外的中间 K 线要求即可。  
同时，`lookback` 口径按“`P0` 之前的 x 根 K 线，不含 `P0` 当前 K 线”解释。

## Risks / Trade-offs

- [先决条件会显著减少可命中的 `P0-P4` 候选] -> Mitigation: 在 spec 和日志中明确这是有意收紧有效性定义。
- [新模块只有一条规则时看起来偏重] -> Mitigation: 这是为了后续可扩展性预留结构，避免二次重构。
- [`PriorDecline` 采用价格单位比例 `y * (a+b1+b2)`，不同 symbol 之间敏感度会不同] -> Mitigation: 先沿用当前结构变量口径；若后续出现跨品种适配问题，再单独提变更。

## Migration Plan

1. 新增运行时参数与输入校验。
2. 在历史骨架阶段加入统一 precondition 入口。
3. 实现 `PriorDecline` 子规则与必要日志字段。
4. 更新回测配置和 spec，确保默认值与行为一致。

## Open Questions

- 当前无需额外开放“启用/禁用该规则”的独立布尔参数，默认视为启用；若后续确有按规则开关的需要，再单独加 change。
