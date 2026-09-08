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
  if (~rstz) begin
    resetn_meta <= 1'b0;
    resetn <= 1'b0;
  end
  else begin
    resetn_meta <= 1'b1;
    resetn <= resetn_meta;
  end
end

assign reset = ~resetn;

always_ff @(posedge clk) begin
  if (reset) begin
    count_low <= '0;
    count_high <= '0;
    incr_high <= 1'b0;
  end
  else begin
    incr_high <= 1'b0;

    // during a load (any segment), the count is paused
    if (load_low) count_low <= load_data;
    else if (load_high) count_high <= load_data;
    else begin
      if (incr) begin
        count_low <= count_low + 1'b1;
        // indicate that the upper word needs to increment
        incr_high <= count_low == '1;
      end

      if (incr_high) count_high <= count_high + 1'b1;
    end
  end
end

// relevant if (EN_COUNTERS && EN_COUNTERS64B): the output 64b count is valid
// when the upper word update has settled
// relevant if (EN_COUNTERS && !EN_COUNTERS64B): the upper word will be optimized out
assign count = (EN_COUNTERS && EN_COUNTERS64B) ? {count_high, count_low} :
               EN_COUNTERS                     ? {32'b0, count_low} :
                                                  64'b0;
assign count_vld = (EN_COUNTERS && EN_COUNTERS64B) ? ~incr_high : 1'b1;

endmodule
