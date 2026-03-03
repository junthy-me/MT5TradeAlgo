## 1. Specs And Parameter Surface

- [x] 1.1 更新变更 spec，移除 `InpMaxAdjustPointSpan` 和 `NoiseFilter_bSumValueCompBuyPricePercent` 的 requirement，并写入新的参数名称
- [x] 1.2 更新 EA 输入参数、默认值和输入校验，完成 `InpRatioC` 与 `InpSoftLossN` 的重命名，并将 `InpProfitC` 默认值改为 `0.6`

## 2. Matching And Entry Logic

- [x] 2.1 删除相邻线段数量过滤相关状态与判断，仅保留单段跨度限制
- [x] 2.2 删除 `b1+b2` 买价百分比噪声过滤及相关日志字段，确保入场流程不再因该阈值阻止发单

## 3. Verification And Config Updates

- [x] 3.1 更新日志与 exact-compare 调试输出，移除废弃字段并使用新参数名
- [x] 3.2 更新仓库中的回测 `.ini` 参数名与默认值，移除废弃输入项
