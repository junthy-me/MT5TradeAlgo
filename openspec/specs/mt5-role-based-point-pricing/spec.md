# mt5-role-based-point-pricing Specification

## Purpose
TBD - created by archiving change refine-mt5-point-role-pricing. Update Purpose after archive.
## Requirements
### Requirement: P0-P3 和 P5-P6 必须按点位角色使用已收盘 K 线极值
策略 SHALL 使用按点位角色定义的价格规则计算历史确认点和后续确认点。P0、P2、P5 SHALL 使用对应已收盘 K 线的最低价，P1、P3、P6 SHALL 使用对应已收盘 K 线的最高价。

#### Scenario: 波谷点使用已收盘 K 线最低价
- **WHEN** 策略为某个候选序列计算 P0、P2 或 P5 的价格
- **THEN** 该点位价格使用对应已收盘 K 线的最低价

#### Scenario: 波峰点使用已收盘 K 线最高价
- **WHEN** 策略为某个候选序列计算 P1、P3 或 P6 的价格
- **THEN** 该点位价格使用对应已收盘 K 线的最高价

### Requirement: P4 必须作为实时触发点使用当前实时价格
策略 SHALL 在 P0-P3 历史结构已经具备的前提下，将 P4 作为实时触发点处理。P4 的价格 SHALL 使用当前实时价格，而不是等待当前 K 线收盘后再按 K 线极值取值。

#### Scenario: P4 用实时价参与模式触发
- **WHEN** 策略已经识别出一组满足历史结构条件的 P0、P1、P2、P3
- **THEN** 策略使用当前实时价格作为 P4 参与与 P4 相关的空间变量和入场触发判断

### Requirement: CondE 的 tspanmin 不得包含 t4
策略 SHALL 将 `CondE` 中使用的 `tspanmin` 定义为 `min(t1, t2, t3)`。`t4` SHALL 不参与 `CondE` 的 `tspanmin` 计算。`CondC` SHALL 保持原定义不变。

#### Scenario: CondE 仅基于历史确认段时长判断
- **WHEN** 策略计算 `CondE`
- **THEN** `tspanmin` 仅取 `t1`、`t2`、`t3` 的最小值，而不包含 `t4`

#### Scenario: CondC 继续使用原时间关系
- **WHEN** 策略计算 `CondC`
- **THEN** 仍按 `t4 < z * (t1 + t2 + t3)` 的规则进行判断

### Requirement: 空间变量和日志必须反映新的点位来源
策略 SHALL 基于新的点位来源计算 `a`、`b1`、`b2`、`c`、`d`、`e` 等空间变量，并在日志中明确反映点位价格、点位来源以及实时 P4 触发语义。

#### Scenario: 日志反映角色化点位和实时触发
- **WHEN** 策略输出模式匹配或交易日志
- **THEN** 日志中包含按角色取值后的点位价格，并能区分 P4 为实时触发价而不是已收盘 K 线极值

### Requirement: 本策略中角色化点位取值优先于全局统一点位取值模式
策略 SHALL 在本策略的 P0-P6 点位计算中优先使用角色化点位取值规则，而不是将 `PointValueTypeEnum` 作为统一点位取值规则覆盖全部点位。

#### Scenario: 全局统一点位取值不覆盖角色规则
- **WHEN** 本策略计算 P0-P6 点位价格
- **THEN** 角色化点位取值规则优先于统一的 `PointValueTypeEnum` 取值逻辑

