## 1. EA Input Surface

- [x] 1.1 更新 [mt5/P4PatternStrategy.mq5](/Users/junthy/Work/MT5TradeAlgo/mt5/P4PatternStrategy.mq5) 中的 `input` 声明与默认值，将 `InpMaxPositionsPerSymbol=1`、`InpLookbackBars=300`、`InpAdjustPointMaxSpanKNumber=10`，并把两个比例参数切换为新名称
- [x] 1.2 替换主策略文件中全部旧参数引用、输入校验和相关日志字段，确保 `CondB` 与弱止损激活逻辑都改用新变量名

## 2. Config And Spec Sync

- [x] 2.1 更新仓库内受影响的回测 `.ini` / `.set` 参数文件，替换 `InpMinP3P4DropRatioOfStructure` 与 `InpMinP5P6ReboundRatioOfP3P5Drop`
- [x] 2.2 检查并清理仓库中对旧参数名以及旧默认值 `10`、`120`、`5` 的过期说明或示例，确保与本次 OpenSpec 变更一致

## 3. Verification

- [x] 3.1 运行针对性的仓库搜索，确认实现与配置中不再残留 `InpMinP3P4DropRatioOfStructure`、`InpMinP5P6ReboundRatioOfP3P5Drop` 等被替换名称
- [x] 3.2 完成一次 EA 编译或等效验证，确认参数重命名与默认值调整后策略仍可正常通过校验
