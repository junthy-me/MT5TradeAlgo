## Context

当前仓库已经有两套与回测结果相关的输出。第一套是 MT5 tester/terminal 自带的 `Test passed`、balance 和耗时日志，这些信息偏平台层，不直接回答“这轮参数回测的业务表现如何”。第二套是 `mt5/backtest_runner.py` 的结构化 JSON 摘要，它能算出胜率和 profit factor，但这些统计只在外部脚本执行后可见，而且字段还没有覆盖总收益率，也没有和策略日志共享同一套命名契约。

用户现在要的是“回测结束时直接打印可读 summary”，因此需要在策略自身生命周期里增加一个 tester-only 汇总输出，同时避免与现有自动化脚本的统计口径分叉。

## Goals / Non-Goals

**Goals:**
- 在单次 MT5 tester run 结束时，由策略输出一条稳定、可解析的 summary 日志。
- 明确定义总收益率、模式匹配次数、模式匹配胜率等指标的计算口径。
- 让 `backtest_runner.py` 的 JSON 摘要与新 summary 字段对齐，至少包含总收益率和模式匹配胜率。
- 保持 live trading 路径不受影响，避免在实盘日志中引入回测专用汇总。

**Non-Goals:**
- 不修改模式检测、下单、止盈止损或其他交易行为。
- 不引入新的持久化存储或外部依赖。
- 不替换 MT5 原生 tester 输出；策略 summary 只是在现有输出上补充业务统计。

## Decisions

### 1. 使用单行中文 `回测总结` 日志作为策略侧契约

策略在回测结束时 SHALL 输出一条以固定前缀 `回测总结` 开头的 summary，例如 `回测总结 品种=... 总收益率=...% 模式匹配胜率=...%`。这样做的原因是：
- 人工读 tester log 时可以快速定位；
- `backtest_runner.py` 可以稳定解析，不需要再从分散的 `ENTRY_P4` / `EXIT` 行反推所有指标；
- 字段扩展时可以增量添加，不需要破坏已有行的语义。

替代方案是复用多行自然语言日志，但这会让解析脆弱，也不适合后续自动化消费。

### 2. 指标按“回测运行内聚合”计算，而不是从历史日志反查

策略内部在本次 tester run 内累积 entry/exit 和盈亏统计，并在回测结束时一次性输出。这样可以避免：
- 依赖外部脚本回扫日志；
- 因日志截断、同日多次回测混杂而产生统计漂移；
- 无法明确处理未闭仓模式匹配的问题。

### 3. 明确区分“模式匹配胜率”和“闭仓胜率”

`模式匹配胜率` 定义为：
- `winning_matches / matched_patterns`

其中：
- `matched_patterns` = 成功执行 `ENTRY_P4` 的次数
- `winning_matches` = 最终闭仓盈利的 entry 次数

这样该指标更贴近用户说的“模式匹配胜率”，而不是仅针对已闭仓交易计算。对于 `matched_patterns > closed_trades` 的情况，未闭仓 entry 仍计入分母，但不计入盈利次数。

同时允许 summary 额外输出 `closed_trade_win_rate_pct = winning_trades / closed_trades` 作为补充指标，但它不是本次 change 的最小契约。

### 4. 总收益率按 balance 口径计算

`total_return_pct` 定义为：
- `((final_balance - initial_balance) / initial_balance) * 100`

该口径与用户观察 tester balance 的习惯一致，也比点数或美元净值更便于跨参数组比较。初始资金取 tester run 启动时账户余额，结束资金取回测结束时账户余额。

### 5. 自动化脚本优先解析中文 summary，保留机器友好的 JSON 键名

`backtest_runner.py` 将优先读取 `回测总结` 日志中的标准字段；如果目标 run 没有该日志，则仍可按现有 `ENTRY_P4` / `EXIT` 路径回退计算。策略日志中的百分比字段 SHALL 直接附带 `%` 符号，以提升人工可读性；自动化脚本解析后输出的 JSON 仍保留机器友好的英文键名，例如 `total_return_pct` 和 `pattern_match_win_rate_pct`。

## Risks / Trade-offs

- [未闭仓 entry 会拉低模式匹配胜率] → 在 summary 中同时输出 `matched_patterns` 和 `closed_trades`，让使用者能判断分母来源。
- [策略 summary 与自动化 JSON 口径漂移] → 让 `backtest_runner.py` 优先解析 `回测总结`，避免双重实现长期分叉。
- [实盘日志被回测摘要污染] → summary 仅在 tester 环境打印，live trading 不输出该日志。
- [后续新增字段破坏解析] → 使用稳定前缀 `回测总结` 和键值对格式，新增字段只能追加，不能重命名已有核心字段。
