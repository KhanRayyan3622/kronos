# Tracker: kronos_counter64 conversion

## Assumptions

- `clk`/`rstz` is a single, free-running clock domain with an async, negatively-asserted
  reset — standard, no special handling anticipated.
- No clock gating/enabling, no latches, no tri-states, and no external file dependencies
  (tick-includes) in `orig.sv`; `prepared.sv` is an unmodified copy of `orig.sv`.
- Module has two parameters (`EN_COUNTERS`, `EN_COUNTERS64B`) that gate `generate`
  blocks controlling `count`/`count_vld` output logic.

## Parameter sets tested (full FEV)

- Default (`EN_COUNTERS=1`, `EN_COUNTERS64B=1`): `fev_full.eqy` — full 64b staggered
  counter output logic.
- `EN_COUNTERS=0`: `fev_full_EN_COUNTERS_0.eqy` — outputs forced to constants
  (`count='0`, `count_vld=1`); this also makes the value of `EN_COUNTERS64B`
  irrelevant, so it is left at its default (1).
- `EN_COUNTERS64B=0` (with `EN_COUNTERS=1`, the default): `fev_full_EN_COUNTERS64B_0.eqy`
  — only the lower 32b counter feeds `count`, `count_vld` tied to 1.
- The internal state registers (`count_low`, `count_high`, `incr_high`) are declared
  unconditionally outside the `generate` block, so the same `[match]` section applies
  to all three parameter sets.

## Limitations

- **Unverified functional change (Reset and Clock task):** `rstz` (async, negatively
  asserted) could not remain async, since TL-Verilog assumes a single free-running
  clock with no async-reset construct. `prepared.sv` (and thus `wip.tlv`/`feved.tlv`)
  was updated to establish a new baseline: a standard two-flop synchronizer
  (`resetn_meta`, `resetn`) synchronizes `rstz` (async-assert, sync-deassert) before
  it gates the counter logic. This changes reset-deassertion timing by up to 2 cycles
  vs. the original and **cannot be FEVed against `orig.sv`** — accepted per the
  process instructions. Everything from this point forward is FEVed against this new
  baseline, not against `orig.sv` directly.
  - Follow-on step (this one FEV'd normally): `resetn` was further converted to an
    internal positively-asserted `reset` (`assign reset = ~resetn;`), used by the
    main counter `always_ff` block, per TL-Verilog convention.

## Deviations from default FEV configuration

(none yet)

## Suggested subsequent logic optimizations

(none yet)

## Potential issues for user review

(none yet)

## Process notes / difficulties

(none yet)
