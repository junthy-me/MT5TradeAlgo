## Why

当前 MT5 形态检测在 `InpAdjustPointMaxSpanKNumber` 较小时可以接受，但当该参数提升到 `100` 级别时，回测时间会显著恶化，导致大跨度搜索几乎不可用。需要在不改变既有策略语义的前提下，重构搜索与触发流程，使历史结构计算和实时 P4 触发判断分层，并减少无效枚举。

## What Changes

- 重构模式搜索流程，将历史结构 `P0-P3` 的搜索与实时 `P4` 触发评估拆开处理。
- 为每个交易品种增加历史结构缓存，避免在每次 `OnTimer` 时重复全量搜索相同的已收盘 K 线结构。
- 引入候选极值点预提取或等效剪枝机制，降低 `InpAdjustPointMaxSpanKNumber` 提大后的组合搜索复杂度。
- 调整定时扫描逻辑，使高频轮询主要服务于实时 P4 触发和持仓管理，而不是每次都重跑整套历史结构搜索。
- 增加性能验证要求，确保在 `InpAdjustPointMaxSpanKNumber = 100` 级别下，回测耗时显著优于当前暴力搜索实现。

## Capabilities

### New Capabilities
- `mt5-pattern-search-performance`: 为 MT5 P4 模式策略提供可扩展的搜索与缓存机制，使大跨度点位搜索在回测和运行时保持可接受性能。

### Modified Capabilities

无。

## Impact

- 影响模式检测实现结构、每个 symbol 的运行时状态和 `OnTimer` 处理流程。
- 影响历史结构搜索路径，需要增加缓存、剪枝或候选极值点索引。
- 影响回测验证方式，需要增加性能对比和大跨度参数场景测试。
