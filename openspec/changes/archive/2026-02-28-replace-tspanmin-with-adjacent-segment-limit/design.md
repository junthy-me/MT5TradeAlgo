## Context

当前策略用 `InpTSpanMinConf` 约束 `CondE = min(t1, t2, t3) >= tspanmin_conf`，试图过滤历史结构中过于拥挤、容易受噪声干扰的模式。但这个规则只覆盖 `P0-P1`、`P1-P2`、`P2-P3` 三段，不包含 `P3-P4`，而且它按“分钟数”判断，过滤效果会随 `InpTF` 周期变化而明显漂移。用户现在希望直接按结构拥挤度来定义过滤条件：统计 `P0-P1`、`P1-P2`、`P2-P3`、`P3-P4` 四段中有多少段是“相邻线段”，并限制该数量的上限。

与此同时，`InpPointValueType` / `PointValueTypeEnum` 已经不再参与 `P0-P6` 的实际取值，代码与主 spec 都已收敛到角色化点位规则。继续保留这个输入参数只会让配置面板和真实行为脱节，因此应在同一个 change 中一并清理。

## Goals / Non-Goals

**Goals:**
- 用新的 `InpMaxAdjustPointSpan` 替换 `InpTSpanMinConf`，让历史骨架过滤基于“相邻线段数量上限”而不是“最短分钟阈值”。
- 将“相邻线段”定义为组成该线段的两点对应 bar span 等于 `1`，并且统计范围覆盖 `P0-P1`、`P1-P2`、`P2-P3`、`P3-P4` 四段。
- 让完整匹配条件中的 `CondE` 表达结构拥挤度限制，而不是 `tspanmin` 限制。
- 删除 `InpPointValueType` / `PointValueTypeEnum`，并把点位取值语义明确收敛为角色化规则。

**Non-Goals:**
- 不改变 `CondA`、`CondC`、`CondF` 的业务含义。
- 不改变 `P4` 的实时触发语义，也不调整 `P5/P6`、弱止损或交易管理逻辑。
- 不引入“相邻线段权重”或不同线段不同阈值的复杂配置，本次只统计总数。

## Decisions

### 1. 用“相邻线段数量”重定义 CondE

`CondE` 将不再基于 `tspanmin`，而是基于四段历史/触发线段中的相邻段数量：

```text
adjacent_segment_count =
  count(
    span(P0,P1) == 1,
    span(P1,P2) == 1,
    span(P2,P3) == 1,
    span(P3,P4) == 1
  )

CondE = adjacent_segment_count <= InpMaxAdjustPointSpan
```

原因：
- 用户真正想防的是“结构太挤、容易由噪声造成伪模式”，而不是单纯某一段分钟数太短。
- 这个定义覆盖 `P3-P4`，比现有 `tspanmin` 更贴近实际需求。
- 它按 bar span 判断，跨不同 `InpTF` 周期时语义更稳定。

备选方案：
- 保留 `CondE` 为 `tspanmin`，另加一个新条件统计相邻段数量。否决原因是会让两套相似但不同的拥挤度过滤并存，增加理解和维护成本。

### 2. “相邻”定义固定为 bar span == 1

两点组成的线段若对应 bar span 恰好为 `1`，则该线段视为相邻。这表示两个点位落在连续 K 线柱上，中间没有再夹其他 bar。

原因：
- 这和用户提供的 15 分钟示例完全一致，例如 `21:15 -> 21:30` 被视为相邻。
- 该定义直接映射到现有 `pointSpans[]` 结构，便于实现和验证。

备选方案：
- 将“只隔一个 K 线柱”解释为 span 等于 `2`。否决原因是与用户示例不一致，会导致实现和预期相反。

### 3. 废弃统一点位取值模式，保留角色化规则为唯一来源

`InpPointValueType` 和 `PointValueTypeEnum` 将从运行时输入和检测语义中移除。`P0/P2/P5` 固定取已收盘 bar 低点，`P1/P3/P6` 固定取已收盘 bar 高点，`P4` 固定取实时价格。

原因：
- 当前实现已经完全按角色化规则运行，统一点位模式没有实际效果。
- 删除无效参数比继续保留“不会生效的配置项”更清晰。

备选方案：
- 保留参数但在说明中标注“当前未使用”。否决原因是仍会误导操作者，并让 spec 保持不必要的过渡语义。

## Risks / Trade-offs

- [相邻线段数量过滤可能和旧版 `tspanmin` 过滤结果差异较大] -> Mitigation: 在 spec 和验证任务里给出明确例子，并通过回测对照确认被过滤的模式类型符合预期。
- [沿用 `CondE` 名称但改变其含义，可能让历史理解出现偏差] -> Mitigation: 在 spec 中明确写出旧的 `tspanmin` 语义已被替换，不再作为完整匹配门槛。
- [移除 `InpPointValueType` 可能影响依赖旧配置模板的使用者] -> Mitigation: 在 proposal/tasks 中将其标记为 breaking change，并要求同步清理参数说明与模板。

## Migration Plan

1. 更新 proposal/specs，明确 `InpTSpanMinConf` 被 `InpMaxAdjustPointSpan` 取代，`InpPointValueType` 被废弃。
2. 在检测逻辑中移除 `PointValueTypeEnum` 分支与输入参数，并新增相邻线段数量计算。
3. 将 `CondE` 判断替换为 `adjacent_segment_count <= InpMaxAdjustPointSpan`。
4. 更新日志/诊断字段，使被过滤时可以看出相邻线段数量及四段 span 分布。
5. 通过编译和回测验证示例 1 可通过、示例 2 被过滤，以及角色化点位取值不受旧参数影响。

Rollback:
- 恢复 `InpTSpanMinConf` 和旧的 `CondE = tspanmin >= threshold` 逻辑，并重新引入 `InpPointValueType` 作为运行时输入。

## Open Questions

- 暂无。当前需求已经明确：相邻线段按 span==1 统计，`InpMaxAdjustPointSpan` 表示四段中最多允许多少段相邻。
