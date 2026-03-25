# 分行情调参测试记录（2026-03-24）

## 目标与口径

本轮按三类行情分别调参，并采用用户最后确认的容差口径：

- 上涨 `ONLY_LONG`：总收益率为正，最大回撤率不超过 `6.5%`
- 震荡 `ONLY_LONG`：总收益率为正，最大回撤率不超过 `6.5%`
- 下跌 `ONLY_LONG`：尽可能少成单，最大回撤率不超过 `6.5%`
- 下跌 `ONLY_SHORT`：尽可能多成单，总收益率为正，最大回撤率不超过 `6.5%`

## 理论支撑

本轮没有做盲调，所有参数改动都对应到策略代码里的明确过滤或出场逻辑。

### 1. `MaxSpan` 决定历史骨架的“时距新鲜度”

- 代码位置：`mt5/P4PatternStrategy.mq5` 中 `BuildHistoricalCandidateCache` 和 `MaxSpanWithinLimit`
- 影响：
  - `InpAdjustPointMaxSpanKNumber` 越大，`P0-P3` 候选结构允许跨越更长时间
  - 在震荡和低波动窗里，这有助于放出更多候选
  - 在上涨窗里，过大的 span 容易引入“旧结构”，导致趋势后段入场质量下降

### 2. `space_limit` / `time_min` 直接控制 `A` 段强度

- 代码位置：`BuildHistoricalBackbone`
- 关键条件：
  - `pattern.a >= InpP1P2AValueSpaceMinPriceLimit`
  - `p1p2BarCount >= InpP1P2AValueTimeMinKNumberLimit`
- 影响：
  - `space_limit` 越大，结构幅度要求越高，候选更少但更干净
  - `time_min` 越大，结构耗时要求越高，能过滤过短的噪声波段
  - 在低波动震荡窗里，`space_limit` 过高会直接导致不交易

### 3. `P3P4MoveMinRatioOfStructure` 控制实时触发强度

- 代码位置：`EvaluateRealtimePatternFromBackbone`
- 关键条件：
  - `pattern.condB = pattern.r1 >= InpP3P4MoveMinRatioOfStructure`
- 理论解释：
  - 这是“当前段是否真的走出了足够强的触发结构”
  - 在震荡窗里，这个参数比继续收 `b_sum/a` 或 `CondA` 更有效，因为它直接抑制弱触发、保留真正走出来的结构

### 4. `CondA` / `b_sum/a` 影响结构形态，但不是这轮的主解

- 代码位置：`BuildHistoricalBackbone`
- 关键条件：
  - `pattern.condA = InRange(pattern.b1 / pattern.b2, InpCondAXMin, InpCondAXMax)`
  - `bSumValue` 与 `InpBSumValueMinRatioOfAValue` / `InpBSumValueMaxRatioOfAValue`
- 本轮结论：
  - 在震荡和下跌 `SHORT` 中，这两组参数只能局部改善，无法解决核心冲突窗口

### 5. 出场参数不是这轮的主瓶颈

- 代码位置：`FindPreferredQualifiedP5ActivationCandidate`
- 关键参数：
  - `InpSoftLossC`
  - `InpP5AnchoredProfitC`
- 本轮结论：
  - 这两项能改善局部窗口的收益回撤比
  - 但在上涨 `UP-4`、震荡 `SIDE-2`、下跌 `SHORT` 的 `DOWN-3/4` 上，核心问题仍是入场结构质量，而不是出场距离

## 一、上涨行情 `ONLY_LONG`

### 搜索思路

- 保持此前验证过的温和出场：
  - `InpSoftLossC=1.0010`
  - `InpP5AnchoredProfitC=1.5`
- 重点只测试结构强度：
  - `MaxSpan`
  - `space_limit`
  - `P3P4MoveMinRatioOfStructure`
  - `b_sum/a` 上限

### 关键候选结果（最难窗口）

| 候选 | `UP-2` | `UP-4` | 结论 |
| --- | --- | --- | --- |
| `up_ms30_dyn_bsum4` | `+6.96% / DD 7.85% / 47单` | `+1.20% / DD 7.97% / 26单` | 两窗 DD 都超标 |
| `up_ms30_floor4` | `-4.95% / DD 18.35% / 18单` | `+1.45% / DD 6.15% / 12单` | `UP-2` 明显恶化 |
| `up_ms28_dyn` | `+18.06% / DD 7.06% / 44单` | `-8.45% / DD 15.50% / 24单` | `UP-4` 明显失效 |
| `up_ms28_dyn_r1_085` | `+23.56% / DD 6.05% / 42单` | `-10.39% / DD 15.25% / 23单` | `UP-2` 接近通过，`UP-4` 仍失效 |
| `up_ms30_dyn_r1_085` | `+20.85% / DD 6.77% / 47单` | `-11.40% / DD 15.03% / 24单` | 无法兼顾 |
| `up_ms29_dyn_r1_085` | `+22.29% / DD 6.77% / 45单` | `-10.17% / DD 15.03% / 23单` | 与上面几乎同结论 |

### 结论

- 上涨窗没有找到一组通用参数同时覆盖 `UP-2` 与 `UP-4`
- `UP-2` 更偏向：
  - 更短的 `MaxSpan`
  - 更高的 `P3P4` 触发强度
- `UP-4` 更偏向：
  - 更高的 `space_limit`
  - 但一旦提高 `space_limit`，`UP-2` 又会明显恶化
- 结论不是“差一个数字”，而是这两个窗口对结构偏好的方向相反

## 二、震荡行情 `ONLY_LONG`

### 搜索思路

- 不再继续收 `b_sum` 或 `CondA`
- 优先验证“提高实时触发强度”是否比“继续收紧历史骨架”更有效

### 难窗口筛选结果

| 候选 | `SIDE-2` | `SIDE-3` | 结论 |
| --- | --- | --- | --- |
| `side_ms30_s3_bsum4` | `+21.56% / DD 9.51% / 13单` | `+1.52% / DD 6.77% / 9单` | DD 仍偏大 |
| `side_ms30_s3_axnarrow` | `+37.12% / DD 7.01% / 10单` | `+2.77% / DD 6.77% / 8单` | 接近，但仍未压住 |
| `side_ms30_s3_r1_085` | `+7.73% / DD 5.68% / 11单` | `+3.38% / DD 3.98% / 7单` | 最优候选 |
| `side_ms28_s3_bsum4` | `+12.10% / DD 9.51% / 11单` | `+1.85% / DD 5.90% / 7单` | `SIDE-2` 仍超标 |

### 最优候选全量验证

参数：

- `InpLookbackBars=220`
- `InpAdjustPointMinSpanKNumber=0`
- `InpAdjustPointMaxSpanKNumber=30`
- `InpP1P2AValueSpaceMinPriceLimit=3`
- `InpP1P2AValueTimeMinKNumberLimit=3`
- `InpP3P4MoveMinRatioOfStructure=0.85`
- `InpSoftLossC=1.0010`
- `InpP5AnchoredProfitC=1.5`

结果：

| 窗口 | 结果 |
| --- | --- |
| `SIDE-1` | `+20.75% / DD 0.48% / 27单` |
| `SIDE-2` | `+7.73% / DD 5.68% / 11单` |
| `SIDE-3` | `+3.38% / DD 3.98% / 7单` |
| `SIDE-4` | `0.00% / DD 0.00% / 0单` |

### 进一步验证：降低 `space_limit` 能否救 `SIDE-4`

候选 `space=2, r1=0.85`：

| 候选 | `SIDE-1` | `SIDE-2` | `SIDE-3` | `SIDE-4` | 结论 |
| --- | --- | --- | --- | --- | --- |
| `side_ms30_s2_r1_085` | `+33.27% / DD 0.90%` | `+4.82% / DD 6.27%` | `-1.36% / DD 8.00%` | `-2.93% / DD 3.37%` | `SIDE-3/4` 失败 |
| `side_ms36_s3_r1_085` | `+15.57% / DD 0.48%` | `+4.40% / DD 6.79%` | `+0.77% / DD 5.35%` | `0.00% / DD 0.00%` | `SIDE-2` 失败 |

### 结论

- 震荡窗最好的通用参数是 `side_ms30_s3_r1_085`
- 但它在 `SIDE-4` 上选择不交易，因此不满足“所有震荡窗都为正收益”的严格要求
- 继续放松 `space_limit` 会重新把 `SIDE-2/3` 的坏结构放进来
- 结论：**当前参数空间内，没有找到同时满足 4 个震荡窗口要求的通用参数**

## 三、下跌行情 `ONLY_LONG`

### 搜索思路

- 目标不是赚钱，而是尽量不逆势乱做
- 因此方向是把入场门槛重新收严，而不是继续放松

### 最终可用参数

- `InpLookbackBars=150`
- `InpAdjustPointMinSpanKNumber=0`
- `InpAdjustPointMaxSpanKNumber=20`
- `InpP1P2AValueSpaceMinPriceLimit=6`
- `InpP1P2AValueTimeMinKNumberLimit=6`
- `InpSoftLossC=1.0010`
- `InpP5AnchoredProfitC=1.5`
- `InpTradeDirectionMode=LONG_ONLY`

### 原测试窗口结果

| 窗口 | 结果 |
| --- | --- |
| `DOWN-1` | `0单 / 0.00% / DD 0.00%` |
| `DOWN-2` | `1单 / +4.15% / DD 3.55%` |
| `DOWN-3` | `0单 / 0.00% / DD 0.00%` |
| `DOWN-4` | `0单 / 0.00% / DD 0.00%` |

### 外样本验证

额外验证窗口：

- `V1: 2022.03.01 - 2022.07.08`
- `V2: 2020.10.01 - 2021.02.18`
- `V3: 2023.04.03 - 2023.08.18`

结果：

| 窗口 | 结果 |
| --- | --- |
| `V1` | `1单 / -3.26% / DD 3.26%` |
| `V2` | `1单 / -3.31% / DD 3.31%` |
| `V3` | `1单 / -2.83% / DD 2.83%` |

### 结论

- 这组参数满足下跌 `ONLY_LONG` 的核心目标：
  - 成单极少
  - 最大回撤远低于 `6.5%`
- 外样本也维持了“极少出手”的特征
- 它的用途很明确：**下跌环境下的抑制多头交易**

## 四、下跌行情 `ONLY_SHORT`

### 搜索思路

- 目标是尽量多做、但必须控制回撤
- 本轮重点测试：
  - `space=3`
  - `time_min=5`
  - `MaxSpan 22-24`
  - `b_sum/a` 收紧
  - `CondA` 收紧
  - `P3P4` 强度提高

### 关键候选结果

| 候选 | `DOWN-1` | `DOWN-3` | `DOWN-4` | 结论 |
| --- | --- | --- | --- | --- |
| `ds_ms24_s3_t5_bsum4` | `+3.99% / DD 3.08% / 21单` | `-3.76% / DD 6.19% / 7单` | `-11.20% / DD 11.20% / 14单` | `DOWN-4` 失败 |
| `ds_ms24_s3_t5_axnarrow` | `+2.43% / DD 0.28% / 16单` | `-10.19% / DD 10.19% / 6单` | `-5.76% / DD 5.76% / 10单` | `DOWN-3` 失败 |
| `ds_ms24_s3_t5_r1_085` | `-8.42% / DD 8.42% / 17单` | `+1.75% / DD 2.53% / 6单` | `-2.66% / DD 4.05% / 13单` | `DOWN-1/4` 失败 |
| `ds_ms22_s3_t5_bsum4_r1` | `-5.61% / DD 5.61% / 14单` | `+1.75% / DD 2.53% / 6单` | `-1.85% / DD 3.24% / 12单` | `DOWN-1/4` 失败 |

### 结论

- 下跌 `ONLY_SHORT` 没有找到一组同时满足 4 个窗口要求的通用参数
- 症状非常稳定：
  - `DOWN-3/4` 里至少会有一个窗口变成负收益
  - 若继续提高触发强度，会损害 `DOWN-1`
- 说明当前 short 结构在这类下跌窗里没有稳定边际

## 总结

### 当前能落地的结果

- 可用：
  - 下跌 `ONLY_LONG` 抑制参数
- 接近可用但未完全通过：
  - 震荡 `ONLY_LONG`：`side_ms30_s3_r1_085`
- 未找到通用解：
  - 上涨 `ONLY_LONG`
  - 下跌 `ONLY_SHORT`

### 当前最重要的工程结论

- 继续只调参数，已经接近边界
- 若要让上涨和下跌 `SHORT` 真正满足目标，下一步更有价值的是改策略结构，而不是继续扫小数点

建议优先级：

1. 给策略增加显式的“行情过滤”层，先识别趋势 / 震荡，再切换参数集
2. 给 `SIDE-4` 这类低波动横盘增加单独的低波动结构模板，而不是用统一 `space_limit`
3. 给 short 方向增加额外的趋势确认，而不是单纯镜像 long 结构
