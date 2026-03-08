## 1. Tracking Model

- [x] 1.1 Extend managed position state to retain post-entry intrabar tracking data needed to derive ordered `P5/P6` events
- [x] 1.2 Replace the current closed-bar `P5/P6` candidate scan entry point with a tick-sequenced evaluation path

## 2. Activation Logic

- [x] 2.1 Implement `P5` detection so only ticks strictly after `tP4` can qualify, even on the same bar
- [x] 2.2 Implement `P6` detection so only ticks strictly after `tP5` can qualify, even on the same bar
- [x] 2.3 Preserve first-activation freezing semantics while selecting the lowest valid `P5` among observed qualifying candidates

## 3. Output Alignment

- [x] 3.1 Update `P5/P6` snapshot writes, chart annotations, and logs to use tick event times instead of closed-bar start times
- [x] 3.2 Verify that same-bar `P4/P5/P6` scenarios remain visually distinguishable in chart annotations

## 4. Validation

- [x] 4.1 Run a targeted backtest covering a same-bar `P4/P5/P6` activation case and confirm `tP4 < tP5 < tP6` in logs
- [x] 4.2 Run a regression case where the bar low occurs before entry and confirm it is not misclassified as `P5`
- [x] 4.3 Run a regression case where the bar high occurs before `P5` and confirm it is not misclassified as `P6`
