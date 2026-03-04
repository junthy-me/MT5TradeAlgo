# Verification

- Repository scan found no backtest parameter files to update: `rg --files -g '*.ini' -g '*.set' .`
- Runtime defaults implemented in [mt5/P4PatternStrategy.mq5](/Users/junthy/Work/MT5TradeAlgo/mt5/P4PatternStrategy.mq5):
  - `InpPreCondPriorDeclineLookbackBars = 20`
  - `InpPreCondPriorDeclineMinDropRatioOfStructure = 0.7`
  - `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0 = 0`
- Boundary handling implemented through `ValidateInputs()`:
  - `lookback >= 1`
  - `min drop ratio >= 0`
  - `min bars between >= 0`
- `InpPreCondPriorDeclineMinBarsBetweenPre0AndP0` counts only bars strictly between `Pre0` and `P0`, using `p0Index - pre0Index - 1`
- MetaEditor compile verified on `2026.03.04 10:51:42`: `0 errors, 0 warnings`
