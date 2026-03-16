## ADDED Requirements

### Requirement: Strategy emits a tester-only backtest summary
The strategy SHALL emit a single structured `回测总结` log line when a backtest run finishes in MT5 tester. The summary SHALL be printed only for tester runs and SHALL NOT be emitted during normal live trading operation.

#### Scenario: Backtest completes successfully
- **WHEN** the strategy reaches the end of a tester run
- **THEN** it prints one `回测总结` log line for that run

### Requirement: Backtest summary includes return and pattern outcome metrics
The `回测总结` log line SHALL include, at minimum, the Chinese-labeled fields `初始资金`, `结束资金`, `总收益率`, `模式匹配次数`, `已闭仓笔数`, `盈利笔数`, `亏损笔数`, and `模式匹配胜率`. The strategy MAY include additional summary fields such as `净点数`, `平局笔数`, `闭仓胜率`, or `盈亏比`, but the required core fields SHALL remain stable. Percentage fields in the printed summary SHALL include a trailing `%` sign.

#### Scenario: User reviews business metrics at the end of a run
- **WHEN** a tester run finishes
- **THEN** the summary line contains the required balance, return, and pattern outcome fields

### Requirement: Pattern match win rate uses executed entries as the denominator
The strategy SHALL define `模式匹配次数` as the number of successfully executed `ENTRY_P4` events in the current tester run. The strategy SHALL define `模式匹配胜率` using the formula `winning_matches / matched_patterns * 100`, where `winning_matches` is the number of matched patterns whose resulting trades close with positive realized PnL during the same tester run. The printed `模式匹配胜率` value SHALL include a trailing `%` sign.

#### Scenario: Some matched patterns do not close profitably
- **WHEN** the tester run contains executed entries with both profitable and non-profitable outcomes
- **THEN** `模式匹配胜率` reflects profitable matched entries divided by total matched entries

### Requirement: Total return percentage uses balance-based calculation
The strategy SHALL define `总收益率` using the formula `((final_balance - initial_balance) / initial_balance) * 100`. `初始资金` SHALL be the account balance at strategy initialization for the tester run, and `结束资金` SHALL be the balance observed when the tester run ends. The printed `总收益率` value SHALL include a trailing `%` sign.

#### Scenario: Summary reports return consistently across parameter sets
- **WHEN** two tester runs start with the same initial deposit but finish with different balances
- **THEN** each summary reports `总收益率` from the same balance-based formula
