## 1. SoftLoss Rule

- [x] 1.1 将 `UpdateSoftStopState()` 中的弱止损激活条件替换为 `e >= InpSoftLossN * (c + d)`
- [x] 1.2 将 `InpSoftLossN` 的默认值更新为 `0.65`
- [x] 1.3 保持 `soft_loss_price = softLossC * Price_P5` 不变

## 2. Verification

- [x] 2.1 编译 EA，确认新的弱止损激活条件没有引入构建错误
- [ ] 2.2 在回测中验证弱止损按 `e >= InpSoftLossN * (c + d)` 激活
- [ ] 2.3 验证默认参数 `InpSoftLossN = 0.65` 在未显式覆盖时生效
