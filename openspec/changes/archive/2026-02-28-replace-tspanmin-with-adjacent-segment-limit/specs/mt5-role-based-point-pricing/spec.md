## MODIFIED Requirements

### Requirement: P0-P3 和 P5-P6 必须按点位角色使用已收盘 K 线极值
策略 SHALL 使用按点位角色定义的价格规则计算历史确认点和后续确认点。P0、P2、P5 SHALL 使用对应已收盘 K 线的最低价，P1、P3、P6 SHALL 使用对应已收盘 K 线的最高价。P4 SHALL 使用当前实时价格。本策略 SHALL NOT 再提供 `PointValueTypeEnum` 作为统一点位取值模式来覆盖这些角色化规则。

#### Scenario: 波谷点使用已收盘 K 线最低价
- **WHEN** 策略为某个候选序列计算 P0、P2 或 P5 的价格
- **THEN** 该点位价格使用对应已收盘 K 线的最低价

#### Scenario: 波峰点使用已收盘 K 线最高价
- **WHEN** 策略为某个候选序列计算 P1、P3 或 P6 的价格
- **THEN** 该点位价格使用对应已收盘 K 线的最高价

#### Scenario: 统一点位取值模式不再生效
- **WHEN** 本策略计算 P0-P6 点位价格
- **THEN** 策略仅按角色化点位规则取值，而不会再暴露或读取统一的 `PointValueTypeEnum` 配置

## REMOVED Requirements

### Requirement: CondE 的 tspanmin 不得包含 t4
**Reason**: `CondE` 不再基于 `tspanmin` 的分钟阈值，而改为基于 `P0-P1`、`P1-P2`、`P2-P3`、`P3-P4` 四段中相邻线段数量上限的结构拥挤度过滤。
**Migration**: 将所有依赖 `tspanmin_conf` / `InpTSpanMinConf` 的配置迁移为 `InpMaxAdjustPointSpan`，并按“bar span == 1 的线段数量”来理解过滤逻辑。

### Requirement: 本策略中角色化点位取值优先于全局统一点位取值模式
**Reason**: 统一点位取值模式被完全废弃，角色化点位规则不再是“优先级更高的覆盖逻辑”，而是唯一有效的点位取值语义。
**Migration**: 删除 `PointValueTypeEnum` / `InpPointValueType` 相关配置，统一按角色化规则理解 `P0-P6` 点位来源。
