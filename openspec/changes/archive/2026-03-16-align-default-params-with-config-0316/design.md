## Context

当前 EA 默认输入值分散在 `mt5/P4PatternStrategy.mq5` 和 `README.md` 参数表中，但实际使用基线已经切换到 `/Users/junthy/Desktop/config_0316.png` 所展示的配置。新挂载 EA、未导入 ini 的回测、以及仅依赖 README 参数表复现环境时，都会继续落到旧默认值上。

这次改动的目标是把“默认值”统一到这张配置快照，而不是改变参数名、校验规则或交易逻辑。截图中未变化的参数继续保持现有默认值；截图中已变化的参数以截图为准。

## Goals / Non-Goals

**Goals:**
- 将源码默认输入值对齐到 `config_0316.png` 中可见配置。
- 将 README 参数表和 runtime-controls spec 中涉及默认值的描述同步到同一口径。
- 让未显式导入 ini 的运行环境直接落到当前基线配置。

**Non-Goals:**
- 不修改参数名、输入校验、交易逻辑或公式。
- 不把截图视为新的独立配置文件格式；仍然以源码默认值为唯一默认来源。
- 不覆盖截图中未展示或未变化的参数。

## Decisions

### 决策：只调整与截图相比发生变化的默认值

从当前源码与截图对比，默认值需要调整的参数包括：
- `InpTF`: `PERIOD_M10` -> `PERIOD_M30`
- `InpLookbackBars`: `300` -> `150`
- `InpAdjustPointMinSpanKNumber`: `3` -> `0`
- `InpAdjustPointMaxSpanKNumber`: `35` -> `20`
- `InpP1P2AValueSpaceMinPriceLimit`: `0.0` -> `5.0`
- `InpP1P2AValueTimeMinKNumberLimit`: `1` -> `5`
- `InpBSumValueMaxRatioOfAValue`: `10.0` -> `5.0`
- `InpPreCondEnable`: `false` -> `true`
- `InpPreCondPriorMoveLookbackBars`: `30` -> `20`
- `InpPreCondPriorMoveMinRatioOfStructure`: `0.45` -> `0.7`
- `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4`: `"true,true,true,true,true"` -> `"false,false,false,false,false"`
- `InpP5AnchoredProfitC`: `1.0` -> `2.0`

其他截图可见参数如果与源码当前值一致，则不做改动。

备选方案：
- 只更新 README，不改源码默认值：无法解决未导入 ini 时的行为偏差。
- 新增单独 baseline ini 替代源码默认值：能保留旧默认，但不满足“默认参数改为一致”的请求。

### 决策：spec 只修改 runtime-controls capability

默认值属于运行时输入契约，因此变更集中落在 `mt5-strategy-runtime-controls`。其他能力如 preconditions 或 trade-management 的公式和行为不变，不需要额外改 spec。

## Risks / Trade-offs

- [默认配置切换会直接改变未显式传参时的行为] → 在 spec 和 README 中明确这是新的基线默认值，并保留参数名不变，便于通过 ini 覆盖。
- [截图驱动的默认值可能遗漏某些未显示参数] → 仅修改截图中明确可见且与源码不同的参数，其余保持现状。
- [源码、README、spec 再次漂移] → 实现时同时修改三处，并通过全文搜索核对关键默认值。
