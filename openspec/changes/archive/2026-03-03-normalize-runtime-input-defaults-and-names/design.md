## Context

当前 `mt5/P4PatternStrategy.mq5` 已经把若干参数收敛到更明确的业务语义，但仍保留了一组不一致点：

- 默认值仍沿用早期调参结果，和当前期望运行方式不一致
- 两个比例参数虽然语义清晰，但命名顺序仍是 `Min...Ratio...`，和其他阈值参数的读法不统一
- 日志、规格和回测配置一旦继续引用旧名称，会让这次重命名只停留在代码表面

这次改动是一次跨运行时输入、形态检测和持仓管理的参数表面整理。它不改变现有公式，只改变默认值与公开名称，并要求仓库内所有文档化入口同时切换。

## Goals / Non-Goals

**Goals:**
- 将 `InpMaxPositionsPerSymbol` 默认值调整为 `1`
- 将 `InpLookbackBars` 默认值调整为 `300`
- 将 `InpAdjustPointMaxSpanKNumber` 默认值调整为 `10`
- 将 `InpMinP3P4DropRatioOfStructure` 统一重命名为 `InpP3P4DropMinRatioOfStructure`
- 将 `InpMinP5P6ReboundRatioOfP3P5Drop` 统一重命名为 `InpP5P6ReboundMinRatioOfP3P5Drop`
- 同步更新规格、日志字段和仓库内参数示例，避免旧名残留

**Non-Goals:**
- 不改变 `CondB`、弱止损激活或持仓上限的判断公式
- 不新增输入参数分组、枚举或兼容别名
- 不在本次变更里调整除上述三项外的其他默认值

## Decisions

### 1. 直接替换公开输入名，不保留旧名兼容层

MQL5 `input` 名称会直接暴露给参数面板、`.set/.ini` 配置和日志，继续保留旧名别名会让同一语义并存两套写法。此次改动直接替换为新名，并把仓库内示例配置同步迁移。

备选方案：
- 保留旧参数并增加镜像新参数
  否决原因：会引入优先级和冲突处理，反而放大配置歧义。

### 2. 默认值作为规格的一部分显式记录

`InpMaxPositionsPerSymbol`、`InpLookbackBars` 和 `InpAdjustPointMaxSpanKNumber` 的默认值会影响策略的初始行为，不能只停留在代码实现里。对应 capability spec 将增加默认值场景，确保后续回归能直接验证。

备选方案：
- 只在代码里改默认值，不更新 spec
  否决原因：归档后主规格无法解释默认行为变化，容易再次漂移。

### 3. 在所有引用路径上统一新名称

重命名不只发生在 `input` 声明，还包括：

- 输入校验与日志文案
- CondB 与弱止损激活相关判断
- OpenSpec delta spec
- 仓库内回测配置与说明

这样可以保证用户在任意入口看到的都是同一套名称。

备选方案：
- 只改代码标识符，保留旧日志和文档
  否决原因：用户最常接触的是输入面板和日志，局部替换没有实际价值。

## Risks / Trade-offs

- [现有 `.ini` / `.set` 仍使用旧参数名，加载后会失效或回退默认值] -> Mitigation: 同步扫描并更新仓库内配置样例，任务中单独列出验证项。
- [将单品种最大持仓默认值改为 `1` 会降低未显式配置场景下的下单频率] -> Mitigation: 在 proposal 和 spec 中将其标记为 breaking default change。
- [将回看 bars 与单段跨度默认值提高后，扫描成本可能上升] -> Mitigation: 仅调整默认值，不改算法；回归时确认策略仍能正常初始化和运行。

## Migration Plan

1. 先更新 OpenSpec proposal、design 和 delta specs，明确新默认值与新名称。
2. 在 EA 主文件中替换 `input` 名称、默认值及其全部引用。
3. 更新仓库内回测配置或示例参数文件中的旧字段名。
4. 通过搜索确认仓库内不再残留被替换的旧参数名。

## Open Questions

- 无。当前需求边界明确，且不要求对旧配置提供兼容层。
