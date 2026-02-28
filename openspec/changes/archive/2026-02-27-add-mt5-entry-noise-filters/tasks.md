## 1. 参数与状态扩展

- [x] 1.1 在 EA 输入参数中新增 `NoiseFilter_aValueCompBuyPricePercent` 和 `NoiseFilter_maxBValueCompAValueProd`，并设置默认值 `1` 与 `1.5`
- [x] 1.2 在模式快照或交易决策结构中新增 CondG、CondH 以及其原始计算值字段，包括 `a / buy_price * 100` 和 `max(b1, b2)`

## 2. 入场噪声过滤实现

- [x] 2.1 在实际准备提交买单前引入 CondG 校验，按实际买价计算 `a / buy_price * 100`
- [x] 2.2 在实际准备提交买单前引入 CondH 校验，按 `max(b1, b2) >= NoiseFilter_maxBValueCompAValueProd * a` 执行过滤
- [x] 2.3 调整发单前总校验逻辑，使 CondA 到 CondF 与新增两条噪声过滤条件必须全部通过才允许提交买单

## 3. 日志与验证

- [x] 3.1 增加噪声过滤日志，输出买价、`a / buy_price * 100`、`max(b1, b2)`、阈值和失败原因
- [ ] 3.2 编译 EA 并确认新增参数、条件字段和入场过滤逻辑没有引入构建错误
- [ ] 3.3 在 Strategy Tester 中验证“模式匹配成功但被噪声过滤阻止下单”和“全部条件通过后正常下单”两类场景
