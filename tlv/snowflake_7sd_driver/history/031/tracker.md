# snowflake_7sd_driver — TL-Verilog Conversion Tracker

## Status
Conversion complete. All `fev.sh` runs (incremental and full, default configuration —
the module has no parameters) passed. `fev_full.eqy` methodology is sound: standard
`hierarchy`/`flatten`/`proc`/`clean` script, automatic EQY partitioning, `sby`/`smtbmc`
strategy; no unusual match/collect/partition hacks were needed anywhere in the flow.

## Prior Broken Attempt (Process Failure, Not a Design Issue)
Before this conversion, a prior agent session left `tracker.md`/`status.json`/`wip.tlv`
in this directory claiming a "structural blocker" (that `\SV_plus` supposedly can't
reference TLV pipesignals, and that `rstz` was an async reset). Both claims were false:
- `rstz` is sampled only inside `always_ff @(posedge clk)` — it is synchronous, not async.
- `\SV_plus` freely mixes raw Verilog and pipesignal (`$name`) references; that is its
  entire purpose.
That attempt never ran `prep.sh` — there was no `scripts`/`instructions`/`fev` symlink,
no `config.json`, no `prepared.sv`, no `fev.eqy`, and `fev.sh` was never invoked. The
directory was re-prepped from scratch via `prep.sh`; the old files are preserved at
`../snowflake_7sd_driver.bak_broken_attempt` for reference. **Process suggestion:** it
may be worth having `get_task.py`/`prep.sh` detect and refuse to proceed in a directory
that has `status.json`/`tracker.md` but is missing the other required infrastructure
files, to prevent an agent from silently working outside the intended process.

## Naming Deviation
Input ports `a` and `b` are single-letter names, which violate pipesignal naming rule 3
(name must begin with two letters). Per the instructions' own example (`a` -> `aa`),
they were renamed to pipesignals `$aa`/`$bb`. This is a cosmetic-only deviation confined
to the TLV file; the Verilog module interface (`a`, `b`) is unchanged.

## Deferred SV_plus Content (by design, not oversight)
During the "Signal Assignments" and "Convert Remaining Signals" tasks, the `sel`/`disp`
output-port registers were deliberately left as raw Verilog in `\SV_plus` rather than
pipesignals, since those tasks are explicitly scoped to *internal* (non-module-interface)
signals. They were converted to pipesignals (`<<1$sel`, `<<1$disp`) in the "Consolidate
the SV-TLV Interface" task, as expected by the process. No `\SV_plus` remains in the
final file.

## FEV Note
When first attempting to add explicit `fev.eqy` match lines for `sel`/`disp` during the
interface-consolidation step, EQY reported a partition conflict (the gold bit was matched
both automatically by name and by the explicit line). This happened because `sel`/`disp`
retain their literal net names post-`clean` even after being re-expressed as pipesignals
with a combinational output-connect assign. Removing the explicit match lines (relying on
automatic by-name matching) resolved it. No case existed where an explicit match was
actually required for this module — the module is small enough that no output ever
feeds back into logic across a cut boundary.

## Design Impact of the Conversion
- Line count grew modestly (70 -> ~90 lines), mostly from the TLV macro/module split
  (module boilerplate duplicated as macro-instantiation wrapper) and the explicit
  input/output connection sections, which have no equivalent in the original (the
  original used ports directly).
- The TLV macro body (lines 6–25) is close in length to the original's logic (excluding
  header comment and ports), and arguably more explicit: every register's next-state is
  a single ternary expression, replacing two `if`/`else` chains, with no risk of
  unintended latch inference.
- No further logic optimization is suggested for this module — it is small, has no
  parameters, and the FEV-proven logic is a direct, line-for-line translation of the
  original with no behavioral changes.
