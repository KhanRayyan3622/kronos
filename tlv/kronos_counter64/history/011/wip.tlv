// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

/*
Staggered 64b counter for Kronos RISC-V

The counter is made of two 32b counters splitting the critical path
for lower-end implementations (ex: Lattice iCE40UP)
The upper word update is delayed by a cycle
*/

module kronos_counter64 #(
  parameter EN_COUNTERS = 1,
  parameter EN_COUNTERS64B = 1
)(
  input  logic        clk,
  input  logic        rstz,
  input  logic        incr,
  input  logic [31:0] load_data,
  input  logic        load_low,
  input  logic        load_high,
  output logic [63:0] count,
  output logic        count_vld
);

logic [31:0] count_low, count_high;
logic incr_high;

// Synchronize the asynchronous, negatively-asserted reset (rstz) into a
// synchronous, negatively-asserted reset (resetn), using a standard two-flop
// synchronizer (async assert, sync deassert). This is a deliberate,
// unverifiable-vs-original functional change; see tracker.md.
logic resetn_meta, resetn;
logic reset;

always_ff @(posedge clk or negedge rstz) begin
  resetn_meta <= ~rstz ? 1'b0 : 1'b1;
  resetn      <= ~rstz ? 1'b0 : resetn_meta;
end

assign reset = ~resetn;

always_ff @(posedge clk) begin
  // during a load (any segment), the count is paused
  count_low <=
    reset     ? '0 :
    load_low  ? load_data :
    load_high ? count_low :
    incr      ? count_low + 1'b1 :
                count_low;

  count_high <=
    reset     ? '0 :
    load_low  ? count_high :
    load_high ? load_data :
    incr_high ? count_high + 1'b1 :
                count_high;

  // indicate that the upper word needs to increment
  incr_high <=
    reset                                ? 1'b0 :
    (!load_low && !load_high && incr)    ? count_low == '1 :
                                            1'b0;
end

// relevant if (EN_COUNTERS && EN_COUNTERS64B): the output 64b count is valid
// when the upper word update has settled
// relevant if (EN_COUNTERS && !EN_COUNTERS64B): the upper word will be optimized out
assign count = (EN_COUNTERS && EN_COUNTERS64B) ? {count_high, count_low} :
               EN_COUNTERS                     ? {32'b0, count_low} :
                                                  64'b0;
assign count_vld = (EN_COUNTERS && EN_COUNTERS64B) ? ~incr_high : 1'b1;

endmodule
