## 1. Runtime Inputs And State

- [x] 1.1 Remove `InpProfitC`, add `InpAdjustPointMinSpanKNumber`, and update default/input validation for the new min/max span settings in `mt5/P4PatternStrategy.mq5`.
- [x] 1.2 Update pattern and position runtime state so `profitPrice` can represent an inactive pre-`P5/P6` state without breaking logs or lifecycle handling.

## 2. Span Semantics

- [x] 2.1 Refactor `pointSpans[0..3]` to use the new “middle-bar count” formula for `P0->P1`, `P1->P2`, `P2->P3`, and `P3->P4`.
- [x] 2.2 Apply `InpAdjustPointMinSpanKNumber` and `InpAdjustPointMaxSpanKNumber` consistently in cached backbone search, legacy exact search, and final `condF` validation.
- [x] 2.3 Verify `P1-P2`’s existing total-bar-count rule remains intact alongside the new span semantics.

## 3. Deferred Profit Activation

- [x] 3.1 Remove initial `profitPrice` generation at `P4` entry and update pre-entry stale-signal filtering so it only checks profit targets when a profit target is active.
- [x] 3.2 Update open-position management so `profit_target` can trigger only after the first qualifying `P5/P6` activation, while `hard_stop` remains active from entry.
- [x] 3.3 Keep the first qualifying `P5/P6` activation path as the single place that simultaneously sets `soft_loss_price` and `profit_price = selectedP5 + InpP5AnchoredProfitC * (a+b1+b2)`, then freezes both values.

## 4. Specs, Docs, And Verification

- [x] 4.1 Update `README.md` and any related runtime/backtest config references to describe the removed initial profit target and the new min/max span semantics.
- [x] 4.2 Compile `mt5/P4PatternStrategy.mq5` and verify there are no errors or warnings after the input, span, and trade-management refactor.
- [ ] 4.3 Run targeted validation or backtests for inactive pre-`P5/P6` profit handling, first-activation-only profit setting, and the new middle-bar span rule across cached and exact search paths.
