## Context

当前策略已经经历过多轮参数语义调整，但主实现里仍混合存在三类问题：

- 输入参数名与公式语义脱节，例如 `InpRatioC`、`InpSoftLossN`
- 两条过滤规则仍然挂在主流程里，但用户已经不再希望继续用它们筛掉信号
- 部分日志与校验输出仍绑定旧参数名，继续增加调试歧义

这次改动不改变 P0-P6 点位定义，也不改变止盈、弱止损激活的核心公式，只做参数语义收敛和两条过滤的移除。

## Goals / Non-Goals

**Goals:**
- 删除 `InpMaxAdjustPointSpan` 及其相邻线段过滤逻辑
- 删除 `NoiseFilter_bSumValueCompBuyPricePercent` 及其入场噪声过滤逻辑
- 将两个比例参数改成可从名字直接读出分子、分母语义的新名称
- 将 `InpProfitC` 默认值更新为 `0.6`
- 同步清理实现、日志与规格中的废弃参数名

**Non-Goals:**
- 不改变 `CondA`、`CondC`、`CondF` 的现有行为
- 不修改弱止损价格本身的计算方式
- 不重构模式缓存或持仓管理整体结构

## Decisions

### 1. `InpRatioC` 重命名为 `InpMinP3P4DropRatioOfStructure`

该参数实际控制的是：

```text
r1 = c / (a + b1 + b2)
CondB = r1 >= threshold
```

新名称直接表达“P3-P4 下跌幅度占前序整体结构振幅的最小占比”，避免继续通过单字母参数名推断语义。

备选方案：
- `InpMinP3P4DropRatio`
  否决原因：没有体现分母是整体结构振幅，语义仍然不完整。

### 2. `InpSoftLossN` 重命名为 `InpMinP5P6ReboundRatioOfP3P5Drop`

该参数实际控制的是：

```text
e >= threshold * (c + d)
```

新名称直接表达“P5-P6 反弹高度占 P3-P5 总下跌幅度的最小占比”，与弱止损激活条件一一对应。

备选方案：
- `InpMinP5P6ReboundRatio`
  否决原因：没有体现分母是 `P3-P5` 的总下跌。

### 3. 删除相邻线段数量限制

`InpMaxAdjustPointSpan` 对应的 `adjacent_segment_count` 过滤将被完全移除：

- 删除输入参数校验
- 删除 `PatternSnapshot` 中相关字段
- 删除 `CondE` 约束
- 更新匹配条件日志与 exact-compare 调试输出

保留每段 `pointSpans[i] <= InpAdjustPointMaxSpanKNumber` 的单段跨度限制。

### 4. 删除 `(b1+b2)/buyPrice` 噪声过滤

`NoiseFilter_bSumValueCompBuyPricePercent` 及其 `CondH` 过滤将被完全移除：

- `ExecuteEntry()` 不再在发单前执行该过滤
- 删除相关日志字段与失败日志函数
- 开仓日志只保留仍参与决策的阈值与结构变量

### 5. 将 `InpProfitC` 默认值改为 `0.6`

只调整默认值，不改变止盈公式：

```text
profitPrice = entryPrice + InpProfitC * (b1 + b2 + a)
```

## Risks / Trade-offs

- [删除两条过滤后，候选与实际入场数量可能增加] -> Mitigation: 保留现有日志中的关键结构变量，便于回测对比。
- [回测 ini 仍使用旧参数名会导致加载失败或参数漂移] -> Mitigation: 同步更新仓库内受影响的 ini 文件。
- [长参数名会让输入面板更拥挤] -> Mitigation: 以语义清晰为优先，后续如需可再统一做输入分组整理。
