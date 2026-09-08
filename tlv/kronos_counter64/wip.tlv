\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)

// The guts of module kronos_counter64.
\TLV kronos_counter64(/_top)
   |default
      @0
         \SV_plus
            // Synchronize the asynchronous, negatively-asserted reset (rstz) into a
            // synchronous, negatively-asserted reset (resetn), using a standard two-flop
            // synchronizer (async assert, sync deassert). This is a deliberate,
            // unverifiable-vs-original functional change; see tracker.md. This
            // block cannot be expressed as TL-Verilog pipesignal assignments since
            // it requires an async-reset-sensitive always_ff (TL-Verilog assumes a
            // single free-running clock).
            always_ff @(posedge clk or negedge $rstz) begin
              if (~ $rstz) begin
                $$resetn_meta <= 1'b0;
                $$resetn <= 1'b0;
              end
              else begin
                $resetn_meta <= 1'b1;
                $resetn <= $resetn_meta;
              end
            end

         $reset = ~ $resetn;

         // during a load (any segment), the count is paused
         <<1$count_low[31:0] =
           $reset      ? '0 :
           $load_low   ? $load_data :
           $load_high  ? $count_low :
           $incr       ? $count_low + 1'b1 :
                          $count_low;

         <<1$count_high[31:0] =
           $reset      ? '0 :
           $load_low   ? $count_high :
           $load_high  ? $load_data :
           $incr_high  ? $count_high + 1'b1 :
                          $count_high;

         // indicate that the upper word needs to increment
         <<1$incr_high =
           $reset                                  ? 1'b0 :
           (! $load_low && ! $load_high && $incr)  ? $count_low == '1 :
                                                       1'b0;

         // relevant if (EN_COUNTERS && EN_COUNTERS64B): the output 64b count is valid
         // when the upper word update has settled
         // relevant if (EN_COUNTERS && ! EN_COUNTERS64B): the upper word will be optimized out
         $count[63:0] = (EN_COUNTERS && EN_COUNTERS64B) ? {$count_high, $count_low} :
                        EN_COUNTERS                     ? {32'b0, $count_low} :
                                                           64'b0;
         $count_vld = (EN_COUNTERS && EN_COUNTERS64B) ? ~ $incr_high : 1'b1;

\SV
   // Copyright (c) 2020 Sonal Pinto
   // SPDX-License-Identifier: Apache-2.0
   //
   // Converted to TL-Verilog by Claude.

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
\TLV
   // Connect Verilog inputs:
   |default
      @0
         $rstz = *rstz;
         $incr = *incr;
         $load_data[31:0] = *load_data;
         $load_low = *load_low;
         $load_high = *load_high;
   m5+kronos_counter64(/top)
   // Connect Verilog outputs:
   |default
      @0
         *count = $count;
         *count_vld = $count_vld;
\SV
   endmodule
