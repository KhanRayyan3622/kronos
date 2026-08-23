# Tracker: input_debouncer conversion

## Assumptions

## Limitations

## Deviations from default FEV configuration

## Deviations from the defined process

## Suggested subsequent logic optimizations

## Potential issues for user review

## Process/instruction improvement suggestions

## Preparation notes

- `prepared.sv` required no modifications from `orig.sv`: no external includes/libraries,
  no latches (design is fully flip-flop-based on posedge clk), no tri-states, and no
  clock gating/enable inputs.
- Note: the per-bit `sync` always_ff block (line 39-41 of `orig.sv`) and the `line`/`read[i]`
  state have no reset. This is inherent to the original design (only `timer` is reset via
  `rstz`). Per the process, no special reset handling is needed for FEV since every state
  element is a cutpoint.
