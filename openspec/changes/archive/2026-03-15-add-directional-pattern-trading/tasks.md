## 1. Runtime Inputs And Direction Abstractions

- [x] 1.1 Add `InpTradeDirectionMode` to `mt5/P4PatternStrategy.mq5`, validate the allowed values `LONG_ONLY / SHORT_ONLY / BOTH`, and keep the default behavior equivalent to `LONG_ONLY`.
- [x] 1.2 Rename the existing direction-biased runtime inputs and related snapshot/state fields from `drop/decline` terminology to the new neutral `move` terminology across the strategy code.
- [x] 1.3 Introduce a reusable direction model in the strategy runtime state and pattern snapshot so detection, entry, management, logging, and annotations can all read the same `direction` value.
- [x] 1.4 Add direction-aware helper functions for point role pricing, realtime entry reference price selection, managed exit comparison price selection, and segment endpoint-extrema checks.

## 2. Pattern Detection And Preconditions

- [x] 2.1 Refactor historical backbone construction and realtime `P4` evaluation so the same search pipeline can produce both long patterns and mirrored short patterns using the shared direction abstraction.
- [x] 2.2 Update candidate ranking so identical-`P3` matches choose the more favorable `P4` by direction: lower `P4` for long, higher `P4` for short.
- [x] 2.3 Replace the prior-decline precondition implementation with the direction-aware prior-move rule, including mirrored `Pre0` search and extrema validation for short setups.
- [x] 2.4 Ensure cached search, legacy exact search, and exact-compare diagnostics all remain consistent after the direction-aware detection changes.

## 3. Trading, Logging, And Chart Annotations

- [x] 3.1 Update entry execution to submit buy orders for long matches and sell orders for short matches while preserving shared `P4` bar locks, shared backbone success locks, and shared symbol-level position limits.
- [x] 3.2 Refactor managed-position lifecycle logic so hard stop, soft stop, profit activation, and profit/stop exits use the correct mirrored formulas and bid/ask comparison side for each direction.
- [x] 3.3 Mirror the intrabar `P5/P6` tracking so long positions still pick the lowest qualified `P5` and short positions pick the highest qualified `P5`, with the corresponding mirrored profit target formula.
- [x] 3.4 Extend entry logs, activation logs, annotation namespaces, and `P4` highlight markers to include explicit direction and render long/short entries differently on charts.

## 4. Docs, Configs, And Verification

- [x] 4.1 Update `README.md` to describe directional pattern matching, the new `InpTradeDirectionMode` input, the neutral move terminology, and the mirrored long/short trade-management rules.
- [x] 4.2 Rename and refresh affected `mt5/configs/*.ini` examples so they use the new neutral input names and include at least one validation profile for short-only or both-directions behavior.
- [x] 4.3 Compile `mt5/P4PatternStrategy.mq5` and confirm there are no errors or warnings after the directional refactor.
- [x] 4.4 Run targeted MT5 validation or backtest scenarios covering `LONG_ONLY`, `SHORT_ONLY`, and `BOTH`, with emphasis on shared gating behavior, mirrored `P5/P6` activation, and updated logs/annotations.
