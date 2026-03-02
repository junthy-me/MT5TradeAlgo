## 1. Runtime State And Inputs

- [x] 1.1 Add `InpProfitObservationBars` input validation and default configuration in `P4PatternStrategy.mq5`.
- [x] 1.2 Extend `SymbolRuntimeState` with the symbol-level profit observation window state needed to remember the latest `profit_target` exit bar.
- [x] 1.3 Reset and maintain the new observation window state alongside existing symbol runtime state initialization paths.

## 2. Observation Window Enforcement

- [x] 2.1 Record the current bar open time when a managed position closes successfully with reason `profit_target`.
- [x] 2.2 Add a `ProcessSymbol()` gate that blocks new buy entries while the current bar remains inside the configured post-profit observation window.
- [x] 2.3 Add dedicated logs for observation-window entry blocks so they are distinguishable from `P4` bar locks, backbone success locks, and position-limit blocks.

## 3. Verification

- [x] 3.1 Compile `P4PatternStrategy.mq5` and confirm there are no errors or warnings.
- [ ] 3.2 Verify that a `profit_target` close immediately blocks re-entry on the remainder of the exit bar and the next configured bars.
- [ ] 3.3 Verify that `hard_stop` and `soft_stop` closes do not start the observation window.
- [ ] 3.4 Verify that setting `InpProfitObservationBars = 0` disables the observation window and allows immediate post-profit re-entry.
