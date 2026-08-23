# Tracker: input_debouncer conversion

## Assumptions

## Limitations

## Deviations from default FEV configuration

## Deviations from the defined process

## Suggested subsequent logic optimizations

## Potential issues for user review

## Process/instruction improvement suggestions

## Define M5 Configurations / Configure Using M5 notes

- Both tasks skipped per their explicit opening condition: the module has no generate
  `if`/`else` blocks and no tick-ifdef/ifndef sections (only a generate `for` loop,
  which is unconditional structural replication, not elaboration-conditional code).
  No `config.json` M5_configs changes needed. `fev.sh` passed.

## TLV File Format notes

- Wrapped the file in `\m5_TLV_version`/`\m5`/`\SV`/`\TLV` structure per the task
  template. The module header (comments, `module input_debouncer #(...)(...);`) stays
  in the top `\SV` block; the module body moved into `\SV_plus` under
  `|default` @0`, with `endmodule` in a trailing `\SV` block.
- Indentation: `|default` (3 spaces), `@0` (6), `\SV_plus` (9), module body (12,
  applied uniformly on top of the body's existing internal indentation).
- No SandPiper-reserved symbols (`$`, `@`, `|`, `/`, `#`, `%`, `*`, `\`) appear
  immediately before word characters anywhere in the body, so no `\`-escaping was
  needed.
- Added whitespace around unary `~` (`~ rstz`, `~ resetn`) and range-specifier colons
  (`[DEBOUNCE : 0]`, `[1 : 0]`, `[2 : 0]`) and the `for` loop header
  (`i = 0; i < N; i++`) per the TL-Verilog identifier-safety conventions.
- `fev.sh` passed on the first attempt (SandPiper parsed the `\SV_plus` block without
  any false pipesignal-identifier matches).

## Eliminate Always Comb notes

- No-op: no `always_comb` or level-sensitive `always` blocks in the design (only
  `always_ff` and `assign`). No changes made.

## Procedural For Loops notes

- No-op: the only `for` loop in the design is the generate `for` (structural
  replication over `N`, not a procedural reduction loop with inter-iteration
  dependency). No changes made.

## If/Else and Case to Ternary notes

- The reset-synchronizer `always_ff` block (`resetn_meta`/`resetn`, asynchronous reset
  on `aresetn`) could **not** be converted to a ternary expression: yosys's `proc` pass
  requires the canonical `if (~areset) ... else ...` form immediately inside the
  always block to correctly infer the async-reset flip-flop. Rewriting the body as a
  ternary produced `ERROR: Multiple edge sensitive events found for this signal!`
  during `read_gate`. Reverted; this block is intentionally left as `if`/`else` and
  flagged as a poor candidate for this refactoring (analogous to the "poor candidate"
  exception called out in the Simplify Code Generation task for blocks that don't
  tolerate transformation).
- `timer`'s `always_ff` (synchronous reset via `resetn`, then `tick`, then increment)
  was converted to a single nested ternary assignment preserving the original
  if/else-if/else priority order.
- `genblk1[i]`'s `line`/`read[i]` `always_ff` (guarded by `if (tick)`, with a nested
  `if (poll=='0) / else if (poll=='1)` for `read[i]`) was converted to ternary
  assignments, explicitly recirculating `line` and `read[i]` when `tick` is deasserted
  or `poll` matches neither pattern.
- Flaky tooling: incremental FEV intermittently hit the hardcoded 120s `eqy` timeout
  in `fev.sh` on this ~130-partition design (`Keyboard interrupt or external
  termination signal` after all partitions had already passed) — a machine-speed
  issue, not a logic error. Simply retrying `fev.sh` succeeded. Worth flagging as a
  potential improvement: `fev.sh`'s per-run timeout may be too tight for designs with
  many small generate-block partitions on slower hardware.

## Eliminate Split Assignments notes

- No-op: no signal has separate assignments to different static bit ranges of the same
  vector (e.g., `sig[7:4]` and `sig[3:0]` assigned in different statements). No changes
  made.
- One transient failure: the first `fev.sh` run failed with a SandPiper-SaaS
  "Error while accessing the compile service" (a remote service error, not a code
  issue) while mapping match pipesignals for `fev_full_DEBOUNCE_0.eqy`. No `wip.tlv`
  changes were made in this task, so I simply reran `fev.sh`, which passed. Flagging
  in case this reflects a flaky remote dependency worth hardening/retrying in `fev.sh`.

## Simplify Code Generation notes

- No-op: the module has no generate `if`/`else` blocks and no tick-ifdef/ifndef
  sections (only a generate `for` loop over `N`, handled by a later task). No changes
  made. No remaining if-chains/tick-ifdefs to track for M5 parameterization.

## Reset and Clock notes — DEVIATION, NOT VERIFIED BY FEV

- `clk` was already correctly named; no change needed.
- The original `rstz` reset was **asynchronous** (used in the `always_ff @(posedge clk or
  negedge rstz)` sensitivity list) and negatively asserted, used only to reset `timer`.
  Per the process for asynchronous resets, this required establishing a new baseline
  `prepared.sv` (a functional change that **cannot be verified by FEV**):
  - Added a 2-flip-flop synchronizer (`resetn_meta`, `resetn`) that asserts
    asynchronously (on `rstz` deassertion) but deasserts synchronously, producing an
    internal `resetn` used in place of `rstz`.
  - `timer`'s reset logic now uses `resetn` synchronously (removed from the `always_ff`
    sensitivity list).
  - Copied the updated `prepared.sv` to `wip.tlv`, `feved.tlv`, and `feved.sv` to
    establish this as the new (unverified) baseline, per instructions.
- Correction: the port was initially (incorrectly) renamed `rstz` -> `aresetn`. Per
  instructions, that rename only applies "if the reset input is called `reset`" (to
  avoid colliding with the new synchronized `reset`/`resetn` signal name). Since our
  input was already named `rstz` (no collision with the new internal `resetn`), no
  interface rename was warranted — only the internal synchronizer was needed. The
  rename was reverted; the port remains `rstz`. Caught and fixed after being flagged
  by the user; no other tasks were affected since no other task referenced `aresetn`.
- Functional impact: reset deassertion for `timer` is now delayed by up to 2 clock
  cycles relative to the original (standard reset-synchronizer behavior); reset
  assertion timing is unchanged (still asynchronous). This is a deliberate, standard
  best-practice change explicitly called for by the conversion process for
  asynchronous resets, not an inadvertent behavioral change — but it is a real,
  unverified deviation from the original RTL and should be reviewed by the user.
- `sync`, `line`, and `read` state have no reset in the original design and are
  unaffected by this change.

## Parameters notes

- Module parameters: `N` (default 16, GPIO width, drives generate-for iteration count)
  and `DEBOUNCE` (default 16, drives `timer` width and the `tick` bit index).
- Alternate parameter sets chosen to exercise generate/elaboration edge cases not
  covered by the N=16, DEBOUNCE=16 default:
  - `fev_full_N_1.eqy`: `N=1` — single generate-for iteration (default already covers
    the "many iterations" case). Match list trimmed to only `genblk1[0].*` signals
    since only one instance is elaborated.
  - `fev_full_DEBOUNCE_0.eqy`: `DEBOUNCE=0` — degenerate 1-bit `timer` and `tick`
    indexing at bit 0 (`timer[0]`). Signal names are unaffected by `DEBOUNCE`, so the
    match list is unchanged from `fev_full.eqy`.
  - `N=0` was not used: it would make `read`/`gpio_in` illegally `[−1:0]`, which is not
    legal in the original code.

## Signal Matching notes

- Added self-referencing `gold-match` entries in `fev_full.eqy` for all internal signals
  at default parameter values: `timer`, `tick`, and per generate-instance
  `genblk1[i].sync`, `genblk1[i].raw_val`, `genblk1[i].line`, `genblk1[i].poll` for
  i=0..15 (N=16). Verified exact net names via a standalone `yosys` run
  (`hierarchy -top ...; flatten; proc -ifx; clean; select -list w:*`) rather than
  guessing at wildcard syntax for generate-block instances.
- `fev.sh` passed with no changes to `wip.tlv`.

## Preparation notes

- `prepared.sv` required no modifications from `orig.sv`: no external includes/libraries,
  no latches (design is fully flip-flop-based on posedge clk), no tri-states, and no
  clock gating/enable inputs.
- Note: the per-bit `sync` always_ff block (line 39-41 of `orig.sv`) and the `line`/`read[i]`
  state have no reset. This is inherent to the original design (only `timer` is reset via
  `rstz`). Per the process, no special reset handling is needed for FEV since every state
  element is a cutpoint.
