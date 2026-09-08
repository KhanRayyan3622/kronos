# Tracker: kronos_counter64 conversion

## Assumptions

- `clk`/`rstz` is a single, free-running clock domain with an async, negatively-asserted
  reset — standard, no special handling anticipated.
- No clock gating/enabling, no latches, no tri-states, and no external file dependencies
  (tick-includes) in `orig.sv`; `prepared.sv` is an unmodified copy of `orig.sv`.
- Module has two parameters (`EN_COUNTERS`, `EN_COUNTERS64B`) that gate `generate`
  blocks controlling `count`/`count_vld` output logic — to be addressed in the
  "Parameters" task.

## Limitations

(none yet)

## Deviations from default FEV configuration

(none yet)

## Suggested subsequent logic optimizations

(none yet)

## Potential issues for user review

(none yet)

## Process notes / difficulties

(none yet)
