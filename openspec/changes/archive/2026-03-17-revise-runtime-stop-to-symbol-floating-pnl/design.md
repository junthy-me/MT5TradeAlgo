## Context

当前实现把 runtime stop 建模为全局状态，只在某笔受管仓位成功平仓后，按历史成交累计已实现账户货币金额，再决定是否停止新的自动开仓。它既不看未平仓浮盈浮亏，也不在触发后主动收掉当前品种仓位，因此与新的风险收口目标不一致。

这次改动需要同时调整运行时状态模型、阈值评估时机、触发后的持仓处理流程，以及 stop 日志的输出范围。变更会跨越 `SymbolRuntimeState`、持仓管理主循环、平仓后统计更新和 README/spec。

## Goals / Non-Goals

**Goals:**
- 将 `InpMaxProfitStopMoney` / `InpMaxLossStopMoney` 改为按品种生效。
- 统计口径包含该品种“已实现盈亏 + 当前浮动盈亏”。
- 当某个品种达到 stop 阈值时，立即平掉该品种全部由 EA 管理的未平仓仓位。
- 触发后阻止该品种在本次 EA 运行内继续自动开仓。
- 输出一次按品种的 stop 原因日志和摘要日志。

**Non-Goals:**
- 不把 stop 作用范围扩展回整个 EA 全局。
- 不平掉非本 EA 管理的仓位。
- 不跨 EA 重启持久化 symbol stop 状态。
- 不改变既有强止损、弱止损、止盈、观察窗口和骨架锁的基础逻辑。

## Decisions

### 决策：将 runtime stop 状态下沉到 `SymbolRuntimeState`

新的 stop 语义是“按当前品种”而不是“整个 EA 实例”，因此运行时累计金额、触发原因、触发时刻和是否已输出摘要，都应挂到 `SymbolRuntimeState`，而不是继续放在全局 `g_runtimeStop` 上。

这样设计后，每个 symbol 都能独立维护：
- `grossRealizedProfitMoney`
- `grossRealizedLossMoney`
- `netRealizedMoney`
- `floatingMoney`
- `totalNetMoney`
- `stopTriggered`
- `stopReason`
- `stopTriggeredAt`
- `stopSummaryEmitted`

备选方案是保留全局 stop 状态，再额外记录当前触发 symbol。这样实现会让状态机混乱，也不利于后续按 symbol 继续管理。

### 决策：浮动盈亏用当前受管持仓的实时账户货币结果汇总

触发条件需要包含浮盈浮亏，因此不能只依赖平仓后的历史成交。实现上应在每次 `ProcessSymbol(symbol)` 轮询时，遍历该 symbol 下所有由 EA 管理的未平仓持仓，汇总其实时账户货币结果。

浮动金额应以 MT5 当前持仓结果为准，并包含：
- `POSITION_PROFIT`
- `POSITION_SWAP`
- `POSITION_COMMISSION`（若平台可提供）

然后按：
- `total_net_money = net_realized_money + floating_money`
- `total_loss_money = -total_net_money`（仅在 `total_net_money < 0` 时有意义）

做阈值判断。

### 决策：stop 触发后立即平掉当前品种全部受管仓位，并停止该品种后续开仓

用户目标是“防止盈利丢失或者亏损进一步扩大”，所以 stop 触发后不能只拦截后续新单，必须先对当前品种全部受管仓位执行平仓。之后该 symbol 在本次运行内保持 stopped 状态，不再允许新的自动开仓。

执行顺序应为：
1. 先完成常规 `ManageOpenPositions(symbol)`。
2. 再计算该 symbol 的总盈亏是否达到阈值。
3. 若触发，则记录 stop 原因，打印一次摘要，并批量平掉该 symbol 的全部受管仓位。
4. 本次运行后续轮询中，直接跳过该 symbol 的新开仓路径。

这样可以避免在同一轮里既触发 stop 又继续对该 symbol 做新的入场决策。

### 决策：stop 日志改为按品种输出，并补充浮动/总盈亏字段

既然语义从“全局已实现 stop”变成“按品种总盈亏 stop”，日志就必须反映 symbol 维度和浮动结果。摘要至少应包含：
- `symbol`
- `reason`
- `gross_realized_profit_money`
- `gross_realized_loss_money`
- `net_realized_money`
- `floating_money`
- `total_net_money`
- `profit_threshold`
- `loss_threshold`

继续保留一次性输出约束，避免每轮询都刷日志。

## Risks / Trade-offs

- [浮动盈亏读取口径在不同券商环境下存在差异] → 优先使用 MT5 持仓原生金额字段，避免自行按价格差换算。
- [批量平仓时个别仓位关闭失败] → 逐笔尝试平仓并保留失败日志，不因为单笔失败阻断其他同 symbol 仓位的关闭尝试。
- [触发 stop 后又重新开仓会违背风控目标] → 对 symbol 增加持久到本次运行结束的 stopped 状态，并在新开仓路径前强制拦截。
- [已实现统计与浮动统计混在一处会让排障困难] → 日志里拆开输出 realized/floating/total 三组金额。
