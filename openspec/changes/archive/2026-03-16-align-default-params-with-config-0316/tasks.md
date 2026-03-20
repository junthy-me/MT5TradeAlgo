## 1. Update Runtime Defaults In Code

- [x] 1.1 In `mt5/P4PatternStrategy.mq5`, update the default input values that differ from `config_0316.png`, including `InpTF`, `InpLookbackBars`, `InpAdjustPointMinSpanKNumber`, `InpAdjustPointMaxSpanKNumber`, `InpP1P2AValueSpaceMinPriceLimit`, `InpP1P2AValueTimeMinKNumberLimit`, `InpBSumValueMaxRatioOfAValue`, `InpPreCondEnable`, `InpPreCondPriorMoveLookbackBars`, `InpPreCondPriorMoveMinRatioOfStructure`, `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4`, and `InpP5AnchoredProfitC`.
- [x] 1.2 Verify that parameters not changed in `config_0316.png` keep their existing defaults and that no input validation logic is altered.

## 2. Sync Specs And Documentation

- [x] 2.1 Update `openspec/specs/mt5-strategy-runtime-controls/spec.md` so the documented runtime defaults match the new baseline.
- [x] 2.2 Update the default-value references in `README.md`, especially the parameter table and any prose that still mentions the old defaults.

## 3. Static Verification

- [x] 3.1 Review the changed defaults against `/Users/junthy/Desktop/config_0316.png` and confirm each intended value is reflected in the code and docs.
- [x] 3.2 Run a targeted text search to confirm the old default values for the changed parameters no longer appear in the runtime-default documentation by mistake.
