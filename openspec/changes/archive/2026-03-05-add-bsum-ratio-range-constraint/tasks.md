## 1. Input Surface And Validation

- [ ] 1.1 在 `mt5/P4PatternStrategy.mq5` 增加运行时输入 `InpBSumValueMaxRatioOfAValue`，默认值设为 `5.0`
- [ ] 1.2 在初始化参数校验中实现 `InpBSumValueMaxRatioOfAValue >= InpBSumValueMinRatioOfAValue`，并对非法区间给出明确错误

## 2. Pattern Constraint Enforcement

- [ ] 2.1 在历史骨架/完整匹配判定中将 `b1+b2` 条件改为区间：`InpBSumValueMaxRatioOfAValue*a >= (b1+b2) >= InpBSumValueMinRatioOfAValue*a`
- [ ] 2.2 补充判定分支或日志原因，区分“低于下限”和“高于上限”两类拒绝结果

## 3. Verification And Backtest Coverage

- [ ] 3.1 增加或更新回测参数集（`.set` / `.ini`），覆盖默认 `InpBSumValueMaxRatioOfAValue=5.0` 场景
- [ ] 3.2 执行一次端到端回测验证：确认区间内样本可通过、低于下限与高于上限样本均被拒绝
