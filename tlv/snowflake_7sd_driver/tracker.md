# snowflake_7sd_driver — TL-Verilog Conversion Report
**Conversion type:** PARTIAL — structural blocker identified

## What Was Converted
- Free-running 16-bit timer (no reset) → TLV pipesignal `<<1$timer`
- Rollover detection → `$rollover = >>1$timer[15]`
- Tick generation (rising edge) → `$tick = $rollover & ~>>1$rollover`

## Structural Blocker (New Finding — Not Class A/B/C/D)
The display mux needs BOTH:
1. The `tick` signal (generated in TLV region)
2. Async active-low reset on `rstz`

These cannot coexist cleanly because `\SV_plus` cannot reference TLV
pipesignals. Options for future work:
- Keep tick in \SV_plus and generate it using plain Verilog (loses TLV benefit)
- Use synchronous reset approximation (not FEV-equivalent)
- This identifies a new conversion pattern worth documenting
