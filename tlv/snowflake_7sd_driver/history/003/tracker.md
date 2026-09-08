# Tracker: snowflake_7sd_driver

## Assumptions
- No parameters in this module; single default configuration only.
- `en` gates the display-mux update synchronously (not clock gating); treated as functional, preserved as-is.
- Reset (`~rstz`) is sampled only inside `always_ff @(posedge clk)`, so it is a **synchronous** reset, not async. (An earlier, abandoned conversion attempt in this directory incorrectly assumed an async reset and used that to justify a false "structural blocker" claim. That attempt never actually ran the setup process — no scripts/instructions symlinks, no config.json/prepared.sv/fev.eqy existed. Directory was reset and re-prepped via prep.sh from scratch; old files moved to ../snowflake_7sd_driver.bak_broken_attempt for reference.)

## Limitations
(none yet)

## Deviations
(none yet)

## Suggested Follow-ups
(none yet)

## Process Notes / Difficulties
(none yet)
