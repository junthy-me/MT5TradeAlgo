# MT5TradeAlgo

本仓库当前的主策略是 `mt5/P4PatternStrategy.mq5`。它会在 MT5 中按定时器轮询多个品种，基于 P4 形态寻找做多机会，并自动管理止盈、强止损、条件触发的弱止损，以及止盈/止损后的观察窗口。

这份说明以当前代码实现为准，结合 `prd/Mt5交易策略_P4Entry.md` 的模式图和已归档的 OpenSpec 变更整理而成，适合第一次接触这份策略代码的人快速理解“它现在到底怎么工作”。

## 模式图

下图来自 PRD，用来说明 P0 到 P6 的点位关系：

![P4 模式点位图](pic/p4_pattern_diagram.png)

在当前实现里，各点位的取值来源固定如下：

- `P0`、`P2`、`P5`：对应 K 线的最低价
- `P1`、`P3`、`P6`：对应 K 线的最高价
- `P4`：实时 `ask` 价格

也就是说，代码已经不再使用最早 PRD 里的 `PointValueTypeEnum` 全局取值模式，而是按点位角色固定取价。

## 变量定义

代码中沿用 PRD 的核心结构变量：

- `b1 = P2 - P0`
- `a = P1 - P2`
- `b2 = P3 - P1`
- `c = P3 - P4`
- `d = P4 - P5`
- `e = P6 - P5`
- `r1 = c / (a + b1 + b2)`
- `r2 = a / (a + b1)`

时间变量定义如下：

- `t1 = T(P0,P1)`
- `t2 = T(P1,P2)`
- `t3 = T(P2,P3)`
- `t4 = T(P3,P4)`
- `t5 = T(P4,P5)`
- `t6 = T(P5,P6)`
- `triggerPatternTotalTimeMinute = t1 + t2 + t3 + t4`

其中：

- `a`、`b1`、`b2` 用于判断历史骨架是否合格
- `c`、`r1`、`t4` 用于判断实时 `P4` 触发是否成立
- `d`、`e` 只在开仓后用于弱止损激活
- `r2`、`sspanmin` 目前主要用于日志和结构记录，不直接参与最终入场门控

## 策略实现思路

### 1. 先在已收盘 K 线中寻找历史骨架 `P0-P3`

策略每次轮询某个品种时，会先读取最近 `InpLookbackBars` 根已收盘 K 线，然后在最近窗口内枚举候选的 `P0/P1/P2/P3` 组合。

相邻点之间允许跨越多根 K 线，但每一段都必须满足最小/最大跨度约束。这里的 `SpanKNumber` 只计算两点之间“中间间隔”的 K 线数量，不包含起点和终点所在的两根 K 线：

- `P0 -> P1`：`InpAdjustPointMinSpanKNumber <= span <= InpAdjustPointMaxSpanKNumber`
- `P1 -> P2`：`InpAdjustPointMinSpanKNumber <= span <= InpAdjustPointMaxSpanKNumber`
- `P2 -> P3`：`InpAdjustPointMinSpanKNumber <= span <= InpAdjustPointMaxSpanKNumber`
- `P3 -> 当前触发段`：`InpAdjustPointMinSpanKNumber <= span <= InpAdjustPointMaxSpanKNumber`

同时，历史骨架必须满足基础拓扑关系：

- `P1 > P0`
- `P2 > P0`
- `P2 < P1`
- `P3 > P1`

除了这些点位关系，历史骨架现在还必须满足“端点就是该段极值”的线段约束，且默认允许并列极值：

- `P0 -> P1`：`P0` 必须达到整段最低点，`P1` 必须达到整段最高点
- `P1 -> P2`：`P1` 必须达到整段最高点，`P2` 必须达到整段最低点
- `P2 -> P3`：`P2` 必须达到整段最低点，`P3` 必须达到整段最高点

### 2. 再对历史骨架做结构过滤

历史骨架不是只要长得像就可以，当前代码会继续检查这些条件：

- `CondA`：`b1 / b2` 必须落在 `[InpCondAXMin, InpCondAXMax]`
- `a` 的最小空间限制：`a >= InpP1P2AValueSpaceMinPriceLimit`
- `P1 -> P2` 的最小持续 K 线数：`pointSpans[1] + 2 >= InpP1P2AValueTimeMinKNumberLimit`
- `b1 + b2` 的区间限制：
  - 下限：`b1 + b2 >= InpBSumValueMinRatioOfAValue * a`
  - 上限：`b1 + b2 <= InpBSumValueMaxRatioOfAValue * a`
- `Pre0` 前置下跌先决条件：
  - 在 `P0` 之前最近 `InpPreCondPriorDeclineLookbackBars` 根 K 线内，必须存在一个 `Pre0`
  - `Pre0 -> P0` 的跌幅要大于 `InpPreCondPriorDeclineMinDropRatioOfStructure * (a + b1 + b2)`
  - `Pre0` 与 `P0` 之间的中间 K 线数量必须 `>= InpPreCondPriorDeclineMinBarsBetweenPre0AndP0`
  - `Pre0` 必须达到 `Pre0 -> P0` 整段最高点，`P0` 必须达到整段最低点；如果段内有并列 high/low，端点只要达到该极值就算通过

只有通过这些检查的 `P0-P3`，才会进入缓存，等待实时 `P4` 触发。

### 3. 用实时价格判断 `P4` 是否触发

历史骨架准备好后，策略不会等当前 K 线收盘，而是直接用实时 `ask` 作为 `P4`：

- `P4 = 当前 ask`
- `c = P3 - P4`

实时触发时还要满足：

- `P4 < P3`
- `CondB`：`c / (a + b1 + b2) >= InpP3P4DropMinRatioOfStructure`
- `CondC`：`t4 < InpCondCZ * (t1 + t2 + t3)`

如果同一时刻有多个候选骨架都能触发，代码优先选择：

- `P3` 时间更晚的候选
- 如果 `P3` 时间相同，则优先 `P4` 更低的候选

### 4. 入场前还要经过运行时门控

即使模式成立，也不一定马上下单。当前代码还会拦截以下情况：

- 同一品种刚刚在当前 `P4` 所在 bar 成功开过仓
- 该品种刚刚止盈，仍处于 `InpProfitObservationBars` 定义的观察窗口内
- 该品种刚刚强止损或弱止损，仍处于 `InpStopObservationBars` 定义的观察窗口内
- 当前候选与“已经成功开过仓的历史骨架”共享同角色的 `P0/P1/P2/P3` 任一点
- 当前由本 EA 管理的该品种持仓数已经达到 `InpMaxPositionsPerSymbol`
- 当前 `ask` 已经低于强止损价
- 如果该模式已经拥有激活后的止盈位，则当前 `ask` 已经高于止盈价，说明信号已过时

只要止盈观察窗口或止损观察窗口任意一个仍未结束，就不会开新单。通过全部门控后，策略才会发出市价买单。

## 开仓、止盈和止损

### 开仓

- 下单方式：`trade.Buy(...)` 市价买入
- 参考入场价：`referenceEntryPrice = P4`
- 实际成交价：由 MT5 按实时市场价成交

因此，`P4` 是策略计算用的参考触发价，不保证与实际成交价完全相同。

### 强止损

当前代码中的强止损不是 PRD 最初写的 `买入价 - hardlossC * a`，而是直接放在：

- `hardLossPrice = P0`

持仓后只要实时 `bid <= hardLossPrice`，策略就会平仓。

### 止盈激活

当前实现里，开仓后不会立刻设置止盈位：

- 开仓时只有 `hardLossPrice = P0`
- `profitPrice` 在首次合格 `P5/P6` 出现前处于未激活状态

也就是说，如果一笔单子始终没有走出合格 `P5/P6`，它将只受强止损管理，不会有 `profit_target`。

### 弱止损

弱止损不是开仓就有，而是开仓后继续从 `P4` 之后的已收盘 K 线中寻找合格的 `P5/P6` 组合：

- `P5`：后续最低点
- `P6`：`P5` 之后的后续最高点

找到后计算：

- `d = P4 - P5`
- `e = P6 - P5`

只有满足下面条件，弱止损和止盈才会首次激活：

- `e >= InpP5P6ReboundMinRatioOfP3P5Drop * (c + d)`

如果当前时刻存在多个满足条件的 `P5` 候选，代码会选择其中价格最低的那个 `P5` 作为 `selectedP5`，并一次性设置：

- `softLossPrice = InpSoftLossC * selectedP5`
- `profitPrice = selectedP5 + InpP5AnchoredProfitC * (a + b1 + b2)`

默认 `InpP5AnchoredProfitC = 0.7`。

一旦首次激活完成，这两个价位会被冻结，后续即使再出现新的 `P5/P6` 组合，也不会继续改写。

如果实时 `bid <= softLossPrice`，则按 `soft_stop` 平仓；如果实时 `bid >=` 当前已激活的 `profitPrice`，则按 `profit_target` 平仓。

### 观察窗口

当前实现有两套互相独立的观察窗口，且都只影响新开仓，不影响已有持仓继续止盈止损：

- 止盈观察窗口：持仓因 `profit_target` 平仓后启动，长度由 `InpProfitObservationBars` 控制
- 止损观察窗口：持仓因 `hard_stop` 或 `soft_stop` 平仓后启动，长度由 `InpStopObservationBars` 控制

如果同一品种同时存在止盈观察窗口和止损观察窗口，则只要任意一个窗口尚未结束，就不能再开新单。

## 参数说明

### 运行与交易参数

| 参数 | 默认值 | 含义 | 如何参与计算 |
| --- | --- | --- | --- |
| `InpSymbols` | `"XAUUSD"` | 要扫描的品种列表，分号分隔 | `OnTimer()` 逐个轮询 |
| `InpTF` | `PERIOD_M15` | 形态识别周期 | 所有 K 线和时间跨度都基于该周期 |
| `InpTimerMillSec` | `100` | 定时器轮询间隔，毫秒 | 控制扫描频率 |
| `InpMagic` | `9527001` | EA 魔术号 | 用来识别本 EA 的持仓 |
| `InpComment` | `"P4PatternStrategy"` | 订单备注前缀 | 用于识别和日志追踪 |
| `InpFixedLots` | `0.05` | 固定下单手数 | 直接用于 `trade.Buy()` |
| `InpMaxPositionsPerSymbol` | `1` | 单品种最大并行持仓数 | 超限时阻止开仓 |
| `InpSlippagePoints` | `20` | 允许的价格偏差点数 | 用于交易请求的成交偏差控制 |
| `InpProfitObservationBars` | `30` | 止盈后观察窗口 bar 数 | 观察期内阻止新开仓 |
| `InpStopObservationBars` | `30` | 止损后观察窗口 bar 数 | `hard_stop` 或 `soft_stop` 后观察期内阻止新开仓 |
| `InpLookbackBars` | `300` | 回看已收盘 K 线数量 | 限制历史骨架搜索范围 |
| `InpAdjustPointMinSpanKNumber` | `5` | 相邻点之间最少中间 K 线数 | 限制 `P0-P4` 各段跨度下限 |
| `InpAdjustPointMaxSpanKNumber` | `35` | 相邻点之间最多中间 K 线数 | 限制 `P0-P4` 各段跨度上限 |

### 历史骨架过滤参数

| 参数 | 默认值 | 含义 | 如何参与计算 |
| --- | --- | --- | --- |
| `InpCondAXMin` | `0.5` | `CondA` 下限 | 要求 `b1 / b2 >= InpCondAXMin` |
| `InpCondAXMax` | `2.0` | `CondA` 上限 | 要求 `b1 / b2 <= InpCondAXMax` |
| `InpP1P2AValueSpaceMinPriceLimit` | `0.0` | `a` 的最小价格幅度 | 要求 `a >= 该值` |
| `InpP1P2AValueTimeMinKNumberLimit` | `1` | `P1->P2` 最小总 K 线数 | 要求 `pointSpans[1] + 2 >= 该值` |
| `InpBSumValueMinRatioOfAValue` | `1.5` | `b1+b2` 相对 `a` 的最小倍数 | 要求 `b1+b2 >= 该值 * a` |
| `InpBSumValueMaxRatioOfAValue` | `5.0` | `b1+b2` 相对 `a` 的最大倍数 | 要求 `b1+b2 <= 该值 * a` |
| `InpPreCondPriorDeclineLookbackBars` | `30` | `Pre0` 前置下跌回看窗口 | 在 `P0` 之前多少根 K 线内寻找 `Pre0` |
| `InpPreCondPriorDeclineMinDropRatioOfStructure` | `0.7` | `Pre0->P0` 最小跌幅系数 | 要求跌幅 `> 该值 * (a+b1+b2)` |
| `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0` | `0` | `Pre0` 与 `P0` 最少间隔 bar 数 | 约束前置下跌与骨架之间的距离 |

### 实时触发与出场参数

| 参数 | 默认值 | 含义 | 如何参与计算 |
| --- | --- | --- | --- |
| `InpP3P4DropMinRatioOfStructure` | `0.4` | `CondB` 阈值 | 要求 `c / (a+b1+b2) >= 该值` |
| `InpCondCZ` | `1.0` | `CondC` 系数 | 要求 `t4 < 该值 * (t1+t2+t3)` |
| `InpP5P6ReboundMinRatioOfP3P5Drop` | `0.65` | 弱止损激活阈值 | 要求 `e >= 该值 * (c+d)` |
| `InpSoftLossC` | `1.0` | 弱止损价系数 | `softLossPrice = 该值 * selectedP5` |
| `InpP5AnchoredProfitC` | `0.7` | 唯一止盈系数 | 首次 `P5/P6` 激活后，`profitPrice = selectedP5 + 该值 * (a+b1+b2)` |
| `InpEnableExactSearchCompare` | `false` | 调试开关 | 打开后会对比缓存搜索和精确搜索结果，仅用于诊断 |

## 当前实现与最初 PRD 的主要差异

为了避免误读，下面这几条最值得先记住：

- 当前实现保留了 PRD 的点位图和主结构，但具体过滤规则已经按归档 spec 演化
- `PointValueTypeEnum` 已移除，点位取价固定为“谷点取 low，峰点取 high，P4 取实时 ask”
- `CondB` 已不是 PRD 最初的 `r1 = y * r2` 匹配，而是直接要求 `c/(a+b1+b2)` 达到最小阈值
- 独立的旧 `CondD` 不再参与过滤；代码里 `condD` 仅保留为结构字段，当前恒为 `true`
- 旧的 `tspanmin` 门槛不再作为入场条件，当前改为 `a` 的最小空间、`P1-P2` 最小时长、`b1+b2` 区间和 `Pre0` 前置下跌先决条件
- 强止损改为 `P0`
- 开仓时不再设置初始止盈；只有首次合格 `P5/P6` 出现后才会激活唯一止盈位
- 首次 `P5/P6` 激活后，止盈基于最低合格 `P5`
- 弱止损激活条件改为 `e >= 阈值 * (c+d)`
- 止盈后和止损后都有独立观察窗口，且任一窗口有效时都禁止新开仓

如果你要调参，建议先按“当前代码公式”理解，不要直接沿用最初 PRD 里的旧公式。

## 日志怎么看

策略默认只突出成功买点日志，重点字段包括：

- 成功买点日志 `ENTRY_P4`：默认只保留这一条核心摘要，输出 `symbol`、`ticket`、`p4_bar`、成交价、`hard_loss`、图形标注状态，以及本次买入实际使用的 `P0-P4` 时间和价格
- `annotation=drawn`：表示策略已在一个已打开且匹配 `symbol + InpTF` 的图表上画出该次买点的模式对象；如果后续首次出现合格 `P5/P6`，同一组对象会继续补画
- `annotation=no_matching_chart`：表示本次买入成功，但当前没有打开匹配的图表，所以没有绘图
- `annotation=draw_failed`：表示交易成功，但图形对象创建失败；不会影响持仓管理

默认不再打印常规阻止日志、弱止损首次激活日志和例行 `EXIT` 摘要，因此 Experts 输出会明显更短，更适合直接盯买点。

## 图上怎么看模式

如果你想直接在图中看到某次买入对应的是哪组模式，需要先满足两个条件：

1. 打开该买入品种对应的图表
2. 图表周期与 `InpTF` 一致

满足后，策略会在成功买入时于该图上绘制：

- `Pre0/P0/P1/P2/P3/P4` 点位标记和相邻连线
- `P4` 买点高亮箭头
- 强止损水平线
- `Pre0-P0` 下跌值、`b1`、`a`、`b2`、`c` 数值标注

如果后续该持仓首次形成合格 `P5/P6`，策略会在同一组对象里继续补充：

- `P5/P6` 点位标记和 `P4-P5-P6` 连线
- 弱止损水平线

点位颜色固定且跨交易保持一致，便于快速辨认：

- `Pre0`、`P0`、`P1`、`P2`、`P3`、`P4`、`P5`、`P6` 都有各自固定颜色

对象名会带上 `symbol`、`timeframe`、`ticket` 和 `p4_bar_time`，所以同一图表上多次买入不会互相覆盖，也可以从对象名反查到对应买点。

## 首次运行

第一次在 MT5 中使用这份策略时，建议按这个顺序操作：

1. 在 MetaEditor 中编译 `mt5/P4PatternStrategy.mq5`。
2. 把 EA 挂到任意一个图表上即可，实际扫描对象由 `InpSymbols` 决定，不依赖挂载图表本身的品种。
3. 设置 `InpSymbols`、`InpTF`、`InpFixedLots` 等运行参数，确认目标品种已在 Market Watch 中可用。
4. 如果想看图上模式，提前打开你关心品种且周期等于 `InpTF` 的图表。
5. 打开 Experts / Journal，先确认初始化日志，再观察 `ENTRY_P4` 是否清楚列出 `P0-P4` 点位，并检查图表上是否出现对应的 `Pre0-P4`、高度值和强止损标注；若后续触发合格 `P5/P6`，再确认图上是否补出 `P5/P6` 和弱止损位。
6. 实盘前先用 Strategy Tester 回测，重点检查止盈/止损观察窗口、共享骨架锁、首次 `P5/P6` 激活后最低 `P5` 的选择，以及二次止盈改写是否符合预期。

## 使用建议

第一次运行建议按下面的顺序理解和验证：

1. 先对照上面的模式图，看懂 `P0-P6` 在当前代码中的取价方式。
2. 再重点理解四组门槛：`CondA`、`a/P1P2/bSum` 结构门槛、`Pre0` 前置下跌、`P4` 实时触发。
3. 最后再调交易参数，特别是 `InpProfitObservationBars`、`InpStopObservationBars`、`InpP5P6ReboundMinRatioOfP3P5Drop`、`InpP5AnchoredProfitC` 和 `InpMaxPositionsPerSymbol`。

如果需要回测，可直接使用 `mt5/P4PatternStrategy.mq5`，并通过 MT5 Strategy Tester 观察 `ENTRY_P4` 日志是否准确对应到图上的 `Pre0-P4` 标注，以及后续 `P5/P6` 与止损线是否按持仓演化补画。
