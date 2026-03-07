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

相邻点之间允许跨越多根 K 线，但每一段都必须满足：

- `P0 -> P1` 跨度 `<= InpAdjustPointMaxSpanKNumber`
- `P1 -> P2` 跨度 `<= InpAdjustPointMaxSpanKNumber`
- `P2 -> P3` 跨度 `<= InpAdjustPointMaxSpanKNumber`
- `P3 -> 当前触发段` 预留跨度 `<= InpAdjustPointMaxSpanKNumber`

同时，历史骨架必须满足基础拓扑关系：

- `P1 > P0`
- `P2 > P0`
- `P2 < P1`
- `P3 > P1`

### 2. 再对历史骨架做结构过滤

历史骨架不是只要长得像就可以，当前代码会继续检查这些条件：

- `CondA`：`b1 / b2` 必须落在 `[InpCondAXMin, InpCondAXMax]`
- `a` 的最小空间限制：`a >= InpP1P2AValueSpaceMinPriceLimit`
- `P1 -> P2` 的最小持续 K 线数：`pointSpans[1] + 1 >= InpP1P2AValueTimeMinKNumberLimit`
- `b1 + b2` 的区间限制：
  - 下限：`b1 + b2 >= InpBSumValueMinRatioOfAValue * a`
  - 上限：`b1 + b2 <= InpBSumValueMaxRatioOfAValue * a`
- `Pre0` 前置下跌先决条件：
  - 在 `P0` 之前最近 `InpPreCondPriorDeclineLookbackBars` 根 K 线内，必须存在一个 `Pre0`
  - `Pre0 -> P0` 的跌幅要大于 `InpPreCondPriorDeclineMinDropRatioOfStructure * (a + b1 + b2)`
  - `Pre0` 与 `P0` 之间的中间 K 线数量必须 `>= InpPreCondPriorDeclineMinBarsBetweenPre0AndP0`

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
- 当前 `ask` 已经低于强止损价，或者已经高于止盈价，说明信号已过时

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

### 初始止盈

开仓后的初始止盈价格为：

- `profitPrice = P4 + InpProfitC * (a + b1 + b2)`

默认 `InpProfitC = 0.6`。

这和最初 PRD 中的 `买入价 + profitC * a` 不同，当前实现使用的是整个前序结构 `a + b1 + b2`。

### 弱止损

弱止损不是开仓就有，而是开仓后继续从 `P4` 之后的已收盘 K 线中寻找合格的 `P5/P6` 组合：

- `P5`：后续最低点
- `P6`：`P5` 之后的后续最高点

找到后计算：

- `d = P4 - P5`
- `e = P6 - P5`

只有满足下面条件，弱止损和二次止盈改写才会首次激活：

- `e >= InpP5P6ReboundMinRatioOfP3P5Drop * (c + d)`

如果当前时刻存在多个满足条件的 `P5` 候选，代码会选择其中价格最低的那个 `P5` 作为 `selectedP5`，并一次性设置：

- `softLossPrice = InpSoftLossC * selectedP5`
- `profitPrice = selectedP5 + InpP5AnchoredProfitC * (a + b1 + b2)`

默认 `InpP5AnchoredProfitC = 0.7`。

一旦首次激活完成，这两个价位会被冻结，后续即使再出现新的 `P5/P6` 组合，也不会继续改写。

如果实时 `bid <= softLossPrice`，则按 `soft_stop` 平仓；如果实时 `bid >=` 当前生效的 `profitPrice`，则按 `profit_target` 平仓。

### 观察窗口

当前实现有两套互相独立的观察窗口，且都只影响新开仓，不影响已有持仓继续止盈止损：

- 止盈观察窗口：持仓因 `profit_target` 平仓后启动，长度由 `InpProfitObservationBars` 控制
- 止损观察窗口：持仓因 `hard_stop` 或 `soft_stop` 平仓后启动，长度由 `InpStopObservationBars` 控制

如果同一品种同时存在止盈观察窗口和止损观察窗口，则只要任意一个窗口尚未结束，就不能再开新单。

## 参数说明

### 运行与交易参数

| 参数 | 默认值 | 含义 | 如何参与计算 |
| --- | --- | --- | --- |
| `InpSymbols` | `"AAPL;MSFT;NVDA"` | 要扫描的品种列表，分号分隔 | `OnTimer()` 逐个轮询 |
| `InpTF` | `PERIOD_M5` | 形态识别周期 | 所有 K 线和时间跨度都基于该周期 |
| `InpTimerMillSec` | `100` | 定时器轮询间隔，毫秒 | 控制扫描频率 |
| `InpMagic` | `9527001` | EA 魔术号 | 用来识别本 EA 的持仓 |
| `InpComment` | `"P4PatternStrategy"` | 订单备注前缀 | 用于识别和日志追踪 |
| `InpFixedLots` | `0.05` | 固定下单手数 | 直接用于 `trade.Buy()` |
| `InpMaxPositionsPerSymbol` | `1` | 单品种最大并行持仓数 | 超限时阻止开仓 |
| `InpSlippagePoints` | `20` | 允许的价格偏差点数 | 用于交易请求的成交偏差控制 |
| `InpProfitObservationBars` | `30` | 止盈后观察窗口 bar 数 | 观察期内阻止新开仓 |
| `InpStopObservationBars` | `30` | 止损后观察窗口 bar 数 | `hard_stop` 或 `soft_stop` 后观察期内阻止新开仓 |
| `InpLookbackBars` | `300` | 回看已收盘 K 线数量 | 限制历史骨架搜索范围 |
| `InpAdjustPointMaxSpanKNumber` | `10` | 相邻点允许的最大 K 线跨度 | 限制 `P0-P3` 各段跨度 |

### 历史骨架过滤参数

| 参数 | 默认值 | 含义 | 如何参与计算 |
| --- | --- | --- | --- |
| `InpCondAXMin` | `0.75` | `CondA` 下限 | 要求 `b1 / b2 >= InpCondAXMin` |
| `InpCondAXMax` | `1.25` | `CondA` 上限 | 要求 `b1 / b2 <= InpCondAXMax` |
| `InpP1P2AValueSpaceMinPriceLimit` | `5.0` | `a` 的最小价格幅度 | 要求 `a >= 该值` |
| `InpP1P2AValueTimeMinKNumberLimit` | `3` | `P1->P2` 最小 K 线数 | 要求 `pointSpans[1] + 1 >= 该值` |
| `InpBSumValueMinRatioOfAValue` | `2.0` | `b1+b2` 相对 `a` 的最小倍数 | 要求 `b1+b2 >= 该值 * a` |
| `InpBSumValueMaxRatioOfAValue` | `5.0` | `b1+b2` 相对 `a` 的最大倍数 | 要求 `b1+b2 <= 该值 * a` |
| `InpPreCondPriorDeclineLookbackBars` | `20` | `Pre0` 前置下跌回看窗口 | 在 `P0` 之前多少根 K 线内寻找 `Pre0` |
| `InpPreCondPriorDeclineMinDropRatioOfStructure` | `0.7` | `Pre0->P0` 最小跌幅系数 | 要求跌幅 `> 该值 * (a+b1+b2)` |
| `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0` | `0` | `Pre0` 与 `P0` 最少间隔 bar 数 | 约束前置下跌与骨架之间的距离 |

### 实时触发与出场参数

| 参数 | 默认值 | 含义 | 如何参与计算 |
| --- | --- | --- | --- |
| `InpP3P4DropMinRatioOfStructure` | `0.4` | `CondB` 阈值 | 要求 `c / (a+b1+b2) >= 该值` |
| `InpCondCZ` | `1.0` | `CondC` 系数 | 要求 `t4 < 该值 * (t1+t2+t3)` |
| `InpP5P6ReboundMinRatioOfP3P5Drop` | `0.65` | 弱止损激活阈值 | 要求 `e >= 该值 * (c+d)` |
| `InpSoftLossC` | `1.0` | 弱止损价系数 | `softLossPrice = 该值 * selectedP5` |
| `InpProfitC` | `0.6` | 止盈系数 | `profitPrice = P4 + 该值 * (a+b1+b2)` |
| `InpP5AnchoredProfitC` | `0.7` | `P5` 锚定止盈系数 | 首次 `P5/P6` 激活后，`profitPrice = selectedP5 + 该值 * (a+b1+b2)` |
| `InpEnableExactSearchCompare` | `false` | 调试开关 | 打开后会对比缓存搜索和精确搜索结果，仅用于诊断 |

## 当前实现与最初 PRD 的主要差异

为了避免误读，下面这几条最值得先记住：

- 当前实现保留了 PRD 的点位图和主结构，但具体过滤规则已经按归档 spec 演化
- `PointValueTypeEnum` 已移除，点位取价固定为“谷点取 low，峰点取 high，P4 取实时 ask”
- `CondB` 已不是 PRD 最初的 `r1 = y * r2` 匹配，而是直接要求 `c/(a+b1+b2)` 达到最小阈值
- 独立的旧 `CondD` 不再参与过滤；代码里 `condD` 仅保留为结构字段，当前恒为 `true`
- 旧的 `tspanmin` 门槛不再作为入场条件，当前改为 `a` 的最小空间、`P1-P2` 最小时长、`b1+b2` 区间和 `Pre0` 前置下跌先决条件
- 强止损改为 `P0`
- 初始止盈改为基于 `a+b1+b2`
- 首次 `P5/P6` 激活后，止盈会改写为基于最低合格 `P5` 的二次止盈
- 弱止损激活条件改为 `e >= 阈值 * (c+d)`
- 止盈后和止损后都有独立观察窗口，且任一窗口有效时都禁止新开仓

如果你要调参，建议先按“当前代码公式”理解，不要直接沿用最初 PRD 里的旧公式。

## 日志怎么看

策略在开仓和平仓时会打印完整日志，重点字段包括：

- 开仓日志 `ENTRY`：会输出 `P0-P4` 时间和价格、`a/b1/b2/c`、`t1-t4`、`Pre0` 信息、止盈止损价和结构过滤阈值
- 平仓日志 `EXIT`：会输出 `P4/P5/P6` 时间和价格、`d/e`、`t5/t6` 以及平仓原因
- 阻止日志：会明确区分是被 `P4` 同 bar 锁、止盈观察窗口、止损观察窗口、双观察窗口重叠、共享骨架成功锁，还是持仓上限拦截

这些日志基本已经覆盖了“为什么开仓”“为什么不开仓”“为什么平仓”三类问题。

## 首次运行

第一次在 MT5 中使用这份策略时，建议按这个顺序操作：

1. 在 MetaEditor 中编译 `mt5/P4PatternStrategy.mq5`。
2. 把 EA 挂到任意一个图表上即可，实际扫描对象由 `InpSymbols` 决定，不依赖挂载图表本身的品种。
3. 设置 `InpSymbols`、`InpTF`、`InpFixedLots` 等运行参数，确认目标品种已在 Market Watch 中可用。
4. 打开 Experts / Journal，先确认初始化日志，再观察 `ENTRY`、`EXIT` 和各种阻止日志是否符合预期。
5. 实盘前先用 Strategy Tester 回测，重点检查止盈/止损观察窗口、共享骨架锁、首次 `P5/P6` 激活后最低 `P5` 的选择，以及二次止盈改写是否符合预期。

## 使用建议

第一次运行建议按下面的顺序理解和验证：

1. 先对照上面的模式图，看懂 `P0-P6` 在当前代码中的取价方式。
2. 再重点理解四组门槛：`CondA`、`a/P1P2/bSum` 结构门槛、`Pre0` 前置下跌、`P4` 实时触发。
3. 最后再调交易参数，特别是 `InpProfitObservationBars`、`InpStopObservationBars`、`InpP5P6ReboundMinRatioOfP3P5Drop`、`InpP5AnchoredProfitC` 和 `InpMaxPositionsPerSymbol`。

如果需要回测，可直接使用 `mt5/P4PatternStrategy.mq5`，并通过 MT5 Strategy Tester 观察 `ENTRY` / `EXIT` 日志是否符合预期。
