## MODIFIED Requirements

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
