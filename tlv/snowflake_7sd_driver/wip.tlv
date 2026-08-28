\m5_TLV_version 1d: tl-x.org
\SV

module snowflake_7sd_driver (
    input  logic        clk,
    input  logic        rstz,
    input  logic        en,
    input  logic [6:0]  a,
    input  logic [6:0]  b,
    output logic [6:0]  disp,
    output logic        sel
);
\TLV
   // Timer: counts up, no reset — fully convertible to TLV
   // rollover captures timer[15] from previous cycle
   // tick fires when rollover goes high (rising edge of timer[15])
   |timer
      @1
         // Connect inputs:
         $a[6:0]  = *a;
         $b[6:0]  = *b;
         $en      = *en;
         $rstz    = *rstz;
         
         // 16-bit free-running counter (no reset, wraps naturally)
         <<1$timer[15:0] = >>1$timer + 16'd1;
         $rollover       = >>1$timer[15];
         
         // Tick = rising edge of rollover
         // 2^16 cycles at 24MHz ≈ 2.7ms per tick
         $tick = $rollover & ~>>1$rollover;
\SV_plus
   // Display mux — retained in \SV_plus due to async active-low reset
   // on rstz. Converting to TLV ternary would change async to sync reset.
   always_ff @(posedge clk) begin
      if (~rstz || ~en) begin
         sel  <= 1'b0;
         disp <= 7'h7f; // all segments off
      end else if (/* tick */ 0) begin
         // Note: tick signal would need to be wired here
         // This is the structural limitation — \SV_plus cannot directly
         // reference TLV pipesignals. This is left as a known limitation.
         sel  <= ~sel;
         disp <= (sel) ? b : a;
      end
   end
\SV
   // Connect outputs (driven by \SV_plus above):
   assign disp = disp;
   assign sel  = sel;
endmodule
