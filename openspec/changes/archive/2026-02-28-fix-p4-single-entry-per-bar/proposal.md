## Why

当前策略将 `P4` 作为实时触发点使用 tick 时间和实时价格去重，这会让同一根未收盘 K 线在价格持续跳动时反复被视为新的入场事件，并在一次成功开仓后继续重复下单。虽然 `InpMaxPositionsPerSymbol` 能限制总持仓数，但它不能表达“同一根 P4 bar 只允许一次成功入场”的交易语义，因此需要补上更准确的 bar 级约束。

## What Changes

- 修改实时 `P4` 触发后的入场约束语义：同一 `symbol + timeframe` 的当前 `P4` K 线周期内，最多只允许一次成功开仓。
- 明确只有“成功创建由 EA 管理的仓位”才会锁定当前 `P4` bar；如果只是模式匹配成功，但被噪声过滤、风控检查或经纪商拒单阻止，则不消耗该 bar 的唯一开仓名额。
- 增加跨 bar 的骨架级约束：如果多个 `P4` 入场点复用同一组 `P0/P1/P2/P3`，则在第一个成功下单的 `P4` K 线柱出现后，后续 `P4` K 线柱即使仍满足条件也不再下单；若前面的 `P4` K 线柱都未成功下单，则后续 `P4` K 线柱仍可继续尝试。
- 调整实时 `P4` 触发与去重说明，避免将“每个新 tick”误当成新的独立入场窗口。
- 更新交易与运行日志语义，使 bar 级阻止原因可以与现有持仓上限阻止原因区分开。
- 收敛交易价格推导规则的 spec 归属，明确 `mt5-pattern-trade-management` 是入场价、强止损、止盈和弱止损规则的唯一权威来源，避免多个 capability 重复维护同一组公式。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mt5-pattern-trade-management`: 修改入场管理要求，新增“同一 `P4` 当前 bar 内只允许一次成功开仓，且仅成功开仓才锁定该 bar”的行为约束。
- `mt5-role-based-point-pricing`: 修改实时 `P4` 触发语义，明确 `P4` 作为实时触发点时，其 bar 周期是去重和单次触发保护的边界，并且同一组 `P0-P3` 在首个成功下单之前可跨多个 `P4` bar 继续触发，成功后后续 `P4` bar 不再作为有效入场窗口。
- `mt5-pattern-a-simplification`: 修改该 capability 的规格边界，使其不再重复承载交易价格推导公式，而是将该类规则收敛到 `mt5-pattern-trade-management`。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5` 的实时 `P4` 评估、入场执行、订单注释/日志和 symbol 运行时状态管理。
- Affected specs: `mt5-pattern-trade-management`、`mt5-role-based-point-pricing` 和 `mt5-pattern-a-simplification` 的 requirement 边界将被重新对齐。
- Affected behavior: 同一根未收盘 `P4` K 线内的重复买入会被抑制；若后续 `P4` K 线柱复用同一组 `P0/P1/P2/P3`，则只有在更早某个 `P4` bar 已经成功下单后，这些更晚的 bar 才不会再次触发下单。
- Validation: 需要补充对“同 bar 首次成功开仓后再次命中不再下单”“同 bar 内失败尝试后后续成功开仓仍允许”以及“同一组 `P0-P3` 的后续 `P4` bar 在首次成功前仍可尝试、首次成功后不再下单”这三类场景的验证。
