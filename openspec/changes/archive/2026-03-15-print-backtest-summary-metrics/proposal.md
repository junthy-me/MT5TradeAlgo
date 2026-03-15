## Why

当前回测结束后，MT5 tester 主要只给出 balance、耗时和基础平台统计，而策略本身不会输出“这次回测到底赚了多少、匹配了多少次、胜率如何”的业务摘要。这使得每次比较参数组时都要再去手工读日志或依赖外部脚本，无法在 tester 结束时直接看到核心结果。

## What Changes

- 为策略新增回测结束摘要日志，在 tester run 完成时输出与当前回测直接相关的业务指标，而不是只保留平台级 `Test passed` 行。
- 定义并输出至少以下摘要指标：初始资金、结束资金、总收益率、模式匹配次数、闭仓次数、盈利次数、亏损次数、模式匹配胜率，以及可选的净点数 / profit factor 等补充统计。
- 明确“模式匹配胜率”的统计口径，使其在回测窗口内可重复计算，并在日志字段命名上与其他统计项保持一致。
- 使仓库内回测自动化摘要与新的策略回测汇总字段保持对齐，避免 tester 结束日志和 `backtest_runner.py` JSON 输出对同一轮回测给出不同统计口径。

## Capabilities

### New Capabilities

- `mt5-backtest-summary-logging`: 在回测结束时输出策略级 summary 日志，涵盖收益率、模式匹配胜率和关键交易统计。

### Modified Capabilities

- `mt5-backtest-automation`: 扩展回测摘要契约，使自动化结果提取能够输出与策略回测 summary 对齐的核心统计字段，至少包括总收益率和模式匹配胜率。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5`, `mt5/backtest_runner.py`
- Affected docs/configs: `README.md` and any backtest usage notes that describe run outputs
- Affected specs: `openspec/specs/mt5-backtest-automation/spec.md`, new `openspec/changes/print-backtest-summary-metrics/specs/mt5-backtest-summary-logging/spec.md`
