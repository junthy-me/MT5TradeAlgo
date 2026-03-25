# XAUUSDm 回测记录

## 说明

- 截至 `2026-03-18 17:02`，本机 Exness `XAUUSDm` tester 日志已显示 `history data begins from 2018.12.19 00:00`，因此 `2020` 年之后的数据当前已经可用。
- 当前这 9 组窗口是在更早一轮历史尚未完全回补时选定的，所以仍然集中在 `2023-2026` 区间；每个窗口都满足“单窗口跨度超过 4 个月且不超过 1 年”。
- 上涨 / 震荡 / 下跌标签依据公共 `XAU/USD` 日线首尾变化筛选；正式回测执行使用的是本机 MT5 的 `XAUUSDm` M30 历史数据。
- `最大回撤` 与 `最大回撤率` 采用当前策略代码中的新口径：`max(0, 初始本金 - 回测期间最低净值)`，净值使用 `ACCOUNT_EQUITY`，包含浮亏。

## 回测配置

| 项目 | 值 |
| --- | --- |
| 策略文件 | `mt5/P4PatternStrategy.mq5` / `P4PatternStrategy.ex5` |
| 品种 | `XAUUSDm` |
| 周期 | `M30` |
| 本金 | `1000 USD` |
| 杠杆 | `1:2000` |
| 回测模型 | `Model=0` |
| 执行模式 | `ExecutionMode=28` |
| 优化 | `Optimization=0` |
| 可视化 | `Visual=0` |
| 其余输入 | 全部采用当前代码默认值 |

## 默认参数

| 参数 | 默认值 |
| --- | --- |
| `InpSymbols` | `XAUUSDm` |
| `InpTF` | `PERIOD_M30` |
| `InpTimerMillSec` | `100` |
| `InpMagic` | `9527001` |
| `InpComment` | `P4PatternStrategy` |
| `InpFixedLots` | `0.05` |
| `InpMaxPositionsPerSymbol` | `1` |
| `InpSlippagePoints` | `20` |
| `InpProfitObservationBars` | `10` |
| `InpStopObservationBars` | `10` |
| `InpMaxProfitStopMoney` | `0.0` |
| `InpMaxLossStopMoney` | `0.0` |
| `InpLookbackBars` | `150` |
| `InpAdjustPointMinSpanKNumber` | `0` |
| `InpAdjustPointMaxSpanKNumber` | `20` |
| `InpCondAXMin` | `0.75` |
| `InpCondAXMax` | `1.25` |
| `InpP3P4MoveMinRatioOfStructure` | `0.75` |
| `InpCondCZ` | `1.0` |
| `InpP1P2AValueSpaceMinPriceLimit` | `5.0` |
| `InpP1P2AValueTimeMinKNumberLimit` | `5` |
| `InpBSumValueMinRatioOfAValue` | `2.0` |
| `InpBSumValueMaxRatioOfAValue` | `5.0` |
| `InpTradeDirectionMode` | `LONG_ONLY (0)` |
| `InpPreCondEnable` | `true` |
| `InpPreCondPriorMoveLookbackBars` | `30` |
| `InpPreCondPriorMoveMinRatioOfStructure` | `1.1` |
| `InpPreCondPriorMoveMinBarsBetweenPre0AndP0` | `0` |
| `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` | `true,true,false,false,false` |
| `InpP5P6ReboundMinRatioOfP3P5Drop` | `0.55` |
| `InpSoftLossC` | `1.0` |
| `InpP5AnchoredProfitC` | `2.0` |
| `InpEnableExactSearchCompare` | `false` |

## 回测窗口

| 类别 | 窗口 | 开始 | 结束 | 天数 | 选择依据 |
| --- | --- | --- | --- | ---: | --- |
| 上涨 | UP-1 | 2025.01.28 | 2026.01.28 | 365 | 公共XAU/USD日线净涨幅约+95.93% |
| 上涨 | UP-2 | 2025.02.27 | 2026.02.27 | 365 | 公共XAU/USD日线净涨幅约+82.96% |
| 上涨 | UP-3 | 2025.03.03 | 2026.03.03 | 365 | 公共XAU/USD日线净涨幅约+75.90% |
| 震荡 | SIDE-1 | 2023.03.15 | 2023.10.16 | 215 | 公共XAU/USD日线首尾涨跌约-0.01% |
| 震荡 | SIDE-2 | 2023.05.17 | 2023.11.17 | 184 | 公共XAU/USD日线首尾涨跌约-0.04% |
| 震荡 | SIDE-3 | 2023.05.22 | 2023.10.23 | 154 | 公共XAU/USD日线首尾涨跌约+0.05% |
| 下跌 | DOWN-1 | 2023.05.04 | 2023.10.04 | 153 | 公共XAU/USD日线净跌幅约-11.17% |
| 下跌 | DOWN-2 | 2023.04.05 | 2023.10.05 | 183 | 公共XAU/USD日线净跌幅约-9.93% |
| 下跌 | DOWN-3 | 2023.05.09 | 2023.10.09 | 153 | 公共XAU/USD日线净跌幅约-8.51% |

## 回测结果

| 类别 | 窗口 | 开始 | 结束 | 初始资金 | 结束资金 | 总收益率 | 模式匹配次数 | 已闭仓笔数 | 盈利笔数 | 亏损笔数 | 平局笔数 | 模式匹配胜率 | 闭仓胜率 | 净点数 | 盈亏比 | 最大回撤 | 最大回撤率 |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 上涨 | UP-1 | 2025.01.28 | 2026.01.28 | 1000.00 | 2853.60 | 185.36% | 73 | 73 | 13 | 60 | 0 | 17.81% | 17.81% | 384.98200 | 2.09 | 9.49 | 0.95% |
| 上涨 | UP-2 | 2025.02.27 | 2026.02.27 | 1000.00 | 4259.91 | 325.99% | 80 | 79 | 15 | 64 | 0 | 18.75% | 18.99% | 657.69300 | 2.76 | 65.76 | 6.58% |
| 上涨 | UP-3 | 2025.03.03 | 2026.03.03 | 1000.00 | 4185.80 | 318.58% | 81 | 81 | 15 | 66 | 0 | 18.52% | 18.52% | 652.04400 | 2.72 | 65.76 | 6.58% |
| 震荡 | SIDE-1 | 2023.03.15 | 2023.10.16 | 1000.00 | 1202.24 | 20.22% | 3 | 3 | 1 | 2 | 0 | 33.33% | 33.33% | 41.06800 | 7.70 | 8.71 | 0.87% |
| 震荡 | SIDE-2 | 2023.05.17 | 2023.11.17 | 1000.00 | 997.64 | -0.24% | 1 | 1 | 0 | 1 | 0 | 0.00% | 0.00% | -0.47200 | 0.00 | 2.36 | 0.24% |
| 震荡 | SIDE-3 | 2023.05.22 | 2023.10.23 | 1000.00 | 997.64 | -0.24% | 1 | 1 | 0 | 1 | 0 | 0.00% | 0.00% | -0.47200 | 0.00 | 2.36 | 0.24% |
| 下跌 | DOWN-1 | 2023.05.04 | 2023.10.04 | 1000.00 | 997.64 | -0.24% | 1 | 1 | 0 | 1 | 0 | 0.00% | 0.00% | -0.47200 | 0.00 | 2.36 | 0.24% |
| 下跌 | DOWN-2 | 2023.04.05 | 2023.10.05 | 1000.00 | 969.36 | -3.06% | 2 | 2 | 0 | 2 | 0 | 0.00% | 0.00% | -6.12700 | 0.00 | 30.64 | 3.06% |
| 下跌 | DOWN-3 | 2023.05.09 | 2023.10.09 | 1000.00 | 997.64 | -0.24% | 1 | 1 | 0 | 1 | 0 | 0.00% | 0.00% | -0.47200 | 0.00 | 2.36 | 0.24% |
