## 1. Spec And Parameter Surface

- [x] 1.1 更新 change specs，写明 a 的最小空间/时间约束与 bSum 相对 a 的最小比例约束
- [x] 1.2 在 EA 输入参数中新增 `InpP1P2AValueSpaceMinPriceLimit`、`InpP1P2AValueTimeMinKNumberLimit`、`InpBSumValueMinRatioOfAValue` 及默认值，并补充输入校验

## 2. Historical Backbone Filtering

- [x] 2.1 在 `BuildHistoricalBackbone()` 中实现 `a >= InpP1P2AValueSpaceMinPriceLimit`
- [x] 2.2 在 `BuildHistoricalBackbone()` 中按“包含 P1/P2 本身的 K 线数量”实现 `P1-P2` 最小时间约束
- [x] 2.3 在 `BuildHistoricalBackbone()` 中实现 `(b1+b2) >= InpBSumValueMinRatioOfAValue * a`

## 3. Visibility And Validation

- [x] 3.1 更新匹配日志或调试输出，保留解释新约束所需的 `a`、`b1`、`b2` 与 `P1-P2` span 字段
- [x] 3.2 更新回测配置或验证说明，覆盖三个新参数的默认值与边界行为
