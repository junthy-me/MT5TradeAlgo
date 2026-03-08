## 1. Segment Extremum Checks

- [x] 1.1 Add reusable inclusive segment-scan helpers in `mt5/P4PatternStrategy.mq5` that can verify whether a segment start/end pair reaches the required high/low extrema while allowing tied extrema.
- [x] 1.2 Apply the new segment-extremum helpers to historical backbone validation so `P0-P1`, `P1-P2`, and `P2-P3` must satisfy the segment endpoint extremum rules before a backbone is accepted.
- [x] 1.3 Apply the same extremum validation to the `Pre0-P0` prior-decline precondition so `Pre0` is segment-high and `P0` is segment-low before the precondition can pass.

## 2. Detection Consistency

- [x] 2.1 Ensure the new extremum validation is shared by both cached history-candidate generation and exact/legacy comparison paths, so enabling compare does not introduce semantic drift.
- [x] 2.2 Review any affected logs or diagnostic output to make sure rejected candidates remain explainable during compare/debug workflows.

## 3. Verification

- [x] 3.1 Compile `mt5/P4PatternStrategy.mq5` and verify there are no errors or warnings.
- [ ] 3.2 Run a targeted validation or compare flow that proves a previously unreasonable `Pre0/P0/P1/P2/P3/P4` shape is now rejected.
- [x] 3.3 Update README or acceptance notes if needed to document that segment endpoints must now reach the full segment extrema and that tied extrema are allowed.
