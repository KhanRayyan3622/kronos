# Tracker: input_debouncer conversion

## Assumptions

## Limitations

## Deviations from default FEV configuration

## Deviations from the defined process

## Suggested subsequent logic optimizations

## Potential issues for user review

## Process/instruction improvement suggestions

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
