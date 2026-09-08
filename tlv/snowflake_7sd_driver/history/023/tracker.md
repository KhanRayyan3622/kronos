# Tracker: snowflake_7sd_driver

## Parameters
- Module has no parameters and no tick-defines. Only the default (single) configuration is tested; no `fev_full_*.eqy` alt-parameter files needed.

## Assumptions
- No parameters in this module; single default configuration only.
- `en` gates the display-mux update synchronously (not clock gating); treated as functional, preserved as-is.
- Reset (`~rstz`) is sampled only inside `always_ff @(posedge clk)`, so it is a **synchronous** reset, not async. (An earlier, abandoned conversion attempt in this directory incorrectly assumed an async reset and used that to justify a false "structural blocker" claim. That attempt never actually ran the setup process — no scripts/instructions symlinks, no config.json/prepared.sv/fev.eqy existed. Directory was reset and re-prepped via prep.sh from scratch; old files moved to ../snowflake_7sd_driver.bak_broken_attempt for reference.)

## Reset and Clock
- `clk` was already the clock signal name; no rename needed.
- `rstz` is a **synchronous**, negatively-asserted reset (sampled only inside `always_ff @(posedge clk)`). Created an internal positively-asserted `reset = ~rstz` in `wip.tlv` and updated its single use site. No change to `prepared.sv` was necessary since the original reset is synchronous.

## Signal Assignments to TLV Pipesignal Assignments
- Converted internal signals `reset`, `timer`, `rollover`, `tick` to pipesignals.
- `sel` and `disp` are module OUTPUT ports driven by non-blocking assignments (registered). Since the task scope is "internal" signal assignments, these were left as raw Verilog in `\SV_plus` for now, referencing the new `$reset`/`$tick` pipesignals directly. Their conversion to pipesignals plus output wiring (`*sel = $sel;`, `*disp = $disp;`) is expected in the later "Consolidate the SV-TLV Interface" task — flagging here so a future pass doesn't mistake this for an oversight.

## Limitations
(none yet)

## Deviations
(none yet)

## Suggested Follow-ups
(none yet)

## Process Notes / Difficulties
(none yet)
