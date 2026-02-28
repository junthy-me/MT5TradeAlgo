## 1. Detection Rule Replacement

- [x] 1.1 移除 `InpTSpanMinConf` 输入参数，并新增 `InpMaxAdjustPointSpan`
- [x] 1.2 将 `CondE` 从 `tspanmin >= threshold` 替换为 `adjacent_segment_count <= InpMaxAdjustPointSpan`
- [x] 1.3 将“相邻线段”实现为 `P0-P1`、`P1-P2`、`P2-P3`、`P3-P4` 四段中 bar span 恰好等于 `1` 的计数
- [x] 1.4 更新模式过滤/诊断输出，使其能够显示相邻线段数量和四段 span 分布

## 2. Point Value Cleanup

- [x] 2.1 移除 `InpPointValueType` / `PointValueTypeEnum` 及相关无效分支
- [x] 2.2 确认 `P0-P6` 点位取值统一固定为角色化规则：`P0/P2/P5 -> Low`、`P1/P3/P6 -> High`、`P4 -> Realtime`
- [x] 2.3 清理所有参数说明、日志或注释中仍暗示统一点位取值模式会生效的表述

## 3. Verification

- [x] 3.1 编译 EA，确认替换 `CondE` 与移除点位模式参数后没有引入构建错误
- [ ] 3.2 使用用户给出的 15 分钟示例验证：当 `InpMaxAdjustPointSpan = 2` 时，含 2 个相邻线段的模式可通过，含 3 个相邻线段的模式被过滤
- [ ] 3.3 验证 `P0-P6` 在移除 `InpPointValueType` 后仍按角色化规则取值，且不会因旧配置模板残留而改变结果
