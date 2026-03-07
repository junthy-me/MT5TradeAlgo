## 1. Runtime State And Inputs

- [x] 1.1 Add `InpStopObservationBars` and `InpP5AnchoredProfitC` to `mt5/P4PatternStrategy.mq5`, including input validation and default values.
- [x] 1.2 Extend symbol and position runtime state to track stop-observation timing and first `P5/P6` activation freeze data.

## 2. Entry Gating

- [x] 2.1 Add stop-observation window evaluation and logging parallel to the existing profit-observation gate.
- [x] 2.2 Update entry gating so any active profit-observation or stop-observation window blocks new entries for the same `symbol + timeframe`.

## 3. Post-Entry Trade Management

- [x] 3.1 Refactor the `P5/P6` activation path so the first qualifying activation evaluates all currently qualifying `P5` candidates and selects the lowest-price `P5`.
- [x] 3.2 On first `P5/P6` activation, set both `soft_loss_price = InpSoftLossC * selectedP5` and `profit_price = selectedP5 + InpP5AnchoredProfitC * (a+b1+b2)`, then freeze them for the rest of the position.
- [x] 3.3 Record stop-observation state when `hard_stop` or `soft_stop` closes a managed position, while preserving the existing post-profit observation behavior.

## 4. Verification

- [x] 4.1 Update logs so blocked-entry output distinguishes profit-observation and stop-observation causes, and activation output shows the selected `P5` and rewritten profit target.
- [x] 4.2 Compile `mt5/P4PatternStrategy.mq5` and verify there are no errors or warnings.
- [x] 4.3 Run backtests or targeted validation for dual observation windows, first-activation `selectedP5` freezing, and `P5`-anchored profit exits.
