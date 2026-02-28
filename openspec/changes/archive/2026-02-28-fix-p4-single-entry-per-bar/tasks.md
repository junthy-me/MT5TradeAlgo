## 1. Runtime State And Entry Gating

- [x] 1.1 在 symbol 运行时状态中新增当前 `P4` bar 成功开仓锁定键，并定义其与现有 tick 级去重状态的职责边界
- [x] 1.2 在实时 `P4` 入场流程中接入 bar 锁判断，使同一 `symbol + timeframe` 的当前未收盘 bar 在首次成功开仓后不再重复提交买单
- [x] 1.3 将 bar 锁写入时点放在成功确认并注册受管仓位之后，确保噪声过滤失败、风控拦截和经纪商拒单都不会消耗当前 bar 名额
- [x] 1.4 为共享同一组 `P0/P1/P2/P3` 的历史骨架记录首个成功下单的 `P4` bar，并在首次成功后阻止后续 `P4` K 线柱继续下单

## 2. Logging And Auditability

- [x] 2.1 更新运行日志，区分“当前 `P4` bar 已锁定”与“达到 `InpMaxPositionsPerSymbol` 上限”两类阻止原因
- [x] 2.2 调整入场相关审计输出，使其能体现当前 `P4` bar 的边界和单次触发保护语义
- [x] 2.3 更新运行日志，区分“共享骨架已存在成功 `P4` bar”与当前 bar 锁定、持仓上限这两类既有阻止原因

## 3. Spec Ownership Cleanup

- [x] 3.1 修正本 change 的 `mt5-pattern-trade-management` delta spec，使其价格推导描述与当前真实规则一致
- [x] 3.2 明确 `mt5-pattern-trade-management` 是交易价格推导规则的唯一权威来源，并移除 `mt5-pattern-a-simplification` 中重复承载该规则的 spec ownership

## 4. Verification

- [x] 4.1 编译 EA，确认新增 bar 锁状态与入场流程调整没有引入构建错误
- [x] 4.2 在 Strategy Tester 中验证同一 `P4` 当前 bar 内首次成功开仓后，后续再次命中不会重复下单
- [x] 4.3 在 Strategy Tester 中验证同一 `P4` 当前 bar 内噪声过滤失败、风控拦截或拒单后，后续有效候选仍可继续尝试并成功开仓
- [x] 4.4 在 Strategy Tester 中验证共享同一组 `P0/P1/P2/P3` 的后续 `P4` K 线柱在首次成功前仍可尝试、首次成功后不会再次触发下单
