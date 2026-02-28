## 1. 条件与参数重构

- [x] 1.1 删除 `InpCondBYMin`、`InpCondBYMax`、`InpCondDM`、`InpHardLossC`、`NoiseFilter_aValueCompBuyPricePercent`、`NoiseFilter_maxBValueCompAValueProd`
- [x] 1.2 新增 `InpRatioC` 和 `NoiseFilter_bSumValueCompBuyPricePercent`，并将 `InpProfitC` 默认值调整为 `1.8`
- [x] 1.3 将 `CondB` 改为 `r1 >= InpRatioC`，删除 `CondD`
- [x] 1.4 删除 `CondG`，并将 `CondH` 改为基于 `((b1+b2)/buyPrice)*100` 的过滤规则

## 2. 风控与日志调整

- [x] 2.1 将强止损价改为 `P0` 点位值，并将止盈价改为 `entryPrice + InpProfitC * (b1+b2+a)`
- [x] 2.2 调整入场前风控检查与持仓管理，使其使用新的强止损/止盈价格
- [x] 2.3 更新入场日志与过滤失败日志，保留 `a` 调试信息并补充新的 `CondB` 与 `CondH` 明细

## 3. 验证

- [x] 3.1 编译 EA，确认参数删除与条件重构没有引入构建错误
- [x] 3.2 运行回测，验证新条件与新风控价格推导符合预期
