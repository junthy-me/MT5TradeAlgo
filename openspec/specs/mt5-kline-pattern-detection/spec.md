# mt5-kline-pattern-detection Specification

## Purpose
TBD - created by archiving change add-mt5-kline-pattern-strategy. Update Purpose after archive.
## Requirements
### Requirement: 从 MT5 K 线数据中识别 PRD 定义的 P0-P6 多头模式
策略 SHALL 针对每个已配置的交易品种和周期分析已收盘的 bar，并识别满足 PRD 空间结构和时间结构的 P0 到 P6 候选点位。检测器 SHALL 为每个候选序列计算 `a`、`b1`、`b2`、`c`、`d`、`e`、`r1`、`r2`、`sspanmin`、`t1` 到 `t6`、`trigger_pattern_total_time_minute` 和 `tspanmin`。

#### Scenario: 候选序列生成标准化模式快照
- **WHEN** 某个交易品种拥有足够的已收盘 bar 来构成一组候选 P0-P6 序列
- **THEN** 检测器会产出一份包含点位时间、点位价格、空间变量和时间变量的模式快照

### Requirement: 强制执行可配置的点位取值与相邻跨度规则
策略 SHALL 支持 `AdjustPointMaxSpanKNumber` 来限制相邻点之间最多跨越的 K 线数量，并 SHALL 支持 `PointValueTypeEnum` 的 `KMax`、`KMin` 和 `KAvg`，以决定每个点位如何从所选 K 线中取值。任何超过配置跨度的候选序列 SHALL 被拒绝。

#### Scenario: 相邻点跨度超限时拒绝该序列
- **WHEN** 某个候选序列中的任意相邻点对跨越的 K 线数量超过 `AdjustPointMaxSpanKNumber`
- **THEN** 检测器拒绝该序列，且不会报告有效模式匹配

#### Scenario: 检测器使用配置的点位取值模式
- **WHEN** `PointValueTypeEnum` 被设置为 `KMax`、`KMin` 或 `KAvg` 之一
- **THEN** 检测器会在整个候选序列中一致地按该模式计算每个点位价格

### Requirement: 仅在 CondA 到 CondF 全部满足时确认完整匹配
策略 SHALL 仅在以下条件全部满足时将某个形态视为完整匹配：`b1 = x * b2` 且落在配置的 `x` 系数范围内，`r1 = y * r2` 且落在配置的 `y` 系数范围内，`t4 < z * (t1 + t2 + t3)`，`c < m * a`，`tspanmin >= tspanmin_conf`，以及每个相邻点跨度都小于或等于 `AdjustPointMaxSpanKNumber`。

#### Scenario: 全部约束通过时输出完整匹配
- **WHEN** 某个候选序列在当前输入配置下同时满足 CondA、CondB、CondC、CondD、CondE 和 CondF
- **THEN** 检测器将该序列标记为完整模式匹配，并将其提供给交易处理逻辑

#### Scenario: 部分匹配不得用于交易
- **WHEN** 某个候选序列的 CondA 到 CondF 中任意一项校验失败
- **THEN** 检测器不会将该序列输出为可交易匹配

