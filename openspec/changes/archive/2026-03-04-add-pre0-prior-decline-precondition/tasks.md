## 1. Parameter Surface

- [x] 1.1 在 [mt5/P4PatternStrategy.mq5](/Users/junthy/Work/MT5TradeAlgo/mt5/P4PatternStrategy.mq5) 中新增 `InpPreCondPriorDeclineLookbackBars`、`InpPreCondPriorDeclineMinDropRatioOfStructure`、`InpPreCondPriorDeclineMinBarsBetweenPre0AndP0` 及默认值
- [x] 1.2 为上述 3 个输入参数补充运行时校验，并在需要的状态结构或日志字段中预留 `Pre0` 命中信息

## 2. Precondition Engine

- [x] 2.1 在历史骨架阶段引入统一的 pattern preconditions 入口，而不是把 `PriorDecline` 直接内联到主判断条件
- [x] 2.2 实现 `PriorDecline` 规则：在 `P0` 之前 `lookback` 窗口内搜索候选 `Pre0`，校验最小跌幅比例与最小 bar 间隔
- [x] 2.3 将 precondition 结果接入当前 `P0-P4` / 完整匹配有效性判定，确保任一启用先决条件失败时直接拒绝候选

## 3. Visibility And Verification

- [x] 3.1 更新日志或调试输出，使其能解释 `PriorDecline` 是否命中，以及命中的 `Pre0` 关键信息
- [x] 3.2 更新仓库中的回测配置或验证说明，覆盖 3 个新参数的默认值与边界行为
