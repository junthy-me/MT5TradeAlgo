## REMOVED Requirements

### Requirement: 强止损与止盈价格不得再由 a 单独推导
**Reason**: 该 requirement 描述的是交易价格推导与持仓管理规则，应由 `mt5-pattern-trade-management` 作为唯一权威来源维护。继续在 `mt5-pattern-a-simplification` 中单独复制完整公式，会让同一业务规则出现多个 spec owner，并再次造成文本漂移。
**Migration**: 将该 requirement 的权威定义迁移到 `mt5-pattern-trade-management`。后续若调整入场价、强止损、止盈或弱止损公式，只修改 `mt5-pattern-trade-management`，而不再在 `mt5-pattern-a-simplification` 中重复维护。
