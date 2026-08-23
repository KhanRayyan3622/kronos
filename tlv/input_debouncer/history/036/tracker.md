# Tracker: input_debouncer conversion

## Assumptions

## Limitations

## Deviations from default FEV configuration

## Deviations from the defined process

## Suggested subsequent logic optimizations

## Potential issues for user review

## Process/instruction improvement suggestions

## Non-vector Signals notes

- No-op: no signed, struct, union, typedef, or enum-typed signals exist in the design.
  All signals are plain bit vectors/booleans, already pipesignals. No changes made.
  `fev.sh` passed.

## For Loop Assignments to TLV Scoped Assignments notes

- Introduced a `/gpio[N-1:0]` TLV scope (matching the original `for (i = 0; i < N; i++)`
  bounds) at `|default@0`, converting the generate-loop signals to pipesignals one at a
  time per the recommended incremental approach. The remaining not-yet-converted
  generate-loop content was kept in a temporarily-renamed `gpio_gen` Verilog block
  (renamed from `gpio` to avoid colliding with the new `/gpio` TLV scope name) until
  fully eliminated.
- Step 1 (`sync`): `<<1$sync[1 : 0] = {$sync[0], *gpio_in[gpio]};`. Tooling notes:
  - Referencing a module input port (`gpio_in`, a flat vector declared outside any
    scope) by the current scope's replica index required using the *bare* scope name
    (`gpio`) as the array index (`*gpio_in[gpio]`) — NOT the documented `#gpio` syntax
    from the task instructions. `#core`-style indexing (from the task's own
    `core[#core].disabled` example) apparently only applies to referencing a signal
    *declared inside* the same generate/scope hierarchy, not a flat top-level port
    array; using `#gpio` there caused SandPiper to emit the literal (unprocessed)
    text `gpio_in[#gpio]`, a Verilog syntax error at the `#`.
  - EQY's `[match]` wildcard `gpio[*].sync` / `|default/gpio[*]<>0$sync` did NOT
    establish the cutpoint (`Warning: Cannot find first entity in gpio[*].sync
    DEFAULT_Gpio_sync_a0` — the gate-side pipesignal-path substitution collapses to a
    single flattened array name with no per-index wildcard placeholder, so EQY's own
    `[]`-capture glob syntax has nothing to correlate against `*` on the gold side).
    Switched to explicit per-index enumeration (`gpio[0].sync` .. `gpio[15].sync`),
    matching the reliable approach already used in the Signal Matching task — this
    resolved it.
  - Renaming the leftover generate block to `gpio_gen` required adding matches for
    the (unrenamed-content, still-Verilog) `raw_val`/`line`/`poll` signals too
    (`gpio[i].sig` -> `gpio_gen[i].sig`), since the hierarchical path changed even
    though the signals themselves are unconverted.
  - `fev_full_N_1.eqy` again logged expected benign "Unable to update" warnings for
    indices 1-15 (N=1 only elaborates index 0).
- `fev.sh` passed after these fixes.
- Step 2 (`raw_val`, `poll`, `line` together): `$raw_val = $sync[1]; $poll[2 : 0] =
  {$line, $raw_val}; <<1$line[1 : 0] = |default$tick ? {$line[0], $raw_val} : $line;`.
  Left only `read[i]`'s always_ff in the (still-excluded) `gpio_gen` generate block,
  updated to reference `/gpio[i]$poll` instead of the removed local `poll` reg.
  Tooling/debugging notes from this step:
  - Referencing a pipesignal assigned at an ANCESTOR scope (`$tick`, assigned at
    `|default@0`) from within the child `/gpio` scope requires the explicit
    `|default$tick` ancestor-qualified path — a bare `$tick` resolves relative to the
    current (`/gpio`) scope and fails with `Signal |default/gpio$tick is used but
    never assigned`.
  - Match-section debugging: after converting `raw_val`/`line`/`poll`, incremental FEV
    initially failed with `read.N` UNKNOWN for all 16 instances, but with NO per-signal
    partition attempts logged at all (not even a failed one) — the match lines simply
    weren't taking effect. Root cause (found via `Warning: Cannot find first entity in
    <gold> <gate>` in the eqy log): the GOLD-side names I wrote no longer matched
    `feved.sv`'s actual structure. `feved.sv` is itself SandPiper-generated from the
    *previous* successfully-verified checkpoint, so gold-side match names must be
    the concrete names `feved.sv` currently uses (verified directly via `grep` on
    `feved.sv`), not the pre-refactor Verilog hierarchy names. This affected `sync`
    too (already-converted in a prior step) even though its pipesignal name hadn't
    changed this round — SandPiper regenerated its underlying flat array name
    (`DEFAULT_Gpio_sync_a0[i]`) differently once `raw_val`/`line` were added, so its
    match entry had to be refreshed as well. **Lesson: whenever `feved.sv`'s generated
    structure could have shifted (i.e., almost every step that adds/changes pipesignal
    logic), re-verify gold-side match names against current `feved.sv` content rather
    than assuming names from an earlier step are still valid.**
  - Separately hit one `[match]`-section corruption from a scripted edit: a Python
    string-replace targeted the *commented-out* example line `# [match
    input_debouncer]` instead of the real `[match input_debouncer]` header a few
    lines below, corrupting the section header. Fixed by inspecting the file
    directly rather than trusting the script's `str.index` match.
- Step 3 (`read`, the module output): introduced an intermediate pipesignal `$read`
  for the state, then connected it to the actual output port per-instance:
  `<<1$read = |default$tick ? ($poll == '0) ? 1'b0 : ($poll == '1) ? 1'b1 : $read :
  $read; *read[gpio] = $read;`. Matched gold's `read[i]` (the register directly on the
  port in the original design) to gate's new `|default/gpio[i]<>0$read` pipesignal.
  Despite the anticipated output-cutpoint complication (gold's register *is* the port;
  gate's register is a separate signal combinationally connected to the port),
  `fev.sh` passed on the first attempt with no extra `[collect]`/`[partition]`
  adjustments needed — the simple direct `*read[gpio] = $read;` connection was
  apparently trivial enough for EQY's default partitioning to handle cleanly.
- The entire generate `for` loop (and the temporary `gpio_gen` block) is now fully
  eliminated; the whole per-GPIO-bit pipeline lives in the `/gpio[N-1:0]` TLV scope.
  All of `sync`, `raw_val`, `poll`, `line`, and `read` are now pipesignals.
- The reset-synchronizer `always_ff` (async reset) remains the only surviving
  `\SV_plus` logic block, as noted above — expected, not a shortfall of this task.

## Signal Assignments to TLV Pipesignal Assignments notes

- Converted `timer` and `tick` (the only qualifying signals: not in a generate block,
  not signed/user-typed, no module/function/macro instantiation) to pipesignals:
  - `timer <= ...` -> `<<1$timer[DEBOUNCE : 0] = ~ *resetn ? '0 : $tick ? '0 : $timer + 1'b1;`
  - `assign tick = timer[DEBOUNCE];` -> `$tick = $timer[DEBOUNCE];`
  - Removed their now-unused `logic` declarations.
  - `resetn` (declared/assigned only in the excluded async-reset-synchronizer
    `\SV_plus` block) is referenced from the new `\TLV` expression as `*resetn`
    per the plain-Verilog-signal-reference convention.
  - Propagated `tick` -> `$tick` into the two remaining references inside the
    (still-excluded, generate-block) `line`/`read[i]` always_ff, since plain `tick`
    no longer exists as a Verilog reg — `\SV_plus` code can reference pipesignals
    directly by their `$name`.
  - Added `gold-match timer |default<>0$timer` / `gold-match tick |default<>0$tick`
    to `fev.eqy`.
- Tooling note: attempting to reopen a `\TLV` block immediately after closing an
  `\SV_plus` block (to return to plain TLV assignment syntax) fails with SandPiper
  error `\TLV block can only be used within m4+ instantiation, not directly within
  another \TLV block`. The fix: don't re-emit `\TLV` at all — once inside the
  top-level `\TLV` region, plain TLV assignment lines can simply be dedented back to
  the `\SV_plus` keyword's own indentation level (sibling to it), no directive needed.
- The reset-synchronizer `always_ff` (async reset on `rstz`) remains, as before,
  un-converted in `\SV_plus` — TL-Verilog assumes a single free-running clock and has
  no construct for asynchronous reset domains.
- `fev.sh` passed.

## Naming Conventions notes

- No-op: `./scripts/rename_sigs.py -n -a` reported no non-compliant internal signal
  names, and `-t` testing of `gpio`, `resetn`, `resetn_meta`, `timer`, `tick`, `sync`,
  `raw_val`, `line`, `poll`, `read`, `gpio_in`, `clk`, `rstz` confirmed all comply with
  the pipesignal naming rules already. No changes made.

## Name Generate Blocks notes

- Named the generate `for` loop `gpio` (`for (i = 0; i < N; i++) begin : gpio`),
  renaming the hierarchical path from `genblk1[i].*` to `gpio[i].*`.
- Updated `fev.eqy`'s `[match]` section with `gold-match genblk1[i].sig gpio[i].sig`
  for all 16 default-config instances/signals so `fev.sh`'s automation could propagate
  the rename into `fev_full*.eqy`.
- `fev_full_N_1.eqy` (N=1) logged 60 benign "Unable to update" warnings for
  `genblk1[1..15].*` — expected, since that config only elaborates instance 0; verified
  none of the warnings referenced index 0. All FEV runs (default, DEBOUNCE=0, N=1)
  passed.

## Eliminate Multiple Assignments notes

- No-op: every signal is assigned exactly once (the `resetn`/`resetn_meta` pair each
  appear in both branches of a single `if`/`else`, which is one logical assignment,
  not multiple). No changes made.

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
