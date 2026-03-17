## 1. Update PriorMove Threshold Calculation

- [x] 1.1 In `mt5/P4PatternStrategy.mq5`, change the `PriorMove` structure denominator from `a + b1` to `a + b1 + b2`.
- [x] 1.2 Verify that the updated denominator is used consistently for both `LONG_ONLY` and `SHORT_ONLY` `PriorMove` threshold checks without changing `Pre0` selection or direction logic.

## 2. Sync Specifications And Documentation

- [x] 2.1 Update the main `mt5-pattern-preconditions` spec so the `PriorMove` ratio formulas use `a + b1 + b2`.
- [x] 2.2 Update `README.md` anywhere the `PriorMove` structure denominator or example formula still references `a + b1`.

## 3. Static Verification

- [x] 3.1 Review the code and docs to confirm all `PriorMove` denominator references now use `a + b1 + b2`.
- [x] 3.2 Confirm the change does not alter unrelated `PriorMove` behavior such as lookback range, minimum bar gap, endpoint-extrema rules, or strongest-`Pre0` selection.
