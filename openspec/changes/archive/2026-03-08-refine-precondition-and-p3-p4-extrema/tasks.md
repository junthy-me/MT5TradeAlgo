## 1. Runtime Inputs And Preconditions

- [x] 1.1 Add `InpPreCondEnable` with default `false`, validation, and reset semantics for `Pre0` snapshot fields when disabled.
- [x] 1.2 Update prior-decline precondition evaluation to use `InpPreCondPriorDeclineMinDropRatioOfStructure * (a + b1)` while preserving the existing lookback, minimum-bar-gap, and endpoint-extrema selection rules.
- [x] 1.3 Ensure the pattern precondition pipeline skips `Pre0` filtering entirely when `InpPreCondEnable=false` and still allows the backbone candidate to proceed.

## 2. Realtime Pattern Validation And Annotations

- [x] 2.1 Add a `P3-P4` endpoint-extrema validation step in realtime trigger evaluation so `P3` must remain the segment maximum, allowing tied highs.
- [x] 2.2 Update chart annotation behavior so `Pre0` point, `Pre0-P0` line, and `pre0_drop` label are created only when the snapshot contains an enabled and matched `Pre0`, while `P0-P4` and later points continue to draw normally.
- [x] 2.3 Refresh README wording for the new precondition formula, the `InpPreCondEnable` default/behavior, and the `P3-P4` extremum rule.

## 3. Verification

- [x] 3.1 Compile `mt5/P4PatternStrategy.mq5` and confirm there are no build errors or warnings.
- [ ] 3.2 Run a targeted validation or log-backed replay covering both `InpPreCondEnable=false` and `InpPreCondEnable=true` to verify `Pre0` gating and the new prior-decline threshold.
- [ ] 3.3 Capture evidence that a candidate with an internal higher high on `P3-P4` is rejected while a tied-high `P3-P4` segment still passes.
