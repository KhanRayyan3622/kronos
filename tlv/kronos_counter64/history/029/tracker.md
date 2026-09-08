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
  - **If/Else and Case to Ternary task:** attempted converting the `resetn`/
    `resetn_meta` synchronizer's `if`/`else` to a ternary form; this reproduces a
    known yosys limitation (also hit during the `input_debouncer` conversion):
    `read_gate: ERROR: Multiple edge sensitive events found for this signal!`
    during `proc -ifx`. The canonical `if (~rstz) ... else ...` form is required
    to infer this async-reset flip-flop. Reverted; this block is the one exception
    left in canonical `if`/`else` form. (Suggested instruction improvement: call
    this out explicitly in the "If/Else and Case to Ternary" task text, since it's
    now been hit on two separate conversions.)

## Deviations from default FEV configuration

(none yet)

## Consolidate the SV-TLV Interface task

Input pipesignals ($rstz, $incr, $load_data, $load_low, $load_high) are assigned at
the top of |default@0 from the module's raw ports; output ports (count, count_vld)
are assigned from pipesignals ($count, $count_vld) at the bottom. All internal logic
uses pipesignals exclusively, including the reset-synchronizer's always_ff sensitivity
list (`posedge clk or negedge $rstz`), which SandPiper substituted without issue.

## Suggested subsequent logic optimizations

(none yet)

## Simplify Code Generation task

The single `generate if (EN_COUNTERS) ... if (EN_COUNTERS64B) ...` chain was fully
eliminated: all RHS expressions (`count_high`, `count_low`, `incr_high`) depend only
on unconditioned signals, so `count`/`count_vld` are now plain ternary `assign`s
covering all three cases. No `generate`/`endgenerate` or tick-ifdef/ifndef blocks
remain, so no M5 parameterization of dead-code elimination is needed downstream.

## Potential issues for user review

(none yet)

## Process notes / difficulties

- **Signal Assignments to TLV Pipesignal Assignments task:** when adding `[match]`
  entries in `fev.eqy` for signals newly converted to pipesignals (`count_low` ->
  `$count_low`, etc.), using the bare pipesignal form (`$count_low`) failed with
  `SandPiper ... Signal $count_low is used but never assigned` during match-section
  extraction. Cause: `map_match_pipesignals.py` appends the match-section pipesignal
  references in a bare `\SV_plus`/`[match]` block at the *very end* of `wip.tlv`,
  after the file's trailing `\SV`/`endmodule` region -- so the appended block is
  outside any `\TLV`/pipeline/stage scope, and a bare `$signal` reference has no
  scope to resolve against. Fix: use the **fully qualified pipesignal path**
  (`|default<>0$count_low`) in the match section, per the instructions ("Pipesignal
  paths ... must be full TL-Verilog paths from top-level scope") -- confirmed this
  is exactly what a prior conversion (`input_debouncer`) also had to do at this same
  task. (Suggested instruction improvement: call out this specific failure mode and
  fix explicitly in the "Matching Signals" section, since bare pipesignal names work
  fine *within* `\TLV` scope elsewhere but silently fail only in this end-of-file
  match-extraction context.)
- **Convert Remaining Signals to Pipesignals task:** converting `resetn`/`resetn_meta`
  to pipesignals (via `$$`/`$` prefixes, preserving the `if`/`else` async-reset
  structure) required manually adding `gold-match` entries for them to
  `fev_full*.eqy` (they were never added during the "Signal Matching" task since
  they didn't exist yet at that point -- they were introduced afterward, during
  "Reset and Clock"). `fev.sh`'s automatic full-FEV match propagation only updates
  *existing* match entries when a matched signal is renamed; it can't add match
  entries for pipesignals that have no incremental match-list history. Full FEV
  failed with `count_low`/`count_high`/`incr_high` all reporting `resetn`/
  `resetn_meta` as unmatched internal signals until these were added by hand.
  (Suggested instruction improvement: note that any new state signal introduced by
  earlier tasks -- e.g. by "Reset and Clock" -- needs a manually-added
  `fev_full*.eqy` match entry once it's later converted to a pipesignal; the
  automatic propagation only covers signals that already had a match entry.)
- The `reset` signal (introduced during the Reset and Clock task) is not in
  `fev_full*.eqy`'s match list (it's a new signal with no corresponding gold signal
  in the original design, per the "do not add match statements for new signals"
  rule), so `fev.sh`'s automatic full-FEV match propagation logs a harmless
  `WARNING: Unable to update fev_full*.eqy for refactoring of 'reset' -> ...` on
  every run from this point on. This is expected, not a bug.
