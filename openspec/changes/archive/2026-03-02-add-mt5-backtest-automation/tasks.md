## 1. Backtest Tooling

- [x] 1.1 Add a shell launcher that converts repo tester ini files into MT5-compatible runtime configs and starts the tester under Wine.
- [x] 1.2 Add a Python runner that orchestrates a backtest run, waits for completion, parses MT5 logs, and emits JSON summaries.

## 2. Reproducible Configurations

- [x] 2.1 Check in the user-provided XAUUSD M15 baseline configuration from 2025-02-28 for repeatable comparison.
- [x] 2.2 Check in the representative `c12` XAUUSD M15 training and July validation configurations used to compare the best pure-parameter candidate across months.

## 3. Verification

- [x] 3.1 Verify the launcher and runner can execute MT5 tester runs from repo-local ini files in the current Wine environment.
- [x] 3.2 Verify the parser emits structured JSON summaries for completed runs, including trade counts, net points, approximate USD profit, and exit reason counts.
- [x] 3.3 Verify the retained configs reproduce the stored comparison baseline: `c12` outperforms nearby pure-parameter variants in June while still failing cross-month robustness in July.
