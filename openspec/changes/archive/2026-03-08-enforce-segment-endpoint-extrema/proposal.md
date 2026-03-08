## Why

当前模式匹配只校验 `P0/P1/P2/P3` 这些端点之间的数值关系，没有校验 `Pre0-P0`、`P0-P1`、`P1-P2`、`P2-P3` 线段内部的极值归属，导致端点并不是真正段内最高/最低点的结构也可能被当成有效模式。这个缺口已经在实际图表回放中暴露出来，需要把“端点就是该段极值”正式提升为检测规则。

## What Changes

- 为历史骨架检测新增线段端点极值约束：`P0-P1` 段内 `P0` 必须达到最低点、`P1` 必须达到最高点；`P1-P2`、`P2-P3` 按相同思路约束。
- 为前置下跌先决条件新增 `Pre0-P0` 线段极值约束：`Pre0` 必须达到该段最高点，`P0` 必须达到该段最低点。
- 明确默认口径为“允许并列极值”，即端点只需要达到该段极值，不要求是唯一极值。
- **BREAKING**：原本仅靠端点相对大小关系即可通过的部分历史候选骨架，现在会因为线段内部存在更高/更低点而被拒绝。

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mt5-kline-pattern-detection`: 历史骨架与前置下跌检测需要增加“线段端点必须达到整段极值”的要求，并明确默认允许并列极值。

## Impact

- Affected code: `mt5/P4PatternStrategy.mq5`
- Affected systems: 历史模式候选筛选、`Pre0` 先决条件判定、回测/实盘匹配结果数量
- No external dependencies or API changes
