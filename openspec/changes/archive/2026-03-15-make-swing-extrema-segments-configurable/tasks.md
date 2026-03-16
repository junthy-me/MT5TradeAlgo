## 1. Runtime Input Parsing

- [x] 1.1 Add `InpRequiredSwingExtremaSegments_Pre0P0_P0P1_P1P2_P2P3_P3P4` to `mt5/P4PatternStrategy.mq5` with the default value `"true,true,true,true,true"`.
- [x] 1.2 Implement strict parsing and validation for the 5-segment boolean string, including whitespace-tolerant `true/false` parsing and explicit init failure on invalid input.
- [x] 1.3 Add startup logging that prints the resolved `Pre0P0/P0P1/P1P2/P2P3/P3P4` segment flags.

## 2. Detection Rule Integration

- [x] 2.1 Update the `Pre0P0` precondition extrema path so the `Pre0-P0` segment extrema check only runs when the `Pre0P0` flag is enabled.
- [x] 2.2 Update the historical backbone validation so `P0P1`、`P1P2` and `P2P3` segment extrema checks each short-circuit according to their configured flag.
- [x] 2.3 Update the realtime `P3P4` trigger validation so the `P3` segment-extrema check only runs when the `P3P4` flag is enabled, while preserving that `P4` is never validated as the opposite endpoint extrema.
- [x] 2.4 Verify the new segment flags are applied identically in `LONG_ONLY`、`SHORT_ONLY` and `BOTH` modes without changing the existing directional role mapping.

## 3. Documentation And Configs

- [x] 3.1 Update `README.md` to document the new segment-extrema parameter, its 5-position order, default value, and the special `P3P4` semantics.
- [x] 3.2 Update sample `.ini` files under `mt5/configs/` to include the new parameter with the default value or an intentional example override.

## 4. Validation

- [x] 4.1 Compile `mt5/P4PatternStrategy.mq5` and confirm the build succeeds with zero errors.
- [x] 4.2 Run targeted validations covering the default all-true setting, at least one disabled historical segment, and `P3P4=false` to confirm the expected filtering changes.
