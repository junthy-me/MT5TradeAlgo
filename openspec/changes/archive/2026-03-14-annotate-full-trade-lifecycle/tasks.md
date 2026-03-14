## 1. Annotation Color Contract

- [x] 1.1 Add or update a single point-color helper in `mt5/P4PatternStrategy.mq5` so `Pre0`、`P0`、`P1`、`P2`、`P3`、`P4`、`P5`、`P6` use the fixed user-specified colors and unknown labels fall back to a neutral default.
- [x] 1.2 Update point-drawing helpers to consistently consume the shared point-color mapping so the same point label keeps the same color across all trades and directions.

## 2. Entry-Time Lifecycle Annotation Expansion

- [x] 2.1 Extend the entry-stage chart annotation path to always draw all currently known lifecycle points (`Pre0/P0/P1/P2/P3/P4`) and their connecting segments within the trade’s existing object namespace.
- [x] 2.2 Extend entry-stage annotation text/objects to display `a`、`b1`、`b2`、`c` and the hard-stop line without changing any trading or risk logic.

## 3. Post-Activation Lifecycle Annotation Expansion

- [x] 3.1 Extend the first `P5/P6` activation annotation path to append `P5/P6` point markers, `P4-P5-P6` connecting segments, and any missing lifecycle point labels in the same trade namespace.
- [x] 3.2 Extend post-activation annotation text/objects to display `d`、`e` and the soft-stop line while preserving the existing lifecycle update flow and avoiding changes to trade management behavior.

## 4. Verification

- [x] 4.1 Compile `mt5/P4PatternStrategy.mq5` and confirm the annotation-only change builds with no new warnings or errors.
- [x] 4.2 Run a targeted MT5 backtest and confirm chart objects show the fixed point colors, full lifecycle points, `a/b1/b2/c/d/e`, and both hard/soft stop annotations for at least one completed trade lifecycle.
