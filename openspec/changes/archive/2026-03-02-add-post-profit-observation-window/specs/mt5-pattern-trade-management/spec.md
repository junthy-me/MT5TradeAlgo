## ADDED Requirements

### Requirement: 止盈后进入盈利观察期并阻止新的买单
策略 SHALL 在某个 `symbol + timeframe` 的 EA 管理买单因 `profit_target` 成功平仓后，立即为该 `symbol + timeframe` 启动盈利观察期。盈利观察期 SHALL 从该次盈利平仓所在的当前 bar 开始生效，并覆盖该 bar 的剩余时间以及其后连续 `InpProfitObservationBars` 根完整 K 线；在此期间，策略 SHALL 不再为该 `symbol + timeframe` 提交新的买单。盈利观察期仅 SHALL 由 `profit_target` 平仓触发，`hard_stop`、`soft_stop`、手动平仓或非 EA 平仓 SHALL NOT 启动该门控。策略在观察期阻止入场时也 SHALL 输出独立日志，说明这是止盈后观察期阻止，而不是 `P4` 同 bar 锁、共享骨架成功锁或持仓上限导致的阻止。

#### Scenario: 止盈后当前 bar 与后续观察窗口内阻止新买单
- **WHEN** 某个 `symbol + timeframe` 的 EA 管理买单刚刚因 `profit_target` 成功平仓，且当前扫描仍处于该盈利平仓所在 bar 或之后 `InpProfitObservationBars` 根完整 bar 之内
- **THEN** 策略不会再为该 `symbol + timeframe` 提交新的买单

#### Scenario: 非止盈平仓不触发观察期
- **WHEN** 某个由 EA 管理的持仓因 `hard_stop`、`soft_stop` 或其他非 `profit_target` 原因平仓
- **THEN** 策略不会因此启动盈利观察期

#### Scenario: 观察窗口结束后恢复允许入场
- **WHEN** 当前 `symbol + timeframe` 已经超过最近一次 `profit_target` 平仓所在 bar 之后的 `InpProfitObservationBars` 根完整 K 线
- **THEN** 策略恢复允许该 `symbol + timeframe` 的新买单继续进入后续入场门控
