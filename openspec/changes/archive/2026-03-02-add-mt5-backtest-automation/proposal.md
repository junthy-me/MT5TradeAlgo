## Why

当前 MT5 参数搜索强依赖 GUI 操作和手工读取日志，既慢也不稳定，导致同一组参数难以复现和横向比较。需要把这轮已经成型的回测启动、结果提取和代表性配置收敛成仓库内可重复执行的工具链。

## What Changes

- 新增仓库内的 MT5 回测启动脚本，负责把 repo 中的 tester ini 配置转换成 Wine/MT5 可识别的运行时配置并启动 tester。
- 新增回测结果提取脚本，按品种、周期、起止日期和输入参数从 MT5 日志中定位目标 run，并产出结构化 JSON 摘要。
- 保留可复现的代表性 XAUUSD M15 回测配置，包括用户提供参数基线和当前最佳纯参数候选 `c12` 的训练/验证配置。
- 将这套自动化能力约束为“回测与结果汇总工具”，不改变 EA 的交易逻辑。

## Capabilities

### New Capabilities
- `mt5-backtest-automation`: 提供可复现的 MT5 回测启动、日志解析和代表性参数配置基线。

### Modified Capabilities
- None.

## Impact

- Affected code: `mt5/backtest_runner.py`、`mt5/run_backtest.sh`、`mt5/backtests/*.ini`
- Affected systems: 本机 Wine/MT5 tester 启动链路、日志解析与参数对比流程
- Validation: 需要验证脚本能够启动指定 ini、产出 JSON 摘要，并复现 `c12` 在 2025-06 与 2025-07 的对比结果
