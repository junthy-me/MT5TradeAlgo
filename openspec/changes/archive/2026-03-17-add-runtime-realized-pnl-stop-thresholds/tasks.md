## 1. Add Runtime Stop Inputs And State

- [x] 1.1 Add `InpMaxProfitStopMoney` and `InpMaxLossStopMoney` to `mt5/P4PatternStrategy.mq5`, with default `0` and validation that disallows negative values.
- [x] 1.2 Add runtime state for gross profit, gross loss, net realized money, stop reason, and one-time stop-summary emission.

## 2. Wire Realized PnL Threshold Checks Into Trade Management

- [x] 2.1 Update the close-trade path so the strategy records this EA's realized PnL in account currency when a managed position is successfully closed.
- [x] 2.2 Add threshold evaluation so reaching the configured profit or loss stop marks the EA as stopped for new entries.
- [x] 2.3 Gate the new-entry path so stopped state blocks future managed entries while existing positions continue to be managed normally.

## 3. Add Runtime Stop Logging And Documentation

- [x] 3.1 Add one-time runtime stop reason and summary logs that include the stop cause and cumulative realized-money metrics.
- [x] 3.2 Update `openspec/specs/mt5-strategy-runtime-controls/spec.md`, `openspec/specs/mt5-pattern-trade-management/spec.md`, and `README.md` so the new inputs and runtime stop behavior are documented consistently.

## 4. Static Verification

- [x] 4.1 Review the implementation to confirm only closed realized PnL affects the stop thresholds and that open positions are still managed after stop triggers.
- [x] 4.2 Run targeted searches to confirm the new runtime stop inputs, stop reasons, and summary fields are referenced consistently across code and docs.
