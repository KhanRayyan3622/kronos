# Tracker: input_debouncer conversion

FEV status: `fev.sh` passes (incremental and all three full-FEV configurations:
default N=16/DEBOUNCE=16, DEBOUNCE=0, N=1).

## Assumptions

- The original design's only reset requirement is for `timer` (via `rstz`); `sync`,
  `line`, and `read` state have no reset in the original design and remain unreset.
- `clk` is a single, free-running clock for the whole design (true in the original).

## Limitations

- The asynchronous, negatively-asserted reset synchronizer (`resetn`/`resetn_meta`,
  driven by `posedge clk or negedge rstz`) could not be expressed in native TL-Verilog
  and remains hand-written Verilog inside `\SV_plus`. TL-Verilog assumes a single
  free-running clock with no construct for asynchronous reset domains. This is the
  *only* logic left outside the `\TLV` pipesignal domain; everything else (`timer`,
  `tick`, `sync`, `raw_val`, `poll`, `line`, `read`) is a proper pipesignal.
  - A related restructuring attempt (expressing this block as a ternary TLV
    assignment) broke yosys's `proc` pass (`Multiple edge sensitive events found`) —
    it requires the canonical `if(~rstz)...else...` form to infer the async-reset
    flip-flops. The `$$`/`$` pipesignal-prefix mechanism (from the "Convert Remaining
    Signals to Pipesignals" task) *did* work for naming these signals as pipesignals
    while preserving the `if`/`else` Verilog structure, so `resetn`/`resetn_meta` are
    pipesignals despite the surrounding code staying in `\SV_plus`.

## Deviations from default FEV configuration

- `fev.eqy`'s `[collect *]` section enables `group *` (its own template's suggested,
  but normally-commented-out, option) instead of full automatic partitioning. This was
  required to avoid a reproducible incremental-FEV timeout: once most per-instance
  `gpio[N-1:0]` signals became individual pipesignal cutpoints (~160 total partitions),
  every partition proved individually but the run still exceeded `fev.sh`'s hardcoded
  120s `eqy` budget, 4/4 consecutive attempts. `fev_full*.eqy` still use default
  automatic partitioning — they haven't hit this wall yet, but the same fix would apply
  if they ever do (e.g., if `N` or per-instance signal count grows further).

## Deviations from the defined process

- **Not FEV-verified — needs user review.** The "Reset and Clock" task required
  establishing a new baseline in `prepared.sv` (since the original reset was
  asynchronous): added a 2-flip-flop synchronizer producing an internal `resetn` from
  `rstz`, and switched `timer`'s reset to synchronous. This is a real, deliberate
  functional change — reset deassertion for `timer` is now delayed by up to 2 clock
  cycles relative to the original design (reset assertion timing is unchanged). It
  follows the documented process for asynchronous resets and is standard best
  practice, but by construction it **cannot be checked by FEV** and should be reviewed
  against the intended timing/behavior. (Note: an earlier draft of this change
  mistakenly also renamed the `rstz` port to `aresetn`; that rename was unwarranted
  per the instructions and has been reverted — the port is still `rstz`.)

## Suggested subsequent logic optimizations

- None identified in the debounce/sync logic itself — it's a straightforward per-bit
  pipeline with no redundancy observed.
- The `/gpio` scope now has an intermediate pipesignal `$read` plus a following
  `*read[gpio] = $read;` connection, versus the original where `read` itself was the
  flip-flop directly. This is a structural artifact of connecting pipesignals to
  module outputs, not a functional or synthesis-level cost (synthesis will trivially
  collapse the pass-through), but worth noting for anyone reading the netlist.

## Potential issues for user review

- The unverified reset-timing change above.
- Any verification collateral for this module (e.g. `tests/unit/debouncer_unit_test.sv`)
  will need updating for the new internal signal names/hierarchy. The `fev*.eqy`
  `[match]` sections in this directory constitute the old-name -> new-name signal map
  accumulated across the conversion and can be used as a reference for that update.
- If this module is ever modified again with more instances/signals, watch for the
  same incremental-FEV timeout described above; `fev_full*.eqy` may need `group *`
  added too at that point.

## Process/instruction improvement suggestions

- `fev.sh`'s hardcoded 120s per-`eqy`-run timeout is too tight for designs with many
  replicated instances once most/all of their per-instance signals become pipesignal
  cutpoints — hit reproducibly (4/4) once `resetn`/`resetn_meta` were converted on top
  of the existing ~150 `gpio`-array cutpoints, even though every partition proved.
  Consider making the timeout configurable, or auto-enabling `[collect] group *` past
  some partition-count threshold.
- The "For Loop Assignments to TLV Scoped Assignments" task's `#scope`-indexing
  example (`core[#core].disabled`) only covers referencing a signal *declared inside*
  the same replicated scope/hierarchy. It doesn't cover the common case of indexing a
  flat, non-replicated Verilog array (e.g., a module input port like `gpio_in`) from
  within a replicated TLV scope — using `#gpio` there caused SandPiper to emit the
  literal, unprocessed text `gpio_in[#gpio]` (a syntax error). The working mechanism
  turned out to be using the bare scope name itself as a plain Verilog array index
  (`*gpio_in[gpio]`), which took some trial and error to discover. Worth adding an
  explicit example to the task instructions.
- EQY's `[match]` wildcard syntax (e.g., `gpio[*].sync` paired with a gate-side
  `/gpio[*]<>0$sync` pipesignal path) silently fails to establish a cutpoint when the
  gate-side pipesignal-path substitution collapses to a flattened array name with no
  per-index wildcard placeholder (`Warning: Cannot find first entity in ...`).
  Explicit per-index enumeration was required instead, matching the approach already
  used in the "Signal Matching" task. Worth flagging that the wildcard example given
  for `fev.eqy` may not generalize to this common case.
- Also relevant: gold-side match names must reflect `feved.sv`'s *current* generated
  structure, not the pre-refactor Verilog hierarchy or an assumption carried over from
  an earlier step — `feved.sv`'s SandPiper-generated names for an already-converted
  signal can shift when unrelated sibling signals are converted later (observed for
  `sync`'s generated name when `raw_val`/`line` were added). This is implied by the
  existing instructions but easy to miss in practice; an explicit callout (e.g. "grep
  `feved.sv` to confirm current gold names before writing a match line") would help.
- Two transient/flaky failures were encountered and resolved by simply retrying
  `fev.sh`, unrelated to code correctness: a SandPiper-SaaS "Error while accessing the
  compile service" error, and (separately, before the `group *` fix) an incremental
  FEV run that reported failure via a timeout/interrupt despite every partition having
  already proved. Worth hardening `fev.sh` with automatic retry for these specific
  failure signatures.

## Impact assessment

- Line count: `orig.sv`/`prepared.sv` is 58 lines; `wip.tlv` is 69 lines. The increase
  is entirely TLV/M5 structural boilerplate (`\m5_TLV_version`, `\m5`, `\SV`/`\TLV`
  block delimiters, the input-connect and macro-instantiation lines) — no logic is
  duplicated.
- The TLV macro body itself is slightly more compact than the original's logic
  (excluding comments/blank lines and the module header/footer): pipesignals
  eliminate roughly nine separate `logic ...` declaration statements (a pipesignal is
  declared implicitly by its first assignment), and the `/gpio[N-1:0]` TLV scope
  eliminates the `generate`/`genvar`/`for`/`begin...end` boilerplate entirely,
  replacing it with a single scope-declaration line.
- The TLV scope construct provides *more* structure than the original generate `for`
  loop: `/gpio[N-1:0]` is a first-class, named, directly-referenceable construct
  (usable in cross-scope pipesignal references like `|default$tick` and in `.eqy`
  match sections), whereas the original's per-instance hierarchy names were
  compiler-assigned (`genblk1[i]`) until a task explicitly labeled the block.
- The one obstacle to a fully "clean" TLV conversion is the asynchronous reset domain,
  which is fundamentally incompatible with TL-Verilog's single-free-running-clock,
  synchronous-pipesignal model. This is inherent to the source design's use of an
  asynchronous reset, not a shortcoming of the conversion effort.
