# Tracker: kronos_counter64 conversion

FEV status: `fev.sh` passes -- incremental and all three full-FEV configurations
(default `EN_COUNTERS=1/EN_COUNTERS64B=1`, `EN_COUNTERS=0`, `EN_COUNTERS64B=0`).

## Most significant issue: unverifiable reset-synchronizer baseline change

`rstz` in `orig.sv` is a genuinely asynchronous, negatively-asserted reset
(`always_ff @(posedge clk or negedge rstz)`). TL-Verilog assumes a single
free-running clock with no async-reset construct, so this could not be preserved.
Per the conversion process, a new `prepared.sv`/`wip.tlv`/`feved.tlv` baseline was
established: a standard two-flop reset synchronizer (`resetn_meta`, `resetn`,
async-assert/sync-deassert) synchronizes `rstz` before it gates the counter logic,
and this new baseline could not be FEVed against `orig.sv` (the process instructions
say this is expected/accepted). **Everything downstream is proven equivalent to this
new baseline, not to `orig.sv` directly.** The user should independently confirm that
delaying reset deassertion by up to 2 cycles (vs. the original's immediate,
combinational deassertion) is acceptable for this design's use in the Kronos RISC-V
core.

## Limitations

- The `resetn`/`resetn_meta` synchronizer remains hand-written Verilog inside
  `\SV_plus` (not native TL-Verilog logic), using the `$$`/`$` pipesignal-prefix
  mechanism to name the signals as pipesignals while preserving the `if`/`else`
  structure. A ternary-expression rewrite of this block was attempted and reproduces
  a yosys limitation: `read_gate: ERROR: Multiple edge sensitive events found for
  this signal!` during `proc -ifx` -- the canonical `if`/`else` form is required to
  infer this async-reset flip-flop. This is the only logic that isn't a native TLV
  pipesignal assignment.
- No tri-states, latches, or external file dependencies were present, so those
  process concerns don't apply here.

## Deviations from default FEV configuration

None beyond the accepted reset-synchronizer baseline change described above.
`fev.eqy`/`fev_full*.eqy` use the default template's `[script]`, `[collect]`, and
`[partition]` sections unmodified.

## Suggested subsequent logic optimizations

None identified. The design is small and its logic (staggered 32b counters with a
1-cycle-delayed upper-word increment) is already minimal; nothing was found that TLV
conversion artificially complicated or that would benefit from restructuring beyond
what the process already produced.

## Code size / structure impact

`wip.tlv` (102 lines) is larger than `orig.sv` (72 lines), primarily due to: the
reset-synchronizer block and its explanatory comments (added during "Reset and
Clock"), the TLV macro wrapper boilerplate (module port connections at top/bottom of
the "Consolidate the SV-TLV Interface" and "TLV Macro" tasks), and the mandatory
3-space-per-scope indentation. The core logic itself (three `<<1$`-prefixed
non-blocking assignments plus two output assignments) is comparable in line count to
the original's two `always_ff` blocks and `generate` block, and arguably clearer:
each state signal now has a single, flat ternary expression instead of being spread
across nested `if`/`else` branches, and the `generate if` chain (mux-only logic
depending on `EN_COUNTERS`/`EN_COUNTERS64B`) collapsed to two plain ternary
`assign`s once fully de-generated in the "Simplify Code Generation" task.

## Process notes for future conversions

- **Match-section pipesignal paths must be fully qualified at this design's
  file-structure stage.** When adding `[match]` entries for newly-pipesignaled
  internal signals (`count_low` -> `$count_low`, etc., in the "Signal Assignments to
  TLV Pipesignal Assignments" task), a bare pipesignal reference (`$count_low`)
  fails with `SandPiper ... Signal $count_low is used but never assigned`. Cause:
  `map_match_pipesignals.py` appends match-section pipesignal references in a bare
  `\SV_plus`/`[match]` block at the *very end* of `wip.tlv` -- after the file's
  trailing `\SV`/`endmodule` region required by the "TLV File Format" task -- so the
  appended block has no enclosing `\TLV`/pipeline/stage scope to resolve a bare
  `$signal` against. Fix: use the fully qualified path (`|default<>0$count_low`).
  This exactly reproduces a difficulty noted in a prior conversion
  (`input_debouncer`). Recommend calling this out explicitly in the "Matching
  Signals" section of the instructions, since it's now been hit independently on two
  conversions and the failure mode (a "used but never assigned" error deep in a
  temp-directory SandPiper log) doesn't obviously point back to the match-section
  syntax.
- **New state signals introduced by earlier tasks need matching added when later
  pipesignaled.** `resetn`/`resetn_meta` were introduced during "Reset and Clock"
  (after the "Signal Matching" task had already run), so they had no existing
  `fev_full*.eqy` match entry. When they were later converted to pipesignals
  (during "Convert Remaining Signals to Pipesignals"), `fev.sh`'s automatic
  full-FEV match propagation could only *update* existing entries, not add new
  ones for them, so full FEV failed until the entries were added by hand. Recommend
  the instructions note this explicitly: any state signal added after "Signal
  Matching" needs its `fev_full*.eqy` match entry added manually at the point it's
  renamed/pipesignaled.
- Two transient SandPiper-SaaS service errors ("Error while accessing the compile
  service") were encountered during otherwise-unremarkable tasks; both resolved on
  a simple re-run of `fev.sh` with no code changes. Not a code issue.
