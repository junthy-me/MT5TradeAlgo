## 1. Entry Logging

- [x] 1.1 Refactor `mt5/P4PatternStrategy.mq5` so the default successful-entry log becomes a concise `P4` buy summary that highlights `P0-P4` times and prices.
- [x] 1.2 Suppress default detailed lifecycle logs for entry-blocked events, observation-window events, shared-backbone blocks, `P5/P6` activation, and routine exits while preserving trading behavior.

## 2. Chart Annotations

- [x] 2.1 Add chart lookup and object naming helpers that resolve an already open chart matching `symbol + InpTF` and build a unique annotation namespace per buy.
- [x] 2.2 Extend the managed-position annotation to draw `Pre0-P6` markers and connecting lines, including the initial buy shape and the later `P5/P6` activation shape, on the matching chart.
- [x] 2.3 Assign fixed, point-specific colors for `Pre0/P0/P1/P2/P3/P4/P5/P6` so the same point keeps the same color across trades.
- [x] 2.4 Add chart value labels for `Pre0-P0` drop, `b1`, `a`, `b2`, and `c`, plus horizontal annotations for hard and soft stop levels, without affecting order creation or position management when drawing fails.

## 3. Docs And Validation

- [x] 3.1 Update `README.md` to describe the new concise buy-point logging behavior and how to view `P0-P4` annotations on charts.
- [x] 3.2 Compile `mt5/P4PatternStrategy.mq5` and verify there are no errors or warnings after the logging and chart-annotation changes.
- [ ] 3.3 Run a targeted MT5 validation to confirm successful entries emit the new `P4` summary log and matching open charts display the correct `Pre0-P6`, value-label, and stop-level objects.
