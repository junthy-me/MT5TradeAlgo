# mt5-backtest-automation Specification

## Purpose
TBD - created by archiving change add-mt5-backtest-automation. Update Purpose after archive.
## Requirements
### Requirement: 仓库内回测配置可直接启动 MT5 tester
系统 SHALL 提供仓库内的回测启动脚本，使 repo 中的 tester ini 可以在当前 macOS + Wine + MT5 环境下直接启动 MT5 tester。启动器 SHALL 负责把源 ini 转换为 `UTF-16LE + BOM` 的运行时配置，写入 `/tmp/mt5run`，并通过 Wine 使用 `Z:\\tmp\\...` 路径启动 `terminal64.exe`。

#### Scenario: 从仓库 ini 生成运行时配置并启动 tester
- **WHEN** 操作人员使用某个 repo 内的 tester ini 调用回测启动脚本
- **THEN** 系统生成对应的运行时 ini，并以该配置启动 MT5 tester

### Requirement: 回测结果可从 MT5 日志提取为结构化摘要
系统 SHALL 提供结果提取脚本，按回测 stem、起止日期和输入参数，从 terminal/agent 日志中识别目标 run，并输出结构化 JSON 摘要。摘要 SHALL 至少包含闭仓数量、净点数、近似收益美元、胜负次数、胜率、profit factor、总收益率、模式匹配次数、模式匹配胜率、输入参数和出场原因分布。

当目标 run 中存在策略输出的 `回测总结` 日志时，结果提取脚本 SHALL 优先使用该 summary 中的标准字段来填充 `total_return_pct`、`matched_patterns` 和 `pattern_match_win_rate_pct` 等对齐指标；当目标 run 不包含该 summary 时，结果提取脚本 SHALL 保持向后兼容，并继续按现有 entry/exit 日志计算可得指标。

#### Scenario: 指定 run 产出包含新增指标的 JSON 摘要
- **WHEN** 操作人员用结果提取脚本运行某个已完成的回测
- **THEN** 系统输出对应 run 的 JSON 摘要，并包含总收益率、模式匹配次数和模式匹配胜率

#### Scenario: 目标 run 已输出回测总结
- **WHEN** 结果提取脚本识别到目标回测的 `回测总结` 日志
- **THEN** 脚本优先使用该日志中的标准 summary 字段，而不是重复推导同名统计

#### Scenario: 目标 run 没有回测总结
- **WHEN** 操作人员解析较早的历史回测日志
- **THEN** 结果提取脚本仍能输出兼容摘要，并对无法直接获得的新增字段使用既定回退计算或留空策略

### Requirement: 仓库保留代表性 XAUUSD M15 参数基线
系统 SHALL 在仓库中保留可复现的代表性 XAUUSD M15 tester ini，包括用户 2025-02-28 参数基线，以及最佳纯参数候选 `c12` 的训练配置和跨月验证配置，用于后续回测比较与回归分析。

#### Scenario: 可以直接重跑用户基线与 c12 对比
- **WHEN** 操作人员需要比较用户参数基线与最佳纯参数候选 `c12`
- **THEN** 仓库中存在可直接调用的 tester ini，使这两组配置能够被重复回测

