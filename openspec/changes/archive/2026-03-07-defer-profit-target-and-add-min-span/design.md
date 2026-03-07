## Context

当前 `mt5/P4PatternStrategy.mq5` 在 `EvaluateRealtimePatternFromBackbone()` 中会为每个通过 `P4` 实时触发的候选直接生成初始 `profitPrice = P4 + InpProfitC * (a+b1+b2)`，随后在 `ManageOpenPositions()` 中始终把 `profitPrice` 视为已激活的有效止盈位。持仓首次出现合格 `P5/P6` 后，策略再把 `profitPrice` 改写为 `selectedP5 + InpP5AnchoredProfitC * (a+b1+b2)`。

与此同时，历史骨架的 `pointSpans[0..3]` 当前按点位索引差计算：

- `P0->P1 = i1 - i0`
- `P1->P2 = i2 - i1`
- `P2->P3 = i3 - i2`
- `P3->P4 = (latestClosedIndex + 1) - i3`

这相当于把起点和终点之间的“步数”当作跨度，但并没有表达“只统计中间间隔 K 线数量”的业务口径。新的需求要求：

- 删除初始止盈阶段，只在首次合格 `P5/P6` 后激活唯一止盈位
- 为 `P0->P1` 到 `P3->P4` 四段统一引入最小/最大跨度区间
- 将跨度口径改成“两点之间中间 bar 数”

这是一个跨越模式搜索、实时触发和持仓管理的联动变更，适合先在设计层把状态语义和跨度口径写死。

## Goals / Non-Goals

**Goals:**

- 移除 `InpProfitC` 及其对应的开仓即有初始止盈阶段
- 让持仓在首次合格 `P5/P6` 出现之前只受强止损管理
- 保持首次合格 `P5/P6` 激活时“最低合格 `P5` 选择 + 弱止损激活 + 唯一止盈激活”三者绑定为同一次状态迁移
- 新增 `InpAdjustPointMinSpanKNumber`，并将 `InpAdjustPointMaxSpanKNumber` 默认值调到 `30`
- 将 `SpanKNumber` 统一改为“中间 bar 数”口径，并同时作用于 cached 搜索、legacy exact 搜索和最终结构过滤
- 保持日志、README 和 specs 对上述新语义的一致描述

**Non-Goals:**

- 不改变 `P0-P3` 的角色取价方式，也不改变 `P4` 使用实时 `ask` 的触发方式
- 不改变 `P5/P6` 的合格条件，仍然使用 `e >= InpP5P6ReboundMinRatioOfP3P5Drop * (c + d)`
- 不把首次 `P5/P6` 激活改成 trailing 机制，首次激活后依然冻结 `selectedP5`
- 不改变止盈/止损观察窗口的现有并联门控语义

## Decisions

### 1. 将 `profitPrice` 的业务语义改为“可未激活”

开仓后不再推导初始止盈位。持仓在首次出现合格 `P5/P6` 之前，`profitPrice` 处于未激活状态；只有在首次合格 `P5/P6` 出现后，才一次性写入：

- `softLossPrice = InpSoftLossC * selectedP5`
- `profitPrice = selectedP5 + InpP5AnchoredProfitC * (a+b1+b2)`

原因：

- 仅删除 `InpProfitC` 还不够，必须同时引入“止盈未激活”语义，否则开仓前 stale 检查和持仓中的 `profit_target` 检查都会把 `0` 当成有效价格。
- 这样可以保持 `hard stop -> later soft stop/profit target` 的阶段性状态机清晰可读。

备选方案：

- 用 `profitPrice = 0` 代替“未激活”，但保留原先所有判断逻辑  
  否决原因：会导致 `tick.ask >= pattern.profitPrice` 和 `currentBid >= snapshot.profitPrice` 立即误判。

### 2. 首次合格 `P5/P6` 激活后，`InpP5AnchoredProfitC` 成为唯一止盈系数

移除 `InpProfitC` 后，`InpP5AnchoredProfitC` 不再是“第二阶段止盈改写系数”，而是“唯一止盈公式系数”。其公式保持不变：

`profitPrice = selectedP5 + InpP5AnchoredProfitC * (a+b1+b2)`

原因：

- 这样能让“没有合格 `P5/P6` 就没有止盈位”的业务规则保持单一、明确。
- 延续用户已经确认的 `selectedP5` 选择和冻结规则，避免重新引入第二套止盈参数。

备选方案：

- 为“无初始止盈”再增加另一套兜底止盈参数  
  否决原因：会把系统重新带回多阶段止盈，不符合本次需求。

### 3. `SpanKNumber` 统一改为“中间 bar 数”

新的跨度定义为：

`span = endIndex - startIndex - 1`

其业务含义是：

- 不包含起点所在 K 线
- 不包含终点所在 K 线
- 只统计中间间隔的 K 线数量

对应结果：

- 相邻两点时，`span = 0`
- 若两点之间隔着 5 根 K 线，则 `span = 5`

原因：

- 这是用户明确确认的新口径。
- 该口径比“索引差”更直接对应“中间间隔了多少根 K 线”的策略含义。

备选方案：

- 继续沿用索引差口径  
  否决原因：与用户确认的跨度定义不符。
- 改成“包含首尾 bar 数”口径  
  否决原因：同样不符合“只计算中间间隔 bar 数”的要求。

### 4. 最小/最大跨度区间统一作用于 `pointSpans[0..3]`

新的 `InpAdjustPointMinSpanKNumber` 与 `InpAdjustPointMaxSpanKNumber` 都作用于：

- `P0->P1`
- `P1->P2`
- `P2->P3`
- `P3->P4`

并统一按“中间 bar 数”口径判断。

原因：

- 当前最大跨度限制已经覆盖四段，新需求也明确要求每根线段都要受最小/最大区间共同约束。
- 如果只在 `P0-P3` 历史骨架上加最小跨度，而不约束 `P3->P4`，会让第四段语义和前三段不一致。

备选方案：

- 只约束 `P0-P3`，不约束 `P3->P4`  
  否决原因：不符合“每根线段”都受限的确认结论。

### 5. cached 搜索、legacy exact 搜索和 `condF` 必须同时切到新口径

实现上需要保证三层逻辑同步切换：

- 候选范围裁剪
- 候选点位两两组合时的跨度剪枝
- 最终 `condF` 过滤

原因：

- 现在项目同时保留 cached 搜索和 legacy exact 搜索做一致性对照。
- 如果只修改其中一条路径，`InpEnableExactSearchCompare` 打开后会持续出现 mismatch。

备选方案：

- 只改 cached 主路径，legacy exact 留待后续  
  否决原因：会破坏现有 exact compare 诊断能力，也会让同一策略在两条搜索路径下出现不同结果。

### 6. 继续保留 `InpP1P2AValueTimeMinKNumberLimit` 的独立时间门槛语义

虽然新的最小跨度也会作用于 `P1->P2`，但 `InpP1P2AValueTimeMinKNumberLimit` 仍保留，继续表达“`P1->P2` 这一段总持续 bar 数的额外门槛”。

原因：

- 该参数表达的是一个单独的业务约束，不应因为通用的最小跨度区间引入而被隐式删除。
- 两者可以并存：一个约束中间间隔，一个约束该段整体持续长度。

备选方案：

- 删除 `InpP1P2AValueTimeMinKNumberLimit`  
  否决原因：会改变另一条既有结构过滤规则，超出本次范围。

## Risks / Trade-offs

- [没有合格 `P5/P6` 的持仓将长期没有止盈位] → Mitigation: 在 proposal/spec 中明确这是一项业务语义变更，并在回测时重点观察持仓寿命和 hard stop 占比。
- [移除初始止盈后，止盈观察窗口触发频率会下降] → Mitigation: 在文档中明确说明止盈观察窗口只会在首次 `P5/P6` 激活后、真正触发 `profit_target` 的单子上出现。
- [跨度口径切换会显著改变候选集合和回测结果] → Mitigation: 将新旧跨度口径写成明确公式，并在验证中同时覆盖 cached 与 exact 搜索结果。
- [最小跨度默认值提升到 5、最大跨度提升到 30 后，结构节奏会变慢] → Mitigation: 在 README 和 specs 中强调这是默认值改变，而不是算法 bug；保留参数可调。
- [持仓管理、实时触发和日志里都依赖 `profitPrice`] → Mitigation: 设计上先统一引入“止盈未激活”语义，再分别改 stale filter、持仓退出和日志输出。

## Migration Plan

1. 更新 proposal 对应的 delta specs，明确移除初始止盈、唯一 `P5` 锚定止盈以及新跨度口径。
2. 在运行时输入中移除 `InpProfitC`，新增 `InpAdjustPointMinSpanKNumber`，并调整 `InpAdjustPointMaxSpanKNumber` 默认值。
3. 重构 `PatternSnapshot` / 持仓管理中的止盈状态表达，使其支持“未激活止盈”。
4. 将历史骨架的跨度计算、cached 搜索、legacy exact 搜索和 `condF` 统一切换到“中间 bar 数”口径，并应用最小/最大跨度区间。
5. 更新日志、README、compile/backtest 配置示例，并通过编译与 targeted validation 验证新行为。

Rollback:

- 恢复 `InpProfitC` 以及开仓时的初始止盈推导。
- 恢复 `SpanKNumber` 的旧口径和旧默认最大跨度。
- 删除 `InpAdjustPointMinSpanKNumber` 并恢复相关 spec 文档。

## Open Questions

- 暂无。当前范围、默认值和跨度口径都已经在探索阶段明确确认。
