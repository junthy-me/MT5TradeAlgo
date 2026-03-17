## 1. Reshape Runtime Stop State

- [x] 1.1 Move runtime stop accounting from a single global state to per-symbol runtime state in `mt5/P4PatternStrategy.mq5`.
- [x] 1.2 Add helpers to compute each symbol's realized money, floating money, total net money, and stopped status.

## 2. Rewire Stop Trigger And Flattening

- [x] 2.1 Update the close-trade path so realized-money accumulation is recorded against the correct symbol runtime state.
- [x] 2.2 Add per-symbol threshold evaluation that includes floating PnL and triggers a stop when total net money reaches either configured threshold.
- [x] 2.3 When a symbol stop triggers, immediately attempt to close all managed open positions for that symbol and block future managed entries for that symbol during the current run.

## 3. Update Logs And Documentation

- [x] 3.1 Change runtime stop logs to be symbol-scoped and include realized, floating, and total net money fields.
- [x] 3.2 Update `openspec/specs/mt5-strategy-runtime-controls/spec.md`, `openspec/specs/mt5-pattern-trade-management/spec.md`, and `README.md` to match the new per-symbol floating-PnL stop semantics.

## 4. Static Verification

- [x] 4.1 Review the implementation to confirm stop checks now include floating PnL and flatten only the triggered symbol's managed positions.
- [x] 4.2 Run targeted searches to confirm the new stop semantics are referenced consistently across code and docs.
